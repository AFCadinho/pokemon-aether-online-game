extends SubViewportContainer
## Optional local desktop renderer, driven by the existing SpriteBox presentation.
## Missing models/forms/doubles/substitute fall back as a pair, never guessing art.

const SUPPORTED := ["dragonite", "roaring-moon"]
var boxes: Array = []
var platforms: Array = []
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var entries := {}
var packed := {}
var actors: Array = [null, null]
var players: Array = [null, null]
var identities := ["", ""]
var restoring := ["idle", "idle"]
var loaded_path := "!unloaded"
var active := false
var saved_colors := {}
var reason := "2.5D selected"
var elapsed := [0.0, 0.0]
var resting := [true, true]
var mode_label: Label

func setup(sprite_boxes: Array, stage_platforms: Array) -> void:
	boxes = sprite_boxes
	platforms = stage_platforms
	name = "ExperimentalBattle3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	visible = false
	mode_label = Label.new()
	mode_label.position = Vector2(16, 55)
	mode_label.z_index = 125
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(mode_label)
	for i in 2:
		boxes[i].presentation_action.connect(_action.bind(i))
	set_process(true)

static func supported(species: String, shiny: bool, double: bool, substitute: bool) -> bool:
	return species.to_lower().replace(" ", "-") in SUPPORTED and not shiny and not double and not substitute

func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("23364b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c3d8e6")
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	world.add_child(sun)
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	_mesh(plane, Vector3(0, -0.1, 0), Color("405651"))
	for i in 2:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.3
		cylinder.bottom_radius = 2.4
		cylinder.height = 0.1
		_mesh(cylinder, _position(i) - Vector3(0, 0.05, 0), Color("879b8a"))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4, 5.5, 12)
	camera.fov = 48
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true

func _position(index: int) -> Vector3:
	return Vector3(-2.8, 0, 1.5) if index == 0 else Vector3(2.8, 0, -1.5)

