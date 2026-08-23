extends SceneTree

const PLAYER_PATH := "res://scripts/world/player.gd"
const MAP_METADATA_PATH := "res://scripts/world/map_metadata.gd"
const FLOOR_PATHS := {
	"kanto_mt_moon_1f": "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
	"kanto_mt_moon_b1f": "res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
	"kanto_mt_moon_b2f": "res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
}

var failed := false


func _init() -> void:
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	_check(player_source.contains('const ENCOUNTER_TYPE_CAVE := "cave"'), "player defines cave encounters")
	_check(
		player_source.contains("elif _is_cave_encounter_map():")
		and player_source.contains("check_for_wild_encounter(ENCOUNTER_TYPE_CAVE)"),
		"walking through configured caves can trigger wild encounters"
	)

	var metadata_source := FileAccess.get_file_as_string(MAP_METADATA_PATH)
	_check(metadata_source.contains("var cave_encounter_chance := 0.0"), "maps expose cave encounter chance")
	_check(metadata_source.contains('encounter_types.get("cave", {})'), "maps load cave encounter metadata")

	for area_id: String in FLOOR_PATHS:
		var floor_source := FileAccess.get_file_as_string(FLOOR_PATHS[area_id])
		_check(
			floor_source.contains('encounter_area_id = "%s"' % area_id),
			"%s uses its floor-specific encounter table" % area_id
		)
		_check(floor_source.contains("cave_encounter_chance = 0.07"), "%s enables cave encounters" % area_id)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
