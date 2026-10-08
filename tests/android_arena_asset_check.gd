extends SceneTree
## Isolated diagnostic: one pack per process, fixed light/camera, no accounts.
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
const ORIGIN := "http://127.0.0.1:8799/"
var report := {}
var failures: Array[String] = []
var output := "user://android-arena-details.json"
var viewport: SubViewport
var lighting_mode := "baseline"
class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()

func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
	return ok
func _fetch(name: String) -> PackedByteArray:
	var request := HTTPRequest.new()
	request.timeout = 45
	request.body_size_limit = 80 * 1024 * 1024
	root.add_child(request)
	if request.request(ORIGIN + name) != OK:
		request.queue_free()
		return PackedByteArray()
	var result: Array = await request.request_completed
	request.queue_free()
	if not _check(result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, "Loopback fixture download: " + name):
		return PackedByteArray()
	return result[3]
func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	var manifest := ""
	if OS.has_feature("android") and FileAccess.file_exists("user://android-arena-lighting"):
		lighting_mode = FileAccess.get_file_as_string("user://android-arena-lighting").strip_edges()
	if OS.has_feature("android"):
		if not _check(OS.has_feature("android_arena_pilot") and OS.is_debug_build(), "Requires the separate tagged debug APK"):
			_finish()
			return
		var variant := FileAccess.get_file_as_string("user://android-arena-variant").strip_edges()
		if not _check(variant in ["desktop-art", "android-etc2-art"], "Explicit variant marker"):
			_finish()
			return
		var bytes: PackedByteArray = await _fetch("fixture.json")
		var config = JSON.parse_string(bytes.get_string_from_utf8())
		if not _check(config is Dictionary and config.has(variant), "Diagnostic fixture pins"):
			_finish()
			return
		var pin: Dictionary = config[variant]
		var pack: PackedByteArray = await _fetch(variant + "/forest.pck")
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pack)
		if not _check(pack.size() == int(pin.bytes) and hash.finish().hex_encode() == pin.sha256, "Exact fixture PCK hash"):
			_finish()
			return
		FileAccess.open("user://android-arena-forest.pck", FileAccess.WRITE).store_buffer(pack)
		FileAccess.open("user://android-arena-forest.json", FileAccess.WRITE).store_string('{"schema":1,"pack":"android-arena-forest.pck"}')
		manifest = "user://android-arena-forest.json"
		report.variant = variant
	else:
		if not _check(args.size() in [2, 3], "Desktop diagnostic needs manifest and output"):
			_finish()
			return
		manifest = args[0]
		output = args[1]
		report.variant = manifest.get_base_dir().get_file()
		if args.size() == 3:
			lighting_mode = args[2]
	if not _check(lighting_mode in ["baseline", "hdr", "sun-only", "unshaded-grass", "diffuse-grass", "ambient-only", "no-shadows", "ground-srgb", "ground-srgb-no-shadows", "smooth-grass"], "Recognized lighting probe"):
		_finish()
		return
	report.lighting_mode = lighting_mode
	print("ANDROID_ARENA_PHASE load ", lighting_mode)
	report.renderer = RenderingServer.get_current_rendering_method()
	if lighting_mode.begins_with("ground-srgb") and not _check(report.renderer == "gl_compatibility", "Ground sRGB investigation requires Compatibility"):
		_finish()
		return
	report.adapter = RenderingServer.get_video_adapter_name()
	report.frame_pacing = ProjectSettings.get_setting("display/window/frame_pacing/android/enable_frame_pacing", true)
	report.static_before = Performance.get_monitor(Performance.MEMORY_STATIC)
	report.render_before = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	if not _check(Catalog.prepare_forest(manifest).is_empty(), "Production art loader mounts candidate"):
		_finish()
		return
	var deadline := Time.get_ticks_msec() + 60000
	while not Catalog.forest_ready():
		if not _check(Catalog.forest_error.is_empty() and Time.get_ticks_msec() < deadline, "All runtime dependencies loaded"):
			_finish()
			return
		await process_frame
	print("ANDROID_ARENA_PHASE build")
	RenderingServer.global_shader_parameter_set("wind_strength", 0.0)
	RenderingServer.global_shader_parameter_set("wind_speed", 0.0)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(960, 540)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.use_hdr_2d = lighting_mode == "hdr"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var surface := TextureRect.new()
	surface.texture = viewport.get_texture()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	Response.apply_neutral_lighting(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Catalog.camera_home("forest")
	camera.fov = Catalog.CAMERA_FOV
	camera.look_at(Catalog.camera_target("forest"))
	camera.current = true
	var arena := Catalog.build("forest", world, camera)
	if not _check(arena != null, "Actual grassfield composition"):
		_finish()
		return
	world.add_child(arena)
	# Diagnostic overrides only. Keep production shaders and downloaded art intact.
	if lighting_mode.begins_with("ground-srgb"):
		var terrain := arena.find_child("MeshTerrain", true, false) as MeshInstance3D
		var material := terrain.mesh.surface_get_material(0) as ShaderMaterial
		var tint_conversion := "tint = mix(tint / 12.92, pow((tint + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), tint));"
		if not _check(tint_conversion in material.shader.code, "Diagnostic changes the authored ground tint conversion"):
			_finish()
			return
		var shader := Shader.new()
		shader.code = material.shader.code.replace(tint_conversion, "")
		material.shader = shader
	var light := arena.get_node("OutdoorLighting")
	light.set_process(false)
	light.apply_seconds(43200.0)
	if lighting_mode in ["no-shadows", "ground-srgb-no-shadows"]:
		for lamp in light._lights:
			lamp.shadow_enabled = false
	if lighting_mode in ["sun-only", "ambient-only"]:
		for index in light._lights.size():
			light._lights[index].light_energy = light._lights[index].light_energy if index == 0 and lighting_mode == "sun-only" else 0.0
	if lighting_mode in ["unshaded-grass", "diffuse-grass", "smooth-grass"]:
		var grass: PackedScene = Catalog.Art.resources["res://entities/nature/grass/grass_3_faces.tscn"]
		var source := grass.instantiate()
		var material: ShaderMaterial = source.get_node("Card").get_active_material(0)
		var shader := Shader.new()
		shader.code = material.shader.code.replace("render_mode ", "render_mode unshaded, ") if lighting_mode == "unshaded-grass" else material.shader.code.replace("specular_toon", "specular_disabled")
		if lighting_mode == "smooth-grass":
			if not _check("ALPHA_SCISSOR_THRESHOLD = alpha_threshold;" in material.shader.code, "Diagnostic changes the authored grass cutoff"):
				source.free()
				_finish()
				return
			shader.code = material.shader.code.replace("depth_draw_opaque", "depth_prepass_alpha").replace(
				"ALPHA_SCISSOR_THRESHOLD = alpha_threshold;",
				"float edge = max(fwidth(ALPHA), 0.001);\n ALPHA = smoothstep(alpha_threshold - edge, alpha_threshold + edge, ALPHA);")
		material.shader = shader
		source.free()
	report.lights = []
	for lamp in light._lights:
		report.lights.append({"energy":lamp.light_energy,"visible":lamp.visible,"shadows":lamp.shadow_enabled})
	report.viewport_size = [viewport.size.x, viewport.size.y]
	report.msaa = viewport.msaa_3d
	print("ANDROID_ARENA_PHASE draw")
	var start := Time.get_ticks_msec()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	report.static_loaded = Performance.get_monitor(Performance.MEMORY_STATIC)
	report.render_loaded = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	report.texture_loaded = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	report.mesh_loaded = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	report.observation_ms = Time.get_ticks_msec() - start
	report.resource_count = Catalog.Art.resources.size()
	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		_check(image.save_png(output.get_base_dir().path_join("android-arena-capture.png")) == OK, "Native rendered capture")
	else:
		_check(false, "A real rendering backend is required")
	_finish()
func _finish() -> void:
	report.failures = failures
	report.engine_errors = sink.errors
	report.success = failures.is_empty() and sink.errors.is_empty()
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ANDROID_ARENA_RESULT ", JSON.stringify(report))
	quit(0 if report.success else 1)
