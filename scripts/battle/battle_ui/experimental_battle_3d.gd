extends Control
## Desktop presentation: explicit combatants/actions/transitions from battle host.
## Missing reviewed models fall back as a whole battle; Substitute has a bundled 3D model.

const BallEffect = preload("res://scripts/battle/battle_ui/pokeball_effect_3d.gd")
var ball_effects: Array = [null, null, null, null]
var ball_restore: Array = [{}, {}, {}, {}]
var actor_transition_offsets := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
signal ball_cue(ident: String, key: String)

const SUPPORTED := ["dragonite", "roaring-moon"]
const MegaEvolutionEffect = preload("res://scripts/battle/battle_ui/mega_evolution_effect_3d.gd")
const MoveEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const SourceMoveEffect = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const ContactMoveEffect = preload("res://scripts/battle/battle_ui/contact_move_effect_3d.gd")
const ElectricMoveEffect = preload("res://scripts/battle/battle_ui/electric_move_effect_3d.gd")
const ThunderboltMoveEffect = preload("res://scripts/battle/battle_ui/thunderbolt_move_effect_3d.gd")
const FireStreamMoveEffect = preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd")
const BubbleMoveEffect = preload("res://scripts/battle/battle_ui/bubble_move_effect_3d.gd")
const IceBeamMoveEffect = preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd")
const MoveRecipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const FamilyMoveEffect = preload("res://scripts/battle/battle_ui/family_move_effect_3d.gd")
const DracoMeteorEffect = preload("res://scripts/battle/battle_ui/draco_meteor_effect_3d.gd")
const BatchFourMoveEffect = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
const LeafMoveEffect = preload("res://scripts/battle/battle_ui/leaf_move_effect_3d.gd")
const CommonBattleEffect = preload("res://scripts/battle/battle_ui/common_battle_effect_3d.gd")
var common_effects: Array[Node] = []
var move_command_holds := [false, false, false, false]
var move_dodges: Array[Dictionary] = [{}, {}, {}, {}]
var dodge_offsets := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var move_contacts: Array[Dictionary] = [{}, {}, {}, {}]
var contact_offsets := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var contact_yaws := [0.0, 0.0, 0.0, 0.0]
const StatusEffect = preload("res://scripts/battle/battle_ui/status_effect_3d.gd")
var status_conditions := ["", "", "", ""]
var status_effects: Array = [null, null, null, null]
const SubstituteModel = preload("res://scripts/battle/battle_ui/substitute_model_3d.gd")
var substitute_models: Array = [null, null, null, null]
var fallback_effect_bounds := {}
const ModelPlacement = preload("res://scripts/battle/battle_ui/model_placement.gd")
const ModelCache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const MoveAttachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const ReviewedModels = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
const AttackSelection = preload("res://scripts/battle/animations/model_attack_selection.gd")
const MotionPlacement = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
const MOTION_PROFILES = preload("res://scripts/battle/battle_ui/reviewed_motion_placement.json")
const MaterialResponse = preload("res://scripts/battle/battle_ui/material_response.gd")
const ArenaCatalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const ForestPool = preload("res://scripts/battle/arenas/shared/environment_pool.gd")
const COOP_TARGET_OUTLINE_SHADER := """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;
uniform vec4 outline_color : source_color = vec4(0.36, 0.97, 0.78, 1.0);
uniform float outline_width = 0.07;
void vertex() {
	float model_scale = (length(MODEL_MATRIX[0].xyz) + length(MODEL_MATRIX[1].xyz) + length(MODEL_MATRIX[2].xyz)) / 3.0;
	VERTEX += NORMAL * outline_width / max(model_scale, 0.001);
}
void fragment() {
	float pulse = 0.78 + 0.22 * sin(TIME * 4.0);
	ALBEDO = outline_color.rgb * pulse;
	EMISSION = outline_color.rgb * pulse;
}
"""
var forest_lease := {}
var forest_pool: Node
var user_camera_yaw := 0.0
var user_camera_pitch := 0.0
var user_camera_zoom := 1.0
var coop_camera_focus_enabled := false
var coop_camera_focus_index := -1
var coop_camera_focus_weight := 0.0
var coop_target_highlight_index := -1
var coop_target_highlight_actor: Node3D
var coop_target_original_overlays: Dictionary = {}
var coop_target_outline_material: ShaderMaterial
const USER_CAMERA_ZOOM_MIN := 0.72
const USER_CAMERA_ZOOM_MAX := 1.45

func reset_user_camera() -> void:
	user_camera_yaw = 0.0
	user_camera_pitch = 0.0
	user_camera_zoom = 1.0

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
var battle_kind := "trainer"
var arena_root: Node3D
var arena_problem := ""
var ground_offsets := {}
var placements := {}
var motion_clips := {}
var visual_bounds := {}
var motion_offsets := [0.0, 0.0, 0.0, 0.0]
var hover_offsets := [0.0, 0.0, 0.0, 0.0]
var arena_preparing := false
var entry_arena_requested := false
var entry_arena_visible := false
var material_response: Node
var boxes: Array = []
var platforms: Array = []
var viewport: SubViewport
var render_surface: TextureRect
var world: Node3D
var camera: Camera3D
var entries := {}
var catalog_entries := {}
var catalog_calibration := {}
var validated_entries := {}
var failed_models := {}
var packed := {}
var actors: Array = [null, null, null, null]
var players: Array = [null, null, null, null]
var staged_mega_species := ["", "", "", ""]
var mega_effects := [null, null, null, null]
var identities := ["", "", "", ""]
var restoring := ["idle", "idle", "idle", "idle"]
var loaded_path := "!unloaded"
var active := false
const WeatherEffect = preload("res://scripts/battle/battle_ui/weather_effect_3d.gd")
var weather_condition := ""
var weather_effect: Node3D
const TerrainEffect = preload("res://scripts/battle/battle_ui/terrain_effect_3d.gd")
var terrain_condition := ""
var trick_room_active := false
var terrain_effect: Node3D
var trick_room_effect: Node3D

func owns_field_effects() -> bool:
	return active and not _is_hybrid_presentation()

func set_terrain_condition(condition: String) -> void:
	terrain_condition = TerrainEffect.normalize(condition)
	_sync_field_effects()

func set_trick_room(enabled: bool) -> void:
	trick_room_active = enabled
	_sync_field_effects()

func _sync_field_effects() -> void:
	var enabled: bool = owns_field_effects() and get_tree().root.get_node("SettingsManager").terrain_effects and is_instance_valid(world)
	terrain_effect = _sync_field_effect(terrain_effect, terrain_condition if enabled else "")
	trick_room_effect = _sync_field_effect(trick_room_effect, "trickroom" if enabled and trick_room_active else "")

func _sync_field_effect(current: Node3D, key: String) -> Node3D:
	if is_instance_valid(current):
		if not key.is_empty() and current.key == key and current.get_parent() == world:
			return current
		current.cancel()
	if key.is_empty(): return null
	var effect := TerrainEffect.new()
	world.add_child(effect)
	var origin := ArenaCatalog.battle_origin(arena_id)
	if is_instance_valid(arena_root): origin.y = float(arena_root.get_meta("surface_height", 0.0))
	effect.start(key, origin, common_effect_speed)
	return effect

func owns_weather() -> bool:
	return active and not _is_hybrid_presentation()

func set_weather_condition(condition: String) -> void:
	weather_condition = WeatherEffect.normalize(condition)
	_sync_weather()

func _clear_weather() -> void:
	if is_instance_valid(weather_effect):
		weather_effect.cancel()
	weather_effect = null

func _sync_weather() -> void:
	var enabled: bool = owns_weather() and get_tree().root.get_node("SettingsManager").weather_effects and not weather_condition.is_empty()
	if not enabled or not is_instance_valid(world) or not is_instance_valid(camera):
		_clear_weather()
		return
	if is_instance_valid(weather_effect):
		if weather_effect.key == weather_condition and weather_effect.get_parent() == world:
			return
		_clear_weather()
	weather_effect = WeatherEffect.new()
	world.add_child(weather_effect)
	var origin := ArenaCatalog.battle_origin(arena_id)
	if is_instance_valid(arena_root): origin.y = float(arena_root.get_meta("surface_height", 0.0))
	weather_effect.start(weather_condition, world, camera, origin, common_effect_speed)

var saved_colors := {}
var reason := "2D selected"
var catalog_problem := ""
var current_actions := ["idle", "idle", "idle", "idle"]
var resting := [true, true, true, true]
var mode_label: Label
var pending_entries: Array = []
var import_times_ms := {}
var model_cache_hits := 0
var download_verified_files := {}
var verified_model_cache_hits := 0
var catalog_read_ms := 0.0
var model_validation_ms := 0.0
var arena_build_ms := 0.0
var actor_build_ms := 0.0
var loading_path := ""
var loading_entry := {}
var loading_started := 0
var integrity_read: IntegrityRead
var loading_scene: PackedScene

func _models_pending() -> bool:
	return not pending_entries.is_empty() or not loading_entry.is_empty() or not loading_path.is_empty()

class IntegrityRead extends RefCounted:
	var task := -1
	var path: String
	var digest := ""
	var bytes := 0
	var elapsed_ms := 0.0
	func start(source: String) -> void:
		path = source
		task = WorkerThreadPool.add_task(_read)
	func _read() -> void:
		var started := Time.get_ticks_usec()
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			bytes = file.get_length()
			if bytes <= 134217728:
				digest = FileAccess.get_sha256(path)
		elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0
	func ready() -> bool:
		if task < 0:
			return true
		if not WorkerThreadPool.is_task_completed(task):
			return false
		WorkerThreadPool.wait_for_task_completion(task) # Completed only: never joins pending I/O.
		task = -1
		return true

class IntegrityDrain extends Node:
	var job: IntegrityRead
	func _process(_delta: float) -> void:
		if job.ready():
			queue_free()

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
	if integrity_read != null:
		var drain := IntegrityDrain.new()
		drain.job = integrity_read
		get_tree().root.add_child.call_deferred(drain)
		integrity_read = null
	if not loading_path.is_empty():
		# ResourceLoader has no cancellation API. Drain without joining/blocking.
		if loading_scene == null:
			var drain := LoadDrain.new()
			drain.path = loading_path
			get_tree().root.add_child.call_deferred(drain)
		loading_path = ""
	loading_entry.clear()
	loading_scene = null

var preparation_cancelled := false
var preparation_failed := false
var warming_render := false
var preparation_phase := "Loading model catalog"
var preparation_metrics := {}
var model_downloader: Node
signal preparation_stopped

class ModelDownloadRequest extends Node:
	signal completed
	var finished := false
	var result: Dictionary = {}
	func run(service: Node, needed: Array[String], catalog_path: String) -> void:
		# A shared download can outlive the battle that requested it. Keep its
		# completion outside the scene so leaving cannot resume a freed presenter.
		result = await service.ensure_models(needed, catalog_path)
		finished = true
		completed.emit()
		queue_free()

class ModelDownloadCompletion extends RefCounted:
	signal completed
	func finish() -> void:
		completed.emit()

func _preparation_progress() -> Array:
	var progress: Array = []
	if not loading_path.is_empty() and loading_scene == null:
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
	entry_arena_requested = false
	entry_arena_visible = false
	_cancel_load()
	pending_entries.clear()
	preparation_stopped.emit()


func begin_entry_arena() -> void:
	# The host may show the empty desktop arena before the response/models.
	# This never claims a combatant is ready and never exposes sprite placeholders.
	entry_arena_requested = true
	if is_instance_valid(mode_label):
		mode_label.hide()
	_set_active(active)


func finish_entry_arena() -> void:
	entry_arena_requested = false
	entry_arena_visible = false
	_set_active(active and not preparation_failed and not preparation_cancelled)

func _blocking_pipelines() -> Array:
	# Specialization compiles in the background and is not a blocking gate.
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]

func battle_download_progress() -> Dictionary:
	if not is_instance_valid(model_downloader) or not model_downloader.has_method("battle_download_progress"):
		return {}
	return model_downloader.battle_download_progress()


