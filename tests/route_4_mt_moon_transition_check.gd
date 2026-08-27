extends SceneTree

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
	)
	var cave_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn"
	)
	var cerulean_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
	)
	var route_script := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/routes/kanto_route_4.gd"
	)
	var route_visual := FileAccess.get_file_as_string(
		"res://generated/tiled_visuals/route_4/route_4.visual.tscn"
	)
	var cerulean_script := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/cerulean_city.gd"
	)
	var map_metadata_script := FileAccess.get_file_as_string(
		"res://scripts/world/map_metadata.gd"
	)
	var cerulean_visual := FileAccess.get_file_as_string(
		"res://generated/tiled_visuals/cerulean_city/cerulean_city.visual.tscn"
	)

	_check(route_source.contains('map_id = "kanto_route_4"'), "Route 4 exposes map metadata")
	_check(route_source.contains('route_4/route_4.visual.tscn'), "Route 4 uses its imported visual")
	_check(route_visual.contains('"height": 50'), "Route 4 visual preserves the Tiled height")
	_check(route_visual.contains('"width": 100'), "Route 4 visual preserves the Tiled width")
	_check(route_source.contains('[node name="FromMtMoon" type="Marker2D" parent="Spawns"'), "Route 4 has a Mt. Moon arrival")
	_check(route_source.contains('position = Vector2(208, 976)'), "Mt. Moon arrival is outside the imported cave entrance")
	_check(route_source.contains('transition_id = "kanto_route_4__to_mt_moon"'), "Route 4 returns to Mt. Moon")
	_check(route_source.contains('target_spawn_name = "FromRoute4"'), "Route 4 targets the cave return spawn")
	_check(route_source.contains('transition_facing_direction = "down"'), "Route 4 entry faces the player into Mt. Moon")
	_check(route_source.contains('[connection signal="body_entered" from="Exits/ToMtMoon"'), "Route 4 listens for the cave return")
	_check(route_source.contains('[node name="FromCerulean" type="Marker2D" parent="Spawns"'), "Route 4 has a Cerulean City arrival")
	_check(route_source.contains('position = Vector2(3136, 1216)'), "Cerulean City arrival is on the imported east road")
	_check(route_source.contains('transition_id = "kanto_route_4__to_cerulean_city"'), "Route 4 exits to Cerulean City")
	_check(route_source.contains('target_spawn_name = "FromRoute4"'), "Route 4 targets the Cerulean City arrival")
	_check(route_source.contains('transition_facing_direction = "right"'), "Cerulean City arrival faces east")
	_check(route_source.contains('[node name="FromCeruleanWater" type="Marker2D" parent="Spawns"]'), "Route 4 has a Cerulean water arrival")
	_check(route_source.contains('position = Vector2(3136, 1008)'), "Cerulean water arrival is on the imported east water")
	_check(route_source.contains('transition_id = "kanto_route_4__to_cerulean_city_water"'), "Route 4 water exits to Cerulean City")
	_check(route_source.contains('target_spawn_name = "FromRoute4Water"'), "Route 4 water targets the Cerulean water arrival")
	_check(route_script.contains('const MAP_SIZE := Vector2i(100, 50)'), "Route 4 bounds match its imported visual")
	_check(route_script.contains('not _is_cerulean_connection_y(y)'), "Route 4 keeps the Cerulean road and water open")
	_check(cave_source.contains('[node name="FromRoute4" type="Marker2D" parent="Spawns"'), "Mt. Moon has a Route 4 return spawn")
	_check(cave_source.contains('transition_id = "kanto_mt_moon__to_route_4"'), "Mt. Moon exits to Route 4")
	_check(cave_source.contains('target_spawn_name = "FromMtMoon"'), "Mt. Moon targets the Route 4 arrival")
	_check(cave_source.contains('[connection signal="body_entered" from="Exits/ToRoute4"'), "Mt. Moon listens for the Route 4 exit")
	_check(cerulean_source.contains('map_id = "kanto_cerulean_city"'), "Cerulean City exposes map metadata")
	_check(cerulean_source.contains('cerulean_city/cerulean_city.visual.tscn'), "Cerulean City uses its imported visual")
	_check(cerulean_visual.contains('"height": 70'), "Cerulean City visual preserves the Tiled height")
	_check(cerulean_visual.contains('"width": 75'), "Cerulean City visual preserves the Tiled width")
	_check(cerulean_visual.contains('metadata/tiled_name = "Doors"'), "Cerulean City visual preserves its door layer")
	_check(cerulean_visual.contains('metadata/tiled_layer_id = 4'), "Cerulean City visual preserves its foreground layer")
	_check(cerulean_source.contains('[node name="FromRoute4" type="Marker2D" parent="Spawns"'), "Cerulean City has a Route 4 arrival")
	_check(cerulean_source.contains('position = Vector2(48, 816)'), "Route 4 arrival is on the imported west road")
	_check(cerulean_source.contains('transition_id = "kanto_cerulean_city__to_route_4"'), "Cerulean City returns to Route 4")
	_check(cerulean_source.contains('target_spawn_name = "FromCerulean"'), "Cerulean City targets the Route 4 arrival")
	_check(cerulean_source.contains('transition_facing_direction = "left"'), "Route 4 return faces west")
	_check(cerulean_source.contains('[connection signal="body_entered" from="Exits/ToRoute4"'), "Cerulean City listens for the Route 4 exit")
	_check(cerulean_source.contains('[node name="FromRoute4Water" type="Marker2D" parent="Spawns"'), "Cerulean City has a Route 4 water arrival")
	_check(cerulean_source.contains('transition_id = "kanto_cerulean_city__to_route_4_water"'), "Cerulean City returns to Route 4 water")
	_check(cerulean_source.contains('target_spawn_name = "FromCeruleanWater"'), "Cerulean City targets the Route 4 water arrival")
	_check(cerulean_script.contains('const MAP_SIZE := Vector2i(75, 70)'), "Cerulean City bounds match its imported visual")
	_check(map_metadata_script.contains('find_map_tilemap_layer("Collision")'), "Cerulean City inherits the shared Collision layer resolver")
	_check(cerulean_script.contains('"route_4"'), "Cerulean City keeps the Route 4 road open")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
