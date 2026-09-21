extends "prepare_battle_3d_runtime.gd"
## Offline 5C candidates only. Reuses the real self-contained SCN converter.

func _run() -> void:
	var source := OS.get_environment("POKEAETHER_PHASE5_REVIEW")
	var measured_path := OS.get_environment("POKEAETHER_PHASE5_MEASURED")
	var candidates_path := OS.get_environment("POKEAETHER_PHASE5_CANDIDATES")
	var output := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	var decisions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/phase5b-review-decisions.json"))
	assert(decisions.review_complete and not decisions.runtime_approved)
	assert(decisions.source_report_sha256 == FileAccess.get_sha256(measured_path))
	assert(decisions.candidates_sha256 == FileAccess.get_sha256(candidates_path))
	assert(decisions.catalog_sha256 == FileAccess.get_sha256(source.path_join("catalog.json")))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("catalog.json")))
	var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(measured_path))
	var candidates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(candidates_path))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var result := []
	var grounding := {}
	for decision: Dictionary in decisions.entries:
		if decision.status != "eligible_for_5c_normal":
			continue
		var species: String = decision.species
		var entry: Dictionary = catalog.entries.filter(func(e): return e.species == species)[0].duplicate(true)
		assert(FileAccess.get_sha256(entry.path) == decision.glb_sha256)
		var measurement: Dictionary = measured.entries.filter(func(e): return e.species == species)[0]
		entry.placement = {"scale": measurement.scale, "yaw_degrees": measurement.yaw_degrees}
		entry.action_timing = {}
		entry["_review_bounds"] = {}
		for action in measurement.clips:
			var clip: Dictionary = measurement.clips[action]
			entry.action_timing[action] = {"frames": clip.duration * 60.0, "speed": 1.0,
				"loop": action in ["idle", "sleep", "faint_loop"]}
			# Raw measurement envelopes already include placement scale; convert
			# once to model-local coordinates for cheap runtime corner projection.
			entry._review_bounds[action] = {"min": clip.envelope_min.map(func(v): return v / measurement.scale),
				"size": clip.envelope_size.map(func(v): return v / measurement.scale)}
		var prepared := _convert(entry, output)
		assert(not prepared.is_empty(), str(errors))
		assert(ResourceLoader.get_dependencies(prepared.runtime_path).is_empty())
		var motion: Dictionary = candidates.motion[species].duplicate(true)
		motion.sha256 = prepared.runtime_sha256
		prepared["_review_motion"] = motion
		prepared["_review_only"] = true
		grounding[species] = {"sha256": prepared.runtime_sha256, "scale": measurement.scale,
			"yaw_degrees": measurement.yaw_degrees, "lift": measurement.candidate_lift}
		result.append(prepared)
		print("PHASE5_PREPARED ", species)
	assert(result.size() == 7 and errors.is_empty())
	assert(_write_json(output.path_join("report.json.grounding.json"), {"schema": 1, "entries": grounding}) == OK)
	assert(_write_json(output.path_join("report.json"), result) == OK)
	print("PHASE5_RUNTIME_PREPARED ", output)
	quit()
