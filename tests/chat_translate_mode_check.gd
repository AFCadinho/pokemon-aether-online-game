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
		overlay_source.contains("selected_language_chat in LANGUAGE_CHAT_CHANNELS"),
		"Translate Mode is limited to official language chats"
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

	for locale: String in LOCALES:
		var path := "res://localization/%s.json" % locale
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s chat translation catalog parses" % locale)
		if parsed is not Dictionary:
			continue
		for key: String in REQUIRED_KEYS:
			_check((parsed as Dictionary).has(key), "%s contains %s" % [locale, key])

	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failures += 1
	push_error("FAIL %s" % message)
