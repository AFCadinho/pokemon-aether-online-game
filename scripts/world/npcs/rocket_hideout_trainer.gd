@tool
extends TrainerNPC

const QUEST := "confront_team_rocket_boss"
const GIOVANNI := "kanto_rocket_hideout_giovanni"
@export var dropped_item_path: NodePath
var _plan_presentation := false
var _presentation_generation := 0
var _departure: Tween

func supports_trainer_rematches() -> bool:
	return false

func _refresh_rematch_marker() -> void:
	super._refresh_rematch_marker()
	if trainer_id == GIOVANNI and rematch_marker != null:
		rematch_marker.visible = false

func prepare_story_sequence() -> Dictionary:
	abort_story_sequence()
	_plan_presentation = trainer_id == GIOVANNI and StoryService.is_requirement_met(QUEST, "learn_plan", "active")
	return {"success": true}

func abort_story_sequence() -> void:
	_presentation_generation += 1
	_plan_presentation = false
	if _departure != null and _departure.is_valid():
		_departure.kill()
	_departure = null
	modulate = Color.WHITE
	if is_inside_tree() and sprite != null:
		_apply_story_visibility()
	var item := get_node_or_null(dropped_item_path) if not dropped_item_path.is_empty() else null
	if item != null and item.has_method("cancel_drop_presentation"):
		item.call("cancel_drop_presentation")

func _exit_tree() -> void:
	if _departure != null and _departure.is_valid():
		_departure.kill()

func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> bool:
	if not _plan_presentation:
		return await super.show_dialogue(lines, speaker_name_override)
	_plan_presentation = false
	var generation := _presentation_generation
	# His defeat outro has finished. The Scope slips out before he notices it
	# and dismisses it as a replaceable machine in the follow-up conversation.
	var item := get_node_or_null(dropped_item_path)
	if item == null or not item.has_method("present_drop_from"):
		abort_story_sequence()
		return false
	var dropped := bool(await item.call("present_drop_from", get_feet_position()))
	if not is_inside_tree() or generation != _presentation_generation:
		return false
	if not dropped:
		abort_story_sequence()
		return false
	var shown := await super.show_dialogue(lines, speaker_name_override)
	if not is_inside_tree() or generation != _presentation_generation:
		return false
	if not shown:
		abort_story_sequence()
		return false
	_departure = create_tween()
	_departure.tween_property(self, "modulate:a", 0.0, 0.4)
	while _departure != null and _departure.is_valid() and _departure.is_running():
		await get_tree().process_frame
	if not is_inside_tree() or generation != _presentation_generation:
		return false
	visible = false
	_departure = null
	return true

func interact_with_player(player: Node2D) -> void:
	if trainer_id == GIOVANNI and StoryService.is_requirement_met(QUEST, "learn_plan", "active"):
		var result: Dictionary = await $AfterBattleHook.try_handle_interaction(self, player, "interact")
		if not bool(result.get("success", false)):
			abort_story_sequence()
		return
	await super.interact_with_player(player)
