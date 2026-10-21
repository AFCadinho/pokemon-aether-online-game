extends SceneTree

const LightRendering := preload("res://scripts/world/night_light_rendering.gd")
const MAX_POINT_LIGHTS_PER_ITEM := 15
var failed := false
var baseline := false


func _init() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	_run.call_deferred()


func _run() -> void:
	_check_configuration_scope()
	var celadon: Node2D
	var fuchsia: Node2D
	for city: String in ["celadon", "cerulean", "vermilion", "fuchsia"]:
		var map: Node2D = load("res://scenes/overworld/kanto/towns/%s_city/%s_city.tscn" % [city, city]).instantiate()
		if not baseline:
			if city == "celadon":
				# Exercise the actual map-load path, including dynamically split
				# depth layers; no World._ready or live account requests are needed.
				var collision: TileMapLayer = map.get_node("Tiles/Collision")
				var data: PackedByteArray = collision.get("tile_map_data")
				var runtime_world: Node = load("res://scripts/world/world.gd").new()
				runtime_world._normalize_map_depth_layer_z_indices(map)
				runtime_world.free()
				_check(collision.get("tile_map_data") == data, "World map loading preserves Celadon collision")
				for layer: Node in map.find_children("*", "TileMapLayer", true, false):
					if layer.visible:
						_check(layer.rendering_quadrant_size <= 4, "Runtime-created depth layers receive light batching")
			else:
				LightRendering.configure_map(map)
		var maximum := _maximum_lights_per_batch(map)
		_check(maximum <= MAX_POINT_LIGHTS_PER_ITEM, "%s tile batches fit the point-light budget (maximum %d)" % [city, maximum])
		print("NIGHT_LIGHT_BATCH_BUDGET ", city, " ", maximum)
		if city == "celadon":
			celadon = map
		elif city == "fuchsia":
			fuchsia = map
		else:
			map.free()
	if DisplayServer.get_name() != "headless":
		await _check_camera_pixels(celadon)
		await _check_camera_pixels(fuchsia, "Fuchsia", 44, [-64, 64, 192, 320, 448, 576, 704, 832, 960, 1088, 1216])
	else:
		print("Night-light pixel comparison requires a graphics renderer; batch-budget checks ran headlessly.")
	celadon.free()
	fuchsia.free()
	print("NIGHT_LIGHT_CAMERA ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check_configuration_scope() -> void:
	var map := Node2D.new()
	var visual := TileMapLayer.new()
	map.add_child(visual)
	var authored_batch_size := visual.rendering_quadrant_size
	LightRendering.configure_map(map)
	_check(visual.rendering_quadrant_size == authored_batch_size, "Maps without nightlights keep their batching")
	var lights := Node2D.new()
	lights.name = "NightLights"
	map.add_child(lights)
	var collision := TileMapLayer.new()
	collision.visible = false
	collision.set_cell(Vector2i(3, 4), 0, Vector2i.ZERO)
	var cells := collision.get_used_cells()
	var data: PackedByteArray = collision.get("tile_map_data")
	var physics_size := collision.physics_quadrant_size
	map.add_child(collision)
	var small := TileMapLayer.new()
	small.rendering_quadrant_size = 2
	map.add_child(small)
	LightRendering.configure_map(map)
	_check(visual.rendering_quadrant_size <= 4, "Visible tile layers use local light batches")
	_check(small.rendering_quadrant_size == 2, "Existing smaller batches stay small")
	_check(collision.rendering_quadrant_size == authored_batch_size and collision.physics_quadrant_size == physics_size, "Hidden collision and physics batching stay unchanged")
	_check(collision.get_used_cells() == cells and collision.get("tile_map_data") == data, "Collision cell data is untouched")
	LightRendering.configure_map(map)
	_check(visual.rendering_quadrant_size <= 4, "Repeated map positioning is idempotent")
	map.free()


func _maximum_lights_per_batch(map: Node2D) -> int:
	var light_rects: Array[Rect2] = []
	for lamp: Node in map.get_node("NightLights").find_children("*", "Node2D", true, false):
		if not lamp.has_method("set_night_intensity"):
			continue
		var point: PointLight2D = lamp.get_node("PointLight2D")
		var size: Vector2 = point.texture.get_size() * lamp.light_texture_scale
		light_rects.append(point.global_transform * Rect2(-size / 2, size))
	var maximum := 0
	for node: Node in map.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if not layer.visible or layer.tile_set == null:
			continue
		var quadrants: Dictionary = {}
		var batch_size := layer.rendering_quadrant_size
		for cell: Vector2i in layer.get_used_cells():
			quadrants[Vector2i(floori(float(cell.x) / batch_size), floori(float(cell.y) / batch_size))] = true
		for quadrant: Vector2i in quadrants:
			var local_rect := Rect2(Vector2(quadrant * batch_size * layer.tile_set.tile_size), Vector2.ONE * batch_size * Vector2(layer.tile_set.tile_size))
			var rect := layer.global_transform * local_rect
			var count := 0
			for light_rect: Rect2 in light_rects:
				if rect.intersects(light_rect):
					count += 1
			maximum = maxi(maximum, count)
	return maximum


func _check_camera_pixels(map: Node2D, city: String = "Celadon", minimum: int = 60, camera_rows: Array = [64, 192, 320, 448, 576]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var stage := Node2D.new()
	viewport.add_child(stage)
	var modulate := CanvasModulate.new()
	modulate.color = Color("65718f")
	stage.add_child(modulate)
	# Only stage the artwork/lights: account/NPC requests are unrelated to this
	# renderer regression. Moving the canvas matches the player's camera pan.
	for name: String in ["Visual", "NightLights"]:
		var node := map.get_node(name)
		map.remove_child(node)
		node.owner = null
		stage.add_child(node)
	await process_frame
	await process_frame
	var samples: Array[Vector2i] = []
	for lamp: Node in stage.get_node("NightLights").find_children("*", "Node2D", true, false):
		if lamp.has_method("set_night_intensity"):
			lamp.set_night_intensity(1.0)
			samples.append(Vector2i(lamp.global_position))
	var observations: Dictionary = {}
	for y: int in camera_rows:
		for x in range(0, 1665, 128):
			viewport.canvas_transform = Transform2D(0.0, -Vector2(x, y))
			await process_frame
			RenderingServer.force_draw(false)
			var frame := viewport.get_texture().get_image()
			for point: Vector2i in samples:
				var screen := point - Vector2i(x, y)
				if not Rect2i(48, 48, 544, 384).has_point(screen):
					continue
				if not observations.has(point):
					observations[point] = []
				observations[point].append(frame.get_pixelv(screen))
	var compared := 0
	var unstable := 0
	var worst_delta := 0.0
	for point: Vector2i in observations:
		var colors: Array = observations[point]
		if colors.size() < 2:
			continue
		compared += 1
		var delta := 0.0
		for channel in 3:
			var low := 1.0
			var high := 0.0
			for color: Color in colors:
				low = minf(low, color[channel])
				high = maxf(high, color[channel])
			delta = maxf(delta, high - low)
		worst_delta = maxf(worst_delta, delta)
		if delta > 0.01:
			unstable += 1
	_check(compared >= minimum, "The camera comparison covers at least %d stationary %s lights" % [minimum, city])
	_check(unstable == 0, "Camera movement does not alter stationary lights (%d unstable)" % unstable)
	print("NIGHT_LIGHT_CAMERA_PIXELS ", {"city": city, "compared": compared, "unstable": unstable, "max_delta": worst_delta})
	viewport.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
