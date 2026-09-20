extends Control
## Desktop presentation: explicit combatants/actions/transitions from battle host.
## Missing models/forms/doubles/substitute fall back as a pair, never guessing art.

const SUPPORTED := ["dragonite", "roaring-moon"]
const MaterialResponse = preload("res://scripts/battle/battle_ui/material_response.gd")
const ArenaCatalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const ForestPool = preload("res://scripts/battle/arenas/forest_environment_pool.gd")
var forest_lease := {}
var forest_pool: Node
var user_camera_yaw := 0.0
var user_camera_pitch := 0.0

func reset_user_camera() -> void:
	user_camera_yaw = 0.0
	user_camera_pitch = 0.0

func _release_forest() -> void:
	if forest_lease.is_empty():
		return
	if is_instance_valid(material_response):
		material_response._drop()
	if is_instance_valid(forest_pool):
		forest_pool.release(self)
	forest_lease.clear()
var arena_id := "classic"
var environment_id: StringName = &"grass"
var arena_root: Node3D
var arena_problem := ""
var ground_offsets := {}
var arena_preparing := false
var material_response: Node
var boxes: Array = []
var platforms: Array = []
var viewport: SubViewport
var render_surface: TextureRect
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
var catalog_problem := ""
var current_actions := ["idle", "idle"]
var resting := [true, true]
var mode_label: Label
var pending_entries: Array = []
var import_times_ms := {}
var loading_path := ""
var loading_entry := {}
var loading_started := 0

class LoadDrain extends Node:
	var path: String
	func _process(_delta: float) -> void:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if status in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED]:
			ResourceLoader.load_threaded_get(path)
		queue_free()

func _cancel_load() -> void:
	if not loading_path.is_empty():
		# ResourceLoader has no cancellation API. Drain without joining/blocking.
		var drain := LoadDrain.new()
		drain.path = loading_path
		get_tree().root.add_child.call_deferred(drain)
		loading_path = ""
		loading_entry.clear()

var preparation_cancelled := false
var preparation_failed := false
var warming_render := false
var preparation_phase := "Loading model catalog"
var preparation_metrics := {}

func _preparation_progress() -> Array:
	var progress: Array = []
	if not loading_path.is_empty():
		ResourceLoader.load_threaded_get_status(loading_path,progress)
	preparation_phase = "Loading Pokémon models"
	if arena_preparing:
		preparation_phase = "Loading forest terrain and textures"
	elif active:
		preparation_phase = "Preparing lighting and shaders"
	var pool := ForestPool.get_current()
	return [loaded_path,pending_entries.size(),loading_path,progress,ArenaCatalog.forest_progress(),pool.phase if pool != null else -1,active,identities.duplicate(),_blocking_pipelines()]

func cancel_preparation() -> void:
	preparation_cancelled = true
	warming_render = false
	_cancel_load()
	pending_entries.clear()

func _blocking_pipelines() -> Array:
	# Specialization compiles in the background and is not a blocking gate.
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]

