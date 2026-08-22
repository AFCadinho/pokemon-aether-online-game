extends SceneTree

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
	)
	var cave_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn"
	)
	var route_script := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/routes/kanto_route_4.gd"
	)

	_check(route_source.contains('map_id = "kanto_route_4"'), "Route 4 exposes map metadata")
	_check(route_source.contains('open_field/open_field.visual.tscn'), "Route 4 uses the open-field visual")
	_check(route_source.contains('[node name="FromMtMoon" type="Marker2D" parent="Spawns"'), "Route 4 has a Mt. Moon arrival")
	_check(route_source.contains('transition_id = "kanto_route_4__to_mt_moon"'), "Route 4 returns to Mt. Moon")
	_check(route_source.contains('target_spawn_name = "FromRoute4"'), "Route 4 targets the cave return spawn")
	_check(route_source.contains('transition_facing_direction = "down"'), "Route 4 entry faces the player into Mt. Moon")
	_check(route_source.contains('[connection signal="body_entered" from="Exits/ToMtMoon"'), "Route 4 listens for the cave return")
	_check(route_script.contains('const MAP_SIZE := Vector2i(24, 18)'), "Route 4 bounds match its placeholder visual")
	_check(route_script.contains('if x < ROAD_MIN_X or x > ROAD_MAX_X:'), "Route 4 keeps the entrance road open")
	_check(cave_source.contains('[node name="FromRoute4" type="Marker2D" parent="Spawns"'), "Mt. Moon has a Route 4 return spawn")
	_check(cave_source.contains('transition_id = "kanto_mt_moon__to_route_4"'), "Mt. Moon exits to Route 4")
	_check(cave_source.contains('target_spawn_name = "FromMtMoon"'), "Mt. Moon targets the Route 4 arrival")
	_check(cave_source.contains('[connection signal="body_entered" from="Exits/ToRoute4"'), "Mt. Moon listens for the Route 4 exit")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
