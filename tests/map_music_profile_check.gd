extends SceneTree

const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const MUSIC_CATALOG_PATH := "res://data/music_catalog.json"
const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const POKEMON_CENTER_TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const PALLET_TOWN_TRACK_ID := "overworld.kanto.pallet_town"
const OAKS_LAB_TRACK_ID := "overworld.kanto.interior.oaks_lab"
const POKEMON_CENTER_TRACK_ID := "overworld.kanto.interior.pokemon_center"
const PALLET_TOWN_TRACK := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"
const OAKS_LAB_TRACK := "res://assets/music/overworld/kanto/interiors/oaks_lab.ogg"
const POKEMON_CENTER_TRACK := "res://assets/music/overworld/kanto/interiors/pokemon_center.ogg"

var failed := false


func _init() -> void:
	var inherited_interior := MapMetadataScript.new()
	inherited_interior.music_profile_id = "kanto.pallet_town"
	_check_equal(inherited_interior.get_music_profile_id(), "kanto.pallet_town", "Map metadata exposes its music profile")
	_check_equal(inherited_interior.get_music_track_id(), "", "A regular interior has no explicit music override")

	var catalog := JSON.parse_string(FileAccess.get_file_as_string(MUSIC_CATALOG_PATH)) as Dictionary
	var tracks: Dictionary = catalog.get("tracks", {}) as Dictionary
	var profiles: Dictionary = catalog.get("map_profiles", {}) as Dictionary
	_check_equal(str(profiles.get("kanto.pallet_town", "")), PALLET_TOWN_TRACK_ID, "Pallet Town profile resolves to its catalog track")
	_check_equal(str((tracks.get(PALLET_TOWN_TRACK_ID, {}) as Dictionary).get("path", "")), PALLET_TOWN_TRACK, "Pallet Town catalog track has the expected path")
	inherited_interior.music_track_id = OAKS_LAB_TRACK_ID
	_check_equal(inherited_interior.get_music_track_id(), OAKS_LAB_TRACK_ID, "An explicit interior catalog track is exposed")

	_check_scene_track(PLAYERS_HOUSE_SCENE_PATH, 'music_profile_id = "kanto.pallet_town"', "Player's House inherits Pallet Town music")
	_check_scene_track(OAKS_LAB_SCENE_PATH, 'music_track_id = "%s"' % OAKS_LAB_TRACK_ID, "Oak's Lab uses its dedicated catalog track")
	_check_scene_track(POKEMON_CENTER_TEMPLATE_PATH, 'music_track_id = "%s"' % POKEMON_CENTER_TRACK_ID, "Pokémon Centers use their dedicated catalog track")
	_check(FileAccess.file_exists(OAKS_LAB_TRACK), "Oak's Lab OGG is included in the project")
	_check(FileAccess.file_exists(POKEMON_CENTER_TRACK), "Pokémon Center OGG is included in the project")

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