func await_prepared(render_under_cover := false, timeout_ms := 10000) -> void:
	# Only the opaque screen host may temporarily expose hidden summon actors.
	# Reuse these exact viewports/materials after reveal; do not rebuild them.
	if render_under_cover:
		warming_render = true
	var deadline := Time.get_ticks_msec() + timeout_ms
	var started := Time.get_ticks_msec()
	var hard_deadline := started + maxi(timeout_ms,120000)
	var last_progress: Array = []
	var last_sample: Array = []
	var quiet_frames := 0
	var last_draw := -1
	while is_inside_tree():
		var progress := _preparation_progress()
		if progress != last_progress and timeout_ms > 0:
			deadline = Time.get_ticks_msec() + timeout_ms
			last_progress = progress.duplicate(true)
		preparation_metrics = {"elapsed_ms":Time.get_ticks_msec()-started,"phase":preparation_phase,"forest_load_ms":ArenaCatalog.forest_load_ms}
		if preparation_cancelled or preparation_failed:
			warming_render = false
			return
		var settings := get_tree().root.get_node("SettingsManager")
		if settings.battle_presentation_mode != "3d" or OS.has_feature("web") or OS.has_feature("mobile"):
			warming_render = false
			return
		var requested: String = settings.battle_3d_catalog_path
		if requested.is_empty():
			requested = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
		if loaded_path == requested and pending_entries.is_empty() and loading_path.is_empty() and not arena_preparing:
			if not render_under_cover and not warming_render:
				await get_tree().process_frame
				await get_tree().process_frame
				return
			if render_under_cover:
				var has_combatants: bool = not combatants[0].species.is_empty() or not combatants[1].species.is_empty()
				if not catalog_problem.is_empty() or (not active and has_combatants):
					# Give _process time to resolve combatants before accepting fallback.
					quiet_frames += 1
					if quiet_frames >= 5:
						warming_render = false
						return
				elif active:
					var sample := _blocking_pipelines()
					sample.append(viewport.size)
					sample.append(identities.duplicate())
					var drawn := Engine.get_frames_drawn()
					if sample != last_sample:
						quiet_frames = 0
					elif drawn != last_draw or DisplayServer.get_name() == "headless":
						quiet_frames += 1
					last_draw = drawn
					last_sample = sample
					if quiet_frames >= 5:
						warming_render = false
						# Restore actual send-out visibility before fading the cover.
						await get_tree().process_frame
						return
		if Time.get_ticks_msec() >= deadline or Time.get_ticks_msec() >= hard_deadline:
			_cancel_load()
			pending_entries.clear()
			preparation_failed = true
			warming_render = false
			reason = "3D preparation stalled: " + preparation_phase
			_set_active(false)
			return
		await get_tree().process_frame
var action_generation := [0, 0]
var camera_phase := 0.0
var combatants := [{"species": "", "shiny": false}, {"species": "", "shiny": false}]
var actor_shown := [true, true]
var actor_scale := [1.0, 1.0]
var transition_tweens: Array = [null, null]
var transition_generation := [0, 0]
var lifecycle := ["empty", "empty"]
var playback_speed := 1.0
var move_categories := {}
const CAMERA_HOME := Vector3(4, 5.5, 12)

func attack_action_for(move_name: String) -> String:
	if move_categories.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_summary_index.json"))
		if parsed is Dictionary:
			move_categories = parsed
	var key := move_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	return "physical_attack" if str(move_categories.get(key, {}).get("category", "")).to_lower() == "physical" else "special_attack"

func set_combatant(index: int, species: String, shiny := false, force := false) -> void:
	var normalized := species.to_lower().replace(" ", "-")
	if not force and combatants[index].species == normalized and combatants[index].shiny == shiny:
		return
	action_generation[index] += 1
	_stop_transition(index)
	combatants[index] = {"species": normalized, "shiny": shiny}
	actor_shown[index] = true
	actor_scale[index] = 1.0
	restoring[index] = "idle"
	lifecycle[index] = "empty" if normalized.is_empty() else "idle"
	if active and identities[index] == normalized and players[index] != null:
		_action("reset", index)

func actor_index(ident: String) -> int:
	return 0 if ident.begins_with("p1") else (1 if ident.begins_with("p2") else -1)

func handles(ident: String) -> bool:
	var index := actor_index(ident)
	return active and index >= 0 and is_instance_valid(actors[index])

func set_sleeping(index: int, sleeping: bool) -> void:
	var desired := "sleep" if sleeping else "idle"
	if restoring[index] == desired:
		return
	restoring[index] = desired
	if active and players[index] != null and resting[index]:
		_action("reset", index)

func cancel_actions() -> void:
	for index in 2:
		_stop_transition(index)
		actor_scale[index] = 1.0
		actor_shown[index] = not combatants[index].species.is_empty()
		lifecycle[index] = "idle" if actor_shown[index] else "empty"
		_action("reset", index)

func start_action(ident: String, action: String) -> void:
	if handles(ident):
		_action(action, actor_index(ident))

func wait_action(ident: String) -> void:
	if not handles(ident):
		return
	var index := actor_index(ident)
	var generation: int = action_generation[index]
	while is_inside_tree() and handles(ident) and generation == action_generation[index]:
		if current_actions[index] in ["idle", "sleep"] or not players[index].is_playing():
			return
		await get_tree().process_frame

func play_action(ident: String, action: String) -> void:
	start_action(ident, action)
	if not handles(ident):
		return
	var generation: int = action_generation[actor_index(ident)]
	await wait_action(ident)
	if action == "faint_start" and handles(ident) and generation == action_generation[actor_index(ident)] and current_actions[actor_index(ident)] == "faint_start":
		actor_shown[actor_index(ident)] = false
		lifecycle[actor_index(ident)] = "fainted"

