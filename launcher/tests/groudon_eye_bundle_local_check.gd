extends SceneTree

const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")
const ASSET_ID := "pokemon_3d:groudon:base"

func _init() -> void:
	_run.call_deferred()

func _read(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary)
	return data

func _archive(directory: String, asset: Dictionary) -> String:
	return directory.path_join(str(asset.object_key).get_file())

func _catalog(path: String, expected: Dictionary) -> void:
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows is Array and rows.size() == 2)
	var seen := {}
	for row: Dictionary in rows:
		var key := str(row.species) + ("@shiny" if row.variant == "shiny" else "")
		assert(expected.has(key) and expected[key] == row.runtime_sha256)
		assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
		assert(ResourceLoader.load(row.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
		seen[key] = true
	assert(seen.has("groudon") and seen.has("groudon@shiny"))

func _run() -> void:
	var old_dir := OS.get_environment("POKEAETHER_GROUDON_OLD_BUNDLE_DIR")
	var new_dir := OS.get_environment("POKEAETHER_GROUDON_NEW_BUNDLE_DIR")
	var output := OS.get_environment("POKEAETHER_GROUDON_BUNDLE_TEST_OUTPUT")
	assert(old_dir.is_absolute_path() and new_dir.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output))
	var old_index := _read(old_dir.path_join("asset-index.json"))
	var new_index := _read(new_dir.path_join("combined-index.json"))
	assert(Index.validate(old_index).is_empty() and Index.validate(new_index).is_empty())
	var old_asset: Dictionary = Index.by_id(old_index)[ASSET_ID]
	var new_asset: Dictionary = Index.by_id(new_index)[ASSET_ID]
	assert(old_asset.version == 1 and new_asset.version == 2)
	var store := Store.new(output.path_join("store"))
	assert(store.plan(old_index, [ASSET_ID]).downloads == [ASSET_ID])
	assert(store.install_archive(old_index, ASSET_ID, _archive(old_dir, old_asset)).error.is_empty())
	_catalog(store.catalog_path(), {"groudon": old_asset.appearances[0].runtime_sha256,
		"groudon@shiny": old_asset.appearances[1].runtime_sha256})
	assert(store.plan(old_index, [ASSET_ID]).downloads.is_empty())
	assert(store.plan(new_index, [ASSET_ID]).downloads == [ASSET_ID])
	var generation := store.active_generation()
	var bytes := FileAccess.get_file_as_bytes(_archive(new_dir, new_asset))
	bytes.resize(bytes.size() / 2)
	var corrupt := output.path_join("corrupt.zip")
	var file := FileAccess.open(corrupt, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	assert(not store.install_archive(new_index, ASSET_ID, corrupt).error.is_empty())
	assert(store.active_generation() == generation)
	assert(store.install_archive(new_index, ASSET_ID, _archive(new_dir, new_asset)).error.is_empty())
	_catalog(store.catalog_path(), {"groudon": new_asset.appearances[0].runtime_sha256,
		"groudon@shiny": new_asset.appearances[1].runtime_sha256})
	store = Store.new(output.path_join("store"))
	assert(store.plan(new_index, [ASSET_ID]).downloads.is_empty())
	assert(store.plan(old_index, [ASSET_ID]).downloads == [ASSET_ID])
	print("GROUDON_EYE_BUNDLE_LOCAL_OK install=true no_op=true single_update=true corruption=true restart=true scenes=2")
	quit()
