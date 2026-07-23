extends SceneTree

const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const EXPECTED_INITIAL_POSITION := Vector2(304, 336)

var failed := false


func _init() -> void:
	_check_world_initial_map()
	_check_players_house_initial_spawn()
	quit(1 if failed else 0)


func _check_world_initial_map() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_SCENE_PATH)
	var world_script_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains('path="%s"' % PLAYERS_HOUSE_SCENE_PATH),
		"World starts without-saved-state players in Player's House"
	)
	_check(
		world_source.contains('[node name="PlayersHouse" parent="CurrentMap"'),
		"World instances Player's House as its initial map"
	)
	_check(
		world_script_source.contains('@export var initial_spawn_name := "InitialSpawn"'),
		"World uses the InitialSpawn marker for players without saved state"
	)
	_check(
		world_script_source.contains("if not saved_state.is_empty():"),
		"Saved player positions still take precedence over the initial spawn"
	)


func _check_players_house_initial_spawn() -> void:
	var players_house_source := FileAccess.get_file_as_string(PLAYERS_HOUSE_SCENE_PATH)
	_check(
		players_house_source.contains('[node name="InitialSpawn" type="Marker2D" parent="Spawns"]'),
		"Player's House exposes Spawns/InitialSpawn"
	)
	_check(
		players_house_source.contains("position = Vector2(%d, %d)" % [
			int(EXPECTED_INITIAL_POSITION.x),
			int(EXPECTED_INITIAL_POSITION.y),
		]),
		"InitialSpawn is centered in the player's upstairs bedroom"
	)
	_check(
		players_house_source.contains('&"upper_floor": Rect2(160, 0, 320, 448)'),
		"Player's House keeps InitialSpawn inside its upper-floor visibility region"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
