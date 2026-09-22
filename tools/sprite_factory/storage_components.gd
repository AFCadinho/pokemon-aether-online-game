extends RefCounted
## Offline prototype only. No registration with the production catalog.
var directory := ""
var resources := {}
var records := {}
var memo := {}
var used := {}

static func sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

static func canonical(value: Variant) -> Variant:
	if value is Image:
		return ["Image", value.get_width(), value.get_height(), value.get_format(),
			value.has_mipmaps(), sha(value.get_data())]
	if value is Resource:
		var fields := {}
		for p in value.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name not in ["resource_name", "resource_path"]:
				fields[str(p.name)] = canonical(value.get(p.name))
		return [value.get_class(), canonical(fields)]
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var result := []
		for key in keys:
			result.append([canonical(key), canonical(value[key])])
		return ["Dictionary", result]
	if value is Array:
		var result := []
		for item in value:
			result.append(canonical(item))
		return ["Array", result]
	if value is NodePath:
		return ["NodePath", str(value)]
	if value is StringName:
		return ["StringName", str(value)]
	return value

static func fingerprint(value: Variant) -> String:
	return sha(var_to_bytes(canonical(value)))

func rewrite(value: Variant) -> Variant:
	if value is Resource:
		return external(value)
	if value is Dictionary:
		var result: Dictionary = value.duplicate()
		for key in value:
			result[key] = rewrite(value[key])
		return result
	if value is Array:
		var result: Array = value.duplicate()
		for i in value.size():
			result[i] = rewrite(value[i])
		return result
	return value

func mark(id: String) -> void:
	used[id] = true
	for dependency in records[id].dependencies:
		mark(dependency)

func external(source: Resource) -> Resource:
	if source == null:
		return null
	var instance := source.get_instance_id()
	if memo.has(instance):
		mark(memo[instance])
		return resources[memo[instance]]
	# Images stay inside their texture container, with original bytes and mips.
	assert(not source is Script, "Executable resources are outside this prototype")
	var id := fingerprint(source)
	memo[instance] = id
	if resources.has(id):
		mark(id)
		return resources[id]
	var copy := source.duplicate(false)
	var parent_used := used
	used = {}
	if not source is Texture2D and not source is Image and not source is ArrayMesh:
		for p in source.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name not in ["resource_path", "resource_name"]:
				copy.set(p.name, rewrite(source.get(p.name)))
	var dependencies := used.keys()
	used = parent_used
	var filename := id + (".scn" if copy is PackedScene else ".res")
	var path := directory.path_join(filename)
	assert(ResourceSaver.save(copy, path, ResourceSaver.FLAG_COMPRESS) == OK)
	copy.take_over_path(path)
	# Compare semantics again after serialization in a separate resource graph.
	var roundtrip := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert(fingerprint(roundtrip) == id, "Serialization changed component: " + source.get_class())
	resources[id] = copy
	records[id] = {"file": filename, "kind": source.get_class(),
		"semantic_sha256": id, "sha256": FileAccess.get_sha256(path),
		"bytes": FileAccess.get_file_as_bytes(path).size(), "dependencies": dependencies}
	mark(id)
	return copy

func prepare(node: Node) -> Dictionary:
	var appearance := {}
	for child in [node] + node.find_children("*", "", true, false):
		if child is MeshInstance3D and child.mesh != null:
			var materials := []
			for surface in child.mesh.get_surface_count():
				materials.append(child.get_surface_override_material(surface)
					if child.get_surface_override_material(surface) != null
					else child.mesh.surface_get_material(surface))
				child.set_surface_override_material(surface, null)
			appearance[str(node.get_path_to(child))] = {
				"surfaces": rewrite(materials), "override": rewrite(child.material_override)}
			child.material_override = null
			var geometry: Mesh = child.mesh.duplicate(false)
			for surface in geometry.get_surface_count():
				geometry.surface_set_material(surface, null)
			child.mesh = geometry
		for p in child.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE:
				var value: Variant = child.get(p.name)
				if value is Resource or value is Dictionary or value is Array:
					child.set(p.name, rewrite(value))
	return appearance

static func instantiate(shared: PackedScene, appearance: Resource) -> Node3D:
	var node := shared.instantiate() as Node3D
	var private_materials := {}
	for path in appearance.get_meta("appearance"):
		var mesh := node.get_node(NodePath(path)) as MeshInstance3D
		var data: Dictionary = appearance.get_meta("appearance")[path]
		for i in data.surfaces.size():
			mesh.set_surface_override_material(i, owned_material(data.surfaces[i], private_materials))
		mesh.material_override = owned_material(data.override, private_materials)
	return node

static func owned_material(material: Material, owned: Dictionary) -> Material:
	if material == null:
		return null
	var id := material.get_instance_id()
	if not owned.has(id):
		# Per-instance material state, immutable shared textures/endpoints.
		owned[id] = material.duplicate(false)
	return owned[id]

static func actor_content(node: Node) -> Dictionary:
	var result := {}
	for child in [node] + node.find_children("*", "", true, false):
		var fields := {}
		for p in child.get_property_list():
			if not p.usage & PROPERTY_USAGE_STORAGE:
				continue
			var name: String = p.name
			if child is MeshInstance3D and (name == "mesh" or name == "material_override" or name.begins_with("surface_material_override/")):
				continue
			fields[name] = canonical(child.get(name))
		if child is MeshInstance3D and child.mesh != null:
			var geometry: Mesh = child.mesh.duplicate(false)
			var mats := []
			for i in geometry.get_surface_count():
				mats.append(canonical(child.get_active_material(i)))
				geometry.surface_set_material(i, null)
			fields["geometry"] = canonical(geometry)
			fields["effective_materials"] = mats
		result[str(node.get_path_to(child))] = [child.get_class(), fields]
	return result
