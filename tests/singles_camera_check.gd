extends SceneTree
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_3d_camera_motion=false
	var stage := Stage.new()
	root.add_child(stage);stage.set_process(false)
	stage.viewport=SubViewport.new();stage.add_child(stage.viewport)
	stage.world=Node3D.new();stage.viewport.add_child(stage.world)
	stage.camera=Camera3D.new();stage.world.add_child(stage.camera)
	stage.camera.fov=Arenas.CAMERA_FOV
	var samples := 0
	for arena in Arenas.IDS:
		stage.arena_id=arena
		for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2200,900)]:
			stage.viewport.size=dimensions
			stage.size=Vector2(dimensions)
			stage.double_mode=false
			stage.reset_user_camera();stage._update_camera(0)
			var single := stage.camera.transform
			var home := Arenas.camera_home(arena)
			var target := Arenas.camera_target(arena)
			assert(is_equal_approx(single.origin.distance_to(target),home.distance_to(target)))
			assert(is_equal_approx(single.origin.y,home.y))
			# The viewer is now closer to their own side of the combat axis.
			assert(single.origin.x<home.x-3.)
			for index in 2:
				var foot: Vector2=stage.camera.unproject_position(stage._position(index))
				var head: Vector2=stage.camera.unproject_position(stage._position(index)+Vector3.UP*4.)
				assert(Rect2(Vector2(40,40),Vector2(dimensions)-Vector2(80,80)).has_point(foot))
				assert(Rect2(Vector2(160,40),Vector2(dimensions)-Vector2(320,100)).has_point(head),"Room for model and HUD")
			stage.user_camera_yaw=.65;stage.user_camera_pitch=.1;stage.user_camera_zoom=1.2
			stage._update_camera(0)
			assert(not stage.camera.transform.is_equal_approx(single))
			stage.reset_user_camera();stage._update_camera(0)
			assert(stage.camera.transform.is_equal_approx(single))
			stage.double_mode=true;stage._update_camera(0)
			assert(stage.camera.position.is_equal_approx(target+(home-target)*1.45),"Doubles keep their original framing")
			samples+=1
	# Hybrid backgrounds retain their fixed orthographic framing.
	settings.battle_presentation_mode="2.5d"
	stage.double_mode=false;stage._update_camera(0)
	assert(stage.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	assert(stage.camera.position.is_equal_approx(Vector3(0,5.5,16)))
	stage.free();await process_frame
	print("SINGLES_CAMERA_OK samples=",samples," reset=true orbit=true doubles_preserved=true hybrid_preserved=true")
	quit()
