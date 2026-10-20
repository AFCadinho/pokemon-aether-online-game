extends "res://scripts/world/player.gd"

# Keep real collision and water rules without network/appearance startup.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)

# Area2D entry uses the player's detection shape, not just its grid center.
func overlaps_exit_at(exit_node: Area2D, world_position: Vector2) -> bool:
	var detection: CollisionShape2D = get_node("DetectionShape")
	var body_transform := Transform2D(0.0, world_position) * detection.transform
	for child in exit_node.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape != null:
			if detection.shape.collide(body_transform, child.shape, child.global_transform):
				return true
	return false
