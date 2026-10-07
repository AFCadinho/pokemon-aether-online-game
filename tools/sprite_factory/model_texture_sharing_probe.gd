extends SceneTree
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() == "headless" and RenderingServer.get_rendering_device() == null,
		"Offline CPU probe requires --headless dummy rendering")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: String = args[1]
	var owned := ProjectSettings.globalize_path("res://.tmp/")
	assert(output.is_absolute_path() and output.simplify_path().begins_with(owned))
	assert(not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var report := {"schema": 1, "models": [], "scope": "CPU image payloads; not GPU allocations or whole-collection savings"}
	var combined := Audit.new()
	for row: Dictionary in input.models:
		assert(str(row.path).is_absolute_path() and str(row.path).simplify_path().begins_with(owned))
		assert(FileAccess.get_sha256(row.path) == row.sha256)
		assert(ResourceLoader.get_dependencies(row.path).is_empty(), "Require self-contained reviewed scenes")
		var scene := ResourceLoader.load(row.path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var audit := Audit.new()
		audit.inspect(scene)
		# Independent objects per file; carry only texture descriptions, never
		# hold model references across the audit of the collection.
		combined.textures.append_array(audit.textures)
		var before := Audit.signature(scene)
		var record := {"identity": row.identity, "source_path": row.path, "source_sha256": row.sha256,
			"before": audit.summary(), "textures": audit.textures, "semantic_sha256": before}
		if int(record.before.strict_shareable_duplicate_bytes) > 0:
			var control_path := output.path_join(row.identity.replace("@", "-") + "-control.scn")
			assert(ResourceSaver.save(scene, control_path, ResourceSaver.FLAG_COMPRESS) == OK)
			assert(Audit.signature(scene) == before)
			record["control_path"] = control_path
			var sharing := Audit.new()
			sharing.share(scene)
			assert(Audit.signature(scene) == before, "Sharing altered resource values")
			var path := output.path_join(row.identity.replace("@", "-") + ".scn")
			assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
			var reloaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			assert(reloaded != null and Audit.signature(reloaded) == before, "Saved values differ")
			var after := Audit.new()
			after.inspect(reloaded)
			assert(int(after.summary().strict_shareable_duplicate_bytes) == 0)
			record.merge({"candidate_path": path, "candidate_sha256": FileAccess.get_sha256(path),
				"after": after.summary(), "replacements": sharing.replacements, "roundtrip_exact": true})
		assert(FileAccess.get_sha256(row.path) == row.sha256)
		report.models.append(record)
		print("MODEL_TEXTURE_AUDIT ", row.identity, " ", record.before)
		await process_frame
	report["combined"] = combined.summary()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MODEL_TEXTURE_SHARING_OK models=", report.models.size(), " ", report.combined)
	quit()
