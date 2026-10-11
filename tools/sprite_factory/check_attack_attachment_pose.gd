extends SceneTree
## Focused regression: discrete visibility must agree in both views of a pose.
const Pose = preload("res://tools/sprite_factory/attack_attachment_pose.gd")
const SurfaceProjection = preload("res://tools/sprite_factory/project_attack_attachment_landmarks.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var closed := Node3D.new()
	closed.name = "Closed"
	actor.add_child(closed)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var animation := Animation.new()
	animation.length = 2.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Closed:visible"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(track, 0.0, true)
	animation.track_insert_key(track, 0.55, false)
	animation.track_insert_key(track, 1.62, true)
	var library := AnimationLibrary.new()
	library.add_animation("attack", animation)
	player.add_animation_library("", library)
	for fraction in [.2, .45, .65, .45, .2, .45]:
		Pose.sample(player, "attack", animation.length * fraction)
		assert(closed.visible == (fraction == .2), "Discrete visibility must match forward playback")
		assert(is_equal_approx(player.current_animation_position, animation.length * fraction))
	actor.free()
	var origin := Vector3(.25, .25, 1)
	var a := Vector3.ZERO
	var b := Vector3.RIGHT
	var c := Vector3.UP
	var hit := SurfaceProjection._intersection(origin, Vector3.FORWARD, a, b, c)
	assert(hit.size() == 4 and is_equal_approx(hit[0], 1.0))
	assert(is_equal_approx(hit[1], .5) and is_equal_approx(hit[2], .25) and is_equal_approx(hit[3], .25))
	var reverse := SurfaceProjection._intersection(origin, Vector3.FORWARD, c, b, a)
	assert(reverse.size() == 4 and is_equal_approx(reverse[0], 1.0))
	assert(SurfaceProjection._intersection(Vector3(2, 2, 1), Vector3.FORWARD, a, b, c).is_empty())
	assert(SurfaceProjection._intersection(origin, Vector3.BACK, a, b, c).is_empty())
	assert(SurfaceProjection._intersection(origin, Vector3.RIGHT, a, b, c).is_empty())
	print("ATTACHMENT_POSE_CHECK_OK forward_visibility=true repeated_pose=true surface_projection=true")
	quit()
