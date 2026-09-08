extends SceneTree

const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const LedgeDirectionResolverScript := preload("res://scripts/world/ledge_direction_resolver.gd")
const COLLISION_MARKER_TILESET := preload("res://resources/world/collision_marker_tileset.tres")
const POKEMON_CENTER_TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const PLAYER_SCRIPT_PATH := "res://scripts/world/player.gd"
const NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	_check_pokemon_center_template_collision()
	_check_direct_layer_priority()
	await _check_map_metadata_collision_contract()
	_check_collision_consumers_use_recursive_lookup()
	_check_multidirectional_ledge_cell()
	quit(1 if failed else 0)


func _check_pokemon_center_template_collision() -> void:
	var template_source := FileAccess.get_file_as_string(POKEMON_CENTER_TEMPLATE_PATH)
	_check(
		template_source.contains('[node name="Collision" type="TileMapLayer" parent="."]')
		or template_source.contains('[node name="Collision" type="TileMapLayer" parent="." unique_id='),
		"Pokémon Center template owns the shared collision layer"
	)
	_check(
		template_source.contains("tile_map_data = PackedByteArray("),
		"Pokémon Center template collision has blocking cells"
	)

	var map_root := Node2D.new()
	var visuals := Node2D.new()
	visuals.name = "Visuals"
	map_root.add_child(visuals)
	var nested_collision := TileMapLayer.new()
	nested_collision.name = "Collision"
	visuals.add_child(nested_collision)
	_check(
		MapLayerResolverScript.find_tilemap_layer(map_root, ["Collision"]) == nested_collision,
		"Recursive resolver finds a nested template collision"
	)
	map_root.free()


func _check_direct_layer_priority() -> void:
	var map_root := Node2D.new()
	var nested_container := Node2D.new()
	nested_container.name = "Visuals"
	map_root.add_child(nested_container)
	var nested_collision := TileMapLayer.new()
	nested_collision.name = "Collision"
	nested_container.add_child(nested_collision)
	var direct_collision := TileMapLayer.new()
	direct_collision.name = "Collision"
	map_root.add_child(direct_collision)

	_check(
		MapLayerResolverScript.find_tilemap_layer(map_root, ["Collision"]) == direct_collision,
		"Direct collision keeps priority over a nested fallback"
	)
	var nested_grass := TileMapLayer.new()
	nested_grass.name = "TallGrass"
	nested_container.add_child(nested_grass)
	_check(
		MapLayerResolverScript.find_tilemap_layer(map_root, ["TallGrass"]) == nested_grass,
		"Recursive resolver finds a nested TallGrass scene mask"
	)
	map_root.free()


func _check_map_metadata_collision_contract() -> void:
	var direct_map := MapMetadataScript.new()
	var direct_collision := TileMapLayer.new()
	direct_collision.name = "Collision"
	direct_map.add_child(direct_collision)
	get_root().add_child(direct_map)
	await process_frame
	_check(
		direct_map.collision == direct_collision,
		"Map metadata resolves a direct Collision layer"
	)
	direct_map.free()

	var nested_map := MapMetadataScript.new()
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	nested_map.add_child(tiles)
	var nested_collision := TileMapLayer.new()
	nested_collision.name = "Collision"
	tiles.add_child(nested_collision)
	get_root().add_child(nested_map)
	await process_frame
	_check(
		nested_map.collision == nested_collision,
		"Map metadata resolves Tiles/Collision through its nested fallback"
	)
	nested_map.free()


