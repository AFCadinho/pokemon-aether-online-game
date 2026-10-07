extends SceneTree
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() == "headless" and RenderingServer.get_rendering_device() == null)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: String = args[1]
	assert(output.simplify_path().begins_with(ProjectSettings.globalize_path("res://.tmp/")))
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	var pairs := {}
	for row: Dictionary in input.models:
		var species: String = str(row.identity).trim_suffix("@shiny")
		if not pairs.has(species):
			pairs[species] = []
		pairs[species].append(row)
	var report := {"schema": 1, "prototype_only": true, "pairs": [], "models": []}
	for species: String in pairs:
		assert(pairs[species].size() == 2)
		var directory := output.path_join(species)
		DirAccess.make_dir_recursive_absolute(directory.path_join("textures"))
		DirAccess.make_dir_recursive_absolute(directory.path_join("models"))
		var sharing := Audit.new()
		var recipe := species + FileAccess.get_sha256("res://tools/sprite_factory/model_pair_texture_probe.gd")
		for source: Dictionary in pairs[species]:
			recipe += str(source.sha256)
		var pack_root := "res://model-pair-experiment/" + recipe.sha256_text()
		var records := []
		var retained: Array[PackedScene] = []
		for row: Dictionary in pairs[species]:
			assert(FileAccess.get_sha256(row.path) == row.sha256)
			assert(ResourceLoader.get_dependencies(row.path).is_empty())
			var scene := ResourceLoader.load(row.path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			assert(scene != null)
			var fingerprint := Audit.signature(scene)
			sharing.share(scene)
			assert(Audit.signature(scene) == fingerprint)
			var variant := "shiny" if str(row.identity).ends_with("@shiny") else "normal"
			records.append({"identity": row.identity, "variant": variant, "source_path": row.path,
				"source_sha256": row.sha256, "semantic_sha256": fingerprint,
				"candidate_path": directory.path_join("models/" + variant + ".scn")})
			retained.append(scene)
		# Only this pair owns the temporary canonical pool. It is not a runtime
		# global cache, and unrelated species do not acquire new dependencies.
		for key: String in sharing.pool:
			var texture: ImageTexture = sharing.pool[key]
			var path := directory.path_join("textures/" + key + ".res")
			var localized := ProjectSettings.localize_path(path)
			assert(ResourceSaver.save(texture, localized, ResourceSaver.FLAG_COMPRESS) == OK)
			texture.resource_path = pack_root.path_join("shared/textures/" + key + ".res")
			assert(ResourceLoader.get_dependencies(path).is_empty())
		for index in records.size():
			var row: Dictionary = records[index]
			assert(ResourceSaver.save(retained[index], ProjectSettings.localize_path(row.candidate_path),
				ResourceSaver.FLAG_COMPRESS) == OK)
			assert(Audit.signature(retained[index]) == row.semantic_sha256)
			row["candidate_sha256"] = FileAccess.get_sha256(row.candidate_path)
			report.models.append(row)
			assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
		report.pairs.append({"species": species, "directory": directory, "namespace": pack_root,
			"texture_files": sharing.pool.size(), "replacements": sharing.replacements, "models": records})
		print("MODEL_PAIR_TEXTURES_OK ", species, " textures=", sharing.pool.size(), " replacements=", sharing.replacements)
		await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	quit()
