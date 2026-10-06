extends "res://tools/route_flower_rollout.gd"

# Reuse the native flower-library pipeline and lossless route rollout checks.
func _run() -> void:
	intake_path = "res://tools/lobby_flower_rollout_intake.json"
	output_report = "res://tools/lobby_flower_rollout_report.json"
	super._run()


func _after_apply(results: Dictionary, _changed: Array) -> void:
	var record: Dictionary = results.lobby
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	baseline.lobby = record.after
	_write(EXPECTED, baseline)
	var rollout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	var overrides: Dictionary = rollout.maps.lobby.get("animation_overrides", {})
	for hash: String in record.flower_cells:
		overrides[hash] = catalog[hash]
	rollout.maps.lobby.animation_overrides = overrides
	rollout.maps.lobby.current_static_reference = record.after
	_write(REPORT, rollout)
	# The fountain regression check also protects the lobby's non-fountain
	# timelines. Update only its two deliberately replaced flower signatures.
	var fountain_path := "res://tools/lobby_fountain_rollout_report.json"
	var fountain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fountain_path))
	for hash: String in record.flower_cells:
		var frames := []
		for frame in 48:
			frames.append({"hash": catalog[hash].frame_hashes[frame], "duration": 0.07, "speed": 1.0})
		fountain.preserved_animations[hash] = frames
	fountain.after = record.after
	fountain.flower_sway_update = {"source_sha256": record.source_sha256, "report": output_report}
	_write(fountain_path, fountain)
