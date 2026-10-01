extends SceneTree

const ROUTE_PATH := "res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn"
const HOUSE_PATH := "res://scenes/overworld/kanto/routes/route2/route_2_house.tscn"

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_PATH)
	var house_source := FileAccess.get_file_as_string(HOUSE_PATH)
	_check(not route_source.is_empty(), "%s loads" % ROUTE_PATH)
	_check(not house_source.is_empty(), "%s loads" % HOUSE_PATH)
	var house_scene := load(HOUSE_PATH) as PackedScene
	_check(house_scene != null, "Route 2 house scene and NPC script resources load")
	if house_scene != null:
		var house_instance := house_scene.instantiate()
		_check(
			house_instance.get_node_or_null("Entities/NPCs/OakAssistant") != null,
			"Oak's assistant instantiates in the Route 2 house"
		)
		house_instance.free()
	_check_route(route_source)
	_check_house(house_source)
	quit(1 if failed else 0)


func _check_route(source: String) -> void:
	var arrival := _node_block(source, "FromHouse")
	_check(arrival.contains("position = Vector2(1424, 560)"), "Route 2 has a safe arrival below the house door")
	var exit := _node_block(source, "ToHouse")
	_check(exit.contains("position = Vector2(1424, 528)"), "Route 2 house transition aligns with the mapped door")
	_check(exit.contains('target_scene_path = "%s"' % HOUSE_PATH), "Route 2 targets the new house interior")
	_check(exit.contains('target_spawn_name = "FromRoute2"'), "Route 2 targets the indoor arrival")
	_check(exit.contains('transition_facing_direction = "up"'), "Entering the house faces the player inward")


func _check_house(source: String) -> void:
	_check(source.contains('map_id = "kanto_route_2_house"'), "Route 2 house exposes unique map metadata")
	_check(source.contains('world_access_group_id = "kanto_route_2"'), "Route 2 house belongs to the Route 2 access group")
	_check(source.contains('world_access_area_type = "interior"'), "Route 2 house is registered as an interior")
	_check(source.contains('lighting_profile = "indoor"'), "Route 2 house uses indoor lighting")
	_check(source.contains('weather_profile = "disabled"'), "Route 2 house disables outdoor weather")
	_check(source.contains('[node name="BrownHouseTemplate" parent="." instance='), "Route 2 house reuses the brown-house template")
	_check(source.contains('[node name="Players" type="Node2D" parent="Entities"]'), "Route 2 house provides the multiplayer player container")
	_check(source.contains('npc_id = "kanto_route_2_house_oak_assistant"'), "Route 2 house contains Oak's assistant")
	_check(source.contains('script = ExtResource("7_oak_assistant")'), "Oak's assistant uses the Pokédex quest interaction")
	_check(source.contains('npc_sprite_frames = ExtResource("8_scientist_m")'), "Oak's assistant uses the scientist overworld sprite")
	_check(source.contains('portrait_id = "showdown_scientist_gen7"'), "Oak's assistant uses a scientist portrait")
	_check(not source.contains("kanto_route_2_house_poke_fan_miles"), "Poke Fan Miles was removed")
	_check(not source.contains("kanto_route_2_house_school_kid_nolan"), "School Kid Nolan was removed")
	_check(source.contains('[node name="FromRoute2" type="Marker2D" parent="Spawns"]\nposition = Vector2(304, 464)'), "Route 2 house has a safe indoor arrival")
	var exit := _node_block(source, "ToRoute2")
	_check(not exit.is_empty(), "Route 2 house has an exit back to the route")
	_check(exit.contains('target_scene_path = "%s"' % ROUTE_PATH), "Route 2 house returns to Route 2")
	_check(exit.contains('target_spawn_name = "FromHouse"'), "Route 2 house targets the outdoor arrival")
	_check(exit.contains('transition_facing_direction = "down"'), "Leaving the house faces the player onto the route")
func _node_block(source: String, node_name: String) -> String:
	var start := source.find('[node name="%s"' % node_name)
	if start < 0:
		return ""
	var finish := source.find("\n[node ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
