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
	target = center + Vector3(0, 1.5, 0)
	yaw = 0.5
	pitch = 0.27
	distance = 14.0
	_camera_update()

func _input_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
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
	var action := action_select.get_item_text(action_select.selected)
	for i in 2:
		_play(i, action)
	status.text = "Playing: " + action + " · camera stays freely controllable"

func _focus(index: int) -> void:
	target = models[index].position + Vector3(0, 1.3, 0)
	distance = 7.0
	_camera_update()

func _button(text: String, callback: Callable, row: HBoxContainer) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	row.add_child(button)

func _ui() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -125
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
	var row := HBoxContainer.new()
	column.add_child(row)
	_button("Battle view", _home, row)
	_button("Dragonite", _focus.bind(0), row)
	_button("Roaring Moon", _focus.bind(1), row)
	action_select = OptionButton.new()
	for action in entries[0].action_timing:
		action_select.add_item(action)
	row.add_child(action_select)
	_button("Play both", _animate, row)
	status = Label.new()
	status.text = "GDQuest environment · art CC-BY-NC-SA 4.0 · local noncommercial study only"
	column.add_child(status)

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
	root.title = "PokeAether — outdoor 3D review (GDQuest, noncommercial)"
	root.msaa_3d = Viewport.MSAA_4X
	Engine.max_fps = 60
	world = Node3D.new()
	root.add_child(world)
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
