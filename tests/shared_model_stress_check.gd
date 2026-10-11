extends SceneTree
## Real presenter and previews across the entire qualified cohort in one process.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Preview = preload("res://scripts/ui/pokedex_model_preview.gd")
const Summary = preload("res://scripts/ui/summary_model_preview.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var battles := 0
var previews := 0
var canceled := 0
var texture_checks := 0
var started := 0

class Sink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := Sink.new()

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		print("SHARED_STRESS_FAIL ", reason)
	return value

func frames(count := 8) -> void:
	for _frame in count:
		await process_frame

func texture_refs(scene: PackedScene) -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for texture: Texture2D in Contract.textures(scene, {}, {}).values():
		result.append(weakref(texture))
	return result

func battle(species: String) -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	root.grab_focus()
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	stage.set_combatant(0, species, false)
	stage.set_combatant(1, species, true)
	await stage.await_prepared(true, 45000)
	if check(stage.active and not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"), "Battle prepares " + species + ": " + stage.catalog_problem + " / " + stage.reason + " / loaded=" + stage.loaded_path + " requested=" + root.get_node("SettingsManager").get_battle_3d_catalog_path() + " / " + JSON.stringify(stage.preparation_metrics)):
		for identity: String in stage.entries:
			var entry: Dictionary = stage.entries[identity]
			var trusted := Pilot.asset_for(identity, str(entry.get("_verified_runtime_hash", "")))
			check(not trusted.is_empty() and entry.get("_pair_asset") == trusted, "Actual qualified pack revision loaded " + identity)
		for scene: PackedScene in stage.packed.values():
			refs.append_array(texture_refs(scene))
		check(not refs.is_empty(), "Battle owns textures: " + species)
		check(Cache.order.size() <= Cache.MAX_ENTRIES and Cache.source_bytes <= Cache.MAX_SOURCE_BYTES, "LRU limits during " + species)
		stage.set_sleeping(0, true)
		await frames()
		stage.set_sleeping(0, false)
		stage.set_combatant(0, species, true)
		stage.set_combatant(1, species, false)
		await stage.await_prepared(true, 45000)
		check(stage.handles("p1") and stage.handles("p2") and not stage.preparation_failed, "Normal/shiny switch " + species)
		stage.set_combatant(0, "", false, true)
		await frames()
		check(stage.handles("p2"), "Other appearance survives actor retirement " + species)
		battles += 1
	stage.queue_free()
	await frames()
	return refs

func preview_pair(species: String, summary: bool, cancel_to := "") -> void:
	var preview: Control = Summary.new() if summary else Preview.new()
	preview.size = Vector2(380, 276)
	root.add_child(preview)
	for shiny in [false, true]:
		check(preview.show_species(species, shiny), "Start preview " + species)
		var deadline := Time.get_ticks_msec() + 45000
		while (preview.is_loading() or preview.actor == null) and Time.get_ticks_msec() < deadline:
			await process_frame
		if check(preview.actor != null and preview.player != null, "Preview loads " + species):
			check(preview.player.has_animation("idle"), "Preview retains idle " + species)
			await frames(4)
			previews += 1
		preview._clear_actor()
		await frames(4)
	if not cancel_to.is_empty():
		preview.show_species(species, false)
		preview.show_species(cancel_to, true)
		var deadline := Time.get_ticks_msec() + 45000
		while preview.is_loading() and Time.get_ticks_msec() < deadline:
			await process_frame
		check(preview.actor != null and preview.requested_key == cancel_to + "@shiny", "Canceled selection cannot reveal old appearance")
		canceled += 1
	preview.queue_free()
	await frames()

func sample(label: String) -> Dictionary:
	var rss := 0
	var proc := FileAccess.open("/proc/self/status", FileAccess.READ)
	if proc != null:
		while not proc.eof_reached():
			var line := proc.get_line()
			if line.begins_with("VmRSS:"):
				rss = line.trim_prefix("VmRSS:").strip_edges().get_slice("kB", 0).strip_edges().to_int() * 1024
	var result := {"label": label, "elapsed_ms": Time.get_ticks_msec() - started,
		"static_bytes": OS.get_static_memory_usage(), "rss_bytes": rss,
		"texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"mounts": Pair.mounted.size(), "namespaces": Pair.namespaces.size(), "closures": Pair.closed.size(),
		"mount_registry_json_bytes": JSON.stringify([Pair.mounted, Pair.namespaces, Pair.closed]).to_utf8_buffer().size(),
		"lru_entries": Cache.order.size(), "lru_source_bytes": Cache.source_bytes}
	samples.append(result)
	print("SHARED_STRESS_SAMPLE ", JSON.stringify(result))
	return result

func _run() -> void:
	OS.add_logger(sink)
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 3 and args[0].is_absolute_path() and args[1].is_absolute_path() and args[2].to_int() >= 3, "Pack directory, receipt and at least three sweeps"):
		quit(1)
		return
	if not check(DisplayServer.get_name() != "headless", "Real GPU renderer required"):
		quit(1)
		return
	var sweeps := args[2].to_int()
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	OS.set_environment("POKEAETHER_MODEL_PAIR_PACKS", args[0])
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	root.mode = Window.MODE_WINDOWED
	root.show()
	root.grab_focus()
	var index: Dictionary = Pilot.DATA.data
	var store := Store.new("user://shared-model-stress-" + str(Time.get_ticks_usec()))
	var ids: Array[String] = []
	var cohort: Array[String] = []
	var declared_members := 0
	for asset: Dictionary in index.assets:
		ids.append(str(asset.asset_id))
		if asset.get("format") == Pair.FORMAT:
			cohort.append(str(asset.appearances[0].runtime_identity))
			declared_members += asset.pair_manifest.files.size() + 1
	var session := store.begin_collection(index, ids)
	for asset_id: String in session.get("downloads", []).duplicate():
		var asset: Dictionary = Index.by_id(index)[asset_id]
		var source_root: String = args[0] if asset.get("format") == Pair.FORMAT else args[0].get_base_dir().get_base_dir().path_join("lossless-catalog-v1/prepared/archives")
		check(str(store.stage_collection(session, asset_id, source_root.path_join(str(asset.object_key).get_file())).error).is_empty(), "Install " + asset_id)
	if not check(str(store.finish_collection(session).error).is_empty(), "Activate complete local fixture"):
		quit(1)
		return
	OS.set_environment("POKEAETHER_MODEL_CATALOG", store.catalog_path())
	check(preload("res://scripts/services/desktop_asset_storage.gd").register_model_usage(store.root, OS.get_process_id()) == OK, "Register launcher store lease")
	await create_timer(1.1).timeout
	sample("baseline")
	for sweep in sweeps:
		for position in cohort.size():
			var species := cohort[(position + sweep * 5) % cohort.size()]
			var refs := await battle(species)
			await preview_pair(species, false, "pikachu" if position == 0 else "")
			await preview_pair(species, true)
			Cache.clear()
			await frames(12)
			for ref: WeakRef in refs:
				check(ref.get_ref() == null, "Battle textures released after cache and previews leave " + species)
				texture_checks += 1
			print("SHARED_STRESS_PAIR sweep=", sweep + 1, " species=", species, " battles=", battles, " previews=", previews)
			if not failures.is_empty() or not sink.errors.is_empty():
				break
		check(Pair.mounted.size() == cohort.size(), "One mount per distinct requested pack")
		check(Pair.namespaces.size() == cohort.size() and Pair.closed.size() == cohort.size(), "Stable namespace/closure registries")
		await create_timer(1.1).timeout # Performance monitors can lag by up to a second.
		sample("sweep-" + str(sweep + 1))
		if not failures.is_empty() or not sink.errors.is_empty():
			break
	if samples.size() == sweeps + 1:
		var warm: Dictionary = samples[1]
		var final: Dictionary = samples[-1]
		check(final.static_bytes - warm.static_bytes <= 16 * 1048576, "Post-warm-up static growth stays below 16 MiB")
		check(final.texture_bytes <= warm.texture_bytes + 1048576 and final.buffer_bytes <= warm.buffer_bytes + 1048576, "No accumulating GPU texture/buffer ownership")
		check(final.resources <= warm.resources + 8 and final.nodes == warm.nodes and final.orphans == warm.orphans, "Resources and nodes stabilize after warm-up")
		check(final.mount_registry_json_bytes == warm.mount_registry_json_bytes, "Repeated encounters do not grow mount registries")
	check(battles == sweeps * cohort.size() and previews == battles * 4 and canceled == sweeps, "Complete requested stress workload")
	check(Pair.protects(store.root) and not str(store.garbage_collect().error).is_empty(), "Mounted fixture files remain protected until process exit")
	failures.append_array(sink.errors)
	var receipt := {"schema": 1, "ok": failures.is_empty(), "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "os": OS.get_name(),
		"sweeps": sweeps, "pairs": cohort.size(), "declared_pck_members": declared_members,
		"battles": battles, "previews": previews, "canceled": canceled, "expired_texture_checks": texture_checks,
		"elapsed_ms": Time.get_ticks_msec() - started, "samples": samples, "errors": failures}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	else:
		check(false, "Write stress receipt")
	print("SHARED_MODEL_STRESS_CHECK ", "OK" if failures.is_empty() else "FAILED", " battles=", battles, " previews=", previews, " errors=", failures)
	quit(0 if failures.is_empty() else 1)
