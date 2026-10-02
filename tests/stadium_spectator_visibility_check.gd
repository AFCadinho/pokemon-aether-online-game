extends SceneTree
const Spectator = preload("res://scripts/battle/arenas/shared/animated_spectator.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(640,480)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position=Vector3(0,1.3,6)
	camera.look_at(Vector3(0,1.3,0))
	var actor := Spectator.new()
	actor.configure(Spectator.MODELS[0],1.3,0.7)
	actor.throttle_outside_camera(0.7)
	view.add_child(actor)
	for frame in 15:
		await process_frame
	assert(actor.on_screen and actor.animation_player.active)
	var position_before: float = actor.animation_player.current_animation_position
	for frame in 6:
		await process_frame
	assert(not is_equal_approx(actor.animation_player.current_animation_position, position_before))
	camera.rotation.y=PI
	for frame in 15:
		await process_frame
	assert(not actor.on_screen and not actor.animation_player.active)
	var elapsed:float=actor.elapsed
	for frame in 15:
		await process_frame
	assert(actor.elapsed>elapsed and not actor.animation_player.active)
	camera.rotation.y=0
	for frame in 15:
		await process_frame
	assert(actor.on_screen and actor.animation_player.active)
	assert(actor.animation_player.current_animation==("Wave" if fmod(actor.elapsed,7.0)<3.2 else "Idle_Neutral"))
	view.queue_free()
	await process_frame
	print("STADIUM_SPECTATOR_VISIBILITY_OK visible_animated=true offscreen_paused=true timeline_continues=true return_resumes=true")
	quit()
