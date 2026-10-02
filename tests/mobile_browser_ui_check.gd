extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.min_size = Vector2i.ZERO
	var settings := root.get_node("SettingsManager")
	var window_fit := root.get_node("WindowFit")
	root.size_changed.disconnect(window_fit.apply_ui_scale)
	var previous_text := FileAccess.get_file_as_string(settings.SETTINGS_PATH)
	var old_scale: float = settings.ui_scale
	var old_touch: bool = window_fit.is_touch_ui()
	var old_browser: bool = window_fit.is_mobile_browser_ui()
	check(settings._validated_ui_scale("invalid") == 100.0, "invalid persisted scale defaults safely")
	check(settings._validated_ui_scale(INF) == 100.0, "non-finite scale defaults safely")
	settings.set_ui_scale(200)
	check(settings.ui_scale == 150, "scale is bounded")
	settings.ui_scale = 100
	settings.load_settings()
	check(settings.ui_scale == 150, "UI scale persists across reload")
	var pixel_policy := load("res://scripts/services/pixel_perfect_rendering.gd")
	var world_output: float = pixel_policy.browser_output_scale(Vector2i(844,390))
	window_fit.set("_touch_ui", true)
	window_fit.set("_mobile_browser_ui", false)
	await _check_native_touch_layout(settings, window_fit)
	window_fit.set("_mobile_browser_ui", true)
	var login := load("res://scenes/interface/login_screen.tscn").instantiate() as Control
	root.add_child(login)
	var menu: Control = login.settings_menu
	menu.show()
	menu.tab_container.current_tab = 2
	for dimensions: Vector2i in [Vector2i(600,1298), Vector2i(1558,720), Vector2i(1280,960)]:
		for percentage: float in [75.0, 100.0, 150.0]:
			settings.set_ui_scale(percentage)
			root.size = dimensions
			await process_frame
			root.content_scale_size = dimensions
			for frame in 5:
				await process_frame
			menu._fit_to_viewport()
			check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(menu.get_global_rect()), "settings fits at %s / %s" % [dimensions, percentage])
			check(login.username_input.custom_minimum_size.y >= 48, "touch input target is enlarged")
			check(not login.find_child("BrandPanel", true, false).visible, "touch login uses one column")
			var canvas_scale := root.get_screen_transform().get_scale()
			var zoom: Vector2 = pixel_policy.camera_zoom_for_output_scale(world_output, canvas_scale)
			check((zoom * canvas_scale).is_equal_approx(Vector2.ONE * world_output), "UI zoom preserves world output scale")
	menu.ui_scale_slider.value = 125
	check(settings.ui_scale == 125, "settings slider applies immediately")
	menu.find_child("ResetUIScaleButton", true, false).pressed.emit()
	check(settings.ui_scale == 100, "scale reset remains usable")
	login.queue_free()
	await process_frame
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	for frame in 5:
		await process_frame
	for panel_id: String in ["party", "chat", "location", "dex_actions", "hotkey_sidebar"]:
		check(bool(overlay.collapsible_panels[panel_id]["collapsed"]), "touch HUD starts compact: " + panel_id)
		var button: Control = overlay.collapsible_panels[panel_id]["button"]
		check(button.size.x >= 44 and button.size.y >= 44, "HUD expander has a touch target")
	overlay._on_collapsible_panel_button_pressed("chat")
	for frame in 5:
		await process_frame
	var tab_scroll: ScrollContainer = overlay.chat_tabs_panel.get_node("TouchChatTabsScroll")
	check(tab_scroll.size.x > 0, "scrollable chat tabs have visible width")
	check(tab_scroll.size.y >= overlay.chat_tab_row.size.y, "chat tabs are not clipped vertically")
	check(overlay.chat_tabs_panel.position.y >= 68, "chat channels stay below the HUD navigation")
	overlay.queue_free()
	await process_frame
	var old_presentation: String = settings.battle_presentation_mode
	var old_layout: String = settings.battle_ui_layout
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.active_enemy_pokemon = Pokemon.new("Garchomp", 50)
	root.add_child(host)
	host.mount(battle)
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for dimensions: Vector2 in [Vector2(600,1298), Vector2(1168,540), Vector2(1280,960)]:
		for percentage: float in [75,100,150]:
			settings.ui_scale = percentage
			host.size = dimensions
			host._fit_battle()
			for frame in 5:
				await process_frame
			for key: String in ["MovesGrid", "UtilityActions", "CurrentActionPanel"]:
				var control: Control = battle.get_node("%" + key)
				check(host.get_global_rect().grow(1).encloses(control.get_global_rect()), str("host=",host.get_global_rect()," stage=",battle.battle_stage.size," rect=",control.get_global_rect()) + " touch battle control fits: %s / %s / %s" % [key,dimensions,percentage])
	battle.setup_coop_battle()
	for frame in 5:
		await process_frame
	check(battle.custom_minimum_size.x == 1500, "co-op keeps its existing wider battlefield")
	check(battle.battle_stage.custom_minimum_size.x == 1152, "co-op's uncropped stage is preserved")
	var coop_viewport: Control = battle.get_node("%BattleStageViewport")
	check(host.get_global_rect().grow(1).encloses(coop_viewport.get_global_rect()), "co-op viewport fits after switching battle mode")
	host.release()
	host.queue_free()
	await process_frame
	settings.battle_presentation_mode = old_presentation
	settings.battle_ui_layout = old_layout
	window_fit.set("_touch_ui", old_touch)
	window_fit.set("_mobile_browser_ui", old_browser)
	settings.set_ui_scale(old_scale)
	var saved := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
	saved.store_string(previous_text)
	saved.close()
	print("mobile_browser_ui_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_native_touch_layout(settings: Node, window_fit: Node) -> void:
	# Native Android is still a touch device, with its existing scene layout.
	settings.ui_scale = 100
	check(window_fit.is_touch_ui() and not window_fit.is_mobile_browser_ui(), "native touch keeps keyboard support without browser layout")
	var login = load("res://scenes/interface/login_screen.tscn").instantiate()
	root.add_child(login)
	for frame in 5:
		await process_frame
	check(login.find_child("BrandPanel", true, false).visible, "native login retains the brand panel")
	check(login.get_node("Background/Shell").has_node("MainSplit"), "native login retains its original split layout")
	check(login.username_input.custom_minimum_size.y < 64, "native login retains its original field sizing")
	check(login.settings_menu.compact_navigation == null, "native settings retain their original navigation")
	login.queue_free()
	await process_frame
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.add_child(overlay)
	for frame in 5:
		await process_frame
	for panel_id: String in ["party", "chat", "location", "dex_actions", "hotkey_sidebar"]:
		check(not bool(overlay.collapsible_panels[panel_id]["collapsed"]), "native HUD panel starts expanded: " + panel_id)
	check(not overlay.chat_tabs_panel.has_node("TouchChatTabsScroll"), "native chat retains its original tabs")
	check(overlay.chat_input.custom_minimum_size.y == 44, "native chat retains its 44-unit input")
	check(overlay.settings_button.custom_minimum_size == Vector2(50,50), "native quick buttons retain their 50-unit size")
	overlay._on_collapsible_panel_button_pressed("chat")
	overlay._on_collapsible_panel_button_pressed("chat")
	check(not bool(overlay.collapsible_panels["party"]["collapsed"]), "opening native chat leaves other panels expanded")
	overlay.queue_free()
	await process_frame
	var old_presentation: String = settings.battle_presentation_mode
	var old_layout: String = settings.battle_ui_layout
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.active_enemy_pokemon = Pokemon.new("Garchomp",50)
	root.add_child(host)
	host.mount(battle)
	for frame in 5:
		await process_frame
	check(battle.custom_minimum_size.x == 1500, "native battle retains the original 1500-unit design")
	check(battle.get_node("%MovesGrid").scale.is_equal_approx(Vector2.ONE * 0.8), "native moves retain original scale")
	host.release()
	host.queue_free()
	await process_frame
	settings.battle_presentation_mode = old_presentation
	settings.battle_ui_layout = old_layout
