extends SceneTree

const CATALOG_PATHS: Dictionary = {
	"en": "res://localization/en.json",
	"nl": "res://localization/nl.json",
	"pt_BR": "res://localization/pt_BR.json",
}
const SETTINGS_SCENE_PATH := "res://scenes/interface/settings/settings_menu.tscn"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"
const PROJECT_PATH := "res://project.godot"
const LanguageSelectorStyle := preload("res://scripts/ui/language_selector_style.gd")

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "LocalizationManager autoload is available")
	if localization_manager == null:
		quit(1)
		return
	var original_locale: String = str(localization_manager.get("current_locale"))
	var catalogs := _load_catalogs()
	_check_catalogs(catalogs)
	_check_locale_normalization()
	_check_locale_request_headers()
	_check_runtime_translation(catalogs)
	_check_language_selector_presentation()
	_check_login_scene_translation()
	await _check_settings_scene_translation()
	_check_settings_persistence_contract()
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _load_catalogs() -> Dictionary:
	var catalogs: Dictionary = {}
	for locale: String in CATALOG_PATHS:
		var path := str(CATALOG_PATHS[locale])
		_check(FileAccess.file_exists(path), "%s catalog exists" % locale)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s catalog is valid JSON" % locale)
		catalogs[locale] = parsed as Dictionary if parsed is Dictionary else {}
	return catalogs


func _check_catalogs(catalogs: Dictionary) -> void:
	var english: Dictionary = catalogs.get("en", {})
	_check(not english.is_empty(), "English catalog is not empty")
	for locale: String in CATALOG_PATHS:
		var catalog: Dictionary = catalogs.get(locale, {})
		_check(catalog.size() == english.size(), "%s catalog has the English key count" % locale)
		for key_value: Variant in english.keys():
			var key := str(key_value)
			_check(catalog.has(key), "%s catalog contains %s" % [locale, key])
			_check(not str(catalog.get(key, "")).strip_edges().is_empty(), "%s value for %s is not empty" % [locale, key])
			_check(
				_placeholders(str(catalog.get(key, ""))) == _placeholders(str(english.get(key, ""))),
				"%s placeholders match English for %s" % [locale, key]
			)


func _check_locale_normalization() -> void:
	_check(localization_manager.call("normalize_locale", "en-US") == "en", "English regions normalize to en")
	_check(localization_manager.call("normalize_locale", "nl_NL") == "nl", "Dutch regions normalize to nl")
	_check(localization_manager.call("normalize_locale", "pt-BR") == "pt_BR", "Brazilian Portuguese normalizes to pt_BR")
	_check(localization_manager.call("normalize_locale", "pt-PT") == "pt_BR", "Portuguese currently falls back to pt_BR")
	_check(localization_manager.call("normalize_locale", "de-DE") == "en", "unsupported locales fall back to English")
	_check(localization_manager.call("get_http_locale", "pt_BR") == "pt-BR", "Godot pt_BR maps to HTTP pt-BR")


func _check_locale_request_headers() -> void:
	var gateway_config := root.get_node_or_null("GatewayApiConfig")
	_check(gateway_config != null, "GatewayApiConfig autoload is available")
	if gateway_config == null:
		return

	var headers: PackedStringArray = gateway_config.call("get_accept_headers", "pt_BR")
	_check(headers.has("Accept-Language: pt-BR"), "gateway requests send the selected HTTP locale")


func _check_runtime_translation(catalogs: Dictionary) -> void:
	localization_manager.call("set_locale", "en")
	_check(localization_manager.call("text", "ui.login.sign_in") == "Sign In", "English runtime translation works")
	localization_manager.call("set_locale", "nl")
	_check(localization_manager.call("text", "ui.login.sign_in") == "Inloggen", "Dutch runtime translation works")
	_check(
		localization_manager.call("plural", "ui.login.player_online", "ui.login.players_online", 2) == "2 spelers online",
		"Dutch plural helper formats the count"
	)
	localization_manager.call("set_locale", "pt_BR")
	_check(localization_manager.call("text", "ui.login.sign_in") == "Entrar", "Brazilian Portuguese runtime translation works")

	var manager_catalogs: Dictionary = localization_manager.get("catalogs")
	var dutch_catalog: Dictionary = manager_catalogs.get("nl", {})
	var original_value: Variant = dutch_catalog.get("ui.login.sign_in")
	dutch_catalog.erase("ui.login.sign_in")
	localization_manager.call("set_locale", "nl")
	_check(localization_manager.call("text", "ui.login.sign_in") == "Sign In", "missing locale key falls back to English")
	dutch_catalog["ui.login.sign_in"] = original_value
	_check(
		(localization_manager.call("get_catalog", "nl") as Dictionary).size() == (catalogs.get("nl", {}) as Dictionary).size(),
		"catalog remains complete after fallback test"
	)


func _check_language_selector_presentation() -> void:
	var selector := OptionButton.new()
	LanguageSelectorStyle.configure(selector)
	for index: int in range(LocalizationManager.SUPPORTED_LOCALES.size()):
		var locale: String = LocalizationManager.SUPPORTED_LOCALES[index]
		LanguageSelectorStyle.add_locale_item(
			selector,
			locale,
			localization_manager.call("get_language_name", locale),
			index
		)
	_check(selector.item_count == 3, "styled language selector lists every locale")
	for index: int in range(selector.item_count):
		_check(selector.get_item_icon(index) != null, "language option %d has a flag" % index)
	_check(selector.has_theme_icon_override("arrow"), "language selector uses the custom chevron")
	_check(selector.has_theme_stylebox_override("normal"), "language selector uses a custom surface")
	_check(selector.has_theme_stylebox_override("focus"), "language selector has keyboard focus styling")
	_check(
		selector.get_popup().has_theme_stylebox_override("panel")
		and selector.get_popup().has_theme_stylebox_override("hover"),
		"language selector popup uses the matching PokeAether style"
	)
	selector.free()


