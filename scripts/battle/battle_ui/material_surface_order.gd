extends RefCounted
## Resolve equal-depth opaque surfaces by scene order, independent of recycled RIDs.
## Explicit priorities and transparent material sorting remain authored behavior.
const META := "pokeaether_material_surface_order"
static func priorities(source: Node) -> Dictionary:
	var surfaces:=[]
	var preserve:=false
	var meshes:=source.find_children("*","MeshInstance3D",true,false)
	if source is MeshInstance3D:meshes.push_front(source)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh==null:continue
		for surface in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(surface)
			if not material is StandardMaterial3D:continue
			surfaces.append([mesh,surface,material.render_priority])
			preserve=preserve or material.render_priority!=0 or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
	var result: Dictionary={}
	var first_priority:=0 if surfaces.size()<=128 else Material.RENDER_PRIORITY_MIN
	for index in surfaces.size():
		var item: Array=surfaces[index]
		if not result.has(item[0]):result[item[0]]={}
		result[item[0]][item[1]]=item[2] if preserve or surfaces.size()>256 else first_priority+index
	return result
static func apply(actor: Node) -> void:
	if actor.has_meta(META):return
	var plan:=priorities(actor)
	var leases:=[]
	for mesh: MeshInstance3D in plan:
		if mesh.material_override is StandardMaterial3D:
			var original: StandardMaterial3D=mesh.material_override
			var first_surface: int=plan[mesh].keys()[0]
			if original.render_priority!=plan[mesh][first_surface]:
				var material: StandardMaterial3D=original.duplicate(false)
				material.render_priority=plan[mesh][first_surface]
				mesh.material_override=material
				leases.append(material)
			continue
		for surface: int in plan[mesh]:
			var original: StandardMaterial3D=mesh.get_active_material(surface)
			if original.render_priority==plan[mesh][surface]:continue
			var material: StandardMaterial3D=original.duplicate(false)
			material.render_priority=plan[mesh][surface]
			mesh.set_surface_override_material(surface,material)
			leases.append(material)
	# Keep private source materials through child teardown and response overrides;
	# never mutate a PackedScene's materials or retain actors in a global cache.
	actor.set_meta(META,leases)
