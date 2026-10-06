extends "res://tests/battle_dialogue_preview.gd"
func _start() -> void:
	root.get_node("SettingsManager").battle_3d_camera_motion=false
	await super._start()
	root.title="PokeAether — schuine single-battlecamera — alle moves goedgekeurd"
	status.text="Nieuwe schuine beginhoek. Vrij draaien blijft mogelijk; camera resetten herstelt deze hoek. Alle 194 moves zijn goedgekeurd."
	print("SINGLES_CAMERA_PREVIEW_READY")
	if "--smoke-camera" in OS.get_cmdline_user_args():await _capture_camera()
func _capture_camera() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	for index in ARENAS.size():
		arena.select(index)
		await _load_preview()
		var stage=battle.animation_router.model_presenter
		assert(stage.active and not stage.double_mode,stage.reason)
		assert(stage.arena_id==ARENAS[index],"Requested arena must render without fallback: "+stage.arena_problem)
		await process_frame;await process_frame
		var initial: Transform3D=stage.camera.transform
		stage.user_camera_yaw=.5
		await process_frame
		assert(not stage.camera.transform.is_equal_approx(initial))
		stage.reset_user_camera();await process_frame
		assert(stage.camera.transform.is_equal_approx(initial))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(ARENAS[index]+".png"))
	host.release();host.queue_free();host=null
	await process_frame;await process_frame
	print("SINGLES_CAMERA_RENDER_OK arenas=4 reset=true")
	quit.call_deferred()
