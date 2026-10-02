extends SceneTree

const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"
const TOWN := "res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn"
const AtlasValidator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var tower := (load(TOWER) as PackedScene).instantiate()
	var town := (load(TOWN) as PackedScene).instantiate()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/tiled/lavender_pokemon_tower_layout.json"))
	var mask := tower.get_node("FloorVisibilityMask")
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = tower.get_node("Spawns/FromLavenderTown").position
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.5, 1.5)
	player.add_child(camera)
	tower.get_node("Entities/Players").add_child(player)
	root.add_child(tower)
	await process_frame
	_check(tower.get("map_id") == "kanto_lavender_town_pokemon_tower"
		and tower.get("world_access_group_id") == "kanto_lavender_town", "Tower belongs to Lavender Town")
	_check(tower.get("lighting_profile") == "indoor" and tower.get("weather_profile") == "disabled", "Tower uses indoor lighting")
	var visual := tower.get_node("Visual")
	var visual_metadata: Dictionary = visual.get_meta("tiled_visual_map")
	_check(visual_metadata.get("width") == 80 and visual_metadata.get("height") == 74, "Tower preserves all seven artist floors")
	_check(str(visual.get_meta("tiled_source_path")).ends_with("/pokemon_tower/Pokemon Tower.tmx"), "Tower uses the requested TMX")
	_check(AtlasValidator.new().validate(visual, "res://generated/tiled_visuals/lavender_pokemon_tower/lavender_pokemon_tower.visual.tileset.tres").is_empty(), "Tower compact atlases are valid")
	var collision := tower.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.tile_set != null and collision.get_used_cells().is_empty(), "Tower collision is empty and editable")
	_check(mask.get("floor_regions").size() == 7 and mask.get("constrain_camera_to_active_floor"), "Seven floor masks constrain the camera")
	for floor_data: Dictionary in layout.floors:
		var n := int(floor_data.floorNumber)
		var bounds: Array = floor_data.tileBounds
		var expected := Rect2(float(bounds[0]) * 32, float(bounds[1]) * 32, float(bounds[2]) * 32, float(bounds[3]) * 32)
		var floor_name := StringName("floor_%d" % n)
		mask.call("show_floor", floor_name)
		_check(mask.call("get_active_floor_region") == expected, "%dF mask follows the artist floor bounds" % n)
		_check(tower.call("get_map_display_name") == "Pokémon Tower %dF" % n, "%dF location label follows the mask" % n)
		var center := Vector2(float(camera.limit_left + camera.limit_right) / 2, float(camera.limit_top + camera.limit_bottom) / 2)
		_check(center.is_equal_approx(expected.get_center()), "%dF camera stays centered on its floor" % n)
		for other: Dictionary in layout.floors:
			var other_bounds: Array = other.tileBounds
			var other_center := Vector2((float(other_bounds[0]) + float(other_bounds[2]) / 2) * 32, (float(other_bounds[1]) + float(other_bounds[3]) / 2) * 32)
			var hidden := false
			for side: String in ["Top", "Bottom", "Left", "Right"]:
				hidden = hidden or Geometry2D.is_point_in_polygon(other_center, (mask.get_node(side) as Polygon2D).polygon)
			_check(hidden == (int(other.floorNumber) != n), "%dF mask hides floor %d only when inactive" % [n, other.floorNumber])
		for connection: Dictionary in floor_data.connections:
			if not connection.isLocalTransition:
				continue
			var destination_floor := int(connection.destination)
			var transition := tower.get_node("FloorTransitions/Floor%dTo%d" % [n, destination_floor])
			var source_arrival: Array = connection.arrival
			player.position = Vector2(float(source_arrival[0]) * 32 + 16, float(source_arrival[1]) * 32 + 16)
			mask.call("show_floor", floor_name)
			var trigger: Array = connection.trigger
			_check(transition.position == Vector2(float(trigger[0]) * 32 + 16, float(trigger[1]) * 32 + 16), "Stair %dF to %dF uses its artist trigger" % [n, destination_floor])
			var destination_marker := transition.get_node(transition.get("destination_marker_path")) as Marker2D
			_check(destination_marker != null, "Stair has an authored arrival marker")
			var landing := destination_marker.position
			var destination_bounds := mask.get("floor_regions")[StringName("floor_%d" % destination_floor)] as Rect2
			_check(destination_bounds.has_point(landing), "Authored stair arrival is on its destination floor")
			var reverse := tower.get_node("FloorTransitions/Floor%dTo%d" % [destination_floor, n])
			var reverse_shape := reverse.get_node("CollisionShape2D") as CollisionShape2D
			var reverse_rect := Rect2(reverse.position - (reverse_shape.shape as RectangleShape2D).size / 2, (reverse_shape.shape as RectangleShape2D).size)
			_check(not reverse_rect.has_point(landing), "Stair arrival avoids immediate return")
			_check(transition.is_connected("body_entered", Callable(transition, "_on_body_entered")), "Stair is connected to walking trigger")
			transition.set("cooldown_seconds", 0.0)
			await transition.call("_on_body_entered", player)
			_check(player.position == landing and mask.get("active_floor") == StringName("floor_%d" % destination_floor), "Stair %dF to %dF moves player and switches mask" % [n, destination_floor])
	player.position = tower.get_node("Spawns/Floor7From6").position
	await process_frame
	await process_frame
	_check(mask.get("active_floor") == &"floor_7", "Restoring a position on 7F automatically selects the correct mask")
	_check(tower.get_node("FloorTransitions").get_child_count() == 12, "All six stair pairs are connected")
	var entrance := town.get_node("Exits/ToPokemonTower")
	var exit := tower.get_node("Exits/ToOutside")
	_check(entrance.get("target_scene_path") == TOWER and entrance.get("target_spawn_name") == "FromLavenderTown", "Town entrance leads to Tower 1F")
	_check(exit.get("target_scene_path") == TOWN and exit.get("target_spawn_name") == "FromPokemonTower", "Tower exits to Lavender Town")
	_check(entrance.is_connected("body_entered", Callable(entrance, "_on_body_entered")) and exit.is_connected("body_entered", Callable(exit, "_on_body_entered")), "Both exterior door signals are connected")
	_check(tower.get_node("Spawns/FromLavenderTown").position == Vector2(368, 592)
		and town.get_node("Spawns/FromPokemonTower").position == Vector2(1072, 528), "Door arrivals match artist connection coordinates")
	_check(not bool(exit.call("contains_world_position", tower.get_node("Spawns/FromLavenderTown").position))
		and not bool(entrance.call("contains_world_position", town.get_node("Spawns/FromPokemonTower").position)),
		"Exterior door arrivals avoid immediate return")
	var town_collision := town.get_node("Tiles/Collision") as TileMapLayer
	_check(town_collision.get_cell_source_id(Vector2i(33, 15)) == -1 and town_collision.get_cell_source_id(Vector2i(33, 16)) == -1, "Tower exterior entrance and arrival are traversable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has("kanto_lavender_town_pokemon_tower")
		and catalog.transitions.has("kanto_lavender_town__to_pokemon_tower")
		and catalog.transitions.has("kanto_lavender_town_pokemon_tower__to_outside"), "Catalog registers Tower and both exterior transitions")
	town.free()
	tower.queue_free()
	await process_frame
	print("Pokémon Tower checks: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
