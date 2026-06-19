extends PanelContainer

signal closed

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
const GEN5_SPRITE_MISSING_MESSAGE := "Gen 5 Animated sprites are not installed. Download them from the launcher."
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const MINIMUM_MENU_SIZE := Vector2(440, 540)
const UI_BG := Color("#070b14f2")
const UI_SLOT_BG := Color("#0d1625e6")
const UI_INPUT_BG := Color("#050912e8")
const UI_BORDER := Color("#d8b767")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_SECTION_TEXT := Color("#d8b767")
const UI_PURPLE_HOVER := Color("#b980ff")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")

@onready var settings_layout: VBoxContainer = $MarginContainer/VBoxContainer
@onready var battle_animations_check_box: CheckBox = $MarginContainer/VBoxContainer/BattleAnimationsCheckBox
@onready var weather_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/WeatherEffectsCheckBox
@onready var terrain_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/TerrainEffectsCheckBox
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
@onready var ui_volume_slider: HSlider = $MarginContainer/VBoxContainer/UiVolumeRow/UiVolumeSlider
@onready var ui_volume_value_label: Label = $MarginContainer/VBoxContainer/UiVolumeRow/UiVolumeValueLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var loading_controls := false
var logging_out := false
var tab_container: TabContainer
var account_tab_root: Control
var account_user_label: Label
var logout_button: Button
var logout_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	custom_minimum_size = MINIMUM_MENU_SIZE
	_setup_tabs()
	_setup_logout_confirm_dialog()
	_apply_premium_styles()
	battle_animations_check_box.toggled.connect(_on_battle_animations_toggled)
	weather_effects_check_box.toggled.connect(_on_weather_effects_toggled)
	terrain_effects_check_box.toggled.connect(_on_terrain_effects_toggled)
	sprite_style_options_button.item_selected.connect(_on_sprite_style_selected)
	fullscreen_check_box.toggled.connect(_on_fullscreen_toggled)
	resolution_options_button.item_selected.connect(_on_resolution_selected)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	battle_music_options_button.item_selected.connect(_on_battle_music_selected)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	ui_volume_slider.value_changed.connect(_on_ui_volume_changed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	close_button.pressed.connect(close)
	_apply_settings_to_controls()
	visible = false


func open(context: String = "game") -> void:
	_apply_settings_to_controls()
	_apply_context(context)
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _apply_settings_to_controls() -> void:
	loading_controls = true
	battle_animations_check_box.button_pressed = SettingsManager.battle_animations
	weather_effects_check_box.button_pressed = SettingsManager.weather_effects
	terrain_effects_check_box.button_pressed = SettingsManager.terrain_effects

	var option_id: int = int(OPTION_ID_BY_SPRITE_STYLE.get(SettingsManager.sprite_style, 0))
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
	_set_volume_control(ui_volume_slider, ui_volume_value_label, SettingsManager.ui_volume)

	loading_controls = false


func _setup_tabs() -> void:
	if tab_container != null:
		return

	tab_container = TabContainer.new()
	tab_container.name = "SettingsTabs"
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_layout.add_child(tab_container)
	settings_layout.move_child(tab_container, 1)

	var general_tab: VBoxContainer = _create_tab_content("General")
	var graphics_tab: VBoxContainer = _create_tab_content("Graphics")
	var sound_tab: VBoxContainer = _create_tab_content("Sound")
	var account_tab: VBoxContainer = _create_tab_content("Account")
	account_tab_root = account_tab.get_parent() as Control

	_move_nodes_to_container(general_tab, [
		battle_animations_check_box,
		weather_effects_check_box,
		terrain_effects_check_box,
	])
	_move_nodes_to_container(graphics_tab, [
		sprite_style_options_button.get_node("../SpriteStyleLabel"),
		sprite_style_options_button,
		sprite_style_status_label,
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
		ui_volume_slider.get_node(".."),
	])
	_build_account_tab(account_tab)


func _apply_context(context: String) -> void:
	var show_account_tab := context != "login"
	if account_tab_root != null:
		account_tab_root.visible = show_account_tab
		var account_tab_index: int = account_tab_root.get_index()
		if tab_container != null and tab_container.has_method("set_tab_hidden"):
			tab_container.call("set_tab_hidden", account_tab_index, not show_account_tab)

	if show_account_tab:
		_refresh_account_tab()
		return

	if tab_container != null:
		tab_container.current_tab = 0


func _create_tab_content(tab_name: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	tab_container.add_child(margin)

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


func _build_account_tab(account_tab: VBoxContainer) -> void:
	var account_label := Label.new()
	account_label.text = "Account"
	account_tab.add_child(account_label)

	account_user_label = Label.new()
	account_user_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_tab.add_child(account_user_label)

	var account_note := Label.new()
	account_note.text = "Return to the login screen without ending your saved session."
	account_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	account_note.add_theme_font_size_override("font_size", 12)
	account_tab.add_child(account_note)

	logout_button = Button.new()
	logout_button.text = "Return to Login"
	account_tab.add_child(logout_button)


func _setup_logout_confirm_dialog() -> void:
	logout_confirm_dialog = ConfirmationDialog.new()
	logout_confirm_dialog.title = "Return to Login"
	logout_confirm_dialog.dialog_text = "Return to the login screen? Your saved session stays active."
	logout_confirm_dialog.ok_button_text = "Return"
	logout_confirm_dialog.cancel_button_text = "Cancel"
	logout_confirm_dialog.exclusive = true
	logout_confirm_dialog.confirmed.connect(_logout_confirmed)
	add_child(logout_confirm_dialog)


func _apply_premium_styles() -> void:
	add_theme_stylebox_override("panel", _make_gold_panel_style(12, 1))
	if tab_container != null:
		tab_container.add_theme_stylebox_override("panel", _make_panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
		tab_container.add_theme_stylebox_override("tab_selected", _make_button_style(Color("#152447ee"), UI_BORDER, 8, 1))
		tab_container.add_theme_stylebox_override("tab_hovered", _make_button_style(Color("#1d3268f2"), UI_PURPLE_HOVER, 8, 1))
		tab_container.add_theme_stylebox_override("tab_unselected", _make_button_style(UI_SLOT_BG, UI_BORDER_SOFT, 8, 1))
		tab_container.add_theme_color_override("font_selected_color", UI_TEXT)
		tab_container.add_theme_color_override("font_unselected_color", UI_MUTED_TEXT)
		tab_container.add_theme_color_override("font_hovered_color", UI_TEXT)

	_apply_styles_recursive(self)
	if logout_button != null:
		_apply_button_style(logout_button, "danger")
	_apply_button_style(close_button)


func _apply_styles_recursive(node: Node) -> void:
	if node is Label:
		_apply_label_style(node as Label)
	elif node is CheckBox:
		_apply_checkbox_style(node as CheckBox)
	elif node is OptionButton:
		_apply_button_style(node as Button)
	elif node is Button:
		_apply_button_style(node as Button)

	for child_node: Node in node.get_children():
		_apply_styles_recursive(child_node)


func _apply_label_style(label: Label) -> void:
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	var text_value := label.text.strip_edges()
	if label.name == "TitleLabel":
		label.add_theme_color_override("font_color", UI_SECTION_TEXT)
		label.add_theme_font_size_override("font_size", 21)
		return
	if text_value in ["Sprite Style", "Display", "Window Resolution", "Audio", "Battle Music", "Account"]:
		label.add_theme_color_override("font_color", UI_SECTION_TEXT)
		label.add_theme_font_size_override("font_size", 14)


func _apply_checkbox_style(check_box: CheckBox) -> void:
	check_box.add_theme_color_override("font_color", UI_TEXT)
	check_box.add_theme_color_override("font_hover_color", UI_TEXT)
	check_box.add_theme_color_override("font_pressed_color", UI_TEXT)
	check_box.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))


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
	var style := _make_panel_style(UI_BG, UI_BORDER, corner_radius, border_width)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_button_style(background_color: Color, border_color: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, corner_radius, border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _refresh_account_tab() -> void:
	if account_user_label == null:
		return

	var display_name: String = AuthService.get_display_name()
	var username: String = str(AuthService.current_user.get("username", ""))
	if display_name == "" and username == "":
		account_user_label.text = "No active account."
		return
	if username != "" and username != display_name:
		account_user_label.text = "Logged in as %s (@%s)" % [display_name, username]
		return
	account_user_label.text = "Logged in as %s" % display_name


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


func _on_sprite_style_selected(index: int) -> void:
	if loading_controls:
		return

	var option_id: int = sprite_style_options_button.get_item_id(index)
	var sprite_style: String = str(SPRITE_STYLE_BY_OPTION_ID.get(option_id, "animated"))
	if not SettingsManager.set_sprite_style(sprite_style):
		_select_current_sprite_style()
		_update_sprite_style_status_label(GEN5_SPRITE_MISSING_MESSAGE)
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


func _on_ui_volume_changed(value: float) -> void:
	_set_volume_value_label(ui_volume_value_label, value)
	if loading_controls:
		return

	SettingsManager.set_ui_volume(value)


func _on_logout_button_pressed() -> void:
	if logging_out:
		return
	logout_confirm_dialog.popup_centered()


func _logout_confirmed() -> void:
	if logging_out:
		return
	logging_out = true
	logout_button.disabled = true
	close_button.disabled = true
	AuthService.clear_session()
	var error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
	if error != OK:
		logging_out = false
		logout_button.disabled = false
		close_button.disabled = false
		push_warning("Could not return to login screen: %s" % error_string(error))


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


func _update_sprite_style_status_label(message: String) -> void:
	if sprite_style_status_label == null:
		return

	if message.is_empty() and not SettingsManager.is_gen5_animated_sprites_installed():
		message = "Gen 5 Animated sprites can be downloaded from the launcher."

	sprite_style_status_label.text = message
	sprite_style_status_label.visible = not message.is_empty()


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
