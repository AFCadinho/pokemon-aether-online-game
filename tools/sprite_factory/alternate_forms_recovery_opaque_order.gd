extends RefCounted
## Offline repair for the three held Sawsbuck scenes. Eye transparency stays authored.
static func apply(actor: Node) -> Array:
	var records := []
	var priority := 1
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		assert(mesh.mesh != null and mesh.material_override == null)
		var changed := false
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			assert(source != null and source.render_priority == 0)
			if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			assert(priority <= Material.RENDER_PRIORITY_MAX)
			if not changed:
				mesh.mesh = mesh.mesh.duplicate(false)
				changed = true
			var material := source.duplicate(false) as StandardMaterial3D
			material.render_priority = priority
			mesh.mesh.surface_set_material(surface, material)
			records.append({"mesh":str(actor.get_path_to(mesh)),"surface":surface,"priority":priority})
			priority += 1
	assert(records.size() in [4, 5])
	return records
