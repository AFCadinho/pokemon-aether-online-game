extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const OPEN_FIELD_VISUAL := "res://generated/tiled_visuals/open_field/open_field.visual.tscn"
const CONNECTIONS := {
	"cerulean_cave": {
		"scene": "res://scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn",
		"map_id": "kanto_cerulean_cave",
		"city_spawn": "FromCeruleanCave",
		"city_exit": "ToCeruleanCave",
		"city_transition": "kanto_cerulean_city__to_cerulean_cave",
		"return_transition": "kanto_cerulean_cave__to_cerulean_city",
		"connection_side": "bottom",
		"arrival_name": "FromCerulean",
		"return_exit_name": "ToCerulean",
	},
	"route_24": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
		"visual": "res://generated/tiled_visuals/route_24/route_24.visual.tscn",
		"map_id": "kanto_route_24",
		"city_spawn": "FromRoute24Path",
		"city_exit": "ToRoute24Path",
		"city_transition": "kanto_cerulean_city__to_route_24_path",
		"return_transition": "kanto_route_24__to_cerulean_city_path",
		"connection_side": "bottom",
		"arrival_name": "FromCeruleanPath",
		"return_exit_name": "ToCeruleanPath",
	},
	"route_9": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_9.tscn",
		"map_id": "kanto_route_9",
		"city_spawn": "FromRoute9",
		"city_exit": "ToRoute9",
		"city_transition": "kanto_cerulean_city__to_route_9",
		"return_transition": "kanto_route_9__to_cerulean_city",
		"connection_side": "left",
		"arrival_name": "FromCerulean",
		"return_exit_name": "ToCerulean",
	},
	"route_5": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_5.tscn",
		"map_id": "kanto_route_5",
		"city_spawn": "FromRoute5Left",
		"city_exit": "ToRoute5Left",
		"city_transition": "kanto_cerulean_city__to_route_5_left",
		"return_transition": "kanto_route_5__to_cerulean_city_left",
		"connection_side": "bottom",
		"arrival_name": "FromCeruleanLeft",
		"return_exit_name": "ToCeruleanLeft",
	},
}

var failed := false


