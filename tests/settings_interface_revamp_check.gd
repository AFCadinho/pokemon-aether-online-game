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
	var layout := menu.find_child("BattleUILayoutOptions", true, false) as OptionButton
	var visuals := menu.find_child("BattlePresentationOptions", true, false) as OptionButton
	var camera_motion := menu.find_child("BattleCameraMotionToggle", true, false)
	if not OS.has_feature("mobile"):
		_check(layout != null and layout.item_count == 2 and layout.get_item_text(0) == "Full screen"
			and layout.get_item_text(1) == "Classic", "battle layout uses plain player-facing names")
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_check(visuals != null and visuals.item_count == 2 and visuals.get_item_text(0) == "2D / 2.5D — sprites"
			and visuals.get_item_text(1) == "3D — models", "battle visuals offer sprites or models")
		_check(camera_motion != null and tabs.get_child(2).is_ancestor_of(camera_motion),
			"camera movement belongs to Graphics, not General")
		var settings := root.get_node("SettingsManager")
		var old_layout: String = settings.battle_ui_layout
		var old_visuals: String = settings.battle_presentation_mode
		layout.item_selected.emit(1)
		_check(settings.battle_ui_layout == "classic", "Classic selection preserves existing layout contract")
		layout.item_selected.emit(0)
		_check(settings.battle_ui_layout == "immersive", "Full screen selects immersive implementation")
		visuals.item_selected.emit(1)
		_check(settings.battle_presentation_mode == "3d", "3D selects model presentation")
		visuals.item_selected.emit(0)
		_check(settings.battle_presentation_mode == "2.5d", "sprite choice selects existing sprite presentation")
		settings.set_battle_ui_layout(old_layout)
		settings.set_battle_presentation_mode(old_visuals)
		# Slot-local persisted legacy preference: it must not become a hidden
		# override after removing its UI. Asset paths must survive unchanged.
		var saved_text := FileAccess.get_file_as_string(settings.SETTINGS_PATH)
		var saved: Dictionary = JSON.parse_string(saved_text)
		var legacy := saved.duplicate(true)
		legacy["battle_3d_arena"] = "cave"
		var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy))
		file.close()
		settings.load_settings()
		_check(settings.battle_3d_arena == "auto", "legacy saved arena overrides return to automatic")
		_check(settings.battle_3d_catalog_path == saved.get("battle_3d_catalog_path", "")
			and settings.battle_3d_forest_manifest == saved.get("battle_3d_forest_manifest", ""),
			"removing pickers preserves installed model and forest paths")
		file = FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(saved_text)
		file.close()
		settings.load_settings()
	_check(menu.find_child("BattleArenaOptions", true, false) == null, "General no longer exposes development arena selection")
	var has_development_picker := false
	for button: Node in menu.find_children("*", "Button", true, false):
		has_development_picker = has_development_picker or "Choose local 3D" in button.text or "Choose trusted local forest" in button.text
	_check(not has_development_picker, "settings contain no development model/forest picker")

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
