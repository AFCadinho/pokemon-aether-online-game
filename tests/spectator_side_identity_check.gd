extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("Spectator side identity runtime check timed out")
		quit(1)
	)
	if change_scene_to_file("res://tests/spectator_side_identity_runtime_check.tscn") != OK:
		quit(1)
