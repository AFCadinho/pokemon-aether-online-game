extends SceneTree
## Runs in the disposable GDQuest project, never the production frontend.

class InputRelay extends Node:
	var callback: Callable
	func _unhandled_input(event: InputEvent) -> void:
		callback.call(event)

var camera: Camera3D
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var entries: Array = []
var target := Vector3(0, 8, 0)
var center := Vector3.ZERO
var yaw := 0.5
var pitch := 0.27
var distance := 14.0
var dragging := false
var status: Label
var world: Node3D
var action_select: OptionButton
var foliage: Array[MeshInstance3D] = []
var hp := [100, 100]
var bars: Array[ProgressBar] = []
var battle_buttons: Array[Button] = []
var busy := false
var cinematic := false
var camera_toggle: CheckButton
var camera_tween: Tween
var effects: Node3D

func _stop_camera() -> void:
	cinematic = false
	if camera_tween != null:
		camera_tween.kill()

func _camera_blend(weight: float, from: Vector3, to: Vector3, from_distance: float,
		to_distance: float, from_yaw: float, to_yaw: float, from_pitch: float, to_pitch: float) -> void:
	target = from.lerp(to, weight)
	distance = lerpf(from_distance, to_distance, weight)
	yaw = lerpf(from_yaw, to_yaw, weight)
	pitch = lerpf(from_pitch, to_pitch, weight)
	_camera_update()

func _shot(focus: Vector3, radius: float, angle: float, elevation: float, duration: float) -> void:
	if not cinematic:
		return
	if camera_tween != null:
		camera_tween.kill()
	camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_method(_camera_blend.bind(target, focus, distance, radius, yaw, angle, pitch, elevation), 0.0, 1.0, duration)

func _reset_encounter() -> void:
	if busy:
		return
	_stop_camera()
	hp = [100, 100]
	for i in 2:
		bars[i].value = hp[i]
		_play(i, "idle")
	status.text = "Choose an attack, or inspect animations freely. Demo HP only."

func _effect(mesh: Mesh, point: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("748aff")
	material.emission_enabled = true
	material.emission = Color("879fff")
	node.material_override = material
	effects.add_child(node)
	node.position = point
	return node

func _attack(attacker: int) -> void:
	if busy or hp.has(0):
		return
	busy = true
	for button in battle_buttons:
		button.disabled = true
	var defender := 1 - attacker
	var action := "special_attack" if attacker == 0 else "physical_attack"
	var saved_target := target
	var saved_distance := distance
	var saved_yaw := yaw
	var saved_pitch := pitch
	cinematic = camera_toggle.button_pressed
	for i in 2:
		_play(i, "idle")
	_play(attacker, action)
	status.text = ("Dragonite · Dragon Pulse" if attacker == 0 else "Roaring Moon · physical attack") + " — scripted demo"
	var start := models[attacker].position + Vector3(0, 1.3, 0)
	var finish := models[defender].position + Vector3(0, 1.3, 0)
	_shot(start, 8.0, saved_yaw + 0.18, 0.2, 0.4)
	await create_timer(0.4).timeout
	_shot(finish, 9.0, saved_yaw - 0.12, 0.23, 0.5)
	if attacker == 0:
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		var projectile := _effect(sphere, start)
		var flight := create_tween()
		flight.tween_property(projectile, "position", finish, 0.5)
		await flight.finished
		projectile.queue_free()
	else:
		await create_timer(0.5).timeout
	_play(defender, "damage")
	hp[defender] = maxi(0, hp[defender] - 18)
	bars[defender].value = hp[defender]
	var ring := TorusMesh.new()
	ring.inner_radius = 0.25
	ring.outer_radius = 0.32
	var impact := _effect(ring, finish)
	impact.rotation_degrees.x = 90
	var burst := create_tween()
	burst.tween_property(impact, "scale", Vector3.ONE * 3.0, 0.3)
	await burst.finished
	impact.queue_free()
	var spec: Dictionary = entries[attacker].action_timing[action]
	await create_timer(maxf(0.5, float(spec.frames) / (60.0 * float(spec.speed)) - 1.2)).timeout
	for i in 2:
		_play(i, "idle" if hp[i] > 0 else "faint_start")
	if cinematic:
		_shot(saved_target, saved_distance, saved_yaw, saved_pitch, 0.7)
		await create_timer(0.7).timeout
	_stop_camera()
	busy = false
	for button in battle_buttons:
		button.disabled = false
	status.text = "Demo finished — Reset HP to replay." if hp.has(0) else "Choose another attack · drag anytime to take over the camera"

func _initialize() -> void:
	call_deferred("_run")

func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _player(child)
		if found != null:
			return found
	return null

func _camera_update() -> void:
	pitch = clampf(pitch, 0.08, 1.15)
	distance = clampf(distance, 5.0, 35.0)
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	# Hide only foreground vegetation intersecting a sightline to a combatant.
	# This review aid restores foliage automatically as the camera moves away.
	for mesh in foliage:
		mesh.visible = true
		for model in models:
			if mesh.get_aabb().intersects_segment(mesh.to_local(camera.position), mesh.to_local(model.position + Vector3(0, 1.2, 0))):
				mesh.visible = false
				break

func _collect_foliage(node: Node) -> void:
	if node is MeshInstance3D:
		foliage.append(node)
	for child in node.get_children():
		_collect_foliage(child)

func _home() -> void:
	_stop_camera()
	target = center + Vector3(0, 1.5, 0)
	yaw = 0.5
	pitch = 0.27
	distance = 14.0
	_camera_update()

func _input_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_stop_camera()
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= 0.9
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.1
		_camera_update()
	elif event is InputEventMouseMotion and dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			dragging = false
			return
		yaw -= event.relative.x * 0.006
		pitch += event.relative.y * 0.004
		_camera_update()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_home()

func _play(index: int, action: String) -> void:
	var spec: Dictionary = entries[index].action_timing[action]
	var animation := players[index].get_animation(action)
	animation.length = float(spec.frames) / 60.0
	animation.loop_mode = Animation.LOOP_LINEAR if spec.loop else Animation.LOOP_NONE
	players[index].speed_scale = float(spec.speed)
	players[index].play(action)

func _animate() -> void:
	if busy:
		return
	var action := action_select.get_item_text(action_select.selected)
	for i in 2:
		_play(i, action)
	status.text = "Playing: " + action + " · camera stays freely controllable"

func _focus(index: int) -> void:
	_stop_camera()
	target = models[index].position + Vector3(0, 1.3, 0)
	distance = 7.0
	_camera_update()

func _button(text: String, callback: Callable, row: HBoxContainer) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	row.add_child(button)
	return button

func _hud(layer: CanvasLayer, index: int) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 26) if index == 0 else Vector2(860, 26)
	panel.custom_minimum_size = Vector2(310, 76)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.94)
	style.border_color = Color("65c9ed")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var label := Label.new()
	label.text = ("Dragonite" if index == 0 else "Roaring Moon") + "     Lv. 100"
	column.add_child(label)
	var bar := ProgressBar.new()
	bar.value = 100
	bar.custom_minimum_size.y = 22
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("57d35a")
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	bars.append(bar)

