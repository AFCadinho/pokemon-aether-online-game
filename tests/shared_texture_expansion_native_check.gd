extends "res://tools/sprite_factory/shared_form_texture_probe.gd"
## Compare fresh schema-3 expansion archives with the actually released v16.

func mount_job(job: Dictionary, pools: Dictionary) -> void:
	var entry := {"pack_path": job.path, "texture_packs": {}}
	for pool: Dictionary in job.asset.pair_manifest.get("texture_pools", []):
		assert(pools.has(pool.sha256) and pools[pool.sha256].asset == pool)
		entry.texture_packs[pool.sha256] = pools[pool.sha256].path
	var checked := Pair.inspect_entry(entry, job.asset)
	assert(str(checked.error).is_empty(), str(checked.error))
	assert(Pair.mount_checked(job.path, job.asset, checked).is_empty())

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: String = args[1]
	assert(not FileAccess.file_exists(output))
	var pools := {}
	for job: Dictionary in fixture.pools:
		assert(not pools.has(job.asset.sha256))
		pools[job.asset.sha256] = job
		var checked := Pair.inspect(job.path, job.asset)
		assert(str(checked.error).is_empty(), str(checked.error))
		assert(Pair.mount_checked(job.path, job.asset, checked).is_empty())
	var records := []
	var samples := 0
	for job: Dictionary in fixture.jobs:
		mount_job({"asset": job.previous, "path": job.previous_path}, pools)
		mount_job(job, pools)
		var looks := []
		for i in job.asset.appearances.size():
			var before: Dictionary = job.previous.appearances[i]
			var after: Dictionary = job.asset.appearances[i]
			assert(before.runtime_identity == after.runtime_identity)
			var old_path: String = str(job.previous.pair_manifest.resource_root).path_join(before.runtime_path)
			var new_path: String = str(job.asset.pair_manifest.resource_root).path_join(after.runtime_path)
			var source := ResourceLoader.load(old_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			var target := ResourceLoader.load(new_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			assert(source != null and target != null, after.runtime_identity)
			var signature := normalized_signature(source)
			assert(signature == normalized_signature(target), "Scene/texture state changed: " + str(after.runtime_identity))
			var clone := target.duplicate(true) as PackedScene
			assert(clone != null and normalized_signature(clone) == signature)
			var old_motion := motion(source)
			assert(old_motion == motion(target) and old_motion == motion(clone), "Animation changed")
			# Simultaneous actors keep independent local materials. Retiring one
			# must leave the other's pose and complete scene state unchanged.
			var first := target.instantiate()
			var second := clone.instantiate()
			root.add_child(first)
			root.add_child(second)
			var survivor := Geometry.pose_state(second)
			var second_materials := actor_materials(second)
			var material_states := []
			for material in second_materials:
				material_states.append(normalized_signature(material))
			var mutations := 0
			for material in actor_materials(first):
				if material is BaseMaterial3D and material.resource_local_to_scene:
					assert(material not in second_materials)
					var color: Color = material.albedo_color
					material.albedo_color = Color(0.125, 0.25, 0.5, 0.75)
					for m in second_materials.size():
						assert(normalized_signature(second_materials[m]) == material_states[m])
					material.albedo_color = color
					mutations += 1
			Geometry.retire(first)
			assert(Geometry.pose_state(second) == survivor)
			assert(normalized_signature(target) == signature and normalized_signature(clone) == signature)
			Geometry.retire(second)
			samples += old_motion.size()
			looks.append({"identity": after.runtime_identity, "signature": signature,
				"motion_sha256": Audit.signature(old_motion), "motion_samples": old_motion.size(),
				"local_material_mutations": mutations, "free_one_survivor_exact": true})
			source = null
			target = null
			clone = null
			second_materials.clear()
			await process_frame
			await process_frame
		records.append({"asset_id": job.asset.asset_id, "source_sha256": job.previous.sha256,
			"candidate_sha256": job.asset.sha256, "looks": looks})
		var progress := FileAccess.open(output + ".progress", FileAccess.WRITE)
		progress.store_string(JSON.stringify({"pairs": records.size(), "motion_samples": samples}) + "\n")
		progress.close()
		print("EXPANSION_NATIVE_PAIR_OK ", records.size(), "/", fixture.jobs.size(), " ", job.asset.asset_id)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": records.size() == fixture.jobs.size(), "records": records,
		"motion_samples": samples, "input_sha256": FileAccess.get_sha256(args[0]),
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "deep_duplicates_exact": true}) + "\n")
	file.close()
	print("EXPANSION_NATIVE_COMPLETE pairs=", records.size(), " samples=", samples)
	quit()
