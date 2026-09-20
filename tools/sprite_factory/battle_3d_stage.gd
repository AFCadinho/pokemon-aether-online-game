extends SceneTree
## Standalone visual battle test. No battle API, saves or production routing.

const Hud = preload("res://scenes/battle/pokemon_hud_panel.tscn")
const Move = preload("res://scenes/battle/move_slot.tscn")
var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var huds: Array[Control] = []
var buttons: Array[Button] = []
var entries: Array = []
var hp := [100, 100]
var busy := false
var status: Label
var key_light: DirectionalLight3D
var phase := "loading"
var samples: Dictionary = {}
var recording := false
var load_ms := 0.0
var root_path := ""
var last_tick := 0
var swapped := false
const CAMERA_HOME := Vector3(5, 5.3, 11)
const CAMERA_FOCUS := Vector3(0, 1, 0)
const CAMERA_SIZE := 7.8
var camera_motion := true
var camera_focus := CAMERA_FOCUS
var camera_tween: Tween
var camera_button: CheckButton

func _camera_pose(weight: float, origin: Vector3, focus: Vector3, size_from: float,
		destination: Vector3, target: Vector3, size_to: float) -> void:
	camera.position = origin.lerp(destination, weight)
	camera_focus = focus.lerp(target, weight)
	camera.size = lerpf(size_from, size_to, weight)
	camera.look_at(camera_focus)

func _camera_shot(destination: Vector3, target: Vector3, size_to: float, duration: float) -> void:
	if not camera_motion:
		return
	if camera_tween != null:
		camera_tween.kill()
	camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_method(_camera_pose.bind(camera.position, camera_focus, camera.size,
		destination, target, size_to), 0.0, 1.0, duration)

func _camera_reset() -> void:
	if camera_tween != null:
		camera_tween.kill()
	camera.position = CAMERA_HOME
	camera_focus = CAMERA_FOCUS
	camera.size = CAMERA_SIZE
	camera.look_at(camera_focus)

func _set_camera_motion(enabled: bool) -> void:
	camera_motion = enabled
	if not enabled:
		# Reduced-motion choice takes effect immediately, including mid-attack.
		_camera_reset()

func _initialize() -> void:
	call_deferred("_run")

