extends Node2D
class_name FloorVisibilityMask

@export var floor_regions: Dictionary = {}
@export var active_floor: StringName = &"ground_floor"
@export var follow_player_floor := true
@export var constrain_camera_to_active_floor := false
@export var mask_color := Color.BLACK
@export_range(1024.0, 131072.0, 256.0) var mask_extent := 65536.0

@onready var top_mask: Polygon2D = $Top
@onready var bottom_mask: Polygon2D = $Bottom
@onready var left_mask: Polygon2D = $Left
@onready var right_mask: Polygon2D = $Right


func _ready() -> void:
	_apply_active_floor()
	_sync_camera_limits_to_active_floor()


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
			elif constrain_camera_to_active_floor:
				_sync_camera_limits_to_active_floor(player)
			return


func show_floor(floor_name: StringName) -> void:
	if not floor_regions.has(floor_name):
		push_warning("FloorVisibilityMask: unknown floor '%s'." % floor_name)
		return

	active_floor = floor_name
	_apply_active_floor()
	_sync_camera_limits_to_active_floor()


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


func _sync_camera_limits_to_active_floor(player: Node2D = null) -> void:
	if not constrain_camera_to_active_floor:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D

	var map_root := get_parent()
	if player == null or map_root == null or not map_root.is_ancestor_of(player):
		return

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var floor_region := get_active_floor_region()
	if floor_region.size.x <= 0.0 or floor_region.size.y <= 0.0:
		return

	var top_left := to_global(floor_region.position)
	var bottom_right := to_global(floor_region.end)
	var global_floor_region := Rect2(top_left, bottom_right - top_left).abs()

	var viewport_size := camera.get_viewport_rect().size
	var camera_zoom := Vector2(
		maxf(absf(camera.zoom.x), 0.001),
		maxf(absf(camera.zoom.y), 0.001)
	)
	var visible_world_size := viewport_size / camera_zoom
	var padded_size := Vector2(
		maxf(global_floor_region.size.x, visible_world_size.x),
		maxf(global_floor_region.size.y, visible_world_size.y)
	)
	var padded_region := Rect2(global_floor_region.get_center() - padded_size * 0.5, padded_size)

	var new_left := floori(padded_region.position.x)
	var new_top := floori(padded_region.position.y)
	var new_right := ceili(padded_region.end.x)
	var new_bottom := ceili(padded_region.end.y)
	if (
		camera.limit_left == new_left
		and camera.limit_top == new_top
		and camera.limit_right == new_right
		and camera.limit_bottom == new_bottom
	):
		return

	camera.limit_left = new_left
	camera.limit_top = new_top
	camera.limit_right = new_right
	camera.limit_bottom = new_bottom
	camera.reset_smoothing()
