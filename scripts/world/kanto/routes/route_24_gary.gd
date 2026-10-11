@tool
extends TrainerNPC

class_name Route24Gary

const TRAINER_ID_PREFIX := "kanto_route_24_gary_"
const ENCOUNTER_ID := "kanto_route_24_gary_oak"
const VALID_RIVAL_STARTER_IDS := ["bulbasaur", "squirtle", "charmander"]
const PROGRESS_RETRY_SECONDS := 2.0

@export_range(1, 8, 1) var challenge_width_tiles := 6

var _won_in_current_map_visit := false
var _progress_retry: Timer


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Keep the encounter inactive until both progress and the correct team
		# are known. Loading failures must never select another starter team.
		hide()
		trainer_id = ""
		_progress_retry = Timer.new()
		_progress_retry.one_shot = true
		_progress_retry.wait_time = PROGRESS_RETRY_SECONDS
		_progress_retry.timeout.connect(_load_trainer_progress)
		add_child(_progress_retry)
	super._ready()


func supports_trainer_rematches() -> bool:
	return false


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
	if trainer_progress_state != STATE_FIRST_ENCOUNTER and not _won_in_current_map_visit:
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
	show()


func _request_encounter_progress() -> Dictionary:
	return await TrainerProgressService.get_progress(ENCOUNTER_ID)


func _request_starter_options() -> Dictionary:
	return await PlayerPartyStateService.get_starter_options()


func _retry_encounter_progress() -> void:
	trainer_progress_request_active = false
	trainer_progress_loaded = false
	_refresh_rematch_marker()
	_configure_vision_area()
	hide()
	_progress_retry.start()


func _apply_vision_area_configuration() -> void:
	super._apply_vision_area_configuration()
	if vision_collision_shape == null or vision_collision_shape.disabled:
		return
	var shape := vision_collision_shape.shape as RectangleShape2D
	if shape != null:
		shape.size.x = float(challenge_width_tiles * TILE_SIZE)


func _is_body_in_sight_range(body: Node2D) -> bool:
	var range_tiles: int = maxi(sight_range_tiles, 0)
	if body == null or range_tiles == 0:
		return false
	var npc_tile := _to_tile(get_feet_position())
	var body_tile := _to_tile(_get_body_target_feet_position(body))
	var delta := body_tile - npc_tile
	var left_width := ceili(float(challenge_width_tiles - 1) * 0.5)
	var right_width := floori(float(challenge_width_tiles - 1) * 0.5)
	return (
		delta.y >= 1
		and delta.y <= range_tiles
		and delta.x >= -left_width
		and delta.x <= right_width
	)


func walk_to_player(_body: Node2D) -> void:
	# Gary guards the complete bridge entrance and starts the battle in place.
	_set_idle_frame(Vector2.DOWN)


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
		push_warning("Route24Gary: rival starter lookup failed; retrying without starting a battle.")
	if starter_id.is_empty():
		return ""
	return TRAINER_ID_PREFIX + starter_id
