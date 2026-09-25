extends "res://tools/sprite_factory/prepare_battle_3d_runtime.gd"
## Offline standalone SCNs for hash-bound, geometry-identical shiny GLBs.
## This never writes the production registry or approves a model.

func _run() -> void:
	var normal_path := OS.get_environment("POKEAETHER_CATALOG_NORMAL_RUNTIME_REPORT")
	var shiny_path := OS.get_environment("POKEAETHER_CATALOG_SHINY_EXPORT_CATALOG")
	var output := OS.get_environment("POKEAETHER_3D_RUNTIME_OUTPUT")
	if not normal_path.is_absolute_path() or not shiny_path.is_absolute_path() or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("Supply existing absolute normal/shiny reports and a new absolute output directory")
		quit(2)
		return
	var normal_rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(normal_path))
	var shiny_catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(shiny_path))
	if not normal_rows is Array or not shiny_catalog is Dictionary or not shiny_catalog.get("entries") is Array:
		printerr("Invalid source reports")
		quit(2)
		return
	var normal := {}
	for row: Dictionary in normal_rows:
		if normal.has(row.species):
			printerr("Duplicate normal identity")
			quit(2)
			return
		normal[row.species] = row
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Cannot create output directory")
		quit(2)
		return
	var result := []
	var holds := []
	var proofs := []
	for variant: Dictionary in shiny_catalog.entries:
		if variant.get("status") != "exported_for_review":
			continue
		var species := str(variant.get("species", ""))
		if not normal.has(species):
			holds.append({"species": species, "reason": "Normal standalone model missing"})
			continue
		var base: Dictionary = normal[species]
		if FileAccess.get_sha256(str(base.runtime_path)) != str(base.runtime_sha256) or FileAccess.get_sha256(str(base.path)) != str(base.glb_sha256) or FileAccess.get_sha256(str(variant.path)) != str(variant.glb_sha256) or str(variant.normal_glb_sha256) != str(base.glb_sha256):
			holds.append({"species": species, "reason": "Normal or shiny source hash mismatch"})
			continue
		var diagnostics := []
		var checker := ProjectSettings.globalize_path("res://tools/sprite_factory/phase5_variant_parity.py")
		if OS.execute("python3", PackedStringArray([checker, str(base.path), str(variant.path)]), diagnostics, true) != 0 or diagnostics.is_empty() or str(diagnostics[0]).strip_edges() != str(variant.geometry_motion_sha256):
			holds.append({"species": species, "reason": "Exact geometry/animation parity failed"})
			continue
		var entry := base.duplicate(true)
		entry.species = species + "@shiny"
		entry.variant = "shiny"
		entry.path = variant.path
		entry.glb_sha256 = variant.glb_sha256
		entry.erase("runtime_path")
		entry.erase("runtime_sha256")
		for key in ["material_response", "material_effects", "visibility"]:
			entry.erase(key)
			if variant.has(key):
				entry[key] = variant[key]
		errors.clear()
		var prepared := _convert(entry, output)
		if prepared.is_empty() or not errors.is_empty():
			holds.append({"species": species, "reason": "; ".join(errors) if not errors.is_empty() else "Standalone conversion returned no scene"})
			continue
		result.append(prepared)
		proofs.append({"species": species, "normal_glb_sha256": base.glb_sha256,
			"shiny_glb_sha256": variant.glb_sha256,
			"normal_scn_sha256": base.runtime_sha256,
			"shiny_scn_sha256": prepared.runtime_sha256,
			"geometry_motion_sha256": variant.geometry_motion_sha256})
		print("CATALOG_SHINY_SCN_OK ", species)
	_write_json(output.path_join("report.json"), result)
	_write_json(output.path_join("parity.json"), proofs)
	_write_json(output.path_join("holds.json"), holds)
	print("CATALOG_SHINY_SCN_COMPLETE ", result.size(), " converted, ", holds.size(), " held")
	quit()
