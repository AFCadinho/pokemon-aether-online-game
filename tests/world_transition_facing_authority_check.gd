extends SceneTree

const CATALOG_PATH := "res://generated/world_access_catalog.json"
const ROUTE_10_PATH := "res://scenes/overworld/kanto/routes/kanto_route_10.tscn"

var failed := false


func _init() -> void:
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_check(catalog_value is Dictionary, "world access catalog is valid JSON")
	if catalog_value is Dictionary:
		var transitions: Dictionary = (catalog_value as Dictionary).get("transitions", {})
		var north_entry: Dictionary = transitions.get("kanto_route_10__to_rock_tunnel_north", {})
		_check(not north_entry.is_empty(), "Route 10 north cave transition exists")
		var catalog_has_facing := false
		for transition_id: String in transitions:
			var transition: Dictionary = transitions[transition_id]
			var destination: Dictionary = transition.get("destination", {})
			catalog_has_facing = catalog_has_facing or destination.has("facingDirection")
		_check(not catalog_has_facing, "transition catalog leaves arrival direction to the client")

	var route_10_source := FileAccess.get_file_as_string(ROUTE_10_PATH)
	var north_exit := _node_block(route_10_source, "ToRockTunnelNorth")
	_check(not north_exit.is_empty(), "Route 10 north cave exit exists")
	_check(
		north_exit.contains('transition_facing_direction = "down"'),
		"Route 10 exit supplies the client arrival direction"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)


func _node_block(source: String, node_name: String) -> String:
	var start := source.find('[node name="%s"' % node_name)
	if start < 0:
		return ""
	var end := source.find("\n[node ", start + 1)
	return source.substr(start, end - start if end >= 0 else source.length())
