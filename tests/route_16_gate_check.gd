extends SceneTree

const EAST := "res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_16.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_16_gate.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var east := (load(EAST) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	var template := (load("res://scenes/overworld/kanto/reusable_interiors/horizontal_transition_building_template.tscn") as PackedScene).instantiate()
	_check(gate.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "approved horizontal interior preserved")
	_check(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "indoor lighting without weather")
	_check(not gate.land_mount_required_entry, "gate lobby accepts walkers")
	for outside in [east,route]:
		_check(not outside.get_node("Exits/ToRoute16Gate").requires_land_mount, "gate can be entered on foot from either side")
	_check(gate.get_node("Exits/ToWest").requires_land_mount, "only the Route 16 exit requires riding")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	for leg in [[east,"ToRoute16Gate",gate,"FromEast","left"],[gate,"ToEast",east,"FromRoute16Gate","right"],[route,"ToRoute16Gate",gate,"FromWest","right"],[gate,"ToWest",route,"FromRoute16Gate","left"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip target and spawn")
		_check(exit_node.monitoring and not exit_node.get_node("CollisionShape2D").disabled, "exit enabled")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit signal connected")
		var collision: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.position), "actual player shape avoids return trigger")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "catalog endpoint matches")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "server arrival position matches")
	var exterior: Area2D = route.get_node("Exits/ToRoute16Gate")
	var door_shape: CollisionShape2D = exterior.get_node("CollisionShape2D")
	var door_size: Vector2 = (door_shape.shape as RectangleShape2D).size
	var door_center := exterior.position + door_shape.position
	for y in range(floori((door_center.y-door_size.y/2)/32),ceili((door_center.y+door_size.y/2)/32)):
		var approach := Vector2(exterior.position.x,y*32+16)
		_check(player.overlaps_exit_at(exterior,approach), "entire saved exterior door aperture transfers")
	var collision: TileMapLayer = gate.get_node("Tiles/Collision")
	var guard: Node = gate.get_node("Entities/NPCs/GateNPC")
	guard.feet_marker = guard.get_node("FeetMarker")
	_check(guard.guard_role == "attendant" and guard.guarded_transition_id == "kanto_route_16_gate__to_route16", "desk attendant checks the Cycling Road exit")
	gate.add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = gate
	player.resolved_map_cache = gate
	player.collision_tilemap = collision
	for y in range(8,13):
		_check(player.overlaps_exit_at(gate.get_node("Exits/ToWest"),Vector2(80,y*32+16)), "full west aperture transfers")
		_check(player.overlaps_exit_at(gate.get_node("Exits/ToEast"),Vector2(560,y*32+16)), "full east aperture transfers")
	player.free()
	template.free()
	east.free()
	route.free()
	gate.free()
	if not failed: print("PASS Route 16 gate: four registered transitions and gate wiring")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
