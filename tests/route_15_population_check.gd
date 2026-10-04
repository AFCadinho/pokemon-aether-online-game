extends SceneTree

const TRAINER_IDS := [
  "kanto_route_15_picnicker_becky",
  "kanto_route_15_crush_kin_ron",
  "kanto_route_15_crush_kin_mya",
  "kanto_route_15_picnicker_celia",
  "kanto_route_15_biker_ernest",
  "kanto_route_15_biker_alex",
  "kanto_route_15_beauty_grace",
  "kanto_route_15_beauty_olivia",
  "kanto_route_15_picnicker_kindra",
  "kanto_route_15_bird_keeper_chester",
  "kanto_route_15_bird_keeper_edwin",
  "kanto_route_15_picnicker_yazmin"
]
const PICKUPS := {
  "kanto_route_15_rain_dance": "tm-rain-dance",
  "kanto_route_15_pp_up": "pp-up",
  "kanto_route_15_rose_incense": "rose-incense"
}
var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_15.tscn") as PackedScene).instantiate()
	check(map.encounter_area_id == "kanto_route_15", "Server encounter area is configured")
	check(is_equal_approx(map.grass_encounter_chance, 0.21), "Grass chance is configured")
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	check(not grass.get_used_cells().is_empty(), "Encounter grass exists")
	for cell in grass.get_used_cells():
		check(map.get_node("Visual/Grass").get_cell_source_id(cell) != -1, "Encounter grass has artwork")
	var npcs := map.get_node("Entities/NPCs").get_children()
	check(npcs.size() == TRAINER_IDS.size(), "All twelve Route 15 trainers exist")
	check(grass.get_used_cells().size() == map.get_node("Visual/Grass").get_used_cells().size(), "All visible grass has encounters")
	var seen := {}
	var occupied := {}
	for npc in npcs:
		occupied[Vector2i(npc.position / 32.0)] = true
	var reachable := reachable_cells(map, Vector2i(map.get_node("Spawns/FromRoute14").position / 32.0), occupied)
	for spawn in map.get_node("Spawns").get_children():
		check(reachable.has(Vector2i(spawn.position / 32.0)), "Arrival stays reachable: " + spawn.name)
	for npc in npcs:
		check(not seen.has(npc.npc_id), "NPC IDs are unique")
		seen[npc.npc_id] = true
		check(npc.npc_id == npc.trainer_id, "Trainer and dialogue IDs match")
		check(TRAINER_IDS.has(npc.trainer_id), "Trainer ID belongs to Route 15")
		check(npc.npc_sprite_frames != null, "Trainer has overworld art")
		check(npc.mugshot != null and not "bugcatcher" in npc.mugshot.resource_path, "Trainer has a matching portrait")
		var cell := Vector2i(npc.position / 32.0)
		check(clear_cell(map, cell), "Trainer stands on walkable land: " + npc.name)
		check(not occupied.has(cell + Vector2i(npc.facing_direction)), "Trainer has an open interaction tile: " + npc.name)
		check(reachable.has(cell + Vector2i(npc.facing_direction)), "Trainer is reachable from Route 14: " + npc.name)
		for step in range(1, npc.sight_range_tiles + 1):
			check(clear_cell(map, cell + Vector2i(npc.facing_direction) * step), "Trainer sight is clear: " + npc.name)
	check(map.get_node("Entities/Interactables").get_child_count() == PICKUPS.size(), "All three pickups exist")
	for pickup in map.get_node("Entities/Interactables").get_children():
		check(PICKUPS.get(pickup.pickup_id, "") == pickup.item_id, "Route 15 pickup is registered: " + pickup.name)
		check(reachable.has(Vector2i(pickup.position / 32.0)), "Pickup is reachable: " + pickup.name)
	map.free()
	if not failed:
		print("PASS Route 15: encounters, twelve trainers, art and three pickups")
	quit(1 if failed else 0)

func clear_cell(map: Node, cell: Vector2i) -> bool:
	return map.get_node("Tiles/Collision").get_cell_source_id(cell) == -1

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func reachable_cells(map: Node, start: Vector2i, occupied: Dictionary) -> Dictionary:
	var visited := {start: true}
	var pending: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if next.x >= 0 and next.x < 104 and next.y >= 0 and next.y < 40 and not visited.has(next) and not occupied.has(next) and clear_cell(map, next):
				visited[next] = true
				pending.append(next)
	return visited
