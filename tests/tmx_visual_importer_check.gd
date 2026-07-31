extends SceneTree

const PokeAetherTmxVisualImporter := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_visual_importer.gd")

const VISUAL_FIXTURE := "res://tests/fixtures/tiled/visual_only_regular.tmx"
const GENERATED_DIR := "res://generated/tiled_visuals/visual_only_regular"
const GENERATED_SCENE := "res://generated/tiled_visuals/visual_only_regular/visual_only_regular.visual.tscn"
const GENERATED_TILESET := "res://generated/tiled_visuals/visual_only_regular/visual_only_regular.visual.tileset.tres"
const ALT_FLIP_H := 4096

var failed := false


func _init() -> void:
	_cleanup_generated_outputs()

	var importer := PokeAetherTmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(VISUAL_FIXTURE)
	_check_true(bool(result.get("success", false)), "visual fixture import should pass: %s" % str(result.get("error", "")))
	_check_equal(str(result.get("visual_id", "")), "visual_only_regular", "visual id")
	_check_equal(str(result.get("visual_scene_path", "")), GENERATED_SCENE, "visual scene path")
	_check_equal(str(result.get("tileset_path", "")), GENERATED_TILESET, "visual tileset path")
	_check_equal(int(result.get("tile_layer_count", -1)), 3, "tile layer count")
	_check_equal(int(result.get("ignored_object_group_count", -1)), 1, "ignored object group count")
	_check_file_exists(GENERATED_SCENE, "visual scene exists")
	_check_file_exists(GENERATED_TILESET, "visual tileset exists")

	var packed_scene := load(GENERATED_SCENE) as PackedScene
	_check_true(packed_scene != null, "visual scene loads")
	if packed_scene != null:
		var root := packed_scene.instantiate()
		_check_true(root != null, "visual scene instantiates")
		if root != null:
			_check_visual_scene(root)
			root.free()

	_cleanup_generated_outputs()
	quit(1 if failed else 0)


func _check_visual_scene(root: Node) -> void:
	_check_true(bool(root.get_meta("pao_generated_visual", false)), "root is marked as generated visual")
	_check_true(not root.has_meta("tiled_properties"), "map properties are not copied to visual scene")
	_check_true(root.get_node_or_null("ObjectLayers") == null, "object layers are ignored")
	_check_equal(root.get_child_count(), 3, "only tile layers are generated")
	_check_equal(root.get_child(0).name, "Ground", "first layer order")
	_check_equal(root.get_child(1).name, "Hidden Guide", "second layer order")
	_check_equal(root.get_child(2).name, "Overlay", "third layer order")

	var ground := root.get_node_or_null("Ground") as TileMapLayer
	var hidden := root.get_node_or_null("Hidden Guide") as TileMapLayer
	var overlay := root.get_node_or_null("Overlay") as TileMapLayer
	_check_true(ground != null, "ground layer exists")
	_check_true(hidden != null, "hidden layer exists")
	_check_true(overlay != null, "overlay layer exists")
	if ground == null or hidden == null or overlay == null:
		return

	_check_true(not ground.has_meta("tiled_properties"), "layer properties are not copied to visual scene")
	_check_equal(str(ground.get_meta("pao_rain_surface", "")), "ground", "rain surface metadata is preserved")
	_check_true(hidden.visible == false, "hidden layer visibility is preserved")
	_check_equal(float(overlay.modulate.a), 0.5, "overlay opacity is preserved")
	_check_equal(ground.z_index, 0, "ground z order")
	_check_equal(hidden.z_index, 1, "hidden z order")
	_check_equal(overlay.z_index, 2050, "overlay z order")
	_check_equal(ground.get_cell_source_id(Vector2i(0, 0)), 1, "ground first cell source id")
	_check_equal(overlay.get_cell_alternative_tile(Vector2i(0, 0)), ALT_FLIP_H, "horizontal flip flag is preserved")


func _check_file_exists(path: String, label: String) -> void:
	_check_true(FileAccess.file_exists(ProjectSettings.globalize_path(path)), label)


func _check_true(value: bool, label: String) -> void:
	if value:
		return

	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _cleanup_generated_outputs() -> void:
	_remove_directory_contents(GENERATED_DIR.path_join("assets"))
	var global_assets_dir := ProjectSettings.globalize_path(GENERATED_DIR.path_join("assets"))
	if DirAccess.dir_exists_absolute(global_assets_dir):
		DirAccess.remove_absolute(global_assets_dir)

	for path in [
		GENERATED_SCENE,
		GENERATED_TILESET,
	]:
		var global_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_path):
			DirAccess.remove_absolute(global_path)

	var global_dir := ProjectSettings.globalize_path(GENERATED_DIR)
	if DirAccess.dir_exists_absolute(global_dir):
		DirAccess.remove_absolute(global_dir)


func _remove_directory_contents(path: String) -> void:
	var global_dir := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(global_dir):
		return

	var dir := DirAccess.open(global_dir)
	if dir == null:
		return

	for file_name in dir.get_files():
		DirAccess.remove_absolute(global_dir.path_join(file_name))
	for child_dir in dir.get_directories():
		var child_path := path.path_join(child_dir)
		_remove_directory_contents(child_path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
