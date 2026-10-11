extends "res://tests/shared_model_stress_check.gd"
## One process visits every qualified pair, then repeats 128 demanding pairs twice.

func _run() -> void:
	OS.add_logger(sink)
	started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 2, "Installed fixture root and fresh receipt path"):
		quit(2)
		return
	if not check(DisplayServer.get_name() != "headless", "Actual GPU required"):
		quit(2)
		return
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	var store := Store.new(args[0])
	var catalog := store.catalog_path_for_launch()
	if not check(not catalog.is_empty(), "Complete installed compact catalog"):
		quit(1)
		return
	OS.set_environment("POKEAETHER_MODEL_CATALOG", catalog)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = catalog # Prevent any network/fallback selection.
	root.mode = Window.MODE_WINDOWED
	root.show()
	root.grab_focus()
	var assets: Array = Pilot.catalog().assets.filter(func(a: Dictionary): return a.get("format") == Pair.FORMAT)
	var cohort: Array[String] = []
	for asset: Dictionary in assets:
		cohort.append(str(asset.appearances[0].runtime_identity))
	check(cohort.size() == 1082, "Exact qualified pair set")
	# Largest file/texture budgets, plus the four runtime-corrected rigs.
	assets.sort_custom(func(a: Dictionary, b: Dictionary): return Pair.budget(a, "normal") > Pair.budget(b, "normal"))
	var repeated: Array[String] = ["gliscor", "garchomp-mega", "charmander", "roaring-moon"]
	for asset: Dictionary in assets:
		var species: String = asset.appearances[0].runtime_identity
		if species not in repeated:
			repeated.append(species)
		if repeated.size() == 128:
			break
	await create_timer(1.1).timeout
	sample("baseline")
	var workloads := [cohort, repeated, repeated]
	for sweep in workloads.size():
		for position in workloads[sweep].size():
			var species: String = workloads[sweep][position]
			var refs := await battle(species)
			await preview_pair(species, false, "pikachu" if position == 0 else "")
			await preview_pair(species, true)
			Cache.clear()
			await frames(12)
			for ref: WeakRef in refs:
				check(ref.get_ref() == null, "Retired textures released " + species)
				texture_checks += 1
			if position % 25 == 0:
				sample("sweep-%d-pair-%d" % [sweep + 1, position + 1])
			print("COLLECTION_STRESS_PAIR sweep=", sweep + 1, " species=", species, " battles=", battles, " previews=", previews)
			if not failures.is_empty() or not sink.errors.is_empty():
				break
		await create_timer(1.1).timeout
		sample("completed-sweep-" + str(sweep + 1))
		check(Pair.mounted.size() == 1082 and Pair.namespaces.size() == 1082 and Pair.closed.size() == 1082, "All distinct packs remain uniquely mounted")
		if not failures.is_empty() or not sink.errors.is_empty():
			break
	var warm: Dictionary = {}
	for row: Dictionary in samples:
		if row.label == "completed-sweep-2":
			warm = row
	if check(not warm.is_empty(), "Repeated workload completed"):
		var final: Dictionary = samples[-1]
		check(final.static_bytes <= warm.static_bytes + 16 * 1048576, "Repeated static allocation stays within 16 MiB")
		check(final.texture_bytes <= warm.texture_bytes + 1048576 and final.buffer_bytes <= warm.buffer_bytes + 1048576, "GPU ownership stabilizes")
		check(final.resources <= warm.resources + 8 and final.nodes == warm.nodes and final.orphans == warm.orphans, "Resources and nodes stabilize")
		check(final.mount_registry_json_bytes == warm.mount_registry_json_bytes, "Mount registries do not grow on revisits")
	check(battles == 1338 and previews == 5352 and canceled == 3, "Complete catalog and repeated workload")
	check(Pair.protects(store.root), "Mounted files protected during whole session")
	failures.append_array(sink.errors)
	var receipt := {"schema": 1, "ok": failures.is_empty(), "godot": Engine.get_version_info().string,
		"os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"catalog_sha256": FileAccess.get_sha256(catalog), "catalog": catalog,
		"qualified_pairs": cohort, "repeated_pairs": repeated, "battles": battles, "previews": previews,
		"canceled": canceled, "expired_texture_checks": texture_checks,
		"elapsed_ms": Time.get_ticks_msec() - started, "samples": samples, "errors": failures}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(receipt, "\t") + "\n")
	output.close()
	print("SHARED_MODEL_COLLECTION_STRESS_CHECK ", "OK" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
