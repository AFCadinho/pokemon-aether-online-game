extends SceneTree

const ROUTE_10_PATH := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"
const ROCK_TUNNEL_1F_PATH := "res://scenes/overworld/kanto/caves/rock_tunnel/1f.tscn"

var failed := false


func _init() -> void:
	var route_10 := FileAccess.get_file_as_string(ROUTE_10_PATH)
	var cave := FileAccess.get_file_as_string(ROCK_TUNNEL_1F_PATH)
	var route_exit := _node_block(route_10, "ToRockTunnelNorth")
	_check(route_exit.contains('target_spawn_name = "FromRoute10North"'), "Route 10 targets the north cave entrance")
	_check(route_exit.contains('transition_facing_direction = "down"'), "arrival in Rock Tunnel faces down into the cave")
	var cave_exit := _node_block(cave, "ToRoute10North")
	_check(cave_exit.contains('transition_facing_direction = "down"'), "return to Route 10 faces away from the cave")
	quit(1 if failed else 0)


func _node_block(source: String, node_name: String) -> String:
	var start := source.find('[node name="%s"' % node_name)
	if start < 0:
		return ""
	var end := source.find("\n[node ", start + 1)
	return source.substr(start, end - start if end >= 0 else source.length())


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		printerr("FAIL %s" % label)
