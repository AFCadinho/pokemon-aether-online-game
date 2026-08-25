extends SceneTree

const PlayersHouseVisualScene := preload("res://generated/tiled_visuals/players_house/players_house.visual.tscn")
const PokemonLaboratoryVisualScene := preload("res://generated/tiled_visuals/pokemon_laboratory/pokemon_laboratory.visual.tscn")
const PokemonCenterVisualScene := preload("res://generated/tiled_visuals/pokemon_center/pokemon_center.visual.tscn")
const VerticalTransitionBuildingVisualScene := preload("res://generated/tiled_visuals/transition_building_vertical/transition_building_vertical.visual.tscn")
const AetherClashLobbyVisualScene := preload("res://generated/tiled_visuals/lobby/lobby.visual.tscn")
const MtMoonB1FVisualScene := preload("res://generated/tiled_visuals/mt_moon_b1f/mt_moon_b1f.visual.tscn")
const MtMoonB2FVisualScene := preload("res://generated/tiled_visuals/mt_moon_b2f/mt_moon_b2f.visual.tscn")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"

var failed := false


func _init() -> void:
	_check_visual(PlayersHouseVisualScene, "Player's House", &"Objects Top")
	_check_visual(PokemonLaboratoryVisualScene, "Oak's Lab", &"StructuresTop")
	_check_visual(PokemonCenterVisualScene, "Pokémon Center template", &"StructuresTop")
	_check_visual(VerticalTransitionBuildingVisualScene, "vertical transition building", &"StructuresTop")
	_check_visual(AetherClashLobbyVisualScene, "Aether Clash Lobby", &"ObjectTop")
	_check_visual(MtMoonB1FVisualScene, "Mt. Moon B1F", &"ObjectsTop")
	_check_visual(MtMoonB2FVisualScene, "Mt. Moon B2F", &"ObjectsTop")

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains('"Objects Top",'),
		"World recognizes Objects Top as a shared depth-sorted visual layer"
	)
	_check(
		world_source.contains('"StructuresTop",'),
		"World recognizes StructuresTop as a shared depth-sorted visual layer"
	)
	_check(
		world_source.contains('"ObjectTop",'),
		"World recognizes the Lobby ObjectTop as a shared depth-sorted visual layer"
	)
	_check(
		world_source.contains('"ObjectsTop",'),
		"World recognizes ObjectsTop as a shared depth-sorted visual layer"
	)
	_check(
		world_source.contains("_build_structure_top_visual_depth_groups(map)"),
		"World builds connected object depth groups when a map loads"
	)
	_check_nameplate_depth()

	quit(1 if failed else 0)


func _check_visual(visual_scene: PackedScene, display_name: String, layer_name: StringName) -> void:
	var visual := visual_scene.instantiate()
	var top_layer := visual.get_node_or_null(NodePath(layer_name)) as TileMapLayer
	_check(top_layer != null, "%s exposes layer 4 as %s" % [display_name, layer_name])
	if top_layer != null:
		_check(
			str(top_layer.get_meta("tiled_name", "")) == layer_name,
			"%s layer 4 opts into shared visual depth sorting" % display_name
		)
		_check(
			not top_layer.get_used_cells().is_empty(),
			"%s %s contains foreground object tiles" % [display_name, layer_name]
		)
	visual.free()


func _check_nameplate_depth() -> void:
	var player_scene_source := FileAccess.get_file_as_string(PLAYER_SCENE_PATH)
	_check(
		player_scene_source.contains(
			'[node name="Nameplate" type="Control" parent="." unique_id=1400626741]\nvisible = false\nz_index = 4096\nz_as_relative = false'
		),
		"player nameplate renders in the absolute foreground band"
	)

	var npc_source := FileAccess.get_file_as_string(NPC_SCRIPT_PATH)
	_check(
		npc_source.contains(
			"nameplate.z_as_relative = false\n\tnameplate.z_index = RenderingServer.CANVAS_ITEM_Z_MAX"
		),
		"NPC nameplates render in the same absolute foreground band"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
