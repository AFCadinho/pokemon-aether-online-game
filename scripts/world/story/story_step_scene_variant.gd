extends Node

class_name StoryStepSceneVariant

const MATCHING_STEP_STATUSES: Array[String] = ["completed", "skipped"]

@export var quest_id := ""
@export var step_id := ""
@export var target_path: NodePath
@export var position_marker_path: NodePath
@export var facing_marker_path: NodePath
@export var disable_area_path: NodePath
@export var override_sprite_offset := false
@export var sprite_offset_override := Vector2(0, -16)


func _ready() -> void:
	_apply_story_state.call_deferred()


func _apply_story_state() -> void:
	if not _matches_story_state():
		return

	var target := get_node_or_null(target_path) as Node2D
	var position_marker := get_node_or_null(position_marker_path) as Marker2D
	var facing_marker := get_node_or_null(facing_marker_path) as Marker2D
	if target == null or position_marker == null or facing_marker == null:
		push_warning("Story scene variant cannot resolve its target or placement markers.")
		return

	target.global_position = position_marker.global_position
	if override_sprite_offset and target.has_method("set_story_sprite_offset"):
		target.call("set_story_sprite_offset", sprite_offset_override)
	if target.has_method("_sync_nameplate"):
		target.call("_sync_nameplate")
	if target.has_method("face_world_position"):
		target.call("face_world_position", facing_marker.global_position)
	if target.has_method("_update_sort_z"):
		target.call("_update_sort_z")

	var disabled_area := get_node_or_null(disable_area_path) as Area2D
	if disabled_area != null:
		disabled_area.monitoring = false
		disabled_area.monitorable = false


func _matches_story_state() -> bool:
	var normalized_quest_id := quest_id.strip_edges()
	var normalized_step_id := step_id.strip_edges()
	if normalized_quest_id.is_empty() or normalized_step_id.is_empty():
		return false
	var story_service := get_node_or_null("/root/StoryService")
	if story_service == null or not story_service.has_method("get_quest"):
		return false
	var quest: Dictionary = story_service.call("get_quest", normalized_quest_id) as Dictionary
	var steps_value: Variant = quest.get("steps", [])
	if not (steps_value is Array):
		return false
	for step_value: Variant in steps_value as Array:
		if not (step_value is Dictionary):
			continue
		var step := step_value as Dictionary
		if (
			str(step.get("stepId", "")) == normalized_step_id
			and str(step.get("status", "")) in MATCHING_STEP_STATUSES
		):
			return true
	return false
