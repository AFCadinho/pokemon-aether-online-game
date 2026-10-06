extends SceneTree
## A launcher catalog is a source of candidates; the game validates requested files.
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const FIXTURE := "user://on-demand-launcher-catalog-check"

class Probe extends Service:
	var release := {}
	var fallback_calls := 0
	func _selected_release() -> Dictionary:
		return release
	func _local_index_path(_release: Dictionary) -> String:
		return FIXTURE.path_join("index.json")
	func _ensure_models(identities: Array[String], source: String) -> Dictionary:
		fallback_calls += 1
		return {"error": "", "missing": _missing_assets(_read_local_index(_local_index_path(release), release), identities, _catalog(source)).asset_ids}


func _init() -> void:
	_run.call_deferred()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()


func _run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE)) == OK)
	var service := Probe.new()
	root.add_child(service)
	var models: Dictionary = Registry.DATA.data.models
	var original: Dictionary = models.garchomp.duplicate(true)
	var bytes := "launcher-cached-garchomp".to_utf8_buffer()
	var digest := service._sha256(bytes)
	models.garchomp.sha256 = digest
	models.garchomp.previous_sha256 = []
	var model_path := ProjectSettings.globalize_path(FIXTURE.path_join("model.scn"))
	var catalog_path := ProjectSettings.globalize_path(FIXTURE.path_join("launcher-catalog.json"))
	var asset_id := "pokemon_3d:garchomp:base"
	var index := {"catalog_revision": "launch-fixture", "assets": [{
		"asset_id": asset_id, "appearances": [{"runtime_identity": "garchomp", "runtime_sha256": digest}]}]}
	var index_path := FIXTURE.path_join("index.json")
	_write(index_path, JSON.stringify(index).to_utf8_buffer())
	service.release = {"revision": "launch-fixture", "requiredAssetIds": [asset_id],
		"index": {"sha256": FileAccess.get_sha256(index_path), "size_bytes": FileAccess.get_file_as_bytes(index_path).size()}}
	var entries := [{"species": "garchomp", "variant": "normal", "runtime_path": model_path,
		"runtime_sha256": digest, "bytes": bytes.size()},
		# Unrelated missing models must not invalidate the requested cached model.
		{"species": "dragonite", "variant": "normal", "runtime_path": FIXTURE.path_join("absent.scn")}]
	_write(model_path, bytes)
	_write(catalog_path, JSON.stringify(entries).to_utf8_buffer())
	var ready: Dictionary = await service.ensure_models(["garchomp"], catalog_path)
	assert(ready.path == catalog_path and service.fallback_calls == 0)
	assert(ready.verified_models.garchomp.sha256 == digest and service.active_request == null)
	var corrupt := bytes.duplicate()
	corrupt[0] ^= 0xff
	_write(model_path, corrupt)
	var rejected: Dictionary = await service.ensure_models(["garchomp"], catalog_path)
	assert(service.fallback_calls == 1 and rejected.missing == [asset_id], "Same-size corruption must request a replacement")
	assert(DirAccess.remove_absolute(model_path) == OK)
	var missing: Dictionary = await service.ensure_models(["garchomp"], catalog_path)
	assert(service.fallback_calls == 2 and missing.missing == [asset_id])
	_write(model_path, bytes)
	entries[0].runtime_sha256 = "0".repeat(64)
	_write(catalog_path, JSON.stringify(entries).to_utf8_buffer())
	var obsolete: Dictionary = await service.ensure_models(["garchomp"], catalog_path)
	assert(service.fallback_calls == 3 and obsolete.missing == [asset_id], "The pinned index, not the launcher, selects the version")
	models.garchomp = original
	service.queue_free()
	print("ON_DEMAND_LAUNCHER_CATALOG_OK cached_reuse=true unrelated_missing_ignored=true corrupt_missing_obsolete_replacement_planned=true")
	quit()
