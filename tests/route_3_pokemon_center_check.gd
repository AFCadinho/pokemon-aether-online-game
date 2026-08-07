extends SceneTree

const ROUTE_3_PATH := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const CENTER_PATH := "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_3_PATH)
	var center_source := FileAccess.get_file_as_string(CENTER_PATH)
	_check(center_source.contains('map_id = "kanto_route_3_pokemon_center"'), "center has a unique map id")
	_check(center_source.contains('npc_id = "kanto_route_3_pokemon_center_nurse_joy"'), "center places Nurse Joy")
	_check(center_source.contains('target_spawn_name = "FromPokecenter"'), "center returns to the route")
	var exit := _node_block(route_source, "ToPokecenter")
	_check(exit.contains('target_scene_path = "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"'), "route exit targets the center")
	_check(exit.contains('target_spawn_name = "FromOutside"'), "route exit uses the center doorway")
	_check(route_source.contains('position = Vector2(1760, 688)'), "route has a center return spawn")
	quit(1 if failed else 0)


func _node_block(source: String, node_name: String) -> String:
	var marker := '[node name="%s"' % node_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var end := source.find("\n[node ", start + marker.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		printerr("FAIL %s" % label)
