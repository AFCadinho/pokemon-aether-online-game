extends "res://tests/battle_move_effects_3d_check.gd"
## Replay the complete move fixture through the Android fallback, offline.
func _init() -> void:
	ProjectSettings.set_setting("_custom_features", "android,android_3d_experimental")

func _setup() -> void:
	super._setup()
	stage.visual_bounds.clear()
	for actor: Node3D in stage.actors:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(1, 2, 1)
		mesh.mesh = shape
		mesh.position.y = 1
		mesh.skin = Skin.new()
		actor.add_child(mesh)
	var fixture_camera := Camera3D.new()
	stage.world.add_child(fixture_camera)
	fixture_camera.position = Vector3(5, 6, 14)
	fixture_camera.look_at(Vector3(4, 1, 1))
	fixture_camera.current = true
	# Keep the fixture offline even if a previous slot test selected 3D.
	get_node("/root/SettingsManager").battle_presentation_mode = "2d"
