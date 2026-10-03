extends SceneTree

const TRAINER_IDS := [
	"kanto_route_13_picnicker_alma",
	"kanto_route_13_bird_keeper_sebastian",
	"kanto_route_13_picnicker_susie",
	"kanto_route_13_beauty_lola",
	"kanto_route_13_beauty_sheila",
	"kanto_route_13_picnicker_valerie",
	"kanto_route_13_picnicker_gwen",
	"kanto_route_13_bird_keeper_perry",
	"kanto_route_13_biker_jared",
	"kanto_route_13_bird_keeper_robert",
]
var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_13.tscn") as PackedScene).instantiate()
	check(map.encounter_area_id == "kanto_route_13", "Server encounter area is configured")
	check(is_equal_approx(map.grass_encounter_chance, 0.21), "Grass chance is configured")
	check(is_equal_approx(map.surf_encounter_chance, 0.02), "Surf chance is configured")
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	check(not grass.is_visible_in_tree() and not grass.get_used_cells().is_empty(), "Encounter grass exists")
	for cell in grass.get_used_cells():
		check(map.get_node("Visual/Grass").get_cell_source_id(cell) != -1, "Encounter grass has artwork")
	var npcs := map.get_node("Entities/NPCs").get_children()
	check(npcs.size() == TRAINER_IDS.size(), "All ten Route 13 trainers exist")
	var ids := {}
	var reachable := reachable_cells(map, Vector2i(map.get_node("Spawns/FromRoute12").position / 32.0))
	for npc in npcs:
		check(not ids.has(npc.npc_id), "NPC IDs are unique")
		ids[npc.npc_id] = true
		check(TRAINER_IDS.has(npc.trainer_id), "Trainer ID belongs to Route 13 roster")
		check(npc.npc_sprite_frames != null, "Trainer has overworld art")
		var cell := Vector2i(npc.position / 32.0)
		check(clear_cell(map, cell), "Trainer stands on walkable land: " + npc.name)
		check(reachable.has(cell), "Trainer is reachable from Route 12: " + npc.name)
		for step in range(1, npc.sight_range_tiles + 1):
			check(clear_cell(map, cell + Vector2i(npc.facing_direction) * step), "Trainer sight is clear: " + npc.name)
		for spawn in map.get_node("Spawns").get_children():
			check(npc.position.distance_to(spawn.position) >= 96.0, "Trainer does not block the Route 12 spawn")
	map.free()
	if not failed:
		print("PASS Route 13: encounters, ten trainers, artwork and safe placement")
	quit(1 if failed else 0)

func clear_cell(map: Node, cell: Vector2i) -> bool:
	return map.get_node("Tiles/Collision").get_cell_source_id(cell) == -1 and map.get_node("Tiles/Water").get_cell_source_id(cell) == -1

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func reachable_cells(map: Node, start: Vector2i) -> Dictionary:
	var visited := {start: true}
	var pending: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if next.x >= 0 and next.x < 96 and next.y >= 0 and next.y < 38 and not visited.has(next) and clear_cell(map, next):
				visited[next] = true
				pending.append(next)
	return visited
