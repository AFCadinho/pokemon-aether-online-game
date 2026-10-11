extends SceneTree
## Secondary audit only: distinguish mesh labels from actual geometry differences.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Geometry = preload("res://tools/sprite_factory/model_geometry_audit.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var full: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	assert(full.complete and full.pairs == full.records.size())
	var exceptions := []
	for row: Dictionary in full.records:
		if row.same_mesh_bindings:
			continue
		var result := {"asset_id": row.asset_id, "all_differences_are_resource_names": true, "differences": []}
		var first: Dictionary = row.variants[0].bindings.meshes
		var second: Dictionary = row.variants[1].bindings.meshes
		if first.size() != second.size():
			result.all_differences_are_resource_names = false
		for path: String in first:
			if first[path] == second.get(path):
				continue
			if not second.has(path):
				result.all_differences_are_resource_names = false
				result.differences.append({"node": path, "missing_counterpart": true})
				continue
			var a := Geometry.geometry(load(row.components.meshes[first[path]].path))
			var b := Geometry.geometry(load(row.components.meshes[second[path]].path))
			var names := [a.get("resource_name"), b.get("resource_name")]
			a.erase("resource_name")
			b.erase("resource_name")
			var equal := Audit.signature(a) == Audit.signature(b)
			result.all_differences_are_resource_names = result.all_differences_are_resource_names and equal
			result.differences.append({"node": path, "resource_names": names, "all_other_mesh_properties_exact": equal})
		exceptions.append(result)
	var name_only := 0
	for row: Dictionary in exceptions:
		name_only += int(row.all_differences_are_resource_names)
	var result := {"prototype_only": true, "production_approved": false,
		"source_report_sha256": FileAccess.get_sha256(args[0]), "pairs": full.pairs,
		"strict_mesh_binding_pairs": full.same_mesh_binding_pairs,
		"additional_mesh_pairs_differing_only_in_resource_name": name_only,
		"mesh_binding_pairs_equal_excluding_resource_name": int(full.same_mesh_binding_pairs) + name_only,
		"exceptions": exceptions}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("SHARED_GEOMETRY_NAME_CHECK_OK strict=", full.same_mesh_binding_pairs, " name_only=", name_only)
	quit()
