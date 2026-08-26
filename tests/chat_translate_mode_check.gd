extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const REALTIME_PATH := "res://scripts/services/chat_realtime_service.gd"
const LOCALES: Array[String] = ["en", "nl", "pt_BR", "zh_CN"]
const REQUIRED_KEYS: Array[String] = [
	"ui.chat.translate.toggle",
	"ui.chat.translate.tooltip",
	"ui.chat.translate.unavailable",
	"ui.chat.translate.translated",
	"ui.chat.translate.original",
	"ui.chat.translate.show_original",
	"ui.chat.translate.show_translation",
	"ui.chat.translate.ai_action",
	"ui.chat.translate.ai_tooltip",
	"ui.chat.translate.ai_loading",
	"ui.chat.translate.ai_result",
	"ui.chat.translate.ai_unavailable",
	"ui.staff.translate.action",
	"ui.staff.translate.action_on",
	"ui.staff.translate.action_description_off",
	"ui.staff.translate.action_description_on",
	"ui.staff.translate.action_description_unavailable",
	"ui.chat.pm.translation.tooltip",
	"ui.chat.pm.translation.off",
	"ui.chat.pm.translation.language.zh",
	"ui.chat.pm.translation.language.pb",
	"ui.chat.pm.translation.unavailable",
	"ui.chat.pm.translation.failed",
]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	var realtime_source := FileAccess.get_file_as_string(REALTIME_PATH)

	_check(
		overlay_source.contains('CHAT_TRANSLATE_PERMISSION := "chat:translate"'),
		"Translate Mode uses its dedicated staff permission"
	)
	_check(
		overlay_source.contains("_has_user_permission(CHAT_TRANSLATE_PERMISSION)"),
		"Translate Mode visibility is permission-gated in game"
	)
	_check(
		overlay_source.contains('staff_chat_translate_button.name = "StaffChatTranslateModeButton"')
		and overlay_source.contains('"ui.staff.translate.action_description_off"'),
		"Translate Mode is exposed as a permission-gated Staff Tools card"
	)
	_check(
		overlay_source.contains("func _apply_chat_translate_mode_card_style(active: bool)")
		and overlay_source.contains('var accent := UI_SUCCESS if active')
		and overlay_source.contains('var border_width := 2 if active else 1'),
		"The server-confirmed active Translate Mode card uses a distinct green state"
	)
	_check(
		realtime_source.contains('"type": "chat_translation.set"'),
		"The client asks the backend to change translation state"
	)
	_check(
		realtime_source.contains('message_type == "chat_translation.state"'),
		"The client uses the authoritative backend translation state"
	)
	_check(
		overlay_source.contains('badge.name = "TranslationBadge"')
		and overlay_source.contains("_toggle_chat_translation_text"),
		"Machine translations expose a reversible original-text control"
	)
	_check(
		realtime_source.contains('"type": "chat_translation.ai_request"')
		and realtime_source.contains('message_type == "chat_translation.ai_result"'),
		"AI translation is an explicit per-message request"
	)
	_check(
		overlay_source.contains('button.name = "AiTranslationButton"')
		and overlay_source.contains("ChatRealtimeService.request_ai_translation(message_id)"),
		"Translated messages offer an on-demand AI refinement"
	)
	_check(
		overlay_source.contains('pm_translation_language_select.name = "StaffPrivateMessageTranslationLanguage"')
		and overlay_source.contains("_has_user_permission(CHAT_TRANSLATE_PERMISSION)")
		and overlay_source.contains("ChatRealtimeService.translation_mode_enabled"),
		"Active Translate Mode exposes a staff-only PM language selector"
	)
	_check(
		realtime_source.contains('"type": "chat_translation.pm_set"')
		and realtime_source.contains('"peerUserId": peer_user_id')
		and realtime_source.contains('"language": normalized_language'),
		"PM translation selection sends only participant identity and language code"
	)
	var pm_request_start := realtime_source.find(
		"func set_private_message_translation_language("
	)
	var pm_request_end := realtime_source.find("\n\nfunc ", pm_request_start + 1)
	var pm_request_source := realtime_source.substr(
		pm_request_start,
		pm_request_end - pm_request_start
	) if pm_request_start >= 0 and pm_request_end > pm_request_start else ""
	_check(
		pm_request_source != "" and not pm_request_source.contains('"body"'),
		"The PM language selector cannot submit arbitrary text for translation"
	)
	_check(
		overlay_source.contains('str(message.get("originalBody", ""))')
		and overlay_source.contains('bool(message.get("machineTranslated", false))')
		and overlay_source.contains("_create_chat_translation_badge("),
		"Translated PMs retain a reversible original-text control"
	)
	var pm_row_source := _function_block(overlay_source, "func _create_pm_message_row(")
	_check(
		pm_row_source.contains("_has_user_permission(CHAT_TRANSLATE_PERMISSION)")
		and pm_row_source.contains("_create_chat_translation_badge("),
		"PM translation metadata and original-text controls are staff-only"
	)
	_check(
		overlay_source.contains("_escape_bbcode(text)")
		and overlay_source.contains("_render_chat_sender_message_label(entry)"),
		"Original and translated PM text stays inside the escaped chat renderer"
	)

	for locale: String in LOCALES:
		var path := "res://localization/%s.json" % locale
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s chat translation catalog parses" % locale)
		if parsed is not Dictionary:
			continue
		for key: String in REQUIRED_KEYS:
			_check((parsed as Dictionary).has(key), "%s contains %s" % [locale, key])
		var description := str((parsed as Dictionary).get(
			"ui.staff.translate.action_description_off", ""
		)).to_lower()
		_check(
			not description.contains("portugu")
			and not description.contains("chinese")
			and not description.contains("chinês")
			and not description.contains("中文")
			and not description.contains("simplified"),
			"%s keeps the Translate Mode description language-agnostic" % locale
		)

	quit(1 if failures > 0 else 0)


func _function_block(source: String, function_header: String) -> String:
	var start := source.find(function_header)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + function_header.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failures += 1
	push_error("FAIL %s" % message)
