extends SceneTree

const FloorVisibilityMaskScript := preload("res://scripts/world/floor_visibility_mask.gd")

const GROUND_FLOOR_REGION := Rect2(64, 608, 480, 416)
const UPPER_FLOOR_REGION := Rect2(160, 0, 320, 448)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var map_root := Node2D.new()
	var player := Node2D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector2(464, 784)
	map_root.add_child(player)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.5, 1.5)
	player.add_child(camera)

	var floor_mask := Node2D.new()
	floor_mask.name = "FloorVisibilityMask"
	floor_mask.set_script(FloorVisibilityMaskScript)
	floor_mask.set("constrain_camera_to_active_floor", true)
	floor_mask.set("floor_regions", {
		&"ground_floor": GROUND_FLOOR_REGION,
		&"upper_floor": UPPER_FLOOR_REGION,
	})
	for mask_name: String in ["Top", "Bottom", "Left", "Right"]:
		var polygon := Polygon2D.new()
		polygon.name = mask_name
		floor_mask.add_child(polygon)
	map_root.add_child(floor_mask)
	root.add_child(map_root)

	await process_frame
	floor_mask.call("show_floor", &"ground_floor")
	await process_frame

	_check_camera_center(camera, GROUND_FLOOR_REGION.get_center(), "Ground floor")
	var ground_limits := _camera_limits(camera)
	player.position += Vector2.DOWN * 32.0
	await process_frame
	_check(
		_camera_limits(camera) == ground_limits,
		"One ground-floor step does not move the camera limits"
	)
	_check_camera_center(camera, GROUND_FLOOR_REGION.get_center(), "Ground floor after one step")

	player.position = Vector2(304, 336)
	floor_mask.call("show_floor", &"upper_floor")
	await process_frame
	_check_camera_center(camera, UPPER_FLOOR_REGION.get_center(), "Upper floor")

	map_root.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_camera_center(camera: Camera2D, expected_center: Vector2, label: String) -> void:
	var limit_center := Vector2(
		(float(camera.limit_left) + float(camera.limit_right)) * 0.5,
		(float(camera.limit_top) + float(camera.limit_bottom)) * 0.5
	)
	_check(limit_center.is_equal_approx(expected_center), "%s camera limits stay centered" % label)

	var visible_world_size := camera.get_viewport_rect().size / camera.zoom
	_check(
		float(camera.limit_right - camera.limit_left) >= visible_world_size.x,
		"%s camera limits cover the viewport width" % label
	)
	_check(
		float(camera.limit_bottom - camera.limit_top) >= visible_world_size.y,
		"%s camera limits cover the viewport height" % label
	)


func _camera_limits(camera: Camera2D) -> Vector4i:
	return Vector4i(
		camera.limit_left,
		camera.limit_top,
		camera.limit_right,
		camera.limit_bottom
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
