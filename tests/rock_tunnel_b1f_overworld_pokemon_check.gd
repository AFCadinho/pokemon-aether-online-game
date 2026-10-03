extends SceneTree

const SCENE_PATH := "res://scenes/overworld/kanto/caves/rock_tunnel/b1f.tscn"
const EXPECTED_POKEMON := {
	"Cubone": ["kanto_rock_tunnel_b1f_cubone_1", "cubone", Vector2(1712, 848)],
	"Onix": ["kanto_rock_tunnel_b1f_onix_1", "onix", Vector2(2032, 848)],
	"Geodude": ["kanto_rock_tunnel_b1f_geodude_1", "geodude", Vector2(528, 400)],
	"Zubat": ["kanto_rock_tunnel_b1f_zubat_1", "zubat", Vector2(1136, 336)],
	"Machop": ["kanto_rock_tunnel_b1f_machop_1", "machop", Vector2(1840, 464)],
	"Mankey": ["kanto_rock_tunnel_b1f_mankey_1", "mankey", Vector2(1136, 1136)],
	"Machoke": ["kanto_rock_tunnel_b1f_machoke_1", "machoke", Vector2(528, 1840)],
	"Cubone2": ["kanto_rock_tunnel_b1f_cubone_2", "cubone", Vector2(1456, 2096)],
	"Geodude2": ["kanto_rock_tunnel_b1f_geodude_2", "geodude", Vector2(2480, 1808)],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	var pokemon_root := map.get_node("Entities/Pokemon")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var ground := map.get_node("Visual/Ground") as TileMapLayer
	var water := map.get_node("Tiles/Water") as TileMapLayer
	var npc_cells := _collect_cells(map.get_node("Entities/NPCs"), collision)
	var item_cells := _collect_cells(map.get_node("Entities/Interactables/Items"), collision)
	var pokemon_cells: Dictionary = {}
	var pokemon_ids: Dictionary = {}
	_check(pokemon_root.get_child_count() == EXPECTED_POKEMON.size(), "Rock Tunnel B1F has nine overworld Pokemon")
	for node_name: String in EXPECTED_POKEMON:
		var expected: Array = EXPECTED_POKEMON[node_name]
		var pokemon := pokemon_root.get_node_or_null(node_name) as Node2D
		_check(pokemon != null, "%s exists in Rock Tunnel B1F" % node_name)
		if pokemon == null:
			continue
		var pokemon_id := str(pokemon.get("overworld_pokemon_id"))
		_check(pokemon_id == expected[0], "%s has its canonical content ID" % node_name)
		_check(not pokemon_ids.has(pokemon_id), "%s has a unique content ID" % node_name)
		pokemon_ids[pokemon_id] = true
		_check(str(pokemon.get("species_id")) == expected[1], "%s uses the expected cave species" % node_name)
		_check(pokemon.position == expected[2], "%s stays at its designed cave position" % node_name)
		_check(FollowerSpriteService.get_sprite_frames(expected[1], false) != null, "%s follower sprite resolves" % node_name)
		_check(str(pokemon.get("movement_behavior")) == "pace_vertical", "%s uses a short vertical patrol" % node_name)
		_check(int(pokemon.get("movement_tiles")) == 1, "%s patrols one tile at a time" % node_name)
		var center := collision.local_to_map(collision.to_local(pokemon.global_position))
		_check(not pokemon_cells.has(center), "%s does not overlap another Pokemon" % node_name)
		_check(not npc_cells.has(center), "%s does not overlap a trainer" % node_name)
		_check(not item_cells.has(center), "%s does not overlap a pickup" % node_name)
		pokemon_cells[center] = true
		for offset in range(-1, 2):
			var cell: Vector2i = center + Vector2i.DOWN * offset
			_check(ground.get_cell_source_id(cell) >= 0, "%s patrol stays on cave floor" % node_name)
			_check(collision.get_cell_source_id(cell) < 0, "%s patrol stays walkable" % node_name)
			_check(water.get_cell_source_id(cell) < 0, "%s patrol stays out of water" % node_name)
	map.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _collect_cells(container: Node, collision: TileMapLayer) -> Dictionary:
	var cells: Dictionary = {}
	for node: Node in container.get_children():
		if not node is Node2D:
			continue
		var actor := node as Node2D
		cells[collision.local_to_map(collision.to_local(actor.global_position))] = true
	return cells


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
