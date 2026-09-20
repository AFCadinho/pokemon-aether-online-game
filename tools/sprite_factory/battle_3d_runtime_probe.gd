extends SceneTree
## Standalone local GLB evidence; does not load the game or alter its settings.

var players: Array[AnimationPlayer] = []
var viewports: Array[SubViewport] = []
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[2]), -float(value[1]))

func _find_players(node: Node) -> void:
	if node is AnimationPlayer:
		players.append(node)
	for child in node.get_children():
		_find_players(child)

func _pose(node: Node) -> Array:
	var result: Array = []
	if node is Skeleton3D:
		for index in node.get_bone_count():
			result.append(node.get_bone_pose(index))
	for child in node.get_children():
		result.append_array(_pose(child))
	return result

func _make_view(model: Node, camera_spec: Dictionary, index: int) -> SubViewport:
	var container := SubViewportContainer.new()
	container.position = Vector2((index % 2) * 512, (index / 2) * 512)
	container.size = Vector2(512, 512)
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	viewport.add_child(model)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("242632")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	viewport.add_child(environment)
	for rotation in [Vector3(-40, -30, 0), Vector3(-20, 140, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = rotation
		light.light_energy = 0.9 if rotation.y < 0 else 0.5
		viewport.add_child(light)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(camera_spec.ortho_scale)
	camera.position = _vector(camera_spec.position)
	camera.look_at(_vector(camera_spec.target))
	camera.current = true
	viewports.append(viewport)
	_find_players(model)
	return viewport

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_3D_PROBE_REPORT")
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not entries is Array or DisplayServer.get_name() == "headless":
		push_error("Supply export report and a real display for GPU measurements")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1024, 1024))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	report = {"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"godot": Engine.get_version_info().string, "cases": [],
		"conditions": "2/4 independent 512px viewports, 4x MSAA, 2 shadowless lights, 60fps cap, no game UI"}
	for entry: Dictionary in entries:
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var start := Time.get_ticks_usec()
		var error := document.append_from_file(str(entry.path), state)
		if error != OK:
			push_error("GLB import failed: " + str(error))
			quit(3)
			return
		var parsed_ms := (Time.get_ticks_usec() - start) / 1000.0
		for count in [2, 4]:
			players.clear()
			viewports.clear()
			var memory_before := OS.get_static_memory_usage()
			start = Time.get_ticks_usec()
			var nodes: Array[Node] = []
			for index in count:
				var model := document.generate_scene(state, 60)
				nodes.append(model)
				_make_view(model, entry.cameras.front if index % 2 == 0 else entry.cameras.back, index)
			var instantiation_ms := (Time.get_ticks_usec() - start) / 1000.0
			var actions := {}
			for action in entry.animations:
				if players.is_empty() or not players[0].has_animation(action):
					push_error("Missing animation " + action)
					quit(4)
					return
				var player := players[0]
				player.play(action)
				player.seek(0.0, true)
				var initial_pose := _pose(nodes[0])
				player.seek(player.get_animation(action).length * 0.5, true)
				actions[action] = {"duration": player.get_animation(action).length,
					"tracks": player.get_animation(action).get_track_count(),
					"bone_pose_changes": initial_pose != _pose(nodes[0])}
			for player in players:
				player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				player.play("idle")
			start = Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			var first_draw_ms := (Time.get_ticks_usec() - start) / 1000.0
			for warmup in 30:
				await process_frame
			var durations: Array[float] = []
			var over_20 := 0
			for frame in 180:
				start = Time.get_ticks_usec()
				await process_frame
				var elapsed := (Time.get_ticks_usec() - start) / 1000.0
				durations.append(elapsed)
				if elapsed > 20.0:
					over_20 += 1
			durations.sort()
			if count == 2:
				await RenderingServer.frame_post_draw
				for index in 2:
					viewports[index].get_texture().get_image().save_png(path.get_base_dir().path_join(str(entry.species) + ("-front.png" if index == 0 else "-back.png")))
			report.cases.append({"species": entry.species, "instances": count,
				"parse_ms": parsed_ms, "instantiate_ms": instantiation_ms, "first_draw_ms": first_draw_ms,
				"median_ms": durations[90], "p95_ms": durations[171], "max_ms": durations[-1], "frames_over_20ms": over_20,
				"static_memory_delta_bytes": OS.get_static_memory_usage() - memory_before,
				"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				"actions": actions})
			print("measured ", entry.species, " instances=", count)
			for viewport in viewports:
				viewport.get_parent().queue_free()
			await process_frame
	var file := FileAccess.open(path.get_base_dir().path_join("godot-3d-runtime.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit()
