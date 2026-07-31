extends PanelContainer

signal closed

const ExternalLinks = preload("res://scripts/core/external_links.gd")
const LanguageSelectorStyle := preload("res://scripts/ui/language_selector_style.gd")
const SPRITE_STYLE_BY_OPTION_ID: Dictionary = {
	0: "animated",
	1: "static",
	2: "pixel",
}
const OPTION_ID_BY_SPRITE_STYLE: Dictionary = {
	"animated": 0,
	"static": 1,
	"pixel": 2,
}
const GEN5_SPRITE_MISSING_KEY := "ui.settings.sprite.not_installed"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const LOADING_SCENE_PATH := "res://scenes/interface/loading_screen.tscn"
const MINIMUM_MENU_SIZE := Vector2(700, 540)
const NAVIGATION_WIDTH := 168.0
const UI_BG := Color("#07111ff7")
const UI_SLOT_BG := Color("#0d1c30eb")
const UI_INPUT_BG := Color("#050d1aed")
const UI_BORDER := Color("#7aa7f4")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f1f5fb")
const UI_MUTED_TEXT := Color("#aebbc9")
const UI_SECTION_TEXT := Color("#b980ff")
const UI_PURPLE_HOVER := Color("#b980ff")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")
const ACCOUNT_DIALOG_STATUS_HEIGHT := 30.0
const PRIVACY_DIALOG_STATUS_HEIGHT := 38.0
const LOGOUT_CONFIRM_SIZE := Vector2(360, 154)
const LOGOUT_CONFIRM_Z_INDEX := 2200

@onready var settings_layout: VBoxContainer = $MarginContainer/VBoxContainer
@onready var battle_animations_check_box: CheckBox = $MarginContainer/VBoxContainer/BattleAnimationsCheckBox
@onready var weather_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/WeatherEffectsCheckBox
@onready var terrain_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/TerrainEffectsCheckBox
var display_own_name_check_box: CheckBox
var hide_other_players_check_box: CheckBox
var language_label: Label
var language_options_button: OptionButton
var terminology_label: Label
var terminology_options_button: OptionButton
var terminology_hint_label: Label
@onready var sprite_style_options_button: OptionButton = $MarginContainer/VBoxContainer/SpriteStyleOptionsButton
@onready var sprite_style_status_label: Label = $MarginContainer/VBoxContainer/SpriteStyleStatusLabel
@onready var fullscreen_check_box: CheckBox = $MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var resolution_options_button: OptionButton = $MarginContainer/VBoxContainer/ResolutionOptionsButton
@onready var master_volume_slider: HSlider = $MarginContainer/VBoxContainer/MasterVolumeRow/MasterVolumeSlider
@onready var master_volume_value_label: Label = $MarginContainer/VBoxContainer/MasterVolumeRow/MasterVolumeValueLabel
@onready var music_volume_slider: HSlider = $MarginContainer/VBoxContainer/MusicVolumeRow/MusicVolumeSlider
@onready var music_volume_value_label: Label = $MarginContainer/VBoxContainer/MusicVolumeRow/MusicVolumeValueLabel
@onready var battle_music_options_button: OptionButton = $MarginContainer/VBoxContainer/BattleMusicOptionsButton
@onready var sfx_volume_slider: HSlider = $MarginContainer/VBoxContainer/SfxVolumeRow/SfxVolumeSlider
@onready var sfx_volume_value_label: Label = $MarginContainer/VBoxContainer/SfxVolumeRow/SfxVolumeValueLabel
@onready var pokemon_cry_volume_slider: HSlider = $MarginContainer/VBoxContainer/PokemonCryVolumeRow/PokemonCryVolumeSlider
@onready var pokemon_cry_volume_value_label: Label = $MarginContainer/VBoxContainer/PokemonCryVolumeRow/PokemonCryVolumeValueLabel
@onready var ui_volume_slider: HSlider = $MarginContainer/VBoxContainer/UiVolumeRow/UiVolumeSlider
@onready var ui_volume_value_label: Label = $MarginContainer/VBoxContainer/UiVolumeRow/UiVolumeValueLabel
@onready var notification_volume_slider: HSlider = $MarginContainer/VBoxContainer/NotificationVolumeRow/NotificationVolumeSlider
@onready var notification_volume_value_label: Label = $MarginContainer/VBoxContainer/NotificationVolumeRow/NotificationVolumeValueLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/Header/CloseButton

var loading_controls := false
var logging_out := false
var logout_confirmation_requested := false
var tab_container: TabContainer
var settings_workspace: HBoxContainer
var settings_navigation: VBoxContainer
var settings_navigation_panel: PanelContainer
var settings_navigation_buttons: Array[Button] = []
var account_tab_root: Control
var account_user_label: Label
var account_status_label: Label
var edit_account_button: Button
var logout_button: Button
var exit_game_button: Button
var credits_button: Button
var credits_status_label: Label
var about_version_label: Label
var logout_confirm_dialog: PanelContainer
var logout_confirm_return_button: Button
var logout_confirm_cancel_button: Button
var logout_confirm_title_label: Label
var logout_confirm_message_label: Label
var account_return_note_label: Label
var account_details_dialog: PanelContainer
var account_details_panel: PanelContainer
var account_dialog_status_label: Label
var account_confirm_button: Button
var account_cancel_button: Button
var account_display_name_input: LineEdit
var account_current_password_input: LineEdit
var account_new_password_input: LineEdit
var account_confirm_password_input: LineEdit
var privacy_export_button: Button
var delete_account_button: Button
var privacy_dialog: PanelContainer
var privacy_dialog_title_label: Label
var privacy_dialog_message_label: Label
var privacy_password_input: LineEdit
var privacy_delete_confirmation_input: LineEdit
var privacy_dialog_status_label: Label
var privacy_open_folder_button: Button
var privacy_confirm_button: Button
var privacy_cancel_button: Button
var privacy_action := ""
var privacy_action_busy := false
var privacy_last_export_path := ""
var account_status_key := ""
var account_status_values: Dictionary = {}
var account_status_is_error := false
var account_dialog_status_key := ""
var account_dialog_status_values: Dictionary = {}
var account_dialog_status_is_error := false


