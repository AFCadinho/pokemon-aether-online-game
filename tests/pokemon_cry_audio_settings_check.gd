extends SceneTree

const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"
const SETTINGS_SCENE_PATH := "res://scenes/interface/settings/settings_menu.tscn"
const SFX_MANAGER_PATH := "res://scripts/services/sfx_manager.gd"
const ANIME_CRY_IMPORTER_PATH := "res://tools/import_anime_cries.py"

var failed := false


func _init() -> void:
	var settings_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var menu_source := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)
	var scene_source := FileAccess.get_file_as_string(SETTINGS_SCENE_PATH)
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER_PATH)
	var importer_source := FileAccess.get_file_as_string(ANIME_CRY_IMPORTER_PATH)

	_check_contains(settings_source, 'const POKEMON_CRY_BUS := "Pokemon Cries"', "settings define a Pokémon cry audio bus")
	_check_contains(settings_source, '"pokemon_cry_volume": pokemon_cry_volume', "cry volume is persisted")
	_check_contains(settings_source, "func set_pokemon_cry_volume", "cry volume has a setter")
	_check(not settings_source.contains("\"anime_pokemon_cries\": anime_pokemon_cries"), "anime cry selection is no longer persisted in settings")
	_check(not settings_source.contains("\"sprite_style\": sprite_style"), "sprite selection is no longer persisted in settings")
	_check_contains(scene_source, '[node name="PokemonCryVolumeSlider"', "settings scene has a cry volume slider")
	_check(not scene_source.contains("AnimePokemonCriesCheckBox"), "settings scene has no anime cry toggle")
	_check(not scene_source.contains("SpriteStyleOptionsButton"), "settings scene has no sprite selector")
	_check_contains(menu_source, "SettingsManager.set_pokemon_cry_volume(value)", "cry slider updates settings")
	_check(not menu_source.contains("anime_pokemon_cries"), "settings menu has no anime cry preference")
	_check(not menu_source.contains("sprite_style_options_button"), "settings menu has no sprite selector")
	_check_contains(sfx_source, "get_cry_path(species, false)", "base cry path remains available when no mod is enabled")
	_check_contains(sfx_source, "ContentPacks.cry(species)", "enabled cry packs override the base cry")
	_check_contains(sfx_source, "SettingsManager.get_audio_output_bus(SettingsManager.POKEMON_CRY_BUS)", "Pokémon cries retain their own bus on desktop and route safely on web")
	_check_contains(importer_source, "mean_loudness", "anime cry import measures loudness")
	_check_contains(importer_source, "alimiter=limit={PEAK_LIMIT}", "anime cry import limits normalized peaks")

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		return

	failed = true
	push_error(label)