func await_prepared(render_under_cover := false, timeout_ms := 10000) -> void:
	# Only the opaque screen host may temporarily expose hidden summon actors.
	# Reuse these exact viewports/materials after reveal; do not rebuild them.
	if render_under_cover:
		warming_render = true
	await _ensure_downloaded_models()
	if preparation_cancelled or preparation_failed or not is_inside_tree():
		warming_render = false
		return
	var deadline := Time.get_ticks_msec() + timeout_ms
	var started := Time.get_ticks_msec()
	var hard_deadline := started + maxi(timeout_ms,120000)
	var last_progress: Array = []
	var last_sample: Array = []
	var quiet_frames := 0
	var last_draw := -1
	var pipeline_start := _blocking_pipelines()
	var warm_started := 0
	var warm_max_frame_ms := 0.0
	var frame_tick := Time.get_ticks_usec()
	_queue_needed_models()
	while is_inside_tree():
		var now := Time.get_ticks_usec()
		if active and not _models_pending() and _actors_resolved():
			if warm_started == 0:
				warm_started = now
			else:
				warm_max_frame_ms = maxf(warm_max_frame_ms, (now - frame_tick) / 1000.0)
		frame_tick = now
		var progress := _preparation_progress()
		if progress != last_progress and timeout_ms > 0:
			deadline = Time.get_ticks_msec() + timeout_ms
			last_progress = progress.duplicate(true)
		preparation_metrics = {"elapsed_ms":Time.get_ticks_msec()-started,"phase":preparation_phase,"forest_load_ms":ArenaCatalog.forest_load_ms,
			"model_cache_hits": model_cache_hits, "catalog_read_ms": catalog_read_ms, "model_validation_ms": model_validation_ms,
			"arena_build_ms": arena_build_ms, "actor_build_ms": actor_build_ms, "model_import_ms": import_times_ms.duplicate()}
		var pipeline_delta := _blocking_pipelines()
		for index in pipeline_delta.size():
			pipeline_delta[index] -= pipeline_start[index]
		preparation_metrics["blocking_pipeline_delta"] = pipeline_delta
		preparation_metrics["render_warm_ms"] = (now - warm_started) / 1000.0 if warm_started > 0 else 0.0
		preparation_metrics["render_warm_max_frame_ms"] = warm_max_frame_ms
		if preparation_cancelled or preparation_failed:
			warming_render = false
			return
		var settings := get_tree().root.get_node("SettingsManager")
		if settings.battle_presentation_mode not in ["2.5d", "3d"] or OS.has_feature("web") or OS.has_feature("mobile"):
			warming_render = false
			return
		var requested: String = settings.get_battle_3d_catalog_path()
		if requested.is_empty():
			requested = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
		if loaded_path == requested and not _models_pending() and not arena_preparing:
			if not render_under_cover and not warming_render:
				await get_tree().process_frame
				await get_tree().process_frame
				if not _models_pending() and _actors_resolved():
					return
			if render_under_cover:
				var has_combatants := false
				for index in _slot_count():
					has_combatants = has_combatants or not combatants[index].species.is_empty()
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
					var required_frames := 2 if _reuses_rendered_models() else 5
					if quiet_frames >= required_frames:
						if DisplayServer.get_name() != "headless":
							for identity: String in identities:
								var entry: Dictionary = entries.get(identity, {})
								ModelCache.mark_rendered(str(entry.get("_resource_cache_key", "")), _render_reuse_key())
						preparation_metrics["warm_reuse"] = required_frames == 2
						preparation_metrics["verified_model_cache_hits"] = verified_model_cache_hits
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


func _reuses_rendered_models() -> bool:
	# A pooled arena and these exact resources have already drawn together.
	# New models, new viewports, evictions and a changed render size stay cold.
	if forest_lease.is_empty() or viewport == null or not _actors_resolved():
		return false
	var needed := _needed_species()
	if needed.is_empty():
		return false
	for identity in needed:
		var key := str(entries.get(identity, {}).get("_resource_cache_key", ""))
		if key.is_empty() or not ModelCache.was_rendered(key, _render_reuse_key()):
			return false
	return true


func _render_reuse_key() -> String:
	return "%s:%s:%s" % [viewport.get_instance_id(), viewport.size, viewport.msaa_3d]


func _ensure_downloaded_models(preserve_actors := false) -> void:
	download_verified_files.clear()
	if OS.has_feature("web") or OS.has_feature("mobile") or OS.has_environment("POKEAETHER_3D_STAGE_REPORT"):
		return
	var settings := get_tree().root.get_node("SettingsManager")
	if settings.battle_presentation_mode not in ["2.5d", "3d"] or settings.has_manual_battle_3d_catalog_selection():
		return
	if not settings.battle_3d_catalog_path.is_empty() and not OS.has_environment("POKEAETHER_MODEL_CATALOG"):
		return
	while is_instance_valid(model_downloader):
		await get_tree().process_frame
	var needed: Array[String] = []
	for index in _slot_count():
		var box: Node = boxes[index] if index < boxes.size() else null
		if box != null and (box.double_container.visible and not double_mode):
			return
		if str(combatants[index].species).is_empty():
			continue
		if not _supports_combatant(combatants[index].species, combatants[index].shiny, double_mode, false):
			return
		var identity := _combatant_key(index)
		if not identity.is_empty() and identity not in needed:
			needed.append(identity)
	for identity in _anticipated_form_keys():
		if identity not in needed:
			needed.append(identity)
	for identity: String in staged_mega_species:
		if not identity.is_empty() and identity not in needed:
			needed.append(identity)
	if needed.is_empty():
		return
	model_downloader = get_tree().root.get_node("OnDemand3DBundleService")
	preparation_phase = "Checking approved 3D models…"
	var old_path: String = settings.get_battle_3d_catalog_path()
	var request := ModelDownloadRequest.new()
	model_downloader.add_child(request)
	request.run(model_downloader, needed, old_path)
	if not request.finished:
		var completion := ModelDownloadCompletion.new()
		request.completed.connect(completion.finish, CONNECT_ONE_SHOT)
		preparation_stopped.connect(completion.finish, CONNECT_ONE_SHOT)
		await completion.completed
		if preparation_stopped.is_connected(completion.finish):
			preparation_stopped.disconnect(completion.finish)
		if request.completed.is_connected(completion.finish):
			request.completed.disconnect(completion.finish)
	var result := request.result
	model_downloader = null
	if preparation_cancelled or not is_inside_tree():
		return
	if not str(result.get("error", "")).is_empty():
		preparation_failed = true
		reason = str(result.error)
		return
	var new_path := str(result.get("path", ""))
	var refresh_catalog: bool = bool(result.get("catalog_changed", false))
	for identity in needed:
		refresh_catalog = refresh_catalog or not catalog_entries.has(identity)
	if not new_path.is_empty() and (new_path != old_path or refresh_catalog):
		OS.set_environment("POKEAETHER_MODEL_CATALOG", new_path)
		_load_catalog(new_path, preserve_actors)
	# Ephemeral full-SHA results from this entry only; catalogs cannot supply them.
	download_verified_files = result.get("verified_models", {}).duplicate(true)
var action_generation := [0, 0, 0, 0]
var camera_phase := 0.0
var combatants := [{"species": "", "shiny": false}, {"species": "", "shiny": false},
	{"species": "", "shiny": false}, {"species": "", "shiny": false}]
var actor_shown := [true, true, true, true]
var actor_scale := [1.0, 1.0, 1.0, 1.0]
var transition_generation := [0, 0, 0, 0]
var lifecycle := ["empty", "empty", "empty", "empty"]
var double_mode := false
var playback_speed := 1.0
var move_categories := {}
const CAMERA_HOME := Vector3(4, 5.5, 12)

func _slot_count() -> int:
	return 4 if double_mode else 2

func set_double_mode(enabled: bool) -> void:
	if double_mode == enabled:
		return
	set_coop_target_highlight("")
	coop_camera_focus_enabled = false
	coop_camera_focus_index = -1
	coop_camera_focus_weight = 0.0
	_set_active(false)
	if viewport != null:
		_clear_actors()
		material_response._drop()
		render_surface.texture = null
		if forest_lease.is_empty():
			viewport.queue_free()
		else:
			_release_forest()
		viewport = null
		world = null
		camera = null
		arena_root = null
	double_mode = enabled
	for index in 4:
		set_combatant(index, "", false, true)

func attack_action_for(move_name: String, actor: String = "") -> String:
	if move_categories.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_summary_index.json"))
		if parsed is Dictionary:
			move_categories = parsed
	var key := AttackSelection.move_key(move_name)
	var index := actor_index(actor)
	if MoveRecipes.supports(move_name):
		if not MoveRecipes.contact(move_name): return "special_attack"
		if MoveRecipes.get_recipe(move_name).family == "z": return "physical_attack"
	# Projectile motion uses a release clip even for physical damage moves.
	if MoveEffect.move_key(move_name)=="dracometeor" or MoveEffect.move_key(move_name) in BatchFourMoveEffect.MOVE_KEYS: return "special_attack"
	if key in ["razorleaf", "razor-leaf"]: return "special_attack"
	if key in ["quickattack", "quick-attack"]: return "physical_attack"
	if key in ["ember", "flamethrower"] and index >= 0 and index < identities.size() and identities[index].trim_suffix("@shiny") == "charmander":
		if entries.get(identities[index], {}).get("action_timing", {}).has("special_attack_2"):
			return "special_attack_2"
	if str(move_categories.get(key, {}).get("category", "")).to_lower() != "physical":
		return "special_attack"
	var family_actions := {}
	if index >= 0 and index < identities.size() and entries.has(identities[index]):
		family_actions = entries[identities[index]].get("attack_family_actions", {})
	return AttackSelection.request_for(key, family_actions)

func set_combatant(index: int, species: String, shiny := false, force := false) -> void:
	var normalized := species.to_lower().replace(" ", "-")
	if not force and combatants[index].species == normalized and combatants[index].shiny == shiny:
		return
	action_generation[index] += 1
	if force or species.is_empty():
		status_conditions[index] = ""
	staged_mega_species[index] = ""
	_stop_transition(index)
	combatants[index] = {"species": normalized, "shiny": shiny}
	actor_shown[index] = true
	actor_scale[index] = 1.0
	motion_offsets[index] = 0.0
	restoring[index] = "idle"
	lifecycle[index] = "empty" if normalized.is_empty() else "idle"
	if is_instance_valid(actors[index]) and identities[index] != _combatant_key(index):
		actors[index].visible = false
	_queue_needed_models()
	if active and identities[index] == _combatant_key(index) and players[index] != null:
		_action("reset", index)

func actor_index(ident: String) -> int:
	for index in _slot_count():
		if ident.begins_with("p" + str(index + 1)):
			return index
	return -1


func set_coop_camera_focus(controller: String, enabled: bool) -> void:
	var index := actor_index(controller)
	coop_camera_focus_enabled = double_mode and enabled and index in [0, 2]
	if coop_camera_focus_enabled:
		coop_camera_focus_index = index


func handles(ident: String) -> bool:
	var index := actor_index(ident)
	return active and index >= 0 and identities[index] == _combatant_key(index) and is_instance_valid(actors[index])


func set_coop_target_highlight(controller: String) -> void:
	var index := actor_index(controller)
	coop_target_highlight_index = index if double_mode and index >= 0 else -1
	_sync_coop_target_highlight()


func _clear_coop_target_highlight() -> void:
	for mesh: MeshInstance3D in coop_target_original_overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = coop_target_original_overlays[mesh]
	coop_target_original_overlays.clear()
	coop_target_highlight_actor = null


func _sync_coop_target_highlight() -> void:
	var desired_actor: Node3D
	if coop_target_highlight_index >= 0 and handles("p%d" % (coop_target_highlight_index + 1)):
		desired_actor = actors[coop_target_highlight_index] as Node3D
	if desired_actor == coop_target_highlight_actor:
		return
	_clear_coop_target_highlight()
	if desired_actor == null:
		return
	if coop_target_outline_material == null:
		var shader := Shader.new()
		shader.code = COOP_TARGET_OUTLINE_SHADER
		coop_target_outline_material = ShaderMaterial.new()
		coop_target_outline_material.shader = shader
	coop_target_highlight_actor = desired_actor
	var meshes: Array[Node] = desired_actor.find_children("*", "MeshInstance3D", true, false)
	if desired_actor is MeshInstance3D:
		meshes.append(desired_actor)
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		coop_target_original_overlays[mesh] = mesh.material_overlay
		var outline := coop_target_outline_material.duplicate()
		outline.next_pass = mesh.material_overlay
		mesh.material_overlay = outline

func _combatant_key(index: int) -> String:
	return ReviewedModels.key(combatants[index].species, combatants[index].shiny)