func _ready() -> void:
	custom_minimum_size = MINIMUM_MENU_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_tabs()
	_setup_logout_confirm_dialog()
	_apply_premium_styles()
	LanguageSelectorStyle.configure(language_options_button)
	LanguageSelectorStyle.configure(terminology_options_button)
	battle_animations_check_box.toggled.connect(_on_battle_animations_toggled)
	weather_effects_check_box.toggled.connect(_on_weather_effects_toggled)
	terrain_effects_check_box.toggled.connect(_on_terrain_effects_toggled)
	display_own_name_check_box.toggled.connect(_on_display_own_name_toggled)
	hide_other_players_check_box.toggled.connect(_on_hide_other_players_toggled)
	sprite_style_options_button.item_selected.connect(_on_sprite_style_selected)
	fullscreen_check_box.toggled.connect(_on_fullscreen_toggled)
	resolution_options_button.item_selected.connect(_on_resolution_selected)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	battle_music_options_button.item_selected.connect(_on_battle_music_selected)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	pokemon_cry_volume_slider.value_changed.connect(_on_pokemon_cry_volume_changed)
	ui_volume_slider.value_changed.connect(_on_ui_volume_changed)
	notification_volume_slider.value_changed.connect(_on_notification_volume_changed)
	language_options_button.item_selected.connect(_on_language_selected)
	terminology_options_button.item_selected.connect(_on_terminology_selected)
	edit_account_button.pressed.connect(_on_edit_account_button_pressed)
	privacy_export_button.pressed.connect(_on_privacy_export_button_pressed)
	delete_account_button.pressed.connect(_on_delete_account_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	exit_game_button.pressed.connect(_on_exit_game_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	close_button.pressed.connect(close)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_settings_to_controls()
	_refresh_localized_content()
	visible = false


func open(context: String = "game") -> void:
	_apply_settings_to_controls()
	_apply_context(context)
	_refresh_impersonation_account_controls()
	visible = true
	_focus_active_navigation_button()


func show_impersonation_return_confirmation() -> void:
	if not AuthService.is_impersonating():
		return
	open("game")
	if tab_container != null and account_tab_root != null:
		tab_container.current_tab = account_tab_root.get_index()
		_refresh_navigation_state()
	_show_logout_confirm_dialog()


func close() -> void:
	if account_details_dialog != null:
		_hide_account_details_dialog()
	if privacy_dialog != null:
		_hide_privacy_dialog()
	logout_confirmation_requested = false
	if logout_confirm_dialog != null:
		_hide_logout_confirm_dialog()
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return

	if privacy_dialog != null and privacy_dialog.visible:
		_hide_privacy_dialog()
	elif account_details_dialog != null and account_details_dialog.visible:
		_hide_account_details_dialog()
	elif logout_confirm_dialog != null and logout_confirm_dialog.visible:
		_hide_logout_confirm_dialog()
	else:
		close()
	get_viewport().set_input_as_handled()


func _apply_settings_to_controls() -> void:
	loading_controls = true
	battle_animations_check_box.button_pressed = SettingsManager.battle_animations
	weather_effects_check_box.button_pressed = SettingsManager.weather_effects
	terrain_effects_check_box.button_pressed = SettingsManager.terrain_effects
	display_own_name_check_box.button_pressed = SettingsManager.display_own_name
	hide_other_players_check_box.button_pressed = SettingsManager.hide_other_players
	_apply_language_options_to_control()
	_apply_terminology_options_to_control()

	var option_id: int = int(OPTION_ID_BY_SPRITE_STYLE.get(SettingsManager.sprite_style, 0))
	_apply_sprite_style_option_labels()
	var option_index: int = sprite_style_options_button.get_item_index(option_id)
	if option_index >= 0:
		sprite_style_options_button.select(option_index)
	_update_sprite_style_status_label("")

	fullscreen_check_box.button_pressed = SettingsManager.fullscreen
	_apply_resolution_options_to_control()
	resolution_options_button.disabled = SettingsManager.fullscreen

	_set_volume_control(master_volume_slider, master_volume_value_label, SettingsManager.master_volume)
	_set_volume_control(music_volume_slider, music_volume_value_label, SettingsManager.music_volume)
	_apply_battle_music_options_to_control()
	_set_volume_control(sfx_volume_slider, sfx_volume_value_label, SettingsManager.sfx_volume)
	_set_volume_control(pokemon_cry_volume_slider, pokemon_cry_volume_value_label, SettingsManager.pokemon_cry_volume)
	_set_volume_control(ui_volume_slider, ui_volume_value_label, SettingsManager.ui_volume)
	_set_volume_control(notification_volume_slider, notification_volume_value_label, SettingsManager.notification_volume)

	loading_controls = false


func _setup_tabs() -> void:
	if tab_container != null:
		return

	tab_container = TabContainer.new()
	tab_container.name = "SettingsTabs"
	tab_container.tabs_visible = false
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(_on_settings_tab_changed)

	settings_workspace = HBoxContainer.new()
	settings_workspace.name = "SettingsWorkspace"
	settings_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_workspace.add_theme_constant_override("separation", 14)
	settings_layout.add_child(settings_workspace)
	settings_layout.move_child(settings_workspace, 1)

	settings_navigation_panel = PanelContainer.new()
	settings_navigation_panel.name = "SettingsNavigationPanel"
	settings_navigation_panel.custom_minimum_size.x = NAVIGATION_WIDTH
	settings_navigation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_workspace.add_child(settings_navigation_panel)

	var navigation_margin := MarginContainer.new()
	navigation_margin.add_theme_constant_override("margin_left", 10)
	navigation_margin.add_theme_constant_override("margin_top", 12)
	navigation_margin.add_theme_constant_override("margin_right", 10)
	navigation_margin.add_theme_constant_override("margin_bottom", 12)
	settings_navigation_panel.add_child(navigation_margin)

	settings_navigation = VBoxContainer.new()
	settings_navigation.name = "SettingsNavigation"
	settings_navigation.add_theme_constant_override("separation", 7)
	navigation_margin.add_child(settings_navigation)

	var content_panel := PanelContainer.new()
	content_panel.name = "SettingsContentPanel"
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color("#081522e8"), Color("#315070cc"), 12, 1)
	)
	settings_workspace.add_child(content_panel)
	content_panel.add_child(tab_container)

	var general_tab: VBoxContainer = _create_tab_content("General", "ui.settings.tab.general")
	var language_tab: VBoxContainer = _create_tab_content("Language", "ui.settings.tab.language")
	var graphics_tab: VBoxContainer = _create_tab_content("Graphics", "ui.settings.tab.graphics")
	var sound_tab: VBoxContainer = _create_tab_content("Sound", "ui.settings.tab.sound")
	var account_tab: VBoxContainer = _create_tab_content("Account", "ui.settings.tab.account")
	var about_tab: VBoxContainer = _create_tab_content("About", "ui.settings.tab.about")
	account_tab_root = account_tab.get_parent().get_parent() as Control
	_build_navigation()

	language_label = Label.new()
	_set_localized_text(language_label, "ui.settings.language")
	language_options_button = OptionButton.new()
	language_options_button.name = "LanguageOptionsButton"
	language_options_button.focus_mode = Control.FOCUS_NONE
	terminology_label = Label.new()
	_set_localized_text(terminology_label, "ui.settings.terminology")
	terminology_options_button = OptionButton.new()
	terminology_options_button.name = "TerminologyOptionsButton"
	terminology_options_button.focus_mode = Control.FOCUS_NONE
	terminology_hint_label = Label.new()
	terminology_hint_label.name = "TerminologyHintLabel"
	terminology_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_localized_text(terminology_hint_label, "ui.settings.terminology_hint")
	_move_nodes_to_container(general_tab, [
		battle_animations_check_box,
		weather_effects_check_box,
		terrain_effects_check_box,
		_create_display_own_name_check_box(),
		_create_hide_other_players_check_box(),
	])
	_wrap_settings_section(
		general_tab,
		"ui.settings.section.gameplay",
		"ui.settings.section.gameplay_subtitle",
		general_tab.get_children()
	)
	_move_nodes_to_container(language_tab, [
		language_label,
		language_options_button,
		terminology_label,
		terminology_options_button,
		terminology_hint_label,
	])
	_wrap_settings_section(
		language_tab,
		"ui.settings.section.language",
		"ui.settings.section.language_subtitle",
		language_tab.get_children()
	)
	_move_nodes_to_container(graphics_tab, [
		sprite_style_options_button.get_node("../SpriteStyleLabel"),
		sprite_style_options_button,
		sprite_style_status_label,
		fullscreen_check_box.get_node("../DisplayLabel"),
		fullscreen_check_box,
		resolution_options_button.get_node("../ResolutionLabel"),
		resolution_options_button,
	])
	_wrap_settings_section(graphics_tab, "ui.settings.section.sprites", "ui.settings.section.sprites_subtitle", [
		sprite_style_options_button.get_node("../SpriteStyleLabel"),
		sprite_style_options_button,
		sprite_style_status_label,
	])
	_wrap_settings_section(graphics_tab, "ui.settings.section.display", "ui.settings.section.display_subtitle", [
		fullscreen_check_box.get_node("../DisplayLabel"),
		fullscreen_check_box,
		resolution_options_button.get_node("../ResolutionLabel"),
		resolution_options_button,
	])
	_move_nodes_to_container(sound_tab, [
		master_volume_slider.get_node("../../AudioLabel"),
		master_volume_slider.get_node(".."),
		music_volume_slider.get_node(".."),
		battle_music_options_button.get_node("../BattleMusicLabel"),
		battle_music_options_button,
		sfx_volume_slider.get_node(".."),
		pokemon_cry_volume_slider.get_node(".."),
		ui_volume_slider.get_node(".."),
		notification_volume_slider.get_node(".."),
	])
	_wrap_settings_section(
		sound_tab,
		"ui.settings.section.audio_mix",
		"ui.settings.section.audio_mix_subtitle",
		sound_tab.get_children()
	)
	_build_account_tab(account_tab)
	_build_about_tab(about_tab)


func _apply_context(context: String) -> void:
	var show_account_tab := context != "login"
	if account_tab_root != null:
		account_tab_root.visible = show_account_tab
		var account_tab_index: int = account_tab_root.get_index()
		if tab_container != null and tab_container.has_method("set_tab_hidden"):
			tab_container.call("set_tab_hidden", account_tab_index, not show_account_tab)
		if account_tab_index >= 0 and account_tab_index < settings_navigation_buttons.size():
			settings_navigation_buttons[account_tab_index].visible = show_account_tab

	if show_account_tab:
		_refresh_account_tab()
		_refresh_navigation_state()
		return

	if tab_container != null:
		tab_container.current_tab = 0
	_refresh_navigation_state()


