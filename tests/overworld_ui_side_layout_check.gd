extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var hotbar_block := _node_block(scene_source, '[node name="HotkeySidebar"')
	var player_status_block := _node_block(scene_source, '[node name="PlayerStatusPanel"')
	var party_block := _node_block(scene_source, '[node name="PartyPanel"')
	var chat_block := _node_block(scene_source, '[node name="ChatPanel"')
	var chat_tabs_block := _node_block(scene_source, '[node name="ChatTabsPanel"')

	_check(hotbar_block.contains("anchors_preset = 6"), "hotbar is anchored to the right")
	_check(hotbar_block.contains("offset_right = 0.0"), "hotbar hugs the right screen edge")
	_check(party_block.contains("anchors_preset = 0"), "normal party is anchored to the left")
	_check(party_block.contains("offset_left = 0.0"), "normal party hugs the left screen edge")
	_check(party_block.contains("offset_top = 160.0"), "normal party leaves clear space above the chat")
	_check(not player_status_block.contains("anchors_preset = 2"), "mini trainer card keeps its inherited bottom-right layout")
	_check(chat_block.contains("anchors_preset = 2"), "chat is anchored bottom-left")
	_check(chat_tabs_block.contains("anchors_preset = 2"), "chat tabs follow the left-side chat")

	_check(script_source.contains('_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "left_center")'), "hotbar collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("chat", chat_panel, "right")'), "chat controls sit on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("player_status", player_status_panel, "left")'), "trainer card collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("party", party_panel, "right")'), "party collapse control sits on its inner edge")
	_check(script_source.contains("chat_tabs_panel.z_index = UI_CHAT_TABS_Z_INDEX"), "chat tabs render above active party slots")
	_check(script_source.contains("chat_resize_drag_start_rect.size.x + delta.x"), "dragging chat's right resize handle outward expands it")
	_check(script_source.contains("chat_panel.offset_right = chat_panel.offset_left + clamped_size.x"), "chat resizing preserves the left edge")
	_check(script_source.contains("func _on_party_slot_clicked(slot_index: int)"), "normal party slots remain clickable")
	_check(script_source.contains("_show_pokemon_summary(slot_index)"), "normal party slots still open summaries")
	_check(battle_source.contains("BATTLE_UI_DEFAULT_HORIZONTAL_OFFSET := 130.0"), "battle UI defaults to the right of the party column")
	_check(battle_source.contains("(parent_control.size.x - size.x) * 0.5 + BATTLE_UI_DEFAULT_HORIZONTAL_OFFSET"), "battle UI applies its horizontal default offset")

	quit(1 if failed else 0)


func _node_block(source: String, header_prefix: String) -> String:
	var start := source.find(header_prefix)
	if start < 0:
		return ""
	var end := source.find("\n\n", start)
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
