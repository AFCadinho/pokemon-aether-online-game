extends Node

signal settings_changed
signal world_pixel_scale_changed(scale: float)
signal mount_loadout_changed(movement_mode: String, mount_id: String)
signal input_binding_changed(action: String, keycode: Key)

const PixelPerfectRendering := preload("res://scripts/services/pixel_perfect_rendering.gd")
const MountServiceScript := preload("res://scripts/services/mount_service.gd")

const SETTINGS_PATH := "user://settings.json"
const SPRITE_STYLE_ANIMATED := "animated"
const SPRITE_STYLE_STATIC := "static"
const SPRITE_STYLE_PIXEL := "pixel"
const SPRITE_STYLE_GEN5_ANIMATED := SPRITE_STYLE_PIXEL
const BATTLE_MUSIC_DEFAULT := "lysandre_remix_pokemon_legends_z_a_zame"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const POKEMON_CRY_BUS := "Pokemon Cries"
const UI_BUS := "UI"
const NOTIFICATION_BUS := "Notifications"
const LANGUAGE_CHAT_ZH := "language_zh"
const LANGUAGE_CHAT_PT := "language_pt"
const AVAILABLE_LANGUAGE_CHATS: Array[String] = [
	LANGUAGE_CHAT_ZH,
	LANGUAGE_CHAT_PT,
]
const DEFAULT_LOCALE := "en"
const CONTENT_NAME_LANGUAGE_ENGLISH := "english"
const CONTENT_NAME_LANGUAGE_LOCALIZED := "localized"
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1600, 900)
const DEFAULT_WORLD_PIXEL_SCALE := PixelPerfectRendering.DEFAULT_SCALE
const AVAILABLE_WORLD_PIXEL_SCALES: Array[float] = PixelPerfectRendering.AVAILABLE_SCALES
const MOUNT_MODE_LAND := MountServiceScript.MOVEMENT_MODE_LAND
const MOUNT_MODE_SURF := MountServiceScript.MOVEMENT_MODE_SURF
const DEFAULT_CURSOR_SCALE := 75.0
const MIN_CURSOR_SCALE := 50.0
const MAX_CURSOR_SCALE := 150.0
const CONFIGURABLE_INPUT_ACTIONS: Array[String] = ["fish", "pickpocket"]
const DEFAULT_INPUT_BINDINGS: Dictionary = {
	"fish": KEY_F,
	"pickpocket": KEY_T,
}
const AVAILABLE_WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var battle_animations := true
var weather_effects := true
var terrain_effects := true
var display_own_name := true
var hide_other_players := false
var sprite_style := SPRITE_STYLE_ANIMATED
var fullscreen := false
var window_resolution := DEFAULT_WINDOW_RESOLUTION
var world_pixel_scale := DEFAULT_WORLD_PIXEL_SCALE
var selected_land_mount_id := MountServiceScript.get_default_mount_id(MOUNT_MODE_LAND)
var selected_surf_mount_id := MountServiceScript.get_default_mount_id(MOUNT_MODE_SURF)
var cursor_scale := DEFAULT_CURSOR_SCALE
var master_volume := 80.0
var music_volume := 55.0
var sfx_volume := 75.0
var pokemon_cry_volume := 75.0
var ui_volume := 75.0
var notification_volume := 75.0
var battle_music_track := BATTLE_MUSIC_DEFAULT
var locale := DEFAULT_LOCALE
var content_name_language := CONTENT_NAME_LANGUAGE_ENGLISH
var enabled_language_chats: Array[String] = []
var input_bindings: Dictionary = DEFAULT_INPUT_BINDINGS.duplicate()


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	_apply_runtime_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		locale = LocalizationManager.get_preferred_system_locale()
		_apply_launcher_locale_argument()
		content_name_language = _default_content_name_language(locale)
		save_settings()
		return

	var settings_text: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	var parsed_data: Variant = JSON.parse_string(settings_text)
	if not parsed_data is Dictionary:
		_apply_launcher_locale_argument()
		save_settings()
		return

	var data: Dictionary = parsed_data as Dictionary
	battle_animations = bool(data.get("battle_animations", battle_animations))
	weather_effects = bool(data.get("weather_effects", weather_effects))
	terrain_effects = bool(data.get("terrain_effects", terrain_effects))
	display_own_name = bool(data.get("display_own_name", display_own_name))
	hide_other_players = bool(data.get("hide_other_players", hide_other_players))
	sprite_style = _validated_sprite_style(str(data.get("sprite_style", sprite_style)))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	window_resolution = _validated_window_resolution(data.get("window_resolution", window_resolution))
	world_pixel_scale = PixelPerfectRendering.validate_scale(
		data.get("world_pixel_scale", world_pixel_scale)
	)
	selected_land_mount_id = MountServiceScript.resolve_mount_id_for_mode(
		str(data.get("selected_land_mount_id", selected_land_mount_id)),
		MOUNT_MODE_LAND,
		true
	)
	selected_surf_mount_id = MountServiceScript.resolve_mount_id_for_mode(
		str(data.get("selected_surf_mount_id", selected_surf_mount_id)),
		MOUNT_MODE_SURF,
		true
	)
	cursor_scale = _validated_cursor_scale(data.get("cursor_scale", cursor_scale))
	master_volume = _validated_volume(data.get("master_volume", master_volume))
	music_volume = _validated_volume(data.get("music_volume", music_volume))
	sfx_volume = _validated_volume(data.get("sfx_volume", sfx_volume))
	pokemon_cry_volume = _validated_volume(data.get("pokemon_cry_volume", pokemon_cry_volume))
	ui_volume = _validated_volume(data.get("ui_volume", ui_volume))
	notification_volume = _validated_volume(data.get("notification_volume", notification_volume))
	battle_music_track = str(data.get("battle_music_track", battle_music_track)).strip_edges()
	if battle_music_track == "":
		battle_music_track = BATTLE_MUSIC_DEFAULT
	locale = LocalizationManager.normalize_locale(
		str(data.get("locale", LocalizationManager.get_preferred_system_locale()))
	)
	var has_content_name_language := data.has("content_name_language")
	content_name_language = _validated_content_name_language(
		str(data.get("content_name_language", _default_content_name_language(locale)))
	)
	enabled_language_chats = _validated_language_chats(
		data.get("enabled_language_chats", enabled_language_chats)
	)
	input_bindings = _validated_input_bindings(data.get("input_bindings", input_bindings))
	var launcher_changed := _apply_launcher_locale_argument()
	if not has_content_name_language:
		content_name_language = _default_content_name_language(locale)
	if launcher_changed or not has_content_name_language:
		save_settings()
	_apply_runtime_settings()


