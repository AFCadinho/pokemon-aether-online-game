extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	OS.set_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST", "1")
	var index := Pilot.catalog().duplicate(true)
	var asset: Dictionary = index.assets[0]
	index.assets = [asset]
	var original: Dictionary = load("res://release/approved_3d_bundles_v11_index.json").data.duplicate(true)
	original.assets = [original.assets[0]]
	var ids: Array[String] = [str(asset.asset_id)]
	for with_fallback in [false, true]:
		var store := Store.new("user://collection-repair-" + str(Time.get_ticks_usec()))
		var prior := ""
		if with_fallback:
			assert(store.install_archive(original, asset.asset_id, config.original_sources[asset.asset_id]).error.is_empty())
			prior = store.active_generation()
		assert(store.install_archive(index, asset.asset_id, config.sources[asset.asset_id]).error.is_empty())
		var generation := store.active_generation()
		var path := store._objects_root().path_join(asset.sha256).path_join("model-pair.pck")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("owned corrupt repair fixture")
		file.close()
		assert(store.active_generation() == prior)
		var session := store.begin_collection(index, ids)
		assert(session.downloads == ids and session.generation == prior)
		assert(store.stage_collection(session, asset.asset_id, config.sources[asset.asset_id]).error.is_empty())
		assert(store.active_generation() == generation)
		assert(store.finish_collection(session).error.is_empty(), "A repaired generation is not a concurrent publication")
		assert(store.active_generation() == generation)
		var stale := store.begin_collection(index, ids)
		var changed := store.state()
		changed.catalog_revision = "concurrent-publication"
		assert(store._write_generation(changed).is_empty())
		var concurrent := store.active_generation()
		assert(concurrent != generation and not store.finish_collection(stale).error.is_empty())
		assert(store.active_generation() == concurrent, "Stale collection cannot overwrite another publication")
	print("SHARED_MODEL_COLLECTION_REPAIR_CHECK_OK empty_and_previous_fallback=true concurrent_publication_rejected=true")
	quit()
