extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.add_child(load("res://tests/aether_clash_bot_player_flow_check.tscn").instantiate())
