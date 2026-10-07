extends SceneTree
## Metadata-only export helper. Does not instantiate the purchased world.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	assert(output != null)
	if args[0] == "roots":
		var loader = load("res://scripts/battle/arenas/shared/forest_art_pack.gd")
		output.store_string(JSON.stringify(Array(loader.resource_paths()), "  "))
	else:
		assert(args[0] == "uids")
		var map := {}
		_collect_uids("res://entities", map)
		_collect_uids("res://common", map)
		# Exported art retains this editor-helper reference. The client supplies
		# the inert runtime stub; the vendor script/native module is not packed.
		var helper := "res://addons/terrain_3d/utils/terrain_3d_objects.gd"
		var id := ResourceLoader.get_resource_uid(helper)
		if id != ResourceUID.INVALID_ID:
			map[ResourceUID.id_to_text(id)] = helper
		output.store_string(JSON.stringify(map, "  "))
	output.close()
	quit()

func _collect_uids(directory: String, result: Dictionary) -> void:
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".import") or name.ends_with(".uid"):
			continue
		var path := directory.path_join(name)
		var id := ResourceLoader.get_resource_uid(path)
		if id != ResourceUID.INVALID_ID:
			result[ResourceUID.id_to_text(id)] = path
	for name in DirAccess.get_directories_at(directory):
		_collect_uids(directory.path_join(name), result)
