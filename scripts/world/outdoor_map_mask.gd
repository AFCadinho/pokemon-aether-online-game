extends RefCounted

const FloorMaskScript := preload("res://scripts/world/floor_visibility_mask.gd")
const MASK_NAME := "OutdoorMapMask"


static func applies_to(map: Node) -> bool:
	var path := map.scene_file_path
	if not path.begins_with("res://scenes/overworld/"):
		return false
	if not ("/towns/" in path or "/routes/" in path):
		return false
	return str(map.get("world_access_area_type")) in ["exterior", "route"]


static func apply(map: Node, world_bounds: Rect2) -> void:
	if not applies_to(map) or not map is Node2D or not world_bounds.has_area():
		return
	var mask := map.get_node_or_null(NodePath(MASK_NAME)) as Node2D
	if mask != null:
		return
	mask = Node2D.new()
	mask.name = MASK_NAME
	mask.set_script(FloorMaskScript)
	mask.set("follow_player_floor", false)
	# Use the same visual bounds as the camera, without changing its zoom/limits.
	var local_bounds := Rect2(
		(map as Node2D).to_local(world_bounds.position),
		(map as Node2D).to_local(world_bounds.end) - (map as Node2D).to_local(world_bounds.position)
	).abs()
	mask.set("floor_regions", {&"ground_floor": local_bounds})
	mask.z_as_relative = false
	mask.z_index = 4096
	# Keep world lights from illuminating the black border.
	mask.light_mask = 0
	for side: String in ["Top", "Bottom", "Left", "Right"]:
		var polygon := Polygon2D.new()
		polygon.name = side
		polygon.light_mask = 0
		mask.add_child(polygon)
	map.add_child(mask)
