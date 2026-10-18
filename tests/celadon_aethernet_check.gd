extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city: Node = load("res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn").instantiate()
	root.add_child(city)
	await process_frame
	var beacon: Node2D = city.get_node("Entities/Interactables/AetherBeacon")
	var keeper: Node2D = city.get_node("Entities/NPCs/TransitKeeperNPC")
	var arrival: Node2D = city.get_node("Spawns/TransitArrival")
	_check(beacon.get("destination_id") == "kanto_celadon_city", "Celadon Beacon attunes the city destination")
	_check(beacon.get("interactable_id") == "kanto_celadon_city_aether_beacon", "Beacon has a stable city-specific identity")
	_check(keeper.get("local_destination_id") == beacon.get("destination_id"), "Keeper uses the same local Aethernet destination")
	_check(beacon.call("_find_local_keeper") == keeper, "Beacon finds the local Keeper for its attunement and Anchor dialogue")
	_check(keeper.is_in_group("aethernet_keeper"), "Celadon Keeper is discoverable by the network")
	_check(arrival.position == Vector2(2288, 208), "Arrival marker matches the server-owned destination tile")
	_check(arrival.position.distance_to(beacon.position) == 32, "Arrival stays one tile beside the Beacon")
	var water: TileMapLayer = city.get_node("Tiles/Water")
	_check(water.get_cell_source_id(water.local_to_map(water.to_local(arrival.global_position))) == -1, "Arrival is on dry land")
	var collision: TileMapLayer = city.get_node("Tiles/Collision")
	var cell := collision.local_to_map(collision.to_local(arrival.global_position))
	_check(collision.get_cell_source_id(cell) == -1, "Arrival tile has no terrain collision")
	_check(not MapCharacterBlocking.is_position_blocked_by_character(city, arrival.global_position), "Arrival tile has no NPC or Pokemon occupant")
	for node: Node2D in [arrival, beacon, keeper]:
		_check(posmod(roundi(node.position.x), 32) == 16 and posmod(roundi(node.position.y), 32) == 16, "%s sits on the world tile grid" % node.name)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var transit_spawn: Dictionary = catalog.areas.kanto_celadon_city.spawnPoints.transit_arrival
	_check(transit_spawn.spawnMarker == "TransitArrival" and float(transit_spawn.tile.x) == 71.0 and float(transit_spawn.tile.y) == 6.0, "World access catalog has the canonical Celadon arrival")
	var reachable := _reachable(collision, Vector2i(city.get_node("Spawns/FromRoute7").position / 32.0))
	for node: Node2D in [arrival, beacon, keeper]:
		_check(reachable.has(Vector2i(node.position / 32.0)), "%s can be reached from Route 7" % node.name)
	print("CELADON_AETHERNET ", "FAIL" if failed else "PASS")
	city.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)

func _reachable(collision: TileMapLayer, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var reached := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := tile + step
			if not Rect2i(0, 0, 80, 70).has_point(next) or reached.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			reached[next] = true
			queue.append(next)
	return reached
