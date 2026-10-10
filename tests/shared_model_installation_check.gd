extends SceneTree
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
var failures: Array[String] = []

class Sink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := Sink.new()

func _init() -> void:
	_run.call_deferred()

func check(value: bool, reason: String) -> bool:
	if not value:
		failures.append(reason)
		print("SHARED_MODEL_FAIL ", reason)
	return value

func changed_pack(source: String, destination: String, offset: int, value: int, asset: Dictionary) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(source)
	bytes.encode_u32(offset, value)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var pin := asset.duplicate(true)
	pin.sha256 = FileAccess.get_sha256(destination)
	return pin

func _load_pair(asset: Dictionary, directory: String) -> Array[WeakRef]:
	var entries := Pair.catalog_entries(asset, directory)
	var checked := Pair.inspect(str(entries[0].pack_path), asset)
	if not check(str(checked.error).is_empty(), "Installed physical pack integrity"):
		return []
	if not check(Pair.mount_checked(str(entries[0].pack_path), asset, checked).is_empty(), "Mount/closed dependencies"):
		return []
	var scenes: Array[PackedScene] = []
	var objects: Array[Dictionary] = []
	var weak: Array[WeakRef] = []
	for i in 2:
		var scene := ResourceLoader.load(str(entries[i].runtime_path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if not check(scene != null, "Native scene loads"):
			return []
		check(Audit.signature(scene) == asset.appearances[i].semantic_sha256, "Complete source semantic graph: " + str(asset.appearances[i].runtime_identity))
		var textures := Contract.textures(scene, {}, {})
		for texture: Texture2D in textures.values():
			weak.append(weakref(texture))
		objects.append(textures)
		scenes.append(scene)
	var shared := 0
	for id: int in objects[0]:
		if objects[1].has(id):
			shared += 1
	check(shared > 0, "Normal/shiny share actual texture objects")
	objects.clear()
	scenes[0] = null
	check(not Contract.textures(scenes[1], {}, {}).is_empty(), "Shiny survives normal release")
	scenes.clear()
	return weak

func _run() -> void:
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	if not check(args.size() == 1 and args[0].is_absolute_path(), "Owned pilot pack directory"):
		quit(1)
		return
	var packs: String = args[0]
	var index: Dictionary = Pilot.DATA.data
	var first: Dictionary = index.assets[0]
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PILOT")
	check(Reviewed.resolve(str(first.appearances[0].runtime_identity), str(first.appearances[0].runtime_sha256)).is_empty(), "Pilot rejected by default")
	OS.set_environment("POKEAETHER_SHARED_MODEL_PILOT", "1")
	OS.set_environment("POKEAETHER_MODEL_PAIR_PACKS", packs)
	var index_error := Index.validate(index)
	if not check(index_error.is_empty(), "Runtime contract 2 index: " + index_error):
		quit(1)
		return
	var old_contract := index.duplicate(true)
	old_contract.runtime_contract.pokemon_3d = 1
	check(not Index.validate(old_contract).is_empty(), "v11 cannot silently admit external resources")
	var path := packs.path_join(str(first.object_key).get_file())
	check(str(Pair.inspect(path, first).error).is_empty(), "Exact physical PCK validation")
	var task_root := "user://shared-model-install-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(task_root)
	var damaged_path := task_root.path_join("damaged.pck")
	for mutation in [[0, 0], [4, 4], [20, 3], [32, 0x7fffffff]]:
		var bad := changed_pack(path, damaged_path, mutation[0], mutation[1], first)
		check(not str(Pair.inspect(damaged_path, bad).error).is_empty(), "Invalid magic/version/flags/directory offset rejected before mount")
	var metadata := first.duplicate(true)
	metadata.pair_manifest.files[0].path = "../outside.gd"
	check(not Pair.metadata_error(metadata).is_empty(), "Traversal rejected")
	metadata = first.duplicate(true)
	metadata.pair_manifest.files.append(metadata.pair_manifest.files[0].duplicate())
	check(not Pair.metadata_error(metadata).is_empty(), "Duplicate member rejected")
	metadata = first.duplicate(true)
	metadata.pair_manifest.files[0].decoded_bytes = Pair.MAX_PACK + 1
	check(not Pair.metadata_error(metadata).is_empty(), "Unbounded decoded data rejected")
	var store := Store.new(task_root.path_join("store"))
	var ids: Array[String] = []
	for asset: Dictionary in index.assets:
		ids.append(str(asset.asset_id))
	var transaction := store.begin_collection(index, ids)
	check(str(transaction.error).is_empty() and transaction.downloads.size() == index.assets.size(), "Collection planning including legacy form dependencies")
	check(str(store.stage_collection(transaction, str(first.asset_id), path).error).is_empty(), "First staged pack")
	check(store.active_generation().is_empty(), "Incomplete collection never activates")
	var resumed := Store.new(task_root.path_join("store"))
	transaction = resumed.begin_collection(index, ids)
	check(transaction.downloads.size() == index.assets.size() - 1, "Interrupted installation reuses verified immutable object")
	check(not str(resumed.stage_collection(transaction, str(index.assets[1].asset_id), damaged_path).error).is_empty(), "Failed stage cannot publish collection")
	for asset_id: String in transaction.downloads.duplicate():
		var asset: Dictionary = Index.by_id(index)[asset_id]
		var source_root := packs if asset.get("format") == Pair.FORMAT else packs.get_base_dir().get_base_dir().path_join("lossless-catalog-v1/prepared/archives")
		var archive := source_root.path_join(str(asset.object_key).get_file())
		var stage_result := resumed.stage_collection(transaction, str(asset.asset_id), archive)
		check(str(stage_result.error).is_empty(), "Stage " + str(asset.asset_id) + ": " + str(stage_result.error))
	if not check(str(resumed.finish_collection(transaction).error).is_empty(), "Atomic complete collection activation"):
		print(failures)
		quit(1)
		return
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(resumed.catalog_path()))
	check(catalog.size() == index.assets.size() * 2, "Portable catalog has both appearances, including legacy fallback")
	check(Store.new(task_root.path_join("store")).begin_collection(index, ids).downloads.is_empty(), "Restart requires no new downloads")
	var physical := resumed._objects_root().path_join(str(first.sha256))
	var generation := resumed.active_generation()
	var corrupt := FileAccess.open(physical.path_join("model-pair.pck"), FileAccess.WRITE)
	corrupt.store_string("damaged")
	corrupt.close()
	check(not str(Pair.object_check(physical, first).error).is_empty(), "Corrupted installed pack rejected")
	check(str(Pair.install(path, first, physical).error).is_empty() and resumed.active_generation() == generation, "Verified repair preserves the catalog generation")
	var total := 0
	for asset: Dictionary in index.assets:
		if asset.get("format") != Pair.FORMAT:
			continue
		var object := resumed._objects_root().path_join(str(asset.sha256))
		var folder := DirAccess.open(object)
		check(folder.get_directories().is_empty() and folder.get_files().size() == 2, "One PCK plus metadata; no extracted duplicate payload")
		check(Pair.budget(asset, "normal") >= int(asset.appearances[0].cache_source_bytes), "Original cache admission floor retained")
		var weak := _load_pair(asset, object)
		await process_frame
		for reference: WeakRef in weak:
			check(reference.get_ref() == null, "Textures expire after both variants leave")
		total += int(asset.size_bytes)
	check(Pair.protects(task_root.path_join("store")), "Mounted physical files are protected")
	check(preload("res://scripts/services/desktop_asset_storage.gd").register_model_usage(resumed.root, OS.get_process_id()) == OK, "Game registers the launcher store lease")
	check(not str(resumed.garbage_collect().error).is_empty(), "Mounted pack cleanup is deferred")
	var service := Service.new()
	root.add_child(service)
	var identities: Array[String] = []
	for appearance: Dictionary in first.appearances:
		identities.append(str(appearance.runtime_identity))
	var installed := service._unpack_asset(first, path)
	check(str(installed.error).is_empty() and installed.entries.size() == 2, "Independent on-demand installer")
	var catalog_path := service._publish_catalog(installed.entries)
	var ready := await service.ensure_models(identities, catalog_path)
	check(str(ready.error).is_empty() and ready.path == catalog_path and service.active_request == null, "On-demand restart reuses pack without HTTP")
	service.queue_free()
	await process_frame
	check(FileAccess.get_file_as_bytes("res://scripts/services/model_pair_pack.gd") == FileAccess.get_file_as_bytes("res://launcher/scripts/model_pair_pack.gd"), "Launcher/game validators stay identical")
	check(FileAccess.get_file_as_bytes("res://data/model_pair_pilot.json") == FileAccess.get_file_as_bytes("res://launcher/data/model_pair_pilot.json"), "Both exports pin the same pilot")
	if not sink.errors.is_empty():
		failures.append_array(sink.errors)
	print("SHARED_MODEL_INSTALLATION_CHECK ", "OK" if failures.is_empty() else "FAILED", " pairs=16 scenes=32 bytes=", total, " errors=", failures)
	quit(0 if failures.is_empty() else 1)