func set_sleeping(index: int, sleeping: bool) -> void:
	if lifecycle[index] == "fainted":
		return
	var desired := "sleep" if sleeping else "idle"
	if restoring[index] == desired:
		return
	restoring[index] = desired
	if active and players[index] != null and resting[index]:
		_action("reset", index)

func cancel_actions() -> void:
	for doll: Node in substitute_models:
		if is_instance_valid(doll): doll.cancel_motion()
	_cancel_common_effects()
	for index in _slot_count():
		staged_mega_species[index] = ""
		if is_instance_valid(mega_effects[index]):
			mega_effects[index].cancel()
		mega_effects[index] = null
		_stop_transition(index)
		actor_scale[index] = 1.0
		actor_shown[index] = not combatants[index].species.is_empty()
		lifecycle[index] = "idle" if actor_shown[index] else "empty"
		_action("reset", index)

func _cancel_common_effects() -> void:
	for index in 4:
		_clear_move_dodge(index)
		_clear_move_contact(index)
		move_command_holds[index] = false
	for effect: Node in common_effects.duplicate():
		if is_instance_valid(effect):
			effect.cancel()
	common_effects.clear()

func _substitute_box(index: int) -> Node:
	return boxes[index] if index >= 0 and index < boxes.size() else null

func _substitute_visible(index: int) -> bool:
	var box := _substitute_box(index)
	return box != null and box.substitute_active and not box.substitute_revealed_for_move

func _clear_substitute_models() -> void:
	for index in 4:
		if is_instance_valid(substitute_models[index]):
			substitute_models[index].queue_free()
		substitute_models[index] = null

func _sync_substitute_models() -> void:
	for index in _slot_count():
		var box := _substitute_box(index)
		var needed: bool = active and is_instance_valid(world) and handles("p%d" % (index+1)) and box != null and box.substitute_active
		if not needed:
			if is_instance_valid(substitute_models[index]): substitute_models[index].queue_free()
			substitute_models[index] = null
			continue
		if not is_instance_valid(substitute_models[index]):
			var doll := SubstituteModel.new()
			world.add_child(doll)
			doll.build(_effect_bounds(index).height, common_effect_speed)
			substitute_models[index] = doll
		var doll: Node3D = substitute_models[index]
		doll.position = _position(index) + dodge_offsets[index] + contact_offsets[index]
		var facing_origin: Vector3 = _position(index) if not move_contacts[index].is_empty() else doll.position
		var direction := _position(index + 1 if index % 2 == 0 else index - 1) - facing_origin
		doll.rotation.y = atan2(direction.x,direction.z) + contact_yaws[index]
		doll.visible = _substitute_visible(index) and actor_shown[index] and lifecycle[index] not in ["fainted", "hidden", "empty", "send_out", "recall", "capture"]
		actors[index].visible = actor_shown[index] and not doll.visible

func set_substitute_active(ident: String, enabled: bool) -> void:
	var index := actor_index(ident)
	var box := _substitute_box(index)
	if box == null: return
	box.set_substitute_active(enabled,false)
	if not enabled and handles(ident): actors[index].visible = actor_shown[index]
	_sync_substitute_models()
	_sync_status_effects()

func reveal_substitute_pokemon(ident: String, revealed: bool) -> bool:
	var index := actor_index(ident)
	var box := _substitute_box(index)
	if box == null or not box.substitute_active or not handles(ident): return false
	box.substitute_revealed_for_move = revealed
	_sync_substitute_models()
	_sync_status_effects()
	return true

func play_substitute_hit(ident: String) -> void:
	var index := actor_index(ident)
	if index < 0: return
	_sync_substitute_models()
	var doll: Node = substitute_models[index]
	if not is_instance_valid(doll): return
	doll.hit()
	while active and is_instance_valid(doll) and doll.hit_left > 0.0:
		await get_tree().process_frame

func set_status_condition(index: int, condition: String) -> void:
	if index < 0 or index >= 4:
		return
	status_conditions[index] = preload("res://scripts/battle/animations/status_condition_overlay.gd")._normalize_condition(condition)
	set_sleeping(index, status_conditions[index] == "sleeping")
	_sync_status_effects()

func _effect_bounds(index: int) -> Dictionary:
	var actor: Node3D = actors[index]
	var result := {"position": world.to_local(actor.global_position), "height": 2.0, "radius": 1.0}
	var bounds: Dictionary = visual_bounds.get(identities[index], {}).get("idle", {})
	var box: AABB
	if not bounds.is_empty():
		box = AABB(Vector3(bounds.min[0],bounds.min[1],bounds.min[2]),Vector3(bounds.size[0],bounds.size[1],bounds.size[2]))
	else:
		# Older approved cohorts have grounding but no sampled idle bounds.
		# Derive their mesh envelope once, in model units, then apply live scale.
		var identity: String = identities[index]
		if not fallback_effect_bounds.has(identity):
			var meshes := actor.find_children("*", "MeshInstance3D", true, false)
			if actor is MeshInstance3D: meshes.append(actor)
			for mesh: MeshInstance3D in meshes:
				if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
				var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
				if posed == null: posed = mesh.mesh
				var mesh_box: AABB = (actor.global_transform.affine_inverse() * mesh.global_transform) * posed.get_aabb()
				box = box.merge(mesh_box) if box.has_volume() else mesh_box
			fallback_effect_bounds[identity] = box
		box = fallback_effect_bounds[identity]
	if box.has_volume():
		var local_box: AABB = (world.global_transform.affine_inverse() * actor.global_transform) * box
		result.position = local_box.position + Vector3(local_box.size.x * 0.5,0,local_box.size.z * 0.5)
		result.height = local_box.size.y
		result.radius = maxf(local_box.size.x, local_box.size.z) * 0.55
		result["half_extents"] = local_box.size * 0.5
	return result

func _clear_status_effects() -> void:
	_clear_coop_target_highlight()
	for index in 4:
		if is_instance_valid(status_effects[index]):
			status_effects[index].cancel()
		status_effects[index] = null

func _sync_status_effects() -> void:
	for index in _slot_count():
		var ident := "p%d" % (index + 1)
		var actor: Node3D = actors[index]
		var enabled: bool = active and is_instance_valid(world) and handles(ident) and actor.visible and actor_shown[index] and lifecycle[index] not in ["fainted", "hidden", "empty", "send_out", "recall", "capture"] and get_tree().root.get_node("SettingsManager").battle_animations
		var key := "status_" + str(status_conditions[index]) if enabled and not status_conditions[index].is_empty() else ""
		var effect: Node = status_effects[index]
		if is_instance_valid(effect) and (effect.done or effect.key != key or effect.actor != actor):
			_clear_coop_target_highlight()
			effect.cancel()
			status_effects[index] = null
			effect = null
		if not key.is_empty() and not is_instance_valid(effect):
			_clear_coop_target_highlight()
			effect = StatusEffect.new()
			world.add_child(effect)
			var bounds := _effect_bounds(index)
			effect.position = bounds.position
			effect.view_camera = camera
			effect.start(key, bounds.height, bounds.radius, func(): return active and handles(ident) and actors[index] == actor and actor.visible and actor_shown[index], common_effect_speed)
			effect.attach_model(actor)
			status_effects[index] = effect
		if is_instance_valid(effect):
			effect.position = _effect_bounds(index).position
	_sync_coop_target_highlight()

func common_effect_speed() -> float:
	return playback_speed

func create_common_effect(key: String, ident: String) -> Node:
	if not active or not is_instance_valid(world) or not CommonBattleEffect.supports(key):
		return null
	var effect := CommonBattleEffect.new()
	var body_height := 2.0
	var body_radius := 1.0
	var anchor := Vector3.ZERO
	var guard: Callable
	if key == "grassy_terrain_start":
		var count := 0
		for slot in _slot_count():
			if handles("p%d" % (slot + 1)):
				anchor += _position(slot)
				count += 1
		if count == 0:
			effect.free()
			return null
		anchor /= count
		guard = func(): return active and is_instance_valid(world)
	else:
		if not handles(ident):
			effect.free()
			return null
		var index := actor_index(ident)
		var actor: Node3D = actors[index]
		var visual: Node3D = substitute_models[index] if is_instance_valid(substitute_models[index]) and substitute_models[index].visible else actor
		if not visual.visible or not actor_shown[index] or lifecycle[index] in ["hidden", "empty", "fainted"]:
			effect.free()
			return null
		var bounds := _effect_bounds(index)
		if visual != actor:
			bounds = {"position": world.to_local(visual.global_position), "height": visual.idle_scale * 1.2, "radius": visual.idle_scale * 0.6}
		anchor = bounds.position
		body_height = bounds.height
		body_radius = bounds.radius
		guard = func(): return active and handles(ident) and actors[index] == actor and is_instance_valid(visual) and visual.visible and actor_shown[index] and lifecycle[index] not in ["hidden", "empty", "fainted"]
	if key == "mega_evolution":
		guard = func(): return active and is_instance_valid(world)
	world.add_child(effect)
	effect.view_camera = camera
	effect.position = anchor
	if is_instance_valid(camera):
		var toward_camera: Vector3 = world.to_local(camera.global_position) - anchor
		effect.front = Vector3(toward_camera.x,0,toward_camera.z).normalized()
	common_effects.append(effect)
	effect.tree_exiting.connect(func(): common_effects.erase(effect), CONNECT_ONE_SHOT)
	effect.start(key, body_height, body_radius, guard, common_effect_speed)
	return effect

func hold_move_command(ident: String, held: bool) -> void:
	if not handles(ident): return
	var index := actor_index(ident)
	move_command_holds[index] = held
	if is_instance_valid(players[index]): players[index].speed_scale = 0.0 if held else playback_speed

func start_move_dodge(actor: String, target: String, move: String) -> void:
	var source := _move_visual(actor)
	var destination := _move_visual(target)
	if source == null or destination == null or actor_index(actor) == actor_index(target): return
	var source_index := actor_index(actor)
	var index := actor_index(target)
	if not is_instance_valid(players[source_index]): return
	var clock := bind_action_clock(actor)
	if not clock.is_valid(): return
	_clear_move_dodge(index)
	var duration: float = players[source_index].current_animation_length
	if duration <= 0.0: return
	var timing := move_timing(move, actor)
	var impact := clampf(float(timing.get("impact_frame", duration * 60.0 * 0.45)) / 60.0, duration * 0.2, duration * 0.65)
	var bounds := _move_bounds(target)
	var forward: Vector3 = bounds.position - _move_bounds(actor).position
	forward.y = 0
	if forward.length_squared() < 0.001: forward = Vector3.FORWARD
	var side := Vector3.UP.cross(forward.normalized())
	var distance := clampf(float(bounds.radius) * 1.4 + 0.35, 0.8, 2.4)
	move_dodges[index] = {"source": source, "target": destination, "actor": actor, "target_ident": target,
		"clock": clock, "duration": duration, "impact": impact, "displacement": side * distance,
		"hop": minf(float(bounds.height) * 0.08, 0.16)}

func _set_dodge_offset(index: int, offset: Vector3) -> void:
	var change: Vector3 = offset - dodge_offsets[index]
	dodge_offsets[index] = offset
	# Apply immediately too: cancellation restores the pose even while paused.
	if is_instance_valid(actors[index]): actors[index].position += change
	if is_instance_valid(substitute_models[index]): substitute_models[index].position += change

func _clear_move_dodge(index: int) -> void:
	_set_dodge_offset(index, Vector3.ZERO)
	move_dodges[index] = {}

func _update_move_dodges() -> void:
	for index in 4:
		var dodge: Dictionary = move_dodges[index]
		if dodge.is_empty(): continue
		if not active or _move_visual(dodge.actor) != dodge.source or _move_visual(dodge.target_ident) != dodge.target:
			_clear_move_dodge(index)
			continue
		var seconds: float = dodge.clock.call()
		var duration: float = dodge.duration
		if seconds >= duration - 0.00001:
			_clear_move_dodge(index)
			continue
		# Snap aside before contact, hold until the beam/tail passes, then return.
		# Native-clock sampling makes pause and playback speed match the move.
		var out_start := maxf(0, float(dodge.impact) - duration * 0.2)
		var out_phase := clampf((seconds - out_start) / (duration * 0.16), 0, 1)
		var return_start := minf(maxf(float(dodge.impact) + duration * 0.3, duration * 0.7), duration * 0.82)
		var return_phase := clampf((seconds - return_start) / (duration * 0.18), 0, 1)
		var weight := (1.0 - pow(1.0 - out_phase, 3)) * (1.0 - smoothstep(0, 1, return_phase))
		var hop := sin(out_phase * PI) if return_phase <= 0 else sin(return_phase * PI) * 0.5
		_set_dodge_offset(index, dodge.displacement * weight + Vector3.UP * hop * float(dodge.hop))

