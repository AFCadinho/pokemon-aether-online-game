extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const BRIDGE_SCRIPT := "res://scripts/world/kanto/routes/nugget_bridge_trainer.gd"
const RECRUITER_SCRIPT := "res://scripts/world/kanto/routes/nugget_bridge_recruiter.gd"
const CITY_TRAINERS := [
	{
		"node": "NuggetBridge01Cale",
		"id": "kanto_route_24_nugget_bridge_01_cale",
		"position": Vector2(1872, 464),
		"definition": "trainer_class_bug_catcher",
	},
	{
		"node": "NuggetBridge02Ali",
		"id": "kanto_route_24_nugget_bridge_02_ali",
		"position": Vector2(1872, 176),
		"definition": "trainer_class_lass",
	},
]
const ROUTE_TRAINERS := [
	{
		"node": "NuggetBridge03Timmy",
		"id": "kanto_route_24_nugget_bridge_03_timmy",
		"position": Vector2(1072, 1808),
		"definition": "trainer_class_youngster",
	},
	{
		"node": "NuggetBridge04Reli",
		"id": "kanto_route_24_nugget_bridge_04_reli",
		"position": Vector2(1072, 1424),
		"definition": "trainer_class_lass",
	},
	{
		"node": "NuggetBridge05Ethan",
		"id": "kanto_route_24_nugget_bridge_05_ethan",
		"position": Vector2(1072, 1040),
		"definition": "trainer_class_camper",
	},
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := await _instantiate_map(CITY_SCENE)
	var route_24 := await _instantiate_map(ROUTE_24_SCENE)
	_check_trainers(city, CITY_TRAINERS, "Cerulean City")
	_check_trainers(route_24, ROUTE_TRAINERS, "Route 24")
	_check(
		_count_bridge_trainers(city) == 2,
		"Cerulean City owns the first two Nugget Bridge challengers"
	)
	_check(
		_count_bridge_trainers(route_24) == 4,
		"Route 24 owns three challengers plus the separate Rocket recruiter"
	)
	var bridge_source := FileAccess.get_file_as_string(BRIDGE_SCRIPT)
	_check(
		not bridge_source.contains("challenge_width_tiles")
		and not bridge_source.contains("func _is_body_in_sight_range")
		and bridge_source.contains("hold their reviewed positions"),
		"Nugget Bridge challengers use standard straight-line trainer sight"
	)
	var recruiter := route_24.get_node("Entities/NPCs/NuggetBridgeRocketRecruiter")
	_check(recruiter.position == Vector2(1072, 752), "Recruiter keeps the reviewed post-bridge tile")
	_check(recruiter.sight_range_tiles == 5, "Disguised recruiter stops players automatically")
	_check_bridge_sight_lane(recruiter, "NuggetBridgeRocketRecruiter")
	_check(not recruiter.rematch_marker.visible, "Disguised recruiter shows no trainer challenge marker")
	_check(recruiter.npc_definition_id == "trainer_class_camper", "Recruiter begins in an ordinary disguise")
	_check(recruiter.display_name == "Bridge Attendant", "Recruiter hides his identity before the reveal")
	_check(
		recruiter.get_script().resource_path == RECRUITER_SCRIPT,
		"Recruiter uses the scripted prize and reveal sequence"
	)
	var collision := route_24.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := route_24.find_map_tilemap_layer("Water") as TileMapLayer
	var recruiter_cell := collision.local_to_map(recruiter.position)
	_check(collision.get_cell_source_id(recruiter_cell) < 0, "Recruiter stands on walkable ground")
	_check(water == null or water.get_cell_source_id(recruiter_cell) < 0, "Recruiter stands outside water")
	var recruiter_source := FileAccess.get_file_as_string(RECRUITER_SCRIPT)
	_check(
		recruiter_source.contains("func show_intro_dialogue()")
		and recruiter_source.contains("await _run_recruitment_sequence()"),
		"Recruiter vision starts the prize and reveal sequence"
	)
	_check(
		recruiter_source.contains("kanto_route_24_nugget_bridge_big_nugget"),
		"Recruiter claims the one-time Big Nugget prize"
	)
	var refusal_position := recruiter_source.find('REFUSAL_DIALOGUE_ID, ["No."]')
	var reveal_position := recruiter_source.find("_reveal_team_rocket()", refusal_position)
	var challenge_position := recruiter_source.find("CHALLENGE_DIALOGUE_ID,", reveal_position)
	var battle_position := recruiter_source.find(
		"start_trainer_battle(trainer_metadata)",
		challenge_position
	)
	_check(
		refusal_position >= 0
		and reveal_position > refusal_position
		and challenge_position > reveal_position
		and battle_position > challenge_position,
		"Recruiter auto-refuses before the outfit reveal, threat, and battle"
	)
	_check(
		not recruiter_source.contains("learn_to_pickpocket")
		and not recruiter_source.contains("start_quest_offer"),
		"Rocket recruitment scene does not activate a quest"
	)
	city.queue_free()
	route_24.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_trainers(map: Node, expected_trainers: Array, map_label: String) -> void:
	var collision := map.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := map.find_map_tilemap_layer("Water") as TileMapLayer
	for expected: Dictionary in expected_trainers:
		var trainer := map.get_node_or_null("Entities/NPCs/%s" % expected.node)
		_check(trainer != null, "%s places %s" % [map_label, expected.node])
		if trainer == null:
			continue
		_check(trainer.trainer_id == expected.id, "%s has its ordered trainer ID" % expected.node)
		_check(trainer.npc_id == expected.id, "%s has a stable NPC ID" % expected.node)
		_check(
			trainer.npc_definition_id == expected.definition,
			"%s uses its trainer class" % expected.node
		)
		_check(trainer.position == expected.position, "%s keeps its reviewed bridge tile" % expected.node)
		_check(trainer.facing_direction == Vector2.LEFT, "%s faces approaching players" % expected.node)
		_check(trainer.sight_range_tiles == 5, "%s has consistent bridge sight range" % expected.node)
		_check(
			trainer.get_script().resource_path == BRIDGE_SCRIPT,
			"%s uses the bridge challenge behavior" % expected.node
		)
		_check_bridge_sight_lane(trainer, expected.node)
		var cell := collision.local_to_map(trainer.position)
		_check(collision.get_cell_source_id(cell) < 0, "%s stands on walkable bridge flooring" % expected.node)
		_check(water == null or water.get_cell_source_id(cell) < 0, "%s stands outside the water mask" % expected.node)


func _check_bridge_sight_lane(trainer: Node2D, trainer_name: String) -> void:
	var player := Node2D.new()
	trainer.add_sibling(player)
	var feet_position: Vector2 = trainer.get_feet_position()
	var vision_shape := trainer.vision_collision_shape.shape as RectangleShape2D
	_check(
		vision_shape != null
		and vision_shape.size.y == 32.0
		and trainer.vision_collision_shape.position.y == 0.0,
		"%s has a one-tile-high physical sight lane" % trainer_name
	)
	player.global_position = feet_position + Vector2(-32, 0)
	_check(
		bool(trainer.call("_is_body_in_sight_range", player)),
		"%s sees a player directly ahead" % trainer_name
	)
	player.global_position = feet_position + Vector2(-32, 32)
	_check(
		not bool(trainer.call("_is_body_in_sight_range", player)),
		"%s does not challenge a player one tile below its line of sight" % trainer_name
	)
	player.queue_free()


func _count_bridge_trainers(map: Node) -> int:
	var count := 0
	for child: Node in map.get_node("Entities/NPCs").get_children():
		if child.name.begins_with("NuggetBridge"):
			count += 1
	return count


func _instantiate_map(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	return map


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
