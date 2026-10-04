extends "res://tools/sprite_factory/measure_model_grounding.gd"
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Motion = preload("res://scripts/battle/battle_ui/model_motion_placement.gd")
var output := ""
func _run():
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2, "LOCAL_CATALOG OUTPUT_DIRECTORY")
	output = args[1].trim_suffix("/") + "/"
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_3d_arena="classic"
	settings.battle_3d_camera_motion=false
	settings.battle_3d_catalog_path=ProjectSettings.globalize_path(args[0])
	settings._manual_model_catalog_this_session=true
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	stage.set_combatant(0,"Gliscor",false)
	stage.set_combatant(1,"Gliscor",true)
	for frame in 1200:
		await process_frame
		if stage.active and stage._actors_resolved(): break
	assert(stage.active and stage._actors_resolved(),stage.reason)
	stage.set_process(false)
	stage.mode_label.hide()
	for i in 2:
		assert(is_equal_approx(stage.players[i].get_animation("idle").length,140.0/60.0))
		assert(stage.placements[stage.identities[i]].hover_height==0)
	for camera_index in 2:
		stage.user_camera_yaw=0 if camera_index==0 else PI
		stage._update_camera(0)
		for action in ["idle","physical_attack","special_attack","damage","sleep","faint_start","faint_loop"]:
			for i in 2:
				stage.resting[i]=true
				stage.players[i].stop()
				stage.players[i].playback_default_blend_time=0
				for sk: Skeleton3D in stage.actors[i].find_children("*","Skeleton3D",true,false): sk.reset_bone_poses()
				stage._action(action,i)
				stage.players[i].pause()
				var duration: float=stage.players[i].get_animation(action).length
				var t: float=duration*(.95 if action=="faint_start" else .4)
				stage.players[i].seek(t,true)
				for sk: Skeleton3D in stage.actors[i].find_children("*","Skeleton3D",true,false): sk.force_update_all_bone_transforms()
				stage.actors[i].position.y=stage._position(i).y+stage.placements[stage.identities[i]].lift+Motion.offset(stage.motion_clips[stage.identities[i]],action,t)
			await process_frame
			RenderingServer.force_draw(false)
			for i in 2:
				assert(_minimum(stage.actors[i].find_children("*","MeshInstance3D",true,false))>=.015,action)
			root.get_texture().get_image().save_png(output+"battle-"+action+"-"+str(camera_index)+".png")
	# Deterministic live blending at 120 Hz through the real presenter.
	var lowest:=INF
	for speed in [1.0,4.0]:
		stage.playback_speed=speed
		for i in 2:
			stage.players[i].callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			stage.set_combatant(i,"Gliscor",i==1,true)
		for action in ["idle","physical_attack","idle","special_attack","idle","damage","idle","sleep","idle","faint_start","faint_loop"]:
			for i in 2: stage._action(action,i)
			var duration: float=stage.players[0].get_animation(action).length
			for frame in ceili((duration+.3)*120/speed):
				for i in 2: stage.players[i].advance(1.0/120.0)
				stage._process(1.0/120.0)
				for i in 2:
					for sk: Skeleton3D in stage.actors[i].find_children("*","Skeleton3D",true,false): sk.force_update_all_bone_transforms()
				await process_frame
				RenderingServer.force_draw(false)
				for i in 2:
					var floor_y:=_minimum(stage.actors[i].find_children("*","MeshInstance3D",true,false))
					lowest=minf(lowest,floor_y)
					if floor_y<.005:
						printerr("FLOOR ",action," ",i," ",floor_y," frame=",frame," speed=",speed)
						quit(1)
						return
			print("TRANSITION_OK ",action," speed=",speed)
	print("GLISCOR_FLIGHT_BATTLE_OK variants=2 cameras=2 actions=7 speeds=1,4 minimum=",lowest)
	stage.free()
	quit()