func _stop_transition(index: int) -> void:
	transition_generation[index] += 1
	if transition_tweens[index] != null and transition_tweens[index].is_valid():
		transition_tweens[index].kill()
	transition_tweens[index] = null

func set_actor_shown(index: int, shown: bool) -> void:
	_stop_transition(index)
	actor_shown[index] = shown
	actor_scale[index] = 1.0
	lifecycle[index] = "idle" if shown else "hidden"

func send_out(ident: String) -> bool:
	if not handles(ident):
		return false
	return await _transition_actor(actor_index(ident), true, 0.32)

func recall(ident: String) -> bool:
	if not handles(ident):
		return false
	return await _transition_actor(actor_index(ident), false, 0.26)

func _transition_actor(index: int, entering: bool, duration: float) -> bool:
	_stop_transition(index)
	var generation: int = transition_generation[index]
	lifecycle[index] = "send_out" if entering else "recall"
	actor_shown[index] = true
	actor_scale[index] = 0.05 if entering else 1.0
	var tween := create_tween().set_speed_scale(playback_speed)
	transition_tweens[index] = tween
	tween.tween_method(func(value: float): actor_scale[index] = value,
		actor_scale[index], 1.0 if entering else 0.05, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		actor_shown[index] = entering
		lifecycle[index] = "idle" if entering else "hidden"
		transition_tweens[index] = null)
	while is_inside_tree() and active and generation == transition_generation[index] and tween.is_valid() and tween.is_running():
		await get_tree().process_frame
	return is_inside_tree() and active and generation == transition_generation[index]

func setup(sprite_boxes: Array = [], stage_platforms: Array = []) -> void:
	boxes = sprite_boxes
	platforms = stage_platforms
	name = "ExperimentalBattle3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	render_surface = TextureRect.new()
	render_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	render_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(render_surface)
	render_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mode_label = Label.new()
	mode_label.position = Vector2(16, 55)
	mode_label.z_index = 125
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(mode_label)
	material_response = MaterialResponse.new()
	material_response.stage = self
	add_child(material_response)
	set_process(true)
	# Observe before rendering but after SpriteBox state changes.
	process_priority = 10

static func supported(species: String, shiny: bool, double: bool, substitute: bool) -> bool:
	return species.to_lower().replace(" ", "-") in SUPPORTED and not shiny and not double and not substitute

func _requested_arena() -> String:
	return ArenaCatalog.resolve(get_tree().root.get_node("SettingsManager").battle_3d_arena, environment_id)

