extends SceneTree
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "user://full-catalog-size-check.json"
	var model_path := "user://full-catalog-size-check.scn"
	var packed := PackedScene.new()
	var node := Node3D.new()
	packed.pack(node)
	node.free()
	ResourceSaver.save(packed, model_path)
	var rows := []
	# Catalogue admission reads metadata; model hashes are validated lazily when
	# selected. This fixture has no selected actor and never loads fake geometry.
	for identity: String in Registry.DATA.data.models:
		rows.append({"species": identity.trim_suffix("@shiny"), "variant": "shiny" if identity.ends_with("@shiny") else "normal",
			"runtime_schema": 1, "runtime_sha256": Registry.DATA.data.models[identity].sha256,
			"runtime_path": ProjectSettings.globalize_path(model_path), "bytes": FileAccess.get_size(model_path),
			"note": "Full launcher catalog path allowance: " + "x".repeat(350)})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	file.close()
	assert(FileAccess.get_size(path) > 1024 * 1024)
	var service := Service.new()
	assert(service._catalog(path).size() == rows.size(), "full launcher catalog does not trigger duplicate downloads")
	var stage := Stage.new()
	root.add_child(stage)
	stage.setup()
	stage._load_catalog(path)
	assert(stage.catalog_entries.size() >= rows.size(), "full launcher catalog is available to battles")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[]" + " ".repeat(Service.MAX_CATALOG_BYTES))
	file.close()
	assert(service._catalog(path).is_empty(), "catalog input remains bounded")
	stage._load_catalog(path)
	assert(stage.catalog_entries.is_empty(), "battle catalog input remains bounded")
	service.free()
	stage.mode_label.free()
	stage.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model_path))
	if not FileAccess.file_exists("res://tests/full_3d_catalog_size_check.gd.uid"):
		var uid := FileAccess.open("res://tests/full_3d_catalog_size_check.gd.uid", FileAccess.WRITE)
		uid.store_line(ResourceUID.id_to_text(ResourceUID.create_id()))
		uid.close()
	print("PASS full_3d_catalog_size_check appearances=", rows.size(), " duplicate_downloads=false bounded=true")
	quit()
