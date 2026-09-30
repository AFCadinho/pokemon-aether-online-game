extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := Node3D.new()
	actor.name = "NativeModel"
	actor.set_meta("pokeaether_eye_motion", 1)
	var marker := Node3D.new()
	marker.name = "NativePart"
	actor.add_child(marker)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	player.add_animation_library("", library)
	for action in ["idle", "faint_start"]:
		var animation := Animation.new()
		animation.length = 1.0
		var index := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(index, NodePath("NativePart"))
		animation.track_insert_key(index, 0.0, Vector3(3, 0, 0))
		animation.track_insert_key(index, 1.0, Vector3(3, 0, 0))
		library.add_animation(action, animation)
	var manifest := {"schema": 1, "glb_sha256": "source", "review_required": true, "clips": {
		"idle": {"duration": 1.0, "loop": false, "keys": [[0.0, 0.0], [1.0, 0.0]]},
		"faint_start": {"duration": 1.0, "loop": false, "keys": [[0.0, 0.0], [1.0, -2.0]]}}}
	var bad := manifest.duplicate(true)
	bad.clips.idle.duration = 2.0
	var rejected := preload("res://tools/sprite_factory/visual_ground_motion_pack.gd").new()
	assert(rejected.apply(actor, bad, "source") == null)
	assert(actor.get_parent() == null and player.get_animation("idle").get_track_count() == 1)
	var helper := preload("res://tools/sprite_factory/visual_ground_motion_pack.gd").new()
	var wrapped := helper.apply(actor, manifest, "source")
	assert(wrapped != null and wrapped.get_meta("pokeaether_eye_motion") == 1)
	root.add_child(wrapped)
	wrapped.position = Vector3(0, 8, 0)
	player.play("faint_start")
	player.seek(1.0, true)
	assert(wrapped.position == Vector3(0, 8, 0))
	assert(actor.get_parent().position.is_equal_approx(Vector3(0, -2, 0)))
	assert(marker.position.is_equal_approx(Vector3(3, 0, 0)))
	assert(player.get_animation("faint_start").track_get_key_value(0, 1) == Vector3(3, 0, 0))
	player.play("idle")
	player.seek(0.5, true)
	assert(actor.get_parent().position.is_equal_approx(Vector3.ZERO))
	wrapped.free()
	print("PASS: visual offsets preserve gameplay root/native keys, restore idle and reject bad clocks")
	quit()