func _build_world() -> void:
	if _requested_arena() == "forest" and ground_offsets.size() >= packed.size():
		forest_pool = ForestPool.get_current()
		if forest_pool != null:
			forest_lease = forest_pool.acquire(self)
		if not forest_lease.is_empty():
			arena_id = "forest"
			viewport = forest_lease.main.viewport
			world = forest_lease.main.world
			camera = forest_lease.main.camera
			arena_root = forest_lease.main.arena
			camera.position = ArenaCatalog.camera_home(arena_id)
			camera.look_at(ArenaCatalog.camera_target(arena_id))
			_sync_render_size()
			render_surface.texture = viewport.get_texture()
			return
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	_sync_render_size()
	render_surface.texture = viewport.get_texture()
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("23364b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	MaterialResponse.apply_neutral_lighting(world)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for light in world.get_children():
		if light is DirectionalLight3D:
			light.shadow_blur = 2.0/3.0
	arena_id = _requested_arena()
	if arena_id != "classic" and ground_offsets.size() < packed.size():
		arena_problem = "Arena ground calibration missing or outdated; regenerate the local catalog grounding file"
		arena_id = "classic"
	if arena_id == "forest":
		arena_problem = ArenaCatalog.prepare_forest(get_tree().root.get_node("SettingsManager").get_battle_3d_forest_manifest())
		if not arena_problem.is_empty():
			arena_id = "classic"
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	arena_root = ArenaCatalog.build(arena_id, world, camera)
	if arena_root != null:
		world.add_child(arena_root)
	else:
		_build_classic_ground()
	camera.position = ArenaCatalog.camera_home(arena_id)
	camera.fov = 48
	camera.look_at(ArenaCatalog.camera_target(arena_id))
	camera.current = true

func _build_classic_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	_mesh(plane, Vector3(0, -0.1, 0), Color("405651"))
	for i in 2:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.3
		cylinder.bottom_radius = 2.4
		cylinder.height = 0.1
		_mesh(cylinder, _position(i) - Vector3(0, 0.05, 0), Color("879b8a"))

func _position(index: int) -> Vector3:
	var point := ArenaCatalog.spawn(index)
	if is_instance_valid(arena_root):
		point.y = float(arena_root.get_meta("surface_height",0.0))
	return point

func build_response_arena(response_world: Node3D, response_camera: Camera3D) -> Node3D:
	return ArenaCatalog.build(arena_id, response_world, response_camera)

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
	_cancel_load()
	loaded_path = path
	pending_entries.clear()
	import_times_ms.clear()
	catalog_problem = "Invalid 3D catalog; choose a prepared preview report in Settings"
	reason = catalog_problem
	entries.clear()
	packed.clear()
	_clear_actors()
	if path.strip_edges().is_empty():
		catalog_problem = "No 3D catalog selected — choose a local 3D preview report in Settings"
		reason = catalog_problem
		return
	if not FileAccess.file_exists(path):
		catalog_problem = "Selected 3D catalog not found — choose it again in Settings"
		reason = catalog_problem
		return
	var prepared_path := path + ".runtime.json" if FileAccess.file_exists(path + ".runtime.json") else path
	ground_offsets.clear()
	var calibration := {}
	if FileAccess.file_exists(prepared_path+".grounding.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(prepared_path+".grounding.json"))
		if parsed is Dictionary and parsed.get("schema",0)==1 and parsed.get("entries") is Dictionary:
			calibration = parsed.entries
	var file := FileAccess.open(prepared_path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Array:
		return
	for entry in data:
		if not entry is Dictionary or not entry.get("species", "") in SUPPORTED:
			continue
		var model_path := str(entry.get("runtime_path", ""))
		var timing: Variant = entry.get("action_timing", {})
		if entry.get("runtime_schema", 0) != 1 or not timing is Dictionary or not model_path.ends_with(".scn") or not FileAccess.file_exists(model_path):
			continue
		var model_file := FileAccess.open(model_path, FileAccess.READ)
		if model_file == null or model_file.get_length() > 134217728:
			continue
		var valid := true
		for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start"]:
			var spec: Variant = timing.get(action, {})
			if not spec is Dictionary or float(spec.get("frames", 0)) <= 0 or float(spec.get("speed", 0)) <= 0:
				valid = false
		if not valid:
			continue
		if not pending_entries.any(func(item): return item.species == entry.species):
			var ground: Dictionary = calibration.get(entry.species,{})
			var expected_scale := 1.0 if entry.species == "dragonite" else 0.65
			if ground.get("sha256","") == FileAccess.get_sha256(model_path) and is_equal_approx(float(ground.get("scale",0)),expected_scale) and is_finite(float(ground.get("lift",NAN))) and float(ground.get("lift",-1)) >= 0:
				ground_offsets[entry.species] = ground
			pending_entries.append(entry)
	if not pending_entries.is_empty():
		catalog_problem = ""
		reason = "Preparing local 3D models…"
	else:
		catalog_problem = "Catalog has no valid prepared Dragonite/Roaring Moon models"
		reason = catalog_problem

func _import_next_model() -> void:
	if loading_path.is_empty():
		if pending_entries.is_empty():
			return
		loading_entry = pending_entries.pop_front()
		loading_path = loading_entry.runtime_path
		loading_started = Time.get_ticks_usec()
		if ResourceLoader.load_threaded_request(loading_path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE) != OK:
			catalog_problem = "Could not load prepared 3D model: " + str(loading_entry.species)
			loading_path = ""
			loading_entry.clear()
		return
	var status := ResourceLoader.load_threaded_get_status(loading_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene := ResourceLoader.load_threaded_get(loading_path) as PackedScene
		if scene != null:
			packed[loading_entry.species] = scene
			entries[loading_entry.species] = loading_entry.duplicate(true)
			import_times_ms[loading_entry.species] = (Time.get_ticks_usec() - loading_started) / 1000.0
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		catalog_problem = "Could not load prepared 3D model: " + str(loading_entry.species)
		ResourceLoader.load_threaded_get(loading_path)
	loading_path = ""
	loading_entry.clear()

func _clear_actors() -> void:
	for i in 2:
		action_generation[i] += 1
		if is_instance_valid(actors[i]):
			actors[i].queue_free()
		actors[i] = null
		players[i] = null
		identities[i] = ""

func _set_active(value: bool) -> void:
	if active and not value:
		camera_phase = 0.0
		for i in 2:
			_stop_transition(i)
			action_generation[i] += 1
			if is_instance_valid(players[i]):
				players[i].stop()
				resting[i] = true
				current_actions[i] = "idle"
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

func _sync_render_size() -> void:
	if viewport == null:
		return
	# Include both the battlefield/UI scale and the window's stretch transform.
	# The texture's raster size is independent of the HUD's design coordinates.
	var screen := get_screen_transform()
	var target := Vector2i(maxi(2, ceili(size.x * screen.x.length())), maxi(2, ceili(size.y * screen.y.length())))
	if viewport.size != target:
		viewport.size = target

func _project_to_ui(point: Vector3) -> Vector2:
	var local_point := camera.unproject_position(point) * size / Vector2(viewport.size)
	return get_global_transform() * local_point

func _anchor(body: bool, index: int) -> Vector2:
	if actors[index] == null:
		return Vector2.ZERO
	var point: Vector3 = actors[index].position + Vector3(0,1.2,0) if body else _position(index)
	return _project_to_ui(point)

func _visual_rect(index: int) -> Rect2:
	if actors[index] == null or not actors[index].visible:
		return Rect2()
	# Conservative presentation bounds; source skeletal mesh AABBs include rest pose.
	var bottom := _anchor(false, index)
	var top := _project_to_ui(actors[index].position + Vector3(0, 3, 0))
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
	action_generation[index] += 1
	current_actions[index] = action
	var spec: Dictionary = entries[identities[index]].action_timing[action]
	var animation: Animation = players[index].get_animation(action)
	animation.length = float(spec.frames) / 60.0
	animation.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
	players[index].speed_scale = playback_speed
	players[index].play(action, -1, float(spec.speed))
	resting[index] = action in ["idle", "sleep", "faint_start", "faint_loop"]

func _update_camera(delta: float) -> void:
	var settings := get_tree().root.get_node("SettingsManager")
	if not settings.battle_3d_camera_motion:
		camera_phase = 0.0
		camera.position = ArenaCatalog.camera_home(arena_id)
	else:
		# Small arc, never crosses the combat axis; both actors remain in frame.
		# Hold framing during actions: existing 2D effects capture screen anchors.
		if resting[0] and resting[1] and current_actions[0] in ["idle", "sleep"] and current_actions[1] in ["idle", "sleep"] and lifecycle[0] in ["idle", "empty", "hidden"] and lifecycle[1] in ["idle", "empty", "hidden"]:
			camera_phase += delta * 0.22
		camera.position = ArenaCatalog.camera_home(arena_id).rotated(Vector3.UP, sin(camera_phase) * 0.10)
	var target := ArenaCatalog.camera_target(arena_id)
	var offset := camera.position - target
	offset = offset.rotated(Vector3.UP,user_camera_yaw)
	var right := offset.cross(Vector3.UP).normalized()
	offset = offset.rotated(right,user_camera_pitch)
	camera.position = target + offset
	camera.look_at(target)

func _process(delta: float) -> void:
	_sync_render_size()
	if preparation_failed or preparation_cancelled:
		_set_active(false)
		if is_instance_valid(mode_label):
			mode_label.text = "2.5D · " + reason
			mode_label.tooltip_text = reason
		return
	var settings := get_tree().root.get_node("SettingsManager")
	mode_label.visible = settings.battle_presentation_mode == "3d" and not OS.has_feature("web") and not OS.has_feature("mobile")
	mode_label.text = ("3D · " + arena_id + (" · " + arena_problem if not arena_problem.is_empty() else "")) if active else ("Preparing local 3D models…" if not pending_entries.is_empty() or not loading_path.is_empty() else "2.5D · " + reason)
	mode_label.tooltip_text = reason + (" · " + arena_problem if not arena_problem.is_empty() else "")
	if settings.battle_presentation_mode != "3d" or OS.has_feature("web") or OS.has_feature("mobile"):
		_set_active(false)
		_cancel_load()
		pending_entries.clear()
		loaded_path = "!unloaded"
		if not packed.is_empty() or viewport != null:
			_clear_actors()
			packed.clear()
			entries.clear()
			if viewport != null:
				render_surface.texture = null
				if forest_lease.is_empty():
					viewport.queue_free()
				else:
					_release_forest()
				viewport = null
				world = null
				camera = null
		return
	var path: String = settings.battle_3d_catalog_path
	if path.is_empty():
		path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	# Start independent terrain I/O alongside model loading, not after it.
	if viewport == null and _requested_arena() == "forest":
		arena_problem = ArenaCatalog.prepare_forest(settings.get_battle_3d_forest_manifest())
		arena_preparing = arena_problem.is_empty() and not ArenaCatalog.forest_ready()
	if path != loaded_path:
		_set_active(false)
		_load_catalog(path)
		return
	if not pending_entries.is_empty() or not loading_path.is_empty():
		_import_next_model()
		return
	if packed.is_empty() and not catalog_problem.is_empty():
		reason = catalog_problem
		_set_active(false)
		return
	var desired := []
	for platform in platforms:
		if platform.hazards.visible or platform.player_screens.visible or platform.enemy_screens.visible:
			reason = "Field hazard/screen presentation uses 2.5D"
			_set_active(false)
			return
	for index in 2:
		var box: Node = boxes[index] if index < boxes.size() else null
		var double: bool = box != null and box.double_container.visible
		var substitute: bool = box != null and box.substitute_active
		var species: String = combatants[index].species
		if species.is_empty() and not double and not substitute:
			desired.append("")
			continue
		if not supported(species, combatants[index].shiny, double, substitute):
			reason = "Unsupported active Pokémon/form, doubles or substitute: " + species
			_set_active(false)
			return
		if not packed.has(species):
			reason = "Prepared 3D model unavailable: " + species
			_set_active(false)
			return
		desired.append(species)
	if desired == ["", ""]:
		_set_active(false)
		return
	if viewport == null:
		if _requested_arena() == "forest":
			arena_problem = ArenaCatalog.prepare_forest(get_tree().root.get_node("SettingsManager").get_battle_3d_forest_manifest())
			arena_preparing = arena_problem.is_empty() and not ArenaCatalog.forest_ready()
			var pool := ForestPool.get_current()
			if pool != null and not pool.ready_for_battle and not pool.failed:
				arena_preparing = true
			if arena_preparing:
				reason = "Preparing forest assets…"
				return
		_build_world()
	_set_active(true)
	_update_camera(delta)
	reason = "Experimental 3D active"
	for i in 2:
		if desired[i].is_empty():
			action_generation[i] += 1
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
			if ground_offsets.has(desired[i]):
				actors[i].position.y += float(ground_offsets[desired[i]].lift)
			actors[i].scale = Vector3.ONE * (1.0 if desired[i] == "dragonite" else 0.65)
			var direction := _position(1-i) - _position(i)
			actors[i].rotation.y = atan2(direction.x, direction.z)
			players[i] = _find_player(actors[i])
			identities[i] = desired[i]
			resting[i] = true
			_action(restoring[i], i)
		players[i].speed_scale = playback_speed
		if transition_tweens[i] != null and transition_tweens[i].is_valid():
			transition_tweens[i].set_speed_scale(playback_speed)
		if resting[i] and not players[i].is_playing() and current_actions[i] not in ["faint_start", "faint_loop"]:
			_action(restoring[i], i)
		actors[i].visible = warming_render or actor_shown[i]
		actors[i].scale = Vector3.ONE * (1.0 if warming_render else actor_scale[i]) * (1.0 if identities[i] == "dragonite" else 0.65)
		if not resting[i] and not players[i].is_playing():
			resting[i] = true
			_action(restoring[i], i)

func _exit_tree() -> void:
	for index in 2:
		_stop_transition(index)
	_cancel_load()
	_set_active(false)
	pending_entries.clear()
	packed.clear()
	entries.clear()
	_clear_actors()
	if is_instance_valid(mode_label):
		mode_label.queue_free()
	_release_forest()
