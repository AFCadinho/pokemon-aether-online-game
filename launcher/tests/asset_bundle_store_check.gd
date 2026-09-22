extends SceneTree
const Index = preload("res://scripts/asset_bundle_index.gd")
const Store = preload("res://scripts/asset_bundle_store.gd")

var output: String


func _init() -> void:
	_run.call_deferred()


func _scene_bytes(species: String, variant: String, revision: int) -> PackedByteArray:
	var node := Node3D.new()
	node.name = "%s_%s_v%d" % [species, variant, revision]
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	node.free()
	var path := output.path_join(".%s-%s-v%d.scn" % [species, variant, revision])
	assert(ResourceSaver.save(scene, path) == OK)
	var bytes := FileAccess.get_file_as_bytes(path)
	assert(not bytes.is_empty())
	assert(DirAccess.remove_absolute(path) == OK)
	return bytes


func _write_bundle(species: String, version: int, revision: int) -> Dictionary:
	var appearances := []
	var payloads := {}
	for variant in ["normal", "shiny"]:
		var bytes := _scene_bytes(species, variant, revision)
		var path := "models/%s.scn" % variant
		var digest := Store._hash(bytes)
		payloads[path] = bytes
		appearances.append({
			"variant": variant,
			"runtime_identity": species + ("@shiny" if variant == "shiny" else ""),
			"runtime_path": path,
			"runtime_sha256": digest,
			"bytes": bytes.size(),
		})
	var asset_id := "pokemon_3d:%s:base" % species
	var manifest := {
		"schema": 1,
		"kind": "pokeaether-asset-bundle",
		"asset_id": asset_id,
		"asset_type": "pokemon_3d",
		"species_id": species,
		"form_id": "base",
		"version": version,
		"dependencies": [],
		"appearances": appearances,
	}
	var archive_path := output.path_join("%s-v%d.zip" % [species, version])
	var writer := ZIPPacker.new()
	assert(writer.open(archive_path) == OK)
	assert(writer.start_file("bundle.json") == OK)
	writer.write_file((JSON.stringify(manifest, "\t") + "\n").to_utf8_buffer())
	writer.close_file()
	for path: String in payloads:
		assert(writer.start_file(path) == OK)
		writer.write_file(payloads[path])
		writer.close_file()
	assert(writer.close() == OK)
	var archive := FileAccess.open(archive_path, FileAccess.READ)
	var archive_size := archive.get_length()
	archive.close()
	return {
		"archive_path": archive_path,
		"asset": {
			"asset_id": asset_id,
			"asset_type": "pokemon_3d",
			"species_id": species,
			"national_dex": {"dragonite": 149, "arcanine": 59, "roaring-moon": 1005}[species],
			"form_id": "base",
			"version": version,
			"size_bytes": archive_size,
			"sha256": FileAccess.get_sha256(archive_path),
			"object_key": "optional-assets/pokemon_3d/%s/base/v%d-%s.zip" % [species, version, FileAccess.get_sha256(archive_path)],
			"dependencies": [],
			"appearances": appearances.map(func(item: Dictionary): return {
				"variant": item.variant,
				"runtime_identity": item.runtime_identity,
				"runtime_sha256": item.runtime_sha256,
			}),
		},
	}


func _index(bundles: Array, revision: String) -> Dictionary:
	return {
		"schema": 1,
		"kind": "pokeaether-optional-asset-index",
		"catalog_revision": revision,
		"runtime_contract": {"pokemon_3d": 1, "godot": "4.6"},
		"assets": bundles.map(func(bundle: Dictionary): return bundle.asset),
	}


func _catalog_identities(path: String) -> Array[String]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Array)
	var result: Array[String] = []
	for entry: Dictionary in parsed:
		var identity := str(entry.species) + ("@shiny" if entry.variant == "shiny" else "")
		result.append(identity)
		assert(FileAccess.file_exists(entry.runtime_path))
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		assert(ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) is PackedScene)
	result.sort()
	return result


