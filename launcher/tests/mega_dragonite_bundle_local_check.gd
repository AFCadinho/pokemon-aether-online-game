extends SceneTree
## Local candidate bundle transaction test; does not change a release descriptor.
const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")
const BASE_ID := "pokemon_3d:dragonite:base"
const MEGA_ID := "pokemon_3d:dragonite:mega"

func _init() -> void:
	_run.call_deferred()

func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary)
	return value

func _archive(directory: String, asset: Dictionary) -> String:
	return directory.path_join(str(asset.object_key).get_file())

func _corrupt(source: String, destination: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(source)
	bytes.resize(bytes.size() / 2)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()

func _catalog(path: String) -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Array and value.size() == 4)
	var identities := {}
	for entry: Dictionary in value:
		var identity := str(entry.species) + ("@shiny" if entry.variant == "shiny" else "")
		identities[identity] = true
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	assert(identities.has("dragonite") and identities.has("dragonite@shiny"))
	assert(identities.has("dragonite-mega") and identities.has("dragonite-mega@shiny"))

func _run() -> void:
	var base_dir := OS.get_environment("POKEAETHER_MEGA_BASE_BUNDLE_DIR")
	var mega_v1_dir := OS.get_environment("POKEAETHER_MEGA_BUNDLE_V1_DIR")
	var mega_v2_dir := OS.get_environment("POKEAETHER_MEGA_BUNDLE_V2_DIR")
	var output := OS.get_environment("POKEAETHER_MEGA_BUNDLE_TEST_OUTPUT")
	assert(base_dir.is_absolute_path() and mega_v1_dir.is_absolute_path() and mega_v2_dir.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	var first := _read(mega_v1_dir.path_join("combined-index.json"))
	var second := _read(mega_v2_dir.path_join("combined-index.json"))
	assert(Index.validate(first).is_empty() and Index.validate(second).is_empty())
	var first_assets := Index.by_id(first)
	var second_assets := Index.by_id(second)
	var store := Store.new(output.path_join("store"))
	var plan: Dictionary = store.plan(first, [MEGA_ID])
	assert(plan.error.is_empty() and plan.downloads == [BASE_ID, MEGA_ID])
	var base_path := _archive(base_dir, first_assets[BASE_ID])
	var mega_v1_path := _archive(mega_v1_dir, first_assets[MEGA_ID])
	var mega_v2_path := _archive(mega_v2_dir, second_assets[MEGA_ID])
	assert(store.install_archive(first, BASE_ID, base_path).error.is_empty())
	var base_generation := store.active_generation()
	var corrupt := output.path_join("corrupt-mega.zip")
	_corrupt(mega_v1_path, corrupt)
	assert(not store.install_archive(first, MEGA_ID, corrupt).error.is_empty())
	assert(store.active_generation() == base_generation)
	assert(store.install_archive(first, MEGA_ID, mega_v1_path).error.is_empty())
	_catalog(store.catalog_path())
	plan = store.plan(first, [MEGA_ID])
	assert(plan.error.is_empty() and plan.downloads.is_empty() and plan.unchanged == [BASE_ID, MEGA_ID])
	store = Store.new(output.path_join("store"))
	assert(store.plan(first, [MEGA_ID]).downloads.is_empty())
	var old_generation := store.active_generation()
	plan = store.plan(second, [MEGA_ID])
	assert(plan.error.is_empty() and plan.downloads == [MEGA_ID] and plan.unchanged == [BASE_ID])
	_corrupt(mega_v2_path, corrupt)
	assert(not store.install_archive(second, MEGA_ID, corrupt).error.is_empty())
	assert(store.active_generation() == old_generation)
	assert(store.install_archive(second, MEGA_ID, mega_v2_path).error.is_empty())
	_catalog(store.catalog_path())
	assert(store.state().assets[BASE_ID].archive_sha256 == first_assets[BASE_ID].sha256)
	store = Store.new(output.path_join("store"))
	assert(store.plan(second, [MEGA_ID]).downloads.is_empty())
	assert(store.plan(first, [MEGA_ID]).downloads == [MEGA_ID])
	assert(store.install_archive(first, MEGA_ID, mega_v1_path).error.is_empty())
	_catalog(store.catalog_path())
	print("MEGA_DRAGONITE_BUNDLE_LOCAL_OK install=true no_op=true single_update=true corruption=true restart=true rollback=true scenes=4")
	quit()
