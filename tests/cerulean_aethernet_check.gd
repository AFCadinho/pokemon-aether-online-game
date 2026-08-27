extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"

const EXPECTED_POSITIONS := {
	"Spawns/TransitArrival": Vector2(1360, 1488),
	"Entities/NPCs/TransitKeeper": Vector2(1328, 1488),
	"Entities/Interactables/AetherBeacon": Vector2(1392, 1456),
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(CITY_SCENE) as PackedScene
	_check(packed_scene != null, "Cerulean City loads with its Aethernet station")
	if packed_scene == null:
		quit(1)
		return

	var city := packed_scene.instantiate()
	root.add_child(city)
	for node_path: String in EXPECTED_POSITIONS:
		var station_node := city.get_node_or_null(node_path) as Node2D
		_check(station_node != null, "Cerulean places %s" % node_path.get_file())
		if station_node != null:
			_check(station_node.position == EXPECTED_POSITIONS[node_path], "%s uses its authoritative tile" % node_path.get_file())

	var keeper := city.get_node_or_null("Entities/NPCs/TransitKeeper")
	var beacon := city.get_node_or_null("Entities/Interactables/AetherBeacon")
	_check(keeper != null and str(keeper.get("local_destination_id")) == "kanto_cerulean_city", "Cerulean Keeper opens the local destination")
	_check(beacon != null and str(beacon.get("destination_id")) == "kanto_cerulean_city", "Cerulean Beacon attunes the city destination")
	_check(beacon != null and str(beacon.get("interactable_id")) == "kanto_cerulean_city_aether_beacon", "Cerulean Beacon has a stable interaction id")

	var collision := city.get_node_or_null("Tiles/Collision") as TileMapLayer
	var water := city.get_node_or_null("Tiles/Water") as TileMapLayer
	_check(collision != null and water != null, "Cerulean station resolves collision and water masks")
	if collision != null and water != null:
		for position: Vector2 in EXPECTED_POSITIONS.values():
			var collision_cell := collision.local_to_map(collision.to_local(position))
			var water_cell := water.local_to_map(water.to_local(position))
			_check(collision.get_cell_source_id(collision_cell) == -1, "Cerulean station tile %s is walkable" % position)
			_check(water.get_cell_source_id(water_cell) == -1, "Cerulean station tile %s is on land" % position)

	city.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error(label)
