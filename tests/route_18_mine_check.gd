extends SceneTree

const MINE := "res://scenes/overworld/kanto/caves/route_18_mine/route_18_mine.tscn"
const SURFACE := "res://scenes/overworld/kanto/routes/kanto_route_18.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var mine := (load(MINE) as PackedScene).instantiate()
	var surface := (load(SURFACE) as PackedScene).instantiate()
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	var visual: Node = mine.get_node("Visual")
	var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(visual,"res://generated/tiled_visuals/route_18_mine/route_18_mine.visual.tileset.tres")
	_check(errors.is_empty(), "mine compact atlas validates: "+str(errors))
	_check(visual.get_meta("tiled_visual_map").width == 42 and visual.get_meta("tiled_visual_map").height == 32, "artist dimensions preserved")
	_check(mine.map_id == "kanto_route_18_mine" and mine.world_access_area_type == "interior", "dedicated mine identity")
	_check(mine.lighting_profile == "indoor" and mine.weather_profile == "disabled" and mine.battle_environment_id == "cave", "underground environment")
	_check(mine.allows_land_mounts() and mine.allows_land_mount_dismount() and not mine.land_mount_required_entry, "optional riding without Cycling Road restrictions")
	var loader: Node = load("res://scripts/services/web_asset_module_service.gd").new()
	_check(loader.scene_for_map(mine.map_id) == MINE, "browser loads mine map pack")
	loader.free()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[surface,"ToUndergroundMine",mine,"FromRoute18","right",Vector2i(10,38)],[mine,"ToRoute18",surface,"FromUndergroundMine","left",Vector2i(4,9)]]:
		var exit_node: Node = leg[0].get_node("Exits/"+leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/"+leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "stairs paired in both directions")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces away from stairs")
		_check(exit_node.monitoring and not exit_node.get_node("CollisionShape2D").disabled, "stairs enabled")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "stair signal connected")
		_check(exit_node.get_travel_block_reason(player).is_empty(), "stairs accept walking")
		_check(player.overlaps_exit_at(exit_node,_point(leg[5])), "actual player enters at authored staircase")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "authoritative endpoints match")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "authoritative arrival matches")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.position), "actual player shape cannot immediately return")
	_check(mine.get_node("Spawns/FromRoute18").position == _point(Vector2i(5,9)), "authored mine landing retained")
	_check(surface.get_node("Spawns/FromUndergroundMine").position == _point(Vector2i(9,38)), "authored surface landing retained")
	mine.add_child(player)
	_configure_player(player,mine)
	mine.remove_child(player)
	surface.add_child(player)
	_configure_player(player,surface)
	player.surf_activity_active = true
	player.surf_activity_active = false
	mine.free()
	surface.free()
	if not failed: print("PASS Route 18 mine: atlas, round-trip wiring and cave metadata")
	quit(1 if failed else 0)

func _configure_player(player: Node,map: Node) -> void:
	for container in ["Entities/NPCs","Entities/Pokemon"]:
		for actor in map.get_node(container).get_children(): actor.feet_marker = actor.get_node("FeetMarker")
	player.map_layers_initialized = true
	player.map_layers_owner = map
	player.resolved_map_cache = map
	player.collision_tilemap = map.find_map_tilemap_layer("Collision")
	player.water_tilemap = map.find_map_tilemap_layer("Water")


func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)

func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
