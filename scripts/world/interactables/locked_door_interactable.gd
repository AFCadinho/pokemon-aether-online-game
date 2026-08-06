extends WorldInteractable

class_name LockedDoorInteractable

@export var required_badge_region := "kanto"
@export var required_badge_count := 7
@export var required_story_quest_id := ""
@export var required_story_step_id := ""
@export var required_story_status := "completed"
@export var locked_dialogue_lines: Array[String] = [
	"The Viridian Gym is closed right now.",
	"The Gym Leader has not returned yet.",
]
@export var unlocked_dialogue_lines: Array[String] = [
	"The Viridian Gym is open.",
]

var is_unlocked := false


func _ready() -> void:
	interactable_kind = "locked_door"
	requires_facing = false
	_ensure_interaction_area()
	_refresh_lock_state()
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save != null and player_save.has_signal("gym_badges_changed"):
		player_save.gym_badges_changed.connect(_refresh_lock_state)
	var story_service := get_node_or_null("/root/StoryService")
	if story_service != null and story_service.has_signal("story_changed"):
		story_service.story_changed.connect(_on_story_changed)


func _on_story_changed(_revision: int) -> void:
	_refresh_lock_state()


func _process(_delta: float) -> void:
	_refresh_lock_state()
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)


func interact_with_player(_player: Node2D) -> void:
	if is_unlocked:
		await show_dialogue(unlocked_dialogue_lines, display_name)
	else:
		await show_dialogue(locked_dialogue_lines, display_name)


func _refresh_lock_state() -> void:
	var unlocked_by_badges := required_badge_count <= 0
	if not unlocked_by_badges:
		var player_save := get_node_or_null("/root/PlayerSave")
		unlocked_by_badges = player_save != null and _get_region_badge_count(player_save) >= required_badge_count

	var unlocked_by_story := true
	if not required_story_quest_id.strip_edges().is_empty():
		var story_service := get_node_or_null("/root/StoryService")
		unlocked_by_story = story_service != null and story_service.is_requirement_met(
			required_story_quest_id,
			required_story_step_id,
			required_story_status
		)

	is_unlocked = unlocked_by_badges and unlocked_by_story
	blocks_movement = not is_unlocked


func _get_region_badge_count(player_save: Node) -> int:
	var badges: Variant = player_save.get("earned_gym_badges")
	if not badges is Array:
		return 0
	var prefix := required_badge_region.strip_edges().to_lower() + ":"
	var count := 0
	for badge_value: Variant in badges as Array:
		if str(badge_value).strip_edges().to_lower().begins_with(prefix):
			count += 1
	return count
