extends SceneTree

const ROUTE_SCENE_PATH := "res://scenes/overworld/kanto/routes/kanto_route_4.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Route 4 scene loads with encounter and trainer content")
	if packed_scene == null:
		quit(1)
		return

	var route := packed_scene.instantiate()
	root.add_child(route)
	await process_frame

	_check(route.get_wild_encounter_area_id() == "kanto_route_4", "Route 4 uses its backend encounter area")
	_check(is_equal_approx(route.grass_encounter_chance, 0.21), "Route 4 grass uses the canonical encounter chance")

	var expected_trainers := {
		"PicnickerHope": "kanto_route_4_picnicker_hope",
		"BirdKeeperHank": "kanto_route_4_bird_keeper_hank",
		"PicnickerSharon": "kanto_route_4_picnicker_sharon",
	}
	var collision := route.get_node("Tiles/Collision") as TileMapLayer
	for node_name: String in expected_trainers:
		var trainer := route.get_node_or_null("Entities/NPCs/%s" % node_name)
		_check(trainer != null, "Route 4 places %s" % node_name)
		if trainer == null:
			continue
		_check(trainer.trainer_id == expected_trainers[node_name], "%s uses the matching trainer metadata" % node_name)
		var trainer_cell := collision.local_to_map(trainer.position)
		_check(collision.get_cell_source_id(trainer_cell) < 0, "%s stands on a walkable tile" % node_name)

	route.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
