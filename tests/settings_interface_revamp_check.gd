extends SceneTree

const SETTINGS_SCENE := "res://scenes/interface/settings/settings_menu.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SETTINGS_SCENE) as PackedScene
	_check(packed != null, "revamped settings scene loads")
	if packed == null:
		quit(1)
		return

	var menu := packed.instantiate() as Control
	root.add_child(menu)
	await process_frame

	var tabs := menu.find_child("SettingsTabs", true, false) as TabContainer
	var navigation := menu.find_child("SettingsNavigation", true, false) as VBoxContainer
	var footer := menu.find_child("SettingsFooter", true, false) as HBoxContainer
	var autosave := menu.find_child("AutosaveLabel", true, false) as Label
	var gameplay_title := menu.find_child("GeneralPageTitle", true, false) as Label
	var gameplay_toggle := menu.find_child("BattleAnimationsCheckBox", true, false) as CheckBox
	var language_options := menu.find_child("LanguageOptionsButton", true, false) as OptionButton
	var world_scale_options := menu.find_child("WorldPixelScaleOptionsButton", true, false) as OptionButton
	var account_portal := _find_button_with_text_key(menu, "ui.settings.account.portal")
	var exit_game := _find_button_with_text_key(menu, "ui.settings.account.exit_game")

	_check(menu.custom_minimum_size == Vector2(900, 680), "settings use the larger readable workspace")
	_check(tabs != null and tabs.get_tab_count() == 8, "all settings domains remain available")
	_check(
		gameplay_title != null
		and str(gameplay_title.get_meta("i18n_text_key", "")) == "ui.settings.tab.general"
		and not gameplay_title.text.is_empty(),
		"active pages have a clear localized heading"
	)
	_check(
		footer != null and autosave != null and not autosave.text.is_empty(),
		"settings disclose automatic saving in a persistent footer"
	)
	_check(
		navigation != null and navigation.find_child("NavigationSpacer", false, false) != null,
		"support and about are visually separated from primary settings"
	)
	_check(
		gameplay_toggle != null
		and gameplay_toggle.text.is_empty()
		and gameplay_toggle.focus_mode == Control.FOCUS_ALL,
		"gameplay preferences use keyboard-focusable compact toggles"
	)
	var first_gameplay_control := menu.call(
		"_find_first_focusable_control", tabs.get_child(0) if tabs != null else menu
	) as Control
	_check(
		first_gameplay_control == gameplay_toggle,
		"rightward navigation enters the first setting instead of the scroll container"
	)
	if gameplay_toggle != null:
		var toggle_icon := gameplay_toggle.get_theme_icon("checked")
		_check(
			toggle_icon != null and toggle_icon.get_size() == Vector2(44, 24),
			"toggle controls use a readable switch treatment"
		)
	_check(
		language_options != null and language_options.focus_mode == Control.FOCUS_ALL,
		"language selection participates in keyboard navigation"
	)
	_check(
		world_scale_options != null and world_scale_options.focus_mode == Control.FOCUS_ALL,
		"graphics selection participates in keyboard navigation"
	)
	_check(
		account_portal != null and account_portal.focus_mode == Control.FOCUS_ALL,
		"account actions participate in keyboard navigation"
	)
	var localization_manager := root.get_node_or_null("LocalizationManager")
	var original_locale := str(localization_manager.get("current_locale")) if localization_manager != null else "en"
	if localization_manager != null:
		localization_manager.call("set_locale", "nl")
		await process_frame
		_check(gameplay_title.text == "Gameplay", "revamped page headings update in Dutch")
		_check(
			autosave.text == "Wijzigingen worden automatisch opgeslagen",
			"revamped footer copy updates in Dutch"
		)
		localization_manager.call("set_locale", original_locale)
		await process_frame
	else:
		_check(false, "LocalizationManager is available for revamped settings copy")
	var fishing_row := menu.find_child("FishingBindingRow", true, false)
	var fishing_reset := menu.find_child("ResetFishingBindingButton", true, false)
	_check(
		fishing_row != null and fishing_reset != null and fishing_reset.get_parent() == fishing_row,
		"hotkey reset actions stay compact inside their binding row"
	)

	menu.call("open", "login")
	_check(exit_game != null and not exit_game.visible, "login settings hide the in-game exit action")
	menu.call("open", "game")
	_check(exit_game != null and exit_game.visible, "in-game settings expose Exit Game in the footer")

	menu.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _find_button_with_text_key(root_node: Node, key: String) -> Button:
	for candidate: Node in root_node.find_children("*", "Button", true, false):
		if str(candidate.get_meta("i18n_text_key", "")) == key:
			return candidate as Button
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