func wait_move_dodge(target: String) -> void:
	var index := actor_index(target)
	if index < 0: return
	while is_inside_tree() and active and not move_dodges[index].is_empty():
		_update_move_dodges()
		if not move_dodges[index].is_empty(): await get_tree().process_frame

func _start_move_contact(actor: String, target: String, timing: Dictionary, effect: Node) -> void:
	var index := actor_index(actor)
	if index < 0 or index == actor_index(target): return
	_clear_move_contact(index)
	var a := _move_bounds(actor)
	var b := _move_bounds(target)
	var delta: Vector3 = b.position - a.position
	delta.y = 0
	var distance := delta.length()
	if distance < 0.01: return
	# Bound the approach by both bodies: a large model must not pass through a small one.
	var clearance := maxf(0.25, float(a.radius) + float(b.radius) + 0.08)
	var displacement := delta.normalized() * maxf(0.0, distance - clearance)
	var source := _move_visual(actor)
	var destination := _move_visual(target)
	var partner: Vector3 = _position(index + 1 if index % 2 == 0 else index - 1) - _position(index)
	var turn := wrapf(atan2(delta.x, delta.z) - atan2(partner.x, partner.z), -PI, PI)
	var motion := {"source":source, "target":destination, "actor":actor, "target_ident":target,
		"clock":bind_action_clock(actor), "duration":float(timing.frames)/60.0,
		"quick": str(timing.get("move_key", "")) == "quickattack",
		"impact":float(timing.impact_frame)/60.0, "displacement":displacement, "yaw":turn,
		"nodes":[actors[index], substitute_models[index]], "hud_transform":actors[index].global_transform}
	if source != actors[index] and source.get("body") is Node3D:
		motion.hud_sub_transform = source.body.global_transform
	move_contacts[index] = motion
	effect.finished.connect(func():
		if move_contacts[index] == motion: _clear_move_contact(index), CONNECT_ONE_SHOT)

func _set_contact_pose(index: int, offset: Vector3, yaw: float) -> void:
	var change: Vector3 = offset - contact_offsets[index]
	var turn: float = yaw - contact_yaws[index]
	contact_offsets[index] = offset
	contact_yaws[index] = yaw
	# Immediate restoration also works during pause/cancel, without waiting for a frame.
	for node in move_contacts[index].get("nodes", [actors[index], substitute_models[index]]):
		if is_instance_valid(node):
			node.position += change
			node.rotation.y += turn

func _clear_move_contact(index: int) -> void:
	_set_contact_pose(index, Vector3.ZERO, 0.0)
	move_contacts[index] = {}

func _update_move_contacts() -> void:
	for index in 4:
		var motion: Dictionary = move_contacts[index]
		if motion.is_empty(): continue
		if not active or _move_visual(motion.actor) != motion.source or _move_visual(motion.target_ident) != motion.target:
			_clear_move_contact(index)
			continue
		var seconds: float = motion.clock.call()
		var duration: float = motion.duration
		if seconds >= duration - 0.00001:
			_clear_move_contact(index)
			continue
		var approach_start := minf(duration * 0.08, float(motion.impact) * 0.15)
		if motion.get("quick",false): approach_start = float(motion.impact)*0.4
		var contact_time := float(motion.impact) * 0.96
		var outward := smoothstep(approach_start, contact_time, seconds)
		var return_start := minf(float(motion.impact) + duration * 0.08, duration * 0.72)
		var returning := smoothstep(return_start, duration * 0.94, seconds)
		var weight := outward * (1.0 - returning)
		_set_contact_pose(index, motion.displacement * weight, float(motion.yaw) * weight)

func _fixed_target_move_anchors(actor: String, target: String, move: String, point: Vector3, radius: float, ground: Variant = null) -> Dictionary:
	var anchors := _move_anchors(actor, target, move)
	anchors.target = point
	anchors.radius = radius
	if ground is Vector3: anchors["target_ground"] = ground
	return anchors

func can_present_move(move: String) -> bool:
	return active and is_instance_valid(world) and MoveEffect.supports(move)

func _move_visual(ident: String) -> Node3D:
	if not handles(ident): return null
	var index := actor_index(ident)
	if not actor_shown[index] or lifecycle[index] in ["hidden", "empty", "fainted"]: return null
	var doll: Node3D = substitute_models[index]
	var visual: Node3D = doll if is_instance_valid(doll) and doll.visible else actors[index]
	return visual if is_instance_valid(visual) and visual.visible else null

func _move_bounds(ident: String) -> Dictionary:
	var index := actor_index(ident)
	var visual := _move_visual(ident)
	if visual != actors[index]:
		return {"position": world.to_local(visual.global_position), "height": visual.idle_scale * 1.2, "radius": visual.idle_scale * 0.6}
	return _effect_bounds(index)

func _move_anchors(actor: String, target: String, move: String) -> Dictionary:
	var recipe := MoveRecipes.get_recipe(move)
	var a := _move_bounds(actor)
	var b := _move_bounds(target)
	var source_height := 0.82 if MoveEffect.move_key(move) in ["ember", "watergun", "flamethrower", "bubble", "bubblebeam", "icebeam", "shadowball", "sludgebomb", "poisonsting", "flashcannon", "waterpulse", "dracometeor"] else 0.6
	if recipe.get("attachment", "") == "mouth": source_height = 0.82
	var source: Vector3 = a.position + Vector3.UP * a.height * source_height
	var end: Vector3 = b.position + Vector3.UP * b.height * 0.55
	var direction := (end-source).normalized()
	source += direction * minf(a.radius * 0.55, (end-source).length()*0.15)
	end -= direction * minf(b.radius * 0.5, (end-source).length()*0.15)
	if MoveEffect.move_key(move) in ["moonblast","dracometeor"]:
		# Reserve space for the fully grown orb, not just its centre. Charge and
		# flight share this point, while the moon stays above the attacker.
		var moon_source := source
		var forward := Vector3(direction.x,0,direction.z).normalized()
		var orb_radius: float = (DracoMeteorEffect.CHARGE_RADIUS if MoveEffect.move_key(move)=="dracometeor" else BatchFourMoveEffect.MOONBLAST_ORB_RADIUS) * MoveEffect.PRESENTATION_SCALES[MoveEffect.move_key(move)]
		var body_extent := forward.abs().dot(a.get("half_extents",Vector3(a.radius,0,a.radius)))
		source = a.position + Vector3.UP * a.height * source_height + forward * (body_extent + orb_radius + 0.15)
		return {"source":source,"sources":[source],"target":end,"radius":b.radius,
			"moon_source":moon_source,"target_ground":Vector3(end.x,_position(actor_index(target)).y+0.04,end.z),
			"attachment_part":"bounds","attachment_bones":[]}
	if not recipe.is_empty() and not bool(recipe.contact):
		# Unprofiled body emitters reserve room for the projectile, including its
		# full visual radius; the orb must not grow through the attacker.
		var forward := Vector3(direction.x,0,direction.z).normalized()
		var extent := forward.abs().dot(a.get("half_extents",Vector3(a.radius,0,a.radius)))
		var clearance := 0.3 * float(recipe.scale) if recipe.family in ["projectiles","z"] else 0.12
		source = a.position + Vector3.UP*a.height*source_height + forward*(extent+clearance)
	var attachment := {}
	var index := actor_index(actor)
	# A visible Substitute owns the emitter; never emit from the hidden Pokémon.
	if _move_visual(actor) == actors[index]:
		attachment = MoveAttachments.sample(actors[index], identities[index], MoveEffect.move_key(move), world)
	var sources: Array = attachment.get("sources", [source])
	return {"source": sources[0], "sources": sources, "target": end, "radius": b.radius,
		"attachment_part": attachment.get("part", "bounds"), "attachment_bones": attachment.get("bones", []),
		"actor_center":a.position+Vector3.UP*a.height*0.55,"actor_radius":a.radius,
		"actor_ground":Vector3(a.position.x,_position(actor_index(actor)).y+0.04,a.position.z),
		"target_ground":Vector3(b.position.x,_position(actor_index(target)).y+0.04,b.position.z)}

func create_move_effect(move: String, actor: String, target: String, options: Dictionary) -> Node:
	if not can_present_move(move): return null
	var recipe := MoveRecipes.get_recipe(move)
	if recipe.get("target", "") == "actor": target = actor
	elif not handles(target) and recipe.get("family", "") == "field":
		# Side/field events may have no explicit combatant target.
		for slot in _slot_count():
			var candidate := "p%d" % (slot+1)
			if slot%2!=actor_index(actor)%2 and _move_visual(candidate)!=null:
				target = candidate
				break
	var source := _move_visual(actor)
	var destination := _move_visual(target)
	if source == null or destination == null: return null
	var timing := move_timing(move, actor)
	if timing.is_empty(): return null
	var effect: Node3D
	if MoveRecipes.supports(move):
		effect = FamilyMoveEffect.new()
	elif MoveEffect.move_key(move)=="dracometeor":
		effect = DracoMeteorEffect.new()
	elif MoveEffect.move_key(move) in ContactMoveEffect.CONTACT_KEYS:
		effect = ContactMoveEffect.new()
	elif MoveEffect.move_key(move) == "thundershock":
		effect = ElectricMoveEffect.new()
	elif MoveEffect.move_key(move) == "thunderbolt":
		effect = ThunderboltMoveEffect.new()
	elif MoveEffect.move_key(move) == "flamethrower":
		effect = FireStreamMoveEffect.new()
	elif MoveEffect.move_key(move) in ["bubble", "bubblebeam"]:
		effect = BubbleMoveEffect.new()
	elif MoveEffect.move_key(move) in BatchFourMoveEffect.MOVE_KEYS:
		effect = BatchFourMoveEffect.new()
	elif MoveEffect.move_key(move) == "icebeam":
		effect = IceBeamMoveEffect.new()
	elif MoveEffect.move_key(move) == "razorleaf":
		effect = LeafMoveEffect.new()
	else:
		effect = SourceMoveEffect.new() if MoveEffect.move_key(move) in ["ember", "watergun"] else MoveEffect.new()
	world.add_child(effect)
	effect.view_camera = camera
	common_effects.append(effect)
	effect.tree_exiting.connect(func(): common_effects.erase(effect), CONNECT_ONE_SHOT)
	var positions := _move_anchors.bind(actor, target, move)
	if str(options.get("result", "")).strip_edges().to_lower() == "miss" or MoveEffect.move_key(move) in ContactMoveEffect.CONTACT_KEYS or MoveRecipes.contact(move):
		var aim := _move_anchors(actor, target, move)
		# Aim at the original position; a dodging target must not drag the beam.
		positions = _fixed_target_move_anchors.bind(actor, target, move, aim.target, aim.radius, aim.get("target_ground"))
	if MoveEffect.move_key(move) in ContactMoveEffect.CONTACT_KEYS or MoveRecipes.contact(move):
		_start_move_contact(actor, target, timing, effect)
	effect.start(move, timing, options, bind_action_clock(actor), positions,
		func(): return active and _move_visual(actor) == source and _move_visual(target) == destination)
	return effect

func start_move_action(ident: String, move: String) -> void:
	if handles(ident):
		var index := actor_index(ident)
		var max_seconds := 0.8 if MoveEffect.move_key(move)=="quickattack" else (1.25 if MoveEffect.supports(move) else 0.0)
		# Moonblast gets a full two-second performance: 0.9s charge, 0.35s
		# flight, then impact/recovery. Draco Meteor takes 3.2s for its ascent
		# and shower. The native clock still owns every cue.
		var duration_override := 2.0 if MoveEffect.move_key(move)=="moonblast" else (3.2 if MoveEffect.move_key(move)=="dracometeor" else 0.0)
		if MoveRecipes.supports(move): duration_override = float(MoveRecipes.get_recipe(move).duration_seconds)
		_action(attack_action_for(move, ident), index, max_seconds, duration_override)
		# play() schedules its reset; sample frame zero before binding a VFX clock.
		if MoveEffect.supports(move) and players[index] != null:
			players[index].seek(0.0, true)
			players[index].advance(0.0)

