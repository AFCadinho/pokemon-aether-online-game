extends "res://scripts/world/player.gd"

# Keep real collision and water rules without network/appearance startup.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
