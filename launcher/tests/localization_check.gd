extends SceneTree

const NewsLocalizationService := preload("res://scripts/news_localization_service.gd")
const LanguageSelectorStyle := preload("res://scripts/language_selector_style.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node_or_null("LauncherLocalization")
	_check(manager != null, "launcher localization autoload is available")
	if manager == null:
		quit(1)
		return

	_check(manager.normalize_locale("nl-NL") == "nl", "Dutch locale normalization matches the game")
	_check(manager.normalize_locale("pt-PT") == "pt_BR", "Portuguese locale normalization matches the game")
	_check(manager.normalize_locale("de-DE") == "en", "unsupported launcher locales fall back to English")
	_check(manager.get_http_locale("pt_BR") == "pt-BR", "launcher maps pt_BR to the HTTP locale")
	_check_language_selector_presentation(manager)

	var scene := load("res://scenes/launcher.tscn") as PackedScene
	_check(scene != null, "localized launcher scene loads")
	if scene != null:
		var launcher := scene.instantiate()
		manager.set_locale("nl")
		manager.localize_tree(launcher)
		var play := launcher.find_child("PlayButton", true, false) as Button
		var news_title := launcher.find_child("NewsTitle", true, false) as Label
		var diagnostics_button := launcher.find_child("DiagnosticsButton", true, false) as Button
		var diagnostics_card := launcher.find_child("DiagnosticsCard", true, false) as PanelContainer
		var language_options := launcher.find_child("LanguageOptionsButton", true, false) as OptionButton
		_check(play != null and play.text == "Spelen", "launcher action renders in Dutch")
		_check(
			news_title != null and news_title.text == "LAATSTE NIEUWS VAN AETHER",
			"launcher news heading renders in Dutch"
		)
		_check(
			diagnostics_button != null and diagnostics_button.text == "Diagnostiek",
			"launcher diagnostics navigation renders in Dutch"
		)
		_check(diagnostics_card != null, "launcher includes the diagnostics view")
		var sanitized_url := str(launcher.call(
			"_sanitize_diagnostic_message",
			"request url=https://updates.example/game.zip?token=private"
		))
		_check(
			sanitized_url == "request url=https://updates.example/game.zip?<redacted>",
			"launcher diagnostics redact URL query values"
		)
		var user_data_path := ProjectSettings.globalize_path("user://").trim_suffix("/")
		var sanitized_path := str(launcher.call(
			"_sanitize_diagnostic_message",
			"file=%s/download.zip" % user_data_path
		))
		_check(
			not sanitized_path.contains(user_data_path) and sanitized_path.contains("<user_data>"),
			"launcher diagnostics redact local user storage paths"
		)
		var sanitized_history := str(launcher.call(
			"_sanitize_diagnostic_contents",
			"old file=%s/update.zip\nold url=https://updates.example/game.zip?token=private" % user_data_path
		))
		_check(
			not sanitized_history.contains(user_data_path)
			and not sanitized_history.contains("token=private")
			and sanitized_history.contains("\n"),
			"launcher diagnostics sanitize historical multiline logs before display and copying"
		)
		_check(language_options != null, "launcher language selector exists")
		launcher.free()

	var localized_news := NewsLocalizationService.resolve_items({
		"items": [{
			"title": "English",
			"localizations": {"nl": {"title": "Nederlands"}},
		}],
	}, "nl")
	_check(localized_news.size() == 1 and localized_news[0].get("title") == "Nederlands", "launcher resolves localized news")

	if not failed:
		print("PASS launcher localization_check")
	quit(1 if failed else 0)


func _check_language_selector_presentation(manager: Node) -> void:
	var selector := OptionButton.new()
	LanguageSelectorStyle.configure(selector)
	var supported_locales: Array[String] = manager.get_supported_locales()
	for index: int in range(supported_locales.size()):
		var locale := supported_locales[index]
		LanguageSelectorStyle.add_locale_item(
			selector,
			locale,
			manager.get_language_name(locale),
			index
		)
	_check(selector.item_count == 3, "launcher styled language selector lists every locale")
	for index: int in range(selector.item_count):
		_check(selector.get_item_icon(index) != null, "launcher language option %d has a flag" % index)
	_check(selector.has_theme_icon_override("arrow"), "launcher language selector uses its custom chevron")
	_check(selector.has_theme_stylebox_override("normal"), "launcher language selector uses a custom surface")
	_check(
		selector.get_popup().has_theme_stylebox_override("panel")
		and selector.get_popup().has_theme_stylebox_override("hover"),
		"launcher language popup uses the matching visual style"
	)
	selector.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % message)
