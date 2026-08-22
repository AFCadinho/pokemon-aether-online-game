extends SceneTree

const TILE_SIZE := 32
const MAP_PICKUPS := {
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": [
		["kanto_viridian_city_potion", "potion", Vector2i(2240, 896)],
	],
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn": [
		["kanto_route_2_ether", "ether", Vector2i(544, 1728)],
		["kanto_route_2_paralyze_heal", "paralyze-heal", Vector2i(672, 2048)],
	],
	"res://scenes/overworld/kanto/routes/viridian_forest.tscn": [
		["kanto_viridian_forest_poke_ball", "poke-ball", Vector2i(672, 1088)],
		["kanto_viridian_forest_antidote", "antidote", Vector2i(1280, 1600)],
		["kanto_viridian_forest_potion", "potion", Vector2i(1568, 1920)],
		["kanto_viridian_forest_potion_2", "potion", Vector2i(768, 1920)],
	],
	"res://scenes/overworld/kanto/routes/kanto_route_4.tscn": [
		["kanto_route_4_tm_roar", "tm-roar", Vector2i(576, 160)],
	],
}

var failed := false


func _init() -> void:
	var all_source := ""
	var pickup_count := 0
	for scene_path: String in MAP_PICKUPS:
		var scene_source := FileAccess.get_file_as_string(scene_path)
		all_source += scene_source
		_check(not scene_source.is_empty(), "item map scene can be read: %s" % scene_path)
		_check(scene_source.contains("overworld_item.tscn"), "item map uses the reusable pickup scene: %s" % scene_path)
		var blocked_cells := _collision_cells(scene_source)
		for pickup: Array in MAP_PICKUPS[scene_path]:
			pickup_count += 1
			_check(scene_source.contains('pickup_id = "%s"' % pickup[0]), "pickup scene id exists: %s" % pickup[0])
			_check(scene_source.contains('item_id = "%s"' % pickup[1]), "pickup item exists: %s" % pickup[1])
			var tile := Vector2i(floori(float(pickup[2].x) / TILE_SIZE), floori(float(pickup[2].y) / TILE_SIZE))
			_check(not blocked_cells.has(tile), "pickup is placed on walkable floor: %s" % pickup[0])

	_check(pickup_count == 8, "all eight early-Kanto pickups are covered")
	_check(all_source.count('pickup_id = "kanto_viridian_city_potion"') == 1, "Viridian City's Potion id is unique")
	_check(all_source.count('pickup_id = "kanto_route_2_') == 2, "Route 2 has two unique pickups")
	_check(all_source.count('pickup_id = "kanto_viridian_forest_') == 4, "Viridian Forest has four unique pickups")
	_check(all_source.count('pickup_id = "kanto_route_4_tm_roar"') == 1, "Route 4's TM05 id is unique")
	quit(1 if failed else 0)


func _collision_cells(scene_source: String) -> Dictionary:
	var cells := {}
	var collision_marker := '[node name="Collision"'
	var collision_start := scene_source.find(collision_marker)
	if collision_start < 0:
		_check(false, "scene contains a Collision layer")
		return cells
	var collision_end := scene_source.find("\n[node name=", collision_start + collision_marker.length())
	if collision_end < 0:
		collision_end = scene_source.length()
	var collision_section := scene_source.substr(collision_start, collision_end - collision_start)
	var data_marker := 'PackedByteArray("'
	var data_start := collision_section.find(data_marker)
	if data_start < 0:
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