func _build_navigation() -> void:
	if settings_navigation == null or tab_container == null:
		return

	for index: int in range(tab_container.get_tab_count()):
		var tab_root := tab_container.get_child(index)
		var button := Button.new()
		button.name = "%sNavigationButton" % str(tab_root.name)
		button.custom_minimum_size = Vector2(NAVIGATION_WIDTH - 20.0, 42.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("settings_tab_index", index)
		if tab_root.has_meta("i18n_tab_key"):
			_set_localized_text(button, str(tab_root.get_meta("i18n_tab_key")))
		button.pressed.connect(_on_navigation_button_pressed.bind(index))
		settings_navigation.add_child(button)
		settings_navigation_buttons.append(button)
	_refresh_navigation_state()


func _on_navigation_button_pressed(tab_index: int) -> void:
	if tab_container == null:
		return
	tab_container.current_tab = tab_index
	_refresh_navigation_state()


func _on_settings_tab_changed(_tab_index: int) -> void:
	_refresh_navigation_state()


func _refresh_navigation_state() -> void:
	if tab_container == null:
		return
	for index: int in range(settings_navigation_buttons.size()):
		var button := settings_navigation_buttons[index]
		_apply_navigation_button_style(button, index == tab_container.current_tab)


func _focus_active_navigation_button() -> void:
	if tab_container == null:
		close_button.grab_focus()
		return
	var active_index := tab_container.current_tab
	if active_index >= 0 and active_index < settings_navigation_buttons.size():
		var button := settings_navigation_buttons[active_index]
		if button.visible:
			button.grab_focus()
			return
	close_button.grab_focus()


func _create_tab_content(tab_name: String, translation_key: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.set_meta("i18n_tab_key", translation_key)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_vertical_custom_step = 32.0
	scroll.follow_focus = true
	tab_container.add_child(scroll)
	tab_container.set_tab_title(scroll.get_index(), LocalizationManager.text(translation_key))

	var margin := MarginContainer.new()
	margin.name = "%sMargin" % tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "%sContent" % tab_name
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	return content


func _move_nodes_to_container(container: VBoxContainer, nodes: Array) -> void:
	for node_value: Variant in nodes:
		var node := node_value as Node
		if node == null:
			continue
		var current_parent := node.get_parent()
		if current_parent != null:
			current_parent.remove_child(node)
		container.add_child(node)


func _wrap_settings_section(container: VBoxContainer, title_key: String, subtitle_key: String, nodes: Array) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, UI_BORDER_SOFT, 10, 1))
	container.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	var title := Label.new()
	_set_localized_text(title, title_key, true)
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UI_SECTION_TEXT)
	stack.add_child(title)

	var subtitle := Label.new()
	_set_localized_text(subtitle, subtitle_key)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	stack.add_child(subtitle)

	for node_value: Variant in nodes.duplicate():
		var node := node_value as Node
		if node == null or node == card:
			continue
		var current_parent := node.get_parent()
		if current_parent != null:
			current_parent.remove_child(node)
		stack.add_child(node)


func _build_account_tab(account_tab: VBoxContainer) -> void:
	var account_label := Label.new()
	_set_localized_text(account_label, "ui.settings.tab.account")
	account_tab.add_child(account_label)

	account_user_label = Label.new()
	account_user_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_tab.add_child(account_user_label)

	edit_account_button = Button.new()
	_set_localized_text(edit_account_button, "ui.settings.account.edit")
	edit_account_button.focus_mode = Control.FOCUS_NONE
	account_tab.add_child(edit_account_button)

	_setup_account_details_dialog()
	account_tab.add_child(account_details_dialog)

	account_status_label = Label.new()
	account_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_status_label.add_theme_font_size_override("font_size", 12)
	account_status_label.visible = false
	account_tab.add_child(account_status_label)

	var privacy_label := Label.new()
	_set_localized_text(privacy_label, "ui.settings.privacy.title")
	privacy_label.add_theme_color_override("font_color", UI_SECTION_TEXT)
	privacy_label.add_theme_font_size_override("font_size", 14)
	account_tab.add_child(privacy_label)

	var privacy_note := Label.new()
	_set_localized_text(privacy_note, "ui.settings.privacy.note")
	privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy_note.add_theme_font_size_override("font_size", 12)
	account_tab.add_child(privacy_note)

	privacy_export_button = Button.new()
	_set_localized_text(privacy_export_button, "ui.settings.privacy.export")
	privacy_export_button.focus_mode = Control.FOCUS_NONE
	account_tab.add_child(privacy_export_button)

	delete_account_button = Button.new()
	_set_localized_text(delete_account_button, "ui.settings.privacy.delete")
	delete_account_button.focus_mode = Control.FOCUS_NONE
	account_tab.add_child(delete_account_button)

	_setup_privacy_dialog()
	account_tab.add_child(privacy_dialog)

	account_return_note_label = Label.new()
	_set_localized_text(account_return_note_label, "ui.settings.account.return_note")
	account_return_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_return_note_label.add_theme_font_size_override("font_size", 12)
	account_tab.add_child(account_return_note_label)

	logout_button = Button.new()
	_set_localized_text(logout_button, "ui.settings.account.return_login")
	logout_button.focus_mode = Control.FOCUS_NONE
	account_tab.add_child(logout_button)

	exit_game_button = Button.new()
	_set_localized_text(exit_game_button, "ui.settings.account.exit_game")
	exit_game_button.focus_mode = Control.FOCUS_NONE
	account_tab.add_child(exit_game_button)


func _build_about_tab(about_tab: VBoxContainer) -> void:
	var about_label := Label.new()
	about_label.text = "PokeAether"
	about_label.add_theme_font_size_override("font_size", 20)
	about_tab.add_child(about_label)

	about_version_label = Label.new()
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	about_version_label.set_meta("version", version)
	_update_about_version_label()
	about_tab.add_child(about_version_label)

	var description_label := Label.new()
	_set_localized_text(description_label, "ui.settings.about.description")
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	about_tab.add_child(description_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	about_tab.add_child(spacer)

	credits_button = Button.new()
	_set_localized_text(credits_button, "ui.settings.about.credits")
	credits_button.focus_mode = Control.FOCUS_ALL
	about_tab.add_child(credits_button)

	credits_status_label = Label.new()
	credits_status_label.visible = false
	credits_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_status_label.add_theme_font_size_override("font_size", 12)
	about_tab.add_child(credits_status_label)

	var legal_note := Label.new()
	_set_localized_text(legal_note, "ui.settings.about.legal")
	legal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legal_note.add_theme_font_size_override("font_size", 12)
	about_tab.add_child(legal_note)


func _create_display_own_name_check_box() -> CheckBox:
	display_own_name_check_box = CheckBox.new()
	_set_localized_text(display_own_name_check_box, "ui.settings.display_own_name")
	display_own_name_check_box.focus_mode = Control.FOCUS_NONE
	return display_own_name_check_box


func _create_hide_other_players_check_box() -> CheckBox:
	hide_other_players_check_box = CheckBox.new()
	_set_localized_text(hide_other_players_check_box, "ui.settings.hide_other_players")
	hide_other_players_check_box.focus_mode = Control.FOCUS_NONE
	return hide_other_players_check_box


func _setup_logout_confirm_dialog() -> void:
	logout_confirm_dialog = PanelContainer.new()
	logout_confirm_dialog.name = "LogoutConfirmPopup"
	logout_confirm_dialog.visible = false
	logout_confirm_dialog.top_level = true
	logout_confirm_dialog.z_as_relative = false
	logout_confirm_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	logout_confirm_dialog.z_index = LOGOUT_CONFIRM_Z_INDEX
	logout_confirm_dialog.custom_minimum_size = LOGOUT_CONFIRM_SIZE
	logout_confirm_dialog.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(logout_confirm_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	logout_confirm_dialog.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	stack.add_child(header)

	logout_confirm_title_label = Label.new()
	_set_localized_text(logout_confirm_title_label, "ui.settings.account.return_login")
	logout_confirm_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logout_confirm_title_label.add_theme_font_size_override("font_size", 17)
	logout_confirm_title_label.add_theme_color_override("font_color", UI_SECTION_TEXT)
	header.add_child(logout_confirm_title_label)

	var close_dialog_button := Button.new()
	close_dialog_button.text = "X"
	close_dialog_button.custom_minimum_size = Vector2(32, 28)
	close_dialog_button.focus_mode = Control.FOCUS_NONE
	close_dialog_button.pressed.connect(_hide_logout_confirm_dialog)
	header.add_child(close_dialog_button)

	logout_confirm_message_label = Label.new()
	_set_localized_text(logout_confirm_message_label, "ui.settings.logout.message")
	logout_confirm_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logout_confirm_message_label.add_theme_font_size_override("font_size", 14)
	logout_confirm_message_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(logout_confirm_message_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)
	stack.add_child(button_row)

	logout_confirm_cancel_button = Button.new()
	_set_localized_text(logout_confirm_cancel_button, "common.cancel")
	logout_confirm_cancel_button.custom_minimum_size = Vector2(104, 32)
	logout_confirm_cancel_button.focus_mode = Control.FOCUS_NONE
	logout_confirm_cancel_button.pressed.connect(_hide_logout_confirm_dialog)
	button_row.add_child(logout_confirm_cancel_button)

	logout_confirm_return_button = Button.new()
	_set_localized_text(logout_confirm_return_button, "common.return")
	logout_confirm_return_button.custom_minimum_size = Vector2(112, 32)
	logout_confirm_return_button.focus_mode = Control.FOCUS_NONE
	logout_confirm_return_button.pressed.connect(_logout_confirmed)
	button_row.add_child(logout_confirm_return_button)


func _setup_account_details_dialog() -> void:
	account_details_dialog = PanelContainer.new()
	account_details_dialog.name = "AccountDetailsPopup"
	account_details_dialog.visible = false
	account_details_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	account_details_dialog.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	account_details_panel = account_details_dialog

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	account_details_dialog.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)

	var title_label := Label.new()
	_set_localized_text(title_label, "ui.settings.account.edit")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 16)
	title_row.add_child(title_label)

	var close_dialog_button := Button.new()
	close_dialog_button.text = "X"
	close_dialog_button.custom_minimum_size = Vector2(30, 28)
	close_dialog_button.pressed.connect(_hide_account_details_dialog)
	title_row.add_child(close_dialog_button)

	var display_hint := Label.new()
	_set_localized_text(display_hint, "ui.settings.account.display_hint")
	display_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	display_hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(display_hint)

	account_display_name_input = _create_account_line_edit("ui.settings.account.display_name", false)
	layout.add_child(account_display_name_input)

	var password_hint := Label.new()
	_set_localized_text(password_hint, "ui.settings.account.password_hint")
	password_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	password_hint.add_theme_font_size_override("font_size", 11)
	layout.add_child(password_hint)

	account_current_password_input = _create_account_line_edit("ui.settings.account.current_password", true)
	layout.add_child(account_current_password_input)

	account_new_password_input = _create_account_line_edit("ui.settings.account.new_password", true)
	layout.add_child(account_new_password_input)

	account_confirm_password_input = _create_account_line_edit("ui.settings.account.confirm_password", true)
	layout.add_child(account_confirm_password_input)

	account_dialog_status_label = Label.new()
	account_dialog_status_label.custom_minimum_size = Vector2(0, ACCOUNT_DIALOG_STATUS_HEIGHT)
	account_dialog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_dialog_status_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(account_dialog_status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)

	var button_spacer := Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(button_spacer)

	account_cancel_button = Button.new()
	_set_localized_text(account_cancel_button, "common.cancel")
	account_cancel_button.custom_minimum_size = Vector2(92, 32)
	account_cancel_button.pressed.connect(_hide_account_details_dialog)
	button_row.add_child(account_cancel_button)

	account_confirm_button = Button.new()
	_set_localized_text(account_confirm_button, "common.confirm")
	account_confirm_button.custom_minimum_size = Vector2(104, 32)
	account_confirm_button.pressed.connect(_account_details_confirmed)
	button_row.add_child(account_confirm_button)


