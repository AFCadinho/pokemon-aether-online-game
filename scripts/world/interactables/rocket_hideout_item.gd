extends OverworldItem

## Availability is trusted progression; the drop animation is presentation only.
@export var required_trainer_id := ""
@export var required_quest_id := ""
@export var required_step_id := ""
@export var animate_trainer_drop := false
var _trainer_defeated := false
var _progress_loaded := false
var _progress_generation := 0
var _drop_generation := 0
var _drop_pending := false
var _drop_presenting := false
var _drop_preview := false
var _drop_tween: Tween
var _input_owner := StringName("rocket_drop_%s" % get_instance_id())
var _pending_coop_drop := false

func _ready() -> void:
	var result: Dictionary = GameState.pending_coop_battle_result
	_pending_coop_drop = animate_trainer_drop and result.get("outcome") == "win" and str(result.get("activityId", "")) == required_trainer_id
	super._ready()
	StoryService.story_changed.connect(_on_story_changed)
	TrainerProgressService.progress_invalidated.connect(_load_guard_progress)
	_refresh_availability()
	_load_guard_progress.call_deferred()

func _exit_tree() -> void:
	_cancel_drop()

func _load_guard_progress() -> void:
	if required_trainer_id.is_empty() or claimed:
		return
	_progress_generation += 1
	var generation := _progress_generation
	var result: Dictionary = await TrainerProgressService.get_progress(required_trainer_id)
	if not is_inside_tree() or generation != _progress_generation:
		return
	var was_defeated := _trainer_defeated
	var was_loaded := _progress_loaded
	_progress_loaded = true
	_trainer_defeated = bool(result.get("success", false)) and bool(result.get("progress", {}).get("firstDefeated", false))
	if not _trainer_defeated:
		_cancel_drop()
	elif animate_trainer_drop and not was_defeated and (was_loaded or _pending_coop_drop):
		_pending_coop_drop = false
		_drop_pending = true
		_drop_after_outro.call_deferred()
	_refresh_availability()

func _drop_after_outro() -> void:
	var generation := _drop_generation
	# Reward refresh precedes the solo outro. Co-op reload also retains its
	# result/outro lock; neither flow may reveal the key behind that dialogue.
	await get_tree().process_frame
	while is_inside_tree() and generation == _drop_generation and _drop_pending:
		if not GameState.is_overworld_input_locked() and not _dialogue_is_open():
			break
		await get_tree().process_frame
	if not is_inside_tree() or generation != _drop_generation or not _drop_pending:
		return
	var origin := global_position
	for actor: Node in get_tree().get_nodes_in_group("trainer_npcs"):
		if str(actor.get("trainer_id")) == required_trainer_id and actor.has_method("get_feet_position"):
			origin = actor.call("get_feet_position")
			break
	await present_drop_from(origin)

func present_drop_from(origin: Vector2) -> bool:
	if claimed or _drop_presenting:
		return false
	_drop_pending = false
	_drop_presenting = true
	_drop_preview = true
	var generation := _drop_generation
	GameState.acquire_overworld_input_lock(_input_owner)
	_refresh_availability()
	var offset := to_local(origin)
	_drop_tween = create_tween()
	_drop_tween.tween_method(func(fraction: float):
		if item_sprite != null:
			item_sprite.position = offset.lerp(Vector2.ZERO, fraction) + Vector2(0, -sin(fraction * PI) * 18.0)
	, 0.0, 1.0, 0.45)
	while _drop_tween != null and _drop_tween.is_valid() and _drop_tween.is_running():
		await get_tree().process_frame
	if not is_inside_tree() or generation != _drop_generation:
		return false
	_drop_tween = null
	_drop_presenting = false
	if item_sprite != null:
		item_sprite.position = Vector2.ZERO
	GameState.release_overworld_input_lock(_input_owner)
	_refresh_availability()
	return true

func cancel_drop_presentation() -> void:
	_cancel_drop()
	_refresh_availability()

func _cancel_drop() -> void:
	_drop_generation += 1
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = null
	_drop_pending = false
	_drop_presenting = false
	_drop_preview = false
	if item_sprite != null:
		item_sprite.position = Vector2.ZERO
	GameState.release_overworld_input_lock(_input_owner)

func _on_story_changed(_revision: int) -> void:
	if not required_quest_id.is_empty():
		if StoryService.is_requirement_met(required_quest_id, required_step_id, "active"):
			_drop_preview = false
		elif not StoryService.is_requirement_met(required_quest_id, "learn_plan", "active"):
			_cancel_drop()
	_refresh_availability()
	_load_guard_progress.call_deferred()

func set_claimed(value: bool) -> void:
	if value:
		_cancel_drop()
	super.set_claimed(value)
	_refresh_availability()

func _refresh_availability() -> void:
	var available := not claimed and not _drop_pending and not _drop_presenting
	if not required_trainer_id.is_empty():
		available = available and _trainer_defeated
	if not required_quest_id.is_empty():
		available = available and StoryService.is_requirement_met(required_quest_id, required_step_id, "active")
	visible = available or (_drop_preview and not claimed)
	blocks_movement = available
	set_process(available)
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", available)
		interaction_area.set_deferred("monitorable", available)

func _dialogue_is_open() -> bool:
	var scene := get_tree().current_scene
	var box := scene.get_node_or_null("DialogueBox/Box") if scene != null else null
	return box != null and bool(box.get("is_open"))
