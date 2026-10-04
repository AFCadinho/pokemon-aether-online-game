extends SceneTree

var failed := false
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_12.tscn") as PackedScene).instantiate()
	check(map.encounter_area_id == "kanto_route_12", "Server encounter area is configured")
	check(is_equal_approx(map.grass_encounter_chance, 0.21), "Grass chance is configured")
	check(is_equal_approx(map.surf_encounter_chance, 0.02), "Surf chance is configured")
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	check(not grass.visible and not grass.get_used_cells().is_empty(), "Encounter grass exists")
	for cell in grass.get_used_cells():
		check(map.get_node("Visual/Grass").get_cell_source_id(cell) != -1, "Encounter grass has artwork")
	var npcs := map.get_node("Entities/NPCs").get_children()
	check(npcs.size() == 16, "Sixteen route trainers exist; the Fishing Guru's brother lives indoors")
	var ids := {}
	for npc in npcs:
		check(not ids.has(npc.npc_id), "NPC IDs are unique")
		ids[npc.npc_id] = true
		check(npc.npc_sprite_frames != null, "NPC has artwork")
		var cell := Vector2i(npc.position / 32.0)
		check(clear_cell(map, cell), "NPC stands on walkable land: " + npc.name)
		if npc.get_script().resource_path.ends_with("trainer_npc.gd"):
			check(npc.trainer_id == npc.npc_id, "Trainer ID matches registered NPC")
			for step in range(1, npc.sight_range_tiles + 1):
				check(clear_cell(map, cell + Vector2i(npc.facing_direction) * step), "Trainer sight is clear: " + npc.name)
		for spawn in map.get_node("Spawns").get_children():
			check(npc.position.distance_to(spawn.position) >= 96.0, "NPC does not block a spawn")
	var pickups := map.get_node("Entities/Interactables").get_children()
	check(pickups.size() == 8, "Eight useful pickups exist")
	for pickup in pickups:
		check(clear_cell(map, Vector2i(pickup.position / 32.0)), "Pickup stands on land: " + pickup.name)
		check(not ids.has(pickup.pickup_id), "Pickup IDs are unique")
		ids[pickup.pickup_id] = true
	check(map.get_node("Exits").get_child_count() == 5, "Route 12 retains its four regional exits and fishing house entrance")
	var house_exit := map.get_node("Exits/ToFishingBrotherHouse")
	check(house_exit.target_scene_path == "res://scenes/overworld/kanto/routes/route_12_fishing_brother_house.tscn", "Fishing house entrance targets its interior")
	check(map.get_node("Spawns/FromFishingBrotherHouse").position == Vector2(1040, 2544), "Fishing house return spawn matches its Tiled arrival tile")
	var house := (load("res://scenes/overworld/kanto/routes/route_12_fishing_brother_house.tscn") as PackedScene).instantiate()
	check(house.get_node("Exits/ToRoute12").target_scene_path == "res://scenes/overworld/kanto/routes/kanto_route_12.tscn", "Fishing house exit returns to Route 12")
	check(house.get_node("Spawns/FromRoute12").position == Vector2(304, 464), "Interior arrival spawn matches its Tiled arrival tile")
	house.free()
	map.free()
	if not failed: print("PASS Route 12: encounters, trainers, pickups, safe placement and fishing house connection")
	quit(1 if failed else 0)
func clear_cell(map: Node, cell: Vector2i) -> bool:
	return map.get_node("Tiles/Collision").get_cell_source_id(cell) == -1 and map.get_node("Tiles/Water").get_cell_source_id(cell) == -1
func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
