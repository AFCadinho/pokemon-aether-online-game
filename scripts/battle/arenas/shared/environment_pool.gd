extends Node
## One world-session-owned pair of mesh-environment passes. Never stores battle state.
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
static var current: WeakRef
var arena_id := "forest"
var passes: Array[Dictionary] = []
var ready_for_battle := false
var failed := false
var borrower: WeakRef
var phase := 0
var started := 0
var preparation_ms := 0
var render_size := Vector2i(1152,648)
var quiet_frames := 0
var last_pipelines: Array = []
var memory_before := 0.0
var retained_render_bytes := 0.0

static func get_current() -> Node:
	return current.get_ref() if current != null else null

static func prepare(owner_node: Node, manifest: String, dimensions: Vector2i, requested_arena := "forest") -> Node:
	var existing := get_current()
	if existing != null and existing.get_parent() == owner_node:
		if existing.arena_id == requested_arena:
			return existing
		if existing.borrower != null and existing.borrower.get_ref() != null:
			return null
		existing.queue_free()
	if not Catalog.prepare_forest(manifest).is_empty():
		return null
	var pool := new()
	pool.name = "ForestEnvironmentPool"
	pool.arena_id = requested_arena
	pool.render_size = dimensions.max(Vector2i(2,2))
	pool.started = Time.get_ticks_msec()
	pool.memory_before = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	pool.process_mode = Node.PROCESS_MODE_ALWAYS
	current = weakref(pool)
	owner_node.add_child(pool)
	return pool

func _process(_delta: float) -> void:
	if failed or ready_for_battle:
		return
	if Time.get_ticks_msec()-started > 120000:
		failed = true
		for pass_data in passes:
			pass_data.viewport.queue_free()
		passes.clear()
		return
	if not Catalog.forest_ready():
		failed = not Catalog.forest_error.is_empty() or Time.get_ticks_msec()-started > 120000
		return
	if passes.size() < 2:
		passes.append(_build_pass(passes.size() == 1))
		phase += 1
		return # Spread mesh assembly over two frames, outside the battle.
	var sample := [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]
	quiet_frames = quiet_frames + 1 if sample == last_pipelines else 0
	last_pipelines = sample
	if quiet_frames < 8:
		return
	ready_for_battle = true
	phase += 1
	preparation_ms = Time.get_ticks_msec()-started
	retained_render_bytes = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)-memory_before
	_suspend()
	print("FOREST_ENVIRONMENT_READY ms=",preparation_ms," render_memory_delta=",retained_render_bytes)

func _build_pass(light_pass: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.use_hdr_2d = light_pass
	viewport.transparent_bg = light_pass
	viewport.size = render_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.set_meta("pooled_forest_environment",true)
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b4cad6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	Response.apply_neutral_lighting(world)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for child in world.get_children():
		if child is DirectionalLight3D:
			child.shadow_blur = 2.0/3.0
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Catalog.camera_home(arena_id)
	camera.fov = 48
	camera.look_at(Catalog.camera_target(arena_id))
	camera.current = true
	var arena := Catalog.build(arena_id,world,camera)
	world.add_child(arena)
	return {"viewport":viewport,"world":world,"camera":camera,"arena":arena,"base":world.get_children()}

func acquire(client: Node) -> Dictionary:
	if not ready_for_battle or (borrower != null and borrower.get_ref() != null):
		return {}
	borrower = weakref(client)
	for pass_data in passes:
		pass_data.world.process_mode = Node.PROCESS_MODE_INHERIT
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return {"main":passes[0],"response":passes[1]}

func release(client: Node) -> void:
	if borrower == null or borrower.get_ref() != client:
		return
	for pass_data in passes:
		for child in pass_data.world.get_children():
			if child not in pass_data.base:
				child.free()
	borrower = null
	_suspend()

func _suspend() -> void:
	for pass_data in passes:
		pass_data.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		pass_data.world.process_mode = Node.PROCESS_MODE_DISABLED
