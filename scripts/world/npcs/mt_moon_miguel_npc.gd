@tool
extends TrainerNPC

class_name MtMoonMiguelNPC

const QUEST_ID := "travel_through_mt_moon"
const BATTLE_STEP_ID := "defeat_miguel"
const BLOCKED_DIALOGUE_ID := "kanto_mt_moon_miguel_blocked"

@export var cleared_position := Vector2(656, 656)

var _blocking_position := Vector2.ZERO


func _ready() -> void:
	_blocking_position = position
	super._ready()
	if Engine.is_editor_hint():
		return
	if not StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.connect(_on_story_changed)
	_apply_story_position()


func _exit_tree() -> void:
	if StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.disconnect(_on_story_changed)


func _can_auto_challenge() -> bool:
	return _story_allows_battle() and super._can_auto_challenge()


func interact_with_player(player: Node2D) -> void:
	if trainer_progress_state == STATE_FIRST_ENCOUNTER and not _story_allows_battle():
		await _show_blocked_dialogue()
		return
	await super.interact_with_player(player)


func _story_allows_battle() -> bool:
	return StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "active")


func _show_blocked_dialogue() -> void:
	var result: Dictionary = await NpcDialogueService.resolve_dialogue(
		BLOCKED_DIALOGUE_ID,
		["Leave me alone!"],
		"MtMoonMiguelNPC"
	)
	var lines: Array[String] = _string_array(result.get("lines", []))
	var speaker_name := str(result.get("speakerName", display_name)).strip_edges()
	await show_dialogue(lines, speaker_name)


func _on_story_changed(_revision: int) -> void:
	_apply_story_position()


func _apply_story_position() -> void:
	if StoryService.is_requirement_met(QUEST_ID, BATTLE_STEP_ID, "completed"):
		position = cleared_position
	else:
		position = _blocking_position