func _copy_corrupt(source: String, destination: String, truncate := false) -> void:
	var bytes := FileAccess.get_file_as_bytes(source)
	if truncate:
		bytes.resize(maxi(1, bytes.size() / 2))
	else:
		bytes[0] = bytes[0] ^ 0xff
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _wrong_manifest_archive(source: String, destination: String) -> void:
	var reader := ZIPReader.new()
	assert(reader.open(source) == OK)
	var manifest: Dictionary = JSON.parse_string(reader.read_file("bundle.json").get_string_from_utf8())
	manifest["species_id"] = "arcanine"
	var payloads := {
		"models/normal.scn": reader.read_file("models/normal.scn"),
		"models/shiny.scn": reader.read_file("models/shiny.scn"),
	}
	reader.close()
	var writer := ZIPPacker.new()
	assert(writer.open(destination) == OK)
	writer.start_file("bundle.json")
	writer.write_file((JSON.stringify(manifest, "\t") + "\n").to_utf8_buffer())
	writer.close_file()
	for name: String in payloads:
		writer.start_file(name)
		writer.write_file(payloads[name])
		writer.close_file()
	assert(writer.close() == OK)


func _snapshot_loader_catalog(source_catalog: String) -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(source_catalog))
	var models := output.path_join("loader-models")
	assert(DirAccess.make_dir_recursive_absolute(models) == OK)
	for entry: Dictionary in entries:
		var destination := models.path_join(str(entry.runtime_sha256) + ".scn")
		var file := FileAccess.open(destination, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(entry.runtime_path))
		file.close()
		entry.runtime_path = destination
	var catalog := FileAccess.open(output.path_join("loader-catalog.json"), FileAccess.WRITE)
	catalog.store_string(JSON.stringify(entries, "\t") + "\n")
	catalog.close()


