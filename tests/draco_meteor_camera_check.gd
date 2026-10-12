extends "res://tests/battle_move_effects_3d_check.gd"

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.camera.fov = 48.0
	stage.user_camera_yaw = 0.4
	stage.user_camera_zoom = 0.85
	stage._update_camera(0.0)
	var overview: Transform3D = stage.camera.transform
	for slot in 4:
		var actor := "p%d" % (slot + 1)
		var target := "p%d" % ((slot + 1) % 4 + 1)
		for result in ["", "miss", "immune"]:
			stage.start_move_action(actor, "Draco Meteor")
			var effect: Node = stage.create_move_effect("Draco Meteor", actor, target, {"result":result,"show_impact":true})
			effect.set_process(false)
			stage.players[slot].speed_scale = 0.0
			_sample(slot, effect, 0.12)
			var charge: Transform3D = stage.camera.transform
			var forward: Vector3 = stage._move_bounds(target).position - stage._move_bounds(actor).position
			forward.y = 0.0
			assert((charge.origin - stage._move_bounds(actor).position).dot(forward) > 0.0, "Charge shot sees the caster from the front")
			assert(not charge.is_equal_approx(overview))
			stage._update_camera(2.0)
			assert(stage.camera.transform.is_equal_approx(charge), "Paused native clock holds the shot")
			_sample(slot, effect, 0.6)
			assert(not stage.camera.transform.is_equal_approx(charge), "Meteor rain cuts to the target")
			var points: Dictionary = effect.anchors.call()
			var sky: Vector3 = points.source.lerp(points.target, 0.55) + Vector3.UP * 4.3
			var rect := Rect2(Vector2.ZERO, stage.camera.get_viewport().get_visible_rect().size)
			for point in [sky, points.target, points.target_ground]:
				assert(not stage.camera.is_position_behind(point) and rect.has_point(stage.camera.unproject_position(point)), "Rain shot includes sky and target")
			_sample(slot, effect, 0.9999)
			assert(stage.camera.position.distance_to(overview.origin) < 0.01, "Recovery returns to the player's view")
			_sample(slot, effect, 0.6)
			effect.cancel()
			assert(stage.camera.transform.is_equal_approx(overview), "Cancellation immediately restores the camera, including during pause")
			assert(stage.move_camera.effect == null)
			await get_tree().process_frame
	# Disabled motion and flat 2.5D never take cinematic shots.
	SettingsManager.battle_3d_camera_motion = false
	stage._update_camera(0.0)
	var static_view: Transform3D = stage.camera.transform
	stage.start_move_action("p1", "Draco Meteor")
	var effect: Node = stage.create_move_effect("Draco Meteor", "p1", "p2", {})
	effect.set_process(false)
	_sample(0, effect, 0.6)
	assert(stage.camera.transform.is_equal_approx(static_view))
	SettingsManager.battle_presentation_mode = "2.5d"
	SettingsManager.battle_3d_camera_motion = true
	stage._update_camera(0.0)
	assert(stage.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	effect.cancel()
	SettingsManager.battle_presentation_mode = "3d"
	stage.start_move_action("p1", "Draco Meteor")
	effect = stage.create_move_effect("Draco Meteor", "p1", "p2", {})
	effect.set_process(false)
	_sample(0, effect, 0.6)
	stage.actor_shown[1] = false
	effect._process(0.0)
	assert(effect.cancelled and stage.move_camera.effect == null, "Lost targets release the shot")
	stage.actor_shown[1] = true
	stage.playback_speed = 2.0
	await router.play_move_animation("Draco Meteor", "p1", "p2", {"stop_at_impact":true,"show_impact":true})
	assert(router.has_3d_impact_damage("p2") and stage.move_camera.effect != null, "The target shot survives the ordered damage beat")
	await router.finish_3d_impact_damage("p2")
	assert(stage.move_camera.effect == null, "Natural recovery releases the shot at faster playback")
	await get_tree().process_frame
	stage._update_camera(0.0)
	var restored: Transform3D = stage.camera.transform
	stage.start_move_action("p1", "Draco Meteor")
	effect = stage.create_move_effect("Draco Meteor", "p1", "p2", {})
	_sample(0, effect, 0.6)
	router.cancel_render()
	assert(effect.cancelled and stage.move_camera.effect == null and stage.camera.transform.is_equal_approx(restored))
	stage.start_move_action("p1", "Draco Meteor")
	effect = stage.create_move_effect("Draco Meteor", "p1", "p2", {})
	stage._set_active(false)
	assert(effect.cancelled and stage.move_camera.effect == null, "Deactivation releases the shot")
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("DRACO_METEOR_CAMERA_OK slots=4 outcomes=3 native_pause=true framing=true recovery=true cancellation=true motion_setting=true hybrid=true lifecycle=true")
	get_tree().quit()

func _sample(slot: int, effect: Node, phase: float) -> void:
	stage.players[slot].seek(effect.duration * phase, true)
	stage._update_camera(0.0)
