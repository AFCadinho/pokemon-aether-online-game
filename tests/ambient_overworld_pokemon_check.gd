extends SceneTree

const MAP_POKEMON := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": {
		"Horsea": "horsea",
		"Pikachu": "pikachu",
		"Krabby": "krabby",
	},
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn": {
		"Lillipup": "lillipup",
		"Pidgey": "pidgey",
		"Rattata": "rattata",
		"Sentret": "sentret",
	},
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": {
		"Slowpoke": "slowpoke",
		"Poliwag": "poliwag",
	},
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn": {
		"Mankey": "mankey",
		"Spearow": "spearow",
	},
	"res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn": {
		"Caterpie": "caterpie",
		"Pidgey": "pidgey",
	},
	"res://scenes/overworld/kanto/routes/viridian_forest.tscn": {
		"Caterpie": "caterpie",
		"Weedle": "weedle",
		"Pikachu": "pikachu",
	},
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": {
		"Geodude": "geodude",
		"Pidgey": "pidgey",
	},
}

var failed := false
var pokemon_ids: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in MAP_POKEMON:
		_check_map(scene_path, MAP_POKEMON[scene_path])
	_check(pokemon_ids.size() == 18, "all ambient Pokemon use unique metadata ids")
	quit(1 if failed else 0)


func _check_map(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var map := packed.instantiate()
	var pokemon_root := map.get_node_or_null("Entities/Pokemon")
	var collision := map.get_node_or_null("Collision") as TileMapLayer
	_check(pokemon_root != null, "%s has an ambient Pokemon group" % scene_path.get_file())
	_check(collision != null, "%s exposes collision data" % scene_path.get_file())
	if pokemon_root == null:
		map.free()
		return
	_check(pokemon_root.get_child_count() >= 2, "%s contains multiple ambient Pokemon" % scene_path.get_file())
	var occupied_cells: Dictionary = {}
	var npc_cells := _collect_npc_cells(map, collision)
	for node_name: String in expected:
		var pokemon := pokemon_root.get_node_or_null(node_name) as Node2D
		_check(pokemon != null, "%s places %s" % [scene_path.get_file(), node_name])
		if pokemon == null:
			continue
		var expected_species := str(expected[node_name])
		_check(str(pokemon.get("species_id")) == expected_species, "%s uses %s" % [node_name, expected_species])
		var metadata_id := str(pokemon.get("overworld_pokemon_id"))
		_check(not metadata_id.is_empty(), "%s has metadata identity" % node_name)
		_check(not pokemon_ids.has(metadata_id), "%s metadata identity is unique" % node_name)
		pokemon_ids[metadata_id] = true
		_check(
			FollowerSpriteService.get_sprite_frames(expected_species, false) != null,
			"%s follower sprite resolves" % node_name
		)
		if collision == null:
			continue
		var cell := collision.local_to_map(collision.to_local(pokemon.global_position))
		_check(collision.get_cell_source_id(cell) == -1, "%s stands on a walkable tile" % node_name)
		_check(not occupied_cells.has(cell), "%s does not overlap another ambient Pokemon" % node_name)
		_check(not npc_cells.has(cell), "%s does not overlap a human NPC" % node_name)
		occupied_cells[cell] = true
		_check_movement_lane(pokemon, collision, cell)
	map.free()


func _collect_npc_cells(map: Node, collision: TileMapLayer) -> Dictionary:
	var cells: Dictionary = {}
	if collision == null:
		return cells
	var npc_root := map.get_node_or_null("Entities/NPCs")
	if npc_root == null:
		return cells
	for node: Node in npc_root.find_children("*", "", true, false):
		if not node is Node2D or not _has_property(node, &"npc_id"):
			continue
		var npc := node as Node2D
		var cell := collision.local_to_map(collision.to_local(npc.global_position))
		cells[cell] = true
	return cells


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func _check_movement_lane(pokemon: Node2D, collision: TileMapLayer, cell: Vector2i) -> void:
	var behavior := str(pokemon.get("movement_behavior"))
	if behavior == "idle":
		return
	var step := Vector2i.RIGHT if behavior == "pace_horizontal" else Vector2i.DOWN
	var forward_clear := collision.get_cell_source_id(cell + step) == -1
	var backward_clear := collision.get_cell_source_id(cell - step) == -1
	_check(forward_clear or backward_clear, "%s has room to pace" % pokemon.name)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
