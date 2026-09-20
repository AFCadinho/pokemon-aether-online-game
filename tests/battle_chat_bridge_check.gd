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
	var settings = root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d"
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var original := panel.get_rect()
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle,overlay)
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = ui.size
	host._fit_battle()
	host.get_node("Cover").hide()
	var bridge = host.chat_bridge
	await process_frame
	assert(not other.visible and panel.visible and tabs.visible)
	assert(not entry.has_focus(),"Showing chat must not steal focus")
	await key(KEY_ENTER)
	assert(entry.has_focus())
	var shortcut := InputEventAction.new()
	shortcut.action = "battle_move_1"
	shortcut.pressed = true
	var queued = battle.queued_battle_action.duplicate(true)
	battle._unhandled_input(shortcut)
	assert(battle.queued_battle_action == queued,"Typing queued a battle action")
	battle._set_battle_log_open(true)
	for frame in 4:
		await process_frame
	assert(not battle.battle_log_rail.get_global_rect().intersects(panel.get_global_rect()),str("Log overlaps chat ",battle.battle_log_rail.get_global_rect()," ",panel.get_global_rect()))
	assert(entry.has_focus(),"Log updates stole chat focus")
	entry.text = "test draft"
	await key(KEY_ENTER)
	assert(sent == ["test draft"],"Exactly one submission through existing signal")
	await key(KEY_ESCAPE)
	assert(not entry.has_focus())
	assert(entry.text == "test draft","Bridge must not clear or resend drafts")
	host.release()
	host.release()
	assert(other.visible and panel.get_rect()==original)
	assert(not overlay.has_meta("battle_chat_active"))
	host.queue_free()
	overlay.queue_free()
	await process_frame
	print("BATTLE_CHAT_BRIDGE_OK")
	quit()
