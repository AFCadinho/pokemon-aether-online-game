extends "res://tools/sprite_factory/measure_model_grounding.gd"
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
const Profiles = preload("res://scripts/battle/battle_ui/reviewed_motion_placement.json")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".grounding.json"))
	var world := Node3D.new()
	root.add_child(world)
	for entry: Dictionary in catalog:
		var hash := FileAccess.get_sha256(entry.runtime_path)
		var placement := Placement.resolve(entry, calibration.entries[entry.species], hash)
		var clips := Motion.resolve(Profiles.data[entry.species], placement, hash, entry.action_timing)
		assert(not clips.is_empty(), "Reviewed profile did not bind: " + str(entry.species))
		var actor: Node3D = load(entry.runtime_path).instantiate()
		world.add_child(actor)
		actor.scale = Vector3.ONE * float(placement.scale)
		actor.rotation.y = deg_to_rad(placement.yaw_degrees)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		for action in clips:
			var duration: float = player.get_animation(action).length
			player.play(action)
			player.pause()
			var clearance := INF
			# Independent half-frame sweep, not the samples used by the baker.
			for frame in ceili(duration * 60):
				var time := minf((frame + 0.5) / 60.0, duration)
				actor.position.y = placement.lift + Motion.offset(clips, action, time)
				await _pose(player, skeletons, time)
				clearance = minf(clearance, _minimum(meshes))
			assert(clearance >= .015, str(entry.species) + ": " + action + " floor=" + str(clearance))
			assert(player.get_animation(action).length == duration)
			print("MOTION_CLEARANCE ", entry.species, " ", action, " ", clearance)
		actor.free()
	world.free()
	print("MODEL_MOTION_RENDER_OK")
	quit()
