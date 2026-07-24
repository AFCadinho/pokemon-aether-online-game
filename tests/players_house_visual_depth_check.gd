extends SceneTree

const PlayersHouseVisualScene := preload("res://generated/tiled_visuals/players_house/players_house.visual.tscn")
const PokemonLaboratoryVisualScene := preload("res://generated/tiled_visuals/pokemon_laboratory/pokemon_laboratory.visual.tscn")
const PokemonCenterVisualScene := preload("res://generated/tiled_visuals/pokemon_center/pokemon_center.visual.tscn")
const VerticalTransitionBuildingVisualScene := preload("res://generated/tiled_visuals/transition_building_vertical/transition_building_vertical.visual.tscn")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	_check_visual(PlayersHouseVisualScene, "Player's House", &"Objects Top")
	_check_visual(PokemonLaboratoryVisualScene, "Oak's Lab", &"StructuresTop")
	_check_visual(PokemonCenterVisualScene, "Pokémon Center template", &"StructuresTop")
	_check_visual(VerticalTransitionBuildingVisualScene, "vertical transition building", &"StructuresTop")

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
		world_source.contains("_build_structure_top_visual_depth_groups(map)"),
		"World builds connected object depth groups when a map loads"
	)

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


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
