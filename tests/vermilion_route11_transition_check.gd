extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_11.tscn"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var route := (load(ROUTE) as PackedScene).instantiate()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(_peer_exit_count(city, ROUTE) == 2, "City has two Route 11 exits")
	_check(_peer_exit_count(route, CITY) == 2, "Route 11 has two city exits")
	for side: String in ["North", "South"]:
		var city_exit := city.get_node("Exits/ToRoute11" + side)
		var route_exit := route.get_node("Exits/ToVermilion" + side)
		var city_spawn := city.get_node("Spawns/FromRoute11" + side) as Marker2D
		var route_spawn := route.get_node("Spawns/FromVermilion" + side) as Marker2D
		_check(city_exit.target_spawn_name == route_spawn.name, "City targets the matching route spawn")
		_check(route_exit.target_spawn_name == city_spawn.name, "Route targets the matching city spawn")
		_check(city_spawn.position.y == city_exit.position.y and route_spawn.position.y == route_exit.position.y, "Spawns align with their own passage")
		_check(city_spawn.position.y - route_spawn.position.y == 320.0, "Passages align across the Tiled map offset")
		_check(city_exit.transition_facing_direction == "right" and route_exit.transition_facing_direction == "left", "Arrival faces into the destination")
		_check(city_exit.body_entered.is_connected(Callable(city_exit, "_on_body_entered")), "City exit is connected")
		_check(route_exit.body_entered.is_connected(Callable(route_exit, "_on_body_entered")), "Route exit is connected")
		_check(not _exit_rect(city_exit).has_point(city_spawn.position), "City arrival avoids the exit trigger")
		_check(not _exit_rect(route_exit).has_point(route_spawn.position), "Route arrival avoids the exit trigger")
		for pair in [[city_exit, route_spawn], [route_exit, city_spawn]]:
			var destination: Dictionary = catalog.transitions[pair[0].transition_id].destination
			_check(destination.spawnMarker == pair[1].name, "Authoritative catalog uses the scene spawn")
			_check(Vector2(destination.position.x, destination.position.y) == pair[1].position, "Authoritative arrival matches the actual spawn coordinates")
	_check(city.get_node("Exits/ToRoute11North").transition_id != city.get_node("Exits/ToRoute11South").transition_id, "City transition IDs are distinct")
	_check(route.get_node("Exits/ToVermilionNorth").transition_id != route.get_node("Exits/ToVermilionSouth").transition_id, "Route transition IDs are distinct")
	city.free()
	route.free()
	quit(1 if failed else 0)


func _peer_exit_count(map: Node, peer_path: String) -> int:
	var count := 0
	for exit: Node in map.get_node("Exits").get_children():
		if exit.get("target_scene_path") == peer_path:
			count += 1
	return count


func _exit_rect(exit: Node2D) -> Rect2:
	var collider := exit.get_node("CollisionShape2D") as CollisionShape2D
	var size := (collider.shape as RectangleShape2D).size
	return Rect2(exit.position + collider.position - size / 2.0, size)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
