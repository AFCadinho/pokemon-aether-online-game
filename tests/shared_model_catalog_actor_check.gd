extends SceneTree
## Actual threaded presenter and both previews, using pinned local catalogs.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Preview = preload("res://scripts/ui/pokedex_model_preview.gd")
const Summary = preload("res://scripts/ui/summary_model_preview.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
var fixture: Dictionary
var output: String
var records := []

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("CATALOG_ACTOR_ABORT ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var error_sink := ErrorSink.new()

func _init() -> void:
	_run.call_deferred()

func save(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value))
	file.close()

func frames(count := 4) -> void:
	for frame in count:
		await process_frame

func pose(actor: Node3D, player: AnimationPlayer, action: String, fraction: float) -> String:
	player.stop()
	for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(player.get_animation(action).length * fraction, true)
	var state := []
	for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
		for bone in skeleton.get_bone_count():
			state.append(skeleton.get_bone_pose(bone))
	return Audit.digest(var_to_bytes(state))

func actor_state(actor: Node3D, player: AnimationPlayer) -> Dictionary:
	assert(actor != null and player != null and player.has_animation("idle"))
	var samples := {}
	for action in player.get_animation_list():
		if action == "RESET":
			continue
		for fraction in [0.0, 0.5, 0.999]:
			samples[str(action) + ":" + str(fraction)] = pose(actor, player, action, fraction)
	return {"animation_signature": Audit.signature(player.get_animation_library("")), "poses": samples}

func battle(species: String, role: String) -> Dictionary:
	Cache.clear()
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	stage.set_combatant(0, species, false)
	stage.set_combatant(1, species, true)
	await stage.await_prepared(true, 45000)
	assert(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"),
		"Battle preparation " + species + " " + role + " " + stage.reason + " " + stage.catalog_problem)
	stage.set_process(false)
	var result := {}
	for index in 2:
		var identity: String = species + ("@shiny" if index == 1 else "")
		var row: Dictionary = fixture.models.filter(func(m: Dictionary): return m.identity == identity)[0]
		var entry: Dictionary = stage.entries[identity]
		assert(entry._verified_runtime_hash == row[role + "_sha256"], "Presenter loaded the wrong revision")
		if role == "candidate":
			assert(entry._pair_asset == row.pair_asset)
			assert(int(entry._cache_source_bytes) >= Pair.budget(row.pair_asset, row.variant))
		var state := actor_state(stage.actors[index], stage.players[index])
		state["placement"] = stage.placements[identity].duplicate(true)
		state["motion"] = stage.motion_clips[identity].duplicate(true)
		state["attack_family_actions"] = entry.attack_family_actions
		result[identity] = state
	assert(Cache.order.size() <= Cache.MAX_ENTRIES and Cache.source_bytes <= Cache.MAX_SOURCE_BYTES)
	stage.set_process(true)
	stage.set_combatant(0, species, true)
	stage.set_combatant(1, species, false)
	await stage.await_prepared(true, 45000)
	assert(stage.handles("p1") and stage.handles("p2") and not stage.preparation_failed, "Appearance swap")
	stage.set_combatant(0, "", false, true)
	await frames(8)
	assert(stage.handles("p2"), "Shiny/normal ownership after actor retirement")
	stage.queue_free()
	await frames()
	Cache.clear()
	return result

func previews(species: String, summary: bool) -> Dictionary:
	var preview: Control = Summary.new() if summary else Preview.new()
	preview.size = Vector2(380, 276)
	root.add_child(preview)
	var result := {}
	for shiny in [false, true]:
		assert(preview.show_species(species, shiny), "Preview start " + species)
		var deadline := Time.get_ticks_msec() + 45000
		while (preview.is_loading() or preview.actor == null) and Time.get_ticks_msec() < deadline:
			await process_frame
		assert(preview.actor != null and preview.player != null, "Preview load " + species)
		preview.set_process(false)
		var identity: String = species + ("@shiny" if shiny else "")
		var state := actor_state(preview.actor, preview.player)
		pose(preview.actor, preview.player, "idle", 0.0)
		if summary:
			preview._fit_model()
		state["camera"] = [preview.camera.position, preview.camera.rotation, preview.camera.fov, preview.camera.near, preview.camera.far]
		state["scale"] = preview.actor.scale
		result[identity] = state
		await frames()
		preview._clear_actor()
		preview.set_process(true)
		await frames()
	preview.queue_free()
	await frames()
	return result

func _run() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name() != "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	fixture = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	output = args[1]
	assert(not FileAccess.file_exists(output))
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	root.mode = Window.MODE_WINDOWED
	root.show()
	root.grab_focus()
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	for species: String in fixture.pairs:
		var states := []
		for role in ["source", "candidate"]:
			var entries := []
			for row: Dictionary in fixture.models:
				if str(row.identity).trim_suffix("@shiny") != species:
					continue
				var entry := {"species": species, "variant": row.variant, "runtime_schema": 1,
					"runtime_path": row[role + "_path"], "runtime_sha256": row[role + "_sha256"], "bytes": row[role + "_bytes"]}
				if role == "candidate":
					entry["pair_asset"] = row.pair_asset
					entry["pack_path"] = row.pack_path
				entries.append(entry)
			assert(entries.size() == 2)
			var path: String = output.get_base_dir().path_join(species + "-" + role + "-catalog.json")
			save(path, entries)
			settings.battle_3d_catalog_path = path
			var state := {"battle": await battle(species, role),
				"pokedex": await previews(species, false), "summary": await previews(species, true)}
			states.append(state)
		assert(states[0] == states[1], "Actual actor / preview changed: " + species)
		var record := {"species": species, "actual_actor_states_exact": true,
			"source_and_candidate_state_sha256": Audit.signature(states[0]),
			"battle_pose_samples": states[0].battle[species].poses.size() + states[0].battle[species + "@shiny"].poses.size()}
		records.append(record)
		save(output + ".progress", {"records": records})
		print("CATALOG_ACTOR_OK ", species, " battles=2 previews=8 pose_samples=", record.battle_pose_samples)
	save(output, {"schema": 1, "complete": records.size() == fixture.pairs.size(), "pairs": fixture.pairs,
		"records": records, "battles": records.size() * 2, "previews": records.size() * 8,
		"mounted_pairs": Pair.mounted.size(), "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name()})
	quit()
