extends Node

signal settings_changed

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
const CHAT_TAB_ALL := "all"
const CHAT_TAB_GENERAL := "general"
const CHAT_TAB_MAP := "map"
const CHAT_TAB_SYSTEM := "system"
const CHAT_TAB_PM := "pm"
const CHAT_TAB_GUILD := "guild"
const LEGACY_CHAT_TAB_CLAN := "clan"
const DEFAULT_LOCALE := "en"
const DEFAULT_CHAT_TAB_ORDER: Array[String] = [
	CHAT_TAB_ALL,
	CHAT_TAB_GENERAL,
	CHAT_TAB_SYSTEM,
	CHAT_TAB_MAP,
	CHAT_TAB_PM,
	CHAT_TAB_GUILD,
]
const DEFAULT_WINDOW_RESOLUTION := Vector2i(1600, 900)
const AVAILABLE_WINDOW_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var battle_animations := true
var weather_effects := true
var terrain_effects := true
var display_own_name := true
var sprite_style := SPRITE_STYLE_ANIMATED
var fullscreen := false
var window_resolution := DEFAULT_WINDOW_RESOLUTION
var master_volume := 80.0
var music_volume := 55.0
var sfx_volume := 75.0
var pokemon_cry_volume := 75.0
var ui_volume := 75.0
var notification_volume := 75.0
var battle_music_track := BATTLE_MUSIC_DEFAULT
var locale := DEFAULT_LOCALE
var chat_tab_visibility: Dictionary = {
	CHAT_TAB_ALL: true,
	CHAT_TAB_GENERAL: true,
	CHAT_TAB_MAP: true,
	CHAT_TAB_SYSTEM: true,
	CHAT_TAB_PM: true,
	CHAT_TAB_GUILD: true,
}
var chat_tab_order: Array[String] = DEFAULT_CHAT_TAB_ORDER.duplicate()


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	_apply_runtime_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		locale = LocalizationManager.get_preferred_system_locale()
		_apply_launcher_locale_argument()
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
	sprite_style = _validated_sprite_style(str(data.get("sprite_style", sprite_style)))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	window_resolution = _validated_window_resolution(data.get("window_resolution", window_resolution))
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
	chat_tab_visibility = _validated_chat_tab_visibility(data.get("chat_tab_visibility", chat_tab_visibility))
	chat_tab_order = _validated_chat_tab_order(data.get("chat_tab_order", chat_tab_order))
	if _apply_launcher_locale_argument():
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
		"sprite_style": sprite_style,
		"fullscreen": fullscreen,
		"window_resolution": {
			"width": window_resolution.x,
			"height": window_resolution.y,
		},
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"pokemon_cry_volume": pokemon_cry_volume,
		"ui_volume": ui_volume,
		"notification_volume": notification_volume,
		"battle_music_track": battle_music_track,
		"locale": locale,
		"chat_tab_visibility": chat_tab_visibility,
		"chat_tab_order": chat_tab_order,
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


func set_locale(value: String) -> void:
	var validated_locale: String = LocalizationManager.normalize_locale(value)
	if locale == validated_locale:
		LocalizationManager.set_locale(locale)
		return

	locale = validated_locale
	LocalizationManager.set_locale(locale)
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


func set_chat_tab_preferences(visibility: Dictionary, order: Array[String]) -> void:
	var validated_visibility := _validated_chat_tab_visibility(visibility)
	var validated_order := _validated_chat_tab_order(order)
	if chat_tab_visibility == validated_visibility and chat_tab_order == validated_order:
		return

	chat_tab_visibility = validated_visibility
	chat_tab_order = validated_order
	_save_and_emit()


func reset_chat_tab_preferences() -> void:
	set_chat_tab_preferences({
		CHAT_TAB_ALL: true,
		CHAT_TAB_GENERAL: true,
		CHAT_TAB_MAP: true,
		CHAT_TAB_SYSTEM: true,
		CHAT_TAB_PM: true,
		CHAT_TAB_GUILD: true,
	}, DEFAULT_CHAT_TAB_ORDER.duplicate())


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


func _validated_volume(volume: Variant) -> float:
	return clampf(float(volume), 0.0, 100.0)


func _validated_chat_tab_visibility(value: Variant) -> Dictionary:
	var source: Dictionary = value as Dictionary if value is Dictionary else {}
	if not source.has(CHAT_TAB_GUILD) and source.has(LEGACY_CHAT_TAB_CLAN):
		source = source.duplicate()
		source[CHAT_TAB_GUILD] = source.get(LEGACY_CHAT_TAB_CLAN, true)
	var visibility: Dictionary = {}
	for tab_id: String in DEFAULT_CHAT_TAB_ORDER:
		visibility[tab_id] = (
			true
			if tab_id in [CHAT_TAB_ALL, CHAT_TAB_GENERAL]
			else bool(source.get(tab_id, true))
		)
	return visibility


func _validated_chat_tab_order(value: Variant) -> Array[String]:
	var order: Array[String] = []
	if value is Array:
		for tab_value: Variant in value as Array:
			var tab_id := str(tab_value)
			if tab_id == LEGACY_CHAT_TAB_CLAN:
				tab_id = CHAT_TAB_GUILD
			if tab_id in DEFAULT_CHAT_TAB_ORDER and not order.has(tab_id):
				order.append(tab_id)
	if not order.has(CHAT_TAB_ALL):
		order.push_front(CHAT_TAB_ALL)
	if not order.has(CHAT_TAB_MAP):
		var system_index := order.find(CHAT_TAB_SYSTEM)
		if system_index >= 0:
			order.insert(system_index + 1, CHAT_TAB_MAP)
	for tab_id: String in DEFAULT_CHAT_TAB_ORDER:
		if not order.has(tab_id):
			order.append(tab_id)
	return order


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
	LocalizationManager.set_locale(locale)
	_apply_audio_settings()
	_apply_display_settings()


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
