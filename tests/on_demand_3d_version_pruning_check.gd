extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
class PruningProbe extends "res://scripts/services/on_demand_3d_bundle_service.gd":
	func _ready() -> void:
		pass

func _init() -> void:
	_run.call_deferred()

func _write(path: String, bytes: PackedByteArray) -> void:
	assert(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()

func _run() -> void:
	# The harness's slot owns user://; fixtures are generated here, never copied.
	var owned := ProjectSettings.globalize_path("user://model-version-pruning-test-%d" % Time.get_ticks_usec())
	var objects := owned.path_join("objects")
	var old := objects.path_join("1".repeat(64))
	var current := objects.path_join("2".repeat(64))
	var staged := objects.path_join("3".repeat(64))
	var unrelated := objects.path_join("4".repeat(64))
	var payload := PackedByteArray([1, 2, 3, 4])
	var service := PruningProbe.new()
	root.add_child(service)
	for path in [old, current, staged]:
		for variant in ["normal", "shiny"]:
			_write(path.path_join(variant + ".scn"), payload)
	_write(unrelated.path_join("keep.txt"), payload)
	var entries := []
	for variant in ["normal", "shiny"]:
		entries.append({"species": "dragonite", "variant": variant, "runtime_schema": 1,
			"runtime_path": current.path_join(variant + ".scn"), "runtime_sha256": service._sha256(payload), "bytes": payload.size()})
	var index := {"assets": [{"sha256": "2".repeat(64)}, {"sha256": "3".repeat(64)}]}
	assert(service._prune_unused_models(entries, index, owned).removed_objects == 0)
	assert(DirAccess.dir_exists_absolute(old), "No cleanup before successful catalog publication")
	_write(owned.path_join("runtime-catalog.json"), JSON.stringify(entries).to_utf8_buffer())
	_write(current.path_join("shiny.scn"), PackedByteArray([0]))
	assert(not service._prune_unused_models(entries, index, owned).error.is_empty())
	assert(DirAccess.dir_exists_absolute(old), "A corrupt surviving appearance keeps previous files")
	_write(current.path_join("shiny.scn"), payload)
	var result: Dictionary = await service._run_storage_work(service._prune_unused_models.bind(entries, index, owned))
	assert(result.error.is_empty() and result.removed_objects == 1)
	assert(not DirAccess.dir_exists_absolute(old))
	assert(DirAccess.dir_exists_absolute(staged), "Current interrupted downloads survive cleanup")
	assert(FileAccess.get_file_as_bytes(unrelated.path_join("keep.txt")) == payload)
	for entry: Dictionary in entries:
		assert(FileAccess.get_file_as_bytes(entry.runtime_path) == payload)
	assert(service._prune_unused_models(entries, index, owned).removed_objects == 0)
	service.free()
	print("ON_DEMAND_3D_VERSION_PRUNING_OK atomic=true corrupt_current=true active_pair=true pending_downloads=true unrelated_files=true worker=true")
	quit()
