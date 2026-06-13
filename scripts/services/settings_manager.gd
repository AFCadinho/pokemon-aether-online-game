extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.json"
const SPRITE_STYLE_ANIMATED := "animated"
const SPRITE_STYLE_STATIC := "static"
const SPRITE_STYLE_PIXEL := "pixel"
const BATTLE_MUSIC_DEFAULT := "default"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1600, 900)
const AVAILABLE_WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var battle_animations := true
var weather_effects := true
var terrain_effects := true
var sprite_style := SPRITE_STYLE_ANIMATED
var fullscreen := false
var window_resolution := DEFAULT_WINDOW_RESOLUTION
var master_volume := 80.0
var music_volume := 55.0
var sfx_volume := 75.0
var ui_volume := 75.0
var battle_music_track := BATTLE_MUSIC_DEFAULT


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	_apply_runtime_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		save_settings()
		return

	var settings_text: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var parsed_data: Variant = JSON.parse_string(settings_text)
	if not parsed_data is Dictionary:
		save_settings()
		return

	var data: Dictionary = parsed_data as Dictionary
	battle_animations = bool(data.get("battle_animations", battle_animations))
	weather_effects = bool(data.get("weather_effects", weather_effects))
	terrain_effects = bool(data.get("terrain_effects", terrain_effects))
	sprite_style = _validated_sprite_style(str(data.get("sprite_style", sprite_style)))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	window_resolution = _validated_window_resolution(data.get("window_resolution", window_resolution))
	master_volume = _validated_volume(data.get("master_volume", master_volume))
	music_volume = _validated_volume(data.get("music_volume", music_volume))
	sfx_volume = _validated_volume(data.get("sfx_volume", sfx_volume))
	ui_volume = _validated_volume(data.get("ui_volume", ui_volume))
	battle_music_track = str(data.get("battle_music_track", battle_music_track)).strip_edges()
	if battle_music_track == "":
		battle_music_track = BATTLE_MUSIC_DEFAULT
	_apply_runtime_settings()


func save_settings() -> void:
	var data: Dictionary = {
		"battle_animations": battle_animations,
		"weather_effects": weather_effects,
		"terrain_effects": terrain_effects,
		"sprite_style": sprite_style,
		"fullscreen": fullscreen,
		"window_resolution": {
			"width": window_resolution.x,
			"height": window_resolution.y,
		},
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"battle_music_track": battle_music_track,
	}

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save settings to %s" % SETTINGS_PATH)
		return

	file.store_string(JSON.stringify(data, "\t"))


func set_battle_animations(enabled: bool) -> void:
	if battle_animations == enabled:
		return

	battle_animations = enabled
	_save_and_emit()


func set_weather_effects(enabled: bool) -> void:
	if weather_effects == enabled:
		return

	weather_effects = enabled
	_save_and_emit()


func set_terrain_effects(enabled: bool) -> void:
	if terrain_effects == enabled:
		return

	terrain_effects = enabled
	_save_and_emit()


func set_sprite_style(style: String) -> void:
	var validated_style: String = _validated_sprite_style(style)
	if sprite_style == validated_style:
		return

	sprite_style = validated_style
	_save_and_emit()


func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return

	fullscreen = enabled
	_apply_display_settings()
	_save_and_emit()


func set_window_resolution(resolution: Vector2i) -> void:
	var validated_resolution: Vector2i = _validated_window_resolution(resolution)
	if window_resolution == validated_resolution:
		return

	window_resolution = validated_resolution
	_apply_display_settings()
	_save_and_emit()


func set_master_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(master_volume, validated_volume):
		return

	master_volume = validated_volume
	_apply_audio_bus_volume(MASTER_BUS, master_volume)
	_save_and_emit()


func set_music_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(music_volume, validated_volume):
		return

	music_volume = validated_volume
	_apply_audio_bus_volume(MUSIC_BUS, music_volume)
	_save_and_emit()


func set_sfx_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(sfx_volume, validated_volume):
		return

	sfx_volume = validated_volume
	_apply_audio_bus_volume(SFX_BUS, sfx_volume)
	_save_and_emit()


func set_ui_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(ui_volume, validated_volume):
		return

	ui_volume = validated_volume
	_apply_audio_bus_volume(UI_BUS, ui_volume)
	_save_and_emit()


func set_battle_music_track(track_id: String) -> void:
	var validated_track_id: String = track_id.strip_edges()
	if validated_track_id == "":
		validated_track_id = BATTLE_MUSIC_DEFAULT
	if battle_music_track == validated_track_id:
		return

	battle_music_track = validated_track_id
	_save_and_emit()


func _save_and_emit() -> void:
	save_settings()
	settings_changed.emit()


func _validated_sprite_style(style: String) -> String:
	match style:
		SPRITE_STYLE_ANIMATED, SPRITE_STYLE_STATIC, SPRITE_STYLE_PIXEL:
			return style
		_:
			return SPRITE_STYLE_ANIMATED


func _validated_volume(volume: Variant) -> float:
	return clampf(float(volume), 0.0, 100.0)


func _validated_window_resolution(resolution: Variant) -> Vector2i:
	if resolution is Vector2i:
		return _closest_available_resolution(resolution as Vector2i)

	if resolution is Vector2:
		var vector_resolution: Vector2 = resolution as Vector2
		return _closest_available_resolution(Vector2i(int(vector_resolution.x), int(vector_resolution.y)))

	if resolution is Dictionary:
		var resolution_data: Dictionary = resolution as Dictionary
		return _closest_available_resolution(Vector2i(
			int(resolution_data.get("width", DEFAULT_WINDOW_RESOLUTION.x)),
			int(resolution_data.get("height", DEFAULT_WINDOW_RESOLUTION.y))
		))

	if resolution is Array:
		var resolution_parts: Array = resolution as Array
		if resolution_parts.size() >= 2:
			return _closest_available_resolution(Vector2i(int(resolution_parts[0]), int(resolution_parts[1])))

	return DEFAULT_WINDOW_RESOLUTION


func _closest_available_resolution(resolution: Vector2i) -> Vector2i:
	for available_resolution: Vector2i in AVAILABLE_WINDOW_RESOLUTIONS:
		if available_resolution == resolution:
			return available_resolution

	return DEFAULT_WINDOW_RESOLUTION


func _ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	_ensure_audio_bus(UI_BUS)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, MASTER_BUS)


func _apply_runtime_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()


func _apply_audio_settings() -> void:
	_apply_audio_bus_volume(MASTER_BUS, master_volume)
	_apply_audio_bus_volume(MUSIC_BUS, music_volume)
	_apply_audio_bus_volume(SFX_BUS, sfx_volume)
	_apply_audio_bus_volume(UI_BUS, ui_volume)


func _apply_audio_bus_volume(bus_name: String, volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	var normalized_volume: float = clampf(volume / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized_volume, 0.0001)))


func _apply_display_settings() -> void:
	if OS.has_feature("web"):
		return

	if fullscreen:
		WindowFit.apply_fullscreen()
		WindowFit.apply_fullscreen_deferred()
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	WindowFit.fit_window_to_screen_deferred(window_resolution)