func _mesh(shape: Mesh, point: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	node.material_override = material
	world.add_child(node)

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var player := _find_player(child)
		if player != null:
			return player
	return null

func _load_catalog(path: String) -> void:
	loaded_path = path
	entries.clear()
	packed.clear()
	_clear_actors()
	if not FileAccess.file_exists(path):
		reason = "3D report missing; using 2.5D"
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Array:
		return
	for entry in data:
		if not entry is Dictionary or not entry.get("species", "") in SUPPORTED:
			continue
		var model_path := str(entry.get("path", ""))
		var timing: Variant = entry.get("action_timing", {})
		if not timing is Dictionary or not model_path.ends_with(".glb") or not FileAccess.file_exists(model_path):
			continue
		var model_file := FileAccess.open(model_path, FileAccess.READ)
		if model_file == null or model_file.get_length() > 33554432:
			continue
		var valid := true
		for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start"]:
			var spec: Variant = timing.get(action, {})
			if not spec is Dictionary or float(spec.get("frames", 0)) <= 0 or float(spec.get("speed", 0)) <= 0:
				valid = false
		if not valid:
			continue
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(model_path, state) != OK:
			continue
		var model := document.generate_scene(state, 60)
		if model == null:
			continue
		var player := _find_player(model)
		if player == null:
			model.free()
			continue
		for action in timing:
			if not player.has_animation(action):
				valid = false
		if valid:
			var scene := PackedScene.new()
			if scene.pack(model) == OK:
				packed[entry.species] = scene
				entries[entry.species] = entry
		model.free()

func _clear_actors() -> void:
	for i in 2:
		if is_instance_valid(actors[i]):
			actors[i].queue_free()
		actors[i] = null
		players[i] = null
		identities[i] = ""

func _set_active(value: bool) -> void:
	active = value
	visible = value
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if not value:
		for node in saved_colors:
			if is_instance_valid(node):
				node.self_modulate = saved_colors[node]
		saved_colors.clear()
	for i in boxes.size():
		boxes[i].presentation_anchor = _anchor.bind(i) if value else Callable()
		boxes[i].presentation_visual_rect = _visual_rect.bind(i) if value else Callable()
	if value:
		var hidden: Array = []
		for platform in platforms:
			hidden.append(platform.get_node("PlatformImage"))
		for box in boxes:
			hidden.append(box.single_sprite)
			if is_instance_valid(box.dratini_poc_shadow):
				hidden.append(box.dratini_poc_shadow)
		for node in hidden:
			if not saved_colors.has(node):
				saved_colors[node] = node.self_modulate
			node.self_modulate.a = 0.0

func _anchor(body: bool, index: int) -> Vector2:
	if actors[index] == null:
		return Vector2.ZERO
	var point := _position(index) + (Vector3(0, 1.2, 0) if body else Vector3.ZERO)
	return get_global_transform() * camera.unproject_position(point)

func _visual_rect(index: int) -> Rect2:
	if actors[index] == null or not actors[index].visible:
		return Rect2()
	# Conservative presentation bounds; source skeletal mesh AABBs include rest pose.
	var bottom := _anchor(false, index)
	var top := get_global_transform() * camera.unproject_position(_position(index) + Vector3(0, 3, 0))
	var extent := absf(bottom.y - top.y)
	return Rect2(Vector2(bottom.x - extent * 0.7, top.y), Vector2(extent * 1.4, extent))

func _action(action: String, index: int) -> void:
	if not active or players[index] == null:
		return
	var forced := action == "reset"
	if forced:
		resting[index] = true
		action = restoring[index]
	if action in ["idle", "sleep"]:
		var changed: bool = forced or restoring[index] != action
		restoring[index] = action
		if not resting[index]:
			return
		if not changed and players[index].current_animation in ["idle", "sleep", "faint_start", "faint_loop"]:
			return
	if not players[index].has_animation(action):
		return
	var spec: Dictionary = entries[identities[index]].action_timing[action]
	var animation: Animation = players[index].get_animation(action)
	animation.length = float(spec.frames) / 60.0
	animation.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
	players[index].play(action, -1, float(spec.speed) * boxes[index].playback_speed)
	elapsed[index] = animation.length / (float(spec.speed) * boxes[index].playback_speed)
	resting[index] = action in ["idle", "sleep", "faint_start", "faint_loop"]

func _process(delta: float) -> void:
	if boxes.size() != 2:
		return
	var settings := get_tree().root.get_node("SettingsManager")
	mode_label.visible = settings.battle_presentation_mode == "3d"
	mode_label.text = "3D preview" if active else "2.5D · 3D preview unavailable"
	mode_label.tooltip_text = reason
	if settings.battle_presentation_mode != "3d" or OS.has_feature("web") or OS.has_feature("mobile"):
		_set_active(false)
		if not packed.is_empty():
			_clear_actors()
			packed.clear()
			entries.clear()
			loaded_path = "!unloaded"
		return
	var path: String = settings.battle_3d_catalog_path
	if path.is_empty():
		path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if path != loaded_path:
		_set_active(false)
		_load_catalog(path)
	var desired := []
	for platform in platforms:
		if platform.hazards.visible or platform.player_screens.visible or platform.enemy_screens.visible:
			reason = "Field hazard/screen presentation uses 2.5D"
			_set_active(false)
			return
	for box in boxes:
		var species: String = box.current_single_species.to_lower().replace(" ", "-")
		if species.is_empty() and not box.double_container.visible and not box.substitute_active:
			desired.append("")
			continue
		if not supported(species, box.current_single_is_shiny, box.double_container.visible, box.substitute_active) or not packed.has(species):
			reason = "Unsupported active Pokémon/situation; using 2.5D"
			_set_active(false)
			return
		desired.append(species)
	if desired == ["", ""]:
		_set_active(false)
		return
	if viewport == null:
		_build_world()
	_set_active(true)
	reason = "Experimental 3D active"
	for i in 2:
		if desired[i].is_empty():
			if is_instance_valid(actors[i]):
				actors[i].queue_free()
			actors[i] = null
			players[i] = null
			identities[i] = ""
			continue
		if identities[i] != desired[i]:
			if is_instance_valid(actors[i]):
				actors[i].queue_free()
			actors[i] = packed[desired[i]].instantiate()
			world.add_child(actors[i])
			actors[i].position = _position(i)
			actors[i].scale = Vector3.ONE * (1.0 if desired[i] == "dragonite" else 0.65)
			var direction := _position(1-i) - _position(i)
			actors[i].rotation.y = atan2(direction.x, direction.z)
			players[i] = _find_player(actors[i])
			identities[i] = desired[i]
			restoring[i] = "idle"
			resting[i] = true
			_action("idle", i)
		actors[i].visible = boxes[i].single_sprite.is_visible_in_tree() and boxes[i].modulate.a > 0.05 and boxes[i].single_sprite.modulate.a > 0.05
		if not resting[i]:
			elapsed[i] -= delta
			if elapsed[i] <= 0:
				resting[i] = true
				_action(restoring[i], i)

func _exit_tree() -> void:
	_set_active(false)
	if is_instance_valid(mode_label):
		mode_label.queue_free()
