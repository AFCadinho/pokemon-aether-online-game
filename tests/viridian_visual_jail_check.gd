extends SceneTree

const VISUAL_SCENE_PATH := "res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn"

var failed := false


func _init() -> void:
	var packed := load(VISUAL_SCENE_PATH) as PackedScene
	_check(packed != null, "Viridian visual scene loads")
	if packed != null:
		var root := packed.instantiate()
		var structure_top := root.get_node_or_null("StructureTop") as TileMapLayer
		_check(structure_top != null, "Viridian visual exposes StructureTop")
		if structure_top != null:
			for cell: Vector2i in [Vector2i(46, 43), Vector2i(51, 44)]:
				_check(
					structure_top.get_cell_source_id(cell) >= 0,
					"Viridian jail lower section keeps tile %s" % cell
				)
		root.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
