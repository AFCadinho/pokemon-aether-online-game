# Rendered native atlas comparison; run with a real rendering/display driver.
extends SceneTree

const SIZE := Vector2i(1600, 1280)
const ORIGINAL := "res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn"
const COMPACT := "res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered comparison requires a non-headless display driver")
		quit(2)
		return
	var first := _viewport(ORIGINAL)
	var second := _viewport(COMPACT)
	for index in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := first.get_texture().get_image()
	var b := second.get_texture().get_image()
	var valid := a != null and b != null and a.get_size() == SIZE and b.get_size() == SIZE
	var identical := valid and a.get_data() == b.get_data()
	var varied := false
	if valid:
		var corner := a.get_pixel(0, 0)
		for y in range(0, SIZE.y, 32):
			for x in range(0, SIZE.x, 32):
				if a.get_pixel(x, y) != corner:
					varied = true
	var output := "res://builds/pallet-native-render"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if valid:
		a.save_png(output + "/original.png")
		b.save_png(output + "/compact.png")
	print("PALLET_NATIVE_RENDER ", JSON.stringify({"size": [SIZE.x, SIZE.y], "identicalPixels": identical,
		"nonblank": varied, "display": DisplayServer.get_name(), "loggedInGameplay": false,
		"success": identical and varied}))
	first.queue_free()
	second.queue_free()
	quit(0 if identical and varied else 1)

func _viewport(path: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	get_root().add_child(viewport)
	var scene: PackedScene = load(path)
	viewport.add_child(scene.instantiate())
	return viewport
