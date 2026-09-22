extends SceneTree
var uid_map := {}
func _uids(directory: String) -> void:
	for name in DirAccess.get_files_at(directory):
		var path := directory.path_join(name)
		if path.ends_with(".import") or path.ends_with(".uid"):
			continue
		var id := ResourceLoader.get_resource_uid(path)
		if id != ResourceUID.INVALID_ID:
			uid_map[ResourceUID.id_to_text(id)] = path
	for name in DirAccess.get_directories_at(directory):
		_uids(directory.path_join(name))

func _strip_editor_scripts(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path.begins_with("res://addons/terrain_3d/utils/"):
		node.set_script(null)
	for child in node.get_children():
		_strip_editor_scripts(child)
## Run only inside the isolated purchased project. Never saves original resources.
func _init() -> void:
	var scene: Node3D = load("res://scenes/world/test_world.res").instantiate()
	for node_name in ["Rendering","Player","WorldBarrier","GrassPlacer"]:
		var node := scene.get_node_or_null(NodePath(node_name))
		if node != null:
			scene.remove_child(node)
			node.free()
	var packed := PackedScene.new()
	_strip_editor_scripts(scene)
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed,"res://pokeaether_forest.tscn") == OK)
	scene.free()
	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg")==OK)
	var index := 0
	while presets.has_section("preset.%s"%index) and presets.get_value("preset.%s"%index,"name","")!="PokeAether Forest Pack":
		index += 1
	var section := "preset.%s"%index
	var files := PackedStringArray(["res://pokeaether_forest.tscn"])
	for filename in DirAccess.get_files_at("res://scenes/world/terrain"):
		if filename.ends_with(".res"):
			files.append("res://scenes/world/terrain/"+filename)
	for directory in ["res://entities","res://common","res://scenes/world/terrain","res://addons/terrain_3d/utils"]:
		_uids(directory)
	var uid_file := FileAccess.open("res://forest_uids.json",FileAccess.WRITE)
	uid_file.store_string(JSON.stringify(uid_map))
	uid_file.close()
	presets.set_value(section,"name","PokeAether Forest Pack")
	presets.set_value(section,"platform","Linux")
	presets.set_value(section,"runnable",false)
	presets.set_value(section,"export_filter","resources")
	presets.set_value(section,"export_files",files)
	presets.set_value(section,"include_filter","addons/terrain_3d/LICENSE.txt,forest_uids.json")
	presets.set_value(section,"exclude_filter","addons/terrain_3d/utils/*")
	presets.set_value(section,"script_export_mode",1)
	presets.set_value(section+".options","texture_format/s3tc_bptc",true)
	presets.set_value(section+".options","binary_format/architecture","x86_64")
	assert(presets.save("res://export_presets.cfg")==OK)
	print("FOREST_RUNTIME_SCENE_OK")
	quit()
