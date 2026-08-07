extends SceneTree

const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")
const POKEMON_CENTER_TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn"
const PLAYER_SCRIPT_PATH := "res://scripts/world/player.gd"
const NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	_check_pokemon_center_template_collision()
	_check_direct_layer_priority()
	_check_collision_consumers_use_recursive_lookup()
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
	map_root.free()


func _check_collision_consumers_use_recursive_lookup() -> void:
	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	_check(
		player_source.contains(
			'collision_tilemap = _find_tilemap_layer(current_map, ["Collision"])'
		),
		"Player refresh resolves nested collision"
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
			'MapLayerResolverScript.find_tilemap_layer(current_map, ["Collision"])'
		),
		"NPC movement resolves nested collision"
	)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains("return MapLayerResolverScript.find_tilemap_layer("),
		"World position snapping resolves nested map layers"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
