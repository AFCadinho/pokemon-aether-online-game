extends SceneTree

const NewsLocalizationService := preload("res://scripts/services/news_localization_service.gd")
const LAUNCHER_CATALOGS := {
	"en": "res://launcher/localization/en.json",
	"nl": "res://launcher/localization/nl.json",
	"pt_BR": "res://launcher/localization/pt_BR.json",
	"zh_CN": "res://launcher/localization/zh_CN.json",
}

var failed := false


func _init() -> void:
	_check_launcher_catalogs()
	_check_news_fallbacks()
	_check_integration_contracts()
	if not failed:
		print("PASS localization_launcher_news_check")
	quit(1 if failed else 0)


func _check_launcher_catalogs() -> void:
	var catalogs: Dictionary = {}
	for locale: String in LAUNCHER_CATALOGS:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(str(LAUNCHER_CATALOGS[locale]))
		)
		_check(parsed is Dictionary, "launcher %s catalog is valid JSON" % locale)
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}

	var english: Dictionary = catalogs.get("en", {})
	_check(not english.is_empty(), "launcher English catalog is not empty")
	for locale: String in LAUNCHER_CATALOGS:
		var catalog: Dictionary = catalogs.get(locale, {})
		_check(catalog.size() == english.size(), "launcher %s catalog has all English keys" % locale)
		for key: Variant in english:
			_check(catalog.has(key), "launcher %s catalog contains %s" % [locale, key])
			_check(
				_placeholders(str(catalog.get(key, ""))) == _placeholders(str(english.get(key, ""))),
				"launcher %s placeholders match for %s" % [locale, key]
			)


func _check_news_fallbacks() -> void:
	var legacy := {
		"items": [{
			"title": "English legacy title",
			"description": "English legacy body",
			"url": "https://example.com/en",
		}],
	}
	var legacy_dutch := NewsLocalizationService.resolve_items(legacy, "nl")
	_check(
		legacy_dutch.size() == 1 and legacy_dutch[0].get("title") == "English legacy title",
		"English-only legacy news remains available in Dutch"
	)

	var localized := {
		"items": [{
			"title": "English title",
			"description": "English body",
			"url": "https://example.com/en",
			"localizations": {
				"nl": {"title": "Nederlandse titel", "description": "Nederlandse tekst"},
				"pt-BR": {"title": "Título em português"},
				"zh-CN": {"title": "中文标题"},
			},
		}],
	}
	var dutch := NewsLocalizationService.resolve_items(localized, "nl-NL")
	_check(dutch[0].get("title") == "Nederlandse titel", "news selects the Dutch item translation")
	var portuguese := NewsLocalizationService.resolve_items(localized, "pt-BR")
	_check(portuguese[0].get("title") == "Título em português", "news selects pt-BR")
	_check(portuguese[0].get("description") == "English body", "missing localized fields fall back to English")
	var chinese := NewsLocalizationService.resolve_items(localized, "zh-CN")
	_check(chinese[0].get("title") == "中文标题", "news selects zh-CN")
	_check(chinese[0].get("description") == "English body", "missing Chinese news fields fall back to English")
	var unsupported := NewsLocalizationService.resolve_items(localized, "de-DE")
	_check(unsupported[0].get("title") == "English title", "unsupported news locale falls back to English")

	var buckets := {
		"locales": {
			"en": {"items": [{"title": "English bucket"}]},
			"nl": {"items": [{"title": "Nederlandse bucket"}]},
		},
	}
	var bucket_items := NewsLocalizationService.resolve_items(buckets, "nl")
	_check(bucket_items[0].get("title") == "Nederlandse bucket", "top-level locale news buckets are supported")


func _check_integration_contracts() -> void:
	var launcher_project := FileAccess.get_file_as_string("res://launcher/project.godot")
	var launcher_source := FileAccess.get_file_as_string("res://launcher/scripts/launcher.gd")
	var launcher_scene := FileAccess.get_file_as_string("res://launcher/scenes/launcher.tscn")
	var login_source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(
		launcher_project.contains('LauncherLocalization="*res://scripts/localization_manager.gd"'),
		"launcher localization manager is an autoload"
	)
	_check(
		launcher_scene.contains('[node name="LanguageOptionsButton" type="OptionButton"'),
		"launcher exposes a language selector"
	)
	_check(
		launcher_source.contains('"locale": locale') and launcher_source.contains('"Accept-Language: %s, en;q=0.8"'),
		"launcher persists locale and requests localized content"
	)
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	_check(
		launcher_source.contains('"--locale=%s" % locale') and settings_source.contains("OS.get_cmdline_user_args()"),
		"launcher language is synchronized to the game on launch"
	)
	_check(
		login_source.contains("NewsLocalizationService.resolve_items") and login_source.contains('"Accept-Language: %s, en;q=0.8"'),
		"login news uses locale selection and an English request fallback"
	)


func _placeholders(value: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("\\{[A-Za-z0-9_]+\\}")
	var result: Array[String] = []
	for match_result: RegExMatch in regex.search_all(value):
		result.append(match_result.get_string())
	result.sort()
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % message)
