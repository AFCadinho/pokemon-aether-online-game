extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const EXPECTED_ROCKS := {
	"WestRockNorth": ["kanto_cerulean_city_west_site_rock_north", Vector2(80, 1168)],
	"WestRockUpper": ["kanto_cerulean_city_west_site_rock_upper", Vector2(144, 1328)],
	"WestRockLower": ["kanto_cerulean_city_west_site_rock_lower", Vector2(48, 1744)],
	"WestRockSouth": ["kanto_cerulean_city_west_site_rock_south", Vector2(144, 1936)],
	"EastRockNorthwest": ["kanto_cerulean_city_east_site_rock_northwest", Vector2(2128, 1680)],
	"EastRockNortheast": ["kanto_cerulean_city_east_site_rock_northeast", Vector2(2320, 1712)],
	"EastRockSouthwest": ["kanto_cerulean_city_east_site_rock_southwest", Vector2(2128, 1904)],
	"EastRockSoutheast": ["kanto_cerulean_city_east_site_rock_southeast", Vector2(2288, 1936)],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CITY_SCENE) as PackedScene
	_check(packed != null, "Cerulean City loads with its mountain sites")
	if packed == null:
		quit(1)
		return
	var city := packed.instantiate()
	city.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(city)

	var guide := city.get_node_or_null("Entities/NPCs/MountainGuide") as Node2D
	_check(guide != null and guide.position == Vector2(432, 1488), "Mountain Guide waits beside the mountain trail")
	if guide != null:
		_check(bool(guide.call("can_access_site", "west", 20)), "West Site opens at Rock Smash level 20")
		_check(not bool(guide.call("can_access_site", "east", 49)), "East Site stays closed below level 50")
		_check(bool(guide.call("can_access_site", "east", 50)), "East Site opens at Rock Smash level 50")

	var site_root := city.get_node_or_null("Entities/Interactables/MountainRockSmashSites")
	var collision := city.get_node_or_null("Tiles/Collision") as TileMapLayer
	var water := city.get_node_or_null("Tiles/Water") as TileMapLayer
	_check(site_root != null, "Cerulean exposes the mountain Rock Smash site group")
	_check(collision != null and water != null, "Cerulean exposes collision and water data for safe placement")
	if site_root != null:
		for rock_name_value: Variant in EXPECTED_ROCKS:
			var rock_name := str(rock_name_value)
			var expected: Array = EXPECTED_ROCKS[rock_name_value]
			var rock := site_root.get_node_or_null(rock_name) as Node2D
			_check(rock != null, "%s is placed" % rock_name)
			if rock != null:
				_check(str(rock.get("rock_id")) == str(expected[0]), "%s has its authoritative ID" % rock_name)
				_check(rock.position == expected[1], "%s keeps its mapped position" % rock_name)
				_check(int(rock.get("rock_visual_style")) == 2, "%s uses the route rock visual" % rock_name)
				_check(rock.z_index == 2054 and not rock.z_as_relative, "%s renders on the plateau" % rock_name)
				_check(_is_open_land(rock.position, collision, water), "%s stands on open land" % rock_name)
		_check(site_root.get_node_or_null("WestReturnTrail") != null, "West Site has a return trail")
		_check(site_root.get_node_or_null("EastReturnTrail") != null, "East Site has a return trail")

	_check(int(city.call("get_actor_sort_z_floor", Vector2(112, 1520))) == 2054, "West Site raises actor depth")
	_check(int(city.call("get_actor_sort_z_floor", Vector2(2192, 1776))) == 2054, "East Site raises actor depth")
	_check(_is_open_land(Vector2(112, 1520), collision, water), "West Site arrival is safe")
	_check(_is_open_land(Vector2(2192, 1776), collision, water), "East Site arrival is safe")
	_check(_is_open_land(Vector2(432, 1520), collision, water), "Mountain Guide return is safe")
	_check(int(city.call("get_actor_sort_z_floor", Vector2(800, 800))) < 0, "Regular city depth remains unchanged")
	city.free()
	quit(1 if failed else 0)


func _is_open_land(position: Vector2, collision: TileMapLayer, water: TileMapLayer) -> bool:
	if collision == null or water == null:
		return false
	var collision_cell := collision.local_to_map(collision.to_local(position))
	var water_cell := water.local_to_map(water.to_local(position))
	return collision.get_cell_source_id(collision_cell) < 0 and water.get_cell_source_id(water_cell) < 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failed = true
		push_error("FAIL: %s" % message)
