extends "res://scripts/world/world.gd"

var mount_count := 0
var lock_count := 0
var unlock_count := 0
var reject_mount := false

func _instantiate_battle_ui() -> bool:
	mount_count += 1
	return false if reject_mount else super._instantiate_battle_ui()

# Load after autoload initialization, like the real world scene. Only isolate
# movement/presence here; the production co-op mounting logic is exercised.
func _lock_overworld_for_battle() -> void:
	lock_count += 1


func _unlock_overworld_after_battle() -> void:
	unlock_count += 1


func _publish_world_presence(_force := false) -> void:
	pass