func _run() -> void:
	output = OS.get_environment("POKEAETHER_ASSET_BUNDLE_TEST_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var bundles := [
		_write_bundle("dragonite", 1, 1),
		_write_bundle("roaring-moon", 1, 1),
		_write_bundle("arcanine", 1, 1),
	]
	var index := _index(bundles, "prototype-1")
	assert(Index.validate(index).is_empty())
	index = JSON.parse_string(JSON.stringify(index))
	assert(Index.validate(index).is_empty(), "A remotely parsed JSON index must retain its integer contract")
	var ids: Array[String] = []
	for bundle: Dictionary in bundles:
		ids.append(bundle.asset.asset_id)
	var store := Store.new(output.path_join("installed"))
	var initial_plan := store.plan(index, ids)
	assert(initial_plan.error.is_empty() and initial_plan.downloads.size() == 3)
	var dependency_index := index.duplicate(true)
	dependency_index.assets[0].dependencies = ["pokemon_3d:arcanine:base"]
	assert(store.plan(dependency_index, ["pokemon_3d:dragonite:base"]).downloads == [
		"pokemon_3d:arcanine:base", "pokemon_3d:dragonite:base"
	])
	for bundle: Dictionary in bundles:
		var installed := store.install_archive(index, bundle.asset.asset_id, bundle.archive_path)
		assert(installed.error.is_empty(), installed.error)
	assert(store.state().assets.size() == 3)
	assert(_catalog_identities(store.catalog_path()) == [
		"arcanine", "arcanine@shiny", "dragonite", "dragonite@shiny",
		"roaring-moon", "roaring-moon@shiny",
	])
	var settled_plan := store.plan(index, ids)
	assert(settled_plan.downloads.is_empty() and settled_plan.unchanged.size() == 3)
	var unchanged_generation := store.active_generation()
	var immutable_violation := _write_bundle("dragonite", 1, 99)
	var immutable_index := _index([immutable_violation, bundles[1], bundles[2]], "prototype-invalid")
	assert(not store.install_archive(immutable_index, immutable_violation.asset.asset_id, immutable_violation.archive_path).error.is_empty())
	assert(store.active_generation() == unchanged_generation)

	# A new process/store instance reconstructs exactly the same active state.
	var first_generation := store.active_generation()
	var first_state_hash := store.state_sha256()
	store = Store.new(output.path_join("installed"))
	assert(store.active_generation() == first_generation)
	assert(store.state_sha256() == first_state_hash)
	assert(store.plan(index, ids).downloads.is_empty())
	var active_path := store.root.path_join("active.json")
	var active_bytes := FileAccess.get_file_as_bytes(active_path)
	var broken_pointer := FileAccess.open(active_path, FileAccess.WRITE)
	broken_pointer.store_string("{\"generation\":\"invalid\"}")
	broken_pointer.close()
	assert(not Store.new(store.root).active_generation().is_empty(), "Previous generation recovers a damaged active pointer")
	var restore_pointer := FileAccess.open(active_path, FileAccess.WRITE)
	restore_pointer.store_buffer(active_bytes)
	restore_pointer.close()
	assert(Store.new(store.root).active_generation() == first_generation)

	# Only Dragonite changes. Other immutable object identities remain untouched.
	var dragonite_v2 := _write_bundle("dragonite", 2, 2)
	var updated_bundles := [dragonite_v2, bundles[1], bundles[2]]
	var updated_index := _index(updated_bundles, "prototype-2")
	var update_plan := store.plan(updated_index, ids)
	assert(update_plan.downloads == ["pokemon_3d:dragonite:base"])
	var before: Dictionary = store.state().assets.duplicate(true)
	var update := store.install_archive(updated_index, dragonite_v2.asset.asset_id, dragonite_v2.archive_path)
	assert(update.error.is_empty(), update.error)
	var after: Dictionary = store.state().assets
	assert(after["pokemon_3d:dragonite:base"].archive_sha256 == dragonite_v2.asset.sha256)
	for unchanged in ["pokemon_3d:roaring-moon:base", "pokemon_3d:arcanine:base"]:
		assert(after[unchanged].archive_sha256 == before[unchanged].archive_sha256)
	_snapshot_loader_catalog(store.catalog_path())

	# Corrupt and incomplete replacements never alter the active generation.
	var dragonite_v3 := _write_bundle("dragonite", 3, 3)
	var failed_index := _index([dragonite_v3, bundles[1], bundles[2]], "prototype-3")
	var stable_generation := store.active_generation()
	for kind in ["corrupt", "incomplete"]:
		var broken := output.path_join(kind + ".zip")
		_copy_corrupt(dragonite_v3.archive_path, broken, kind == "incomplete")
		var failure := store.install_archive(failed_index, dragonite_v3.asset.asset_id, broken)
		assert(not failure.error.is_empty())
		assert(store.active_generation() == stable_generation)
		assert(store.state().assets[dragonite_v2.asset.asset_id].archive_sha256 == dragonite_v2.asset.sha256)
	var wrong_manifest := output.path_join("wrong-manifest.zip")
	_wrong_manifest_archive(dragonite_v3.archive_path, wrong_manifest)
	var wrong_index := failed_index.duplicate(true)
	wrong_index.assets[0].size_bytes = FileAccess.get_file_as_bytes(wrong_manifest).size()
	wrong_index.assets[0].sha256 = FileAccess.get_sha256(wrong_manifest)
	wrong_index.assets[0].object_key = "optional-assets/pokemon_3d/dragonite/base/v3-%s.zip" % wrong_index.assets[0].sha256
	assert(not store.install_archive(wrong_index, dragonite_v3.asset.asset_id, wrong_manifest).error.is_empty())
	assert(store.active_generation() == stable_generation)

	# Explicit removal makes absence normal; controlled GC removes only orphans.
	var arcanine_object := str(store.state().assets["pokemon_3d:arcanine:base"].archive_sha256)
	var removal := store.remove("pokemon_3d:arcanine:base")
	assert(removal.error.is_empty() and removal.changed)
	var identities := _catalog_identities(store.catalog_path())
	assert("arcanine" not in identities and "arcanine@shiny" not in identities)
	assert(identities.size() == 4)
	assert(DirAccess.dir_exists_absolute(store.root.path_join("objects").path_join(arcanine_object)))
	var cleanup := store.garbage_collect()
	assert(cleanup.error.is_empty() and cleanup.removed_objects >= 2)
	assert(not DirAccess.dir_exists_absolute(store.root.path_join("objects").path_join(arcanine_object)))
	assert(_catalog_identities(store.catalog_path()).size() == 4)

	# Index identity, immutability and dependency errors fail before installation.
	var invalid := updated_index.duplicate(true)
	invalid.assets[0].sha256 = "0".repeat(64)
	invalid.assets[0].version = 1
	invalid.assets[1].dependencies = [invalid.assets[0].asset_id]
	invalid.assets[0].dependencies = [invalid.assets[1].asset_id]
	assert(not Index.validate(invalid).is_empty())
	print("ASSET_BUNDLE_STORE_OK initial=3 no_op=0 update=dragonite corrupt_rollback=true restart=true removed=arcanine")
	quit()
