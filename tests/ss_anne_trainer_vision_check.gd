extends SceneTree

const MAPS := {
	"ss_anne_1f": ["PassengerEdwin", "PopulationGentlemanThomas", "PopulationYoungsterTyler", "PopulationLassAnn"],
	"ss_anne_2f": ["PopulationGentlemanArthur"],
	"ss_anne_3f": ["PopulationSailorTrevor"],
	"ss_anne_b1f": ["SailorKai", "PopulationSailorDuncan"],
}

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := Node2D.new()
	player.name = "Player"
	for map_name in MAPS:
		var scene := load("res://scenes/overworld/kanto/towns/ss_anne/%s.tscn" % map_name) as PackedScene
		var map := scene.instantiate()
		for trainer_name in MAPS[map_name]:
			var trainer := map.find_child(trainer_name, true, false)
			_check(trainer != null, "%s exists" % trainer_name)
			if trainer == null:
				continue
			trainer.set("feet_marker", trainer.get_node("FeetMarker"))
			var collision := trainer.get_node("VisionArea/CollisionShape2D") as CollisionShape2D
			trainer.set("vision_collision_shape", collision)
			trainer.set("trainer_progress_loaded", true)
			trainer.set("trainer_progress_state", "first_encounter")
			trainer.call("_configure_vision_area")
			_check(int(trainer.get("sight_range_tiles")) == 3 and not collision.disabled,
				"%s has active three-tile vision" % trainer_name)
			_check(bool(trainer.call("_can_auto_challenge")), "%s can auto-challenge" % trainer_name)
			var feet: Vector2 = trainer.call("get_feet_position")
			var direction: Vector2 = trainer.get("facing_direction")
			for distance in [1, 2, 3]:
				player.global_position = feet + direction * 32 * distance
				_check(bool(trainer.call("_is_body_in_sight_range", player)),
					"%s sees player %d tiles ahead" % [trainer_name, distance])
			for offset in [direction * 128, -direction * 32, Vector2(-direction.y, direction.x) * 32]:
				player.global_position = feet + offset
				_check(not bool(trainer.call("_is_body_in_sight_range", player)),
					"%s ignores player outside sightline %s" % [trainer_name, offset])
			trainer.set("trainer_progress_state", "defeated")
			trainer.call("_configure_vision_area")
			_check(collision.disabled and not bool(trainer.call("_can_auto_challenge")),
				"%s stops auto-challenging after defeat" % trainer_name)
		map.free()
	player.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