func _ui() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	for i in 2:
		_hud(layer, i)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -170
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.95)
	style.content_margin_left = 18
	style.content_margin_top = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var label := Label.new()
	label.text = "3D OUTDOOR REVIEW  ·  Drag: orbit  ·  Scroll: zoom  ·  R: battle view"
	column.add_child(label)
	var attacks := HBoxContainer.new()
	column.add_child(attacks)
	battle_buttons.append(_button("Dragon Pulse · demo", _attack.bind(0), attacks))
	battle_buttons.append(_button("Roaring Moon attacks", _attack.bind(1), attacks))
	battle_buttons.append(_button("Reset HP", _reset_encounter, attacks))
	camera_toggle = CheckButton.new()
	camera_toggle.text = "Attack camera"
	camera_toggle.button_pressed = true
	camera_toggle.toggled.connect(func(enabled):
		if not enabled:
			_stop_camera())
	attacks.add_child(camera_toggle)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button("Battle view", _home, row)
	_button("Dragonite", _focus.bind(0), row)
	_button("Roaring Moon", _focus.bind(1), row)
	action_select = OptionButton.new()
	for action in entries[0].action_timing:
		action_select.add_item(action)
	row.add_child(action_select)
	battle_buttons.append(_button("Play both", _animate, row))
	status = Label.new()
	status.text = "GDQuest environment · art CC-BY-NC-SA 4.0 · local noncommercial study only"
	column.add_child(status)
	var credit := Label.new()
	credit.text = "Environment: GDQuest · CC-BY-NC-SA 4.0 · noncommercial prototype · no game progress"
	credit.add_theme_font_size_override("font_size", 12)
	column.add_child(credit)

