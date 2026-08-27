@tool
extends TrainerNPC

class_name Route24Gary

const TRAINER_ID_PREFIX := "kanto_route_24_gary_"
const DEFAULT_RIVAL_STARTER_ID := "bulbasaur"
const VALID_RIVAL_STARTER_IDS := ["bulbasaur", "squirtle", "charmander"]
const CLEARED_POSITION_OFFSET := Vector2(64, 0)

var _bridge_guard_position := Vector2.ZERO


func _ready() -> void:
	_bridge_guard_position = position
	if not Engine.is_editor_hint():
		trainer_id = await _resolve_rival_trainer_id()
	super._ready()


func supports_trainer_rematches() -> bool:
	return false


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	super.finish_trainer_battle(finished_trainer_id, player_won)
	if finished_trainer_id.strip_edges() == trainer_id and player_won:
		_move_clear_of_bridge()


func apply_battle_victory_progress(progress_trainer_id: String, progress: Dictionary) -> void:
	super.apply_battle_victory_progress(progress_trainer_id, progress)
	if progress_trainer_id.strip_edges() == trainer_id:
		_apply_progress_position()


func _load_trainer_progress() -> void:
	await super._load_trainer_progress()
	_apply_progress_position()


func _resolve_rival_trainer_id() -> String:
	var starter_id := DEFAULT_RIVAL_STARTER_ID
	var options: Dictionary = await PlayerPartyStateService.get_starter_options()
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
		push_warning(
			"Route24Gary: rival starter lookup failed; using the Bulbasaur fallback."
		)
	return TRAINER_ID_PREFIX + starter_id


func _apply_progress_position() -> void:
	if trainer_progress_state == STATE_FIRST_ENCOUNTER:
		position = _bridge_guard_position
		return
	_move_clear_of_bridge()


func _move_clear_of_bridge() -> void:
	position = _bridge_guard_position + CLEARED_POSITION_OFFSET
	_set_idle_frame(Vector2.LEFT)