func _setup_privacy_dialog() -> void:
	privacy_dialog = PanelContainer.new()
	privacy_dialog.name = "PrivacyActionPopup"
	privacy_dialog.visible = false
	privacy_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	privacy_dialog.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	privacy_dialog.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)

	privacy_dialog_title_label = Label.new()
	privacy_dialog_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	privacy_dialog_title_label.add_theme_font_size_override("font_size", 16)
	title_row.add_child(privacy_dialog_title_label)

	var close_dialog_button := Button.new()
	close_dialog_button.text = "X"
	close_dialog_button.custom_minimum_size = Vector2(30, 28)
	close_dialog_button.pressed.connect(_hide_privacy_dialog)
	title_row.add_child(close_dialog_button)

	privacy_dialog_message_label = Label.new()
	privacy_dialog_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy_dialog_message_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(privacy_dialog_message_label)

	privacy_password_input = _create_account_line_edit("ui.settings.account.current_password", true)
	layout.add_child(privacy_password_input)

	privacy_delete_confirmation_input = _create_account_line_edit("ui.settings.privacy.delete_confirmation", false)
	privacy_delete_confirmation_input.visible = false
	layout.add_child(privacy_delete_confirmation_input)

	privacy_dialog_status_label = Label.new()
	privacy_dialog_status_label.custom_minimum_size = Vector2(0, PRIVACY_DIALOG_STATUS_HEIGHT)
	privacy_dialog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy_dialog_status_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(privacy_dialog_status_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)

	privacy_open_folder_button = Button.new()
	_set_localized_text(privacy_open_folder_button, "ui.settings.privacy.open_folder")
	privacy_open_folder_button.custom_minimum_size = Vector2(112, 32)
	privacy_open_folder_button.visible = false
	privacy_open_folder_button.pressed.connect(_on_privacy_open_folder_pressed)
	button_row.add_child(privacy_open_folder_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	privacy_cancel_button = Button.new()
	_set_localized_text(privacy_cancel_button, "common.cancel")
	privacy_cancel_button.custom_minimum_size = Vector2(92, 32)
	privacy_cancel_button.pressed.connect(_hide_privacy_dialog)
	button_row.add_child(privacy_cancel_button)

	privacy_confirm_button = Button.new()
	_set_localized_text(privacy_confirm_button, "common.confirm")
	privacy_confirm_button.custom_minimum_size = Vector2(104, 32)
	privacy_confirm_button.pressed.connect(_privacy_action_confirmed)
	button_row.add_child(privacy_confirm_button)


func _create_account_line_edit(placeholder_key: String, secret: bool) -> LineEdit:
	var input := LineEdit.new()
	_set_localized_placeholder(input, placeholder_key)
	input.custom_minimum_size = Vector2(300, 32)
	input.secret = secret
	input.clear_button_enabled = true
	return input


func _set_localized_text(control: Control, key: String, uppercase: bool = false) -> void:
	control.set_meta("i18n_text_key", key)
	control.set_meta("i18n_text_uppercase", uppercase)
	var translated := LocalizationManager.text(key)
	control.set("text", translated.to_upper() if uppercase else translated)


func _set_localized_placeholder(input: LineEdit, key: String) -> void:
	input.set_meta("i18n_placeholder_key", key)
	input.placeholder_text = LocalizationManager.text(key)


func _refresh_localized_controls(node: Node) -> void:
	if node is Control and node.has_meta("i18n_text_key"):
		var key := str(node.get_meta("i18n_text_key"))
		var translated := LocalizationManager.text(key)
		if bool(node.get_meta("i18n_text_uppercase", false)):
			translated = translated.to_upper()
		node.set("text", translated)
	if node is LineEdit and node.has_meta("i18n_placeholder_key"):
		(node as LineEdit).placeholder_text = LocalizationManager.text(
			str(node.get_meta("i18n_placeholder_key"))
		)
	for child: Node in node.get_children():
		_refresh_localized_controls(child)


func _refresh_tab_titles() -> void:
	if tab_container == null:
		return
	for index: int in range(tab_container.get_tab_count()):
		var tab_root := tab_container.get_child(index)
		if tab_root != null and tab_root.has_meta("i18n_tab_key"):
			tab_container.set_tab_title(
				index,
				LocalizationManager.text(str(tab_root.get_meta("i18n_tab_key")))
			)


func _refresh_localized_content() -> void:
	LocalizationManager.localize_tree(self)
	_refresh_localized_controls(self)
	_refresh_tab_titles()
	_refresh_navigation_state()
	_update_about_version_label()
	_apply_sprite_style_option_labels()
	_apply_language_options_to_control()
	_apply_terminology_options_to_control()
	_update_sprite_style_status_label("")
	_refresh_impersonation_account_controls()
	if account_user_label != null and account_tab_root != null and account_tab_root.visible:
		_refresh_account_tab()
	if not account_status_key.is_empty():
		_set_account_status_key(account_status_key, account_status_values, account_status_is_error)
	if not account_dialog_status_key.is_empty():
		_set_account_dialog_status_key(
			account_dialog_status_key,
			account_dialog_status_values,
			account_dialog_status_is_error
		)
	if privacy_dialog != null and privacy_dialog.visible:
		_refresh_privacy_dialog_copy()


func _update_about_version_label() -> void:
	if about_version_label == null:
		return
	var version := str(about_version_label.get_meta("version", "")).strip_edges()
	about_version_label.text = (
		LocalizationManager.text("ui.settings.about.version", {"version": version})
		if version != "" and version != "dev"
		else LocalizationManager.text("ui.settings.about.alpha_build")
	)


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_content()


func _apply_premium_styles() -> void:
	add_theme_stylebox_override("panel", _make_glass_panel_style(14, 1))
	if settings_navigation_panel != null:
		settings_navigation_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(Color("#091727e8"), Color("#315070cc"), 12, 1)
		)
	if tab_container != null:
		tab_container.add_theme_constant_override("tab_separation", 4)
		tab_container.add_theme_constant_override("side_margin", 4)
		tab_container.add_theme_stylebox_override("panel", _make_panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
		tab_container.add_theme_stylebox_override("tab_selected", _make_button_style(Color("#1b2c4eee"), UI_BORDER, 8, 1))
		tab_container.add_theme_stylebox_override("tab_hovered", _make_button_style(Color("#203966f2"), UI_BORDER_FOCUS, 8, 1))
		tab_container.add_theme_stylebox_override("tab_unselected", _make_button_style(UI_SLOT_BG, UI_BORDER_SOFT, 8, 1))
		tab_container.add_theme_color_override("font_selected_color", UI_TEXT)
		tab_container.add_theme_color_override("font_unselected_color", UI_MUTED_TEXT)
		tab_container.add_theme_color_override("font_hovered_color", UI_TEXT)

	_apply_styles_recursive(self)
	for slider: HSlider in [
		master_volume_slider,
		music_volume_slider,
		sfx_volume_slider,
		pokemon_cry_volume_slider,
		ui_volume_slider,
		notification_volume_slider,
	]:
		_apply_slider_style(slider)
	if logout_button != null:
		_apply_button_style(logout_button)
	if exit_game_button != null:
		_apply_button_style(exit_game_button, "danger")
	if delete_account_button != null:
		_apply_button_style(delete_account_button, "danger")
	_apply_button_style(close_button)
	_apply_account_dialog_style()
	_apply_privacy_dialog_style()
	_apply_logout_confirm_dialog_style()
	_refresh_navigation_state()


func _apply_styles_recursive(node: Node) -> void:
	if node is Label:
		_apply_label_style(node as Label)
	elif node is CheckBox:
		_apply_checkbox_style(node as CheckBox)
	elif node is HSlider:
		_apply_slider_style(node as HSlider)
	elif node is OptionButton:
		_apply_button_style(node as Button)
	elif node is Button:
		_apply_button_style(node as Button)

	for child_node: Node in node.get_children():
		_apply_styles_recursive(child_node)


func _apply_label_style(label: Label) -> void:
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	if label.name == "TitleLabel":
		label.add_theme_color_override("font_color", UI_TEXT)
		label.add_theme_font_size_override("font_size", 21)
		return
	var localization_key := str(label.get_meta("i18n_text_key", ""))
	if label.name in [
		"SpriteStyleLabel",
		"DisplayLabel",
		"ResolutionLabel",
		"AudioLabel",
		"BattleMusicLabel",
	] or localization_key in [
		"ui.settings.language",
		"ui.settings.terminology",
		"ui.settings.tab.account",
	]:
		label.add_theme_color_override("font_color", UI_SECTION_TEXT)
		label.add_theme_font_size_override("font_size", 14)


func _apply_checkbox_style(check_box: CheckBox) -> void:
	check_box.add_theme_color_override("font_color", UI_TEXT)
	check_box.add_theme_color_override("font_hover_color", UI_TEXT)
	check_box.add_theme_color_override("font_pressed_color", UI_TEXT)
	check_box.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	check_box.add_theme_font_size_override("font_size", 13)
	check_box.add_theme_icon_override("unchecked", _settings_checkbox_icon(false, false))
	check_box.add_theme_icon_override("unchecked_hover", _settings_checkbox_icon(false, true))
	check_box.add_theme_icon_override("unchecked_pressed", _settings_checkbox_icon(false, true))
	check_box.add_theme_icon_override("checked", _settings_checkbox_icon(true, false))
	check_box.add_theme_icon_override("checked_hover", _settings_checkbox_icon(true, true))
	check_box.add_theme_icon_override("checked_pressed", _settings_checkbox_icon(true, true))


static func _settings_checkbox_icon(checked: bool, highlighted: bool) -> ImageTexture:
	var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var border := UI_BORDER_FOCUS if highlighted else (UI_SECTION_TEXT if checked else Color("#5d7692"))
	var fill := Color("#274b79") if checked else Color("#0a1423")
	for y: int in range(20):
		for x: int in range(20):
			var is_border := x < 2 or x > 17 or y < 2 or y > 17
			image.set_pixel(x, y, border if is_border else fill)
	if checked:
		var check_pixels := [
			Vector2i(5, 10), Vector2i(6, 11), Vector2i(7, 12), Vector2i(8, 13),
			Vector2i(9, 12), Vector2i(10, 11), Vector2i(11, 10), Vector2i(12, 9),
			Vector2i(13, 8), Vector2i(14, 7),
		]
		for point: Vector2i in check_pixels:
			image.set_pixelv(point, Color.WHITE)
			if point.y + 1 < 18:
				image.set_pixel(point.x, point.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _apply_slider_style(slider: HSlider) -> void:
	if slider == null:
		return
	slider.custom_minimum_size.y = max(slider.custom_minimum_size.y, 22.0)
	slider.add_theme_stylebox_override("slider", _make_panel_style(UI_BORDER_SOFT, UI_BORDER_SOFT, 4, 0))
	slider.add_theme_stylebox_override("grabber_area", _make_panel_style(UI_BORDER, UI_BORDER, 4, 0))


func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_SLOT_BG
	var hover_bg := Color("#151f36f2")
	var pressed_bg := Color("#080d18f2")
	var border := UI_BORDER_SOFT
	var hover_border := UI_BORDER
	var font_color := UI_TEXT

	if variant == "danger":
		normal_bg = UI_DANGER_BG
		hover_bg = Color("#3a151cee")
		pressed_bg = Color("#19090dee")
		border = Color("#7a2b33")
		hover_border = UI_DANGER
		font_color = UI_DANGER

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, hover_border))
	button.add_theme_stylebox_override("focus", _make_button_style(UI_INPUT_BG, UI_BORDER_FOCUS, 8, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_navigation_button_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var normal_bg := Color("#201b3fed") if selected else Color(0, 0, 0, 0)
	var normal_border := UI_PURPLE_HOVER if selected else Color(0, 0, 0, 0)
	button.add_theme_color_override("font_color", UI_TEXT if selected else UI_MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, normal_border, 8, 1 if selected else 0))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#171b35e8"), UI_PURPLE_HOVER, 8, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#12152bf2"), UI_PURPLE_HOVER, 8, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(normal_bg, UI_PURPLE_HOVER, 8, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.7))
	input.add_theme_color_override("caret_color", UI_SECTION_TEXT)
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_stylebox_override("normal", _make_input_style(UI_INPUT_BG, UI_BORDER_SOFT))
	input.add_theme_stylebox_override("focus", _make_input_style(Color("#071225f2"), UI_BORDER_FOCUS, 2))
	input.add_theme_stylebox_override("read_only", _make_input_style(Color("#090d16d8"), UI_BORDER_SOFT))


func _apply_account_dialog_style() -> void:
	if account_details_dialog == null:
		return

	_apply_styles_recursive(account_details_dialog)
	account_details_dialog.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))

	if account_confirm_button != null:
		_apply_button_style(account_confirm_button)
	if account_cancel_button != null:
		_apply_button_style(account_cancel_button, "danger")
	if account_dialog_status_label != null:
		account_dialog_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)

	for input: LineEdit in [
		account_display_name_input,
		account_current_password_input,
		account_new_password_input,
		account_confirm_password_input,
	]:
		if input != null:
			_apply_line_edit_style(input)


