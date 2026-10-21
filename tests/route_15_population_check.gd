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
var movement_probe

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_15.tscn") as PackedScene).instantiate()
	root.add_child(map)
	movement_probe = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	movement_probe.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	map.get_node("Entities/Players").add_child(movement_probe)
	movement_probe.position = map.get_node("Spawns/FromRoute14").position
	movement_probe.refresh_map_layers()
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
		var pickup_cell := Vector2i(pickup.position / 32.0)
		var can_collect := false
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if reachable.has(pickup_cell+direction): can_collect = true
		check(can_collect, "Pickup can be approached for collection: " + pickup.name)
	for leg in [["ToRoute14",71,26,30],["ToFuchsiaGate",6,28,31]]:
		var exit_node: Node = map.get_node("Exits/" + leg[0])
		for y in range(leg[2],leg[3]):
			var point := Vector2(leg[1]*32+16,y*32+16)
			check(movement_probe.can_move_to(point), "Exit aperture is walkable: " + leg[0])
			check(exit_node.contains_world_position(point), "Exit covers its full opening: " + leg[0])
	for spawn in map.get_node("Spawns").get_children():
		for exit_node in map.get_node("Exits").get_children():
			check(not movement_probe.overlaps_exit_at(exit_node,spawn.position), "Arrival body avoids exit trigger: " + spawn.name)
	var all_occupied := occupied.duplicate()
	for pokemon in map.get_node("Entities/Pokemon").get_children():
		var cell := Vector2i(pokemon.position / 32.0)
		check(not all_occupied.has(cell), "Pokemon does not overlap another actor: " + pokemon.name)
		all_occupied[cell] = true
	var bounds := Rect2i(0,0,72,42)
	for actor in map.get_node("Entities/NPCs").get_children() + map.get_node("Entities/Pokemon").get_children():
		var cell := Vector2i(actor.position / 32.0)
		check(bounds.has_point(cell), "Actor is inside current visual: " + actor.name)
		check(actor.facing_direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT], "Actor faces a cardinal direction")
	for pokemon in map.get_node("Entities/Pokemon").get_children():
		var cell := Vector2i(pokemon.position / 32.0)
		var axis := Vector2i.RIGHT if pokemon.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		var approachable := false
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if reachable.has(cell+direction): approachable = true
		check(approachable, "Pokemon is reachable: " + pokemon.name)
		for offset in [-1,0,1]:
			var target: Vector2i = cell + axis*offset
			check(bounds.has_point(target) and clear_cell(map,target), "Pokemon patrol avoids obstacles: " + pokemon.name)
			check(offset == 0 or not all_occupied.has(target), "Pokemon patrol avoids other actors: " + pokemon.name)
			if pokemon.species_id not in ["pidgey","pidgeotto"]:
				check(grass.get_cell_source_id(target) != -1, "Plant/insect Pokemon patrol stays in grass: " + pokemon.name)
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
			if next.x >= 0 and next.x < 72 and next.y >= 0 and next.y < 42 and not visited.has(next) and not occupied.has(next) and movement_probe.can_move_to(Vector2(next)*32+Vector2(16,16)):
				visited[next] = true
				pending.append(next)
	return visited
