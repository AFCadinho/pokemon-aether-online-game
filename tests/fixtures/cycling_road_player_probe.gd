extends "res://tests/fixtures/mount_access_player.gd"
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
func _is_mount_owned(mount_id: String) -> bool:
	return owns_mount and mount_id == "cyclizar"
func _play_walk_animation(_direction: Vector2) -> void:
	pass
func set_idle_frame() -> void:
	pass
func _update_sort_z() -> void:
	pass
