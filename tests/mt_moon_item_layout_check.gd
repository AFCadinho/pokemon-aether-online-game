extends SceneTree

const TILE_SIZE := 32
const FLOOR_SCENES := {
	"1f": "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
	"b1f": "res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
	"b2f": "res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
}
const ROCK_POSITIONS := {
	"1f": [Vector2i(400, 720), Vector2i(720, 1120), Vector2i(2384, 1104)],
	"b1f": [Vector2i(560, 544), Vector2i(2192, 176), Vector2i(2352, 1584)],
	"b2f": [Vector2i(784, 336), Vector2i(1456, 1296), Vector2i(816, 2192)],
}
const PICKUP_POSITIONS := {
	"1f": [
		Vector2i(208, 240), Vector2i(1424, 208), Vector2i(2608, 208),
		Vector2i(2576, 1296), Vector2i(272, 2192), Vector2i(2608, 2192),
	],
	"b1f": [],
	"b2f": [
		Vector2i(432, 336), Vector2i(528, 336), Vector2i(2096, 464),
		Vector2i(464, 1232), Vector2i(1712, 1424), Vector2i(2192, 2160),
	],
}
const EXPECTED_PICKUPS := [
	["kanto_mt_moon_1f_tm_bullet_seed", "tm-bullet-seed"],
	["kanto_mt_moon_1f_paralyze_heal", "paralyze-heal"],
	["kanto_mt_moon_1f_potion", "potion"],
	["kanto_mt_moon_1f_rare_candy", "rare-candy"],
	["kanto_mt_moon_1f_great_ball", "great-ball"],
	["kanto_mt_moon_1f_moon_stone", "moon-stone"],
	["kanto_mt_moon_b2f_tm_thief", "tm-thief"],
	["kanto_mt_moon_b2f_revive", "revive"],
	["kanto_mt_moon_b2f_star_piece", "star-piece"],
	["kanto_mt_moon_b2f_helix_fossil", "helix-fossil"],
	["kanto_mt_moon_b2f_dome_fossil", "dome-fossil"],
	["kanto_mt_moon_b2f_antidote", "antidote"],
]

var failed := false


func _init() -> void:
	var all_scene_source := ""
	for floor_id: String in FLOOR_SCENES:
		var scene_source := FileAccess.get_file_as_string(FLOOR_SCENES[floor_id])
		all_scene_source += scene_source
		var blocked_cells := _collision_cells(scene_source)
		for position: Vector2i in PICKUP_POSITIONS[floor_id]:
			var tile := _tile_for_position(position)
			_check(not blocked_cells.has(tile), "%s item pickup is placed on walkable floor: %s" % [floor_id, position])
		for position: Vector2i in ROCK_POSITIONS[floor_id]:
			var tile := _tile_for_position(position)
			_check(not blocked_cells.has(tile), "%s Rock Smash tile is walkable before placement: %s" % [floor_id, position])
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_check(
					not blocked_cells.has(tile + direction),
					"%s Rock Smash tile keeps every neighboring route open: %s" % [floor_id, position]
				)

	_check(all_scene_source.count("smashable_rock.tscn") == 3, "all three Mt. Moon floors use the reusable Rock Smash scene")
	_check(all_scene_source.count("overworld_item.tscn") == 2, "Mt. Moon visible-item floors use the reusable Poké Ball scene")
	_check(all_scene_source.count('pickup_id = "kanto_mt_moon_') == EXPECTED_PICKUPS.size(), "Mt. Moon has all twelve visible pickups")
	_check(not all_scene_source.contains("escape-rope"), "Mt. Moon does not grant the key-item Escape Rope")
	for pickup: Array in EXPECTED_PICKUPS:
		_check(all_scene_source.contains('pickup_id = "%s"' % pickup[0]), "pickup scene id exists: %s" % pickup[0])
		_check(all_scene_source.contains('item_id = "%s"' % pickup[1]), "pickup item exists: %s" % pickup[1])

	quit(1 if failed else 0)


func _tile_for_position(position: Vector2i) -> Vector2i:
	return Vector2i(floori(float(position.x) / TILE_SIZE), floori(float(position.y) / TILE_SIZE))


func _collision_cells(scene_source: String) -> Dictionary:
	var cells := {}
	var collision_marker := '[node name="Collision"'
	var collision_start := scene_source.find(collision_marker)
	if collision_start < 0:
		_check(false, "scene contains a Collision layer")
		return cells
	var collision_end := scene_source.find("\n[node name=", collision_start + collision_marker.length())
	var collision_section := scene_source.substr(collision_start, collision_end - collision_start)
	var data_marker := 'PackedByteArray("'
	var data_start := collision_section.find(data_marker)
	if data_start < 0:
		_check(false, "Collision layer contains packed tile data")
		return cells
	data_start += data_marker.length()
	var data_end := collision_section.find('")', data_start)
	var raw := Marshalls.base64_to_raw(collision_section.substr(data_start, data_end - data_start))
	for offset in range(2, raw.size() - 3, 12):
		cells[Vector2i(raw.decode_s16(offset), raw.decode_s16(offset + 2))] = true
	return cells


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
