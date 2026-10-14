extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
## Cold native comparison of every repackaged appearance against approved v15.

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
	var pool: Dictionary = fixture.pool
	var pool_check := Pair.inspect(pool.path, pool.asset)
	assert(str(pool_check.error).is_empty(), str(pool_check.error))
	assert(Pair.mount_checked(pool.path, pool.asset, pool_check).is_empty())
	var records := []
	var samples := 0
	for job: Dictionary in fixture.jobs:
		var previous: Dictionary = job.previous
		var candidate: Dictionary = job.asset
		var old_check := Pair.inspect(job.previous_path, previous)
		assert(str(old_check.error).is_empty(), str(old_check.error))
		assert(Pair.mount_checked(job.previous_path, previous, old_check).is_empty())
		var entry := {"pack_path": job.path, "texture_packs": {}}
		for dependency: Dictionary in candidate.pair_manifest.get("texture_pools", []):
			assert(dependency == pool.asset)
			entry.texture_packs[dependency.sha256] = pool.path
		var checked := Pair.inspect_entry(entry, candidate)
		assert(str(checked.error).is_empty(), str(checked.error))
		assert(Pair.mount_checked(job.path, candidate, checked).is_empty())
		var looks := []
		for i in candidate.appearances.size():
			var before: Dictionary = previous.appearances[i]
			var after: Dictionary = candidate.appearances[i]
			assert(before.runtime_identity == after.runtime_identity)
			var source_path := str(previous.pair_manifest.resource_root).path_join(before.runtime_path)
			var target_path := str(candidate.pair_manifest.resource_root).path_join(after.runtime_path)
			var source := ResourceLoader.load(source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			var target := ResourceLoader.load(target_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			assert(source != null and target != null, after.runtime_identity)
			var signature := normalized_signature(source)
			assert(signature == normalized_signature(target), "Scene state changed: " + str(after.runtime_identity))
			var clone := target.duplicate(true) as PackedScene
			assert(clone != null and normalized_signature(clone) == signature, "Deep duplicate changed")
			var original_motion := motion(source)
			assert(original_motion == motion(target), "Animation changed: " + str(after.runtime_identity))
			assert(original_motion == motion(clone), "Duplicate animation changed")
			samples += original_motion.size()
			looks.append({"identity": after.runtime_identity, "signature": signature,
				"motion_sha256": Audit.signature(original_motion), "motion_samples": original_motion.size()})
			source = null
			target = null
			clone = null
			await process_frame
			await process_frame
		records.append({"asset_id": candidate.asset_id, "source_sha256": previous.sha256,
			"candidate_sha256": candidate.sha256, "looks": looks})
		var progress := FileAccess.open(output + ".progress", FileAccess.WRITE)
		progress.store_string(JSON.stringify({"records": records, "motion_samples": samples}) + "\n")
		progress.close()
		print("V16_NATIVE_PAIR_OK ", records.size(), "/", fixture.jobs.size(), " ", candidate.asset_id)
	var report := {"complete": records.size() == fixture.jobs.size(), "records": records,
		"motion_samples": samples, "input_sha256": FileAccess.get_sha256(args[0]),
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "deep_duplicates_exact": true}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report) + "\n")
	file.close()
	print("V16_NATIVE_COMPLETE pairs=", records.size(), " samples=", samples)
	quit()
