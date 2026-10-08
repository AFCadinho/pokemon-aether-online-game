extends SceneTree

var checks := 0
var failures := 0
var overlay: CanvasLayer
const IDS: Array[String] = ["actions", "dex_actions", "quest"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let WindowFit's initial deferred desktop window sizing finish before
	# installing the simulated phone viewport (also used for rendered QA).
	await _settle()
	var fit := root.get_node("WindowFit")
	root.size_changed.disconnect(fit.apply_ui_scale)
	root.mode = Window.MODE_WINDOWED
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(800, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1920, 1080)
	fit.set("_touch_ui", true)
	fit.set("_mobile_browser_ui", false)
	overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	await _settle()
	var view: Control = overlay.quest_journal_view
	view.has_main_tracker = true
	view.has_side_tracker = true
	view._layout_trackers()
	for factor: float in [0.9375, 1.25, 1.875]:
		# Match 75/100/150% Android UI scale in dp-sized screen coordinates.
		root.content_scale_factor = factor
		await _set_state(0)
		var baseline: Dictionary = {}
		for id: String in IDS:
			baseline[id] = _button(id).get_global_rect()
		for mask in 8:
			await _set_state(mask)
			var actions: Rect2 = _owner("actions").get_global_rect()
			var dex: Rect2 = _owner("dex_actions").get_global_rect()
			var quest: Rect2 = _owner("quest").get_global_rect()
			_check(is_equal_approx(dex.position.y - actions.end.y, overlay.ACTION_BAR_SLOT_GAP), "action bars retain desktop spacing")
			_check(is_equal_approx(quest.position.y - dex.end.y, overlay.ACTION_BAR_SLOT_GAP), "quest follows the compact action bars")
			for id: String in IDS:
				var button := _button(id)
				var rect := button.get_global_rect()
				_check(is_equal_approx(rect.position.y, baseline[id].position.y), "%s keeps its row height at %s state %s" % [id, factor, mask])
				_check(button.visible, id + " stays visible")
				var visual := _visual(button)
				var owner := _owner(id).get_global_rect()
				if _collapsed(id):
					# Compact rows can share a vertical touch band. Reopen targets
					# move sideways when an adjacent expanded row occupies the edge.
					_check(visual.end.x <= owner.end.x + 0.01, id + " reopens within the right edge")
				else:
					_check(visual.end.x <= owner.position.x, id + " stays to the left of its expanded row")
				_check(visual.get_center().y >= owner.position.y and visual.get_center().y <= owner.end.y, "%s aligns with row scale=%s visual=%s owner=%s" % [id, factor, visual, owner])
				var pixels := (root.get_screen_transform() * button.get_global_transform_with_canvas()) * Rect2(Vector2.ZERO, button.size)
				_check(pixels.size.x >= 47.99 and pixels.size.y >= 47.99, id + " keeps its touch area")
				for other: String in IDS:
					if other != id:
						_check(not rect.intersects(_button(other).get_global_rect()), id + " is distinct from " + other)
				var before := _collapsed(id)
				await _tap(visual.get_center())
				_check(_collapsed(id) != before, id + " receives a tap on its visible arrow")
				await _tap(button.get_global_rect().position + button.size * Vector2(0.1, 0.9))
				_check(_collapsed(id) == before, id + " receives a tap in transparent padding")
				_check(button.get_global_rect().position.is_equal_approx(rect.position), id + " returns to its position after toggling twice")
	if "--qa-screenshot" in OS.get_cmdline_user_args():
		await _set_state(0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://android-hud-row-spacing.png")
	overlay.queue_free()
	await process_frame
	print("mobile_top_right_collapse_check: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _set_state(mask: int) -> void:
	for index in 2:
		var id := IDS[index]
		overlay.collapsible_panels[id]["collapsed"] = bool(mask & (1 << index))
		overlay._apply_collapsible_panel_state(id)
	overlay.quest_journal_view.tracker_collapsed = bool(mask & 4)
	overlay.quest_journal_view._layout_trackers()
	overlay._invalidate_collapsible_layout()
	await _settle()


func _button(id: String) -> Button:
	return overlay.quest_journal_view.tracker_collapse_button if id == "quest" else overlay.collapsible_panels[id]["button"]


func _owner(id: String) -> Control:
	return overlay.quest_journal_view.tracker_panel if id == "quest" else overlay.collapsible_panels[id]["panel"]


func _collapsed(id: String) -> bool:
	return overlay.quest_journal_view.tracker_collapsed if id == "quest" else overlay.collapsible_panels[id]["collapsed"]


func _visual(button: Button) -> Rect2:
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	return button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size).grow_individual(style.expand_margin_left, style.expand_margin_top, style.expand_margin_right, style.expand_margin_bottom)


func _scale(button: Button) -> Vector2:
	return (root.get_screen_transform() * button.get_global_transform_with_canvas()).get_scale().abs()


func _tap(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await _settle()


func _settle() -> void:
	for frame in 4:
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