func _init() -> void:
	var city_source := FileAccess.get_file_as_string(CITY_SCENE)
	var city_script := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/cerulean_city.gd"
	)
	var map_metadata_script := FileAccess.get_file_as_string(
		"res://scripts/world/map_metadata.gd"
	)
	var placeholder_script := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/open_field_placeholder_map.gd"
	)
	var player_script := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var route_24_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
	)
	var route_9_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/routes/kanto_route_9.tscn"
	)
	var route_5_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/routes/kanto_route_5.tscn"
	)

	_check(map_metadata_script.contains('find_map_tilemap_layer("Collision")'), "Cerulean City inherits the shared nested Collision resolver")
	_check(city_script.contains('"route_24_path"') and city_script.contains('"route_24_bridge"'), "Cerulean City opens both Route 24 foot approaches")
	_check(city_script.contains('"route_24_water_left"') and city_script.contains('"route_24_water_right"'), "Cerulean City opens both Route 24 water approaches")
	_check(city_script.contains('"route_4_water"'), "Cerulean City opens the Route 4 water approach")
	_check(city_script.contains('"route_9"'), "Cerulean City opens its Route 9 east boundary")
	_check(city_script.contains('"route_5_left"') and city_script.contains('"route_5_right"'), "Cerulean City opens its Route 5 south boundary")
	_check(placeholder_script.contains("const MAP_SIZE := Vector2i(24, 18)"), "Placeholder boundaries match the open-field visual")
	_check(placeholder_script.contains("func _is_opening"), "Placeholder boundaries retain their connection opening")
	_check(placeholder_script.contains("second_opening_from") and placeholder_script.contains("fourth_opening_from"), "Placeholder maps support four edge openings")
	_check(placeholder_script.contains("func _build_water_connection"), "Placeholder maps can mark a Surf connection")
	_check(placeholder_script.contains("second_water_opening_from"), "Placeholder maps support two Surf connections")
	_check(player_script.contains("sync_activity_state_for_current_tile") and player_script.contains("_start_surf_activity(false)"), "A water arrival restores Surf automatically")
	_check(route_24_source.contains('[node name="Water" type="TileMapLayer" parent="Tiles"'), "Route 24 exposes a semantic Water layer")
	_check(route_24_source.contains('route_24/route_24.visual.tscn'), "Route 24 uses its imported Tiled visual")
	_check(route_24_source.contains('map_size = Vector2i(60, 60)'), "Route 24 bounds match its imported visual")
	_check(route_24_source.contains('water_connection_side = "bottom"'), "Route 24 marks its water approach")
	_check(city_source.contains('[node name="Water" type="TileMapLayer" parent="Tiles"'), "Cerulean City exposes a semantic Water layer")
	_check(city_script.contains("_build_water_connections"), "Cerulean City marks all water approaches")
	_check(city_source.contains('[node name="FromRoute4Water" type="Marker2D" parent="Spawns"'), "Cerulean City has the Route 4 water spawn")
	_check(city_source.contains('[node name="ToRoute4Water" type="Area2D" parent="Exits"'), "Cerulean City has the Route 4 water exit")
	_check(route_24_source.contains('second_water_opening_from = 35'), "Route 24 marks its second Surf approach")

	for suffix: String in ["Left", "Grass", "Right"]:
		_check(city_source.contains('[node name="FromRoute5%s" type="Marker2D" parent="Spawns"' % suffix), "Cerulean City has the Route 5 %s spawn" % suffix.to_lower())
		_check(city_source.contains('[node name="ToRoute5%s" type="Area2D" parent="Exits"' % suffix), "Cerulean City has the Route 5 %s exit" % suffix.to_lower())
		_check(route_5_source.contains('[node name="FromCerulean%s" type="Marker2D" parent="Spawns"]' % suffix), "Route 5 has the %s arrival" % suffix.to_lower())
		_check(route_5_source.contains('[node name="ToCerulean%s" type="Area2D" parent="Exits"]' % suffix), "Route 5 has the %s return exit" % suffix.to_lower())

	for suffix: String in ["Path", "Bridge", "WaterLeft", "WaterRight"]:
		_check(city_source.contains('[node name="FromRoute24%s" type="Marker2D" parent="Spawns"' % suffix), "Cerulean City has the Route 24 %s spawn" % suffix.to_lower())
		_check(city_source.contains('[node name="ToRoute24%s" type="Area2D" parent="Exits"' % suffix), "Cerulean City has the Route 24 %s exit" % suffix.to_lower())
		_check(route_24_source.contains('[node name="FromCerulean%s" type="Marker2D" parent="Spawns"' % suffix), "Route 24 has the %s arrival" % suffix.to_lower())
		_check(route_24_source.contains('[node name="ToCerulean%s" type="Area2D" parent="Exits"' % suffix), "Route 24 has the %s return exit" % suffix.to_lower())

	for connection_name: String in CONNECTIONS:
		var connection: Dictionary = CONNECTIONS[connection_name]
		var scene_path := str(connection.get("scene", ""))
		var scene_source := FileAccess.get_file_as_string(scene_path)
		var map_id := str(connection.get("map_id", ""))
		var expected_visual := str(connection.get("visual", OPEN_FIELD_VISUAL))
		var city_spawn := str(connection.get("city_spawn", ""))
		var city_exit := str(connection.get("city_exit", ""))
		var city_transition := str(connection.get("city_transition", ""))
		var return_transition := str(connection.get("return_transition", ""))
		var connection_side := str(connection.get("connection_side", ""))
		var arrival_name := str(connection.get("arrival_name", "FromCerulean"))
		var return_exit_name := str(connection.get("return_exit_name", "ToCerulean"))

		_check(ResourceLoader.exists(scene_path), "%s scene exists" % connection_name)
		_check(scene_source.contains(expected_visual), "%s uses its expected visual" % connection_name)
		_check(scene_source.contains('map_id = "%s"' % map_id), "%s exposes map metadata" % connection_name)
		_check(scene_source.contains('connection_side = "%s"' % connection_side), "%s opens the correct map edge" % connection_name)
		_check(scene_source.contains('[node name="%s" type="Marker2D" parent="Spawns"' % arrival_name), "%s has a Cerulean arrival" % connection_name)
		_check(scene_source.contains('target_spawn_name = "%s"' % city_spawn), "%s returns to its Cerulean spawn" % connection_name)
		_check(scene_source.contains('transition_id = "%s"' % return_transition), "%s has a stable return transition" % connection_name)
		_check(scene_source.contains('[connection signal="body_entered" from="Exits/%s"' % return_exit_name), "%s listens for its return exit" % connection_name)
		_check(city_source.contains('[node name="%s" type="Marker2D" parent="Spawns"' % city_spawn), "Cerulean City has the %s arrival" % connection_name)
		_check(city_source.contains('[node name="%s" type="Area2D" parent="Exits"' % city_exit), "Cerulean City has the %s exit" % connection_name)
		_check(city_source.contains('target_scene_path = "%s"' % scene_path), "Cerulean City targets %s" % connection_name)
		_check(city_source.contains('transition_id = "%s"' % city_transition), "Cerulean City has a stable %s transition" % connection_name)
		_check(city_source.contains('[connection signal="body_entered" from="Exits/%s"' % city_exit), "Cerulean City listens for the %s exit" % connection_name)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
