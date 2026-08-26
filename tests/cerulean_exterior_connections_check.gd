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
	},
	"route_24": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
		"map_id": "kanto_route_24",
		"city_spawn": "FromRoute24",
		"city_exit": "ToRoute24",
		"city_transition": "kanto_cerulean_city__to_route_24",
		"return_transition": "kanto_route_24__to_cerulean_city",
		"connection_side": "bottom",
	},
	"route_9": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_9.tscn",
		"map_id": "kanto_route_9",
		"city_spawn": "FromRoute9",
		"city_exit": "ToRoute9",
		"city_transition": "kanto_cerulean_city__to_route_9",
		"return_transition": "kanto_route_9__to_cerulean_city",
		"connection_side": "left",
	},
	"route_5": {
		"scene": "res://scenes/overworld/kanto/routes/kanto_route_5.tscn",
		"map_id": "kanto_route_5",
		"city_spawn": "FromRoute5",
		"city_exit": "ToRoute5",
		"city_transition": "kanto_cerulean_city__to_route_5",
		"return_transition": "kanto_route_5__to_cerulean_city",
		"connection_side": "top",
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

	_check(map_metadata_script.contains('find_map_tilemap_layer("Collision")'), "Cerulean City inherits the shared nested Collision resolver")
	_check(city_script.contains('"route_24"'), "Cerulean City opens its north collision boundary")
	_check(city_script.contains('"route_9"'), "Cerulean City opens its east collision boundary")
	_check(city_script.contains('"route_5"'), "Cerulean City opens its south collision boundary")
	_check(placeholder_script.contains("const MAP_SIZE := Vector2i(24, 18)"), "Placeholder boundaries match the open-field visual")
	_check(placeholder_script.contains("func _is_opening"), "Placeholder boundaries retain their connection opening")

	for connection_name: String in CONNECTIONS:
		var connection: Dictionary = CONNECTIONS[connection_name]
		var scene_path := str(connection.get("scene", ""))
		var scene_source := FileAccess.get_file_as_string(scene_path)
		var map_id := str(connection.get("map_id", ""))
		var city_spawn := str(connection.get("city_spawn", ""))
		var city_exit := str(connection.get("city_exit", ""))
		var city_transition := str(connection.get("city_transition", ""))
		var return_transition := str(connection.get("return_transition", ""))
		var connection_side := str(connection.get("connection_side", ""))

		_check(ResourceLoader.exists(scene_path), "%s scene exists" % connection_name)
		_check(scene_source.contains(OPEN_FIELD_VISUAL), "%s uses the open-field visual" % connection_name)
		_check(scene_source.contains('map_id = "%s"' % map_id), "%s exposes map metadata" % connection_name)
		_check(scene_source.contains('connection_side = "%s"' % connection_side), "%s opens the correct map edge" % connection_name)
		_check(scene_source.contains('[node name="FromCerulean" type="Marker2D" parent="Spawns"]'), "%s has a Cerulean arrival" % connection_name)
		_check(scene_source.contains('target_spawn_name = "%s"' % city_spawn), "%s returns to its Cerulean spawn" % connection_name)
		_check(scene_source.contains('transition_id = "%s"' % return_transition), "%s has a stable return transition" % connection_name)
		_check(scene_source.contains('[connection signal="body_entered" from="Exits/ToCerulean"'), "%s listens for its return exit" % connection_name)
		_check(city_source.contains('[node name="%s" type="Marker2D" parent="Spawns"]' % city_spawn), "Cerulean City has the %s arrival" % connection_name)
		_check(city_source.contains('[node name="%s" type="Area2D" parent="Exits"]' % city_exit), "Cerulean City has the %s exit" % connection_name)
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
