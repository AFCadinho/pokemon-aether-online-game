extends "res://tests/move_camera_choreography_check.gd"
## Exercise all catalog shot families with Android's independently enabled shots.
func _make_stage() -> Node:
	return load("res://tests/fixtures/android_camera_stage.gd").new()

func _set_motion(enabled: bool) -> void:
	SettingsManager.battle_3d_camera_motion = false
	SettingsManager.android_3d_idle_camera_motion = false
	SettingsManager.android_3d_move_camera = enabled

func _camera_zoom() -> float:
	return 0.60
