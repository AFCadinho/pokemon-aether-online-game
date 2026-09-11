extends SceneTree

const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"
const SETTINGS_SCENE_PATH := "res://scenes/interface/settings/settings_menu.tscn"
const SFX_MANAGER_PATH := "res://scripts/services/sfx_manager.gd"

var failed := false


func _init() -> void:
	var settings_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var menu_source := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)
	var scene_source := FileAccess.get_file_as_string(SETTINGS_SCENE_PATH)
	var sfx_source := FileAccess.get_file_as_string(SFX_MANAGER_PATH)

	_check_contains(settings_source, 'const POKEMON_CRY_BUS := "Pokemon Cries"', "settings define a Pokémon cry audio bus")
	_check_contains(settings_source, '"pokemon_cry_volume": pokemon_cry_volume', "cry volume is persisted")
	_check_contains(settings_source, "func set_pokemon_cry_volume", "cry volume has a setter")
	_check_contains(scene_source, '[node name="PokemonCryVolumeSlider"', "settings scene has a cry volume slider")
	_check_contains(menu_source, "SettingsManager.set_pokemon_cry_volume(value)", "cry slider updates settings")
	_check_contains(sfx_source, "SettingsManager.get_audio_output_bus(SettingsManager.POKEMON_CRY_BUS)", "Pokémon cries retain their own bus on desktop and route safely on web")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		return

	failed = true
	push_error(label)
