extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var town := (load("res://scenes/overworld/kanto/towns/lavender_town/lavender_town.tscn") as PackedScene).instantiate()
	root.add_child(town)
	await process_frame
	var beacon := town.get_node("Entities/Interactables/AetherBeacon") as Node2D
	var keeper := town.get_node("Entities/NPCs/TransitKeeperNPC") as Node2D
	var arrival := town.get_node("Spawns/TransitArrival") as Marker2D
	var collision := town.get_node("Tiles/Collision") as TileMapLayer
	_check(beacon.get("destination_id") == "kanto_lavender_town", "Lavender Beacon attunes the town")
	_check(beacon.get("interactable_id") == "kanto_lavender_town_aether_beacon", "Beacon has a stable interaction identity")
	_check(keeper.get("local_destination_id") == beacon.get("destination_id"), "Keeper opens the local destination")
	_check(beacon.call("_find_local_keeper") == keeper, "Beacon finds Lavender's Keeper")
	_check(keeper.is_in_group("aethernet_keeper"), "Keeper is discoverable by the Aethernet")
	_check(arrival.position == Vector2(752, 784), "Transit arrival matches the server destination tile")
	_check(arrival.position.distance_to(beacon.position) == 32, "Transit arrival is one tile from the Beacon")
	_check(collision.get_cell_source_id(collision.local_to_map(arrival.position)) == -1, "Transit arrival has no terrain collision")
	_check(posmod(roundi(arrival.position.x), 32) == 16 and posmod(roundi(arrival.position.y), 32) == 16, "Transit arrival is centered on the world tile grid")
	var catalog := JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json")) as Dictionary
	var lavender_area: Dictionary = catalog.get("areas", {}).get("kanto_lavender_town", {})
	var transit_spawn: Dictionary = lavender_area.get("spawnPoints", {}).get("transit_arrival", {})
	var transit_tile: Dictionary = transit_spawn.get("tile", {})
	_check(
		transit_spawn.get("spawnMarker") == "TransitArrival"
		and float(transit_tile.get("x", -1)) == 23.0
		and float(transit_tile.get("y", -1)) == 24.0,
		"World access catalog includes the Lavender transit spawn"
	)
	town.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