func _apply_launcher_locale_argument() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			var launcher_locale := LocalizationManager.normalize_locale(argument.trim_prefix("--locale="))
			var changed := locale != launcher_locale
			locale = launcher_locale
			return changed
	return false


func save_settings() -> void:
	var data: Dictionary = {
		"battle_animations": battle_animations,
		"weather_effects": weather_effects,
		"terrain_effects": terrain_effects,
		"display_own_name": display_own_name,
		"hide_other_players": hide_other_players,
		"sprite_style": sprite_style,
		"fullscreen": fullscreen,
		"window_resolution": {
			"width": window_resolution.x,
			"height": window_resolution.y,
		},
		"world_pixel_scale": world_pixel_scale,
		"selected_land_mount_id": selected_land_mount_id,
		"selected_surf_mount_id": selected_surf_mount_id,
		"cursor_scale": cursor_scale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"pokemon_cry_volume": pokemon_cry_volume,
		"ui_volume": ui_volume,
		"notification_volume": notification_volume,
		"battle_music_track": battle_music_track,
		"locale": locale,
		"content_name_language": content_name_language,
		"enabled_language_chats": enabled_language_chats,
		"input_bindings": input_bindings,
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


func set_display_own_name(enabled: bool) -> void:
	if display_own_name == enabled:
		return

	display_own_name = enabled
	_save_and_emit()


func set_hide_other_players(enabled: bool) -> void:
	if hide_other_players == enabled:
		return

	hide_other_players = enabled
	_save_and_emit()


func set_sprite_style(style: String) -> bool:
	var validated_style: String = _validated_sprite_style(style)
	if style == SPRITE_STYLE_GEN5_ANIMATED and validated_style != SPRITE_STYLE_GEN5_ANIMATED:
		return false
	if sprite_style == validated_style:
		return true

	sprite_style = validated_style
	_save_and_emit()
	return true


func is_gen5_animated_sprites_installed() -> bool:
	return PokemonAssets.has_optional_gen5_animated_sprites()


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


func set_world_pixel_scale(value: float) -> void:
	var validated_scale := PixelPerfectRendering.validate_scale(value)
	if world_pixel_scale == validated_scale:
		return

	world_pixel_scale = validated_scale
	world_pixel_scale_changed.emit(world_pixel_scale)
	_save_and_emit()


func get_effective_world_pixel_scale(viewport_size: Vector2i = Vector2i.ZERO) -> float:
	var resolved_viewport_size := viewport_size
	if resolved_viewport_size == Vector2i.ZERO and get_tree() != null:
		resolved_viewport_size = Vector2i(get_tree().root.get_visible_rect().size)
	return PixelPerfectRendering.resolve_scale(world_pixel_scale, resolved_viewport_size)


func get_selected_mount_id(movement_mode: String) -> String:
	match movement_mode.strip_edges().to_lower():
		MOUNT_MODE_LAND:
			return selected_land_mount_id
		MOUNT_MODE_SURF:
			return selected_surf_mount_id
	return ""


func set_input_binding(action: String, keycode: Key) -> bool:
	var normalized_action := action.strip_edges().to_lower()
	if normalized_action not in CONFIGURABLE_INPUT_ACTIONS or keycode == KEY_NONE:
		return false
	if int(input_bindings.get(normalized_action, KEY_NONE)) == int(keycode):
		_apply_input_binding(normalized_action, keycode)
		return true
	input_bindings[normalized_action] = int(keycode)
	_apply_input_binding(normalized_action, keycode)
	input_binding_changed.emit(normalized_action, keycode)
	_save_and_emit()
	return true


func reset_input_binding(action: String) -> bool:
	var normalized_action := action.strip_edges().to_lower()
	if normalized_action not in CONFIGURABLE_INPUT_ACTIONS:
		return false
	var default_keycode: Key = int(DEFAULT_INPUT_BINDINGS.get(normalized_action, KEY_NONE))
	return set_input_binding(normalized_action, default_keycode)


func get_input_binding_keycode(action: String) -> Key:
	var normalized_action := action.strip_edges().to_lower()
	var keycode: Key = int(input_bindings.get(
		normalized_action,
		DEFAULT_INPUT_BINDINGS.get(normalized_action, KEY_NONE)
	))
	return keycode


func get_input_binding_label(action: String) -> String:
	var keycode := get_input_binding_keycode(action)
	var label := OS.get_keycode_string(keycode).strip_edges()
	return label if not label.is_empty() else "?"


func set_selected_mount_id(movement_mode: String, mount_id: String) -> bool:
	var normalized_mode := movement_mode.strip_edges().to_lower()
	if normalized_mode not in MountServiceScript.AVAILABLE_MOVEMENT_MODES:
		return false
	var resolved_mount_id := MountServiceScript.resolve_mount_id_for_mode(
		mount_id,
		normalized_mode
	)
	if resolved_mount_id == "":
		return false
	if get_selected_mount_id(normalized_mode) == resolved_mount_id:
		return true

	if normalized_mode == MOUNT_MODE_LAND:
		selected_land_mount_id = resolved_mount_id
	else:
		selected_surf_mount_id = resolved_mount_id
	mount_loadout_changed.emit(normalized_mode, resolved_mount_id)
	_save_and_emit()
	return true


func set_cursor_scale(value: float) -> void:
	var validated_scale := _validated_cursor_scale(value)
	if is_equal_approx(cursor_scale, validated_scale):
		return

	cursor_scale = validated_scale
	CursorThemeManager.set_cursor_scale(cursor_scale)
	_save_and_emit()


func set_locale(value: String) -> void:
	var validated_locale: String = LocalizationManager.normalize_locale(value)
	if locale == validated_locale:
		LocalizationManager.set_locale(locale)
		return

	locale = validated_locale
	LocalizationManager.set_locale(locale)
	_save_and_emit()


func set_content_name_language(value: String) -> void:
	var validated_value := _validated_content_name_language(value)
	if content_name_language == validated_value:
		return

	content_name_language = validated_value
	_save_and_emit()
	LocalizationManager.refresh_current_locale()


func get_content_name_locale() -> String:
	return (
		LocalizationManager.DEFAULT_LOCALE
		if content_name_language == CONTENT_NAME_LANGUAGE_ENGLISH
		else LocalizationManager.current_locale
	)


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


func set_pokemon_cry_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(pokemon_cry_volume, validated_volume):
		return

	pokemon_cry_volume = validated_volume
	_apply_audio_bus_volume(POKEMON_CRY_BUS, pokemon_cry_volume)
	_save_and_emit()


func set_ui_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(ui_volume, validated_volume):
		return

	ui_volume = validated_volume
	_apply_audio_bus_volume(UI_BUS, ui_volume)
	_save_and_emit()


func set_notification_volume(volume: float) -> void:
	var validated_volume: float = _validated_volume(volume)
	if is_equal_approx(notification_volume, validated_volume):
		return

	notification_volume = validated_volume
	_apply_audio_bus_volume(NOTIFICATION_BUS, notification_volume)
	_save_and_emit()


func set_battle_music_track(track_id: String) -> void:
	var validated_track_id: String = track_id.strip_edges()
	if validated_track_id == "":
		validated_track_id = BATTLE_MUSIC_DEFAULT
	if battle_music_track == validated_track_id:
		return

	battle_music_track = validated_track_id
	_save_and_emit()


func set_enabled_language_chats(channels: Array[String]) -> void:
	var validated_channels := _validated_language_chats(channels)
	if enabled_language_chats == validated_channels:
		return

	enabled_language_chats = validated_channels
	_save_and_emit()


func reset_enabled_language_chats() -> void:
	set_enabled_language_chats([])


func _save_and_emit() -> void:
	save_settings()
	settings_changed.emit()


func _validated_sprite_style(style: String) -> String:
	match style:
		SPRITE_STYLE_ANIMATED, SPRITE_STYLE_STATIC:
			return style
		SPRITE_STYLE_GEN5_ANIMATED:
			if is_gen5_animated_sprites_installed():
				return style
			return SPRITE_STYLE_ANIMATED
		_:
			return SPRITE_STYLE_ANIMATED


func _validated_content_name_language(value: String) -> String:
	return (
		CONTENT_NAME_LANGUAGE_LOCALIZED
		if value == CONTENT_NAME_LANGUAGE_LOCALIZED
		else CONTENT_NAME_LANGUAGE_ENGLISH
	)


func _default_content_name_language(interface_locale: String) -> String:
	return (
		CONTENT_NAME_LANGUAGE_LOCALIZED
		if LocalizationManager.normalize_locale(interface_locale) in ["pt_BR", "zh_CN"]
		else CONTENT_NAME_LANGUAGE_ENGLISH
	)


func _validated_volume(volume: Variant) -> float:
	return clampf(float(volume), 0.0, 100.0)


func _validated_cursor_scale(value: Variant) -> float:
	return clampf(float(value), MIN_CURSOR_SCALE, MAX_CURSOR_SCALE)


func _validated_language_chats(value: Variant) -> Array[String]:
	var channels: Array[String] = []
	if value is Array:
		for channel_value: Variant in value as Array:
			var channel := str(channel_value)
			if channel in AVAILABLE_LANGUAGE_CHATS and not channels.has(channel):
				channels.append(channel)
	return channels


func _validated_input_bindings(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if value is Dictionary else {}
	var bindings := DEFAULT_INPUT_BINDINGS.duplicate()
	for action: String in CONFIGURABLE_INPUT_ACTIONS:
		var keycode := int(source.get(action, bindings.get(action, KEY_NONE)))
		if keycode != int(KEY_NONE):
			bindings[action] = keycode
	return bindings


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
	_ensure_audio_bus(POKEMON_CRY_BUS)
	_ensure_audio_bus(UI_BUS)
	_ensure_audio_bus(NOTIFICATION_BUS)


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, MASTER_BUS)


func _apply_runtime_settings() -> void:
	_apply_pixel_rendering_defaults()
	_apply_input_bindings()
	LocalizationManager.set_locale(locale)
	CursorThemeManager.set_cursor_scale(cursor_scale)
	_apply_audio_settings()
	_apply_display_settings()


func _apply_input_bindings() -> void:
	for action: String in CONFIGURABLE_INPUT_ACTIONS:
		_apply_input_binding(action, get_input_binding_keycode(action))


func _apply_input_binding(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action) or keycode == KEY_NONE:
		return
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _apply_pixel_rendering_defaults() -> void:
	if get_tree() == null:
		return
	var root_viewport := get_tree().root
	root_viewport.snap_2d_transforms_to_pixel = true
	root_viewport.snap_2d_vertices_to_pixel = true


func _apply_audio_settings() -> void:
	_apply_audio_bus_volume(MASTER_BUS, master_volume)
	_apply_audio_bus_volume(MUSIC_BUS, music_volume)
	_apply_audio_bus_volume(SFX_BUS, sfx_volume)
	_apply_audio_bus_volume(POKEMON_CRY_BUS, pokemon_cry_volume)
	_apply_audio_bus_volume(UI_BUS, ui_volume)
	_apply_audio_bus_volume(NOTIFICATION_BUS, notification_volume)


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