func _run() -> void:
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report))
	if not parsed is Array or parsed.size() != 2:
		push_error("Supply the Dragonite/Roaring Moon GLB report")
		quit(2)
		return
	entries = parsed
	assert(entries[0].species == "dragonite" and entries[1].species == "roaring-moon")
	root.size = Vector2i(1200, 800)
	root.content_scale_size = Vector2i(1200, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.title = "PokeAether — outdoor 3D review (GDQuest, noncommercial)"
	root.msaa_3d = Viewport.MSAA_4X
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
	effects = Node3D.new()
	world.add_child(effects)
	var environment_scene := load("res://outdoor_review.tscn") as PackedScene
	assert(environment_scene != null)
	var environment := environment_scene.instantiate()
	world.add_child(environment)
	_collect_foliage(environment.get_node("Level/Trees"))
	_collect_foliage(environment.get_node("Level/Bushes"))
	# Compatibility supports the scene geometry/materials, not the demo's SSAO.
	var settings: Environment = environment.get_node("WorldEnvironment").environment
	settings.ssao_enabled = false
	settings.volumetric_fog_enabled = false
	# The source water's depth reconstruction targets Forward+; use a simple
	# opaque water material in this Compatibility-only geometry review.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("369ac1")
	water.roughness = 0.7
	environment.get_node("Level/Water").material_override = water
	await physics_frame
	await physics_frame
	for i in 2:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(entries[i].path, state) == OK)
		var model := document.generate_scene(state, 60)
		world.add_child(model)
		# Use the original demo's starting clearing, not the island's steep edge.
		var x := 8.2 if i == 0 else 13.2
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, -27.6), Vector3(x, -10, -27.6)))
		assert(not hit.is_empty(), "No terrain at battle placement")
		model.position = hit.position + Vector3(0, 0.05, 0)
		model.scale = Vector3.ONE * (1.0 if i == 0 else 0.65)
		models.append(model)
		players.append(_player(model))
		assert(players[i] != null)
		for action in entries[i].action_timing:
			assert(players[i].has_animation(action))
		_play(i, "idle")
		print("PLACEMENT ", entries[i].species, " ", model.position)
	for i in 2:
		var direction := models[1-i].position - models[i].position
		models[i].rotation.y = atan2(direction.x, direction.z)
	center = (models[0].position + models[1].position) * 0.5
	camera = Camera3D.new()
	world.add_child(camera)
	camera.fov = 55
	camera.near = 0.1
	camera.far = 500
	camera.current = true
	_home()
	_ui()
	var relay := InputRelay.new()
	relay.callback = _input_event
	root.add_child(relay)
	_reset_encounter()
	if OS.get_environment("POKEAETHER_OUTDOOR_BATTLE_SMOKE") == "1":
		await _battle_smoke()
		quit()
		return
	if OS.get_environment("POKEAETHER_OUTDOOR_SMOKE") == "1":
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		assert(not output.is_empty())
		DirAccess.make_dir_recursive_absolute(output)
		for angle in 4:
			yaw = 0.5 + angle * PI / 2
			_camera_update()
			for frame in 60:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("orbit-%d.png" % angle))
		for action in entries[0].action_timing:
			for i in 2:
				_play(i, action)
			await process_frame
			assert(players[0].current_animation == action)
		pitch = 10
		distance = -10
		_camera_update()
		assert(is_equal_approx(pitch, 1.15) and is_equal_approx(distance, 5))
		_home()
		var initial := camera.position
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		_input_event(wheel)
		assert(distance < 14 and not camera.position.is_equal_approx(initial))
		_focus(0)
		assert(target.is_equal_approx(models[0].position + Vector3(0, 1.3, 0)))
		_focus(1)
		assert(target.is_equal_approx(models[1].position + Vector3(0, 1.3, 0)))
		_home()
		print("OUTDOOR_SMOKE_OK: four angles, seven actions, camera limits/reset")
		quit()

func _battle_smoke() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var original := camera.position
	_attack(0)
	await create_timer(0.3).timeout
	assert(busy and not camera.position.is_equal_approx(original))
	_attack(1) # Reentry must not cause another attack.
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("impact.png"))
	while busy:
		await process_frame
	assert(hp == [100, 82] and camera.position.is_equal_approx(original))
	assert(effects.get_child_count() == 0)
	camera_toggle.button_pressed = false
	await _attack(1)
	assert(hp == [82, 82] and camera.position.is_equal_approx(original))
	camera_toggle.button_pressed = true
	_attack(0)
	await create_timer(0.2).timeout
	_focus(1) # Manual control cancels later scripted camera cues.
	var manual := camera.position
	while busy:
		assert(camera.position.is_equal_approx(manual))
		await process_frame
	_reset_encounter()
	assert(hp == [100, 100] and effects.get_child_count() == 0)
	hp[1] = 18
	camera_toggle.button_pressed = false
	await _attack(0)
	assert(hp == [100, 0] and players[1].current_animation == "faint_start")
	await _attack(1)
	assert(hp == [100, 0])
	_reset_encounter()
	camera_toggle.button_pressed = true
	_home()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("overview.png"))
	print("OUTDOOR_BATTLE_OK: attacks, HP, reentry, effects cleanup, camera on/off/takeover, reset")
