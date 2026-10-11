extends SceneTree
## Private, offline pack experiment. Never accepted by the production pair loader.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Geometry = preload("res://tools/sprite_factory/model_geometry_audit.gd")
var files := {}
var pool := {}
var memo := {}
var resource_root := ""
var output := ""

class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			print("GEOMETRY_PROTOTYPE_ERROR ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := Sink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

static func effective(actor: Node) -> String:
	var nodes := []
	var resources := {}
	for node in [actor] + actor.find_children("*", "", true, false):
		var properties := {}
		for property: Dictionary in node.get_property_list():
			var key: String = property.name
			if not int(property.usage) & PROPERTY_USAGE_STORAGE:
				continue
			if key in ["mesh", "surface_material_override", "owner"] or key.begins_with("surface_material_override/"):
				continue
			properties[key] = node.get(key)
		if node is MeshInstance3D:
			assert(node.mesh is ArrayMesh)
			properties["geometry"] = Geometry.mesh_key(node.mesh)
			var materials := []
			for surface in node.mesh.get_surface_count():
				materials.append(node.get_active_material(surface))
			properties["effective_materials"] = materials
		nodes.append([str(actor.get_path_to(node)), node.get_class(), Audit.signature(properties, resources)])
	return Audit.signature(nodes)

func remap_textures(value: Variant, seen: Dictionary) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id):
			return
		seen[id] = true
		if value is Texture2D:
			assert(value is ImageTexture and not value.resource_local_to_scene)
			var source: String = value.resource_path
			assert(source.begins_with("res://pokemon-pairs/") and "::" not in source)
			var relative := "textures/" + source.get_file()
			if not files.has(relative):
				var path := output.path_join(relative)
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_buffer(FileAccess.get_file_as_bytes(source))
				file.close()
				files[relative] = path
			value.take_over_path(resource_root.path_join(relative))
			return
		for key in Audit.storage_properties(value):
			remap_textures(value.get(key), seen)
	elif value is Array:
		for item in value:
			remap_textures(item, seen)
	elif value is Dictionary:
		for item in value.values():
			remap_textures(item, seen)

