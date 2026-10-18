extends OverworldItem

## Presentation follows trusted trainer/story state. The server checks again on claim.
@export var required_trainer_id := ""
@export var required_quest_id := ""
@export var required_step_id := ""
var _trainer_defeated := false
var _progress_generation := 0

func _ready() -> void:
	super._ready()
	StoryService.story_changed.connect(_on_story_changed)
	TrainerProgressService.progress_invalidated.connect(_load_guard_progress)
	_refresh_availability()
	_load_guard_progress.call_deferred()

func _load_guard_progress() -> void:
	if required_trainer_id.is_empty() or claimed:
		return
	_progress_generation += 1
	var generation := _progress_generation
	var result: Dictionary = await TrainerProgressService.get_progress(required_trainer_id)
	if not is_inside_tree() or generation != _progress_generation:
		return
	_trainer_defeated = bool(result.get("success", false)) and bool(result.get("progress", {}).get("firstDefeated", false))
	_refresh_availability()

func _on_story_changed(_revision: int) -> void:
	_refresh_availability()
	# Solo rewards refresh StoryService after their trusted settlement. They do
	# not emit the developer-only trainer progress invalidation signal.
	_load_guard_progress.call_deferred()

func set_claimed(value: bool) -> void:
	super.set_claimed(value)
	_refresh_availability()

func _refresh_availability() -> void:
	var available := not claimed
	if not required_trainer_id.is_empty():
		available = available and _trainer_defeated
	if not required_quest_id.is_empty():
		available = available and StoryService.is_requirement_met(required_quest_id, required_step_id, "active")
	visible = available
	blocks_movement = available
	set_process(available)
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", available)
		interaction_area.set_deferred("monitorable", available)