func _material(color: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m

func _mesh(mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	world.add_child(node)
	return node

func _ring(position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.025
	mesh.outer_radius = radius + 0.025
	mesh.rings = 64
	mesh.ring_segments = 8
	return _mesh(mesh, position, _material(color, true))

func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _player(child)
		if found != null:
			return found
	return null

func _label(text: String, position: Vector2, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("cfe9ff"))
	root.add_child(label)
	return label

func _play(index: int, action: String) -> void:
	var spec: Dictionary = entries[index].action_timing[action]
	var animation := players[index].get_animation(action)
	animation.length = float(spec.frames) / 60.0
	animation.loop_mode = Animation.LOOP_LINEAR if spec.loop else Animation.LOOP_NONE
	players[index].speed_scale = float(spec.speed)
	players[index].play(action)

func _refresh_hud() -> void:
	for i in 2:
		huds[i].set_pokemon_data(entries[i].species, 100, hp[i], 100, "", "", false, {}, "Dragonite" if i == 0 else "Roaring Moon")
		var label = huds[i].get_node("MarginContainer/VBoxContainer/PokemonInfoHud/MarginContainer/VBoxContainer/HPRow/HPTextLabel")
		label.text = "HP:"

func _controls() -> void:
	_label("POKÉAETHER  /  3D BATTLE STUDY", Vector2(24, 16), 22)
	_label("Local scripted encounter • 60 FPS • no game progress", Vector2(24, 48), 13)
	for i in 2:
		var hud := Hud.instantiate()
		root.add_child(hud)
		hud.position = Vector2(70, 155) if i == 0 else Vector2(730, 100)
		hud.size = Vector2(280, 70)
		huds.append(hud)
	_refresh_hud()
	status = _label("Choose an animation to review", Vector2(30, 585), 19)
	var actions := ["physical_attack", "special_attack", "counter", "reset"]
	var titles := ["Physical attack", "Dragon Pulse · demo", "Roaring Moon reply", "Reset encounter"]
	for i in 4:
		var button := Move.instantiate() as Button
		# Reuse the actual UI scene/styles; this harness supplies local actions.
		button.set_script(null)
		root.add_child(button)
		button.position = Vector2(30 + i * 267, 628)
		button.size = Vector2(252, 90)
		button.get_node("MarginContainer/VBoxContainer/TopRow/MoveNameLabel").text = titles[i]
		button.get_node("MarginContainer/VBoxContainer/TopRow/TypeBanner").visible = false
		button.get_node("MarginContainer/VBoxContainer/BottomRow/PPLabel").text = "REVIEW"
		button.get_node("MarginContainer/VBoxContainer/BottomRow/EffectivenessLabel").text = ""
		button.pressed.connect(_trigger.bind(actions[i]))
		buttons.append(button)
	var shadow_button := CheckButton.new()
	shadow_button.text = "Shadows"
	shadow_button.position = Vector2(930, 24)
	shadow_button.button_pressed = true
	shadow_button.toggled.connect(func(enabled): key_light.shadow_enabled = enabled)
	root.add_child(shadow_button)
	var swap_button := Button.new()
	swap_button.text = "Swap sides"
	swap_button.position = Vector2(780, 25)
	swap_button.pressed.connect(_swap_sides)
	root.add_child(swap_button)
	camera_button = CheckButton.new()
	camera_button.text = "Camera motion"
	camera_button.position = Vector2(570, 24)
	camera_button.button_pressed = true
	camera_button.toggled.connect(_set_camera_motion)
	root.add_child(camera_button)

func _swap_sides() -> void:
	if busy:
		return
	swapped = not swapped
	var place := models[0].position
	models[0].position = models[1].position
	models[1].position = place
	for i in 2:
		var direction := models[1-i].position - models[i].position
		models[i].rotation.y = atan2(direction.x, direction.z)
		huds[i].position = Vector2(730, 100) if (i == 0) == swapped else Vector2(70, 155)

func _trigger(action: String) -> void:
	if busy:
		return
	if action == "reset":
		_camera_reset()
		hp = [100, 100]
		_refresh_hud()
		for i in 2:
			_play(i, "idle")
		status.text = "Choose an animation to review"
		return
	await _attack(1 if action == "counter" else 0, "physical_attack" if action == "counter" else action)

func _attack(attacker: int, action: String) -> void:
	busy = true
	for button in buttons:
		button.disabled = true
	var target := 1 - attacker
	phase = ("dragonite_" if attacker == 0 else "roaring_moon_") + action
	status.text = ("Dragonite" if attacker == 0 else "Roaring Moon") + " · " + action.replace("_", " ")
	_play(attacker, action)
	var start := models[attacker].position + Vector3(0, 1.3, 0)
	var end := models[target].position + Vector3(0, 1.1, 0)
	var cinematic := attacker == 0 and action == "special_attack" and camera_motion
	if cinematic:
		# Stay on the same side of the action axis; focus follows swapped positions.
		_camera_shot(start + Vector3(5, 3.2, 8), start, 5.8, 0.3)
	await create_timer(0.3).timeout
	if action == "special_attack":
		if cinematic:
			_camera_shot(end + Vector3(3.5, 3.2, 9), end, 6.2, 0.5)
		var ball := SphereMesh.new()
		ball.radius = 0.22
		ball.height = 0.44
		var projectile := _mesh(ball, start, _material(Color("699dff"), true))
		var tween := create_tween()
		tween.tween_property(projectile, "position", end, 0.5)
		await tween.finished
		projectile.queue_free()
	else:
		await create_timer(0.35).timeout
	_play(target, "damage")
	hp[target] = maxi(0, hp[target] - 18)
	_refresh_hud()
	var impact := _ring(end, 0.45, Color("eab7ff"))
	impact.rotation_degrees.x = 90
	var tween := create_tween()
	tween.tween_property(impact, "scale", Vector3.ONE * 2.5, 0.35)
	await tween.finished
	impact.queue_free()
	await create_timer(maxf(0.0, players[attacker].get_animation(action).length - 1.0)).timeout
	for i in 2:
		_play(i, "idle")
	if cinematic and camera_motion:
		_camera_shot(CAMERA_HOME, CAMERA_FOCUS, CAMERA_SIZE, 0.65)
		await create_timer(0.65).timeout
		_camera_reset()
	busy = false
	phase = "idle"
	status.text = "Choose an animation to review"
	for button in buttons:
		button.disabled = false

func _run() -> void:
	root_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path))
	if not data is Array or data.size() != 2 or data[0].species != "dragonite" or data[1].species != "roaring-moon":
		push_error("Supply the two-species PBR export report")
		quit(2)
		return
	entries = data
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1120, 750)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1120, 750)
	root.position = Vector2i(30, 40)
	DisplayServer.window_set_title("PokeAether — 3D battle stage study")
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_default_clear_color(Color("07101c"))
	var container := SubViewportContainer.new()
	container.position = Vector2(0, 72)
	container.size = Vector2(1120, 500)
	root.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1120, 500)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0c1226")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c3cfff")
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52, -35, 0)
	key_light.light_energy = 1.15
	key_light.light_color = Color("fff3db")
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 30
	world.add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("a4cfff")
	fill.light_energy = 0.7
	world.add_child(fill)
	var ground := PlaneMesh.new()
	ground.size = Vector2(60, 60)
	_mesh(ground, Vector3(0, -0.2, 0), _material(Color("141d30")))
	var places := [Vector3(-2.8, 0, 1.7), Vector3(2.5, 0, -2.0)]
	for i in 2:
		var base := CylinderMesh.new()
		base.top_radius = 2.05
		base.bottom_radius = 2.1
		base.height = 0.16
		base.radial_segments = 64
		_mesh(base, places[i] - Vector3(0, 0.08, 0), _material(Color("222940")))
		_ring(places[i] + Vector3(0, 0.015, 0), 1.93, Color("65d8ff") if i == 0 else Color("ce78ff"))
		_ring(places[i] + Vector3(0, 0.016, 0), 1.55, Color("365a91"))
	var start := Time.get_ticks_usec()
	for i in 2:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(entries[i].path, state) == OK)
		var model := document.generate_scene(state, 60)
		world.add_child(model)
		model.position = places[i]
		model.rotation.y = PI if i == 0 else 0.0
		model.scale = Vector3.ONE * (1.0 if i == 0 else 0.65)
		models.append(model)
		players.append(_player(model))
		assert(players[i] != null)
		for action in entries[i].action_timing:
			assert(players[i].has_animation(action))
		_play(i, "idle")
	for i in 2:
		var direction: Vector3 = places[1-i] - places[i]
		models[i].rotation.y = atan2(direction.x, direction.z)
	load_ms = (Time.get_ticks_usec() - start) / 1000.0
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera_reset()
	camera.current = true
	_controls()
	phase = "idle"
	if OS.get_environment("POKEAETHER_CAMERA_SMOKE") == "1":
		await _camera_smoke()
		quit()
		return
	if OS.get_environment("POKEAETHER_STAGE_MEASURE") == "1":
		for frame in 90:
			await process_frame
		recording = true
		await create_timer(3).timeout
		await _attack(0, "physical_attack")
		await _attack(0, "special_attack")
		await _attack(1, "physical_attack")
		recording = false
		var results := {"gpu": RenderingServer.get_video_adapter_name(),
			"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
			"load_ms": load_ms, "viewport": viewport.size, "msaa": "4x", "shadow": true,
			"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"static_memory_bytes": OS.get_static_memory_usage(), "phases": {}, "final_hp": hp}
		for name in samples:
			var values: Array = samples[name]
			values.sort()
			var late := 0
			for value in values:
				if value > 20:
					late += 1
			results.phases[name] = {"frames": values.size(), "median_ms": values[values.size()/2],
				"p95_ms": values[int(values.size()*0.95)], "max_ms": values[-1], "over_20ms": late}
		var output_dir := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		if output_dir.is_empty():
			output_dir = root_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(output_dir)
		results["timing"] = "Time.get_ticks_usec wall-clock process-frame intervals; 60-FPS cap"
		var file := FileAccess.open(output_dir.path_join("stage-runtime.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "  "))
		file.close()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("stage.png"))
		assert(hp == [82, 64])
		_swap_sides()
		assert(swapped and models[0].position == places[1])
		await _trigger("reset")
		assert(hp == [100, 100] and not busy)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("stage-swapped.png"))
		_swap_sides()
		assert(not swapped and models[0].position == places[0])
		print("STAGE_REVIEW_OK ", hp)
		quit()

func _camera_smoke() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var hud_positions := [huds[0].position, huds[1].position]
	for reverse in [false, true]:
		if reverse:
			_swap_sides()
		var fixed_huds := [huds[0].position, huds[1].position]
		_attack(0, "special_attack")
		await create_timer(0.27).timeout
		assert(not camera.position.is_equal_approx(CAMERA_HOME))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("attacker-%s.png" % reverse))
		await create_timer(0.55).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("impact-%s.png" % reverse))
		while busy:
			assert(huds[0].position == fixed_huds[0] and huds[1].position == fixed_huds[1])
			await process_frame
		assert(camera.position.is_equal_approx(CAMERA_HOME) and is_equal_approx(camera.size, CAMERA_SIZE))
	_swap_sides()
	assert(huds[0].position == hud_positions[0] and huds[1].position == hud_positions[1])
	# Disable in flight, then verify a whole disabled attack stays fixed.
	_attack(0, "special_attack")
	await create_timer(0.15).timeout
	camera_button.button_pressed = false
	while busy:
		assert(camera.position.is_equal_approx(CAMERA_HOME))
		await process_frame
	_attack(0, "special_attack")
	while busy:
		assert(camera.position.is_equal_approx(CAMERA_HOME))
		await process_frame
	camera_button.button_pressed = true
	await _trigger("reset")
	assert(hp == [100, 100] and camera_focus.is_equal_approx(CAMERA_FOCUS))
	print("CAMERA_SMOKE_OK: both sides, return, mid-attack off, disabled attack, reset")

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if recording and last_tick != 0:
		if not samples.has(phase):
			samples[phase] = []
		samples[phase].append((now - last_tick) / 1000.0)
	last_tick = now
	return false
