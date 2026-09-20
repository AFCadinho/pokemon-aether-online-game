extends SceneTree
const Bridge = preload("res://scripts/battle/battle_ui/battle_chat_bridge.gd")
var sent: Array[String] = []
func _init() -> void:
	_run.call_deferred()
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
func _run() -> void:
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var ui := Control.new()
	ui.name = "Control"
	ui.size = Vector2(1920,1080)
	overlay.add_child(ui)
	var other := Button.new()
	other.name = "Inventory"
	ui.add_child(other)
	var panel := PanelContainer.new()
	panel.name = "ChatPanel"
	ui.add_child(panel)
	var node: Node = panel
	for name in ["MarginContainer","VBoxContainer","InputRow"]:
		var child := Control.new()
		child.name = name
		node.add_child(child)
		node = child
	var entry := LineEdit.new()
	entry.name = "ChatInput"
	entry.size = Vector2(300,32)
	node.add_child(entry)
	entry.text_submitted.connect(func(value): sent.append(value))
	var tabs := Control.new()
	tabs.name = "ChatTabsPanel"
	tabs.size = Vector2(400,32)
	ui.add_child(tabs)
	var row := HBoxContainer.new()
	row.name = "TabRow"
	tabs.add_child(row)
	var general := Button.new()
	general.text = "General"
	row.add_child(general)
	var settings = root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var original := panel.get_rect()
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle,overlay)
	assert(host.get_node("Cover").z_index == RenderingServer.CANVAS_ITEM_Z_MAX)
	assert(not overlay.visible, "Chat canvas must remain hidden under the preparation cover")
	var loading_shortcut := InputEventAction.new()
	loading_shortcut.action = "battle_run"
	loading_shortcut.pressed = true
	var before_loading_input = battle.queued_battle_action.duplicate(true)
	battle._unhandled_input(loading_shortcut)
	assert(battle.queued_battle_action == before_loading_input,"Loading must not queue battle shortcuts")
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = ui.size
	host._fit_battle()
	host.get_node("Cover").hide()
	battle.remove_meta("battle_screen_preparing")
	var bridge = host.chat_bridge
	bridge._refresh()
	await process_frame
	assert(not other.visible and not panel.visible and not tabs.visible)
	assert(bridge.log_selected and bridge.log_view.visible,"Every battle must initially show Battle Log")
	assert(bridge.log_view.get_theme_stylebox("normal").bg_color.a < 0.7)
	assert(panel.get_theme_stylebox("panel").bg_color.a < 0.7)
	assert(bridge.calculator_button.get_global_rect().end.y <= bridge.primary_tabs.get_global_rect().position.y)
	battle.calc_drawer.show()
	await process_frame
	assert(not bridge.primary_tabs.visible and not bridge.log_view.visible and not panel.visible)
	battle.calc_drawer.hide()
	await process_frame
	assert(bridge.log_view.visible)
	assert(not entry.has_focus(),"Showing chat must not steal focus")
	await key(KEY_ENTER)
	assert(entry.has_focus())
	var shortcut := InputEventAction.new()
	shortcut.action = "battle_move_1"
	shortcut.pressed = true
	var queued = battle.queued_battle_action.duplicate(true)
	battle._unhandled_input(shortcut)
	assert(battle.queued_battle_action == queued,"Typing queued a battle action")
	battle.battle_log_panel.add_message("Dragonite used Outrage")
	for frame in 4:
		await process_frame
	assert(not battle.battle_log_rail.visible)
	assert(bridge.log_tab.text.contains("•"))
	assert(entry.has_focus(),"Log updates stole chat focus")
	entry.text = "test draft"
	await key(KEY_ENTER)
	assert(sent == ["test draft"],"Exactly one submission through existing signal")
	await key(KEY_ESCAPE)
	assert(not entry.has_focus())
	assert(entry.text == "test draft","Bridge must not clear or resend drafts")
	battle._set_battle_log_open(true)
	await process_frame
	assert(bridge.log_selected and bridge.log_view.visible and not panel.visible)
	assert(not tabs.visible and bridge.primary_tabs.visible)
	assert(bridge.log_tab.get_parent() == bridge.primary_tabs)
	assert(bridge.log_view.text == battle.battle_log_panel.log_buffer)
	assert(bridge.log_tab.text == "Battle Log")
	general.pressed.emit()
	await process_frame
	assert(not bridge.log_selected and panel.visible and not bridge.log_view.visible)
	assert(tabs.visible)
	var original_scale: Vector2 = panel.scale
	var original_height: float = panel.size.y
	bridge.preferred_height = 500
	bridge._refresh()
	assert(panel.size.y > original_height and panel.scale == original_scale,"Height adjustment must not shrink text")
	assert(bridge.contains_pointer(bridge.resize_handle.get_global_rect().get_center()))
	var saved_height: float = settings.immersive_chat_height
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	bridge._resize_input(press)
	assert(bridge.resizing)
	var motion := InputEventMouseMotion.new()
	motion.position.y = bridge.drag_start_y + 60
	bridge._input(motion)
	press.pressed = false
	bridge._input(press)
	assert(not bridge.resizing and settings.immersive_chat_height == bridge.preferred_height)
	assert(panel.scale == original_scale)
	settings.set_immersive_chat_height(saved_height)
	assert(entry.text == "test draft")
	bridge.select_log(true)
	await key(KEY_ENTER)
	assert(not bridge.log_selected and entry.has_focus())
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		bridge.select_log(true)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("chat-log.png"))
	host.release()
	host.release()
	assert(other.visible and panel.get_rect()==original)
	assert(not overlay.has_meta("battle_chat_active"))
	assert(not entry.has_theme_font_override("font") and not entry.has_theme_font_size_override("font_size"),"Overworld chat typography must be restored")
	assert(not row.has_node("BattleLogTab"))
	assert(not panel.has_theme_stylebox_override("panel"),"Restore overworld panel styling")
	# A previous battle ending on Chat must not change the next battle's default.
	host.queue_free()
	await process_frame
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var next_battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(next_battle,overlay)
	await process_frame
	assert(host.chat_bridge.log_selected and host.chat_bridge.log_view.visible)
	assert(entry.text == "test draft")
	host.release()
	host.queue_free()
	overlay.queue_free()
	await process_frame
	print("BATTLE_CHAT_BRIDGE_OK")
	quit()
