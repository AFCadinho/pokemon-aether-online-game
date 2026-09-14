extends "res://scripts/world/world.gd"

# Load after autoload initialization, like the real world scene. Only isolate
# movement/presence here; the production co-op mounting logic is exercised.
func _lock_overworld_for_battle() -> void:
	pass


func _publish_world_presence(_force := false) -> void:
	pass
