extends SceneTree
## Full production presenter, fixed raster size; diagnostic APK only.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Pool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const ORIGIN := "http://127.0.0.1:8799/"
const REPORT := "user://android-battle-budget-details.json"
const DIMENSIONS := Vector2i(960, 540)
var report := {"suite":"android-battle-budget", "schema":1, "phases":[]}
var failures: Array[String] = []
var service: Node
var settings: Node
var pool: Node
var stage: Control
var response_exercised := false
var canvas: SubViewport
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
		print("ANDROID_BATTLE_BUDGET_FAIL ", reason)
	return ok
func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null,"Write diagnostic file: " + path.get_file()):
		file.store_string(text)
		file.close()
func _fetch(name: String) -> PackedByteArray:
	var request := HTTPRequest.new()
	request.timeout = 45
	request.body_size_limit = 80 * 1024 * 1024
	root.add_child(request)
	if request.request(ORIGIN + name) != OK:
		_check(false, "Fixture request start: " + name)
		request.queue_free()
		return PackedByteArray()
	var result: Array = await request.request_completed
	request.queue_free()
	return result[3] if _check(result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200, "Fixture HTTP: " + name) else PackedByteArray()
func _forest() -> bool:
	var config = JSON.parse_string((await _fetch("fixture.json")).get_string_from_utf8())
	if not _check(config is Dictionary and config.has("android-etc2-art"), "ETC2 fixture pins"):
		return false
	var pin: Dictionary = config["android-etc2-art"]
	var path := "user://android-battle-budget-forest.pck"
	if not service._valid_file(ProjectSettings.globalize_path(path), int(pin.bytes), pin.sha256):
		var bytes: PackedByteArray = await _fetch("android-etc2-art/forest.pck")
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if not _check(bytes.size() == int(pin.bytes) and hash.finish().hex_encode() == pin.sha256, "Exact candidate PCK hash"):
			return false
		var file := FileAccess.open(path,FileAccess.WRITE)
		if not _check(file != null,"Write fixture pack"):
			return false
		file.store_buffer(bytes)
		file.close()
	_write("user://android-battle-budget-forest.json", '{"schema":1,"pack":"android-battle-budget-forest.pck"}')
	settings.battle_3d_forest_manifest = "user://android-battle-budget-forest.json"
	report.arena_pin = pin
	return true
func _metrics() -> Dictionary:
	return {"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),
		"render_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
func _observe(label: String) -> void:
	_write("user://android-battle-budget-phase", label)
	print("ANDROID_BATTLE_BUDGET_PHASE ", label)
	# Counters can lag by a second. Keep a native sampler window per phase.
	var start := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var samples: Array[float] = []
	while samples.size() < 10 or Time.get_ticks_msec() - start < 5000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-last)/1000.0)
		last = now
	await RenderingServer.frame_post_draw
	samples.sort()
	var phase := _metrics()
	phase.label = label
	phase.frames = samples.size()
	phase.frame_p50_ms = samples[samples.size()/2]
	phase.frame_p95_ms = samples[int(samples.size()*0.95)]
	phase.frame_max_ms = samples.back()
	phase.pool_passes = pool.passes.size() if is_instance_valid(pool) else 0
	phase.cache_entries = Cache.items.size()
	phase.cache_source_bytes = Cache.source_bytes
	if is_instance_valid(stage) and stage.viewport != null:
		phase.render_size = [stage.viewport.size.x,stage.viewport.size.y]
		phase.identities = stage.identities.duplicate()
		phase.preparation = stage.preparation_metrics.duplicate(true)
		phase.actor_response = _response_state()
		phase.response_size = [stage.material_response.viewport.size.x,stage.material_response.viewport.size.y] if stage.material_response.viewport != null else []
	report.phases.append(phase)
	_write(REPORT,JSON.stringify(report,"\t"))
func _noon() -> void:
	for pass_data: Dictionary in pool.passes:
		var light: Node = pass_data.arena.get_node("OutdoorLighting")
		light.set_process(false)
		light.apply_seconds(43200.0)
func _new_stage() -> void:
	stage = Stage.new()
	canvas.add_child(stage)
	stage.setup()
	stage.set_battle_context(&"grass", "wild")
func _response_state() -> Array:
	var state := []
	for index in 2:
		var actor: Node = stage.actors[index]
		state.append({"identity":stage.identities[index],"schema":actor.get_meta("pokeaether_material_response",0),
			"copy":stage.material_response.copies[index] != null})
	return state
func _response_ok() -> bool:
	var state := _response_state()
	print("ANDROID_BATTLE_BUDGET_RESPONSE ",JSON.stringify(state))
	for item: Dictionary in state:
		if int(item.schema)==1:
			if not _check(item.copy,"Response copy required by authored metadata: " + str(item.identity)):
				return false
			response_exercised = true
	if stage.material_response.viewport == null:
		return true # Original StandardMaterial actors use their normal light path.
	return _check(stage.material_response.sync_count > 0 and stage.material_response.viewport.size == DIMENSIONS,"Synchronized fixed-size irradiance pass")