func _apply_logout_confirm_dialog_style() -> void:
	if logout_confirm_dialog == null:
		return

	_apply_styles_recursive(logout_confirm_dialog)
	logout_confirm_dialog.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	if logout_confirm_return_button != null:
		_apply_button_style(logout_confirm_return_button, "danger")
	if logout_confirm_cancel_button != null:
		_apply_button_style(logout_confirm_cancel_button)


func _apply_privacy_dialog_style() -> void:
	if privacy_dialog == null:
		return
	privacy_dialog.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	if privacy_confirm_button != null:
		_apply_button_style(
			privacy_confirm_button,
			"danger" if privacy_action == "delete" else "default"
		)


func _make_panel_style(background_color: Color, border_color: Color, corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _make_gold_panel_style(corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := _make_panel_style(UI_BG, UI_BORDER_SOFT, corner_radius, border_width)
	style.shadow_color = Color("#3f2b8a55")
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_glass_panel_style(corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := _make_panel_style(UI_BG, Color("#506f9acc"), corner_radius, border_width)
	style.shadow_color = Color("#4b2ca866")
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 8)
	return style


func _make_button_style(background_color: Color, border_color: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, corner_radius, border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _make_input_style(background_color: Color, border_color: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, 7, border_width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _refresh_account_tab() -> void:
	if account_user_label == null:
		return

	_set_account_status("")
	var display_name: String = AuthService.get_display_name()
	var username: String = str(AuthService.current_user.get("username", ""))
	print("[settings] refresh account tab. display=%s username=%s" % [display_name, username])
	if display_name == "" and username == "":
		account_user_label.text = LocalizationManager.text("ui.settings.account.no_active")
		if edit_account_button != null:
			edit_account_button.disabled = true
		if privacy_export_button != null:
			privacy_export_button.disabled = true
		if delete_account_button != null:
			delete_account_button.disabled = true
		print("[settings] edit account disabled: no active account")
		return
	if edit_account_button != null:
		edit_account_button.disabled = false
		print("[settings] edit account enabled")
	if privacy_export_button != null:
		privacy_export_button.disabled = AuthService.is_impersonating()
	if delete_account_button != null:
		delete_account_button.disabled = AuthService.is_impersonating()
	if username != "" and username != display_name:
		account_user_label.text = LocalizationManager.text(
			"ui.settings.account.logged_in_with_username",
			{"display_name": display_name, "username": username}
		)
		return
	account_user_label.text = LocalizationManager.text(
		"ui.settings.account.logged_in",
		{"display_name": display_name}
	)


func _on_battle_animations_toggled(enabled: bool) -> void:
	if loading_controls:
		return

	SettingsManager.set_battle_animations(enabled)


func _on_weather_effects_toggled(enabled: bool) -> void:
	if loading_controls:
		return

	SettingsManager.set_weather_effects(enabled)


func _on_terrain_effects_toggled(enabled: bool) -> void:
	if loading_controls:
		return

	SettingsManager.set_terrain_effects(enabled)


func _on_display_own_name_toggled(enabled: bool) -> void:
	if loading_controls:
		return

	SettingsManager.set_display_own_name(enabled)
	_refresh_local_player_nameplate()


func _on_hide_other_players_toggled(enabled: bool) -> void:
	if loading_controls:
		return

	SettingsManager.set_hide_other_players(enabled)


func _on_sprite_style_selected(index: int) -> void:
	if loading_controls:
		return

	var option_id: int = sprite_style_options_button.get_item_id(index)
	var sprite_style: String = str(SPRITE_STYLE_BY_OPTION_ID.get(option_id, "animated"))
	if not SettingsManager.set_sprite_style(sprite_style):
		_select_current_sprite_style()
		_update_sprite_style_status_label(GEN5_SPRITE_MISSING_KEY)
		return

	_update_sprite_style_status_label("")


func _on_fullscreen_toggled(enabled: bool) -> void:
	resolution_options_button.disabled = enabled
	if loading_controls:
		return

	SettingsManager.set_fullscreen(enabled)


func _on_resolution_selected(index: int) -> void:
	if loading_controls:
		return

	var resolution_metadata: Variant = resolution_options_button.get_item_metadata(index)
	if not resolution_metadata is Vector2i:
		return

	SettingsManager.set_window_resolution(resolution_metadata as Vector2i)


func _on_master_volume_changed(value: float) -> void:
	_set_volume_value_label(master_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	_set_volume_value_label(music_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_music_volume(value)


func _on_battle_music_selected(index: int) -> void:
	if loading_controls:
		return

	var track_id: String = str(battle_music_options_button.get_item_metadata(index))
	SettingsManager.set_battle_music_track(track_id)


func _on_sfx_volume_changed(value: float) -> void:
	_set_volume_value_label(sfx_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_sfx_volume(value)


func _on_pokemon_cry_volume_changed(value: float) -> void:
	_set_volume_value_label(pokemon_cry_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_pokemon_cry_volume(value)


func _on_ui_volume_changed(value: float) -> void:
	_set_volume_value_label(ui_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_ui_volume(value)


func _on_notification_volume_changed(value: float) -> void:
	_set_volume_value_label(notification_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_notification_volume(value)


func _on_language_selected(index: int) -> void:
	if loading_controls:
		return
	var selected_locale := str(language_options_button.get_item_metadata(index))
	if selected_locale.is_empty():
		return
	SettingsManager.set_locale(selected_locale)


func _on_terminology_selected(index: int) -> void:
	if loading_controls:
		return
	var selected_language := str(terminology_options_button.get_item_metadata(index))
	if selected_language.is_empty():
		return
	SettingsManager.set_content_name_language(selected_language)


func _on_logout_button_pressed() -> void:
	if logging_out or not visible or not _is_account_tab_active():
		return
	_show_logout_confirm_dialog()


func _on_exit_game_button_pressed() -> void:
	if logging_out or not visible or not _is_account_tab_active():
		return
	logging_out = true
	if exit_game_button != null:
		exit_game_button.disabled = true
	if logout_button != null:
		logout_button.disabled = true
	if close_button != null:
		close_button.disabled = true
	await _leave_ranked_queue_before_logout()
	var trade_realtime_service: Object = get_node_or_null("/root/TradeRealtimeService")
	if trade_realtime_service != null and trade_realtime_service.has_method("leave_active_trade_for_exit"):
		await trade_realtime_service.call("leave_active_trade_for_exit")
	var tree := get_tree()
	if tree != null:
		tree.quit()


func _on_credits_button_pressed() -> void:
	if credits_status_label != null:
		credits_status_label.visible = false
	var open_error := OS.shell_open(ExternalLinks.CREDITS_URL)
	if open_error != OK and credits_status_label != null:
		credits_status_label.text = LocalizationManager.text("ui.settings.account.error.credits")
		credits_status_label.add_theme_color_override("font_color", UI_DANGER)
		credits_status_label.visible = true


func _show_logout_confirm_dialog() -> void:
	logout_confirmation_requested = true
	_refresh_impersonation_account_controls()
	if logout_confirm_dialog != null:
		_position_logout_confirm_dialog()
		logout_confirm_dialog.visible = true
		logout_confirm_dialog.z_index = LOGOUT_CONFIRM_Z_INDEX
		logout_confirm_dialog.move_to_front()
	if logout_confirm_return_button != null:
		logout_confirm_return_button.grab_focus()


func _position_logout_confirm_dialog() -> void:
	if logout_confirm_dialog == null:
		return

	var popup_position := global_position + ((size - LOGOUT_CONFIRM_SIZE) * 0.5)
	logout_confirm_dialog.position = popup_position
	logout_confirm_dialog.size = LOGOUT_CONFIRM_SIZE
	logout_confirm_dialog.custom_minimum_size = LOGOUT_CONFIRM_SIZE
	logout_confirm_dialog.offset_left = popup_position.x
	logout_confirm_dialog.offset_top = popup_position.y
	logout_confirm_dialog.offset_right = popup_position.x + LOGOUT_CONFIRM_SIZE.x
	logout_confirm_dialog.offset_bottom = popup_position.y + LOGOUT_CONFIRM_SIZE.y


func _hide_logout_confirm_dialog() -> void:
	logout_confirmation_requested = false
	if logout_confirm_dialog != null:
		logout_confirm_dialog.visible = false


func _is_account_tab_active() -> bool:
	if tab_container == null or account_tab_root == null or not account_tab_root.visible:
		return false
	return tab_container.current_tab == account_tab_root.get_index()


func _on_edit_account_button_pressed() -> void:
	print("[settings] edit account pressed. dialog_parent=%s visible=%s disabled=%s" % [
		str(account_details_dialog.get_parent() if account_details_dialog != null else null),
		str(account_details_dialog.visible if account_details_dialog != null else false),
		str(edit_account_button.disabled if edit_account_button != null else true),
	])
	var display_name: String = AuthService.get_display_name()
	var username: String = str(AuthService.current_user.get("username", ""))
	_hide_privacy_dialog()
	account_display_name_input.text = display_name if display_name != "" else username
	account_current_password_input.clear()
	account_new_password_input.clear()
	account_confirm_password_input.clear()
	_set_account_dialog_status("")
	_popup_account_details_dialog()
	account_display_name_input.grab_focus()


func _on_privacy_export_button_pressed() -> void:
	_show_privacy_dialog("export")


func _on_delete_account_button_pressed() -> void:
	_show_privacy_dialog("delete")


func _show_privacy_dialog(action: String) -> void:
	if privacy_action_busy or AuthService.is_impersonating():
		return
	_hide_account_details_dialog()
	privacy_action = action
	privacy_password_input.clear()
	privacy_delete_confirmation_input.clear()
	privacy_last_export_path = ""
	privacy_open_folder_button.visible = false
	privacy_delete_confirmation_input.visible = action == "delete"
	_set_privacy_dialog_status("")
	_refresh_privacy_dialog_copy()
	_apply_privacy_dialog_style()
	privacy_dialog.visible = true
	privacy_dialog.move_to_front()
	privacy_password_input.grab_focus()


func _refresh_privacy_dialog_copy() -> void:
	if privacy_dialog_title_label == null or privacy_dialog_message_label == null:
		return
	var suffix := "delete" if privacy_action == "delete" else "export"
	privacy_dialog_title_label.text = LocalizationManager.text("ui.settings.privacy.%s" % suffix)
	privacy_dialog_message_label.text = LocalizationManager.text(
		"ui.settings.privacy.%s_message" % suffix
	)


func _hide_privacy_dialog() -> void:
	if privacy_dialog == null or privacy_action_busy:
		return
	privacy_dialog.visible = false
	privacy_action = ""
	privacy_password_input.clear()
	privacy_delete_confirmation_input.clear()
	privacy_last_export_path = ""
	privacy_open_folder_button.visible = false
	_set_privacy_dialog_status("")


func _privacy_action_confirmed() -> void:
	if privacy_action_busy:
		return
	var current_password := privacy_password_input.text
	if current_password.is_empty():
		_set_privacy_dialog_status_key("ui.settings.privacy.error.password", true)
		return
	if privacy_action == "delete" and privacy_delete_confirmation_input.text != "DELETE":
		_set_privacy_dialog_status_key("ui.settings.privacy.error.confirmation", true)
		return
	if privacy_action == "export":
		privacy_last_export_path = ""
		privacy_open_folder_button.visible = false

	_set_privacy_controls_disabled(true)
	_set_privacy_dialog_status_key("ui.settings.privacy.%s_working" % privacy_action)
	var result: Dictionary
	if privacy_action == "delete":
		result = await AuthService.delete_account(current_password, LocalizationManager.current_locale)
	else:
		result = await AuthService.export_personal_data(current_password, LocalizationManager.current_locale)

	if not bool(result.get("success", false)):
		_set_privacy_controls_disabled(false)
		var error_message := str(result.get("error", "")).strip_edges()
		_set_privacy_dialog_status(
			error_message if not error_message.is_empty() else LocalizationManager.text("ui.settings.privacy.error.request"),
			true
		)
		return

	if privacy_action == "delete":
		AuthService.set_pending_login_notice(LocalizationManager.text("ui.settings.privacy.deleted"))
		var scene_error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
		if scene_error != OK:
			_set_privacy_controls_disabled(false)
			_set_privacy_dialog_status(LocalizationManager.text("ui.settings.privacy.error.return_login"), true)
		return

	var export_result := _save_privacy_export(result.get("document", {}))
	_set_privacy_controls_disabled(false)
	if not bool(export_result.get("success", false)):
		_set_privacy_dialog_status_key("ui.settings.privacy.error.save", true)
		return
	_set_privacy_dialog_status_key(
		"ui.settings.privacy.exported",
		false,
		{"path": str(export_result.get("path", ""))}
	)
	privacy_last_export_path = str(export_result.get("path", ""))
	privacy_open_folder_button.visible = not privacy_last_export_path.is_empty()
	privacy_password_input.clear()


func _on_privacy_open_folder_pressed() -> void:
	if privacy_last_export_path.is_empty():
		return
	var open_error := OS.shell_show_in_file_manager(privacy_last_export_path)
	if open_error != OK:
		_set_privacy_dialog_status_key(
			"ui.settings.privacy.error.open_folder",
			true,
			{"path": privacy_last_export_path}
		)


func _save_privacy_export(document_value: Variant) -> Dictionary:
	if not document_value is Dictionary:
		return {"success": false}
	var export_directory := ProjectSettings.globalize_path("user://exports")
	if DirAccess.make_dir_recursive_absolute(export_directory) != OK:
		return {"success": false}
	var timestamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var local_path := "user://exports/pokeaether-personal-data-%s.json" % timestamp
	var file := FileAccess.open(local_path, FileAccess.WRITE)
	if file == null:
		return {"success": false}
	file.store_string(JSON.stringify(document_value, "\t"))
	file.close()
	return {
		"success": true,
		"path": ProjectSettings.globalize_path(local_path),
	}


func _set_privacy_dialog_status(message: String, is_error: bool = false) -> void:
	if privacy_dialog_status_label == null:
		return
	privacy_dialog_status_label.text = message
	privacy_dialog_status_label.add_theme_color_override(
		"font_color",
		UI_DANGER if is_error else UI_MUTED_TEXT
	)


func _set_privacy_dialog_status_key(key: String, is_error: bool = false, values: Dictionary = {}) -> void:
	_set_privacy_dialog_status(LocalizationManager.text(key, values), is_error)


func _set_privacy_controls_disabled(disabled: bool) -> void:
	privacy_action_busy = disabled
	for button: Button in [
		privacy_export_button,
		delete_account_button,
		privacy_open_folder_button,
		privacy_confirm_button,
		privacy_cancel_button,
	]:
		if button != null:
			button.disabled = disabled
	if privacy_password_input != null:
		privacy_password_input.editable = not disabled
	if privacy_delete_confirmation_input != null:
		privacy_delete_confirmation_input.editable = not disabled
	if close_button != null:
		close_button.disabled = disabled


func _popup_account_details_dialog() -> void:
	if account_details_dialog == null:
		print("[settings] account details popup aborted: dialog is null")
		return

	account_details_dialog.visible = true
	account_details_dialog.move_to_front()
	print("[settings] account details shown inline. parent=%s pos=%s size=%s visible=%s" % [
		str(account_details_dialog.get_parent()),
		str(account_details_dialog.global_position),
		str(account_details_dialog.size),
		str(account_details_dialog.visible),
	])


func _hide_account_details_dialog() -> void:
	if account_details_dialog == null:
		return

	print("[settings] account details hidden")
	account_details_dialog.visible = false


func _account_details_confirmed() -> void:
	var display_name: String = account_display_name_input.text.strip_edges()
	var username: String = str(AuthService.current_user.get("username", "")).strip_edges()
	var current_password: String = account_current_password_input.text
	var new_password: String = account_new_password_input.text
	var confirm_password: String = account_confirm_password_input.text

	if username == "":
		_set_account_dialog_status_key("ui.settings.account.no_active", {}, true)
		return
	if display_name == "":
		_set_account_dialog_status_key("ui.settings.account.error.display_required", {}, true)
		return
	if display_name.to_lower() != username.to_lower():
		_set_account_dialog_status_key("ui.settings.account.error.display_mismatch", {}, true)
		return
	if new_password != "" or confirm_password != "" or current_password != "":
		if current_password == "":
			_set_account_dialog_status_key("ui.settings.account.error.current_password", {}, true)
			return
		if new_password.length() < 8:
			_set_account_dialog_status_key("ui.settings.account.error.password_length", {}, true)
			return
		if new_password != confirm_password:
			_set_account_dialog_status_key("ui.settings.account.error.password_mismatch", {}, true)
			return

	_set_account_controls_disabled(true)
	_set_account_dialog_status_key("ui.settings.account.saving")
	var result: Dictionary = await AuthService.update_account_details(display_name, current_password, new_password)
	_set_account_controls_disabled(false)

	if not bool(result.get("success", false)):
		var error_message := str(result.get("error", "")).strip_edges()
		if error_message.is_empty():
			_set_account_dialog_status_key("ui.settings.account.error.update", {}, true)
		else:
			_set_account_dialog_status(error_message, true)
		return

	PlayerSave.player_name = AuthService.get_display_name()
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_display_name"):
		player_node.call("set_display_name", PlayerSave.player_name, SettingsManager.display_own_name)

	_refresh_account_tab()
	_hide_account_details_dialog()
	_set_account_status_key("ui.settings.account.updated")


func _refresh_local_player_nameplate() -> void:
	var player_node: Node
	var world := GameState.get_world()
	if world != null:
		player_node = world.get_node_or_null("Player")
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_display_name"):
		player_node.call("set_display_name", PlayerSave.player_name, SettingsManager.display_own_name)


func _set_account_dialog_status(message: String, is_error: bool = false) -> void:
	if account_dialog_status_label == null:
		return

	account_dialog_status_key = ""
	account_dialog_status_values = {}
	account_dialog_status_is_error = is_error
	account_dialog_status_label.text = message
	account_dialog_status_label.add_theme_color_override("font_color", UI_DANGER if is_error else UI_MUTED_TEXT)


func _set_account_dialog_status_key(key: String, values: Dictionary = {}, is_error: bool = false) -> void:
	_set_account_dialog_status(LocalizationManager.text(key, values), is_error)
	account_dialog_status_key = key
	account_dialog_status_values = values.duplicate()
	account_dialog_status_is_error = is_error


func _set_account_controls_disabled(disabled: bool) -> void:
	if edit_account_button != null:
		edit_account_button.disabled = disabled
	if logout_button != null:
		logout_button.disabled = disabled
	if exit_game_button != null:
		exit_game_button.disabled = disabled
	if close_button != null:
		close_button.disabled = disabled
	if account_confirm_button != null:
		account_confirm_button.disabled = disabled
	if account_cancel_button != null:
		account_cancel_button.disabled = disabled
	if privacy_export_button != null:
		privacy_export_button.disabled = disabled or AuthService.is_impersonating()
	if delete_account_button != null:
		delete_account_button.disabled = disabled or AuthService.is_impersonating()

	for input: LineEdit in [
		account_display_name_input,
		account_current_password_input,
		account_new_password_input,
		account_confirm_password_input,
	]:
		if input != null:
			input.editable = not disabled


func _set_account_status(message: String, is_error: bool = false) -> void:
	if account_status_label == null:
		return
	account_status_key = ""
	account_status_values = {}
	account_status_is_error = is_error
	account_status_label.text = message
	account_status_label.visible = message != ""
	if is_error:
		account_status_label.add_theme_color_override("font_color", UI_DANGER)
	else:
		account_status_label.add_theme_color_override("font_color", UI_SECTION_TEXT)


func _set_account_status_key(key: String, values: Dictionary = {}, is_error: bool = false) -> void:
	_set_account_status(LocalizationManager.text(key, values), is_error)
	account_status_key = key
	account_status_values = values.duplicate()
	account_status_is_error = is_error


func _logout_confirmed() -> void:
	if logging_out or not logout_confirmation_requested:
		return
	logout_confirmation_requested = false
	logging_out = true
	logout_button.disabled = true
	close_button.disabled = true
	if logout_confirm_return_button != null:
		logout_confirm_return_button.disabled = true
	if logout_confirm_cancel_button != null:
		logout_confirm_cancel_button.disabled = true
	if AuthService.is_impersonating():
		await _stop_impersonation_confirmed()
		return
	await _leave_ranked_queue_before_logout()
	# This action only returns to the login scene. Keep AuthService and its
	# remember-me session intact; the explicit Logout action on the login screen
	# is responsible for ending the session and clearing the saved token.
	var error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
	if error != OK:
		logging_out = false
		logout_button.disabled = false
		close_button.disabled = false
		if logout_confirm_return_button != null:
			logout_confirm_return_button.disabled = false
		if logout_confirm_cancel_button != null:
			logout_confirm_cancel_button.disabled = false
		push_warning("Could not return to login screen: %s" % error_string(error))


func _stop_impersonation_confirmed() -> void:
	var world := GameState.get_world()
	if world == null or not world.has_method("prepare_for_account_switch"):
		_restore_account_return_controls()
		_set_account_status_key("ui.staff.impersonate.return_failed", {}, true)
		return
	var prepare_value: Variant = await world.call("prepare_for_account_switch")
	var prepare_result: Dictionary = (
		prepare_value as Dictionary if prepare_value is Dictionary else {}
	)
	if not bool(prepare_result.get("success", false)):
		_restore_account_return_controls()
		_set_account_status(
			str(prepare_result.get("error", LocalizationManager.text(
				"ui.staff.impersonate.return_failed"
			))),
			true
		)
		return

	var result: Dictionary = await AuthService.stop_impersonating()
	if not bool(result.get("success", false)):
		if world.has_method("cancel_account_switch"):
			world.call("cancel_account_switch")
		_restore_account_return_controls()
		_set_account_status(
			str(result.get("error", LocalizationManager.text(
				"ui.staff.impersonate.return_failed"
			))),
			true
		)
		return

	_hide_logout_confirm_dialog()
	GameState.set_prepared_world_state({})
	var error: Error = get_tree().change_scene_to_file(LOADING_SCENE_PATH)
	if error != OK:
		AuthService.clear_session()
		var login_error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
		if login_error != OK:
			push_error("Could not restore the staff account after impersonation.")


func _restore_account_return_controls() -> void:
	logging_out = false
	logout_confirmation_requested = false
	if logout_button != null:
		logout_button.disabled = false
	if close_button != null:
		close_button.disabled = false
	if logout_confirm_return_button != null:
		logout_confirm_return_button.disabled = false
	if logout_confirm_cancel_button != null:
		logout_confirm_cancel_button.disabled = false
	_hide_logout_confirm_dialog()


func _refresh_impersonation_account_controls() -> void:
	var impersonating := AuthService.is_impersonating()
	var button_key := (
		"ui.staff.impersonate.return_account"
		if impersonating
		else "ui.settings.account.return_login"
	)
	var note_key := (
		"ui.staff.impersonate.active_note"
		if impersonating
		else "ui.settings.account.return_note"
	)
	var message_key := (
		"ui.staff.impersonate.return_confirm"
		if impersonating
		else "ui.settings.logout.message"
	)
	if logout_button != null:
		_set_localized_text(logout_button, button_key)
	if account_return_note_label != null:
		_set_localized_text(account_return_note_label, note_key)
	if logout_confirm_title_label != null:
		_set_localized_text(logout_confirm_title_label, button_key)
	if logout_confirm_message_label != null:
		_set_localized_text(logout_confirm_message_label, message_key)
	if privacy_export_button != null:
		privacy_export_button.disabled = impersonating
	if delete_account_button != null:
		delete_account_button.disabled = impersonating

func _leave_ranked_queue_before_logout() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group("ui_overlay"):
		if node != null and node.has_method("leave_pvp_queue_for_logout"):
			await node.call("leave_pvp_queue_for_logout")


func _set_volume_control(slider: HSlider, value_label: Label, value: float) -> void:
	slider.value = value
	_set_volume_value_label(value_label, value)


func _set_volume_value_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(roundf(value))


func _select_current_sprite_style() -> void:
	var option_id: int = int(OPTION_ID_BY_SPRITE_STYLE.get(SettingsManager.sprite_style, 0))
	var option_index: int = sprite_style_options_button.get_item_index(option_id)
	if option_index >= 0:
		sprite_style_options_button.select(option_index)


func _update_sprite_style_status_label(message_key: String) -> void:
	if sprite_style_status_label == null:
		return

	if message_key.is_empty() and not SettingsManager.is_gen5_animated_sprites_installed():
		message_key = "ui.settings.sprite.download_available"

	sprite_style_status_label.text = LocalizationManager.text(message_key) if not message_key.is_empty() else ""
	sprite_style_status_label.visible = not message_key.is_empty()


func _apply_sprite_style_option_labels() -> void:
	if sprite_style_options_button == null:
		return
	var translation_key_by_id: Dictionary = {
		0: "ui.settings.sprite.animated",
		1: "ui.settings.sprite.static",
		2: "ui.settings.sprite.gen5",
	}
	for index: int in range(sprite_style_options_button.item_count):
		var option_id := sprite_style_options_button.get_item_id(index)
		var key := str(translation_key_by_id.get(option_id, ""))
		if not key.is_empty():
			sprite_style_options_button.set_item_text(index, LocalizationManager.text(key))


func _apply_language_options_to_control() -> void:
	if language_options_button == null:
		return
	var was_loading_controls := loading_controls
	loading_controls = true
	language_options_button.clear()
	var selected_index := 0
	var supported_locales: Array[String] = LocalizationManager.get_supported_locales()
	for index: int in range(supported_locales.size()):
		var supported_locale := supported_locales[index]
		LanguageSelectorStyle.add_locale_item(
			language_options_button,
			supported_locale,
			LocalizationManager.get_language_name(supported_locale),
			index
		)
		if supported_locale == SettingsManager.locale:
			selected_index = index
	if language_options_button.item_count > 0:
		language_options_button.select(selected_index)
	loading_controls = was_loading_controls


func _apply_terminology_options_to_control() -> void:
	if terminology_options_button == null:
		return
	var was_loading_controls := loading_controls
	loading_controls = true
	terminology_options_button.clear()
	var options: Array[String] = [
		SettingsManager.CONTENT_NAME_LANGUAGE_ENGLISH,
		SettingsManager.CONTENT_NAME_LANGUAGE_LOCALIZED,
	]
	var translation_keys := {
		SettingsManager.CONTENT_NAME_LANGUAGE_ENGLISH: "ui.settings.terminology.english",
		SettingsManager.CONTENT_NAME_LANGUAGE_LOCALIZED: "ui.settings.terminology.localized",
	}
	var selected_index := 0
	for index: int in range(options.size()):
		var option := options[index]
		terminology_options_button.add_item(
			LocalizationManager.text(str(translation_keys.get(option, ""))),
			index
		)
		terminology_options_button.set_item_metadata(index, option)
		if option == SettingsManager.content_name_language:
			selected_index = index
	if terminology_options_button.item_count > 0:
		terminology_options_button.select(selected_index)
	loading_controls = was_loading_controls


func _apply_battle_music_options_to_control() -> void:
	battle_music_options_button.clear()

	var selected_index: int = 0
	var track_ids: Array[String] = MusicManager.get_battle_music_track_ids()
	for index: int in range(track_ids.size()):
		var track_id: String = track_ids[index]
		battle_music_options_button.add_item(MusicManager.get_battle_music_track_label(track_id), index)
		battle_music_options_button.set_item_metadata(index, track_id)
		if track_id == SettingsManager.battle_music_track:
			selected_index = index

	if battle_music_options_button.item_count > 0:
		battle_music_options_button.select(selected_index)


func _apply_resolution_options_to_control() -> void:
	resolution_options_button.clear()

	var selected_index: int = 0
	for index: int in range(SettingsManager.AVAILABLE_WINDOW_RESOLUTIONS.size()):
		var resolution: Vector2i = SettingsManager.AVAILABLE_WINDOW_RESOLUTIONS[index]
		resolution_options_button.add_item("%dx%d" % [resolution.x, resolution.y], index)
		resolution_options_button.set_item_metadata(index, resolution)
		if resolution == SettingsManager.window_resolution:
			selected_index = index

	if resolution_options_button.item_count > 0:
		resolution_options_button.select(selected_index)
