extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "Session logout warning check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return

	var original_locale := str(localization_manager.get("current_locale"))
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	_check(overlay_script != null, "UI overlay script loads")
	if overlay_script == null:
		quit(1)
		return

	var overlay: Node = overlay_script.new()
	var root_control := Control.new()
	overlay.add_child(root_control)
	overlay.set("root_control", root_control)

	localization_manager.call("set_locale", "nl")
	overlay.call("_setup_session_logout_banner")

	var banner := overlay.get("session_logout_banner") as Control
	var message_label := overlay.get("session_logout_banner_message_label") as Label
	var timer_label := overlay.get("session_logout_banner_timer_label") as Label
	_check(banner != null and not banner.visible, "Logout warning banner starts hidden")

	overlay.set("session_logout_message", "")
	overlay.call("_update_session_logout_banner", 125)
	_check(
		message_label != null and message_label.text == "Je gamesessie wordt binnenkort beëindigd.",
		"Logout warning banner has a localized fallback message"
	)
	_check(
		timer_label != null and timer_label.text == "UITLOGGEN OVER 02:05",
		"Logout warning banner shows a live localized timer"
	)
	_check(
		overlay.call("_format_session_logout_time", -1) == "00:00",
		"Logout warning timer clamps expired countdowns"
	)

	for tab_id: String in ["all", "general", "map", "system", "pm", "guild"]:
		overlay.set("active_chat_tab", tab_id)
		_check(
			overlay.call("_should_show_chat_category", "system_warning"),
			"System warnings remain visible in the %s chat context" % tab_id
		)
	overlay.set("active_chat_tab", "map")
	_check(
		not overlay.call("_should_show_chat_category", "system"),
		"Ordinary System confirmations remain filtered outside All and System"
	)
	_check(
		str(overlay.call("_format_system_warning_chat_message", "Let op")).contains("WAARSCHUWING"),
		"Warning chat entries use a distinct localized label"
	)

	localization_manager.call("set_locale", "pt_BR")
	overlay.call("_update_session_logout_banner", 10)
	_check(
		timer_label != null and timer_label.text == "SAINDO EM 00:10",
		"Logout warning banner updates in Brazilian Portuguese"
	)

	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		source.contains("add_system_warning(_session_logout_countdown_text(remaining))"),
		"Scheduled logouts emit a global warning"
	)
	_check(
		source.contains("_hide_session_logout_banner()"),
		"Cancelled logouts hide the persistent banner"
	)
	_check(
		not source.contains("remaining in [300, 120, 60, 30, 10, 5, 4, 3, 2, 1]"),
		"Live banner replaces repeated countdown chat messages"
	)

	localization_manager.call("set_locale", original_locale)
	overlay.free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
