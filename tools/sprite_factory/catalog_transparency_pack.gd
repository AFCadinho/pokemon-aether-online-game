extends RefCounted
## Hash-bound, review-only mapping of imported alpha surfaces to source blend modes.
var failure := ""

func _visit(node: Node, expected: Dictionary, seen: Dictionary, alpha_mix: bool) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original == null or not expected.has(original.resource_name):
				continue
			if not original is StandardMaterial3D or original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				failure = "Source alpha surface was not imported as transparent: " + original.resource_name
				return false
			var profile: Dictionary = expected[original.resource_name]
			var material := original.duplicate() as StandardMaterial3D
			if profile.has("source_base_alpha"):
				var alpha := float(profile.source_base_alpha)
				if not is_finite(alpha) or alpha < 0.0 or alpha > 1.0:
					failure = "Invalid source constant alpha"
					return false
				material.albedo_color.a *= alpha
			match str(profile.source_alpha_type):
				"Blend": material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
				"Add": material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				"BlendPreMultiAlpha": material.blend_mode = BaseMaterial3D.BLEND_MODE_PREMULT_ALPHA
				_:
					failure = "Unknown source blend mode"
					return false
			if profile.source_refraction:
				var alpha_min := float(profile.get("source_fresnel_alpha_min", 1.0))
				var alpha_max := float(profile.get("source_fresnel_alpha_max", 1.0))
				if not is_finite(alpha_min) or not is_finite(alpha_max) or alpha_min < 0.0 or alpha_min > 1.0 or alpha_max < 0.0 or alpha_max > 1.0:
					failure = "Invalid source Fresnel alpha"
					return false
				var tint: Color = material.albedo_color
				tint.a *= (alpha_min + alpha_max) * 0.5
				material.albedo_color = tint
				# Optional alpha-only review avoids screen-space refraction hiding
				# opaque facial geometry enclosed by the transparent shell.
				material.refraction_enabled = not alpha_mix
				if alpha_mix:
					material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
				# Constant average Fresnel and Godot's default strength are review
				# approximations; the native Thin graph remains unrepresented.
				material.refraction_scale = 0.05
			node.set_surface_override_material(surface, material)
			seen[original.resource_name] = true
	for child in node.get_children():
		if not _visit(child, expected, seen, alpha_mix):
			return false
	return true

func apply(node: Node, manifest: Dictionary, glb_hash: String) -> bool:
	failure = ""
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or manifest.get("visual_review_required") != true:
		failure = "Transparency manifest does not match GLB"
		return false
	if not manifest.get("materials") is Array or manifest.materials.is_empty():
		failure = "Missing transparent source materials"
		return false
	if manifest.get("refraction_approximation", "") not in ["", "alpha_mix"]:
		failure = "Unknown refraction approximation"
		return false
	var expected := {}
	for row in manifest.materials:
		if not row is Dictionary or row.get("profile") != "scvi_source_alpha_diagnostic_v1" or not row.get("material") is String or expected.has(row.material) or not row.get("source_refraction") is bool:
			failure = "Invalid transparent source profile"
			return false
		expected[row.material] = row
	var seen := {}
	if not _visit(node, expected, seen, manifest.get("refraction_approximation", "") == "alpha_mix") or seen.size() != expected.size():
		if failure.is_empty():
			failure = "Transparent source material not bound to a mesh"
		return false
	node.set_meta("pokeaether_transparency_diagnostic", 1)
	return true
