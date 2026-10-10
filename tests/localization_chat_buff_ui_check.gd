extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Chat and buff localization check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	_check_localized_helpers()
	_check_chat_navigation()
	_check_scene_uses_semantic_keys()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_localized_helpers() -> void:
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	_check(overlay_script != null, "Chat and buff overlay script loads")
	if overlay_script == null:
		return

	var overlay: Node = overlay_script.new()
	var enabled_language_chats: Array[String] = ["language_zh"]
	overlay.set("enabled_language_chats", enabled_language_chats)
	overlay.set("active_chat_tab", "all")
	_check(
		overlay.call("_should_show_chat_category", "language_zh"),
		"All chat shows an enabled community language channel"
	)
	_check(
		not overlay.call("_should_show_chat_category", "language_pt"),
		"All chat keeps a disabled community language channel hidden"
	)
	localization_manager.call("set_locale", "nl")
	_check(overlay.call("_chat_tab_label", "general") == "Algemeen", "General chat tab renders in Dutch")
	_check(overlay.call("_chat_tab_label", "languages") == "Talen", "Languages chat tab renders in Dutch")
	_check(overlay.call("_language_chat_label", "language_zh") == "中文", "Chinese chat keeps its native label")
	_check(
		str(localization_manager.call("text", "ui.chat.settings.description")).contains("Moderatie kan beperkt zijn"),
		"Dutch language chat settings disclose limited community moderation"
	)
	_check(
		overlay.call("_localized_buff_name", {"name_key": "ui.buff.global_exp.name"}) == "Wereldwijde EXP-boost",
		"Global buff name renders in Dutch"
	)
	_check(
		overlay.call("_localized_buff_description", {"description_key": "ui.buff.global_exp.description"}).begins_with("Na financiering"),
		"Global buff description renders in Dutch"
	)
	_check(
		overlay.call("_localized_buff_name", {"name_key": "ui.buff.global_heal.name"}) == "Global Heal",
		"Global Heal name renders in Dutch"
	)
	_check(
		overlay.call(
			"_localized_buff_name",
			{"name_key": "ui.buff.aether_blessing_shiny.name"}
		) == "5% Shiny",
		"Aether Blessing's Shiny effect is immediately readable in the boost tray"
	)
	_check(
		overlay.call(
			"_localized_buff_name",
			{"name_key": "ui.buff.aether_blessing_travel.name"}
		) == "50% Travel",
		"Aether Blessing's travel effect is immediately readable in the boost tray"
	)
	_check(
		overlay.call(
			"_localized_buff_name",
			{"name_key": "ui.buff.aether_blessing_shops.name"}
		) == "5% NPC Shops",
		"Aether Blessing's NPC shop effect is immediately readable in the boost tray"
	)
	_check(
		str(localization_manager.call("text", "ui.buff.global_heal.no_aetherite")).contains("geen Aetherite"),
		"Global Heal clearly states that it does not award Aetherite"
	)
	_check(
		overlay.call("_format_global_buff_remaining", 3_541) == "60 min",
		"Global buff countdown rounds remaining time up to whole minutes"
	)
	_check(
		overlay.call("_global_live_event_message", {
			"action": "activated",
			"eventName": "Dubbele EXP-weekend",
		}) == "Live-event gestart: Dubbele EXP-weekend.",
		"Admin live events render as localized Dutch system messages"
	)
	_check(
		str(localization_manager.call(
			"text",
			"ui.buff.server_event_remaining",
			{"event": "Dubbele EXP-weekend", "remaining": "48 min"}
		)).contains("Dubbele EXP-weekend"),
		"The active boost details retain the player-facing live event name"
	)
	_check(
		overlay.call("_global_exp_boost_contribution_message", {
			"displayName": "Misty",
			"amount": 25_000,
		}) == "Misty heeft ₽25,000 bijgedragen aan de Wereldwijde EXP-boost!",
		"Global EXP contributions render as localized Dutch system messages"
	)
	_check(
		overlay.call("_global_boost_activation_message", {
			"name_key": "ui.buff.global_exp.name",
		}) == "Wereldwijde EXP-boost is geactiveerd!",
		"Global boost activations render as localized Dutch system messages"
	)
	_check(
		overlay.call("_global_skill_exp_boost_contribution_message", {
			"displayName": "Misty",
			"amount": 10_000,
		}) == "Misty heeft ₽10,000 bijgedragen aan de Wereldwijde Skill-EXP-boost!",
		"Global Skill EXP contributions render as localized Dutch system messages"
	)
	_check(
		overlay.call("_global_ev_boost_contribution_message", {
			"displayName": "Misty",
			"amount": 10_000,
		}) == "Misty heeft ₽10,000 bijgedragen aan de Wereldwijde EV-boost!",
		"Global EV contributions render as localized Dutch system messages"
	)
	_check(
		overlay.call("_global_rare_encounter_boost_contribution_message", {
			"displayName": "Misty",
			"amount": 10_000,
		}) == "Misty heeft ₽10,000 bijgedragen aan de Zeldzame-ontmoetingsboost!",
		"Rare encounter contributions render as localized Dutch system messages"
	)

	var map_prefix := overlay.call("_create_chat_channel_prefix", "map") as Button
	_check(map_prefix != null and map_prefix.text == "[Kaart]", "All-chat channel prefix renders in Dutch")
	_check(map_prefix != null and map_prefix.tooltip_text == "Open de Kaart-chat", "Channel prefix tooltip renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	if map_prefix != null:
		localization_manager.call("localize_tree", map_prefix)
	_check(overlay.call("_chat_tab_label", "general") == "Geral", "General chat tab updates to Portuguese")
	_check(overlay.call("_chat_tab_label", "languages") == "Idiomas", "Languages chat tab updates to Portuguese")
	_check(overlay.call("_language_chat_label", "language_pt") == "Português", "Portuguese chat keeps its native label")
	_check(
		str(localization_manager.call("text", "ui.chat.settings.description")).contains("moderação pode ser limitada"),
		"Portuguese language chat settings disclose limited community moderation"
	)
	_check(
		overlay.call("_localized_buff_name", {"name_key": "ui.buff.global_exp.name"}) == "Bônus global de EXP",
		"Global buff name updates to Portuguese"
	)
	_check(
		overlay.call("_global_exp_boost_contribution_message", {
			"displayName": "Misty",
			"amount": 25_000,
		}) == "Misty contribuiu com ₽25,000 para o Bônus global de EXP!",
		"Global EXP contribution system messages update to Portuguese"
	)
	_check(map_prefix != null and map_prefix.text == "[Mapa]", "Existing channel prefix updates to Portuguese")
	_check(map_prefix != null and map_prefix.tooltip_text == "Abrir o chat do Mapa", "Existing channel tooltip updates to Portuguese")

	localization_manager.call("set_locale", "zh_CN")
	_check(overlay.call("_chat_tab_label", "languages") == "语言", "Languages chat tab updates to Simplified Chinese")
	_check(overlay.call("_language_chat_label", "language_zh") == "中文", "Chinese chat uses its native Simplified Chinese label")
	_check(
		str(localization_manager.call("text", "ui.chat.settings.description")).contains("审核可能有限"),
		"Chinese language chat settings disclose limited community moderation"
	)

	if map_prefix != null:
		map_prefix.free()
	overlay.free()


func _check_chat_navigation() -> void:
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	if overlay_script == null:
		return
	var overlay: Node = overlay_script.new()
	var auth_service := root.get_node("AuthService")
	var original_user: Dictionary = auth_service.get("current_user").duplicate(true)
	var controls := Node.new()
	root.add_child(controls)
	var input := LineEdit.new()
	var send := Button.new()
	var selector := Button.new()
	var dock := PanelContainer.new()
	var row := HBoxContainer.new()
	var messages := VBoxContainer.new()
	var options := VBoxContainer.new()
	for binding: Array in [
		["chat_input", input], ["send_button", send],
		["chat_context_selector_button", selector], ["chat_input_dock", dock],
		["chat_input_row", row], ["message_list", messages],
		["chat_context_options", options],
	]:
		overlay.set(binding[0], binding[1])
		controls.add_child(binding[1])

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		auth_service.set("current_user", {"permissions": []})
		localization_manager.call("set_locale", locale)
		overlay.call("_on_general_chat_context_selected", "system")
		_check(overlay.call("_active_primary_chat_tab_id") == "general", "System selects General in %s" % locale)
		_check(dock.visible and row.visible and selector.visible and not selector.disabled, "System keeps channel navigation accessible in %s" % locale)
		_check(not input.visible and not send.visible, "System remains read-only in %s" % locale)
		_check(selector.text.contains(str(localization_manager.call("text", "ui.chat.tab.system"))), "System selector is localized in %s" % locale)
		overlay.call("_rebuild_chat_context_options")
		_check(options.get_child_count() == 4, "General exposes four channel choices in %s" % locale)
		_check((options.get_child(0) as Button).text == localization_manager.call("text", "ui.chat.channel.global"), "Global remains reachable from System in %s" % locale)
		_check((options.get_child(3) as Button).text == localization_manager.call("text", "ui.chat.tab.system"), "System replaces Help in General's menu in %s" % locale)
		(options.get_child(0) as Button).pressed.emit()
		_check(overlay.get("active_chat_tab") == "general" and input.visible and input.editable and send.visible, "Choosing Global from System restores message input in %s" % locale)
		(options.get_child(3) as Button).pressed.emit()
		_check(overlay.get("active_chat_tab") == "system" and not input.visible, "Choosing System from Global restores the read-only view in %s" % locale)

		overlay.call("_on_all_channel_badge_pressed", "help")
		_check(overlay.call("_active_primary_chat_tab_id") == "help", "All's Help prefix opens the independent Help tab in %s" % locale)
		_check(input.visible and input.editable and send.visible and not send.disabled, "Help accepts messages in %s" % locale)
		_check(selector.text == localization_manager.call("text", "ui.chat.tab.help") and selector.disabled, "Help shows its localized fixed channel in %s" % locale)
		_check(overlay.call("_get_active_chat_channel") == "help", "Help sends to the Help channel in %s" % locale)
		_check(overlay.call("_should_show_chat_category", "help") and not overlay.call("_should_show_chat_category", "system"), "Help filters messages to its channel in %s" % locale)
		_check(input.placeholder_text == localization_manager.call("text", "ui.chat.input.help"), "Regular players see the Help cooldown hint in %s" % locale)
		auth_service.set("current_user", {"permissions": ["chat:help:cooldown:bypass"]})
		overlay.call("_apply_chat_tab_state")
		var bypass_hint := str(localization_manager.call("text", "ui.chat.input.help.no_cooldown"))
		_check(input.placeholder_text == bypass_hint and selector.tooltip_text == bypass_hint, "Help bypass updates input and tooltip in %s" % locale)
		auth_service.set("current_user", {"permissions": []})
		overlay.call("_apply_chat_tab_state")
		_check(input.placeholder_text == localization_manager.call("text", "ui.chat.input.help"), "Removing the bypass restores the cooldown hint in %s" % locale)
		overlay.call("_on_chat_tab_pressed", "general")
		_check(overlay.get("active_chat_tab") == "system", "Returning from Help preserves General's System selection in %s" % locale)
		overlay.call("_on_chat_tab_pressed", "all")
		_check(overlay.call("_should_show_chat_category", "system"), "All retains system messages in %s" % locale)
		_check(overlay.call("_should_show_chat_category", "system_warning"), "All retains important warnings in %s" % locale)

	auth_service.set("current_user", original_user)
	overlay.free()
	controls.free()


func _check_scene_uses_semantic_keys() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	for key: String in [
		"ui.chat.tab.general",
		"ui.chat.tab.trade",
		"ui.chat.tab.system",
		"ui.chat.send",
		"ui.buff.none",
		"ui.buff.global_exp.name",
		"ui.buff.global_heal.receive_requests",
		"ui.social.title",
	]:
		_check(source.contains('"%s"' % key), "Overlay scene uses semantic key %s" % key)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
