extends Node2D
class_name FloorVisibilityMask

@export var floor_regions: Dictionary = {}
@export var active_floor: StringName = &"ground_floor"
@export var follow_player_floor := true
@export var mask_color := Color.BLACK
@export_range(1024.0, 131072.0, 256.0) var mask_extent := 65536.0

@onready var top_mask: Polygon2D = $Top
@onready var bottom_mask: Polygon2D = $Bottom
@onready var left_mask: Polygon2D = $Left
@onready var right_mask: Polygon2D = $Right


func _ready() -> void:
	_apply_active_floor()


func _process(_delta: float) -> void:
	if not follow_player_floor:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var map_root := get_parent()
	if player == null or map_root == null or not map_root.is_ancestor_of(player):
		return

	var player_position := to_local(player.global_position)
	for floor_name_value: Variant in floor_regions:
		var floor_name := StringName(floor_name_value)
		var region_value: Variant = floor_regions[floor_name_value]
		if region_value is Rect2 and (region_value as Rect2).has_point(player_position):
			if floor_name != active_floor:
				show_floor(floor_name)
			return


func show_floor(floor_name: StringName) -> void:
	if not floor_regions.has(floor_name):
		push_warning("FloorVisibilityMask: unknown floor '%s'." % floor_name)
		return

	active_floor = floor_name
	_apply_active_floor()


func get_active_floor_region() -> Rect2:
	var region_value: Variant = floor_regions.get(active_floor, Rect2())
	if region_value is Rect2:
		return region_value as Rect2
	return Rect2()


func _apply_active_floor() -> void:
	var visible_region := get_active_floor_region()
	if visible_region.size.x <= 0.0 or visible_region.size.y <= 0.0:
		push_warning("FloorVisibilityMask: floor '%s' has no valid visible region." % active_floor)
		visible = false
		return

	visible = true
	for mask: Polygon2D in [top_mask, bottom_mask, left_mask, right_mask]:
		mask.color = mask_color

	var left := visible_region.position.x
	var top := visible_region.position.y
	var right := visible_region.end.x
	var bottom := visible_region.end.y
	var outer_left := left - mask_extent
	var outer_top := top - mask_extent
	var outer_right := right + mask_extent
	var outer_bottom := bottom + mask_extent

	top_mask.polygon = _rectangle_polygon(outer_left, outer_top, outer_right, top)
	bottom_mask.polygon = _rectangle_polygon(outer_left, bottom, outer_right, outer_bottom)
	left_mask.polygon = _rectangle_polygon(outer_left, top, left, bottom)
	right_mask.polygon = _rectangle_polygon(right, top, outer_right, bottom)


func _rectangle_polygon(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(left, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
	])
