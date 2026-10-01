extends SceneTree

const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const MUSIC_CATALOG_PATH := "res://data/music_catalog.json"
const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const POKEMON_CENTER_TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const ROUTE_3_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const ROUTE_22_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_22.tscn"
const ROUTE_11_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_11.tscn"
const ROUTE_12_WEST_SCENE_PATH := "res://scenes/overworld/kanto/routes/connections/route_12_west.tscn"
const VERMILION_CITY_SCENE_PATH := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const SS_ANNE_SCENE_PATHS := [
	"res://scenes/overworld/kanto/towns/ss_anne/ss_anne_b1f.tscn",
	"res://scenes/overworld/kanto/towns/ss_anne/ss_anne_1f.tscn",
	"res://scenes/overworld/kanto/towns/ss_anne/ss_anne_2f.tscn",
	"res://scenes/overworld/kanto/towns/ss_anne/ss_anne_3f.tscn",
]
const CERULEAN_CITY_SCENE_PATH := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const PEWTER_GYM_SCENE_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn"
const CERULEAN_GYM_SCENE_PATH := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn"
const MT_MOON_SCENE_PATHS := [
	"res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
	"res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
	"res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
]
const PALLET_TOWN_TRACK_ID := "overworld.kanto.pallet_town"
const OAKS_LAB_TRACK_ID := "overworld.kanto.interior.oaks_lab"
const POKEMON_CENTER_TRACK_ID := "overworld.kanto.interior.pokemon_center"
const KANTO_ROUTE_GROUP_PROFILE_ID := "kanto.routes_3_10_16_22"
const KANTO_ROUTE_GROUP_TRACK_ID := "overworld.kanto.routes_3_10_16_22"
const MT_MOON_TRACK_ID := "overworld.kanto.cave.mt_moon"
const CERULEAN_CITY_TRACK_ID := "overworld.kanto.cerulean_city"
const GYM_PROFILE_ID := "gym.interior"
const GYM_TRACK_ID := "overworld.gym.black_white_remastered_zame"
const PALLET_TOWN_TRACK := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"
const OAKS_LAB_TRACK := "res://assets/music/overworld/kanto/interiors/oaks_lab.ogg"
const POKEMON_CENTER_TRACK := "res://assets/music/overworld/kanto/interiors/pokemon_center.ogg"
const KANTO_ROUTE_GROUP_TRACK := "res://assets/music/overworld/kanto/routes/kanto_routes_3_10_16_22.ogg"
const KANTO_ROUTES_11_15_PROFILE_ID := "kanto.routes_11_15"
const KANTO_ROUTES_11_15_TRACK_ID := "overworld.kanto.routes_11_15_zame"
const KANTO_ROUTES_11_15_TRACK := "res://assets/music/overworld/kanto/routes/kanto_routes_11_15.ogg"
const VERMILION_CITY_PROFILE_ID := "kanto.vermilion_city"
const VERMILION_CITY_TRACK_ID := "overworld.kanto.vermilion_city_remastered_zame"
const VERMILION_CITY_TRACK := "res://assets/music/overworld/kanto/towns/vermilion_city_remastered_zame.ogg"
const SS_ANNE_PROFILE_ID := "kanto.ss_anne"
const SS_ANNE_TRACK_ID := "overworld.kanto.ss_anne_zame"
const SS_ANNE_TRACK := "res://assets/music/overworld/kanto/towns/ss_anne.ogg"
const MT_MOON_TRACK := "res://assets/music/overworld/kanto/caves/mt_moon.ogg"
const CERULEAN_CITY_TRACK := "res://assets/music/overworld/kanto/towns/cerulean_city.ogg"
const GYM_TRACK := "res://assets/music/overworld/gyms/black_white_gym_theme_remastered_zame.ogg"
const AETHER_CLASH_DUEL_TRACK_ID := "overworld.aether_clash.duel"
const AETHER_CLASH_DUEL_TRACK := "res://assets/music/overworld/aether_clash/aether_clash_duel.ogg"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inherited_interior := MapMetadataScript.new()
	inherited_interior.music_profile_id = "kanto.pallet_town"
	_check_equal(inherited_interior.get_music_profile_id(), "kanto.pallet_town", "Map metadata exposes its music profile")
	_check_equal(inherited_interior.get_music_track_id(), "", "A regular interior has no explicit music override")

	var catalog := JSON.parse_string(FileAccess.get_file_as_string(MUSIC_CATALOG_PATH)) as Dictionary
	var tracks: Dictionary = catalog.get("tracks", {}) as Dictionary
	var profiles: Dictionary = catalog.get("map_profiles", {}) as Dictionary
	_check_equal(str(profiles.get("kanto.pallet_town", "")), PALLET_TOWN_TRACK_ID, "Pallet Town profile resolves to its catalog track")
	_check_equal(str((tracks.get(PALLET_TOWN_TRACK_ID, {}) as Dictionary).get("path", "")), PALLET_TOWN_TRACK, "Pallet Town catalog track has the expected path")
	_check_equal(str(profiles.get(KANTO_ROUTE_GROUP_PROFILE_ID, "")), KANTO_ROUTE_GROUP_TRACK_ID, "Kanto route group profile resolves to its catalog track")
	_check_equal(str((tracks.get(KANTO_ROUTE_GROUP_TRACK_ID, {}) as Dictionary).get("path", "")), KANTO_ROUTE_GROUP_TRACK, "Kanto route group catalog track has the expected path")
	_check_equal(str(profiles.get(KANTO_ROUTES_11_15_PROFILE_ID, "")), KANTO_ROUTES_11_15_TRACK_ID, "Routes 11–15 profile resolves to its catalog track")
	_check_equal(str((tracks.get(KANTO_ROUTES_11_15_TRACK_ID, {}) as Dictionary).get("path", "")), KANTO_ROUTES_11_15_TRACK, "Routes 11–15 catalog track has the expected path")
	_check_equal(str(profiles.get(VERMILION_CITY_PROFILE_ID, "")), VERMILION_CITY_TRACK_ID, "Vermilion City profile resolves to its catalog track")
	_check_equal(str((tracks.get(VERMILION_CITY_TRACK_ID, {}) as Dictionary).get("path", "")), VERMILION_CITY_TRACK, "Vermilion City catalog track has the expected path")
	_check_equal(str(profiles.get(SS_ANNE_PROFILE_ID, "")), SS_ANNE_TRACK_ID, "S.S. Anne profile resolves to its catalog track")
	_check_equal(str((tracks.get(SS_ANNE_TRACK_ID, {}) as Dictionary).get("path", "")), SS_ANNE_TRACK, "S.S. Anne catalog track has the expected path")
	inherited_interior.music_track_id = OAKS_LAB_TRACK_ID
	_check_equal(inherited_interior.get_music_track_id(), OAKS_LAB_TRACK_ID, "An explicit interior catalog track is exposed")

	_check_scene_track(PLAYERS_HOUSE_SCENE_PATH, 'music_profile_id = "kanto.pallet_town"', "Player's House inherits Pallet Town music")
	_check_scene_track(OAKS_LAB_SCENE_PATH, 'music_track_id = "%s"' % OAKS_LAB_TRACK_ID, "Oak's Lab uses its dedicated catalog track")
	_check_scene_track(POKEMON_CENTER_TEMPLATE_PATH, 'music_track_id = "%s"' % POKEMON_CENTER_TRACK_ID, "Pokémon Centers use their dedicated catalog track")
	_check_scene_track(ROUTE_3_SCENE_PATH, 'music_profile_id = "%s"' % KANTO_ROUTE_GROUP_PROFILE_ID, "Route 3 uses the shared Kanto route group profile")
	_check_scene_track(ROUTE_22_SCENE_PATH, 'music_profile_id = "%s"' % KANTO_ROUTE_GROUP_PROFILE_ID, "Route 22 uses the shared Kanto route group profile")
	_check_scene_track(ROUTE_11_SCENE_PATH, 'music_profile_id = "%s"' % KANTO_ROUTES_11_15_PROFILE_ID, "Route 11 uses the Routes 11–15 profile")
	_check_scene_track(ROUTE_12_WEST_SCENE_PATH, 'music_profile_id = "%s"' % KANTO_ROUTES_11_15_PROFILE_ID, "Route 12 West uses the Routes 11–15 profile")
	_check_scene_track(VERMILION_CITY_SCENE_PATH, 'music_profile_id = "%s"' % VERMILION_CITY_PROFILE_ID, "Vermilion City uses its remastered profile")
	for scene_path: String in SS_ANNE_SCENE_PATHS:
		_check_scene_track(scene_path, 'music_profile_id = "%s"' % SS_ANNE_PROFILE_ID, "%s uses the S.S. Anne profile" % scene_path)
	_check_equal(str((tracks.get(MT_MOON_TRACK_ID, {}) as Dictionary).get("path", "")), MT_MOON_TRACK, "Mt. Moon catalog track has the expected path")
	for scene_path: String in MT_MOON_SCENE_PATHS:
		_check_scene_track(scene_path, 'music_track_id = "%s"' % MT_MOON_TRACK_ID, "%s uses the dedicated Mt. Moon track" % scene_path)
	_check_equal(str((tracks.get(CERULEAN_CITY_TRACK_ID, {}) as Dictionary).get("path", "")), CERULEAN_CITY_TRACK, "Cerulean City catalog track has the expected path")
	_check_scene_track(CERULEAN_CITY_SCENE_PATH, 'music_track_id = "%s"' % CERULEAN_CITY_TRACK_ID, "Cerulean City uses its dedicated catalog track")
	_check_equal(str(profiles.get(GYM_PROFILE_ID, "")), GYM_TRACK_ID, "Gym interior profile resolves to its catalog track")
	_check_equal(str((tracks.get(GYM_TRACK_ID, {}) as Dictionary).get("path", "")), GYM_TRACK, "Gym catalog track has the expected path")
	_check_equal(str(profiles.get("aether_clash.duel", "")), AETHER_CLASH_DUEL_TRACK_ID, "Aether Clash Duel profile resolves to its dedicated track")
	_check_equal(str((tracks.get(AETHER_CLASH_DUEL_TRACK_ID, {}) as Dictionary).get("path", "")), AETHER_CLASH_DUEL_TRACK, "Aether Clash Duel catalog track has the expected path")
	_check_scene_track(PEWTER_GYM_SCENE_PATH, 'music_profile_id = "%s"' % GYM_PROFILE_ID, "Pewter Gym uses the shared gym interior profile")
	_check_scene_track(CERULEAN_GYM_SCENE_PATH, 'music_profile_id = "%s"' % GYM_PROFILE_ID, "Cerulean Gym uses the shared gym interior profile")
	_check(FileAccess.file_exists(OAKS_LAB_TRACK), "Oak's Lab OGG is included in the project")
	_check(FileAccess.file_exists(POKEMON_CENTER_TRACK), "Pokémon Center OGG is included in the project")
	_check(FileAccess.file_exists(MT_MOON_TRACK), "Mt. Moon OGG is included in the project")
	_check(FileAccess.file_exists(CERULEAN_CITY_TRACK), "Cerulean City OGG is included in the project")
	_check(FileAccess.file_exists(KANTO_ROUTES_11_15_TRACK), "Routes 11–15 OGG is included in the project")
	_check(FileAccess.file_exists(VERMILION_CITY_TRACK), "Vermilion City OGG is included in the project")
	_check(FileAccess.file_exists(SS_ANNE_TRACK), "S.S. Anne OGG is included in the project")
	_check(FileAccess.file_exists(GYM_TRACK), "Gym OGG is included in the project")
	_check(FileAccess.file_exists(AETHER_CLASH_DUEL_TRACK), "Aether Clash Duel OGG is included in the project")
	_check(ResourceLoader.exists(CERULEAN_CITY_TRACK), "Godot recognizes the Cerulean City OGG resource")
	var cerulean_stream := load(CERULEAN_CITY_TRACK) as AudioStream
	_check(cerulean_stream != null and cerulean_stream.get_length() > 130.0, "Cerulean City OGG decodes as a complete audio stream")
	_check(ResourceLoader.exists(GYM_TRACK), "Godot recognizes the gym OGG resource")
	var gym_stream := load(GYM_TRACK) as AudioStream
	_check(gym_stream != null and gym_stream.get_length() > 70.0, "Gym OGG decodes as a complete audio stream")
	for track_path: String in [KANTO_ROUTES_11_15_TRACK, VERMILION_CITY_TRACK, SS_ANNE_TRACK]:
		_check(ResourceLoader.exists(track_path), "%s is recognized as a Godot resource" % track_path)
		var music_stream := load(track_path) as AudioStream
		_check(music_stream != null and music_stream.get_length() > 120.0, "%s decodes as a complete audio stream" % track_path)

	var lavender_track := "res://assets/music/overworld/kanto/towns/lavender_town_remastered_zame.ogg"
	var lavender_stream := load(lavender_track) as AudioStreamOggVorbis
	_check(lavender_stream != null and absf(lavender_stream.get_length() - 160.04) < 1.0,
		"Lavender Town OGG decodes with the complete source duration")
	var music_manager := load("res://scripts/services/music_manager.gd").new() as Node
	for scene_path: String in [
		"res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn",
	]:
		var map := (load(scene_path) as PackedScene).instantiate()
		_check_equal(music_manager.call("get_map_music_path", map), lavender_track,
			"%s resolves Lavender Town music through the runtime manager" % scene_path)
		map.free()
	music_manager.free()
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
