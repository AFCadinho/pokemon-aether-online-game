extends SceneTree

const ROUTE_2_PATH := "res://scenes/overworld/kanto/routes/kanto_route_2.tscn"
const VIRIDIAN_FOREST_PATH := "res://scenes/overworld/kanto/routes/viridian_forest.tscn"
const NORTH_GATE_PATH := "res://scenes/overworld/kanto/transition_buildings/route_2_viridian_forest_north_gate.tscn"
const SOUTH_GATE_PATH := "res://scenes/overworld/kanto/transition_buildings/route_2_viridian_forest_south_gate.tscn"
const TEMPLATE_PATH := "res://scenes/overworld/kanto/reusable_interiors/vertical_transition_building_template.tscn"

var failed := false


func _init() -> void:
	var route_2_source := FileAccess.get_file_as_string(ROUTE_2_PATH)
	var forest_source := FileAccess.get_file_as_string(VIRIDIAN_FOREST_PATH)
	var north_gate_source := FileAccess.get_file_as_string(NORTH_GATE_PATH)
	var south_gate_source := FileAccess.get_file_as_string(SOUTH_GATE_PATH)
	var template_source := FileAccess.get_file_as_string(TEMPLATE_PATH)
	_check(
		template_source.contains('&"ground_floor": Rect2(192, 64, 320, 576)'),
		"vertical gate mask leaves room for the guard nameplate"
	)

	_check_transition(
		route_2_source,
		"ToViridianForestNorth",
		NORTH_GATE_PATH,
		"FromNorth",
		"Route 2 north entrance enters the north gate"
	)
	_check_transition(
		forest_source,
		"ToRoute2North",
		NORTH_GATE_PATH,
		"FromSouth",
		"Viridian Forest north entrance enters the north gate"
	)
	_check_transition(
		route_2_source,
		"ToViridianForestSouth",
		SOUTH_GATE_PATH,
		"FromSouth",
		"Route 2 south entrance enters the south gate"
	)
	_check_transition(
		forest_source,
		"ToRoute2South",
		SOUTH_GATE_PATH,
		"FromNorth",
		"Viridian Forest south entrance enters the south gate"
	)

	_check_gate(
		north_gate_source,
		"kanto_route_2_viridian_forest_north_gate",
		ROUTE_2_PATH,
		"FromViridianForestNorth",
		VIRIDIAN_FOREST_PATH,
		"FromRoute2North",
		"north gate"
	)
	_check_gate(
		south_gate_source,
		"kanto_route_2_viridian_forest_south_gate",
		VIRIDIAN_FOREST_PATH,
		"FromRoute2South",
		ROUTE_2_PATH,
		"FromViridianForestSouth",
		"south gate"
	)

	quit(1 if failed else 0)


func _check_transition(
	source: String,
	node_name: String,
	target_path: String,
	target_spawn: String,
	label: String
) -> void:
	var block := _node_block(source, node_name)
	_check(not block.is_empty(), "%s exists" % label)
	_check(block.contains('target_scene_path = "%s"' % target_path), "%s targets the gate" % label)
	_check(block.contains('target_spawn_name = "%s"' % target_spawn), "%s uses the correct gate doorway" % label)


func _check_gate(
	source: String,
	map_id: String,
	north_target: String,
	north_spawn: String,
	south_target: String,
	south_spawn: String,
	label: String
) -> void:
	_check(source.contains('path="%s"' % TEMPLATE_PATH), "%s inherits the vertical transition template" % label)
	_check(source.contains('map_id = "%s"' % map_id), "%s has a unique map id" % label)

	var north_exit := _node_block(source, "ToNorth")
	_check(north_exit.contains('target_scene_path = "%s"' % north_target), "%s north exit target" % label)
	_check(north_exit.contains('target_spawn_name = "%s"' % north_spawn), "%s north exit spawn" % label)

	var south_exit := _node_block(source, "ToSouth")
	_check(south_exit.contains('target_scene_path = "%s"' % south_target), "%s south exit target" % label)
	_check(south_exit.contains('target_spawn_name = "%s"' % south_spawn), "%s south exit spawn" % label)


func _node_block(source: String, node_name: String) -> String:
	var node_start := source.find('[node name="%s"' % node_name)
	if node_start < 0:
		return ""
	var next_node := source.find("\n[node ", node_start + 1)
	if next_node < 0:
		return source.substr(node_start)
	return source.substr(node_start, next_node - node_start)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