func prepare_mega_form(ident: String, species: String, shiny: bool, timeout_ms := 5000) -> bool:
	var index := actor_index(ident)
	var key := ReviewedModels.key(species, shiny)
	if index < 0 or not handles(ident) or not ReviewedModels.supports(key):
		return false
	var generation: int = action_generation[index]
	staged_mega_species[index] = key
	if not catalog_entries.has(key):
		# Download only the public form announced by this event. Keep the old
		# actors visible while the selected, pinned release supplies its model.
		await _ensure_downloaded_models(true)
	if not is_inside_tree() or not active or generation != action_generation[index] or not catalog_entries.has(key):
		staged_mega_species[index] = ""
		return false
	_queue_needed_models()
	var deadline := Time.get_ticks_msec() + timeout_ms
	while is_inside_tree() and active and handles(ident) and generation == action_generation[index] and not packed.has(key) and not failed_models.has(key) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ready: bool = is_inside_tree() and active and handles(ident) and generation == action_generation[index] and packed.has(key) and bool(placements.get(key, {}).get("calibrated", false))
	if not ready:
		staged_mega_species[index] = ""
	return ready

func play_mega_evolution(ident: String, reveal: Callable) -> bool:
	var index := actor_index(ident)
	if index < 0 or not handles(ident) or staged_mega_species[index].is_empty() or not packed.has(staged_mega_species[index]) or not reveal.is_valid():
		return false
	if staged_mega_species[index].trim_suffix("@shiny") != "dragonite-mega":
		return false # Other reviewed forms use the generic staged reveal in the router.
	var effect := MegaEvolutionEffect.new()
	world.add_child(effect)
	effect.position = actors[index].position
	mega_effects[index] = effect
	var target_key: String = staged_mega_species[index]
	effect.reveal_requested.connect(func():
		if not is_instance_valid(effect) or mega_effects[index] != effect or not handles(ident):
			return
		reveal.call()
		_start_mega_appeal_after_swap(index, target_key, effect)
	)
	effect.start(playback_speed)
	await effect.finished
	if mega_effects[index] == effect:
		mega_effects[index] = null
	return effect.revealed

func _start_mega_appeal_after_swap(index: int, expected_key: String, effect: Node) -> void:
	for frame in 10:
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(effect) or mega_effects[index] != effect:
			return
		if identities[index] == expected_key and players[index] != null:
			break
	if identities[index] != expected_key or players[index] == null:
		return
	var player: AnimationPlayer = players[index]
	if not player.has_animation("mega_appeal"):
		return
	var clip := player.get_animation("mega_appeal")
	clip.length = 181.0 / 60.0
	clip.loop_mode = Animation.LOOP_NONE
	player.speed_scale = playback_speed
	player.play("mega_appeal")
	current_actions[index] = "mega_appeal"
	resting[index] = false

func start_action(ident: String, action: String) -> void:
	if handles(ident):
		_action(action, actor_index(ident))

func wait_action(ident: String) -> void:
	if not handles(ident):
		return
	var index := actor_index(ident)
	var generation: int = action_generation[index]
	while is_inside_tree() and handles(ident) and generation == action_generation[index]:
		if current_actions[index] in ["idle", "sleep", "faint_loop"] or not players[index].is_playing():
			return
		await get_tree().process_frame

func move_timing(move: String, ident: String) -> Dictionary:
	if not handles(ident):
		return {}
	var index := actor_index(ident)
	var timing: Dictionary = entries[identities[index]].action_timing
	var mapped := ActionMap.resolve(attack_action_for(move, ident), players[index].get_animation_list(), timing)
	if mapped.is_empty():
		return {}
	var profile := preload("res://scripts/battle/battle_3d_move_timing.gd").profile(identities[index], move, mapped.action, timing)
	if MoveEffect.supports(move) and not mapped.loop:
		# Baseline choreography for unreviewed species; preserve authored pilot markers.
		if profile.is_empty():
			profile = {"action": mapped.action, "frames": mapped.duration * 60.0, "impact_frame": mapped.duration * 60.0 * 0.45}
		profile["move_key"] = MoveEffect.move_key(move)
		if MoveRecipes.supports(move):
			var recipe := MoveRecipes.get_recipe(move)
			profile["launch_frame"] = float(profile.frames) * float(recipe.launch_fraction)
			profile["impact_frame"] = float(profile.frames) * float(recipe.impact_fraction)
		elif profile.move_key == "moonblast":
			profile["launch_frame"] = float(profile.frames) * 0.45
			profile["impact_frame"] = float(profile.frames) * 0.625
		elif profile.move_key == "dracometeor":
			profile["launch_frame"] = float(profile.frames) * (0.7/3.2)
			profile["impact_frame"] = float(profile.frames) * (2.05/3.2)
	return profile

func action_clock(ident: String, generation: int, end_seconds: float) -> float:
	if not handles(ident):
		return end_seconds
	var index := actor_index(ident)
	if action_generation[index] != generation or current_actions[index] in ["idle", "sleep"]:
		return end_seconds
	return players[index].current_animation_position

func bind_action_clock(ident: String) -> Callable:
	if not handles(ident):
		return Callable()
	var index := actor_index(ident)
	var length: float = players[index].get_animation(current_actions[index]).length
	return action_clock.bind(ident, action_generation[index], length)

func wait_action_until(ident: String, native_frame: float) -> void:
	if not handles(ident):
		return
	var index := actor_index(ident)
	var generation: int = action_generation[index]
	while is_inside_tree() and handles(ident) and generation == action_generation[index]:
		if current_actions[index] in ["idle", "sleep", "faint_loop"] or not players[index].is_playing():
			return
		if players[index].current_animation_position >= native_frame / 60.0:
			return
		await get_tree().process_frame

func play_action(ident: String, action: String) -> void:
	start_action(ident, action)
	if not handles(ident):
		return
	var generation: int = action_generation[actor_index(ident)]
	await wait_action(ident)
	if action == "faint_start" and handles(ident) and generation == action_generation[actor_index(ident)] and current_actions[actor_index(ident)] == "faint_start":
		lifecycle[actor_index(ident)] = "fainted"
		# Keep the final pose if a legacy catalog has no faint_loop.
		# Never hide a fainted 3D actor while the player chooses a replacement.
		if players[actor_index(ident)].has_animation("faint_loop") and entries[identities[actor_index(ident)]].action_timing.has("faint_loop"):
			_action("faint_loop", actor_index(ident))

func _stop_transition(index: int) -> void:
	transition_generation[index] += 1
	if is_instance_valid(ball_effects[index]):
		ball_effects[index].cancel()
		# The awaiting coroutine owns disposal; freeing it here would strand its caller.
		if not ball_restore[index].is_empty():
			actor_shown[index] = ball_restore[index].shown
			actor_scale[index] = 1.0
			lifecycle[index] = ball_restore[index].lifecycle
			if is_instance_valid(actors[index]): actors[index].visible = actor_shown[index]
	ball_effects[index] = null
	ball_restore[index] = {}
	actor_transition_offsets[index] = Vector3.ZERO

func set_actor_shown(index: int, shown: bool) -> void:
	_stop_transition(index)
	actor_shown[index] = shown
	actor_scale[index] = 1.0
	lifecycle[index] = "idle" if shown else "hidden"

func send_out(ident: String, item_id := "poke-ball", cry_species := "", with_throw := true) -> bool:
	if not handles(ident): return false
	return await _play_ball(ident, "send_out", item_id, 0, false, cry_species, with_throw)

func recall(ident: String, item_id := "poke-ball") -> bool:
	if not handles(ident): return false
	return await _play_ball(ident, "recall", item_id)

func capture(ident: String, item_id: String, shakes: int, caught: bool) -> bool:
	if not handles(ident): return false
	return await _play_ball(ident, "capture", item_id, shakes, caught)

func _play_ball(ident: String, kind: String, item_id: String, shakes := 0, caught := false, cry_species := "", with_throw := true) -> bool:
	var index := actor_index(ident)
	_stop_transition(index)
	var generation: int = transition_generation[index]
	var actor: Node3D = actors[index]
	var bounds := _effect_bounds(index)
	var ground := _position(index)
	var center: Vector3 = bounds.position + Vector3.UP * maxf(bounds.height * 0.5, 0.4)
	var opponent := _position(index + 1 if index % 2 == 0 else index - 1)
	var away := (ground - opponent).normalized()
	var start := ground + away * (3.4 if kind == "send_out" else 2.2) + Vector3.UP * 1.0
	if kind == "capture": start = opponent + Vector3.UP * 0.8
	var original_shown: bool = actor_shown[index]
	var original_lifecycle: String = lifecycle[index]
	ball_restore[index] = {"shown": original_shown, "lifecycle": original_lifecycle}
	lifecycle[index] = kind
	var effect := BallEffect.new()
	world.add_child(effect)
	ball_effects[index] = effect
	effect.build(start, center, ground, item_id, common_effect_speed, func(amount: float, offset: Vector3):
		if generation != transition_generation[index] or actors[index] != actor: return
		actor_scale[index] = maxf(amount, 0.001)
		actor_transition_offsets[index] = offset
		actor_shown[index] = amount > 0.001
		actor.visible = actor_shown[index]
	)
	effect.cue.connect(func(key: String):
		if generation != transition_generation[index]: return
		ball_cue.emit(ident, key)
		if key == "cry":
			if not cry_species.is_empty(): get_tree().root.get_node("SfxManager").play_pokemon_cry(cry_species)
		else:
			get_tree().root.get_node("SfxManager").play(key)
	)
	var completed := false
	match kind:
		"send_out": completed = await effect.send_out(with_throw)
		"recall": completed = await effect.recall()
		"capture": completed = await effect.capture(shakes, caught)
	if is_instance_valid(effect): effect.queue_free()
	if generation != transition_generation[index] or actors[index] != actor: return false
	ball_effects[index] = null
	ball_restore[index] = {}
	actor_transition_offsets[index] = Vector3.ZERO
	actor_scale[index] = 1.0
	actor_shown[index] = (kind == "send_out" or (kind == "capture" and not caught)) if completed else original_shown
	lifecycle[index] = ("idle" if actor_shown[index] else "hidden") if completed else original_lifecycle
	actor.visible = actor_shown[index]
	return completed and active

func setup(sprite_boxes: Array = [], stage_platforms: Array = []) -> void:
	boxes = sprite_boxes
	platforms = stage_platforms
	name = "ExperimentalBattle3D"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1 # Above the 2D platform art, below battle HUD and effects.
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
	return ReviewedModels.supports(ReviewedModels.key(species, shiny))

# Narrow override points for the offline candidate harness. The production
# renderer never reads candidate allowlists or motion profiles from Settings.
func _supports_combatant(species: String, shiny: bool, double: bool, substitute: bool) -> bool:
	return supported(species, shiny, double, substitute)

func _catalog_species_allowed(species: String) -> bool:
	return ReviewedModels.supports(species)

func _motion_profile(species: String) -> Dictionary:
	var entry: Dictionary = catalog_entries.get(species, {})
	var reviewed := ReviewedModels.resolve(species, str(entry.get("runtime_sha256", "")))
	if not reviewed.is_empty() and reviewed.get("motion") is Dictionary:
		return reviewed.motion
	return MOTION_PROFILES.data.get(species, {})

func _requested_arena() -> String:
	if get_tree().root.get_node("SettingsManager").battle_presentation_mode == "2.5d":
		return "classic"
	return ArenaCatalog.resolve(get_tree().root.get_node("SettingsManager").battle_3d_arena, environment_id, battle_kind)

func set_battle_context(next_environment_id: StringName, next_kind: String) -> void:
	environment_id = next_environment_id
	battle_kind = next_kind
	if viewport == null or arena_id == _requested_arena():
		return
	# A battle screen can be prewarmed before its response supplies the actual
	# encounter kind. Rebuild that empty stage before showing the battle.
	_set_active(false)
	_clear_actors()
	material_response._drop()
	render_surface.texture = null
	if forest_lease.is_empty():
		viewport.queue_free()
	else:
		_release_forest()
	viewport = null
	world = null
	camera = null
	arena_root = null
	arena_preparing = false
	entry_arena_visible = false


func _prepare_arena() -> bool:
	if viewport != null:
		return true
	arena_preparing = false
	if ArenaCatalog.uses_forest_assets(_requested_arena()):
		arena_problem = ArenaCatalog.prepare_forest(get_tree().root.get_node("SettingsManager").get_battle_3d_forest_manifest())
		arena_preparing = arena_problem.is_empty() and not ArenaCatalog.forest_ready()
	var pool := ForestPool.get_current()
	if pool != null and pool.arena_id == _requested_arena() and not pool.ready_for_battle and not pool.failed:
		arena_preparing = true
	if arena_preparing:
		return false
	var arena_started := Time.get_ticks_usec()
	_build_world()
	arena_build_ms += (Time.get_ticks_usec() - arena_started) / 1000.0
	return viewport != null

