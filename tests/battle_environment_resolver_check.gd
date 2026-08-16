extends SceneTree

const Resolver := preload("res://scripts/battle/battle_environment_resolver.gd")
const Catalog := preload("res://scripts/battle/battle_environment_catalog.gd")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const MAP_METADATA_SCRIPT_PATH := "res://scripts/world/map_metadata.gd"
const BASE_NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"

var failed := false


func _init() -> void:
	_check_resolution_priority()
	_check_world_integration_contract()
	_check_configuration_contract()
	quit(1 if failed else 0)


func _check_resolution_priority() -> void:
	_check_equal(
		Resolver.resolve({
			"battle_kind": "wild",
			"explicit_environment_id": "cave",
			"encounter_type": "surf",
			"player_on_water": true,
			"map_environment_id": "water",
		}),
		Catalog.CAVE_ENVIRONMENT_ID,
		"explicit encounter or trainer override wins"
	)
	_check_equal(
		Resolver.resolve({"battle_kind": "pvp", "map_environment_id": "cave"}),
		Catalog.PVP_STADIUM_ENVIRONMENT_ID,
		"PvP defaults to its stadium"
	)
	for encounter_type: String in ["surf", "fish", "old-rod", "good_rod", "super rod"]:
		_check_equal(
			Resolver.resolve({
				"battle_kind": "wild",
				"encounter_type": encounter_type,
				"map_environment_id": "cave",
			}),
			Catalog.WATER_ENVIRONMENT_ID,
			"%s encounters use the water environment" % encounter_type
		)
	_check_equal(
		Resolver.resolve({
			"battle_kind": "wild",
			"player_on_water": true,
			"map_environment_id": "cave",
		}),
		Catalog.WATER_ENVIRONMENT_ID,
		"standing on a water tile overrides the map default"
	)
	_check_equal(
		Resolver.resolve({
			"battle_kind": "wild",
			"player_on_tall_grass": true,
			"map_environment_id": "cave",
		}),
		Catalog.DEFAULT_ENVIRONMENT_ID,
		"standing in tall grass selects the grass environment"
	)
	_check_equal(
		Resolver.resolve({
			"battle_kind": "wild",
			"encounter_type": "grass",
			"map_environment_id": "cave",
		}),
		Catalog.CAVE_ENVIRONMENT_ID,
		"a cave ground encounter is not mistaken for tall grass"
	)
	_check_equal(
		Resolver.resolve({"battle_kind": "trainer", "map_environment_id": "cave"}),
		Catalog.CAVE_ENVIRONMENT_ID,
		"trainer battles inherit the map environment"
	)
	_check_equal(
		Resolver.resolve({
			"battle_kind": "trainer",
			"explicit_environment_id": "water",
			"map_environment_id": "cave",
		}),
		Catalog.WATER_ENVIRONMENT_ID,
		"trainer environment overrides beat the map default"
	)
	_check_equal(
		Resolver.resolve({
			"battle_kind": "trainer",
			"explicit_environment_id": "unknown",
			"map_environment_id": "cave",
		}),
		Catalog.CAVE_ENVIRONMENT_ID,
		"unknown overrides fall through to a valid map default"
	)
	_check_equal(
		Resolver.resolve({"battle_kind": "trainer", "map_environment_id": "unknown"}),
		Catalog.DEFAULT_ENVIRONMENT_ID,
		"missing environment context falls back to grass"
	)


func _check_world_integration_contract() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check_true(world_source.contains('_resolve_battle_environment_id("wild", response, encounter_type)'), "wild battles resolve tile and map context")
	_check_true(world_source.contains('_resolve_battle_environment_id("trainer", battle_trainer_data)'), "trainer battles resolve override and map context")
	_check_true(world_source.contains('_resolve_battle_environment_id("pvp", response)'), "PvP resolves its explicit stadium context")
	_check_true(world_source.contains('player.call("is_standing_on_water")'), "world samples the player water tile before wild battles")
	_check_true(world_source.contains('player.call("is_standing_on_tall_grass")'), "world samples the player tall-grass tile before wild battles")


func _check_configuration_contract() -> void:
	var map_source := FileAccess.get_file_as_string(MAP_METADATA_SCRIPT_PATH)
	var npc_source := FileAccess.get_file_as_string(BASE_NPC_SCRIPT_PATH)
	_check_true(map_source.contains('var battle_environment_id := "grass"'), "maps expose a grass-default battle environment")
	_check_true(map_source.contains("func get_battle_environment_id()"), "maps expose their battle environment to the resolver")
	_check_true(npc_source.contains('battle_metadata["battleEnvironmentId"] = normalized_environment_id'), "trainer placements forward explicit environment overrides")
	for environment_id: StringName in [
		Catalog.DEFAULT_ENVIRONMENT_ID,
		Catalog.WATER_ENVIRONMENT_ID,
		Catalog.CAVE_ENVIRONMENT_ID,
		Catalog.PVP_STADIUM_ENVIRONMENT_ID,
	]:
		var profile := Catalog.get_profile(environment_id)
		_check_true(profile != null and profile.is_valid(), "%s environment profile is valid" % environment_id)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
