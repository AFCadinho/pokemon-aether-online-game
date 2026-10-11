extends "res://tools/sprite_factory/shared_geometry_prototype.gd"
## Schema-2 collection producer/verifier. Uses the exact prototype invariants.
const Pair = preload("res://scripts/services/model_pair_pack.gd")

func remap_textures(value: Variant, seen: Dictionary) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id): return
		seen[id] = true
		if value is Texture2D:
			assert(value is ImageTexture and not value.resource_local_to_scene)
			var relative := "textures/" + Audit.signature(value) + ".res"
			if not files.has(relative):
				var path := output.path_join(relative)
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				assert(ResourceSaver.save(value, path, ResourceSaver.FLAG_COMPRESS) == OK)
				assert(ResourceLoader.get_dependencies(path).is_empty())
				files[relative] = path
			value.take_over_path(resource_root.path_join(relative))
			return
		for key in Audit.storage_properties(value): remap_textures(value.get(key), seen)
	elif value is Array:
		for item in value: remap_textures(item, seen)
	elif value is Dictionary:
		for item in value.values(): remap_textures(item, seen)

static func pose_values(actor: Node) -> Array:
	var states := []
	for node in [actor] + actor.find_children("*", "", true, false):
		# Skeleton3D creates an internal simulator with a process-local generated name.
		if node.get_class() == "PhysicalBoneSimulator3D" and node.owner == null: continue
		if node is Node3D: states.append([str(actor.get_path_to(node)), node.transform, node.visible])
		if node is Skeleton3D:
			node.force_update_all_bone_transforms()
			for bone in node.get_bone_count(): states.append(node.get_bone_pose(bone))
		if node is MeshInstance3D:
			for shape in node.get_blend_shape_count(): states.append(node.get_blend_shape_value(shape))
	return states

static func pose_state(actor: Node) -> String:
	return Audit.digest(var_to_bytes(pose_values(actor)))

static func retire(actor: Node) -> void:
	# Local-to-scene materials can otherwise release their RIDs before Godot
	# finishes detaching a MeshInstance. Keep them through the complete teardown.
	var materials := []
	for node in [actor] + actor.find_children("*", "MeshInstance3D", true, false):
		if not node is MeshInstance3D: continue
		materials.append(node.material_override)
		materials.append(node.material_overlay)
		for surface in node.mesh.get_surface_count():
			materials.append(node.get_surface_override_material(surface))
			materials.append(node.mesh.surface_get_material(surface))
	actor.free()
	materials.clear()

func motion(scene: PackedScene) -> Dictionary:
	var actor := scene.instantiate()
	root.add_child(actor)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var player: AnimationPlayer = players[0]
	var result := {}
	for action in player.get_animation_list():
		for fraction in [0.0, 0.5, 0.999]:
			player.stop()
			for skeleton in actor.find_children("*", "Skeleton3D", true, false): skeleton.reset_bone_poses()
			player.play(action)
			player.pause()
			player.seek(player.get_animation(action).length * fraction, true)
			result[str(action) + ":" + str(fraction)] = pose_state(actor)
	retire(actor)
	return result

