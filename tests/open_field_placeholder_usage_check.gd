extends SceneTree

const OVERWORLD_ROOT := "res://scenes/overworld"
const TEMPLATE_SCENE := "res://scenes/overworld/kanto/templates/open_field_placeholder_template.tscn"
const MAP_METADATA_SCRIPT := "res://scripts/world/map_metadata.gd"
const LEGACY_COLLISION_SCRIPT := "res://scripts/world/kanto/open_field_placeholder_map.gd"
const TEMPLATE_MAPS := {
	"res://scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn": {
		"bottom": [Vector2i(10, 13)],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_5.tscn": {
		"bottom": [Vector2i(2, 5), Vector2i(10, 13), Vector2i(18, 21)],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_9.tscn": {
		"left": [Vector2i(7, 10)],
	},
}
const MAP_SIZE := Vector2i(24, 18)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(not FileAccess.file_exists(LEGACY_COLLISION_SCRIPT), "Legacy runtime Collision script is removed")

	var template_source := FileAccess.get_file_as_string(TEMPLATE_SCENE)
	_check(template_source.contains("open_field.visual.tscn"), "Template owns the OpenField visual")
	_check(template_source.contains('res://scripts/world/map_metadata.gd'), "Template uses non-mutating map metadata")
	_check(template_source.contains('[node name="Collision" type="TileMapLayer" parent="Tiles"]'), "Template owns a Collision TileMapLayer")
	_check(
		template_source.contains('tile_map_data = PackedByteArray("')
			and not template_source.contains('tile_map_data = PackedByteArray("")'),
		"Template stores drawn boundary cells"
	)

	var template := (load(TEMPLATE_SCENE) as PackedScene).instantiate()
	var template_collision := template.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(
		_boundary_matches(template_collision, {}),
		"Template draws a completely closed 24×18 boundary"
	)
	template.free()

	var template_users: Array[String] = []
	var legacy_script_users: Array[String] = []
	_scan_scenes(OVERWORLD_ROOT, template_users, legacy_script_users)
	template_users.sort()
	legacy_script_users.sort()
	_check(legacy_script_users.is_empty(), "No overworld scene references the removed Collision script")

	for scene_path: String in template_users:
		_check(TEMPLATE_MAPS.has(scene_path), "%s is an intentional OpenField template map" % scene_path)
	for scene_path: String in TEMPLATE_MAPS:
		_check(template_users.has(scene_path), "%s inherits the OpenField template" % scene_path)
		var source := FileAccess.get_file_as_string(scene_path)
		_check(
			source.contains('[node name="Collision" parent="Tiles" index="0"]')
				and source.contains('tile_map_data = PackedByteArray("')
				and not source.contains('tile_map_data = PackedByteArray("")'),
			"%s stores its drawn exit openings as a scene override" % scene_path
		)

		var map := (load(scene_path) as PackedScene).instantiate()
		_check(
			map.get_script() != null and map.get_script().resource_path == MAP_METADATA_SCRIPT,
			"%s uses metadata without Collision code" % scene_path
		)
		var collision := map.find_map_tilemap_layer("Collision") as TileMapLayer
		var before := _cell_state(collision)
		_check(
			_boundary_matches(collision, TEMPLATE_MAPS[scene_path]),
			"%s stores its complete expected boundary" % scene_path
		)
		root.add_child(map)
		await process_frame
		_check(
			before == _cell_state(collision),
			"%s leaves authored Collision unchanged during startup" % scene_path
		)
		map.queue_free()
		await process_frame

	quit(1 if failed else 0)


func _scan_scenes(
	directory_path: String,
	template_users: Array[String],
	legacy_script_users: Array[String]
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failed = true
		push_error("FAIL Could not scan %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_scenes(entry_path, template_users, legacy_script_users)
		elif entry.ends_with(".tscn"):
			var source := FileAccess.get_file_as_string(entry_path)
			if source.contains(TEMPLATE_SCENE):
				template_users.append(entry_path)
			if source.contains(LEGACY_COLLISION_SCRIPT):
				legacy_script_users.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _boundary_matches(layer: TileMapLayer, openings: Dictionary) -> bool:
	for x: int in range(MAP_SIZE.x):
		if _is_open(layer, Vector2i(x, 0)) != _offset_is_open(openings.get("top", []), x):
			return false
		if _is_open(layer, Vector2i(x, MAP_SIZE.y - 1)) != _offset_is_open(openings.get("bottom", []), x):
			return false
	for y: int in range(1, MAP_SIZE.y - 1):
		if _is_open(layer, Vector2i(0, y)) != _offset_is_open(openings.get("left", []), y):
			return false
		if _is_open(layer, Vector2i(MAP_SIZE.x - 1, y)) != _offset_is_open(openings.get("right", []), y):
			return false
	return true


func _offset_is_open(ranges: Array, offset: int) -> bool:
	for opening: Vector2i in ranges:
		if offset >= opening.x and offset <= opening.y:
			return true
	return false


func _is_open(layer: TileMapLayer, cell: Vector2i) -> bool:
	return layer != null and layer.get_cell_source_id(cell) == -1


func _cell_state(layer: TileMapLayer) -> Dictionary:
	var result := {}
	for cell: Vector2i in layer.get_used_cells():
		result[cell] = [
			layer.get_cell_source_id(cell),
			layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell),
		]
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
