extends "catalog_mega_battle_review.gd"
## Reuse exact native geometry samples while correcting only screenshot framing.
## Same original GLBs, runtime scenes and catalog; never a qualification shortcut.
var regional_baseline: Dictionary = {}

func _measure(entry: Dictionary, model: Node3D, player: AnimationPlayer) -> Dictionary:
	if entry.species == "dragonite":
		return await super._measure(entry, model, player)
	var path := OS.get_environment("POKEAETHER_REGIONAL_REFRAME_BASELINE")
	assert(path.is_absolute_path())
	if regional_baseline.is_empty():
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(report.complete and report.sample_hz == 60)
		assert(report.catalog_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_REVIEW").path_join("catalog.json")))
		assert(report.runtime_catalog_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")))
		for row: Dictionary in report.entries:
			if row.has("clips"):
				regional_baseline[row.species] = row
	assert(regional_baseline.has(entry.species))
	var measured: Dictionary = regional_baseline[entry.species].duplicate(true)
	assert(measured.glb_sha256 == entry.glb_sha256)
	assert(is_equal_approx(measured.scale, float(entry.placement.scale)))
	model.scale = Vector3.ONE * float(measured.scale)
	measured.erase("shots")
	measured["native_geometry_baseline_sha256"] = FileAccess.get_sha256(path)
	measured["measurement_origin"] = "unchanged native 60 Hz geometry; fresh correctly sized viewport captures"
	return measured
