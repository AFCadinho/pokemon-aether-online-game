extends SceneTree

const ROUTE_3_PATH := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const CENTER_PATH := "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"

var failed := false


func _init() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_3_PATH)
	var center_source := FileAccess.get_file_as_string(CENTER_PATH)
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
	var mt_moon_lock := _node_block(route_source, "MtMoonCaveLock")
	_check(mt_moon_lock.contains('position = Vector2(2640, 688)'), "Mt. Moon lock blocks the tile before the cave mouth")
	_check(mt_moon_lock.contains('display_name = "Mt. Moon"'), "Mt. Moon lock identifies the closed area")
	_check(mt_moon_lock.contains('fallback_locked_dialogue_lines'), "Mt. Moon lock explains that the map is unavailable")
	_check(route_source.contains('path="res://scenes/world/interactables/locked_door_interactable.tscn" id="13_mt_moon_lock"'), "Mt. Moon reuses the standard locked entrance scene")
	var mt_moon_exit := _node_block(route_source, "ToMtMoon")
	_check(mt_moon_exit.contains('position = Vector2(2640, 672)'), "Mt. Moon exit covers the cave mouth")
	_check(mt_moon_exit.contains('monitoring = false'), "Mt. Moon exit stays inactive until its map exists")
	_check(mt_moon_exit.contains('transition_id = "kanto_route_3__to_mt_moon"'), "Mt. Moon exit reserves a stable transition id")
	_check(mt_moon_exit.contains('metadata/pao_pending_target_map_id = "kanto_mt_moon"'), "Mt. Moon exit records its pending destination")
	var mt_moon_collision := _node_block(route_source, "CollisionShape2D", "Exits/ToMtMoon")
	_check(mt_moon_collision.contains('disabled = true'), "Mt. Moon exit collision stays disabled until its map exists")
	quit(1 if failed else 0)


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
