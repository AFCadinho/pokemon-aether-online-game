extends SceneTree
## Read-only inputs. All generated evidence lives in a fresh audit directory.
var output: String
var seen: Dictionary
var textures: Dictionary
var components: Array

func _initialize() -> void:
	_run.call_deferred()

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func role(path: String) -> String:
	for label in ["endpoint_0", "endpoint_1", "albedo_texture", "normal_texture", "roughness_texture"]:
		if label in path:
			return label
	return "other"

func component(kind: String, resource: Resource) -> void:
	# Standalone Godot serialization gives a storage proxy, NOT additive shares
	# of a compressed SCN stream. Mesh material references are removed on a copy.
	var path := output.path_join("component.res")
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS) == OK)
	var bytes := FileAccess.get_file_as_bytes(path)
	components.append({"kind":kind,"bytes":bytes.size(),"sha256":digest(bytes)})

func walk(value: Variant, path: String) -> void:
	if value is Texture2D:
		var id: int = value.get_instance_id()
		if textures.has(id):
			if role(path) not in textures[id].roles:
				textures[id].roles.append(role(path))
			return
		var img: Image = value.get_image()
		if img == null:
			return
		var bytes := img.get_data()
		var metadata := [img.get_width(),img.get_height(),img.get_format(),img.has_mipmaps()]
		textures[id] = {"roles":[role(path)],"width":img.get_width(),"height":img.get_height(),
			"format":img.get_format(),"mipmaps":img.has_mipmaps(),"payload_bytes":bytes.size(),
			"zstd_bytes":bytes.compress(FileAccess.COMPRESSION_ZSTD).size(),
			"sha256":digest(var_to_bytes(metadata)+bytes)}
		return
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		if value is ArrayMesh:
			var copy: ArrayMesh = value.duplicate()
			for surface in copy.get_surface_count():
				copy.surface_set_material(surface,null)
			component("mesh",copy)
		elif value is Animation:
			component("animation",value)
		elif value is Skin:
			component("skin",value)
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				walk(value.get(property.name),path+"/"+str(property.name))
	elif value is Dictionary:
		for key in value:
			walk(value[key],path+"/"+str(key))
	elif value is Array:
		for item in value:
			walk(item,path)

func _run() -> void:
	output = OS.get_environment("STORAGE_AUDIT_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var source := OS.get_environment("STORAGE_AUDIT_CATALOG")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	var shiny_source := OS.get_environment("STORAGE_AUDIT_SHINY_CATALOG")
	if not shiny_source.is_empty():
		var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(shiny_source))
		var rows: Array = extra if extra is Array else extra.entries
		for row in rows:
			var entry: Dictionary = row.duplicate(true)
			if not str(entry.runtime_path).is_absolute_path():
				entry.runtime_path = shiny_source.get_base_dir().path_join(entry.runtime_path)
			entry["control"] = true
			entries.append(entry)
	var results := []
	var rejected := []
	var pack := PCKPacker.new()
	assert(pack.pck_start(output.path_join("catalog.pck")) == OK)
	for entry: Dictionary in entries:
		var path: String = entry.runtime_path
		if FileAccess.get_sha256(path) != entry.runtime_sha256:
			rejected.append({"species":entry.species,"variant":entry.get("variant","normal"),"reason":"source_hash_mismatch"})
			if not entry.get("control",false):
				push_error("Primary catalog hash mismatch: "+str(entry.species))
				quit(1)
				return
			continue
		var original := FileAccess.get_file_as_bytes(path)
		var scene: PackedScene = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		assert(scene != null)
		seen = {}
		textures = {}
		components = []
		walk(scene,"scene")
		var skeleton_bytes := 0
		var node := scene.instantiate()
		for skeleton in node.find_children("*","Skeleton3D",true,false):
			var bones := []
			for index in skeleton.get_bone_count():
				bones.append([skeleton.get_bone_name(index),skeleton.get_bone_parent(index),skeleton.get_bone_rest(index)])
			skeleton_bytes += var_to_bytes(bones).size()
		node.free()
		var item := {"species":entry.species,"variant":entry.get("variant","normal"),
			"control":entry.get("control",false),"source_sha256":entry.runtime_sha256,
			"disk_bytes":original.size(),"file_header":original.slice(0,4).get_string_from_ascii(),
			"outer_zstd_bytes":original.compress(FileAccess.COMPRESSION_ZSTD).size(),
			"skeleton_serialized_bytes":skeleton_bytes,"textures":textures.values(),"components":components}
		# Existing Scene -> same engine compressed save; no model conversion.
		assert(ResourceSaver.save(scene,output.path_join("resaved.scn"),ResourceSaver.FLAG_COMPRESS) == OK)
		item["resaved_compressed_bytes"] = FileAccess.get_file_as_bytes(output.path_join("resaved.scn")).size()
		if not item.control:
			assert(pack.add_file("res://models/"+str(entry.species)+".scn",path) == OK)
		assert(FileAccess.get_sha256(path) == entry.runtime_sha256)
		results.append(item)
		print("STORAGE_AUDIT ",entry.species," ",entry.get("variant","normal")," textures=",textures.size())
		var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		report.store_string(JSON.stringify({"schema":1,"catalog_sha256":FileAccess.get_sha256(source),"rejected":rejected,"entries":results},"\t"))
		report.close()
		await process_frame
	assert(pack.flush() == OK)
	print("STORAGE_AUDIT_DONE ",results.size())
	quit()
