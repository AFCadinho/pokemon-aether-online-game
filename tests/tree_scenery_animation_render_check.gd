# Native animation regression: run with a real display, never --headless.
# No source atlas or animation is frozen or mutated to build the reference.
extends SceneTree

const Occlusion := preload("res://scripts/world/tree_scenery_occlusion.gd")
const Trees := preload("res://scripts/world/tree_lower_depth_sorting.gd")
const CASES := [
	["viridian_city", Vector2i(39, 20), Vector2i(26, 8)],
	["kanto_route_2", Vector2i(44, 12), Vector2i(7, 7)],
	["kanto_route_2", Vector2i(43, 23), Vector2i(11, 7)],
]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Tree animation rendering needs a real display driver")
		quit(2)
		return
	var world: Node = load("res://scripts/world/world.gd").new()
	var output := "user://tree-scenery-animation-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for index in range(CASES.size()):
		var spec: Array = CASES[index]
		var actual := _viewport(world, spec, false)
		var reference := _viewport(world, spec, true)
		var different := 0
		var changed_frames := 0
		var previous := PackedByteArray()
		# 96 samples span the complete 48 x 70ms foliage cycle, including the
		# native timing of both complementary pieces and neighbouring crowns.
		for sample in range(96):
			await create_timer(0.04).timeout
			await RenderingServer.frame_post_draw
			var a := actual.get_texture().get_image()
			var b := reference.get_texture().get_image()
			var pixels := a.get_data()
			if pixels != b.get_data():
				different += 1
				if different == 1:
					a.save_png(output + "/%d_mismatch_actual.png" % index)
					b.save_png(output + "/%d_mismatch_reference.png" % index)
			if not previous.is_empty() and pixels != previous:
				changed_frames += 1
			previous = pixels
			if sample == 0:
				a.save_png(output + "/%d_fixed.png" % index)
				b.save_png(output + "/%d_reference.png" % index)
		var passed := different == 0 and changed_frames > 0
		print("TREE_ANIMATION_RENDER %s %s mismatches=%d moving_samples=%d %s" % [spec[0], spec[1], different, changed_frames, "PASS" if passed else "FAIL"])
		failed = failed or not passed
		actual.free()
		reference.free()
	world.free()
	print("Tree animation render output: ", ProjectSettings.globalize_path(output))
	quit(1 if failed else 0)


func _viewport(world: Node, spec: Array, reference: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = spec[2] * 32
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var map: Node = load("res://generated/tiled_visuals/%s/%s.visual.tscn" % [spec[0], spec[0]]).instantiate()
	viewport.add_child(map)
	var originals := {}
	if reference:
		var layers: Array[TileMapLayer] = []
		Occlusion._collect_layers(map, layers)
		for layer: TileMapLayer in layers:
			if Trees.BOTTOM_LAYER_NAMES.has(str(layer.name)):
				originals[layer] = layer.duplicate(0)
	world.call("_normalize_map_depth_layer_z_indices", map)
	if reference:
		var layers: Array[TileMapLayer] = []
		Occlusion._collect_layers(map, layers)
		for layer: TileMapLayer in layers:
			if layer.get_meta(Occlusion.TREE_META, false):
				var base := layer.get_node(layer.get_meta(Occlusion.SOURCE_META)) as TileMapLayer
				var original: TileMapLayer = originals[base]
				for cell: Vector2i in layer.get_used_cells():
					# Restore only promoted tree cells, not unrelated lamp-post
					# cells already moved by object-depth normalization.
					base.set_cell(cell, original.get_cell_source_id(cell), original.get_cell_atlas_coords(cell), original.get_cell_alternative_tile(cell))
				layer.free()
		for layer: TileMapLayer in originals:
			var original: TileMapLayer = originals[layer]
			layer.tile_set = original.tile_set
			original.free()
	viewport.canvas_transform.origin = -Vector2(spec[1] * 32)
	return viewport
