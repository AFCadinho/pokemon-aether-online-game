extends SceneTree

const Integrity = preload("res://scripts/asset_pack_integrity.gd")


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/launcher.gd")
	assert(source.contains('"battle-environment-forest": "forest-runtime"'))
	assert(source.contains('"forest-runtime/forest.json"'))
	assert(source.contains('"forest-runtime/forest.pck"'))
	assert(source.contains('OS.set_environment(\n\t\tFOREST_MANIFEST_ENV,'))
	var required_path := "forest-runtime"
	var required_files := ["forest-runtime/forest.json", "forest-runtime/forest.pck"]
	var install_dir := "user://forest_integrity_%d" % Time.get_ticks_usec()
	var absolute := ProjectSettings.globalize_path(install_dir)
	DirAccess.make_dir_recursive_absolute(absolute.path_join(required_path))
	assert(not Integrity.has_required_contents(install_dir, required_path, required_files))
	for required_file: String in required_files:
		var file := FileAccess.open(absolute.path_join(required_file), FileAccess.WRITE)
		file.store_8(1)
		file.close()
	assert(Integrity.has_required_contents(install_dir, required_path, required_files))
	print("FOREST_ASSET_INTEGRITY_OK")
	quit()
