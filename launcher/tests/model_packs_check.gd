extends SceneTree
const Store = preload("res://scripts/model_pack_store.gd")
const ModelsPanel = preload("res://scripts/model_packs_panel.gd")
var output: String


func _init() -> void:
	_run.call_deferred()

func _zip(name: String, manifest: Dictionary, extra := false) -> String:
	var path := output.path_join(name + ".zip")
	var writer := ZIPPacker.new()
	assert(writer.open(path) == OK)
	assert(writer.start_file("catalog.json") == OK)
	writer.write_file(JSON.stringify(manifest).to_utf8_buffer())
	writer.close_file()
	writer.start_file(manifest.entries[0].runtime_path)
	writer.write_file("bad".to_utf8_buffer())
	writer.close_file()
	if extra:
		writer.start_file("script.gd")
		writer.write_file("extends Node".to_utf8_buffer())
		writer.close_file()
	assert(writer.close() == OK)
	return path

func _run() -> void:
	output = OS.get_environment("POKEAETHER_MODEL_PACK_TEST_OUTPUT")
	var source := OS.get_environment("POKEAETHER_MODEL_PACK_ZIP")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var store := Store.new(output.path_join("installed"))
	assert(store.selected_catalog().is_empty())
	var panel := ModelsPanel.new()
	panel.store = store
	root.add_child(panel)
	var locale := root.get_node("LauncherLocalization")
	locale.set_locale("nl")
	panel.setup(locale.text)
	panel.popup_centered()
	assert(panel.title == "3D-modellen")
	panel.start_job("install", source)
	assert(panel.import_button.disabled and panel.get_ok_button().disabled)
	var frames := 0
	var deadline := Time.get_ticks_msec() + 30000
	while panel.thread != null:
		await process_frame
		frames += 1
		assert(Time.get_ticks_msec() < deadline)
	assert(frames > 2, "Installation must keep the UI processing frames")
	assert(store.installed().size() == 1, panel.status.text)
	assert(store.selected_catalog().is_empty(), "Import must not auto-select")
	var id: String = store.installed()[0].id
	var catalog := store.catalog(id)
	assert(not catalog.is_empty() and panel.choices.item_count == 2)
	assert(not store.import_zip(source).error.is_empty(), "No overwrite")
	panel.choices.select(1)
	panel.select_button.pressed.emit()
	while panel.thread != null:
		await process_frame
		assert(Time.get_ticks_msec() < deadline)
	assert(store.selected_catalog() == catalog)
	assert(Store.new(store.root).selected_catalog() == catalog, "Selection persists")
	var launcher: Variant = load("res://tests/model_launch_probe.gd").new()
	var had_env := OS.has_environment("POKEAETHER_MODEL_CATALOG")
	var previous_env := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	OS.set_environment("POKEAETHER_MODEL_CATALOG", "previous-value")
	launcher.model_path = catalog
	assert(launcher._create_game_process("not-started") == 42)
	assert(launcher.observed == catalog)
	assert(OS.get_environment("POKEAETHER_MODEL_CATALOG") == "previous-value")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	launcher.result = -1
	launcher.model_path = ""
	assert(launcher._create_game_process("not-started") == -1)
	assert(launcher.observed.is_empty() and not OS.has_environment("POKEAETHER_MODEL_CATALOG"))
	if had_env: OS.set_environment("POKEAETHER_MODEL_CATALOG", previous_env)
	launcher.free()
	var selection := FileAccess.get_file_as_string(store.root.path_join("selection.json"))
	var manifest := Store._json(catalog)
	var small := manifest.duplicate(true)
	small.entries = [manifest.entries[0].duplicate(true)]
	small.entries[0].bytes = 3
	var corrupt := _zip("corrupt", small)
	assert(not Store._archive_entries(corrupt).is_empty(), "Baseline ZIP headers validate")
	assert(not store.import_zip(corrupt).error.is_empty())
	var original := FileAccess.get_file_as_bytes(corrupt)
	var central := original.decode_u32(original.size() - 6)
	for mutation in ["local-size", "symlink", "encrypted", "zip64", "truncated"]:
		var data := original.duplicate()
		match mutation:
			"local-size": data.encode_u32(22, 0x7FFFFFFF)
			"symlink": data.encode_u32(central + 38, 0xA1FF0000)
			"encrypted": data.encode_u16(central + 8, 1)
			"zip64": data.encode_u32(central + 24, 0xFFFFFFFF)
			"truncated": data.resize(35)
		var invalid := output.path_join(mutation + ".zip")
		var file := FileAccess.open(invalid, FileAccess.WRITE)
		file.store_buffer(data)
		file.close()
		assert(Store._archive_entries(invalid).is_empty(), mutation)
		assert(not store.import_zip(invalid).error.is_empty())
	assert(not store.import_zip(_zip("extra-script", small, true)).error.is_empty())
	var bad := small.duplicate(true)
	bad.entries[0].runtime_path = "../outside.scn"
	assert(not store.import_zip(_zip("traversal", bad)).error.is_empty())
	bad = small.duplicate(true)
	bad.godot = "5.0"
	assert(not store.import_zip(_zip("wrong-engine", bad)).error.is_empty())
	assert(FileAccess.get_file_as_string(store.root.path_join("selection.json")) == selection)
	for dir in DirAccess.open(store.root).get_directories():
		assert(not dir.begins_with(".import-"), "Failed imports must clean staging")
	assert(not store.select("invalid").error.is_empty())
	assert(store.selected_catalog() == catalog)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(panel.size.y <= 600, "Model panel must fit the launcher")
		assert(panel.get_texture().get_image().save_png(output.path_join("model-packs-panel.png")) == OK)
	assert(store.select("").error.is_empty())
	assert(store.selected_catalog().is_empty())
	var original_catalog := FileAccess.get_file_as_bytes(catalog)
	var catalog_file := FileAccess.open(catalog, FileAccess.WRITE)
	catalog_file.store_buffer(original_catalog)
	catalog_file.store_string(" ")
	catalog_file.close()
	assert(not store.select(id).error.is_empty(), "Immutable catalog identity must match its bytes")
	catalog_file = FileAccess.open(catalog, FileAccess.WRITE)
	catalog_file.store_buffer(original_catalog)
	catalog_file.close()
	# Revalidation refuses a changed installed model, preserving the last selection.
	var entry: Dictionary = manifest.entries[0]
	var changed := FileAccess.open(catalog.get_base_dir().path_join(entry.runtime_path), FileAccess.READ_WRITE)
	changed.seek(0)
	changed.store_8(0)
	changed.close()
	assert(not store.select(id).error.is_empty())
	assert(store.selected_catalog().is_empty())
	panel.queue_free()
	await process_frame
	print("MODEL_PACKS_LAUNCHER_OK imported=14 worker_frames=", frames, " selection/errors/rollback/checksums passed")
	quit()
