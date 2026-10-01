extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city: Node = load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn").instantiate()
	root.add_child(city)
	await process_frame
	var beacon: Node2D = city.get_node("Entities/Interactables/AetherBeacon")
	var keeper: Node2D = city.get_node("Entities/NPCs/TransitKeeperNPC")
	var arrival: Node2D = city.get_node("Spawns/TransitArrival")
	_check(beacon.get("destination_id") == "kanto_vermilion_city", "Vermilion Beacon attunes the city destination")
	_check(beacon.get("interactable_id") == "kanto_vermilion_city_aether_beacon", "Beacon has a stable city-specific identity")
	_check(keeper.get("local_destination_id") == beacon.get("destination_id"), "Keeper uses the same local Aethernet destination")
	_check(beacon.call("_find_local_keeper") == keeper, "Beacon finds the local Keeper for its attunement and Anchor dialogue")
	_check(keeper.is_in_group("aethernet_keeper"), "Vermilion Keeper is discoverable by the network")
	_check(arrival.position == Vector2(848, 176), "Arrival marker matches the server-owned destination tile")
	_check(arrival.position.distance_to(beacon.position) == 32, "Arrival stays one tile beside the Beacon")
	_check(not city.is_water_tile_for_actor(arrival.global_position, null), "Arrival is on dry land")
	var collision: TileMapLayer = city.get_node("Tiles/Collision")
	var cell := collision.local_to_map(collision.to_local(arrival.global_position))
	_check(collision.get_cell_source_id(cell) == -1, "Arrival tile has no terrain collision")
	_check(not MapCharacterBlocking.is_position_blocked_by_character(city, arrival.global_position), "Arrival tile has no NPC or Pokemon occupant")
	for node: Node2D in [arrival, beacon, keeper]:
		_check(posmod(roundi(node.position.x), 32) == 16 and posmod(roundi(node.position.y), 32) == 16, "%s sits on the world tile grid" % node.name)
	city.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
