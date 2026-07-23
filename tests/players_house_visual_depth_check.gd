extends SceneTree

const PlayersHouseVisualScene := preload("res://generated/tiled_visuals/players_house/players_house.visual.tscn")
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"

const TOP_LAYER_PATH := NodePath("Objects Top")

var failed := false


func _init() -> void:
	var players_house_visual := PlayersHouseVisualScene.instantiate()
	var top_layer := players_house_visual.get_node_or_null(TOP_LAYER_PATH) as TileMapLayer
	_check(top_layer != null, "Player's House exposes layer 4 as Objects Top")
	if top_layer == null:
		players_house_visual.free()
		quit(1)
		return

	_check(
		str(top_layer.get_meta("tiled_name", "")) == "Objects Top",
		"Player's House layer 4 opts into shared visual depth sorting"
	)
	_check(not top_layer.get_used_cells().is_empty(), "Objects Top contains foreground object tiles")

	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check(
		world_source.contains('"Objects Top",'),
		"World recognizes Objects Top as a shared depth-sorted visual layer"
	)
	_check(
		world_source.contains("_build_structure_top_visual_depth_groups(map)"),
		"World builds connected object depth groups when a map loads"
	)

	players_house_visual.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
