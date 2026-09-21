extends SceneTree
## Deterministic fixed-camera source for the lightweight 2D stadium loop.

const FRAME_SIZE := Vector2i(1152, 648)
const ArenaCatalog := preload("res://scripts/battle/arenas/arena_catalog.gd")
const MaterialResponse := preload("res://scripts/battle/battle_ui/material_response.gd")


func _initialize() -> void:
	root.size = FRAME_SIZE
	var world := Node3D.new()
	root.add_child(world)

	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("060510")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(environment)
	MaterialResponse.apply_neutral_lighting(world)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = ArenaCatalog.CAMERA_FOV
	camera.look_at_from_position(
		ArenaCatalog.camera_home("stadium"),
		ArenaCatalog.camera_target("stadium")
	)

	var arena := ArenaCatalog.build("stadium", world, camera)
	if arena == null:
		push_error("Could not build stadium arena")
		quit(1)
		return
	world.add_child(arena)