func produce(job: Dictionary, recipe: String) -> Dictionary:
	files = {}; pool = {}; memo = {}
	assert(FileAccess.get_sha256(job.source) == job.asset.sha256)
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	resource_root = "res://pokemon-pairs/" + (recipe + str(job.asset.sha256)).sha256_text()
	var paths := {}
	if job.asset.get("format") == Pair.FORMAT:
		var checked := Pair.inspect(job.source, job.asset)
		assert(str(checked.error).is_empty(), str(checked.error))
		assert(Pair.mount_checked(job.source, job.asset, checked).is_empty())
		for appearance: Dictionary in job.asset.appearances:
			paths[appearance.variant] = str(job.asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
	else:
		var zip := ZIPReader.new()
		assert(zip.open(job.source) == OK)
		for appearance: Dictionary in job.asset.appearances:
			var path := output.path_join("sources/" + str(appearance.variant) + ".scn")
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var payload := zip.read_file("models/" + str(appearance.variant) + ".scn")
			assert(Audit.digest(payload) == appearance.runtime_sha256)
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(payload); file.close()
			paths[appearance.variant] = path
		zip.close()
	var models := []
	for appearance: Dictionary in job.asset.appearances:
		var source: String = paths[appearance.variant]
		assert(FileAccess.get_sha256(source) == appearance.runtime_sha256)
		var scene := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var source_motion := motion(scene)
		var actor := scene.instantiate()
		var fingerprint := effective(actor)
		remap_textures(scene, {})
		for node in [actor] + actor.find_children("*", "", true, false):
			if node is MeshInstance3D:
				var materials := []
				for surface in node.mesh.get_surface_count(): materials.append(node.mesh.surface_get_material(surface))
				node.mesh = shared(node.mesh, "meshes")
				for surface in materials.size():
					if node.get_surface_override_material(surface) == null: node.set_surface_override_material(surface, materials[surface])
				if node.skin != null: node.skin = shared(node.skin, "skins")
			if node is AnimationPlayer:
				for name in node.get_animation_library_list():
					var library := shared(node.get_animation_library(name), "libraries") as AnimationLibrary
					node.remove_animation_library(name)
					assert(node.add_animation_library(name, library) == OK)
		assert(effective(actor) == fingerprint, "Geometry/material relocation changed the model")
		var candidate := PackedScene.new()
		assert(candidate.pack(actor) == OK)
		var relative := "models/" + str(appearance.variant) + ".scn"
		var path := output.path_join(relative)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(ResourceSaver.save(candidate, path, ResourceSaver.FLAG_COMPRESS) == OK)
		files[relative] = path
		models.append({"identity": appearance.runtime_identity, "variant": appearance.variant, "source_path": source,
			"source_sha256": appearance.runtime_sha256, "candidate_path": resource_root.path_join(relative),
			"effective_sha256": fingerprint, "motion": source_motion})
		retire(actor)
	# Moving effective materials to instance overrides can make old, overridden
	# mesh materials unreachable. Include exactly the scene dependency closure.
	var referenced := {}
	for variant in ["normal", "shiny"]:
		for dependency in ResourceLoader.get_dependencies(files["models/" + variant + ".scn"]):
			var target: String = dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			assert(target.begins_with(resource_root + "/"))
			referenced[target.trim_prefix(resource_root + "/")] = true
	for relative in files.keys():
		if not relative.begins_with("models/") and not referenced.has(relative): files.erase(relative)
	return {"asset_id": job.asset.asset_id, "resource_root": resource_root, "models": models, "files": files.duplicate()}

func verify(job: Dictionary) -> Dictionary:
	var asset: Dictionary = job.asset
	var installed := output.path_join(str(asset.sha256))
	var checked := Pair.install(job.path, asset, installed)
	assert(str(checked.error).is_empty(), str(checked.error))
	var pack_path := installed.path_join("model-pair.pck")
	checked = Pair.inspect(pack_path, asset)
	assert(str(checked.error).is_empty(), str(checked.error))
	var mount_error := Pair.mount_checked(pack_path, asset, checked)
	assert(mount_error.is_empty(), mount_error)
	var actors := []
	var scenes := []
	var samples := 0
	for row: Dictionary in job.models:
		var scene := ResourceLoader.load(row.candidate_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
		assert(scene != null)
		var actor := scene.instantiate()
		assert(effective(actor) == row.effective_sha256, "Cold effective model mismatch: " + str(row.identity))
		var candidate_motion := motion(scene)
		if candidate_motion != row.motion:
			var differences := []
			for key in row.motion:
				if candidate_motion.get(key) != row.motion[key]: differences.append(key)
			print("MOTION_DIFFERENCES ", row.identity, " ", differences)
		assert(candidate_motion == row.motion, "Cold motion mismatch: " + str(row.identity))
		samples += row.motion.size()
		actors.append(actor); scenes.append(scene); root.add_child(actor)
	var first: Node = actors[0]
	var second: Node = actors[1]
	var shared_meshes := 0
	for node in first.find_children("*", "MeshInstance3D", true, false):
		var other := second.get_node(first.get_path_to(node)) as MeshInstance3D
		assert(node.mesh == other.mesh and node.skin == other.skin)
		shared_meshes += 1
	for skeleton in first.find_children("*", "Skeleton3D", true, false):
		var other := second.get_node(first.get_path_to(skeleton)) as Skeleton3D
		assert(skeleton != other)
		var original := other.get_bone_pose_position(0)
		skeleton.set_bone_pose_position(0, original + Vector3.ONE)
		assert(other.get_bone_pose_position(0) == original)
	var pa: AnimationPlayer = first.find_children("*", "AnimationPlayer", true, false)[0]
	var pb: AnimationPlayer = second.find_children("*", "AnimationPlayer", true, false)[0]
	for name in pa.get_animation_library_list(): assert(pa.get_animation_library(name) == pb.get_animation_library(name))
	var second_pose := pose_state(second)
	pa.play("idle"); pa.pause(); pa.seek(0.7, true)
	assert(pose_state(second) == second_pose)
	retire(first)
	assert(pose_state(second) == second_pose)
	retire(second)
	return {"asset_id": asset.asset_id, "ok": true, "shared_meshes": shared_meshes, "motion_samples": samples,
		"installed_bytes": int(asset.size_bytes) + FileAccess.get_file_as_bytes(installed.path_join("bundle.json")).size()}

func _run() -> void:
	assert(DisplayServer.get_name() == "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	DirAccess.make_dir_recursive_absolute(directory)
	var receipt := FileAccess.open(directory.path_join("records.jsonl"), FileAccess.WRITE)
	for index in input.jobs.size():
		var job: Dictionary = input.jobs[index]
		var result: Dictionary
		match args[0]:
			"produce":
				output = directory.path_join(str(index))
				result = produce(job, str(input.recipe))
			"pack":
				output = job.path
				pack(job)
				result = {"ok": true}
			"verify":
				output = directory.path_join("objects")
				result = verify(job)
			_: assert(false)
		receipt.store_line(JSON.stringify(result)); receipt.flush()
		print("GEOMETRY_COLLECTION_", args[0].to_upper(), "_OK ", job.get("asset", {}).get("asset_id", index))
		await process_frame
	receipt.close()
	quit()
