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
	_check(manager.normalize_locale("zh-Hans") == "zh_CN", "Simplified Chinese locale normalization matches the game")
	_check(manager.normalize_locale("de-DE") == "en", "unsupported launcher locales fall back to English")
	_check(manager.get_http_locale("pt_BR") == "pt-BR", "launcher maps pt_BR to the HTTP locale")
	_check(manager.get_http_locale("zh_CN") == "zh-CN", "launcher maps zh_CN to the HTTP locale")
	manager.set_locale("zh_CN")
	_check(
		ThemeDB.fallback_font != null and ThemeDB.fallback_font.has_char("简".unicode_at(0)),
		"launcher activates the bundled Simplified Chinese font"
	)
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
		var last_check := launcher.find_child("LastCheckLabel", true, false) as Label
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
		_check(last_check != null and last_check.text == "Nooit", "launcher localizes an empty last-check value")
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
			not sanitized_path.contains(user_data_path) and sanitized_path.contains("<private_path>"),
			"launcher diagnostics redact local user storage paths"
		)
		launcher.set("install_dir", "/custom/private/game-folder")
		var sanitized_custom_install := str(launcher.call(
			"_sanitize_diagnostic_message",
			"install=/custom/private/game-folder/game/update.zip"
		))
		_check(
			not sanitized_custom_install.contains("/custom/private/game-folder")
			and sanitized_custom_install.contains("<private_path>"),
			"launcher diagnostics redact a custom install folder"
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
		var valid_manifest := {
			"game": {
				"url": "https://updates.example/game.zip",
				"sizeBytes": 10,
				"sha256": "ab".repeat(32),
			},
			"assetPacks": [{
				"id": "sprites",
				"url": "https://updates.example/assets/sprites.zip",
				"sizeBytes": 20,
				"sha256": "cd".repeat(32),
			}],
		}
		_check(str(launcher.call("_validate_download_manifest", valid_manifest)).is_empty(), "launcher accepts complete download integrity metadata")
		valid_manifest["assetPacks"][0]["sha256"] = ""
		_check(str(launcher.call("_validate_download_manifest", valid_manifest)).contains("SHA-256"), "launcher rejects asset packs without a checksum")
		_check(bool(launcher.call("_is_safe_archive_path", "assets/sprites/front.png")), "launcher accepts safe archive paths")
		_check(not bool(launcher.call("_is_safe_archive_path", "../outside.txt")), "launcher rejects archive path traversal")
		_check_transactional_game_install(launcher)
		_check(language_options != null, "launcher language selector exists")
		launcher.set("last_check_datetime", {
			"day": 16,
			"month": 8,
			"year": 2026,
			"hour": 14,
			"minute": 37,
		})
		manager.set_locale("en")
		var english_last_check := str(launcher.call("_get_last_check_display_text"))
		manager.set_locale("nl")
		var dutch_last_check := str(launcher.call("_get_last_check_display_text"))
		_check(
			english_last_check == "16-08-2026 14:37"
			and dutch_last_check == english_last_check,
			"changing launcher language preserves the last update-check timestamp"
		)
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
	_check(selector.item_count == 4, "launcher styled language selector lists every locale")
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


func _check_transactional_game_install(launcher: Node) -> void:
	var install_root := "user://launcher-transaction-test"
	launcher.set("install_dir", install_root)
	launcher.call("_remove_directory_tree", install_root)
	var executable := str(launcher.call("_get_default_game_executable_name"))
	launcher.set("manifest", {"game": {"executable": executable}})
	var target_dir := install_root.path_join("game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	_write_test_file(target_dir.path_join("old.txt"), "old")

	var staging_root := install_root.path_join(".launcher-staging/valid")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(staging_root))
	_write_test_file(staging_root.path_join(executable), "new")
	var install_error := int(launcher.call("_commit_staged_download", {"type": "game", "id": "game"}, staging_root))
	_check(install_error == OK, "launcher promotes a complete staged game")
	_check(FileAccess.file_exists(target_dir.path_join(executable)), "transactional install exposes the new game")
	_check(not FileAccess.file_exists(target_dir.path_join("old.txt")), "transactional install removes the replaced game only after promotion")

	var invalid_staging := install_root.path_join(".launcher-staging/invalid")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(invalid_staging))
	_write_test_file(invalid_staging.path_join("not-the-game.txt"), "invalid")
	var invalid_error := int(launcher.call("_commit_staged_download", {"type": "game", "id": "game"}, invalid_staging))
	_check(invalid_error != OK, "launcher rejects an incomplete staged game")
	_check(FileAccess.file_exists(target_dir.path_join(executable)), "failed staged install preserves the working game")

	var backup_dir := "%s.launcher-backup" % ProjectSettings.globalize_path(target_dir)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(target_dir), backup_dir)
	var recovery_staging := install_root.path_join(".launcher-staging/recovery")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery_staging))
	_write_test_file(recovery_staging.path_join(executable), "recovered-update")
	var recovery_error := int(launcher.call("_commit_staged_download", {"type": "game", "id": "game"}, recovery_staging))
	_check(recovery_error == OK, "launcher recovers an interrupted install transaction")
	_check(FileAccess.file_exists(target_dir.path_join(executable)), "transaction recovery leaves a working game")
	launcher.call("_remove_directory_tree", install_root)


func _write_test_file(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % message)
