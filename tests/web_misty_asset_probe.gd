extends SceneTree
class_name MistyAssetProbe

# Isolated visual-only probe: no accounts, backend or production requests.
const VISUALS := ["route_3", "mt_moon_1f", "mt_moon_b1f", "mt_moon_b2f", "route_4", "cerulean_city", "cerulean_gym", "cerulean_bike_shop", "cerulean_house_template_blue", "route_24", "route_25", "bills_house"]
var report := {"success": true, "files": [], "visuals": [], "textures": [], "errors": []}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.has_feature("web"):
		var request := HTTPRequest.new()
		request.timeout = 60
		root.add_child(request)
		request.download_file = "user://misty-maps.pck"
		var err := request.request("http://127.0.0.1:8063/misty-maps.pck")
		if err != OK:
			_fail("download could not start")
			_finish()
			return
		var response: Array = await request.request_completed
		if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
			_fail("download failed")
			_finish()
			return
		request.queue_free()
		if not ProjectSettings.load_resource_pack("user://misty-maps.pck", false):
			_fail("mount failed")
	else:
		var args := OS.get_cmdline_user_args()
		if args.is_empty() or not ProjectSettings.load_resource_pack(args[0], false):
			_fail("mount failed")
	if not report.success:
		_finish()
		return
	var before := Performance.get_monitor(Performance.MEMORY_STATIC)
	_walk("res://")
	report.staticMemoryAfterTextureInspectionBytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	for directory: String in VISUALS:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [directory, directory]
		var scene := load(path) as PackedScene
		if scene == null:
			_fail("missing visual " + path)
			continue
		var node := scene.instantiate()
		root.add_child(node)
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		report.visuals.append({"path": path, "staticMemoryBytes": Performance.get_monitor(Performance.MEMORY_STATIC), "textureMemoryBytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
		if not OS.has_feature("web") or directory != VISUALS.back():
			node.queue_free()
		await process_frame
	report.staticMemoryBaselineBytes = before
	report.staticMemoryEndBytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	_finish()


func _walk(directory: String) -> void:
	for name: String in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		report.files.append(path)
		if name.ends_with(".texture.res"):
			var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			if texture == null:
				_fail("texture load failed " + path)
				continue
			report.textures.append({"path": path, "width": texture.get_width(), "height": texture.get_height(), "rgbaBytes": texture.get_width() * texture.get_height() * 4})
	for child: String in DirAccess.get_directories_at(directory):
		_walk(directory.path_join(child))


func _fail(message: String) -> void:
	report.success = false
	report.errors.append(message)


func _finish() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.mistyProbe = " + JSON.stringify(report), true)
	else:
		print("MISTY_PROBE " + JSON.stringify(report))
		quit(0 if report.success else 1)
