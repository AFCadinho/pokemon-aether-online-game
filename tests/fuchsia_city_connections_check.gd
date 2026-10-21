extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_15_fuchsia_gate.tscn"

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	root.add_child(city)
	root.add_child(gate)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	city.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	var ground: TileMapLayer = city.get_node("Visual/Ground")
	_check(ground.get_used_rect() == Rect2i(0, 0, 72, 50) and ground.get_used_cells().size() == 3600, "complete artist visual is imported")
	var validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(city.get_node("Visual"), "res://generated/tiled_visuals/fuchsia_city/fuchsia_city.visual.tileset.tres").is_empty(), "compact atlas is valid")
	_check(city.get_node("Visual/ObjectsTop").z_index > city.get_node("Entities").z_index, "upper scenery draws above players")
	var stairs := preload("res://scripts/world/horizontal_stair_elevation.gd")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city, "ToRoute15Gate", gate, "FromFuchsiaCity", "right"], [gate, "ToWest", city, "FromRoute15Gate", "left"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip destination matches")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces away from doorway")
		_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "exit signal is connected")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "server catalog matches runtime")
		for destination_exit in leg[2].get_node("Exits").get_children():
			for offset in [Vector2.ZERO, Vector2(0,-16), Vector2(0,8)]:
				_check(not destination_exit.contains_world_position(arrival.global_position + offset), "arrival cannot immediately retrigger")
	# Exercise the actual player's collision and water rules, including Surf.
	for surfing in [false, true]:
		player.surf_activity_active = surfing
	player.surf_activity_active = false
	player.surf_activity_active = true
	player.surf_activity_active = false
	var city_exit: Area2D = city.get_node("Exits/ToRoute15Gate")
	_check(city_exit.position == Vector2(2224,720), "Route 15 exit keeps its authored position")
	_check(city_exit.get_node("CollisionShape2D").position == Vector2(16,0), "Route 15 trigger keeps its authored half-tile offset")
	_check(city.get_node("Spawns/FromRoute15Gate").position == Vector2(2192,720), "Route 15 arrival keeps its authored position")
	city.free()
	gate.free()
	print("FUCHSIA_CITY_CONNECTIONS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
