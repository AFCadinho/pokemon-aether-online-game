extends "prepare_battle_3d_runtime.gd"
## Offline variants only; bit-identical geometry/motion is required to reuse placement.
func _run() -> void:
	var normal_path := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")
	var source := OS.get_environment("POKEAETHER_PHASE5_REVIEW")
	var output := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	var result: Array = JSON.parse_string(FileAccess.get_file_as_string(normal_path))
	var grounding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(normal_path + ".grounding.json"))
	var variants: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("catalog.json")))
	var proofs := []
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	for variant: Dictionary in variants.entries:
		if variant.status != "exported_for_review":
			continue
		var normal: Dictionary = result.filter(func(e): return e.species == variant.species)[0]
		assert(normal._review_only and FileAccess.get_sha256(normal.runtime_path) == normal.runtime_sha256)
		assert(FileAccess.get_sha256(normal.path) == normal.glb_sha256)
		assert(FileAccess.get_sha256(variant.path) == variant.glb_sha256)
		var diagnostics := []
		var checker := ProjectSettings.globalize_path("res://tools/sprite_factory/phase5_variant_parity.py")
		assert(OS.execute("python3", PackedStringArray([checker, normal.path, variant.path]), diagnostics, true) == 0, str(diagnostics))
		var entry := normal.duplicate(true)
		entry.species = str(normal.species) + "@shiny"
		entry.path = variant.path
		entry["variant"] = "shiny"
		# Never carry normal endpoint colours into a shiny conversion.
		if normal.has("material_response"):
			assert(variant.has("material_response"), "Shiny export is missing its own material response")
		entry.erase("material_response")
		if variant.has("material_response"):
			entry.material_response = variant.material_response
		var prepared := _convert(entry, output)
		assert(not prepared.is_empty() and errors.is_empty(), str(errors))
		prepared._review_motion.sha256 = prepared.runtime_sha256
		grounding.entries[entry.species] = grounding.entries[normal.species].duplicate(true)
		grounding.entries[entry.species].sha256 = prepared.runtime_sha256
		result.append(prepared)
		proofs.append({"species": normal.species, "normal_glb_sha256": normal.glb_sha256,
			"shiny_glb_sha256": variant.glb_sha256, "geometry_motion_sha256": str(diagnostics[0]).strip_edges()})
	assert(proofs.size() >= 6)
	assert(_write_json(output.path_join("parity.json"), proofs) == OK)
	assert(_write_json(output.path_join("report.json.grounding.json"), grounding) == OK)
	assert(_write_json(output.path_join("report.json"), result) == OK)
	print("PHASE5_VARIANTS_PREPARED ", proofs.size())
	quit()
