extends SceneTree


const CameraInput = preload("res://scripts/battle/battle_ui/immersive_camera_input.gd")
const PLATFORM = preload("res://assets/background/platform/grass_platform_v3.png")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2.5d"
	settings.battle_3d_camera_motion = true
	var parent := Control.new()
	root.add_child(parent)
	var platforms: Array = []
	for index in 2:
		var platform := Control.new()
		parent.add_child(platform)
		var image := TextureRect.new()
		image.name = "PlatformImage"
		image.texture = PLATFORM
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.size = Vector2(500, 300)
		platform.add_child(image)
		platforms.append(platform)
	var stage = load("res://scripts/battle/battle_ui/experimental_battle_3d.gd").new()
	parent.add_child(stage)
	stage.setup([], platforms)
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.set_process(false)
	parent.size = Vector2(1280, 720)
	stage.size = parent.size
	stage._build_world()
	var input := CameraInput.new()
	root.add_child(input)
	stage.active = true
	assert(not input._may_rotate(stage), "Hybrid terrain must not accept an orbit that separates models from their platforms")
	for dimensions: Vector2 in [Vector2(1280,720), Vector2(1920,1080), Vector2(2200,900), Vector2(768,1024)]:
		parent.size = dimensions
		parent.position = Vector2(33, 27)
		parent.scale = Vector2(0.8, 0.7)
		stage.size = dimensions
		for index in 2:
			platforms[index].position = dimensions * (Vector2(0.38,0.59) if index == 0 else Vector2(0.65,0.46)) - Vector2(250,150) * 0.82
			platforms[index].scale = Vector2.ONE * 0.82
		stage._sync_render_size()
		stage.user_camera_yaw = 0.7
		stage.user_camera_pitch = 0.4
		stage.user_camera_zoom = 1.7
		stage._update_camera(0.5)
		var fixed_camera: Transform3D = stage.camera.transform
		for frame in 4:
			stage._update_camera(0.5)
			assert(stage.camera.transform.is_equal_approx(fixed_camera), "Idle camera movement must not shift a hybrid Pokémon")
		assert(stage.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
		for index in 2:
			var image: TextureRect = platforms[index].get_node("PlatformImage")
			var projected: Vector2 = stage._project_to_ui(stage._position(index))
			var local: Vector2 = image.get_global_transform().affine_inverse() * projected
			# The visible grass ellipse is centered around source pixel (768,666).
			# Recover source pixels from the covered TextureRect, independently of
			# the model anchor, to catch the original enemy landing below the art.
			var texture_size := PLATFORM.get_size()
			var ratio := image.size / texture_size
			var scale_factor := maxf(ratio.x, ratio.y)
			var source := (local - (image.size - texture_size * scale_factor) * 0.5) / scale_factor
			assert(source.distance_to(Vector2(768,666)) < 2.0, "Both model floors must land in the platform center after resize/scaling")
		stage.double_mode = true
		for side in 2:
			var image: TextureRect = platforms[side].get_node("PlatformImage")
			var first: Vector2 = image.get_global_transform().affine_inverse() * stage._project_to_ui(stage._position(side))
			var second: Vector2 = image.get_global_transform().affine_inverse() * stage._project_to_ui(stage._position(side + 2))
			assert(absf(first.y - second.y) < 0.01 and second.x - first.x > 100.0, "Double slots retain separate landing positions on the same platform")
		stage.double_mode = false
	# Small pairs get a clear increase without changing authored model scale.
	parent.scale = Vector2.ONE
	parent.position = Vector2.ZERO
	parent.size = Vector2(1280,720)
	stage.size = parent.size
	stage._sync_render_size()
	stage.combatants[0] = {"species":"azumarill", "shiny":false}
	stage.combatants[1] = {"species":"rattata", "shiny":false}
	for identity in ["azumarill","rattata"]:
		stage.placements[identity] = {"scale":1.0,"yaw_degrees":0.0}
		stage.visual_bounds[identity] = {"idle":{"min":[-0.4,0,-0.4],"size":[0.8,1.0,0.8]}}
	stage._update_camera(0)
	assert(is_equal_approx(stage.camera.size,6.5))
	var floor: Vector2 = stage._project_to_ui(stage._position(0))
	var large_span: float = floor.distance_to(stage._project_to_ui(stage._position(0)+Vector3.UP))
	stage.camera.size=10.0
	var old_span: float = stage._project_to_ui(stage._position(0)).distance_to(stage._project_to_ui(stage._position(0)+Vector3.UP))
	assert(large_span/old_span>1.5, "Small Pokémon become at least 50% clearer at the same anchor")
	# Very large envelopes widen the common frame; both sides retain one scale.
	stage.visual_bounds.rattata.idle = {"min":[-4,0,-4],"size":[8,7,8]}
	stage._update_camera(0)
	assert(stage.camera.size>6.5)
	assert(is_equal_approx(stage._hybrid_size_limit(),1.0), "The large silhouette fits within its screen budget")
	var fitted: float = stage.camera.size
	stage.current_actions[1]="physical_attack"
	stage._update_camera(0)
	assert(is_equal_approx(stage.camera.size,fitted), "Attacks must not pump the framing")
	assert(stage.placements.azumarill.scale==1.0 and stage.placements.rattata.scale==1.0)
	stage.current_actions[1]="idle"
	# Full 3D retains perspective, its existing world spawns and camera input.
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	stage.reset_user_camera()
	stage._update_camera(0.0)
	assert(stage.camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(stage._position(0).is_equal_approx(Vector3(-2.8,0,1.5)))
	assert(stage._position(1).is_equal_approx(Vector3(2.8,0,-1.5)))
	assert(input._may_rotate(stage))
	input.free()
	parent.free()
	await process_frame
	print("HYBRID_PLATFORM_FRAMING_OK resized=true scaled=true double_slots=true fixed_camera=true full_3d_preserved=true")
	quit()
