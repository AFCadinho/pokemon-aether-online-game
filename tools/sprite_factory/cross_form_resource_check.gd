extends SceneTree
## Offline semantic comparison of already externalized resources. No actors.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Geometry = preload("res://tools/sprite_factory/model_geometry_audit.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")

class Sink extends Logger:
	var errors: Array[String] = []
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
			tree.call_deferred("quit", 2)

var sink := Sink.new()

func embedded_inventory(scene: PackedScene, identity: String, schema: int, rows: Array[Dictionary]) -> void:
	var audit := Audit.new()
	audit.inspect(scene)
	for texture: Dictionary in audit.textures:
		# Schema-1 scenes already use external textures, counted in the archive
		# inventory. ZIP scenes keep theirs embedded.
		if schema == 0:
			rows.append({"asset_id": identity, "category": "textures", "signature": texture.texture_signature,
				"eligible": texture.shareable, "image_bytes": texture.bytes})
	var inventory := Geometry.inventory(scene)
	for category: String in ["meshes", "skins", "libraries"]:
		for resource: Resource in inventory[category]:
			var signature := Geometry.mesh_key(resource) if resource is ArrayMesh else Audit.signature(resource)
			var eligible := not resource.resource_local_to_scene
			if resource is AnimationLibrary:
				eligible = eligible and Geometry.sensitive_tracks(resource).is_empty()
			rows.append({"asset_id": identity, "category": category, "signature": signature, "eligible": eligible})

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2, "Expected absolute job/report paths")
	var job_path: String = args[0]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	var rows: Array[Dictionary] = []
	var embedded_rows: Array[Dictionary] = []
	var embedded_pairs := 0
	for job: Dictionary in config.jobs:
		var pck: bool = job.asset.get("format") == Pair.FORMAT
		if pck:
			var checked := Pair.inspect(job.source, job.asset)
			assert(str(checked.error).is_empty(), str(checked.error))
			assert(Pair.mount_checked(job.source, job.asset, checked).is_empty())
		for relative: String in job.resources:
			var path := str(job.asset.pair_manifest.resource_root).path_join(relative)
			var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			assert(resource != null)
			var category := relative.get_slice("/", 0)
			assert((category == "textures" and resource is ImageTexture) or (category == "meshes" and resource is ArrayMesh) or (category == "skins" and resource is Skin) or (category == "libraries" and resource is AnimationLibrary))
			var signature := Geometry.mesh_key(resource) if resource is ArrayMesh else Audit.signature(resource)
			assert(signature == relative.get_file().trim_suffix(".res"), "Resource filename is not its full semantic signature")
			rows.append({"asset_id": job.asset.asset_id, "path": relative, "sha256": FileAccess.get_sha256(path),
				"signature": signature, "class": resource.get_class(), "local_to_scene": resource.resource_local_to_scene,
				"dependencies": ResourceLoader.get_dependencies(path).size(),
				"sensitive_tracks": Geometry.sensitive_tracks(resource).size() if resource is AnimationLibrary else 0})
		if job.inspect_embedded:
			embedded_pairs += 1
			for appearance: Dictionary in job.asset.appearances:
				var path: String
				var schema: int = job.asset.get("pair_manifest", {}).get("schema", 0)
				if pck:
					path = str(job.asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
				else:
					assert(FileAccess.get_sha256(job.source) == job.asset.sha256)
					var zip := ZIPReader.new()
					assert(zip.open(job.source) == OK)
					var payload := zip.read_file("models/" + str(appearance.variant) + ".scn")
					assert(Audit.digest(payload) == appearance.runtime_sha256)
					path = job_path.get_base_dir().path_join("extracted/" + str(job.asset.asset_id).sha256_text() + "/" + str(appearance.variant) + ".scn")
					DirAccess.make_dir_recursive_absolute(path.get_base_dir())
					var file := FileAccess.open(path, FileAccess.WRITE)
					file.store_buffer(payload)
					file.close()
					zip.close()
				var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
				assert(scene != null)
				embedded_inventory(scene, job.asset.asset_id, schema, embedded_rows)
		print("RESOURCE_PACK_OK ", job.asset.asset_id)
	var report := {"schema": 1, "complete": true, "errors": sink.errors, "resources": rows,
		"embedded_resources": embedded_rows, "embedded_pairs": embedded_pairs,
		"job_sha256": FileAccess.get_sha256(job_path), "script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"godot": Engine.get_version_info().string}
	assert(sink.errors.is_empty())
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report) + "\n")
	output.close()
	print("RESOURCE_CHECK_OK occurrences=", rows.size())
	quit()