func _screened_arena_review() -> bool:
	# Screened candidates are a local visual-QC cohort. They have exact source
	# identity and hashes, but intentionally no production grounding/motion
	# approval yet. Let a battle containing only these candidates use the chosen
	# arena for review instead of silently replacing it with the classic stage.
	# Mixed / official model battles keep the stricter calibration requirement.
	if packed.is_empty():
		return false
	for identity in packed:
		var entry: Dictionary = validated_entries.get(identity, catalog_entries.get(identity, {}))
		if not entry.get("_screened_model", false):
			return false
	return true

func _build_world() -> void:
	var screened_review := _screened_arena_review()
	if ground_offsets.size() >= packed.size() or screened_review:
		forest_pool = ForestPool.get_current()
		if forest_pool != null and forest_pool.arena_id == _requested_arena():
			forest_lease = forest_pool.acquire(self)
		if not forest_lease.is_empty():
			arena_id = _requested_arena()
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
	viewport.transparent_bg = get_tree().root.get_node("SettingsManager").battle_presentation_mode == "2.5d"
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	_sync_render_size()
	render_surface.texture = viewport.get_texture()
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR if viewport.transparent_bg else Environment.BG_COLOR
	environment.environment.background_color = Color("23364b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	MaterialResponse.apply_neutral_lighting(world)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	for light in world.get_children():
		if light is DirectionalLight3D:
			light.shadow_blur = 2.0/3.0
	arena_id = _requested_arena()
	if arena_id != "classic" and ground_offsets.size() < packed.size() and not screened_review:
		arena_problem = "Arena ground calibration missing or outdated; regenerate the local catalog grounding file"
		arena_id = "classic"
	elif arena_id != "classic" and screened_review:
		arena_problem = "Screened model review — placement is not arena-calibrated"
	if ArenaCatalog.uses_forest_assets(arena_id):
		arena_problem = ArenaCatalog.prepare_forest(get_tree().root.get_node("SettingsManager").get_battle_3d_forest_manifest())
		if not arena_problem.is_empty():
			arena_id = "classic"
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	arena_root = ArenaCatalog.build(arena_id, world, camera)
	if arena_root != null:
		world.add_child(arena_root)
	elif not viewport.transparent_bg:
		_build_classic_ground()
	camera.position = ArenaCatalog.camera_home(arena_id)
	camera.fov = ArenaCatalog.CAMERA_FOV
	camera.look_at(ArenaCatalog.camera_target(arena_id))
	camera.current = true

func _build_classic_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	_mesh(plane, Vector3(0, -0.1, 0), Color("405651"))
	for i in _slot_count():
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.3
		cylinder.bottom_radius = 2.4
		cylinder.height = 0.1
		_mesh(cylinder, _position(i) - Vector3(0, 0.05, 0), Color("879b8a"))

func _position(index: int) -> Vector3:
	if _is_hybrid_presentation() and is_instance_valid(camera) and is_instance_valid(viewport) and platforms.size() >= 2:
		# Hybrid terrain is screen art. Project its visible landing surface back
		# onto the model floor rather than using the full arena's fixed spawns.
		var local_point := get_global_transform().affine_inverse() * _hybrid_platform_anchor(index)
		var pixel := local_point * Vector2(viewport.size) / size.max(Vector2.ONE)
		var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
		if point is Vector3:
			return point
	var point := ArenaCatalog.spawn(index % 2) + ArenaCatalog.battle_origin(arena_id)
	if double_mode:
		# Align each team's row with the home camera. World X alone projects at
		# different screen heights because that camera views the arena obliquely.
		var view := ArenaCatalog.camera_home(arena_id) - ArenaCatalog.camera_target(arena_id)
		view.y = 0.0
		view = view.normalized()
		var right := Vector3(view.z, 0.0, -view.x)
		var team_side := 1.0 if index % 2 == 0 else -1.0
		var lane_side := -1.0 if index < 2 else 1.0
		point = ArenaCatalog.battle_origin(arena_id) + view * team_side * 2.7 + right * lane_side * 2.25
	if is_instance_valid(arena_root):
		point.y = float(arena_root.get_meta("surface_height",0.0))
	return point


func _is_hybrid_presentation() -> bool:
	return get_tree().root.get_node("SettingsManager").battle_presentation_mode == "2.5d"


func _hybrid_platform_anchor(index: int) -> Vector2:
	var image: TextureRect = platforms[index % 2].get_node("PlatformImage")
	# The shared platform images have transparent space above their ellipse;
	# its surface is at 65% of the source image height, not the control center.
	var surface := Vector2(0.5, 0.65)
	if double_mode:
		surface.x = 0.32 if index < 2 else 0.68
	var dimensions := image.size
	if image.texture != null and image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		var texture_size := image.texture.get_size()
		var ratio := dimensions / texture_size.max(Vector2.ONE)
		var drawn_size := texture_size * maxf(ratio.x, ratio.y)
		return image.get_global_transform() * ((dimensions - drawn_size) * 0.5 + drawn_size * surface)
	return image.get_global_transform() * (dimensions * surface)

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

func _load_catalog(path: String, preserve_actors := false) -> void:
	var catalog_started := Time.get_ticks_usec()
	_cancel_load()
	loaded_path = path
	pending_entries.clear()
	import_times_ms.clear()
	model_cache_hits = 0
	download_verified_files.clear()
	verified_model_cache_hits = 0
	catalog_read_ms = 0.0
	model_validation_ms = 0.0
	catalog_entries.clear()
	catalog_calibration.clear()
	validated_entries.clear()
	failed_models.clear()
	catalog_problem = "Invalid 3D catalog; choose a compatible installed model catalog in Settings"
	reason = catalog_problem
	if not preserve_actors:
		entries.clear()
		packed.clear()
		_clear_actors()
	if path.strip_edges().is_empty():
		catalog_problem = "No 3D catalog selected — choose a local model catalog in Settings"
		reason = catalog_problem
		return
	if not FileAccess.file_exists(path):
		catalog_problem = "Selected 3D catalog not found — choose it again in Settings"
		reason = catalog_problem
		return
	var prepared_path := path + ".runtime.json" if FileAccess.file_exists(path + ".runtime.json") else path
	if not preserve_actors:
		ground_offsets.clear()
		placements.clear()
		motion_clips.clear()
		visual_bounds.clear()
	if FileAccess.file_exists(prepared_path+".grounding.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(prepared_path+".grounding.json"))
		if parsed is Dictionary and parsed.get("schema",0)==1 and parsed.get("entries") is Dictionary:
			catalog_calibration = parsed.entries
	var file := FileAccess.open(prepared_path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	var portable_pack := data is Dictionary
	if portable_pack:
		data = ReviewedModels.pack_entries(data, prepared_path.get_base_dir())
	if not data is Array:
		return
	var seen := {}
	for raw in data:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw.duplicate(true)
		for internal_key in ["_verified_runtime_hash", "_source_bytes", "_resource_cache_key", "_reviewed_model", "_screened_model"]:
			entry.erase(internal_key) # Local catalogs cannot forge loader/cache state.
		var identity := ReviewedModels.entry_key(entry)
		if not _catalog_species_allowed(identity):
			continue
		if seen.has(identity):
			catalog_entries.erase(identity) # Ambiguous variants fail closed.
			continue
		seen[identity] = true
		entry.species = identity
		var reviewed := ReviewedModels.resolve(identity, str(entry.get("runtime_sha256", "")))
		if not reviewed.is_empty():
			entry.placement = reviewed.placement
			entry.action_timing = reviewed.action_timing
			entry.attack_family_actions = reviewed.get("attack_family_actions", {})
			if ReviewedModels.is_screened(identity, str(entry.get("runtime_sha256", ""))):
				entry["_screened_model"] = true
			else:
				entry["_reviewed_model"] = true
		elif identity not in SUPPORTED:
			continue # Only the two legacy normal controls retain compatibility.
		var model_path := str(entry.get("runtime_path", ""))
		var timing: Variant = entry.get("action_timing", {})
		if entry.get("runtime_schema", 0) != 1 or not timing is Dictionary or not model_path.ends_with(".scn") or not FileAccess.file_exists(model_path):
			continue
		var model_file := FileAccess.open(model_path, FileAccess.READ)
		if model_file == null or model_file.get_length() > 134217728:
			continue
		if portable_pack and model_file.get_length() != int(entry.bytes):
			continue
		var valid := true
		for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start"]:
			var spec: Variant = timing.get(action, {})
			if not spec is Dictionary or float(spec.get("frames", 0)) <= 0 or float(spec.get("speed", 0)) <= 0:
				valid = false
		if not valid:
			continue
		if not catalog_entries.has(entry.species):
			catalog_entries[entry.species] = entry.duplicate(true)
	ReviewedModels.add_alias_entries(catalog_entries)
	catalog_read_ms = (Time.get_ticks_usec() - catalog_started) / 1000.0
	if not catalog_entries.is_empty():
		catalog_problem = ""
		reason = "Preparing local 3D models…"
		_queue_needed_models()
	else:
		catalog_problem = "Catalog has no valid reviewed 3D models"
		reason = catalog_problem

func _anticipated_form_keys() -> Array[String]:
	# Prepare all public possible forms of the visible combatants, including
	# Megas, without relying on hidden enemy items or waiting for a form event.
	var result: Array[String] = []
	for index in _slot_count():
		var identity := ReviewedModels.key(combatants[index].species, combatants[index].shiny)
		for key in preload("res://scripts/battle/battle_ui/model_form_dependencies.gd").anticipated(identity):
			if key not in result:
				result.append(key)
	return result

func _needed_species() -> Array[String]:
	var needed: Array[String] = []
	for platform in platforms:
		if platform.hazards.visible or platform.player_screens.visible or platform.enemy_screens.visible:
			return []
	for index in _slot_count():
		var box: Node = boxes[index] if index < boxes.size() else null
		if box != null and box.double_container.visible and not double_mode:
			return []
		var double: bool = double_mode
		var substitute: bool = box != null and box.substitute_active
		var species: String = combatants[index].species
		if species.is_empty() and not substitute:
			continue
		if not _supports_combatant(species, combatants[index].shiny, double, substitute):
			return [] # Pair fallback must not import unused art.
		var key := _combatant_key(index)
		if key not in needed:
			needed.append(key)
	for key in _anticipated_form_keys():
		if key not in needed:
			needed.append(key)
	for key in staged_mega_species:
		if key != "" and key not in needed:
			needed.append(key)
	return needed

func _actors_resolved() -> bool:
	if not active:
		return true # The process loop has resolved a fallback.
	for index in _slot_count():
		if identities[index] != _combatant_key(index):
			return false
	return true

func _queue_needed_models() -> void:
	if preparation_cancelled or preparation_failed:
		return
	if is_inside_tree() and get_tree().root.get_node("SettingsManager").battle_presentation_mode not in ["2.5d", "3d"]:
		return
	var needed := _needed_species()
	pending_entries = pending_entries.filter(func(entry): return entry.species in needed)
	for species in needed:
		if packed.has(species) or failed_models.has(species) or not catalog_entries.has(species):
			continue
		if loading_entry.get("species", "") == species or pending_entries.any(func(entry): return entry.species == species):
			continue
		# A catalog is a battle-local resource snapshot, just like packed actors.
		# Revalidate on catalog reload/new battle, not on every switch back.
		if validated_entries.has(species):
			pending_entries.append(validated_entries[species].duplicate(true))
			continue
		pending_entries.append(catalog_entries[species].duplicate(true))

func _finish_validation(entry: Dictionary, check: IntegrityRead) -> bool:
	var species: String = entry.species
	var reviewed := ReviewedModels.resolve(species, check.digest)
	if (entry.get("_reviewed_model", false) or entry.get("_screened_model", false)) and reviewed.is_empty():
		failed_models[species] = true
		catalog_problem = ("Screened" if entry.get("_screened_model", false) else "Reviewed") + " 3D model hash mismatch: " + species
		return false
	if not reviewed.is_empty():
		entry.placement = reviewed.placement
		entry.action_timing = reviewed.action_timing
	var calibration: Dictionary = reviewed.get("grounding", catalog_calibration.get(species, {})) if not reviewed.is_empty() else catalog_calibration.get(species, {})
	var placement := ModelPlacement.resolve(entry, calibration, check.digest)
	model_validation_ms += check.elapsed_ms
	if check.digest.is_empty() or check.bytes > 134217728 or placement.is_empty():
		failed_models[species] = true
		return false
	placements[species] = placement
	ground_offsets.erase(species)
	if placement.calibrated:
		ground_offsets[species] = placement
	var motion: Dictionary = reviewed.get("motion", _motion_profile(species)) if not reviewed.is_empty() else _motion_profile(species)
	motion_clips[species] = MotionPlacement.resolve(motion, placement, check.digest, entry.action_timing)
	if not reviewed.is_empty() and reviewed.get("bounds") is Dictionary:
		visual_bounds[species] = reviewed.bounds
	entry["_verified_runtime_hash"] = check.digest
	entry["_source_bytes"] = check.bytes
	entry["_resource_cache_key"] = ModelCache.key(entry.runtime_path, check.digest, entry.action_timing) if ResourceLoader.get_dependencies(entry.runtime_path).is_empty() else ""
	validated_entries[species] = entry.duplicate(true)
	return true

func _prune_models() -> void:
	# Active and retiring actors own their resources independently. Keep only
	# current demand in this presenter; the bounded shared LRU owns warm reuse.
	var needed := _needed_species()
	for species in packed.keys():
		if species not in needed:
			packed.erase(species)
			entries.erase(species)

func _import_next_model() -> void:
	if loading_path.is_empty():
		if loading_entry.is_empty():
			if pending_entries.is_empty():
				return
			loading_entry = pending_entries.pop_front()
		if not loading_entry.has("_verified_runtime_hash"):
			_reuse_checked_resource(loading_entry)
		if not loading_entry.has("_verified_runtime_hash"):
			if integrity_read == null:
				integrity_read = IntegrityRead.new()
				integrity_read.start(loading_entry.runtime_path)
				return
			if not integrity_read.ready():
				return
			var valid := _finish_validation(loading_entry, integrity_read)
			integrity_read = null
			if not valid:
				loading_entry.clear()
				return
		var cache_key := str(loading_entry.get("_resource_cache_key", ""))
		var cached: PackedScene = ModelCache.fetch(cache_key) if not cache_key.is_empty() else null
		if cached != null:
			packed[loading_entry.species] = cached
			entries[loading_entry.species] = loading_entry.duplicate(true)
			import_times_ms[loading_entry.species] = 0.0
			model_cache_hits += 1
			loading_entry.clear()
			return
		loading_path = loading_entry.runtime_path
		loading_started = Time.get_ticks_usec()
		if ResourceLoader.load_threaded_request(loading_path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE) != OK:
			failed_models[loading_entry.species] = true
			catalog_problem = "Could not load prepared 3D model: " + str(loading_entry.species)
			loading_path = ""
			loading_entry.clear()
		return
	var status := ResourceLoader.THREAD_LOAD_LOADED if loading_scene != null else ResourceLoader.load_threaded_get_status(loading_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if loading_scene == null:
			loading_scene = ResourceLoader.load_threaded_get(loading_path) as PackedScene
		var scene := loading_scene
		if scene == null:
			failed_models[loading_entry.species] = true
			catalog_problem = "Invalid prepared 3D scene: " + str(loading_entry.species)
		else:
			if integrity_read == null:
				integrity_read = IntegrityRead.new()
				integrity_read.start(loading_path)
				return
			if not integrity_read.ready():
				return
			var digest := integrity_read.digest
			integrity_read = null
			if digest != str(loading_entry.get("_verified_runtime_hash", "")):
				failed_models[loading_entry.species] = true
				catalog_problem = "Prepared 3D model changed during loading; select the catalog again"
				loading_path = ""
				loading_entry.clear()
				loading_scene = null
				return
			packed[loading_entry.species] = scene
			entries[loading_entry.species] = loading_entry.duplicate(true)
			import_times_ms[loading_entry.species] = (Time.get_ticks_usec() - loading_started) / 1000.0
			var cache_key := str(loading_entry.get("_resource_cache_key", ""))
			if not cache_key.is_empty():
				ModelCache.retain(cache_key, scene, int(loading_entry._source_bytes))
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		failed_models[loading_entry.species] = true
		catalog_problem = "Could not load prepared 3D model: " + str(loading_entry.species)
		ResourceLoader.load_threaded_get(loading_path)
	loading_path = ""
	loading_entry.clear()
	loading_scene = null


func _reuse_checked_resource(entry: Dictionary) -> void:
	# The downloader just checked the entire file. Only an already admitted,
	# hash-bound RAM scene can reuse that result; cold loads still recheck disk
	# before and after loading, including changes made during the load.
	if integrity_read != null:
		return # Finish any read that was already started before the handoff.
	var identity := ReviewedModels.canonical_identity(str(entry.species))
	var verified: Dictionary = download_verified_files.get(identity, {})
	var digest := str(verified.get("sha256", ""))
	var reviewed := ReviewedModels.resolve(identity, digest)
	if reviewed.is_empty() or not entry.get("_reviewed_model", false):
		return
	if digest != str(entry.get("runtime_sha256", "")) or int(verified.get("bytes", 0)) != int(entry.get("bytes", -1)):
		return
	if ProjectSettings.globalize_path(str(verified.get("path", ""))) != ProjectSettings.globalize_path(str(entry.runtime_path)):
		return
	var key := ModelCache.key(entry.runtime_path, digest, reviewed.action_timing)
	if ModelCache.fetch(key) == null:
		return
	var check := IntegrityRead.new()
	check.digest = digest
	check.bytes = int(verified.bytes)
	if _finish_validation(entry, check):
		verified_model_cache_hits += 1

func _clear_actors() -> void:
	fallback_effect_bounds.clear()
	_clear_substitute_models()
	_clear_status_effects()
	_cancel_common_effects()
	_clear_coop_target_highlight()
	for i in 4:
		staged_mega_species[i] = ""
		if is_instance_valid(mega_effects[i]):
			mega_effects[i].cancel()
		mega_effects[i] = null
		action_generation[i] += 1
		if is_instance_valid(actors[i]):
			actors[i].queue_free()
		actors[i] = null
		players[i] = null
		identities[i] = ""

func _set_active(value: bool) -> void:
	if active and not value:
		_clear_substitute_models()
		_clear_status_effects()
		_cancel_common_effects()
		_clear_coop_target_highlight()
		camera_phase = 0.0
		for i in 4:
			staged_mega_species[i] = ""
			if is_instance_valid(mega_effects[i]):
				mega_effects[i].cancel()
			mega_effects[i] = null
			_stop_transition(i)
			action_generation[i] += 1
			if is_instance_valid(players[i]):
				players[i].stop()
				resting[i] = true
				current_actions[i] = "idle"
	active = value
	_sync_weather()
	_sync_field_effects()
	visible = value or (entry_arena_requested and entry_arena_visible and viewport != null)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not value and not entry_arena_requested:
		for node in saved_colors:
			if is_instance_valid(node):
				node.self_modulate = saved_colors[node]
		saved_colors.clear()
	for i in boxes.size():
		boxes[i].presentation_anchor = _anchor.bind(i) if value else Callable()
		boxes[i].presentation_visual_rect = _visual_rect.bind(i) if value else Callable()
		boxes[i].set_model_sprites_hidden(value or entry_arena_requested)
	if value or entry_arena_requested:
		var hidden: Array = []
		if get_tree().root.get_node("SettingsManager").battle_presentation_mode == "3d":
			for platform in platforms:
				hidden.append(platform.get_node("PlatformImage"))
		for box in boxes:
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
	# CanvasItem's screen transform omits Window's content stretch here. Apply
	# the viewport's final transform explicitly so a 720p window renders 720p,
	# rather than the 1080p UI design canvas (and HiDPI output stays sharp).
	var screen := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var target := Vector2i(maxi(2, ceili(size.x * screen.x.length())), maxi(2, ceili(size.y * screen.y.length())))
	if viewport.size != target:
		viewport.size = target

func _project_to_ui(point: Vector3) -> Vector2:
	var local_point := camera.unproject_position(point) * size / Vector2(viewport.size)
	return get_global_transform() * local_point

func _anchor(body: bool, index: int) -> Vector2:
	if actors[index] == null:
		return Vector2.ZERO
	var doll: Node3D = substitute_models[index]
	if body and is_instance_valid(doll) and doll.visible:
		return _project_to_ui(doll.body.global_transform * doll.visual_bounds.get_center())
	var point: Vector3 = actors[index].position + Vector3(0,1.2,0) if body else _position(index)
	return _project_to_ui(point)

func _visual_rect(index: int) -> Rect2:
	# Substitute owns the visible model while the Pokémon is hidden. Its projected
	# bounds keep the HP HUD and hover/effect anchors attached to the battlefield.
	var doll: Node3D = substitute_models[index]
	if is_instance_valid(doll) and doll.visible:
		var home: Transform3D = move_contacts[index].get("hud_sub_transform", doll.body.global_transform)
		return _project_visual_bounds(doll.visual_bounds, home)
	if actors[index] == null or not actors[index].visible:
		return Rect2()
	var home: Transform3D = move_contacts[index].get("hud_transform", actors[index].global_transform)
	var data: Dictionary = visual_bounds.get(identities[index], {}).get(current_actions[index], {})
	if not data.is_empty():
		var box := AABB(Vector3(data.min[0], data.min[1], data.min[2]), Vector3(data.size[0], data.size[1], data.size[2]))
		return _project_visual_bounds(box, home)
	if _is_hybrid_presentation():
		# Older approved models lack sampled bounds. Reuse the posed envelope
		# already cached for effects instead of placing their HUD 3 metres up.
		_effect_bounds(index)
		var box: AABB = fallback_effect_bounds.get(identities[index], AABB())
		if box.has_volume():
			return _project_visual_bounds(box, home)
	# Conservative presentation bounds; source skeletal mesh AABBs include rest pose.
	var bottom := _anchor(false, index)
	var top := _project_to_ui(actors[index].position - contact_offsets[index] + Vector3(0, 3, 0))
	var extent := absf(bottom.y - top.y)
	return Rect2(Vector2(bottom.x - extent * 0.7, top.y), Vector2(extent * 1.4, extent))

func _project_visual_bounds(box: AABB, placement: Transform3D) -> Rect2:
	var rect := Rect2()
	for corner in 8:
		var point := _project_to_ui(placement * box.get_endpoint(corner))
		rect = Rect2(point, Vector2.ZERO) if corner == 0 else rect.expand(point)
	return rect

func actor_visual_rect(ident: String) -> Rect2:
	return _visual_rect(actor_index(ident)) if handles(ident) else Rect2()

func actor_anchor(ident: String) -> Vector2:
	return _anchor(true, actor_index(ident)) if handles(ident) else Vector2.ZERO

func _action(action: String, index: int, max_seconds := 0.0, duration_override := 0.0) -> void:
	if not active or players[index] == null:
		return
	if lifecycle[index] == "fainted" and action != "faint_loop":
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
	var mapped := ActionMap.resolve(action, players[index].get_animation_list(), entries[identities[index]].action_timing)
	if mapped.is_empty():
		return # Keep the current pose; never fall back to a sprite effect.
	action = mapped.action
	action_generation[index] += 1
	current_actions[index] = action
	var animation: Animation = players[index].get_animation(mapped.clip)
	animation.length = mapped.duration
	animation.loop_mode = Animation.LOOP_LINEAR if mapped.loop else Animation.LOOP_NONE
	players[index].speed_scale = playback_speed
	var clip_speed: float = mapped.speed * ActionMap.presentation_speed(action, mapped.duration / mapped.speed)
	if max_seconds > 0.0: clip_speed = maxf(clip_speed, mapped.duration / max_seconds)
	if duration_override > 0.0 and not mapped.loop: clip_speed = mapped.duration / duration_override
	players[index].play(mapped.clip, -1, clip_speed)
	resting[index] = action in ["idle", "sleep", "faint_start", "faint_loop"]

func _hybrid_size_limit() -> float:
	# One shared magnification preserves relative model sizes. Fit idle envelopes
	# so giant bodies do not fill the field, and attacks never pump the camera.
	var limit := 1.0
	for index in _slot_count():
		var identity := _combatant_key(index)
		if not placements.has(identity):
			continue
		var data: Dictionary = visual_bounds.get(identity, {}).get("idle", {})
		var box := AABB()
		if not data.is_empty():
			box = AABB(Vector3(data.min[0], data.min[1], data.min[2]), Vector3(data.size[0], data.size[1], data.size[2]))
		elif fallback_effect_bounds.has(identity):
			box = fallback_effect_bounds[identity]
		if not box.has_volume():
			continue
		var direction := _position(index + 1 if index % 2 == 0 else index - 1) - _position(index)
		var yaw := atan2(direction.x, direction.z) + deg_to_rad(float(placements[identity].yaw_degrees))
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(placements[identity].scale))
		var rect := Rect2()
		for corner in 8:
			var point := camera.unproject_position(basis * box.get_endpoint(corner))
			rect = Rect2(point, Vector2.ZERO) if corner == 0 else rect.expand(point)
		var available := Vector2(viewport.size) * (Vector2(0.24, 0.30) if double_mode else Vector2(0.40, 0.40))
		limit = maxf(limit, maxf(rect.size.x / maxf(available.x, 1.0), rect.size.y / maxf(available.y, 1.0)))
	return limit

func _update_camera(delta: float) -> void:
	var settings := get_tree().root.get_node("SettingsManager")
	if settings.battle_presentation_mode == "2.5d":
		# A flat background cannot follow orbit/zoom or perspective depth changes.
		# Keep a shallow, centered view and equal model scale on both platforms.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.5
		camera.position = Vector3(0, 5.5, 16)
		camera.look_at(Vector3(0, 1.3, 0))
		camera.size *= _hybrid_size_limit()
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var all_resting := true
	var focus_reframe_safe := true
	for index in _slot_count():
		all_resting = all_resting and resting[index] and current_actions[index] in ["idle", "sleep"] and lifecycle[index] in ["idle", "empty", "hidden"]
		focus_reframe_safe = focus_reframe_safe and (
			lifecycle[index] in ["empty", "hidden", "fainted"]
			or (resting[index] and current_actions[index] in ["idle", "sleep"])
		)
	if not settings.battle_3d_camera_motion:
		camera_phase = 0.0
		camera.position = ArenaCatalog.camera_home(arena_id)
	else:
		# Small arc, never crosses the combat axis; both actors remain in frame.
		# Hold framing during actions: existing 2D effects capture screen anchors.
		if all_resting:
			camera_phase += delta * 0.22
		var origin := ArenaCatalog.battle_origin(arena_id)
		camera.position = origin + (ArenaCatalog.camera_home(arena_id) - origin).rotated(Vector3.UP, sin(camera_phase) * 0.10)
	var target := ArenaCatalog.camera_target(arena_id)
	var offset := camera.position - target
	var focus_ready: bool = (
		coop_camera_focus_enabled
		and coop_camera_focus_index >= 0
		and handles("p%d" % (coop_camera_focus_index + 1))
		and actor_shown[coop_camera_focus_index]
		and lifecycle[coop_camera_focus_index] != "fainted"
	)
	if focus_reframe_safe:
		coop_camera_focus_weight = move_toward(coop_camera_focus_weight, 1.0 if focus_ready else 0.0, delta * 1.8)
	var focus_mix := smoothstep(0.0, 1.0, coop_camera_focus_weight)
	if coop_camera_focus_index >= 0 and focus_mix > 0.0:
		# Keep the partner and both opponents visible while giving the local
		# Trainer a closer, over-the-shoulder view during their decision.
		target = target.lerp(_position(coop_camera_focus_index) + Vector3(0, 1.2, 0), focus_mix * 0.35)
	offset = offset.rotated(Vector3.UP,user_camera_yaw)
	var right := offset.cross(Vector3.UP).normalized()
	offset = offset.rotated(right,user_camera_pitch)
	offset *= user_camera_zoom * (1.45 if double_mode else 1.0) * (1.0 - focus_mix * 0.13)
	camera.position = target + offset
	camera.look_at(target)

func _process(delta: float) -> void:
	_sync_render_size()
	var settings := get_tree().root.get_node("SettingsManager")
	if entry_arena_requested and settings.battle_presentation_mode == "3d" and not preparation_failed and not preparation_cancelled:
		# Terrain preparation is independent of catalog/model I/O. A pooled arena
		# can already be drawing while the actual Pokémon are still downloading.
		if _prepare_arena():
			entry_arena_visible = true
			_set_active(active)
			_update_camera(delta)
	if is_instance_valid(model_downloader):
		preparation_phase = model_downloader.progress_text()
		return
	if preparation_failed or preparation_cancelled:
		entry_arena_requested = false
		entry_arena_visible = false
		_set_active(false)
		if is_instance_valid(mode_label):
			mode_label.text = "2D · " + reason
			mode_label.tooltip_text = reason
		return
	mode_label.visible = not entry_arena_requested and settings.battle_presentation_mode in ["2.5d", "3d"] and not OS.has_feature("web") and not OS.has_feature("mobile")
	mode_label.text = (("2.5D" if settings.battle_presentation_mode == "2.5d" else "3D") + " · " + arena_id + (" · " + arena_problem if not arena_problem.is_empty() else "")) if active else ("Preparing local 3D models…" if _models_pending() else "2D · " + reason)
	mode_label.tooltip_text = reason + (" · " + arena_problem if not arena_problem.is_empty() else "")
	if settings.battle_presentation_mode not in ["2.5d", "3d"] or OS.has_feature("web") or OS.has_feature("mobile"):
		entry_arena_requested = false
		entry_arena_visible = false
		ModelCache.clear() # Explicitly leaving 3D releases retained resources.
		_set_active(false)
		_cancel_load()
		pending_entries.clear()
		catalog_entries.clear()
		catalog_calibration.clear()
		validated_entries.clear()
		failed_models.clear()
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
	var path: String = settings.get_battle_3d_catalog_path()
	if path.is_empty():
		path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	# Start independent terrain I/O alongside model loading, not after it.
	if viewport == null and ArenaCatalog.uses_forest_assets(_requested_arena()):
		arena_problem = ArenaCatalog.prepare_forest(settings.get_battle_3d_forest_manifest())
		arena_preparing = arena_problem.is_empty() and not ArenaCatalog.forest_ready()
	if path != loaded_path:
		_set_active(false)
		_load_catalog(path)
		return
	_queue_needed_models()
	if _models_pending():
		_import_next_model()
		if _models_pending():
			return
	if packed.is_empty() and not catalog_problem.is_empty():
		# Empty Team Preview needs an arena, not a model catalog. Actual leads
		# still take the complete download/validation path when they are selected.
		if viewport != null and (entry_arena_visible or active) and combatants.all(func(combatant): return str(combatant.species).is_empty()):
			_set_active(true)
			return
		reason = catalog_problem
		_set_active(false)
		return
	var desired := []
	for platform in platforms:
		if platform.hazards.visible or platform.player_screens.visible or platform.enemy_screens.visible:
			reason = "Field hazard/screen presentation uses 2D"
			_set_active(false)
			return
	for index in _slot_count():
		var box: Node = boxes[index] if index < boxes.size() else null
		if box != null and box.double_container.visible and not double_mode:
			reason = "Double battle has no four-slot 3D presenter"
			_set_active(false)
			return
		var double: bool = double_mode
		var substitute: bool = box != null and box.substitute_active
		var species: String = combatants[index].species
		if species.is_empty() and not substitute:
			desired.append("")
			continue
		if not _supports_combatant(species, combatants[index].shiny, double, substitute):
			reason = "Unsupported active Pokémon/form or substitute: " + species
			_set_active(false)
			for sprite_box in boxes:
				sprite_box.allow_web_sprite_upgrades(true)
			return
		var key := _combatant_key(index)
		if not packed.has(key):
			reason = "Prepared 3D model unavailable: " + species
			_set_active(false)
			return
		desired.append(key)
	# Team Preview has no active combatants yet. Build and warm the empty
	# arena anyway so the loading cover can release the lead-selection UI.
	# Empty actor slots are cleared below; no placeholder Pokémon are needed.
	if viewport == null:
		if not _prepare_arena():
			reason = "Preparing arena assets…"
			return
	_set_active(true)
	_update_camera(delta)
	reason = "Experimental 3D active"
	for i in _slot_count():
		if desired[i].is_empty():
			_clear_move_dodge(i)
			_clear_move_contact(i)
			move_command_holds[i] = false
			action_generation[i] += 1
			if is_instance_valid(actors[i]):
				actors[i].queue_free()
			actors[i] = null
			players[i] = null
			identities[i] = ""
			continue
		if identities[i] != desired[i]:
			_clear_move_dodge(i)
			_clear_move_contact(i)
			move_command_holds[i] = false
			var actor_started := Time.get_ticks_usec()
			if is_instance_valid(actors[i]):
				actors[i].queue_free()
			actors[i] = packed[desired[i]].instantiate()
			motion_offsets[i] = 0.0
			world.add_child(actors[i])
			actors[i].position = _position(i)
			if ground_offsets.has(desired[i]):
				actors[i].position.y += float(ground_offsets[desired[i]].lift)
			actors[i].scale = Vector3.ONE * float(placements[desired[i]].scale)
			var opponent_index := i + 1 if i % 2 == 0 else i - 1
			var direction := _position(opponent_index) - _position(i)
			actors[i].rotation.y = atan2(direction.x, direction.z) + deg_to_rad(float(placements[desired[i]].yaw_degrees))
			players[i] = _find_player(actors[i])
			preload("res://scripts/battle/animations/gliscor_flight.gd").apply(players[i], desired[i], str(entries[desired[i]].get("_verified_runtime_hash", "")))
			preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(players[i], desired[i], str(entries[desired[i]].get("_verified_runtime_hash", "")))
			preload("res://scripts/battle/animations/charmander_breath.gd").apply(players[i], desired[i], str(entries[desired[i]].get("_verified_runtime_hash", "")))
			identities[i] = desired[i]
			resting[i] = true
			_action(restoring[i], i)
			hover_offsets[i] = ModelPlacement.hover_target(placements[desired[i]], current_actions[i], 0.0, players[i].current_animation_length)
			actor_build_ms += (Time.get_ticks_usec() - actor_started) / 1000.0
		players[i].speed_scale = 0.0 if move_command_holds[i] or (status_conditions[i] == "frozen" and resting[i]) else playback_speed
		if resting[i] and not players[i].is_playing() and current_actions[i] not in ["faint_start", "faint_loop"]:
			_action(restoring[i], i)
		actors[i].visible = warming_render or actor_shown[i]
		actors[i].scale = Vector3.ONE * (1.0 if warming_render else actor_scale[i]) * float(placements[identities[i]].scale)
		if not resting[i] and not players[i].is_playing():
			resting[i] = true
			_action(restoring[i], i)
		var target_offset := MotionPlacement.offset(motion_clips.get(identities[i], {}), current_actions[i], players[i].current_animation_position if not players[i].current_animation.is_empty() else 0.0)
		motion_offsets[i] = MotionPlacement.advance(motion_offsets[i], target_offset, delta * playback_speed)
		var hover_target := ModelPlacement.hover_target(placements[identities[i]], current_actions[i], players[i].current_animation_position, players[i].current_animation_length)
		hover_offsets[i] = ModelPlacement.advance_hover(hover_offsets[i], hover_target, placements[identities[i]], delta * playback_speed)
		if _is_hybrid_presentation():
			# Follow responsive platform layout without changing native animation,
			# grounding, recall scale or the attack/faint motion correction.
			actors[i].position = _position(i)
			var direction: Vector3 = _position(i + 1 if i % 2 == 0 else i - 1) - actors[i].position
			actors[i].rotation.y = atan2(direction.x, direction.z) + deg_to_rad(float(placements[identities[i]].yaw_degrees)) + contact_yaws[i]
		actors[i].position = _position(i) + actor_transition_offsets[i] + dodge_offsets[i] + contact_offsets[i]
		actors[i].position.y += float(placements[identities[i]].lift) + motion_offsets[i] + hover_offsets[i]
	_update_move_contacts()
	_update_move_dodges()
	_sync_substitute_models()
	_sync_status_effects()
	_prune_models()

func _exit_tree() -> void:
	for index in 4:
		_stop_transition(index)
	cancel_preparation()
	_set_active(false)
	pending_entries.clear()
	packed.clear()
	entries.clear()
	_clear_actors()
	if is_instance_valid(mode_label):
		mode_label.queue_free()
	_release_forest()
