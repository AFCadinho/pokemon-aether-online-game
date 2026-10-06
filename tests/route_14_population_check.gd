extends SceneTree

const TRAINER_IDS := [
	"kanto_route_14_bird_keeper_mitch",
	"kanto_route_14_biker_lukas",
	"kanto_route_14_bird_keeper_carter",
	"kanto_route_14_biker_isaac",
	"kanto_route_14_bird_keeper_marlon",
	"kanto_route_14_biker_malik",
	"kanto_route_14_bird_keeper_beck",
	"kanto_route_14_biker_gerald",
]
const PICKUPS := {
	"kanto_route_14_pinap_berry": "max-repel",
	"kanto_route_14_zinc": "zinc",
	"kanto_route_14_poison_barb": "poison-barb",
}
var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_14.tscn") as PackedScene).instantiate()
	check(map.encounter_area_id == "kanto_route_14", "Server encounter area is configured")
	check(is_equal_approx(map.grass_encounter_chance, 0.21), "Grass chance is configured")
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	check(not grass.get_used_cells().is_empty(), "Encounter grass exists")
	for cell in grass.get_used_cells():
		check(map.get_node("Visual/Grass2").get_cell_source_id(cell) != -1, "Encounter grass has artwork")
	var npcs := map.get_node("Entities/NPCs").get_children()
	check(npcs.size() == TRAINER_IDS.size(), "All eight Route 14 trainers exist")
	var seen := {}
	var reachable := reachable_cells(map, Vector2i(map.get_node("Spawns/FromRoute13").position / 32.0))
	for npc in npcs:
		check(not seen.has(npc.npc_id), "NPC IDs are unique")
		seen[npc.npc_id] = true
		check(TRAINER_IDS.has(npc.trainer_id), "Trainer ID belongs to Route 14")
		check(npc.npc_sprite_frames != null, "Trainer has overworld art")
		var cell := Vector2i(npc.position / 32.0)
		check(clear_cell(map, cell), "Trainer stands on walkable land: " + npc.name)
		check(reachable.has(cell), "Trainer is reachable from Route 13: " + npc.name)
		for step in range(1, npc.sight_range_tiles + 1):
			check(clear_cell(map, cell + Vector2i(npc.facing_direction) * step), "Trainer sight is clear: " + npc.name)
	for pickup in map.get_node("Entities/Interactables").get_children():
		check(PICKUPS.get(pickup.pickup_id, "") == pickup.item_id, "Route 14 pickup is registered: " + pickup.name)
		check(reachable.has(Vector2i(pickup.position / 32.0)), "Pickup is reachable: " + pickup.name)
	map.free()
	if not failed:
		print("PASS Route 14: encounters, eight trainers, art and three pickups")
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
			if next.x >= 0 and next.x < 48 and next.y >= 0 and next.y < 76 and not visited.has(next) and clear_cell(map, next):
				visited[next] = true
				pending.append(next)
	return visited
