extends SceneTree
## One isolated process per pack/configuration; identical virtual namespaces
## cannot resolve dependencies from a previously loaded baseline/candidate.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")

class ErrorSink extends Logger:
	var errors: Array = []
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
			if tree != null: tree.call_deferred("quit", 2)

var sink := ErrorSink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	run.call_deferred()

static func peak_rss() -> int:
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null: return 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("VmHWM:"):
			return int(line.trim_prefix("VmHWM:").strip_edges().split("kB")[0]) * 1024
	return 0

static func pose(actor: Node) -> String:
	var values := []
	for node in [actor] + actor.find_children("*", "", true, false):
		if node.get_class() == "PhysicalBoneSimulator3D" and node.owner == null: continue
		var path := str(actor.get_path_to(node))
		if node is Node3D: values.append([path, node.transform, node.visible])
		if node is Skeleton3D:
			node.force_update_all_bone_transforms()
			for bone in node.get_bone_count(): values.append(node.get_bone_pose(bone))
		if node is MeshInstance3D:
			for shape in node.get_blend_shape_count(): values.append(node.get_blend_shape_value(shape))
	return Audit.signature(values)

static func motion(actor: Node) -> Dictionary:
	var results := {}
	for player in actor.find_children("*", "AnimationPlayer", true, false):
		for action in player.get_animation_list():
			for fraction in [0.0, 0.5, 0.999]:
				player.stop()
				for skeleton in actor.find_children("*", "Skeleton3D", true, false): skeleton.reset_bone_poses()
				player.play(action)
				player.pause()
				player.seek(player.get_animation(action).length * fraction, true)
				results[str(actor.get_path_to(player)) + ":" + str(action) + ":" + str(fraction)] = pose(actor)
	return results

static func retire(actor: Node) -> void:
	var materials := []
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		materials.append(node.material_override)
		materials.append(node.material_overlay)
		for surface in node.mesh.get_surface_count():
			materials.append(node.get_surface_override_material(surface))
			materials.append(node.mesh.surface_get_material(surface))
	actor.free()
	materials.clear()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var asset: Dictionary = job.asset
	assert(FileAccess.get_sha256(job.pack) == asset.sha256)
	var result := {"asset_id": job.asset_id, "label": job.label, "godot": Engine.get_version_info().string,
		"appearances": [], "load_instantiate_ms": [], "complete": false, "errors": []}
	if job.format == "pck":
		var inspection := Pair.inspect(job.pack, asset)
		result["production_validator_error"] = inspection.error
		if job.expect_production_codec:
			assert(str(inspection.error).is_empty(), str(inspection.error))
			var mount_error := Pair.mount_checked(job.pack, asset, inspection)
			assert(mount_error.is_empty(), mount_error)
			result["production_mount_error"] = mount_error
		else:
			assert(inspection.error == "Model-pair decoded size/codec mismatch.", "Unexpected validator outcome")
			# Larger blocks have passed independent physical/hash checks but
			# deliberately fail the current production admission rule above.
			assert(ProjectSettings.load_resource_pack(job.pack, false))
	for appearance: Dictionary in asset.appearances:
		var relative := "models/" + str(appearance.variant) + ".scn"
		var path: String = str(asset.pair_manifest.resource_root).path_join(relative) if job.format == "pck" else str(job.scene_directory).path_join(relative)
		assert(FileAccess.get_sha256(path) == appearance.runtime_sha256)
		var cycles := int(job.get("load_cycles", 3))
		assert(cycles >= 1 and cycles <= 3)
		for cycle in cycles:
			var start := Time.get_ticks_usec()
			var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			assert(scene != null)
			var actor := scene.instantiate()
			result.load_instantiate_ms.append((Time.get_ticks_usec() - start) / 1000.0)
			root.add_child(actor)
			if cycle == 0:
				if job.get("load_only", false):
					result.appearances.append({"variant": appearance.variant, "runtime_sha256": appearance.runtime_sha256, "loaded": true})
				else:
					result.appearances.append({"variant": appearance.variant, "semantic_sha256": Audit.signature(scene), "motion": motion(actor)})
			retire(actor)
			scene = null
	result.errors = sink.errors.duplicate()
	result["peak_rss_bytes"] = peak_rss()
	result.complete = sink.errors.is_empty()
	var out := FileAccess.open(job.output, FileAccess.WRITE)
	assert(out != null)
	out.store_string(JSON.stringify(result, "\t") + "\n")
	out.close()
	quit(0 if result.complete else 2)
