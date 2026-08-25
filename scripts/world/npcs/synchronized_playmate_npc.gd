@tool
extends DialogueNPC

class_name SynchronizedPlaymateNPC

## Keeps this NPC in a fixed formation with a moving NPC or overworld Pokemon.
## The leader remains responsible for pathfinding and collision decisions.
@export var movement_target_path: NodePath
@export var movement_offset := Vector2.ZERO

var movement_target: BaseNPC


func _ready() -> void:
	_ready_base_npc()
	if Engine.is_editor_hint():
		return
	_resolve_movement_target()
	_sync_to_movement_target()


func _after_base_npc_process() -> void:
	# Formation updates share BaseNPC's serialized lifecycle, so closing the
	# dialogue cannot race a second process callback into reopening it.
	if not is_interacting:
		_sync_to_movement_target()


func _resolve_movement_target() -> void:
	movement_target = get_node_or_null(movement_target_path) as BaseNPC
	if movement_target != null:
		# The follower updates after its leader, minimizing visible frame lag.
		process_priority = movement_target.process_priority + 1


func _sync_to_movement_target() -> void:
	if movement_target == null or not is_instance_valid(movement_target):
		_resolve_movement_target()
	if movement_target == null:
		return

	global_position = movement_target.global_position + movement_offset
	if is_interacting:
		return

	facing_direction = movement_target.facing_direction
	if movement_target.is_npc_moving:
		_play_walk_animation(facing_direction)
	else:
		_set_idle_frame(facing_direction)
