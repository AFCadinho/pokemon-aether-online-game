extends SceneTree
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Geometry = preload("res://tools/sprite_factory/model_geometry_audit.gd")
var failed := false

class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			print("GEOMETRY_PROBE_ERROR ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := Sink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

func compare(job: Dictionary, output: String) -> Dictionary:
	var asset: Dictionary = job.asset
	assert(FileAccess.get_sha256(job.source) == asset.sha256)
	var shared: bool = asset.get("format") == "model-pair-pck-v1"
	var paths := []
	if shared:
		assert(ProjectSettings.load_resource_pack(job.source, false))
		for appearance: Dictionary in asset.appearances:
			paths.append(str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path))
	else:
		var archive := ZIPReader.new()
		assert(archive.open(job.source) == OK)
		for appearance: Dictionary in asset.appearances:
			var name := "models/" + str(appearance.variant) + ".scn"
			var payload := archive.read_file(name)
			assert(Audit.digest(payload) == appearance.runtime_sha256)
			var path := output.path_join(str(appearance.variant) + ".scn")
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(payload)
			file.close()
			paths.append(path)
		archive.close()
	var records := []
	var pools := {"meshes": {}, "skins": {}, "libraries": {}}
	for position in paths.size():
		var scene := ResourceLoader.load(paths[position], "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var inventory := Geometry.inventory(scene)
		var memo := {}
		var record := {"variant": asset.appearances[position].variant, "structure": Geometry.structure(scene),
			"skeletons": Geometry.skeletons(scene), "bindings": Geometry.bindings(scene, memo),
			"meshes": [], "skins": [], "libraries": [], "sensitive_tracks": []}
		for category: String in pools:
			for resource: Resource in inventory[category]:
				var key: String = Geometry.mesh_key(resource) if category == "meshes" else Audit.signature(resource, memo)
				record[category].append({"key": key, "local_to_scene": resource.resource_local_to_scene})
				if not pools[category].has(key):
					var path := output.path_join(category + "-" + key + ".res")
					var detached: Resource = Geometry.bare_mesh(resource) if category == "meshes" else resource
					assert(ResourceSaver.save(detached, path, ResourceSaver.FLAG_COMPRESS) == OK)
					assert(ResourceLoader.get_dependencies(path).is_empty())
					pools[category][key] = {"path": path, "variants": [], "shareable": not resource.resource_local_to_scene}
				pools[category][key].variants.append(record.variant)
				pools[category][key].shareable = pools[category][key].shareable and not resource.resource_local_to_scene
				if resource is AnimationLibrary:
					record.sensitive_tracks.append_array(Geometry.sensitive_tracks(resource))
		records.append(record)
	assert(records.size() == 2 and records[0].variant != records[1].variant)
	return {"asset_id": asset.asset_id, "source_sha256": asset.sha256, "source_bytes": asset.size_bytes,
		"baseline_shared_textures": shared, "variants": records, "components": pools,
		"same_structure": records[0].structure == records[1].structure,
		"same_mesh_bindings": not records[0].bindings.meshes.is_empty() and records[0].bindings.meshes == records[1].bindings.meshes,
		"same_skin_bindings": records[0].bindings.skins == records[1].bindings.skins,
		"same_animation_bindings": not records[0].bindings.libraries.is_empty() and records[0].bindings.libraries == records[1].bindings.libraries,
		"same_skeleton": not records[0].skeletons.is_empty() and records[0].skeletons == records[1].skeletons}

func _run() -> void:
	assert(DisplayServer.get_name() == "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output: String = args[1]
	assert(not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var receipt := FileAccess.open(output.path_join("records.jsonl"), FileAccess.WRITE)
	for index in config.jobs.size():
		var directory := output.path_join(str(index))
		assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
		var row := compare(config.jobs[index], directory)
		receipt.store_line(JSON.stringify(row))
		receipt.flush()
		print("GEOMETRY_PAIR_OK ", row.asset_id)
		await process_frame
	receipt.close()
	print("SHARED_GEOMETRY_BATCH_OK pairs=", config.jobs.size())
	quit()
