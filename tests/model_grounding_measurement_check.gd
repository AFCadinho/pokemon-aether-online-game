extends "res://tools/sprite_factory/measure_model_grounding.gd"
## Analytic animated-box fixture for world-space pose sampling and lift policy.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var folder := "user://grounding-check-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	output_prefix = ProjectSettings.globalize_path(folder.path_join("review"))
	var actor := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3.ONE
	actor.add_child(mesh)
	mesh.owner = actor
	var player := AnimationPlayer.new()
	actor.add_child(player)
	player.owner = actor
	var library := AnimationLibrary.new()
	for action in ["idle", "attack"]:
		var clip := Animation.new()
		clip.length = 0.1
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, NodePath("Mesh:position"))
		clip.track_insert_key(track, 0.0, Vector3(0, 0.4, 0))
		clip.track_insert_key(track, 0.1, Vector3(0, 0.2 if action == "idle" else -0.5, 0))
		library.add_animation(action, clip)
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK)
	var path := ProjectSettings.globalize_path(folder.path_join("fixture.scn"))
	assert(ResourceSaver.save(packed, path) == OK)
	actor.free()
	var world := Node3D.new()
	root.add_child(world)
	review_camera = Camera3D.new()
	world.add_child(review_camera)
	review_camera.current = true
	var entry := {"species": "analytic-box", "runtime_path": path, "placement": {"scale": 2.0, "yaw_degrees": 90.0}, "action_timing": {"idle": {}, "attack": {}}}
	var result := await _measure(entry, world)
	assert(failures.is_empty(), str(failures))
	assert(absf(result.clips.idle.minimum_y - -0.6) < 0.001)
	assert(absf(result.candidate_lift - 0.625) < 0.001)
	assert(result.idle_verified)
	assert(result.clips.attack.clearance_with_idle_lift < -1.0, "Attack must not raise resting lift")
	world.free()
	print("MODEL_GROUNDING_MEASUREMENT_OK")
	quit()
