extends "res://tests/battle_move_effects_3d_check.gd"

const MOVES := ["Moonblast", "Hyper Beam", "Solar Beam", "Focus Blast", "Shadow Ball", "Flash Cannon", "Electro Shot", "Pyro Ball", "Blizzard", "Hurricane", "Tera Starstorm"]

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.battle_3d_camera_motion = true
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.camera.fov = 48.0
	stage.user_camera_yaw = 0.4
	stage.user_camera_pitch = 0.12
	stage.user_camera_zoom = 0.85
	for doubles in [false, true]:
		stage.double_mode = doubles
		stage._update_camera(0.0)
		var overview: Transform3D = stage.camera.transform
		for move in MOVES:
			for slot in (4 if doubles else 2):
				var actor := "p%d" % (slot + 1)
				var target := "p%d" % ((slot + 1) % (4 if doubles else 2) + 1)
				for result in ["", "miss", "immune"]:
					stage.start_move_action(actor, move)
					var timing: Dictionary = stage.move_timing(move, actor)
					var effect: Node = stage.create_move_effect(move, actor, target, {"result":result, "show_impact":true})
					effect.set_process(false)
					stage.players[slot].speed_scale = 0.0
					assert(stage.move_camera.effect == effect)
					assert((stage.move_atmosphere.effect == effect) == stage.move_atmosphere.supports(effect.key))
					assert(is_equal_approx(effect.duration, float(timing.frames) / 60.0), "Camera never extends animation duration")
					_sample(slot, effect, effect.launch * 0.6)
					var charge: Transform3D = stage.camera.transform
					assert(not charge.is_equal_approx(overview), move)
					stage._update_camera(2.0)
					assert(stage.camera.transform.is_equal_approx(charge), "Native pause holds " + move)
					var anchors: Dictionary = effect.anchors.call()
					_in_frame(anchors.source, move + " charge emitter")
					if move == "Moonblast":
						_in_frame(anchors.moon_source + Vector3.UP * (1.35 + 0.3 * (effect.presentation_scale - 1.0)), "Moon above caster")
					_sample(slot, effect, lerpf(effect.launch, effect.impact, 0.6))
					_in_frame(anchors.target, move + " target")
					if move in ["Hyper Beam", "Solar Beam", "Flash Cannon", "Electro Shot"]:
						for source: Vector3 in anchors.sources: _in_frame(source, move + " beam emitter")
					if move == "Pyro Ball":
						_in_frame(effect.origin.lerp(effect.aim, 0.5) + Vector3.UP * effect.projectile_arc_height, "Pyro Ball arc")
					if move in ["Blizzard", "Hurricane", "Tera Starstorm"]:
						for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
							_in_frame(effect.field_center + direction * effect.field_radius + Vector3.UP * 3.0, move + " field edge")
						if move == "Tera Starstorm": _in_frame(effect.field_center + Vector3.UP * 5.5, "Starstorm crown")
					else:
						assert(not stage.camera.transform.is_equal_approx(charge), move + " cuts after charge")
					_sample(slot, effect, lerpf(effect.impact, effect.duration, 0.2))
					_in_frame(anchors.target, move + " impact")
					SettingsManager.battle_3d_camera_motion = false
					stage._update_camera(0.0)
					assert(stage.camera.transform.is_equal_approx(overview), "Disabled camera motion")
					SettingsManager.battle_3d_camera_motion = true
					_sample(slot, effect, effect.duration * 0.9999)
					assert(stage.camera.position.distance_to(overview.origin) < 0.01, "Smooth recovery")
					effect.cancel()
					assert(stage.move_camera.effect == null and stage.camera.transform.is_equal_approx(overview), "Cancel restores manual orbit")
					await get_tree().process_frame
	# All profiles survive the router's ordered impact/recovery split.
	stage.playback_speed = 4.0
	for move in MOVES:
		await router.play_move_animation(move, "p1", "p2", {"stop_at_impact":true, "show_impact":true})
		assert(stage.move_camera.effect != null, move + " holds through damage beat")
		await router.finish_3d_impact_damage("p2")
		assert(stage.move_camera.effect == null, move + " natural recovery")
		await get_tree().process_frame
	# Orthographic mode, substitute removal, overlapping cleanup and route cancellation.
	stage.start_move_action("p1", "Moonblast")
	var old: Node = stage.create_move_effect("Moonblast", "p1", "p2", {})
	stage.start_move_action("p2", "Hyper Beam")
	var current: Node = stage.create_move_effect("Hyper Beam", "p2", "p1", {})
	old.cancel()
	assert(stage.move_camera.effect == current, "An older effect cannot clear a newer shot")
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._update_camera(0.0)
	assert(stage.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	router.cancel_render()
	assert(current.cancelled and stage.move_camera.effect == null)
	SettingsManager.battle_presentation_mode = "3d"
	var doll := Doll.new()
	stage.world.add_child(doll)
	doll.position = Vector3(4, 0, 2)
	stage.substitute_models[1] = doll
	stage.actors[1].hide()
	stage.start_move_action("p1", "Focus Blast")
	current = stage.create_move_effect("Focus Blast", "p1", "p2", {})
	_sample(0, current, current.impact)
	_in_frame(doll.position + Vector3.UP * 0.5, "Substitute")
	doll.hide()
	current._process(0.0)
	assert(current.cancelled and stage.move_camera.effect == null)
	stage.substitute_models[1] = null
	doll.queue_free()
	stage.actors[1].show()
	_check_portrait_framing()
	for move in ["Tackle", "Quick Attack", "Ice Shard"]:
		stage.start_move_action("p1", move)
		current = stage.create_move_effect(move, "p1", "p2", {})
		assert(stage.move_camera.effect == null, "Short attacks retain their camera")
		current.cancel()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_CAMERA_CHOREOGRAPHY_OK moves=11 singles=true doubles=true outcomes=3 framing=true portrait=true pause=true recovery=true cancellation=true ownership=true substitute=true settings=true hybrid=true short_moves_unchanged=true")
	get_tree().quit()

func _sample(slot: int, effect: Node, seconds: float) -> void:
	stage.players[slot].seek(seconds, true)
	stage._update_camera(0.0)
	effect._process(0.0)
	stage._update_camera(0.0)

func _in_frame(point: Vector3, label: String) -> void:
	var rect := Rect2(Vector2.ZERO, stage.camera.get_viewport().get_visible_rect().size)
	assert(not stage.camera.is_position_behind(point) and rect.has_point(stage.camera.unproject_position(point)), label)

func _check_portrait_framing() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 780)
	add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var points: Array[Vector3] = [Vector3(-7, 0, -5), Vector3(7, 6, 5), Vector3(7, 0, -5), Vector3(-7, 6, 5)]
	for keep in [Camera3D.KEEP_WIDTH, Camera3D.KEEP_HEIGHT]:
		camera.keep_aspect = keep
		camera.transform = stage.move_camera._fit(camera, points, Vector3(1, 0.5, 1).normalized())
		for point in points:
			assert(Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(camera.unproject_position(point)), "Portrait field framing")
	viewport.queue_free()