func _check_collision_consumers_use_recursive_lookup() -> void:
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	_check(
		player_source.contains(
			'collision_tilemap = _find_tilemap_layer(current_map, ["Collision"])'
		),
		"Player refresh resolves nested collision"
	)
	_check(
		player_source.contains(
			'grass_tilemap = _find_tall_grass_tilemap(current_map)'
		),
		"Player refresh uses the TallGrass scene-mask resolver"
	)
	_check(
		player_source.contains(
			'_find_tilemap_layer(parent_node, ["Collision", "TallGrass"])'
		),
		"Player map discovery accepts direct and nested collision layers"
	)
	_check(
		player_source.contains('get_node_or_null("Tiles/TallGrass") as TileMapLayer'),
		"Player prefers the canonical Tiles/TallGrass scene path"
	)
	_check(
		player_source.contains('block_left_tilemap = _find_tilemap_layer(current_map, ["BlockLeft"])')
		and player_source.contains('block_right_tilemap = _find_tilemap_layer(current_map, ["BlockRight"])')
		and player_source.contains('direction == Vector2.LEFT')
		and player_source.contains('direction == Vector2.RIGHT'),
		"Player movement resolves and checks horizontal direction blocks"
	)
	var npc_source := FileAccess.get_file_as_string(NPC_SCRIPT_PATH)
	_check(
		npc_source.contains(
			'MapLayerResolverScript.find_tilemap_layer('
		),
		"NPC movement resolves nested collision"
	)
	_check_npc_collision_layer_cache()
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("return MapLayerResolverScript.find_tilemap_layer("),
		"World position snapping resolves nested map layers"
	)
	var metadata_source := FileAccess.get_file_as_string(
		"res://scripts/world/map_metadata.gd"
	)
	_check(
		metadata_source.contains(
			'@onready var collision: TileMapLayer = find_map_tilemap_layer("Collision")'
		),
		"Every standard map inherits the shared collision resolver"
	)


func _check_npc_collision_layer_cache() -> void:
	var npc_script := load(NPC_SCRIPT_PATH) as Script
	var npc := npc_script.new() as Node2D
	var first_map := Node2D.new()
	var first_tiles := Node2D.new()
	first_map.add_child(first_tiles)
	var first_collision := TileMapLayer.new()
	first_collision.name = "Collision"
	first_tiles.add_child(first_collision)
	var second_map := Node2D.new()
	var second_collision := TileMapLayer.new()
	second_collision.name = "Collision"
	second_map.add_child(second_collision)

	_check(
		npc.call("_get_movement_collision_tilemap", first_map) == first_collision,
		"NPC resolves a nested collision layer once for its current map"
	)
	first_collision.name = "RenamedAfterResolution"
	_check(
		npc.call("_get_movement_collision_tilemap", first_map) == first_collision,
		"NPC reuses its valid collision layer without another tree search"
	)
	_check(
		npc.call("_get_movement_collision_tilemap", second_map) == second_collision,
		"NPC refreshes its collision layer when the active map changes"
	)
	var late_map := Node2D.new()
	_check(
		npc.call("_get_movement_collision_tilemap", late_map) == null,
		"NPC accepts a map whose collision layer is not available yet"
	)
	var late_collision := TileMapLayer.new()
	late_collision.name = "Collision"
	late_map.add_child(late_collision)
	_check(
		npc.call("_get_movement_collision_tilemap", late_map) == late_collision,
		"NPC retries a missing collision layer on the same map"
	)

	npc.free()
	first_map.free()
	second_map.free()
	late_map.free()


func _check_multidirectional_ledge_cell() -> void:
	var map_root := Node2D.new()
	var ledge_up := TileMapLayer.new()
	ledge_up.name = "LedgeUp"
	ledge_up.tile_set = COLLISION_MARKER_TILESET
	map_root.add_child(ledge_up)
	var ledge_right := TileMapLayer.new()
	ledge_right.name = "LedgeRight"
	ledge_right.tile_set = COLLISION_MARKER_TILESET
	map_root.add_child(ledge_right)

	var ledge_cell := Vector2i(2, 3)
	ledge_up.set_cell(ledge_cell, 0, Vector2i.ZERO)
	ledge_right.set_cell(ledge_cell, 0, Vector2i.ZERO)

	var directions := LedgeDirectionResolverScript.directions_for_tile(
		ledge_up.map_to_local(ledge_cell),
		null,
		ledge_up,
		null,
		ledge_right
	)
	_check(
		directions.has(Vector2.UP) and directions.has(Vector2.RIGHT),
		"One ledge cell can allow both up and right movement"
	)
	_check(
		not directions.has(Vector2.DOWN) and not directions.has(Vector2.LEFT),
		"A multidirectional ledge cell does not allow unmarked directions"
	)

	map_root.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
