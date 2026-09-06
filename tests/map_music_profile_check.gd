extends SceneTree

const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const MUSIC_MANAGER_SCRIPT_PATH := "res://scripts/services/music_manager.gd"
const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const POKEMON_CENTER_TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const PALLET_TOWN_TRACK := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"
const OAKS_LAB_TRACK := "res://assets/music/overworld/kanto/interiors/oaks_lab.ogg"
const POKEMON_CENTER_TRACK := "res://assets/music/overworld/kanto/interiors/pokemon_center.ogg"
const AETHER_CLASH_DUEL_TRACK := "res://assets/music/overworld/aether_clash/aether_clash_duel.ogg"

var failed := false


func _init() -> void:
	var inherited_interior := MapMetadataScript.new()
	inherited_interior.music_profile_id = "kanto.pallet_town"
	_check_equal(inherited_interior.get_music_profile_id(), "kanto.pallet_town", "Map metadata exposes its music profile")
	_check_equal(inherited_interior.get_music_track_path(), "", "A regular interior has no explicit music override")

	var music_manager_source := FileAccess.get_file_as_string(MUSIC_MANAGER_SCRIPT_PATH)
	_check(
		music_manager_source.contains('"kanto.pallet_town": "%s"' % PALLET_TOWN_TRACK),
		"Pallet Town profile resolves to its town track"
	)
	inherited_interior.music_track_path = OAKS_LAB_TRACK
	_check(
		music_manager_source.find("if map_track_path != \"\":") < music_manager_source.find("get_music_profile_track_path"),
		"An explicit interior track is resolved before a music profile"
	)
	_check(
		music_manager_source.contains('AETHER_CLASH_DUEL_MUSIC_PATH := "%s"' % AETHER_CLASH_DUEL_TRACK),
		"Aether Clash Duel has a dedicated map track"
	)

	_check_scene_track(PLAYERS_HOUSE_SCENE_PATH, 'music_profile_id = "kanto.pallet_town"', "Player's House inherits Pallet Town music")
	_check_scene_track(OAKS_LAB_SCENE_PATH, 'music_track_path = "%s"' % OAKS_LAB_TRACK, "Oak's Lab uses its dedicated music")
	_check_scene_track(POKEMON_CENTER_TEMPLATE_PATH, 'music_track_path = "%s"' % POKEMON_CENTER_TRACK, "Pokémon Centers use their dedicated music")
	_check(FileAccess.file_exists(OAKS_LAB_TRACK), "Oak's Lab OGG is included in the project")
	_check(FileAccess.file_exists(POKEMON_CENTER_TRACK), "Pokémon Center OGG is included in the project")
	_check(FileAccess.file_exists(AETHER_CLASH_DUEL_TRACK), "Aether Clash Duel OGG is included in the project")

	inherited_interior.free()
	quit(1 if failed else 0)


func _check_scene_track(scene_path: String, expected_setting: String, label: String) -> void:
	var scene_source := FileAccess.get_file_as_string(scene_path)
	_check(scene_source.contains(expected_setting), label)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])
