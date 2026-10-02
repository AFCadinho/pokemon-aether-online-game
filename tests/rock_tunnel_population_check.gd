extends SceneTree

const FLOORS := {
	"1f": {
		"scene": "res://scenes/overworld/kanto/caves/rock_tunnel/1f.tscn",
		"trainer_count": 7,
		"trainer_ids": [
			"kanto_rock_tunnel_1f_pokemaniac_ashton",
			"kanto_rock_tunnel_1f_hiker_lenny",
			"kanto_rock_tunnel_1f_hiker_oliver",
			"kanto_rock_tunnel_1f_hiker_lucas",
			"kanto_rock_tunnel_1f_picnicker_leah",
			"kanto_rock_tunnel_1f_picnicker_ariana",
			"kanto_rock_tunnel_1f_picnicker_dana",
		],
	},
	"b1f": {
		"scene": "res://scenes/overworld/kanto/caves/rock_tunnel/b1f.tscn",
		"trainer_count": 8,
		"trainer_ids": [
			"kanto_rock_tunnel_b1f_pokemaniac_winston",
			"kanto_rock_tunnel_b1f_picnicker_martha",
			"kanto_rock_tunnel_b1f_pokemaniac_steve",
			"kanto_rock_tunnel_b1f_hiker_allen",
			"kanto_rock_tunnel_b1f_hiker_eric",
			"kanto_rock_tunnel_b1f_picnicker_sofia",
			"kanto_rock_tunnel_b1f_hiker_dudley",
			"kanto_rock_tunnel_b1f_pokemaniac_cooper",
		],
	},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for floor_name: String in FLOORS:
		var config: Dictionary = FLOORS[floor_name]
		var scene_path := str(config["scene"])
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "%s scene loads" % floor_name)
		if packed == null:
			continue

		var map := packed.instantiate()
		root.add_child(map)
		await process_frame
		_check(
			str(map.get("encounter_area_id")) == "kanto_rock_tunnel_%s" % floor_name,
			"%s uses the matching encounter area" % floor_name
		)
		_check(
			is_equal_approx(float(map.get("cave_encounter_chance")), 0.07),
			"%s uses the standard cave step chance" % floor_name
		)

		var npcs := map.get_node("Entities/NPCs")
		var collision := map.get_node("Tiles/Collision") as TileMapLayer
		var scene_text := FileAccess.get_file_as_string(scene_path)
		var trainers := npcs.get_children()
		_check(trainers.size() == int(config["trainer_count"]), "%s has all FRLG trainers" % floor_name)
		for trainer_id: String in config["trainer_ids"]:
			_check(scene_text.contains('trainer_id = "%s"' % trainer_id), "%s is registered in the scene" % trainer_id)
		for trainer: Node2D in trainers:
			var cell := collision.local_to_map(collision.to_local(trainer.global_position))
			_check(collision.get_cell_source_id(cell) < 0, "%s stands on a walkable tile" % trainer.name)
			var direction := Vector2i(Vector2(trainer.get("facing_direction")))
			for step in range(1, int(trainer.get("sight_range_tiles")) + 1):
				_check(
					collision.get_cell_source_id(cell + direction * step) < 0,
					"%s has a clear trainer sightline" % trainer.name
				)
			for spawn: Marker2D in map.get_node("Spawns").get_children():
				_check(trainer.position.distance_to(spawn.position) >= 96.0, "%s leaves spawn points clear" % trainer.name)
		map.queue_free()
		await process_frame

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
