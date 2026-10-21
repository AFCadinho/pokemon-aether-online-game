# Run through slot-env with a real display. This uses the native renderer.
extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
var house_door := false
var gym_door := false
var pewter_gym := false
var origin := Vector2(1024, 1216)
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Door render check requires a display")
		quit(2)
		return
	if house_door:
		origin = Vector2(1440, 832)
	if gym_door:
		origin = Vector2(480, 464) if pewter_gym else Vector2(1216, 336)
	var world: Node = load("res://scripts/world/world.gd").new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224,128) if house_door or gym_door else Vector2i(224,288)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	viewport.canvas_transform.origin = -origin
	var city := (load("res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn" if pewter_gym else CITY) as PackedScene).instantiate()
	var visual := city.get_node("PewterCity" if pewter_gym else "ViridianCity")
	city.remove_child(visual)
	city.free()
	var map := Node2D.new()
	viewport.add_child(map)
	map.add_child(visual)
	var door := visual.get_node(("GymDoubleSlidingDoor" if gym_door else ("House1HingedDoor" if house_door else "PokemonCenterSlidingDoor")))
	door.set_process(false)
	world.call("_normalize_map_depth_layer_z_indices", map)
	var output := "user://viridian-house-door-review" if house_door else "user://viridian-door-review"
	if gym_door:
		output = "user://pewter-gym-door-review" if pewter_gym else "user://viridian-gym-door-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	door.visible = false
	await process_frame
	RenderingServer.force_draw(true, 0.0)
	var reference := viewport.get_texture().get_image()
	door.visible = true
	var previous: Image
	var steps := 6 if house_door else 4
	for step in range(steps + 1):
		door.open_amount = float(step) / steps
		await process_frame
		RenderingServer.force_draw(true, 0.0)
		var frame := viewport.get_texture().get_image()
		frame.save_png(output + "/door_%d.png" % step)
		if step == 0:
			_check(frame.get_data() == reference.get_data(), "Closed door matches original map pixels")
		else:
			_check(frame.get_data() != previous.get_data(), "Opening step %d visibly changes" % step)
		var outside_changes := 0
		var aperture := (Rect2i(96,22,32,38) if house_door else Rect2i(92,200,40,44))
		for y in range(frame.get_height()):
			for x in range(frame.get_width()):
				if not (_gym_aperture(Vector2i(x,y)) if gym_door else aperture.has_point(Vector2i(x,y))) and frame.get_pixel(x,y) != reference.get_pixel(x,y):
					outside_changes += 1
		_check(outside_changes == 0, "Step %d preserves facade, frame, sidelights and threshold" % step)
		if gym_door and step == 1:
			_check(frame.get_pixel(92, 58) == reference.get_pixel(98, 58), "Left leaf translates left")
			_check(frame.get_pixel(131, 58) == reference.get_pixel(125, 58), "Right leaf translates right")
			_check(frame.get_pixel(111, 58).is_equal_approx(door.opening_color) and frame.get_pixel(112, 58).is_equal_approx(door.opening_color), "Opening starts at the center seam")
		previous = frame
	_check((previous.get_pixel(112,50) if gym_door else (previous.get_pixel(112,44) if house_door else previous.get_pixel(112,220))).is_equal_approx(door.opening_color), "Fully open reveals dark doorway")
	if house_door:
		# Check the complete original leaf, including its six shaded top rows
		# and rightmost edge; checking only the center missed both remnants.
		var remaining_pixels := 0
		for y in range(22, 60):
			for x in range(96, 128):
				if not previous.get_pixel(x, y).is_equal_approx(door.opening_color):
					remaining_pixels += 1
		_check(remaining_pixels == 0, "Fully open house door leaves no original top strip or leaf edge")

	if gym_door:
		var remaining := 0
		for y in range(32,70):
			for x in range(88,136):
				if _gym_aperture(Vector2i(x,y)) and not previous.get_pixel(x,y).is_equal_approx(door.opening_color):
					remaining += 1
		_check(remaining == 0, "Both gym leaves and the center seam disappear completely")

	door.open_amount = 0.0
	await process_frame
	RenderingServer.force_draw(true,0.0)
	_check(viewport.get_texture().get_image().get_data() == reference.get_data(), "Closing restores exact original artwork")
	print("Door review images: ", ProjectSettings.globalize_path(output))
	viewport.free(); world.free()
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	failed = failed or not ok

func _gym_aperture(pixel: Vector2i) -> bool:
	var x := pixel.x - 88
	if x < 0 or x >= 48:
		return false
	var edge := mini(x, 47 - x)
	var top := 32 + (0 if edge < 2 else (2 if edge < 10 else (4 if edge < 20 else 6)))
	return pixel.y >= top and pixel.y < top + 32
