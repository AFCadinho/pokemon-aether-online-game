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
	await _check_small_house_movement()
	print("FLOOR_CAMERA ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check_camera_center(camera: Camera2D, expected_center: Vector2, label: String) -> void:
	var limit_center := Vector2(
		(float(camera.limit_left) + float(camera.limit_right)) * 0.5,
		(float(camera.limit_top) + float(camera.limit_bottom)) * 0.5
	)
	_check(limit_center.is_equal_approx(expected_center), "%s camera limits stay centered" % label)

	var visible_world_size := camera.get_viewport_rect().size / camera.zoom
	_check(
		absf(float(camera.limit_right - camera.limit_left) - visible_world_size.x) < 2.0,
		"%s camera limits fit the viewport width without scroll slack" % label
	)
	_check(
		absf(float(camera.limit_bottom - camera.limit_top) - visible_world_size.y) < 2.0,
		"%s camera limits fit the viewport height without scroll slack" % label
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


func _check_small_house_movement() -> void:
	var view := SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for scene_path: String in [
		"res://scenes/overworld/kanto/towns/fuchsia_city/tall_house.tscn",
		"res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn",
	]:
		var house := (load(scene_path) as PackedScene).instantiate()
		# Hide animated transition hints so screenshot comparisons isolate scenery.
		for group_name: String in ["Exits", "FloorTransitions"]:
			var group := house.get_node_or_null(group_name)
			if group != null:
				group.visible = false
				for area: Node in group.get_children():
					if area is Area2D:
						area.monitoring = false
		var npcs := house.get_node_or_null("Entities/NPCs")
		if npcs != null:
			npcs.free()
		view.add_child(house)
		var player := Node2D.new()
		player.add_to_group("player")
		house.get_node("Entities/Players").add_child(player)
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		player.add_child(camera)
		var mask: Node = house.get_node("FloorVisibilityMask")
		for output_size: Vector2i in [Vector2i(1280,720), Vector2i(1366,768), Vector2i(1920,1080)]:
			view.size = output_size
			for zoom: float in [1.5, 2.25]:
				camera.zoom = Vector2.ONE * zoom
				for floor_name: StringName in [&"ground_floor", &"upper_floor"]:
					var region: Rect2 = mask.floor_regions[floor_name]
					var label := "%s %s %s zoom %s" % [scene_path.get_file(), floor_name, output_size, zoom]
					player.position = region.get_center()
					mask.show_floor(floor_name)
					var reference_transform := Transform2D.IDENTITY
					var reference_pixels := PackedByteArray()
					var sample := 0
					# Cross the room center in both directions, horizontally and vertically.
					for offset: Vector2 in [Vector2(-0.25,0), Vector2(0,0), Vector2(0.25,0), Vector2(0,0.25), Vector2(0,-0.25), Vector2(-0.25,0)]:
						var displacement := region.size * offset
						var visible_size := Vector2(view.size) / camera.zoom
						if region.size.x > visible_size.x:
							displacement.x = 0.0
						if region.size.y > visible_size.y:
							displacement.y = 0.0
						player.position = region.get_center() + displacement
						await process_frame
						await process_frame
						camera.force_update_scroll()
						if sample == 0:
							reference_transform = view.canvas_transform
						else:
							_check(view.canvas_transform.origin.distance_to(reference_transform.origin) < 0.001, label + " scenery transform stays fixed during movement: %s vs %s, player %s, limits %s" % [view.canvas_transform.origin, reference_transform.origin, player.position, _camera_limits(camera)])
						if DisplayServer.get_name() != "headless":
							RenderingServer.force_draw(false)
							var pixels := view.get_texture().get_image().get_data()
							if sample == 0:
								reference_pixels = pixels
							else:
								_check(pixels == reference_pixels, label + " scenery pixels stay fixed during movement")
						sample += 1
		# A larger floor must still scroll normally instead of becoming fixed.
		mask.floor_regions = {&"large_floor": Rect2(0,0,2400,2000)}
		camera.zoom = Vector2(1.5,1.5)
		player.position = Vector2(800,800)
		mask.show_floor(&"large_floor")
		await process_frame
		camera.force_update_scroll()
		var initial_center := camera.get_screen_center_position()
		player.position += Vector2(320,160)
		await process_frame
		camera.force_update_scroll()
		_check(camera.get_screen_center_position().is_equal_approx(initial_center + Vector2(320,160)), "Larger floors retain normal camera following")
		house.free()
	view.free()
