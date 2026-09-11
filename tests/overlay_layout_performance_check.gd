extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	var overlay := scene.instantiate()
	var control: Control = overlay.get_node("Control")
	# Mount only the controls: the full overlay's startup performs service requests.
	overlay.remove_child(control)
	control.owner = null
	root.add_child(control)
	overlay.set("root_control", control)
	_check(overlay.get("item_dex_popup") == null and overlay.get("pokedex_popup") == null, "dex windows start unallocated")
	for method: String in ["_setup_item_dex_popup", "_setup_pokedex_popup"]:
		overlay.call(method)
		var count := control.get_child_count()
		overlay.call(method)
		_check(control.get_child_count() == count, "opening a dex reuses its window")
	var panel := Control.new()
	control.add_child(panel)
	panel.size = Vector2(100, 50)
	overlay.call("_register_collapsible_panel", "test", panel, "right")
	overlay.call("_position_collapsible_buttons")
	_check(not overlay.get("_collapsible_layout_dirty"), "settled layout is clean")
	panel.position = Vector2(32, 64)
	_check(overlay.get("_collapsible_layout_dirty"), "panel movement invalidates layout")
	overlay.call("_position_collapsible_buttons")
	var button: Button = overlay.get("collapsible_panels")["test"]["button"]
	_check(button.position.y == 64 and button.position.x > 100, "button follows moved panel")
	overlay.free()
	control.free()
	await process_frame
	print("overlay_layout_performance_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