func _prepare(name: String, shiny := false) -> bool:
	stage.set_combatant(0,name,shiny)
	await stage.await_prepared(true,60000)
	for frame in 3:
		await process_frame
	var key := Reviewed.key(name,shiny)
	return _check(stage.active and stage.handles("p1") and stage.handles("p2") and stage.arena_id == "forest" and not stage.forest_lease.is_empty(), "Full 3D forest: " + name + ": " + stage.reason) and _check(stage.identities[0] == key and stage.entries[key].runtime_sha256 == Reviewed.DATA.data.models[key].sha256, "Reviewed identity/hash: " + key) and _response_ok() and _check(stage.viewport.size == DIMENSIONS,"Fixed main raster size")
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(canvas.get_texture().get_image().save_png("user://android-battle-budget-" + name + ".png") == OK,"Capture: " + name)
func _run() -> void:
	OS.add_logger(sink)
	if not _check(OS.has_feature("android") and OS.has_feature("android_battle_budget") and OS.is_debug_build(), "Only the full battle debug diagnostic"):
		_finish()
		return
	service = root.get_node("OnDemand3DBundleService")
	settings = root.get_node("SettingsManager")
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.shader_cache = ProjectSettings.get_setting("rendering/shader_compiler/shader_cache/enabled",true)
	report.frame_pacing = ProjectSettings.get_setting("display/window/frame_pacing/android/enable_frame_pacing", true)
	if not _check(report.renderer == "mobile", "Mobile renderer required; no silent GLES fallback"):
		_finish()
		return
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "forest"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = false
	await _observe("autoloads")
	if not await _forest():
		_finish()
		return
	var mount_error := Catalog.prepare_forest(settings.battle_3d_forest_manifest)
	if not _check(mount_error.is_empty(),"Mount candidate: " + mount_error):
		_finish()
		return
	var deadline := Time.get_ticks_msec()+60000
	while not Catalog.forest_ready() and Catalog.forest_error.is_empty() and Time.get_ticks_msec()<deadline:
		await process_frame
	if not _check(Catalog.forest_ready(), "Forest resources loaded"):
		_finish()
		return
	RenderingServer.global_shader_parameter_set("wind_strength",0.0)
	RenderingServer.global_shader_parameter_set("wind_speed",0.0)
	await _observe("forest-resources")
	pool = Pool.prepare(root,settings.battle_3d_forest_manifest,DIMENSIONS,"forest")
	# Drive the existing builder in isolation to account for each unchanged pass.
	pool.set_process(false)
	pool._process(0.0)
	_noon()
	await _observe("arena-main")
	pool._process(0.0)
	_noon()
	await _observe("arena-response")
	pool.set_process(true)
	deadline = Time.get_ticks_msec()+60000
	while not pool.ready_for_battle and not pool.failed and Time.get_ticks_msec()<deadline:
		await process_frame
	if not _check(pool.ready_for_battle and pool.passes.size()==2,"Pooled production arena ready"):
		_finish()
		return
	await _observe("arena-suspended")
	canvas = SubViewport.new()
	canvas.size = DIMENSIONS
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var surface := TextureRect.new()
	surface.texture = canvas.get_texture()
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_new_stage()
	stage.set_combatant(1,"Dragonite")
	if not await _prepare("Bulbasaur"):
		_finish()
		return
	await _observe("battle-normal")
	await _capture("normal")
	if not await _prepare("Bulbasaur",true):
		_finish()
		return
	await _observe("battle-shiny")
	await _capture("shiny")
	stage.start_action("p1","physical_attack")
	_check(stage.current_actions[0]=="physical_attack","Attack clip selected")
	await stage.wait_action("p1")
	stage.set_sleeping(0,true)
	await _observe("battle-sleep")
	_check(stage.current_actions[0]=="sleep","Sleep clip maintained")
	await _capture("sleep")
	stage.set_sleeping(0,false)
	if not await _prepare("Charizard"):
		_finish()
		return
	_check(await stage.prepare_mega_form("p1","Charizard-Mega-X",false,30000),"Mega preloaded before reveal")
	if not await _prepare("Charizard-Mega-X"):
		_finish()
		return
	await _observe("battle-mega")
	stage.start_move_action("p1","Flamethrower")
	var effect: Node = stage.create_move_effect("Flamethrower","p1","p2",{})
	_check(effect != null,"Production 3D move effect instantiated")
	await _capture("effect")
	await _observe("battle-after-effect")
	if not await _prepare("Wailord"):
		_finish()
		return
	await _observe("battle-large")
	await _capture("large")
	stage.queue_free()
	await process_frame
	await process_frame
	stage = null
	await _observe("battle-released")
	_check(pool.borrower == null and pool.passes[0].viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and pool.passes[1].viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"Release suspends both retained passes")
	_new_stage()
	stage.set_combatant(1,"Dragonite")
	if not await _prepare("Wailord"):
		_finish()
		return
	await _observe("battle-reused")
	_check(stage.forest_pool == pool,"Next battle reuses same prepared environment")
	await _capture("reused")
	_check(response_exercised,"Authored two-pass Pokémon response exercised")
	_finish()
func _finish() -> void:
	report.failures = failures
	report.engine_errors = sink.errors
	report.success = failures.is_empty() and sink.errors.is_empty()
	if service != null:
		report.installed_model_bytes = service.downloaded_bytes()
		report.completed_downloads = service.completed_downloads
	_write(REPORT,JSON.stringify(report,"\t"))
	print("ANDROID_BATTLE_BUDGET_RESULT ",JSON.stringify(report))
	quit(0 if report.success else 1)
