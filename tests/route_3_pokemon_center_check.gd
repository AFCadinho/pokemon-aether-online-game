extends SceneTree

const ROUTE_3_PATH := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const CENTER_PATH := "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"
const MT_MOON_1F_PATH := "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_3_PATH)
	var center_source := FileAccess.get_file_as_string(CENTER_PATH)
	var mt_moon_source := FileAccess.get_file_as_string(MT_MOON_1F_PATH)
	_check_route_3_center_npc_spacing()
	_check(center_source.contains('map_id = "kanto_route_3_pokemon_center"'), "center has a unique map id")
	_check(center_source.contains('npc_id = "kanto_route_3_pokemon_center_nurse_joy"'), "center places Nurse Joy")
	_check(center_source.contains('npc_id = "kanto_route_3_pokemon_center_magikarp_salesman"'), "center places the Magikarp salesman")
	_check(center_source.contains('target_spawn_name = "FromPokecenter"'), "center returns to the route")
	var exit := _node_block(route_source, "ToPokecenter")
	_check(exit.contains('target_scene_path = "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"'), "route exit targets the center")
	_check(exit.contains('target_spawn_name = "FromOutside"'), "route exit uses the center doorway")
	var center_spawn := _node_block(route_source, "FromPokecenter")
	_check(center_spawn.contains('position = Vector2(2864, 1104)'), "route has a center return spawn")
	var mt_moon_spawn := _node_block(route_source, "FromMtMoon")
	_check(mt_moon_spawn.contains('position = Vector2(2640, 720)'), "route has a Mt. Moon return spawn")
	var mt_moon_exit := _node_block(route_source, "ToMtMoon")
	_check(mt_moon_exit.contains('position = Vector2(2640, 672)'), "Mt. Moon exit covers the cave mouth")
	_check(mt_moon_exit.contains('target_scene_path = "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn"'), "Route 3 exit targets Mt. Moon 1F")
	_check(mt_moon_exit.contains('target_spawn_name = "FromRoute3"'), "Route 3 exit uses the Mt. Moon entrance spawn")
	_check(mt_moon_exit.contains('transition_id = "kanto_route_3__to_mt_moon"'), "Mt. Moon exit reserves a stable transition id")
	_check(mt_moon_exit.contains('transition_facing_direction = "up"'), "Route 3 entry faces into the cave")
	var mt_moon_collision := _node_block(route_source, "CollisionShape2D", "Exits/ToMtMoon")
	_check(not mt_moon_collision.contains('disabled = true'), "Mt. Moon exit collision is enabled")
	_check(not route_source.contains('[node name="MtMoonCaveLock"'), "the temporary Mt. Moon lock is removed")
	_check(route_source.contains('[connection signal="body_entered" from="Exits/ToMtMoon"'), "Route 3 listens for Mt. Moon entry")
	_check(mt_moon_source.contains('map_id = "kanto_mt_moon_1f"'), "Mt. Moon 1F has a unique map id")
	_check(mt_moon_source.contains('battle_environment_id = "cave"'), "Mt. Moon uses the cave battle environment")
	var route_3_spawn := _node_block(mt_moon_source, "FromRoute3")
	_check(route_3_spawn.contains('position = Vector2(944, 2448)'), "Mt. Moon spawn sits above the Route 3 entrance")
	var route_3_exit := _node_block(mt_moon_source, "ToRoute3")
	_check(route_3_exit.contains('position = Vector2(960, 2480)'), "Mt. Moon exit covers the visible entrance")
	_check(route_3_exit.contains('target_scene_path = "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"'), "Mt. Moon exit targets Route 3")
	_check(route_3_exit.contains('target_spawn_name = "FromMtMoon"'), "Mt. Moon exit uses the Route 3 return spawn")
	_check(route_3_exit.contains('transition_id = "kanto_mt_moon_1f__to_route_3"'), "Mt. Moon return has a stable transition id")
	_check(route_3_exit.contains('transition_facing_direction = "down"'), "Mt. Moon exit faces the player away from the cave")
	_check(mt_moon_source.contains('[connection signal="body_entered" from="Exits/ToRoute3"'), "Mt. Moon listens for Route 3 return")
	quit(1 if failed else 0)


func _check_route_3_center_npc_spacing() -> void:
	var packed := load(CENTER_PATH) as PackedScene
	_check(packed != null, "Route 3 Pokemon Center loads for NPC spacing")
	if packed == null:
		return
	var center := packed.instantiate()
	var deleter := center.get_node_or_null("Entities/NPCs/MoveDeleter") as Node2D
	var iris := center.get_node_or_null("Entities/NPCs/CamperIris") as Node2D
	var paras := center.get_node_or_null("Entities/Pokemon/Paras") as Node2D
	_check(deleter != null and iris != null and paras != null, "Route 3 Pokemon Center exposes specialist NPCs and Paras")
	if deleter != null and iris != null and paras != null:
		_check(iris.position != deleter.position, "Camper Iris no longer overlaps the Move Deleter")
		_check(paras.position != deleter.position, "Paras no longer overlaps the Move Deleter")
		_check(iris.position != paras.position, "Camper Iris and Paras have separate positions")
	center.free()


func _node_block(source: String, node_name: String, parent := "") -> String:
	var marker := '[node name="%s"' % node_name
	if not parent.is_empty():
		marker += ' type="CollisionShape2D" parent="%s"' % parent
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
