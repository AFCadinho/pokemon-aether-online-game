extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("Spectator party isolation runtime check timed out")
		quit(1)
	)
	var error := change_scene_to_file("res://tests/spectator_party_isolation_runtime_check.tscn")
	if error != OK:
		quit(1)
