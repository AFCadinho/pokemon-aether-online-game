extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn"
const Trees := preload("res://scripts/world/tree_lower_depth_sorting.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node = load("res://scripts/world/world.gd").new()
	var map: Node = load(ROUTE).instantiate()
	root.add_child(map)
	_check(map.individual_tree_depth_sorting, "Route 16 explicitly opts in")
	var visual: Node = map.get_node("Visual")
	var before := _visible_cells(visual)
	var crowns := Trees.find_complete_tree_crowns(visual.get_node("TreeTop"))
	_check(not crowns.is_empty(), "artist trees are recognized by their complete artwork")
	world.call("_normalize_map_depth_layer_z_indices",map)
	_check(_visible_cells(visual) == before, "normalization neither loses nor duplicates artwork")
	var tree := _layer_at(visual,Vector2i(12,6),"pao_tree_lower_depth_layer")
	var roof := _layer_at(visual,Vector2i(12,6),"pao_structure_top_depth_group","ObjectsTop")
	_check(tree != null and roof != null, "roof overlap is represented by real runtime layers")
	if tree != null and roof != null:
		_check(tree.z_index < roof.z_index, "trees behind the cottage stay behind its roof")
	var snapshot := _depth_snapshot(visual)
	world.call("_normalize_map_depth_layer_z_indices",map)
	_check(_depth_snapshot(visual) == snapshot and _visible_cells(visual) == before, "repeated normalization is idempotent")
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	state.current_map = map
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	local.set("depth_map",map)
	map.get_node("Entities/Players").add_child(local)
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	map.get_node("Entities/Players").add_child(remote)
	remote.set_process(false)
	for mount_id: String in ["","zekrom","zekrom_shiny"]:
		local.set("active_mount_id",mount_id)
		local.set("activity_style","walk" if mount_id.is_empty() else "ride")
		local.call("_apply_body_appearance",Appearance.DEFAULT_MALE_BODY_ID)
		local.call("_sync_mount_visual")
		remote.call("apply_state",{"userId":1,"gender":"female","position":{"x":400,"y":272},"movement":{"isMoving":false,"activityStyle":"walk" if mount_id.is_empty() else "ride","mountId":mount_id}})
		var checked_upper := false
		var checked_lower := false
		for crown in crowns:
			var origin: Vector2i = crown[0]
			if (origin.y < 16 and checked_upper) or (origin.y >= 16 and checked_lower): continue
			var lower := _layer_at(visual,origin+Vector2i(0,2),"pao_tree_lower_depth_layer")
			var upper := _layer_at(visual,origin,"pao_structure_top_depth_group","TreeTop")
			_check(lower != null and upper != null, "complete tree keeps both halves at runtime")
			if lower == null or upper == null: continue
			_check(lower.z_index == upper.z_index, "whole tree shares its own crown depth")
			for actor in [local,remote]:
				for offset in [-16,16]:
					actor.position = Vector2(origin.x*32+16,(origin.y+2)*32+offset)
					actor.call("_update_sort_z")
					_check((actor.z_index > lower.z_index) == (offset > 0), "walking/mounted local and remote players cross the tree boundary at every map height")
				if not mount_id.is_empty():
					_check_flat_mount(actor.get_node("Look"))
					var old_z: int = actor.z_index
					actor.call("_update_mount_hover",0.6)
					actor.call("_update_sort_z")
					_check(actor.z_index == old_z, "mount hover does not change ground depth")
			if origin.y < 16: checked_upper = true
			else: checked_lower = true
		_check(checked_upper and checked_lower, "both upper and lower map trees are checked")
	state.current_map = previous
	map.free()
	# Real maps that did not opt in must still use their original group partition.
	for name: String in ["viridian_city","kanto_route_2","kanto_route_22","viridian_forest"]:
		var original: Node = load("res://generated/tiled_visuals/%s/%s.visual.tscn" % [name,name]).instantiate()
		var container := Node2D.new()
		container.add_child(original)
		for layer in _layers(original):
			var cells := layer.get_used_cells()
			_check(world.call("_build_structure_depth_groups",container,layer,cells) == world.call("_build_connected_tile_groups",cells), name+" retains its existing grouping by default")
		container.free()
	world.free()
	print("ROUTE_16_TREE_DEPTH ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_flat_mount(node: Node) -> void:
	if node is CanvasItem and node.z_as_relative:
		_check(node.z_index == 0, "mount and rider stay together in world depth")
	for child in node.get_children(): _check_flat_mount(child)

func _layers(node: Node) -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	if node is TileMapLayer: result.append(node)
	for child in node.get_children(): result.append_array(_layers(child))
	return result

func _layer_at(node: Node,cell: Vector2i,meta: String,prefix := "") -> TileMapLayer:
	for layer in _layers(node):
		if layer.visible and layer.get_meta(meta,false) and str(layer.name).begins_with(prefix) and layer.get_cell_source_id(cell) >= 0:
			return layer
	return null

func _visible_cells(node: Node) -> Dictionary:
	var result := {}
	for layer in _layers(node):
		if not layer.visible: continue
		for cell in layer.get_used_cells():
			var key := "%s:%s:%s:%s:%s" % [cell,layer.tile_set.get_instance_id(),layer.get_cell_source_id(cell),layer.get_cell_atlas_coords(cell),layer.get_cell_alternative_tile(cell)]
			result[key] = int(result.get(key,0))+1
	return result

func _depth_snapshot(node: Node) -> Dictionary:
	var result := {}
	for layer in _layers(node):
		result[str(layer.get_path())] = [layer.z_index,layer.visible,layer.get_used_cells()]
	return result

func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
