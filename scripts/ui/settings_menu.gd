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

@onready var battle_animations_check_box: CheckBox = $MarginContainer/VBoxContainer/BattleAnimationsCheckBox
@onready var weather_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/WeatherEffectsCheckBox
@onready var terrain_effects_check_box: CheckBox = $MarginContainer/VBoxContainer/TerrainEffectsCheckBox
@onready var sprite_style_options_button: OptionButton = $MarginContainer/VBoxContainer/SpriteStyleOptionsButton
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


func _ready() -> void:
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
	close_button.pressed.connect(close)
	_apply_settings_to_controls()
	visible = false


func open() -> void:
	_apply_settings_to_controls()
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

	fullscreen_check_box.button_pressed = SettingsManager.fullscreen
	_apply_resolution_options_to_control()
	resolution_options_button.disabled = SettingsManager.fullscreen

	_set_volume_control(master_volume_slider, master_volume_value_label, SettingsManager.master_volume)
	_set_volume_control(music_volume_slider, music_volume_value_label, SettingsManager.music_volume)
	_apply_battle_music_options_to_control()
	_set_volume_control(sfx_volume_slider, sfx_volume_value_label, SettingsManager.sfx_volume)
	_set_volume_control(ui_volume_slider, ui_volume_value_label, SettingsManager.ui_volume)

	loading_controls = false


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
	SettingsManager.set_sprite_style(sprite_style)


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


func _set_volume_control(slider: HSlider, value_label: Label, value: float) -> void:
	slider.value = value
	_set_volume_value_label(value_label, value)


func _set_volume_value_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(roundf(value))


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
