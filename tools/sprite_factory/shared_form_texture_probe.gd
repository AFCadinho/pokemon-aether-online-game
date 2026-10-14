extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
## Private pool admission for an offline experiment; production stays closed.

func collect(value: Variant, textures: Dictionary, seen: Dictionary) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id): return
		seen[id] = true
		if value is Texture2D:
			textures[value.resource_path] = value
			return
		for key in Audit.storage_properties(value): collect(value.get(key), textures, seen)
	elif value is Array:
		for item in value: collect(item, textures, seen)
	elif value is Dictionary:
		for item in value.values(): collect(item, textures, seen)

func check_closure(job: Dictionary, pool_paths: Dictionary) -> void:
	var asset: Dictionary = job.asset
	var prefix: String = str(asset.pair_manifest.resource_root) + "/"
	var declared := {}
	for row: Dictionary in asset.pair_manifest.files: declared[prefix + str(row.path)] = row
	var reached := {}
	for path: String in declared:
		assert(FileAccess.get_sha256(path) == declared[path].sha256)
		for dependency: String in ResourceLoader.get_dependencies(path):
			var target: String = dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			var relative := path.trim_prefix(prefix)
			assert(relative.begins_with("models/"), "Leaf imported an external resource")
			if target.begins_with(prefix):
				assert(declared.has(target) and Pair.dependency_allowed(int(asset.pair_manifest.schema), relative, target.trim_prefix(prefix)))
			else:
				assert(pool_paths.has(target), "Dependency is outside the exact pinned pool")
			reached[target] = true
	for path: String in declared:
		if not path.trim_prefix(prefix).begins_with("models/"): assert(reached.has(path), "Unreferenced private leaf")
	# Each requested pooled dependency must actually be used by a scene.
	for relative: String in job.texture_paths:
		assert(reached.has(str(job.texture_paths[relative])))

func measure(job: Dictionary, models: Dictionary, textures: Dictionary) -> void:
	var asset: Dictionary = job.asset
	var paths: Dictionary = job.get("texture_paths", {})
	var rows := {}
	for relative: String in job.textures:
		var path: String = paths.get(relative, str(asset.pair_manifest.resource_root).path_join(relative))
		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(texture != null)
		var state := normalized_signature(texture_state(texture))
		assert(state == job.textures[relative], "Texture pixel/mip/metadata state changed")
		var duplicate := texture.duplicate(true) as Texture2D
		assert(duplicate != null and texture_state(duplicate) == texture_state(texture))
		rows[relative] = state
	textures[asset.asset_id] = rows
	for appearance: Dictionary in asset.appearances:
		var path: String = str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
		assert(FileAccess.get_sha256(path) == appearance.runtime_sha256)
		var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
		assert(scene != null)
		var signature := normalized_signature(scene)
		var duplicate := scene.duplicate(true) as PackedScene
		assert(duplicate != null and normalized_signature(duplicate) == signature, "Scene deep duplication changed graph")
		models[appearance.runtime_identity] = {"signature": signature, "motion": motion(scene)}

func actor_textures(actor: Node) -> Dictionary:
	var textures := {}
	for node in [actor] + actor.find_children("*", "", true, false):
		for property: Dictionary in node.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "owner": collect(node.get(property.name), textures, {})
	return textures

func actor_materials(actor: Node) -> Array:
	var materials := []
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material != null and material not in materials: materials.append(material)
	return materials

func check_live(actor: Node, pool_paths: Dictionary) -> int:
	var textures := actor_textures(actor)
	var found := 0
	for path: String in textures:
		var texture: Texture2D = textures[path]
		if pool_paths.has(path):
			assert(texture == ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE))
			assert(normalized_signature(texture_state(texture)) == pool_paths[path])
			found += 1
	return found

