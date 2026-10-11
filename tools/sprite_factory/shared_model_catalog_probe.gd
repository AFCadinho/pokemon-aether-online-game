extends SceneTree
## Offline producer and independent-process physical-pack verifier.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
var failures: Array[String] = []

class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			print("CATALOG_PROBE_ERROR ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := Sink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()

func produce(job: Dictionary, directory: String, recipe_hash: String) -> Dictionary:
	print("CATALOG_PRODUCE_BEGIN ", job.asset.asset_id)
	assert(DirAccess.make_dir_recursive_absolute(directory.path_join("textures")) == OK)
	assert(DirAccess.make_dir_recursive_absolute(directory.path_join("models")) == OK)
	assert(DirAccess.make_dir_recursive_absolute(directory.path_join("controls")) == OK)
	var recipe: String = str(job.asset.asset_id) + recipe_hash
	for row: Dictionary in job.models:
		recipe += str(row.sha256)
	var resource_root := "res://pokemon-pairs/" + recipe.sha256_text()
	var sharing := Audit.new()
	var combined := Audit.new()
	var records: Array[Dictionary] = []
	var scenes: Array[PackedScene] = []
	for row: Dictionary in job.models:
		assert(FileAccess.get_sha256(row.path) == row.sha256)
		assert(ResourceLoader.get_dependencies(row.path).is_empty())
		var scene := ResourceLoader.load(row.path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		var inspection := Audit.new()
		inspection.inspect(scene)
		combined.textures.append_array(inspection.textures)
		var fingerprint := Audit.signature(scene)
		var control := directory.path_join("controls/" + str(row.variant) + ".scn")
		assert(ResourceSaver.save(scene, control, ResourceSaver.FLAG_COMPRESS) == OK)
		assert(ResourceLoader.get_dependencies(control).is_empty())
		assert(Audit.signature(scene) == fingerprint)
		sharing.share(scene)
		assert(Audit.signature(scene) == fingerprint)
		records.append({"identity": row.identity, "variant": row.variant,
			"source_path": row.path, "source_sha256": row.sha256,
			"semantic_sha256": fingerprint, "source_texture_summary": inspection.summary(),
			"serializer_control_path": control,
			"shared_path": directory.path_join("models/" + str(row.variant) + ".scn")})
		scenes.append(scene)
	for key: String in sharing.pool:
		var texture: ImageTexture = sharing.pool[key]
		var path := directory.path_join("textures/" + key + ".res")
		assert(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) == OK)
		assert(ResourceLoader.get_dependencies(path).is_empty())
		texture.resource_path = resource_root.path_join("textures/" + key + ".res")
	for position in records.size():
		var row: Dictionary = records[position]
		assert(ResourceSaver.save(scenes[position], row.shared_path, ResourceSaver.FLAG_COMPRESS) == OK)
		assert(Audit.signature(scenes[position]) == row.semantic_sha256)
		assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
	return {"asset_id": job.asset.asset_id, "resource_root": resource_root,
		"directory": directory, "models": records, "texture_summary": combined.summary(),
		"texture_files": sharing.pool.size(), "replacements": sharing.replacements}

func validate_pack(pin: Dictionary, directory: String, kind: String, expected: Array) -> Dictionary:
	var asset: Dictionary = pin.asset
	var metadata_error := Pair.metadata_error(asset)
	if not metadata_error.is_empty():
		return {"ok": false, "error": metadata_error}
	var path: String = pin.path
	var installed_bytes := 0
	var sidecar_bytes := 0
	if kind == "shared":
		var object := directory.path_join(str(asset.sha256))
		var installed := Pair.install(path, asset, object)
		if not str(installed.error).is_empty():
			return {"ok": false, "error": str(installed.error)}
		assert(DirAccess.get_files_at(object).size() == 2 and DirAccess.get_directories_at(object).is_empty())
		path = object.path_join("model-pair.pck")
		var sidecar := FileAccess.open(object.path_join("bundle.json"), FileAccess.READ)
		sidecar_bytes = sidecar.get_length()
		installed_bytes = int(asset.size_bytes) + sidecar_bytes
	var checked := Pair.inspect(path, asset)
	if not str(checked.error).is_empty():
		return {"ok": false, "error": str(checked.error)}
	var mounted := Pair.mount_checked(path, asset, checked)
	if not mounted.is_empty():
		return {"ok": false, "error": mounted}
	var scenes: Array[PackedScene] = []
	var textures: Array[Dictionary] = []
	var refs: Array[WeakRef] = []
	for index in expected.size():
		var row: Dictionary = expected[index]
		var model := str(asset.pair_manifest.resource_root).path_join("models/" + str(row.variant) + ".scn")
		var scene := ResourceLoader.load(model, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		assert(Audit.signature(scene) == row.semantic_sha256, "Physical resource graph changed: " + str(row.identity))
		var objects := Contract.textures(scene, {}, {})
		for texture: Texture2D in objects.values():
			refs.append(weakref(texture))
		textures.append(objects)
		scenes.append(scene)
	var shared := 0
	for id: int in textures[0]:
		if textures[1].has(id):
			shared += 1
	var shiny_texture_count: int = textures[1].size()
	textures.clear()
	scenes[0] = null
	assert(Contract.textures(scenes[1], {}, {}).size() == shiny_texture_count, "Shiny lost its textures when normal left")
	scenes.clear()
	return {"ok": true, "error": "", "installed_bytes": installed_bytes,
		"sidecar_bytes": sidecar_bytes, "cross_variant_texture_objects": shared,
		"scenes_exact": expected.size(), "refs": refs}

func _run() -> void:
	assert(DisplayServer.get_name() == "headless" and RenderingServer.get_rendering_device() == null)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3 and args[0] in ["produce", "pack", "validate"])
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	var owned := OS.get_environment("POKEAETHER_CATALOG_WORK_ROOT").trim_suffix("/") + "/"
	assert(owned.is_absolute_path() and directory.is_absolute_path() and directory.simplify_path().begins_with(owned))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	if args[0] == "pack":
		for row: Dictionary in input:
			var packer := PCKPacker.new()
			assert(packer.pck_start(row.path) == OK)
			for file: Dictionary in row.files:
				assert(packer.add_file(file.virtual_path, file.source_path) == OK)
			assert(packer.flush() == OK)
		write_json(directory.path_join("packed.json"), {"ok": true, "packs": input.size()})
	else:
		var receipt := FileAccess.open(directory.path_join("receipts.jsonl"), FileAccess.WRITE)
		assert(receipt != null)
		for job: Dictionary in input.jobs:
			var result: Dictionary
			if args[0] == "produce":
				result = produce(job, directory.path_join(str(job.position)), str(input.recipe_hash))
			else:
				print("CATALOG_VALIDATE_BEGIN ", job.asset_id)
				result = {"asset_id": job.asset_id, "packs": {}}
				for kind: String in job.packs:
					var checked := validate_pack(job.packs[kind], directory.path_join("objects"), kind, job.models)
					var refs: Array = checked.get("refs", [])
					checked.erase("refs")
					await process_frame
					for reference: WeakRef in refs:
						assert(reference.get_ref() == null, "Resources retained after pair release")
					result.packs[kind] = checked
			receipt.store_string(JSON.stringify(result) + "\n")
			receipt.flush()
			print("CATALOG_PROBE_PAIR_OK ", job.get("asset_id", job.get("asset", {}).get("asset_id", "")))
			await process_frame
		receipt.close()
	quit()
