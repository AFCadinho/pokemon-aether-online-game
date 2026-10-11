@tool
extends TrainerNPC

class_name RivalTrainerNPC

const VALID_RIVAL_STARTER_IDS := ["bulbasaur", "squirtle", "charmander"]
const PROGRESS_RETRY_SECONDS := 2.0

@export var rival_encounter_id := ""

var _won_in_current_map_visit := false
var _progress_retry: Timer
var _encounter_allows_rematches := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Keep the encounter inactive until both progress and the correct team
		# are known. Loading failures must never select another starter team.
		_progress_retry = Timer.new()
		_progress_retry.one_shot = true
		_progress_retry.wait_time = PROGRESS_RETRY_SECONDS
		_progress_retry.timeout.connect(_load_trainer_progress)
		add_child(_progress_retry)
	super._ready()
	if not Engine.is_editor_hint():
		# Trainer profiles may supply a default team. Only the persisted rival
		# starter may select the battle team for this controller.
		trainer_id = ""


func supports_trainer_rematches() -> bool:
	return _encounter_allows_rematches


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	super.finish_trainer_battle(finished_trainer_id, player_won)
	if finished_trainer_id.strip_edges() == trainer_id and player_won:
		_won_in_current_map_visit = true


func _load_trainer_progress() -> void:
	if trainer_progress_request_active:
		return
	_progress_retry.stop()
	trainer_progress_request_active = true
	var result: Dictionary = await _request_encounter_progress()
	if bool(result.get("success", false)):
		var progress: Dictionary = result.get("progress", {})
		# A successful transport without a valid projection is still unknown.
		if str(progress.get("state", "")) in [STATE_FIRST_ENCOUNTER, STATE_DEFEATED, STATE_READY, STATE_SLEEPING, STATE_COMPLETED]:
			_apply_trainer_progress(progress, STATE_FIRST_ENCOUNTER)
		else:
			result["success"] = false
	if not bool(result.get("success", false)):
		_retry_encounter_progress()
		return
	if not supports_trainer_rematches() and trainer_progress_state != STATE_FIRST_ENCOUNTER and not _won_in_current_map_visit:
		trainer_progress_request_active = false
		queue_free()
		return
	if trainer_id.is_empty():
		trainer_progress_loaded = false
		trainer_id = await _resolve_rival_trainer_id()
		if trainer_id.is_empty():
			_retry_encounter_progress()
			return
	trainer_progress_loaded = true
	trainer_progress_request_active = false
	_refresh_rematch_marker()
	_configure_vision_area()
	if trainer_progress_state == STATE_SLEEPING:
		next_progress_refresh_at_msec = Time.get_ticks_msec() + SLEEPING_REFRESH_INTERVAL_MSEC
	_apply_story_visibility()


func _request_encounter_progress() -> Dictionary:
	return await TrainerProgressService.get_progress(rival_encounter_id + "_rival")


func _request_starter_options() -> Dictionary:
	return await PlayerPartyStateService.get_starter_options()


func _retry_encounter_progress() -> void:
	trainer_progress_request_active = false
	trainer_progress_loaded = false
	_refresh_rematch_marker()
	_configure_vision_area()
	_apply_story_visibility()
	_progress_retry.start()


func _resolve_rival_trainer_id() -> String:
	var starter_id := ""
	var options: Dictionary = await _request_starter_options()
	if bool(options.get("success", false)):
		var resolved_starter_id := str(options.get("rivalStarterSpeciesId", "")).strip_edges().to_lower()
		if resolved_starter_id in VALID_RIVAL_STARTER_IDS:
			starter_id = resolved_starter_id
		else:
			var prior_trainer_id := str(options.get("rivalTrainerId", "")).strip_edges().to_lower()
			var trainer_suffix := prior_trainer_id.rsplit("_", true, 1)[-1]
			if trainer_suffix in VALID_RIVAL_STARTER_IDS:
				starter_id = trainer_suffix
	else:
		push_warning("RivalTrainerNPC: rival starter lookup failed; retrying without starting a battle.")
	if starter_id.is_empty():
		return ""
	return rival_encounter_id + "_" + starter_id


func _apply_trainer_progress(progress: Dictionary, fallback_state: String) -> void:
	_encounter_allows_rematches = bool(progress.get("rematchEligible", false))
	super._apply_trainer_progress(progress, fallback_state)


func _is_story_visibility_active() -> bool:
	if not Engine.is_editor_hint():
		if not trainer_progress_loaded:
			return false
		if not supports_trainer_rematches() and trainer_progress_state != STATE_FIRST_ENCOUNTER and not _won_in_current_map_visit:
			return false
	return super._is_story_visibility_active()
