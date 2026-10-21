extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const GYM := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_gym.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	city.position = Vector2(4096,0)
	var gym := (load(GYM) as PackedScene).instantiate()
	for map in [city,gym]:
		for exit_node in map.get_node("Exits").get_children(): exit_node.monitoring = false
	root.add_child(city)
	root.add_child(gym)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	player.add_to_group("player")
	gym.get_node("Entities/Players").add_child(player)
	player.position = gym.get_node("Spawns/FromFuchsiaCity").position
	player.refresh_map_layers()
	await process_frame
	await process_frame
	for x in range(13,16):
		_check(player.overlaps_exit_at(gym.get_node("Exits/ToFuchsiaCity"),_point(Vector2i(x,30))), "Interior exit covers all three door tiles")
	_check(gym.music_profile_id == "gym.interior", "Gym music profile")
	_check(gym.lighting_profile == "indoor" and gym.weather_profile == "disabled", "Indoor lighting and weather")
	var mask: Node = gym.get_node("FloorVisibilityMask")
	_check(mask.floor_regions.size() == 1, "The supplied Gym stays a single room")
	var camera: Camera2D = player.get_node("Camera2D")
	_check(is_equal_approx((camera.limit_left+camera.limit_right)/2.0,464.0), "Camera centers the Gym horizontally")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city,"ToGym",gym,"FromFuchsiaCity","up"],[gym,"ToFuchsiaCity",city,"FromGym","down"]]:
		var exit_node: Area2D = leg[0].get_node("Exits/"+leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "Paired scene and spawn")
		_check(exit_node.transition_facing_direction == leg[4], "Arrival facing")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "Doorway signal is connected")
		player.reparent(leg[2].get_node("Entities/Players"))
		player.refresh_map_layers()
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.global_position), "Arrival avoids immediate return")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "Server catalog endpoints match")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "Server spawn matches the scene")
	var door: Node = city.get_node("MapDoors").doors["Door76"]
	_check(door.access_enabled, "Existing Gym door is enabled")
	for x in [31]:
		var threshold: Vector2 = city.to_global(_point(Vector2i(x,34)))
		_check(player.overlaps_exit_at(city.get_node("Exits/ToGym"),threshold), "Exterior exit covers the full door width")
		player.position = _point(Vector2i(x,35))
		_check(door._actor_needs_door(player), "Door opens from the approach tile")
		_check(not player.overlaps_exit_at(city.get_node("Exits/ToGym"),player.global_position), "Door does not trigger from the approach row")
	city.get_node("MapDoors").prepare_player_arrival("FromGym")
	_check(is_equal_approx(float(door.open_amount),1.0), "Returning through the door prepares Gym door open")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.scene_for_map(gym.map_id) == GYM, "Browser resolves the Gym")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(gym.get_node("Visual"),"res://generated/tiled_visuals/fuchsia_gym/fuchsia_gym.visual.tileset.tres").is_empty(), "Visual atlas resolves")
	city.free()
	gym.free()
	print("FUCHSIA_GYM ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _point(tile: Vector2i) -> Vector2:
	return Vector2(tile)*32+Vector2(16,16)

func _check(ok: bool,label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
