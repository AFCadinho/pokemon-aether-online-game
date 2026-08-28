extends SceneTree

const OUTDOOR_MAP_SCENES: Array[String] = [
	"res://scenes/overworld/aether_clash/aether_clash_lobby.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn",
	"res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_3.tscn",
	"res://scenes/overworld/kanto/routes/viridian_forest.tscn",
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn",
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn",
]

var failed := false


func _init() -> void:
	for scene_path: String in OUTDOOR_MAP_SCENES:
		_check_map_stair_markers(scene_path)
	quit(1 if failed else 0)


func _check_map_stair_markers(scene_path: String) -> void:
	var source := FileAccess.get_file_as_string(scene_path)
	_check(not source.is_empty(), "%s is readable" % scene_path)
	if source.is_empty():
		return

	var stairs_block := _node_block(source, "Stairs", ".")
	var up_left_block := _node_block(source, "StairUpLeft", "Stairs")
	var up_right_block := _node_block(source, "StairUpRight", "Stairs")
	_check(not stairs_block.is_empty(), "%s has a Stairs marker container" % scene_path)
	_check(stairs_block.contains("visible = false"), "%s keeps stair markers hidden" % scene_path)
	_check(not up_left_block.is_empty(), "%s has StairUpLeft" % scene_path)
	_check(not up_right_block.is_empty(), "%s has StairUpRight" % scene_path)

	var left_cells := _tile_cells(up_left_block)
	var right_cells := _tile_cells(up_right_block)
	_check(
		not left_cells.is_empty() or not right_cells.is_empty(),
		"%s marks at least one horizontal stair" % scene_path
	)
	for cell: Vector2i in left_cells:
		_check(
			not right_cells.has(cell),
			"%s does not mark cell %s as both up-left and up-right" % [scene_path, cell]
		)


func _node_block(source: String, node_name: String, parent_name: String) -> String:
	var marker := '[node name="%s" type=' % node_name
	var start := source.find(marker)
	while start >= 0:
		var line_end := source.find("\n", start)
		if line_end < 0:
			line_end = source.length()
		var header := source.substr(start, line_end - start)
		if header.contains('parent="%s"' % parent_name):
			var block_end := source.find("\n[node ", line_end)
			if block_end < 0:
				block_end = source.length()
			return source.substr(start, block_end - start)
		start = source.find(marker, line_end)
	return ""


func _tile_cells(node_block: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var data_prefix := 'tile_map_data = PackedByteArray("'
	var data_start := node_block.find(data_prefix)
	if data_start < 0:
		return cells
	var encoded_start := data_start + data_prefix.length()
	var data_end := node_block.find('")', encoded_start)
	if data_end < encoded_start:
		return cells
	var raw := Marshalls.base64_to_raw(node_block.substr(encoded_start, data_end - encoded_start))
	if raw.size() < 2 or (raw.size() - 2) % 12 != 0:
		return cells
	for offset: int in range(2, raw.size(), 12):
		cells.append(Vector2i(raw.decode_u16(offset), raw.decode_u16(offset + 2)))
	return cells


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
