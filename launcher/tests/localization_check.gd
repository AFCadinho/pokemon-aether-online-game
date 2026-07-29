extends SceneTree

const NewsLocalizationService := preload("res://scripts/news_localization_service.gd")

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

	var scene := load("res://scenes/launcher.tscn") as PackedScene
	_check(scene != null, "localized launcher scene loads")
	if scene != null:
		var launcher := scene.instantiate()
		manager.set_locale("nl")
		manager.localize_tree(launcher)
		var play := launcher.find_child("PlayButton", true, false) as Button
		var news_title := launcher.find_child("NewsTitle", true, false) as Label
		var language_options := launcher.find_child("LanguageOptionsButton", true, false) as OptionButton
		_check(play != null and play.text == "Spelen", "launcher action renders in Dutch")
		_check(
			news_title != null and news_title.text == "LAATSTE NIEUWS VAN AETHER",
			"launcher news heading renders in Dutch"
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


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % message)
