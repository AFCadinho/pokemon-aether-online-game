extends "res://tests/draco_meteor_camera_check.gd"
## Run real charge/release/recovery checks with Android close-up and static idle.
func _make_stage() -> Node:
	return load("res://tests/fixtures/android_camera_stage.gd").new()

func _set_motion(enabled: bool) -> void:
	SettingsManager.battle_3d_camera_motion = false
	SettingsManager.android_3d_idle_camera_motion = false
	SettingsManager.android_3d_move_camera = enabled

func _camera_zoom() -> float:
	return 0.60

func _camera_yaw() -> float:
	return Stage.ANDROID_CAMERA_YAW_DEFAULT
