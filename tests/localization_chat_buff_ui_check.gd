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
	localization_manager.call("set_locale", "nl")
	_check(overlay.call("_chat_tab_label", "general") == "Algemeen", "General chat tab renders in Dutch")
	_check(
		overlay.call("_localized_buff_name", {"name_key": "ui.buff.global_exp.name"}) == "Wereldwijde EXP-boost",
		"Global buff name renders in Dutch"
	)
	_check(
		overlay.call("_localized_buff_description", {"description_key": "ui.buff.global_exp.description"}).begins_with("Na financiering"),
		"Global buff description renders in Dutch"
	)

	var map_prefix := overlay.call("_create_chat_channel_prefix", "map") as Button
	_check(map_prefix != null and map_prefix.text == "[Kaart]", "All-chat channel prefix renders in Dutch")
	_check(map_prefix != null and map_prefix.tooltip_text == "Open de Kaart-chat", "Channel prefix tooltip renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	if map_prefix != null:
		localization_manager.call("localize_tree", map_prefix)
	_check(overlay.call("_chat_tab_label", "general") == "Geral", "General chat tab updates to Portuguese")
	_check(
		overlay.call("_localized_buff_name", {"name_key": "ui.buff.global_exp.name"}) == "Bônus global de EXP",
		"Global buff name updates to Portuguese"
	)
	_check(map_prefix != null and map_prefix.text == "[Mapa]", "Existing channel prefix updates to Portuguese")
	_check(map_prefix != null and map_prefix.tooltip_text == "Abrir o chat do Mapa", "Existing channel tooltip updates to Portuguese")

	if map_prefix != null:
		map_prefix.free()
	overlay.free()


func _check_scene_uses_semantic_keys() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	for key: String in [
		"ui.chat.tab.general",
		"ui.chat.tab.trade",
		"ui.chat.tab.system",
		"ui.chat.send",
		"ui.buff.none",
		"ui.buff.global_exp.name",
		"ui.social.title",
	]:
		_check(source.contains('"%s"' % key), "Overlay scene uses semantic key %s" % key)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
