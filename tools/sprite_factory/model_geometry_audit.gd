extends RefCounted
## Offline comparison; excludes material bindings only from mesh geometry keys.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

static func geometry(mesh: ArrayMesh) -> Dictionary:
	var result := {}
	for name in Audit.storage_properties(mesh):
		var value: Variant = mesh.get(name)
		if name == "_surfaces":
			var surfaces: Array = value.duplicate()
			for i in surfaces.size():
				var surface: Dictionary = surfaces[i].duplicate()
				surface.erase("material")
				surfaces[i] = surface
			value = surfaces
		result[name] = value
	return result

static func mesh_key(mesh: ArrayMesh) -> String:
	return Audit.signature([mesh.get_class(), geometry(mesh)])

static func bare_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var result := mesh.duplicate() as ArrayMesh
	for surface in result.get_surface_count():
		result.surface_set_material(surface, null)
	assert(mesh_key(result) == mesh_key(mesh))
	return result

static func resources(value: Variant, result: Dictionary, seen: Dictionary) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		if value is Texture2D or value is Image or value is Material:
			return
		if value is ArrayMesh:
			result.meshes.append(value)
			return
		if value is Skin:
			result.skins.append(value)
			return
		if value is AnimationLibrary:
			result.libraries.append(value)
			return
		for name in Audit.storage_properties(value):
			resources(value.get(name), result, seen)
	elif value is Array:
		for item in value:
			resources(item, result, seen)
	elif value is Dictionary:
		for item in value.values():
			resources(item, result, seen)

static func inventory(scene: PackedScene) -> Dictionary:
	var result := {"meshes": [], "skins": [], "libraries": []}
	resources(scene, result, {})
	return result

static func skeletons(scene: PackedScene) -> Dictionary:
	var state := scene.get_state()
	var result := {}
	for index in state.get_node_count():
		if state.get_node_type(index) != "Skeleton3D":
			continue
		var properties := {}
		for p in state.get_node_property_count(index):
			properties[str(state.get_node_property_name(index, p))] = state.get_node_property_value(index, p)
		result[str(state.get_node_path(index))] = Audit.signature(properties)
	return result

static func bindings(scene: PackedScene, memo: Dictionary = {}) -> Dictionary:
	var result := {"meshes": {}, "skins": {}, "libraries": {}}
	var state := scene.get_state()
	for node in state.get_node_count():
		var path := str(state.get_node_path(node))
		for property in state.get_node_property_count(node):
			var name := str(state.get_node_property_name(node, property))
			var value: Variant = state.get_node_property_value(node, property)
			if name == "mesh" and value is ArrayMesh:
				result.meshes[path] = mesh_key(value)
			elif name == "skin" and value is Skin:
				result.skins[path] = Audit.signature(value, memo)
			elif name == "libraries" and value is Dictionary:
				for library_name: StringName in value:
					result.libraries[path + ":" + str(library_name)] = Audit.signature(value[library_name], memo)
			elif name.begins_with("libraries/") and value is AnimationLibrary:
				result.libraries[path + ":" + name.trim_prefix("libraries/")] = Audit.signature(value, memo)
	return result

static func structure(scene: PackedScene) -> String:
	# Authored node hierarchy/transforms plus all non-resource properties. Root
	# names are retained; this is a strict correspondence test, not fuzzy matching.
	var state := scene.get_state()
	var nodes := []
	for index in state.get_node_count():
		var properties := {}
		for p in state.get_node_property_count(index):
			var name := str(state.get_node_property_name(index, p))
			if name in ["mesh", "skin", "libraries", "material_override", "material_overlay"] or name.begins_with("surface_material_override/") or name.begins_with("libraries/"):
				continue
			properties[name] = state.get_node_property_value(index, p)
		nodes.append([state.get_node_path(index), state.get_node_path(index, true), state.get_node_owner_path(index),
			state.get_node_name(index), state.get_node_type(index), state.get_node_groups(index),
			state.get_node_instance(index), properties])
	return Audit.signature(nodes)

static func sensitive_tracks(library: AnimationLibrary) -> Array[String]:
	var result: Array[String] = []
	for name in library.get_animation_list():
		var animation := library.get_animation(name)
		for track in animation.get_track_count():
			var path := str(animation.track_get_path(track))
			if animation.track_get_type(track) == Animation.TYPE_METHOD or "material" in path.to_lower() or ":mesh" in path:
				result.append(str(name) + ":" + path)
	return result
