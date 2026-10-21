extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var house := (load("res://scenes/overworld/kanto/towns/fuchsia_city/tall_house.tscn") as PackedScene).instantiate()
	for exit_node in house.get_node("Exits").get_children():
		exit_node.monitoring = false
	root.add_child(house)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	house.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	await process_frame
	var warden: Node2D = house.get_node("Entities/NPCs/Warden")
	_check(warden.npc_id == "kanto_fuchsia_city_warden", "Warden metadata binding")
	_check(warden.get_script() == load("res://scripts/world/npcs/fuchsia_warden.gd"), "Turn-in script parses and instantiates")
	_check(house.get_node("FloorVisibilityMask").floor_regions[&"ground_floor"].has_point(warden.position), "Warden is downstairs")
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(10, 31)]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if reachable.has(cell) or not Rect2i(3, 24, 15, 9).has_point(cell):
			continue
		if not player.can_move_to(Vector2(cell * 32) + Vector2(16, 16)):
			continue
		reachable[cell] = true
		for delta in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			queue.append(cell + delta)
	_check(reachable.has(Vector2i(9, 28)), "Player can reach the tile facing the Warden from the doorway")
	_check(reachable.has(Vector2i(14, 31)), "Warden leaves stairs reachable")
	house.free()
	print("FUCHSIA_GOLD_TEETH " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
