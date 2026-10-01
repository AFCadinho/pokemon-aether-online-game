extends SceneTree
## Isolated diagnostic pack. No catalog, registry or source asset writes.
const Fire = preload("res://tools/sprite_factory/catalog_fire_preview.gdshader")
var records: Array = []
var bound: Dictionary = {}

func _inline(value: Variant, seen: Dictionary) -> void:
	if value is Resource or value is Node:
		var identity: int = value.get_instance_id()
		if seen.has(identity): return
		seen[identity] = true
		if value is Resource: value.resource_path = ""
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				_inline(value.get(property.name),seen)
		if value is Node:
			for child in value.get_children(): _inline(child,seen)
	elif value is Array:
		for item in value: _inline(item,seen)
	elif value is Dictionary:
		for item in value.values(): _inline(item,seen)

func _check_materials(node: Node, fire_names: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(i)
			assert(material != null)
			if fire_names.has(material.resource_name):
				assert(material is ShaderMaterial and material.shader.code == Fire.code)
				assert(material.get_shader_parameter("coverage_tex") is Texture2D)
				assert(material.get_shader_parameter("noise_tex") is Texture2D)
	for child in node.get_children(): _check_materials(child,fire_names)

func _signature(node: Node) -> Array:
	var signature := [str(node.name), str(node.get_class())]
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			signature.append(hash(node.mesh.surface_get_arrays(i)))
		if node.skin != null:
			for i in node.skin.get_bind_count():
				signature.append([node.skin.get_bind_bone(i), node.skin.get_bind_pose(i)])
	if node is Skeleton3D:
		for i in node.get_bone_count():
			signature.append([node.get_bone_name(i),node.get_bone_parent(i),node.get_bone_rest(i)])
	if node is AnimationPlayer:
		for action in node.get_animation_list():
			var animation: Animation = node.get_animation(action)
			var tracks := [str(action), animation.length, animation.loop_mode]
			for i in animation.get_track_count():
				tracks.append([str(animation.track_get_path(i)),animation.track_get_type(i)])
				for k in animation.track_get_key_count(i):
					tracks.append([animation.track_get_key_time(i,k),animation.track_get_key_value(i,k)])
			signature.append(tracks)
	for child in node.get_children(): signature.append(_signature(child))
	return signature

func _texture(row: Dictionary) -> ImageTexture:
	assert(FileAccess.get_sha256(row.path) == row.sha256)
	var image := Image.load_from_file(row.path)
	assert(image != null and not image.is_empty())
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _bind(node: Node, materials: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(i)
			if original != null and materials.has(original.resource_name):
				node.set_surface_override_material(i,materials[original.resource_name])
				bound[original.resource_name] = true
	for child in node.get_children(): _bind(child,materials)

func _init() -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_FIRE_PREVIEW_JOB")))
	assert(not DirAccess.dir_exists_absolute(job.output))
	assert(DirAccess.make_dir_recursive_absolute(job.output) == OK)
	for row in job.entries:
		assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
		var packed: PackedScene = load(row.runtime_path)
		var model: Node = packed.instantiate()
		var before := _signature(model)
		var materials := {}
		bound.clear()
		for entry in row.fire_materials:
			assert(not materials.has(entry.material))
			var material := ShaderMaterial.new()
			material.shader = Fire
			material.resource_name = entry.material
			material.set_shader_parameter("coverage_tex",_texture(entry.coverage))
			material.set_shader_parameter("noise_tex",_texture(entry.noise))
			material.set_shader_parameter("uv_transform",Vector4(entry.transform[0],entry.transform[1],entry.transform[2],entry.transform[3]))
			material.set_shader_parameter("enabled",entry.enabled)
			material.set_shader_parameter("shape_flames",entry.get("shape_flames",false))
			material.set_shader_parameter("coverage_gain",entry.get("coverage_gain",1.0))
			for parameter in ["tongue_base", "tongue_span", "layer_opacity", "retain_coverage"]:
				if entry.has(parameter): material.set_shader_parameter(parameter,entry[parameter])
			materials[entry.material] = material
		_bind(model,materials)
		assert(bound.size() == materials.size())
		assert(before == _signature(model))
		_inline(model,{})
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var target: String = job.output.path_join(row.species+".scn")
		assert(ResourceSaver.save(scene,target,ResourceSaver.FLAG_COMPRESS) == OK)
		var loaded: PackedScene = ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var reloaded := loaded.instantiate()
		assert(before == _signature(reloaded))
		_check_materials(reloaded,materials)
		var record: Dictionary = row.duplicate(true)
		record.runtime_path = target
		record.runtime_sha256 = FileAccess.get_sha256(target)
		record.runtime_approved = false
		record.appearance_approved = false
		record.native_geometry_skin_animation_unchanged = true
		record.shader_sha256 = FileAccess.get_sha256("res://tools/sprite_factory/catalog_fire_preview.gdshader")
		records.append(record)
		model.free()
		reloaded.free()
		print("FIRE_PREVIEW_PACK ",row.species," materials=",bound.size()," native_parity=true")
	var file := FileAccess.open(job.output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  "))
	quit()
