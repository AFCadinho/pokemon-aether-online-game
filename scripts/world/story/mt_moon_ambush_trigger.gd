extends StoryTrigger

const QUEST_ID := "travel_through_mt_moon"
const FINAL_STEP_ID := "cross_mt_moon"

var _pending_activation := false


func _ready() -> void:
	super._ready()
	if not StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.connect(_on_story_changed)
	_on_story_changed(StoryService.get_revision())


func _process(_delta: float) -> void:
	if (
		not _pending_activation
		or _in_flight
		or GameState.is_overworld_input_locked()
		or GameState.is_ui_input_locked()
	):
		return
	_check_overlapping_player()


func _exit_tree() -> void:
	if StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.disconnect(_on_story_changed)


func _on_story_changed(_revision: int) -> void:
	_pending_activation = StoryService.is_requirement_met(
		QUEST_ID,
		FINAL_STEP_ID,
		"active"
	)


func _check_overlapping_player() -> void:
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player") or body.name == "Player":
			_pending_activation = false
			_on_body_entered(body)
			return
