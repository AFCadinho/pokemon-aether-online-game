extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = 1.0
	var parent := Control.new()
	root.add_child(parent)
	parent.scale = Vector2(1.25, 0.75)
	var stage := Renderer.new()
	parent.add_child(stage)
	stage.set_process(false)
	stage.size = Vector2(640, 480)
	stage.viewport = SubViewport.new()
	stage.add_child(stage.viewport)
	for output in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = output
		await process_frame
		await process_frame
		stage._sync_render_size()
		# Independent expected pixel dimensions: logical size * parent scale *
		# physical window/design ratio, including both downscale and upscale.
		var expected := Vector2(800, 360) * Vector2(output) / Vector2(1920, 1080)
		assert(absf(stage.viewport.size.x - expected.x) <= 1.01)
		assert(absf(stage.viewport.size.y - expected.y) <= 1.01)
		assert(stage.size == Vector2(640, 480) and parent.scale == Vector2(1.25, 0.75))
		print("BATTLE_RASTER_SIZE_OK output=", output, " raster=", stage.viewport.size)
	parent.queue_free()
	await process_frame
	quit()
