extends SceneTree
## Offline visual review using the normal async loader, arena and battle lifecycle.
## Admission exception is test-local and pinned to the recorded candidate hash.
const EVIDENCE = preload("res://tools/sprite_factory/garchomp_bank_candidate_results.json")
class CandidateStage:
	extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
	var candidate: Dictionary
	func _load_catalog(path: String) -> void:
		super._load_catalog(path)
		assert(catalog_entries.has("garchomp"))
		var replacement := candidate.duplicate(true)
		replacement.placement = catalog_entries.garchomp.placement.duplicate(true)
		catalog_entries.garchomp = replacement
		pending_entries.clear()
		_queue_needed_models()
	func _finish_validation(entry: Dictionary, check: IntegrityRead) -> bool:
		if entry.species == "garchomp":
			assert(check.digest == candidate.runtime_sha256)
		return super._finish_validation(entry, check)
	func _screened_arena_review() -> bool:
		return not packed.is_empty() and packed.keys().all(func(k): return k in ["garchomp", "azumarill"])

var output: String
var results := []

func _init() -> void:
	_run.call_deferred()

func ready_stage(stage: Node, identity: String) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while not stage.active or stage.identities[0] != identity or not stage._actors_resolved():
		assert(Time.get_ticks_msec() < deadline, stage.reason)
		await process_frame
	await stage.await_prepared(true, 30000)
	assert(not stage.preparation_failed and stage.arena_id != "classic")
	for frame in 3:
		await process_frame

func capture(stage: Node, label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(stage.viewport.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	var minimum := INF
	var maximum := -INF
	for mesh: MeshInstance3D in stage.actors[0].find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform * vertex
				minimum = minf(minimum, point.y)
				maximum = maxf(maximum, point.y)
	results.append({"capture": label, "arena": stage.arena_id, "action": stage.current_actions[0],
		"visible": stage.actors[0].visible, "min_y": minimum, "max_y": maximum,
		"surface_y": stage._position(0).y, "runtime_hash": stage.entries.garchomp.runtime_sha256})

func _run() -> void:
	create_timer(150).timeout.connect(func(): printerr("ARENA_REVIEW_TIMEOUT"); quit(2))
	output = OS.get_environment("CANDIDATE_ARENA_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var report: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CANDIDATE_REPORT")))
	assert(report.size() == 1 and report[0].runtime_sha256 == EVIDENCE.data.runtime_sha256)
	assert(FileAccess.get_sha256(report[0].runtime_path) == EVIDENCE.data.runtime_sha256)
	root.size = Vector2i(1280, 720)
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_ui_layout = "immersive"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	for arena in ["forest", "stadium"]:
		settings.battle_3d_arena = arena
		var stage = load("res://scripts/battle/battle_ui/experimental_battle_3d.gd").new() if OS.get_environment("CANDIDATE_USE_ACTIVE_CATALOG") == "1" else CandidateStage.new()
		if stage is CandidateStage:
			stage.candidate = report[0]
		host.add_child(stage)
		stage.size = Vector2(1280, 720)
		stage.setup()
		stage.set_combatant(0, "garchomp")
		stage.set_combatant(1, "azumarill")
		await ready_stage(stage, "garchomp")
		assert(stage.entries.garchomp.runtime_sha256 == EVIDENCE.data.runtime_sha256)
		assert(stage.entries.garchomp.action_timing.faint_start.frames == 100)
		assert(stage.arena_id == arena)
		assert(stage.material_response.viewport != null)
		await capture(stage, arena + "-idle")
		for cycle in 2:
			for action in ["physical_attack", "special_attack", "damage"]:
				stage.start_action("p1", action)
				await create_timer(stage.players[0].get_animation(action).length * 0.5).timeout
				await capture(stage, arena + "-" + str(cycle) + "-" + action)
				await stage.wait_action("p1")
				for frame in 3:
					await process_frame
				assert(stage.current_actions[0] == "idle")
			var before: int = stage.actors[0].get_instance_id()
			await stage.play_action("p1", "faint_start")
			assert(stage.current_actions[0] == "faint_loop")
			await create_timer(0.2).timeout
			await capture(stage, arena + "-" + str(cycle) + "-faint")
			assert(stage.actors[0].visible)
			stage.set_combatant(0, "azumarill")
			await ready_stage(stage, "azumarill")
			stage.set_combatant(0, "garchomp")
			await ready_stage(stage, "garchomp")
			assert(stage.actors[0].get_instance_id() != before)
			assert(stage.lifecycle[0] == "idle")
			await capture(stage, arena + "-" + str(cycle) + "-replacement")
		var viewport_ref: WeakRef = weakref(stage.viewport)
		stage.queue_free()
		for frame in 6:
			await process_frame
		assert(viewport_ref.get_ref() == null)
		print("CANDIDATE_ARENA_OK ", arena, " two cycles and replacements")
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"runtime_approved": false, "samples": results}, "\t"))
	file.close()
	host.queue_free()
	await process_frame
	quit()
