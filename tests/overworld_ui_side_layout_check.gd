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
	var global_buffs_block := _node_block(scene_source, '[node name="GlobalBuffsPanel"')
	var global_buff_details_block := _node_block(scene_source, '[node name="GlobalBuffDetailsPanel"')
	var personal_buffs_block := _node_block(scene_source, '[node name="PersonalBuffsPanel"')
	var store_block := _node_block(scene_source, '[node name="DonatorStoreButton"')

	_check(hotbar_block.contains("anchors_preset = 6"), "hotbar is anchored to the right")
	_check(hotbar_block.contains("offset_right = 0.0"), "hotbar hugs the right screen edge")
	_check(party_block.contains("anchors_preset = 0"), "normal party is anchored to the left")
	_check(party_block.contains("offset_left = 0.0"), "normal party hugs the left screen edge")
	_check(party_block.contains("offset_top = 160.0"), "normal party leaves clear space above the chat")
	_check(not player_status_block.contains("anchors_preset = 2"), "mini trainer card keeps its inherited bottom-right layout")
	_check(chat_block.contains("anchors_preset = 2"), "chat is anchored bottom-left")
	_check(chat_tabs_block.contains("anchors_preset = 2"), "chat tabs follow the left-side chat")
	_check(global_buffs_block.contains("anchors_preset = 5"), "global buffs sit beside the top-center location card")
	_check(global_buffs_block.contains("offset_left = 214.0"), "global buffs clear the location collapse button")
	_check(global_buffs_block.contains("custom_minimum_size = Vector2(197, 50)"), "global buffs use a compact four-icon tray")
	_check(personal_buffs_block.contains("anchors_preset = 3"), "personal buffs sit above the bottom-right trainer card")
	_check(personal_buffs_block.contains("offset_bottom = -104.0"), "personal buffs leave space above the trainer card")
	_check(personal_buffs_block.contains("custom_minimum_size = Vector2(160, 98)"), "personal buffs have room for three readable text rows")
	_check(store_block.contains("anchors_preset = 3"), "Donator Store is anchored near the trainer card")
	_check(store_block.contains('icon = ExtResource("22_donator_gem")'), "Donator Store uses the purple gem icon")
	_check(not scene_source.contains('[node name="ScopeLabel"'), "buff tray context labels are removed")
	_check(scene_source.count('parent="Control/GlobalBuffsPanel/MarginContainer/Row/BuffSlots"') == 4, "global buff tray exposes four community-goal slots")
	_check(scene_source.count('parent="Control/PersonalBuffsPanel/MarginContainer/Row/BuffSlots"') == 3, "personal buff tray exposes three placeholder slots")
	_check(scene_source.contains('icon = ExtResource("23_global_exp")'), "global EXP goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("24_global_ev")'), "global EV goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("25_global_shiny")'), "global Shiny goal uses its own icon")
	_check(scene_source.contains('icon = ExtResource("26_global_rare")'), "rare encounter goal uses its own icon")
	_check(scene_source.count('[node name="ProgressBar" type="ProgressBar" parent="Control/GlobalBuffsPanel') == 4, "each global icon includes compact funding progress")
	_check(global_buff_details_block.contains("visible = false"), "global buff details start closed")
	_check(scene_source.contains('[node name="DonationSection" type="VBoxContainer" parent="Control/GlobalBuffDetailsPanel'), "global buff details expose contribution controls")
	_check(scene_source.count('[node name="NameLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render readable effect names")
	_check(scene_source.count('[node name="TimeLabel" type="Label" parent="Control/PersonalBuffsPanel') == 3, "personal buffs render remaining durations")
	_check(scene_source.contains('[node name="EmptyLabel" type="Label" parent="Control/PersonalBuffsPanel'), "personal buffs provide an empty-state label")
	_check(scene_source.contains('text = "No buffs active"'), "personal empty state clearly reports that no buffs are active")
	_check(scene_source.contains('[node name="ActiveSummaryButton" type="Button" parent="Control/PersonalBuffsPanel'), "active personal buffs use a compact count button")

	_check(script_source.contains('_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "left_center")'), "hotbar collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("chat", chat_panel, "right")'), "chat controls sit on its inner edge")
	_check(script_source.contains("[personal_buffs_panel, donator_store_button]"), "trainer collapse includes personal buffs and the Donator Store")
	_check(script_source.contains('_register_collapsible_panel("party", party_panel, "right")'), "party collapse control sits on its inner edge")
	_check(script_source.contains('_register_collapsible_panel("location", location_panel, "right_center", null, [global_buffs_panel])'), "location collapse includes global buffs")
	_check(script_source.contains('"companions": companions'), "collapse state tracks grouped companion controls")
	_check(script_source.contains('bool(companion.get_meta("group_available", true))'), "grouped buff docks stay hidden when no buffs are active")
	_check(script_source.contains("chat_tabs_panel.z_index = UI_CHAT_TABS_Z_INDEX"), "chat tabs render above active party slots")
	_check(script_source.contains("chat_resize_drag_start_rect.size.x + delta.x"), "dragging chat's right resize handle outward expands it")
	_check(script_source.contains("chat_panel.offset_right = chat_panel.offset_left + clamped_size.x"), "chat resizing preserves the left edge")
	_check(script_source.contains("func _on_party_slot_clicked(slot_index: int)"), "normal party slots remain clickable")
	_check(script_source.contains("_show_pokemon_summary(slot_index)"), "normal party slots still open summaries")
	_check(script_source.contains("func set_global_buffs(buffs: Array)"), "global buff tray accepts future live data")
	_check(script_source.contains("func set_personal_buffs(buffs: Array)"), "personal buff tray accepts future live data")
	_check(script_source.contains("set_personal_buffs([])"), "personal buffs default to the empty state")
	_check(script_source.contains('personal_buffs_panel.set_meta("group_available", true)'), "personal empty state remains part of the trainer collapse group")
	_check(script_source.contains("PERSONAL_BUFF_PANEL_COMPACT_HEIGHT"), "empty and collapsed active states use a compact panel height")
	_check(script_source.contains("func _on_personal_buffs_summary_pressed()"), "personal buff count can expand and collapse its details")
	_check(script_source.contains("func _personal_buffs_summary_tooltip()"), "personal buff count exposes hover details")
	_check(script_source.contains('personal_buffs_summary_button.text = "%d %s active  %s"'), "personal buff summary reports the active count")
	_check(script_source.contains("func _on_global_buff_button_pressed(button: Button)"), "global buff icons open their detail panel")
	_check(script_source.contains('str(buff.get("state", "funding")) == "active"'), "global buff icons distinguish active and funding states")
	_check(script_source.contains('"id": "global_shiny"'), "global buff data includes Shiny encounters")
	_check(script_source.contains('"id": "global_rare_encounter"'), "global buff data includes rarer Pokémon encounters")
	_check(script_source.contains("Community contributions are not connected yet."), "community contribution placeholder cannot silently spend currency")
	_check(script_source.contains('name_label.text = str(buff.get("name", "Buff"))'), "personal buff rows receive readable names")
	_check(script_source.contains("The Donator Gems Store is not connected yet."), "placeholder Store interaction gives clear feedback")
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
