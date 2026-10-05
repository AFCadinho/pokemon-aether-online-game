extends "catalog_galar_birds_battle_review.gd"
## Fresh screenshots only. Geometry qualification is inherited from the pinned
## prior run, with exact mesh/skin/motion/placement parity checked by Python.
## This is not a new 120 Hz measurement or a performance qualification.
var refresh_rows: Dictionary = {}
var refresh_receipt: Dictionary = {}

func _measure(entry: Dictionary, model: Node3D, player: AnimationPlayer) -> Dictionary:
	if entry.species == "dragonite":
		return await super._measure(entry, model, player)
	if refresh_receipt.is_empty():
		var path := OS.get_environment("POKEAETHER_REGIONAL_REFRESH_RECEIPT")
		refresh_receipt = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(refresh_receipt.catalog_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_REVIEW").path_join("catalog.json")))
		assert(refresh_receipt.runtime_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")))
		assert(refresh_receipt.placement_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_CANDIDATES")))
		assert(refresh_receipt.source_report_sha256 == FileAccess.get_sha256(refresh_receipt.source_report))
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(refresh_receipt.source_report))
		assert(report.complete)
		assert(report.framing_sha256 == FileAccess.get_sha256(framing.resource_path))
		assert(report.placement_sha256 == FileAccess.get_sha256(placement_rules.resource_path))
		assert(report.motion_rules_sha256 == FileAccess.get_sha256(motion_rules.resource_path))
		for row: Dictionary in report.entries:
			if row.has("clips"):
				refresh_rows[row.species] = row
	var proof: Dictionary = refresh_receipt.variants[entry.species]
	assert(proof.glb_sha256 == entry.glb_sha256)
	assert(proof.runtime_sha256 == runtime_rows[entry.species].runtime_sha256)
	var measured: Dictionary = refresh_rows[entry.species].duplicate(true)
	assert(measured.glb_sha256 == proof.old_glb_sha256)
	measured.erase("shots")
	model.scale = Vector3.ONE * float(measured.scale)
	for action: String in measured.clips:
		assert(player.has_animation(action) and is_equal_approx(player.get_animation(action).length, measured.clips[action].duration))
	measured["measurement_origin"] = "Prior qualified geometry retained by exact parity; fresh eye-material screenshots only"
	measured["refresh_receipt_sha256"] = FileAccess.get_sha256(OS.get_environment("POKEAETHER_REGIONAL_REFRESH_RECEIPT"))
	return measured

func _validate_motion(entry: Dictionary, _model: Node3D, _player: AnimationPlayer, _measured: Dictionary) -> Dictionary:
	return refresh_rows[entry.species].corrected_clearance_120hz.duplicate(true)
