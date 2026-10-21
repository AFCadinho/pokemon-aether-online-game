extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const HOUSE := "res://scenes/overworld/kanto/towns/fuchsia_city/tall_house.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	city.position = Vector2(4096, 0)
	var house := (load(HOUSE) as PackedScene).instantiate()
	for map in [city, house]:
		for exit_node in map.get_node("Exits").get_children():
			exit_node.monitoring = false
	root.add_child(city)
	root.add_child(house)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	player.add_to_group("player")
	house.get_node("Entities/Players").add_child(player)
	player.position = house.get_node("Spawns/FromFuchsiaCity").position
	player.refresh_map_layers()
	var mask: Node = house.get_node("FloorVisibilityMask")
	await process_frame
	_check(house.lighting_profile == "indoor" and house.weather_profile == "disabled", "Indoor light and weather profiles")
	_check(mask.constrain_camera_to_active_floor and mask.follow_player_floor, "Same floor mask and camera behavior as Player's House")
	_check(mask.get_script() == load("res://scripts/world/floor_visibility_mask.gd"), "Shared Player's House mask script")
	for leg in [["GroundToUpper", "UpperFloorStairs", "upper_floor"], ["UpperToGround", "GroundFloorStairs", "ground_floor"]]:
		var stair: Area2D = house.get_node("FloorTransitions/" + leg[0])
		_check(stair.get_script() == load("res://scripts/world/internal_floor_transition.gd"), "Shared Player's House stair implementation")
		_check(stair.is_connected("body_entered", Callable(stair,"_on_body_entered")), "Stair responds to physical walking")
		stair.cooldown_seconds = 0.0
		stair._on_body_entered(player)
		for frame in range(5):
			await physics_frame
		var landing: Vector2 = house.get_node("Spawns/" + leg[1]).position
		_check(player.position == landing and str(mask.active_floor) == leg[2], "Stair handler moves to " + leg[2])
		_check(player.target_position == landing and not player.is_moving, "Stair synchronizes movement state")
		var reverse: Area2D = house.get_node("FloorTransitions/" + ("UpperToGround" if leg[2] == "upper_floor" else "GroundToUpper"))
		_check(not player.overlaps_exit_at(reverse, landing), "Stair landing avoids automatic return")
		_check(not bool(house.get_meta(&"pao_internal_floor_transition_locked", false)), "Shared stair lock clears after transfer")
		await process_frame
		var camera: Camera2D = player.get_node("Camera2D")
		var center := Vector2((camera.limit_left + camera.limit_right) / 2.0, (camera.limit_top + camera.limit_bottom) / 2.0)
		_check(center.is_equal_approx(mask.get_active_floor_region().get_center()), "Camera stays centered on the active floor")
		var other := mask.floor_regions[&"ground_floor" if leg[2] == "upper_floor" else &"upper_floor"] as Rect2
		var hidden := false
		for side in ["Top", "Bottom", "Left", "Right"]:
			hidden = hidden or Geometry2D.is_point_in_polygon(other.get_center(), mask.get_node(side).polygon)
		_check(hidden, "Other floor is masked")
	player.position = house.get_node("Spawns/UpperFloorStairs").position
	await process_frame
	_check(mask.active_floor == &"upper_floor" and house.get_map_display_name().ends_with("Upstairs"), "Direct upstairs arrivals select the right floor and location label")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city,"ToTallHouse",house,"FromFuchsiaCity","up"], [house,"ToFuchsiaCity",city,"FromTallHouse","down"]]:
		var exit_node: Area2D = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "Paired city/house destination")
		_check(exit_node.transition_facing_direction == leg[4], "Exterior arrival facing")
		_check(exit_node.is_connected("body_entered", Callable(exit_node,"_on_body_entered")), "Exterior doorway signal is connected")
		player.reparent(leg[2].get_node("Entities/Players"))
		player.refresh_map_layers()
		for other_exit in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other_exit, arrival.global_position), "Arrival avoids every external exit trigger")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "Server transition endpoints match")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "Server uses the authored arrival")
	player.refresh_map_layers()
	_check(player.overlaps_exit_at(city.get_node("Exits/ToTallHouse"), city.to_global(_point(Vector2i(22,9)))), "Exterior door detects entry at the threshold")
	_check(not player.overlaps_exit_at(city.get_node("Exits/ToTallHouse"), city.to_global(_point(Vector2i(22,10)))), "Door does not trigger from the approach tile")
	var door: Node = city.get_node("MapDoors").doors["Door74"]
	_check(door.access_enabled, "Existing exterior door animation is enabled")
	city.get_node("MapDoors").prepare_player_arrival("FromTallHouse")
	_check(is_equal_approx(float(door.get("open_amount")), 1.0), "Returning through the door prepares its opening")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.scene_for_map(house.map_id) == HOUSE, "Browser resolves the house scene")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(house.get_node("Visual"), "res://generated/tiled_visuals/fuchsia_tall_house/fuchsia_tall_house.visual.tileset.tres").is_empty(), "Imported visual atlas resolves")
	city.free()
	house.free()
	print("FUCHSIA_TALL_HOUSE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _point(tile: Vector2i) -> Vector2:
	return Vector2(tile) * 32 + Vector2(16,16)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
