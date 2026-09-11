extends SceneTree

const PALLET_VISUAL_SCENE := preload("res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn")

var failed := false


func _init() -> void:
	var visual := PALLET_VISUAL_SCENE.instantiate()
	var expected_tile_counts := {
		"Ground": 2000,
		"GroundDetail": 1307,
		"Objects": 832,
		"ObjectsTop": 234,
		"Doors": 3,
	}
	for layer_name: String in expected_tile_counts:
		var layer := visual.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		_check(layer != null, "%s visual layer exists" % layer_name)
		if layer == null:
			continue
		_check(layer.tile_set != null, "%s layer has its generated TileSet" % layer_name)
		_check(
			layer.get_used_cells().size() == int(expected_tile_counts[layer_name]),
			"%s layer keeps every painted Pallet Town tile" % layer_name
		)
	visual.free()
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failed = true
	push_error("FAIL: %s" % description)