func _check_settings_scene_translation() -> void:
	localization_manager.call("set_locale", "nl")
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	_check(packed != null, "settings scene loads with localization enabled")
	if packed == null:
		return

	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame

	var title := menu.get_node_or_null("MarginContainer/VBoxContainer/Header/Heading/TitleLabel") as Label
	var language_options := menu.find_child("LanguageOptionsButton", true, false) as OptionButton
	var tabs := menu.find_child("SettingsTabs", true, false) as TabContainer
	_check(
		title != null and title.text == "Instellingen",
		"static settings text renders in Dutch (received %s)" % str(title.text if title != null else "<missing>")
	)
	_check(language_options != null and language_options.item_count == 3, "language selector lists three locales")
	_check(
		language_options != null and language_options.get_item_icon(0) != null,
		"settings language selector displays flags"
	)
	_check(tabs != null and tabs.get_tab_title(0) == "Algemeen", "dynamic tab title renders in Dutch")
	var dutch_minimum_size := (menu as Control).get_combined_minimum_size()
	_check(
		dutch_minimum_size.x <= 720.0 and dutch_minimum_size.y <= 720.0,
		"Dutch settings fit a 1280x720 viewport (minimum %s)" % dutch_minimum_size
	)

	localization_manager.call("set_locale", "pt_BR")
	await process_frame
	_check(
		title != null and title.text == "Configurações",
		"static settings text updates at runtime (received %s)" % str(title.text if title != null else "<missing>")
	)
	_check(tabs != null and tabs.get_tab_title(0) == "Geral", "dynamic tab title updates at runtime")
	var portuguese_minimum_size := (menu as Control).get_combined_minimum_size()
	_check(
		portuguese_minimum_size.x <= 720.0 and portuguese_minimum_size.y <= 720.0,
		"Brazilian Portuguese settings fit a 1280x720 viewport (minimum %s)" % portuguese_minimum_size
	)

	menu.queue_free()
	await process_frame


func _check_login_scene_translation() -> void:
	var packed := load(LOGIN_SCENE_PATH) as PackedScene
	_check(packed != null, "login scene loads with localization enabled")
	if packed == null:
		return

	var login := packed.instantiate()
	var headline := login.get_node_or_null(
		"Background/Shell/MainSplit/BrandPanel/BrandMargin/BrandLayout/Headline"
	) as Label
	var sign_in := login.get_node_or_null(
		"Background/Shell/MainSplit/LoginColumn/LoginCard/LoginMargin/LoginLayout/LoginButton"
	) as Button
	var language_options := login.get_node_or_null(
		"Background/ScreenActions/LanguageOptionsButton"
	) as OptionButton

	localization_manager.call("set_locale", "nl")
	localization_manager.call("localize_tree", login)
	_check(headline != null and headline.text == "Welkom, Trainer", "login headline renders in Dutch")
	_check(sign_in != null and sign_in.text == "Inloggen", "login action renders in Dutch")
	_check(language_options != null, "login screen exposes the language selector before sign-in")
	var settings_manager := root.get_node_or_null("SettingsManager")
	if language_options != null and settings_manager != null:
		var original_settings_locale := str(settings_manager.get("locale"))
		settings_manager.set("locale", "nl")
		login.set("language_options_button", language_options)
		login.call("_apply_language_options_to_control")
		_check(language_options.item_count == 3, "login language selector lists three locales")
		_check(language_options.get_item_icon(0) != null, "login language selector displays flags")
		_check(
			str(language_options.get_item_metadata(language_options.selected)) == "nl",
			"login language selector reflects the saved locale"
		)
		settings_manager.set("locale", original_settings_locale)

	localization_manager.call("set_locale", "pt_BR")
	localization_manager.call("localize_tree", login)
	_check(
		headline != null and headline.text == "Boas-vindas, Treinador",
		"login headline updates to Brazilian Portuguese"
	)
	_check(sign_in != null and sign_in.text == "Entrar", "login action updates to Brazilian Portuguese")
	login.free()


func _check_settings_persistence_contract() -> void:
	var settings_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
	_check(settings_source.contains('"locale": locale'), "locale is persisted in local settings")
	_check(settings_source.contains("func set_locale"), "settings expose a locale setter")
	_check(
		settings_source.contains("LocalizationManager.get_preferred_system_locale()"),
		"first-run settings use the supported system locale"
	)
	_check(
		project_source.contains('LocalizationManager="*res://scripts/services/localization_manager.gd"'),
		"localization manager is registered as an autoload"
	)
	_check(project_source.contains('locale/fallback="en"'), "project declares English fallback")


func _placeholders(value: String) -> Array[String]:
	var placeholders: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\{[A-Za-z0-9_]+\\}")
	for match_value: RegExMatch in regex.search_all(value):
		var placeholder := match_value.get_string()
		if not placeholders.has(placeholder):
			placeholders.append(placeholder)
	placeholders.sort()
	return placeholders


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