func shared(resource: Resource, category: String) -> Resource:
	assert(not resource.resource_local_to_scene)
	var key: String = Geometry.mesh_key(resource) if category == "meshes" else Audit.signature(resource, memo)
	var relative := category + "/" + key + ".res"
	if pool.has(relative):
		return pool[relative]
	var detached: Resource = Geometry.bare_mesh(resource) if category == "meshes" else resource.duplicate(true)
	if detached is AnimationLibrary:
		assert(Geometry.sensitive_tracks(detached).is_empty())
	var path := output.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert(ResourceSaver.save(detached, path, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(path).is_empty())
	detached.resource_path = resource_root.path_join(relative)
	files[relative] = path
	pool[relative] = detached
	return detached

func prepare(config: Dictionary) -> void:
	var job: Dictionary = config.jobs[0]
	assert(config.jobs.size() == 1 and job.asset.format == "model-pair-pck-v1")
	assert(FileAccess.get_sha256(job.source) == job.asset.sha256)
	assert(ProjectSettings.load_resource_pack(job.source, false))
	assert(not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	resource_root = "res://geometry-probe/" + str(job.asset.sha256)
	var models := []
	for appearance: Dictionary in job.asset.appearances:
		var source: String = str(job.asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
		assert(FileAccess.get_sha256(source) == appearance.runtime_sha256)
		var scene := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var actor := scene.instantiate()
		var fingerprint := effective(actor)
		remap_textures(scene, {})
		for node in actor.find_children("*", "", true, false):
			if node is MeshInstance3D:
				var materials := []
				for surface in node.mesh.get_surface_count():
					materials.append(node.mesh.surface_get_material(surface))
				node.mesh = shared(node.mesh, "meshes")
				for surface in materials.size():
					if node.get_surface_override_material(surface) == null:
						node.set_surface_override_material(surface, materials[surface])
				if node.skin != null:
					node.skin = shared(node.skin, "skins")
			if node is AnimationPlayer:
				for name in node.get_animation_library_list():
					var library := shared(node.get_animation_library(name), "libraries") as AnimationLibrary
					node.remove_animation_library(name)
					assert(node.add_animation_library(name, library) == OK)
		assert(effective(actor) == fingerprint, "Effective model changed during conversion")
		var candidate := PackedScene.new()
		assert(candidate.pack(actor) == OK)
		var relative: String = appearance.runtime_path
		var path := output.path_join(relative)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(ResourceSaver.save(candidate, path, ResourceSaver.FLAG_COMPRESS) == OK)
		files[relative] = path
		models.append({"identity": appearance.runtime_identity, "source_path": source,
			"source_sha256": appearance.runtime_sha256, "candidate_path": resource_root.path_join(relative),
			"effective_sha256": fingerprint})
		actor.free()
	var manifest := {"schema": 1, "prototype_only": true, "production_approved": false,
		"resource_root": resource_root, "asset_id": job.asset.asset_id, "source_pack": job.source,
		"source_sha256": job.asset.sha256, "source_bytes": job.asset.size_bytes,
		"models": models, "files": files, "shared_resources": pool.size()}
	write_json(output.path_join("prepared.json"), manifest)
	print("SHARED_GEOMETRY_PREPARED resources=", pool.size())

static func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func pack(config: Dictionary) -> void:
	var packer := PCKPacker.new()
	assert(packer.pck_start(output) == OK)
	for relative: String in config.files:
		assert(packer.add_file(str(config.resource_root).path_join(relative), config.files[relative]) == OK)
	assert(packer.flush() == OK)
	print("SHARED_GEOMETRY_PACKED")

func check(config: Dictionary) -> void:
	assert(FileAccess.get_sha256(config.pack_path) == config.pack_sha256)
	assert(ProjectSettings.load_resource_pack(config.pack_path, false))
	for relative: String in config.file_hashes:
		var path: String = str(config.resource_root).path_join(relative)
		assert(FileAccess.get_sha256(path) == config.file_hashes[relative])
		if relative.ends_with(".res") or relative.ends_with(".scn"):
			for dependency in ResourceLoader.get_dependencies(path):
				assert(dependency.begins_with(str(config.resource_root) + "/"))
				assert(config.file_hashes.has(dependency.trim_prefix(str(config.resource_root) + "/")))
	var actors := []
	for row: Dictionary in config.models:
		assert(FileAccess.get_sha256(row.candidate_path) == row.candidate_sha256)
		var scene := ResourceLoader.load(row.candidate_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
		assert(scene != null)
		var actor := scene.instantiate()
		assert(effective(actor) == row.effective_sha256, "Cold loaded effective model changed")
		actors.append(actor)
		root.add_child(actor)
	var first: Node = actors[0]
	var second: Node = actors[1]
	var meshes := 0
	for node in first.find_children("*", "MeshInstance3D", true, false):
		var other := second.get_node(first.get_path_to(node)) as MeshInstance3D
		assert(node.mesh == other.mesh and node.skin == other.skin)
		meshes += 1
	var a: Skeleton3D = first.find_children("*", "Skeleton3D", true, false)[0]
	var b: Skeleton3D = second.find_children("*", "Skeleton3D", true, false)[0]
	assert(a != b)
	var original := b.get_bone_pose_position(0)
	a.set_bone_pose_position(0, original + Vector3(1, 2, 3))
	assert(b.get_bone_pose_position(0) == original)
	var pa: AnimationPlayer = first.find_children("*", "AnimationPlayer", true, false)[0]
	var pb: AnimationPlayer = second.find_children("*", "AnimationPlayer", true, false)[0]
	for name in pa.get_animation_library_list():
		assert(pa.get_animation_library(name) == pb.get_animation_library(name))
	pa.play("idle")
	pa.pause()
	pa.seek(0.1, true)
	var unchanged := effective(second)
	pa.seek(0.7, true)
	assert(effective(second) == unchanged, "Animation leaked into the other actor")
	for actor in actors:
		actor.free()
	write_json(output, {"cold_effective_equal": true, "dependency_closure": true, "shared_mesh_instances": meshes,
		"shared_skin_and_libraries": true, "separate_skeleton_nodes": true, "pose_isolation": true,
		"prototype_only": true, "production_approved": false})
	print("SHARED_GEOMETRY_COLD_OK meshes=", meshes)

func _run() -> void:
	assert(DisplayServer.get_name() == "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	output = args[2]
	match args[0]:
		"prepare": prepare(config)
		"pack": pack(config)
		"check": check(config)
		_: assert(false)
	quit()