func exercise(jobs: Array, pool_paths: Dictionary, weak: Dictionary) -> Dictionary:
	var scenes := []
	var actors := []
	var edges := 0
	for job: Dictionary in jobs:
		for appearance: Dictionary in job.asset.appearances:
			var path: String = str(job.asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
			var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
			scenes.append(scene)
			var actor := scene.instantiate()
			root.add_child(actor)
			actors.append(actor)
			edges += check_live(actor, pool_paths)
	assert(edges > pool_paths.size(), "No actual shared model texture references")
	for path: String in pool_paths:
		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(not texture.resource_local_to_scene, "Scene-local texture cannot be pooled this way")
		weak[path] = weakref(texture)
	# Mutate a scene-local material in one form. Another form must remain exact.
	var first_index := -1
	for index in actors.size():
		for material in actor_materials(actors[index]):
			if material is BaseMaterial3D and material.resource_local_to_scene:
				first_index = index
				break
		if first_index >= 0: break
	assert(first_index >= 0, "Group needs a scene-local material for the mutation control")
	var second_index := (first_index + 2) % actors.size()
	var first_materials := actor_materials(actors[first_index])
	var second_materials := actor_materials(actors[second_index])
	var second_states := []
	for material in second_materials: second_states.append(normalized_signature(material))
	var mutated := 0
	for material in first_materials:
		if material is BaseMaterial3D and material.resource_local_to_scene:
			assert(material not in second_materials)
			var original: Color = material.albedo_color
			material.albedo_color = Color(0.125, 0.25, 0.5, 0.75)
			for index in second_materials.size(): assert(normalized_signature(second_materials[index]) == second_states[index])
			material.albedo_color = original
			mutated += 1
	assert(mutated > 0, "Material ownership check needs a scene-local material")
	var survivor_pose := Geometry.pose_state(actors[2])
	Geometry.retire(actors[0])
	actors.remove_at(0)
	scenes.remove_at(0)
	for actor in actors: assert(check_live(actor, pool_paths) > 0)
	assert(Geometry.pose_state(actors[1]) == survivor_pose, "Freeing one form affected another")
	for actor in actors: Geometry.retire(actor)
	actors.clear()
	scenes.clear()
	return {"simultaneous_actors": jobs.size()*2, "shared_model_texture_edges": edges,
		"isolated_material_mutations": mutated, "free_one_survivors_exact": true}

func reload_pool(pool_paths: Dictionary) -> int:
	var bytes := 0
	for path: String in pool_paths:
		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(texture != null and normalized_signature(texture_state(texture)) == pool_paths[path])
		assert(normalized_signature(texture_state(texture.duplicate(true))) == pool_paths[path])
		if texture is PortableCompressedTexture2D:
			var buffer: PackedByteArray = texture.get("_data")
			assert(not buffer.is_empty())
			bytes += buffer.size()
	return bytes

func _run() -> void:
	assert(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility")
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var mode: String = args[0]
	assert(mode in ["source", "shared"])
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var output: String = args[2]
	var pool_paths := {}
	var pool_sha := ""
	var rejected := 0
	if mode == "shared":
		var pool: Dictionary = config.pool
		pool_sha = pool.asset.sha256
		assert(FileAccess.get_sha256(pool.path) == pool_sha)
		assert(not str(Pair.inspect(pool.path, pool.asset).error).is_empty(), "Production admitted private pool")
		assert(ProjectSettings.load_resource_pack(pool.path, false))
		for row: Dictionary in pool.asset.pair_manifest.files:
			var path: String = str(pool.asset.pair_manifest.resource_root).path_join(row.path)
			assert(FileAccess.get_sha256(path) == row.sha256 and ResourceLoader.get_dependencies(path).is_empty())
			pool_paths[path] = ""
		for group: Dictionary in pool.groups:
			var path: String = str(pool.asset.pair_manifest.resource_root).path_join(group.path)
			assert(pool_paths.has(path))
			pool_paths[path] = group.state_signature
	var packs := {}
	for job: Dictionary in config.jobs:
		var checked := Pair.inspect(job.path, job.asset)
		assert(str(checked.error).is_empty(), str(checked.error))
		var error := Pair.mount_checked(job.path, job.asset, checked)
		if mode == "source": assert(error.is_empty(), error)
		else:
			assert(error == "Model-pair dependency escapes its resource_root.", "Production unexpectedly admitted pool dependency: " + error)
			rejected += 1
			check_closure(job, pool_paths)
		packs[job.asset.asset_id] = job.asset.sha256
	var models := {}
	var textures := {}
	for job: Dictionary in config.jobs:
		measure(job, models, textures)
		await process_frame
		print("SHARED_FORM_PAIR_OK ", mode, " ", job.asset.asset_id)
	var ownership := {}
	if mode == "shared":
		var weak := {}
		ownership = exercise(config.jobs, pool_paths, weak)
		await process_frame
		await process_frame
		for path: String in weak:
			assert(weak[path].get_ref() == null and not ResourceLoader.has_cached(path), "Pooled texture retained after full eviction")
		ownership["evicted_pool_resources"] = weak.size()
		ownership["retained_pool_codec_buffer_bytes"] = reload_pool(pool_paths)
		await process_frame
		await process_frame
		for path: String in pool_paths: assert(not ResourceLoader.has_cached(path), "Reloaded texture leaked")
		var reload_models := {}
		var reload_textures := {}
		for job: Dictionary in config.jobs: measure(job, reload_models, reload_textures)
		assert(reload_models == models and reload_textures == textures, "Reloaded model changed")
		ownership["reload_exact"] = true
		ownership["production_pair_rejections"] = rejected
	var report := {"schema": 1, "complete": true, "prototype_only": true, "production_approved": false,
		"input_sha256": FileAccess.get_sha256(args[1]), "packs": packs, "pool_sha256": pool_sha,
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "models": models, "textures": textures, "ownership": ownership}
	assert(not FileAccess.file_exists(output.path_join("report.json")))
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report) + "\n")
	file.close()
	print("SHARED_FORM_TEXTURE_OK ", mode, " looks=", models.size())
	quit()
