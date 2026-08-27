extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const BRIDGE_SCRIPT := "res://scripts/world/kanto/routes/nugget_bridge_trainer.gd"
const CITY_TRAINERS := [
	{
		"node": "NuggetBridge01Cale",
		"id": "kanto_route_24_nugget_bridge_01_cale",
		"position": Vector2(1808, 560),
		"definition": "trainer_class_bug_catcher",
	},
	{
		"node": "NuggetBridge02Ali",
		"id": "kanto_route_24_nugget_bridge_02_ali",
		"position": Vector2(1808, 304),
		"definition": "trainer_class_lass",
	},
]
const ROUTE_TRAINERS := [
	{
		"node": "NuggetBridge03Timmy",
		"id": "kanto_route_24_nugget_bridge_03_timmy",
		"position": Vector2(704, 1664),
		"definition": "trainer_class_youngster",
	},
	{
		"node": "NuggetBridge04Reli",
		"id": "kanto_route_24_nugget_bridge_04_reli",
		"position": Vector2(704, 1280),
		"definition": "trainer_class_lass",
	},
	{
		"node": "NuggetBridge05Ethan",
		"id": "kanto_route_24_nugget_bridge_05_ethan",
		"position": Vector2(704, 896),
		"definition": "trainer_class_rocket_grunt",
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
		_count_bridge_trainers(route_24) == 3,
		"Route 24 owns the final three Nugget Bridge challengers"
	)
	var bridge_source := FileAccess.get_file_as_string(BRIDGE_SCRIPT)
	_check(
		bridge_source.contains("challenge_width_tiles")
		and bridge_source.contains("battles in place"),
		"Nugget Bridge challengers guard the complete bridge width"
	)
	var recruiter := route_24.get_node("Entities/NPCs/NuggetBridge05Ethan")
	_check(recruiter.one_time_challenge, "Rocket recruiter cannot grant repeat challenge rewards")
	_check(
		recruiter.post_victory_quest_id == "learn_to_pickpocket",
		"Rocket recruiter offers the existing Thieving side quest"
	)
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(
		world_source.contains("_show_trainer_post_victory_offer(reward_trainer_id)"),
		"Trainer victory flow opens configured post-battle quest offers"
	)
	_check(
		world_source.contains("_notify_trainer_reward_items(reward.get(\"items\", []))"),
		"Trainer victory flow announces item rewards"
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
		_check(trainer.facing_direction == Vector2.DOWN, "%s faces approaching players" % expected.node)
		_check(trainer.sight_range_tiles == 5, "%s has consistent bridge sight range" % expected.node)
		_check(
			trainer.get_script().resource_path == BRIDGE_SCRIPT,
			"%s uses the bridge-wide challenge behavior" % expected.node
		)
		var cell := collision.local_to_map(trainer.position)
		_check(collision.get_cell_source_id(cell) < 0, "%s stands on walkable bridge flooring" % expected.node)
		_check(water == null or water.get_cell_source_id(cell) < 0, "%s stands outside the water mask" % expected.node)


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
