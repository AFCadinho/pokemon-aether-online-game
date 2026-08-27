@tool
extends TrainerNPC

class_name Route24Gary

const TRAINER_ID_PREFIX := "kanto_route_24_gary_"
const DEFAULT_RIVAL_STARTER_ID := "bulbasaur"
const VALID_RIVAL_STARTER_IDS := ["bulbasaur", "squirtle", "charmander"]

@export_range(1, 8, 1) var challenge_width_tiles := 6

var _won_in_current_map_visit := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		trainer_id = await _resolve_rival_trainer_id()
	super._ready()


func supports_trainer_rematches() -> bool:
	return false


func finish_trainer_battle(finished_trainer_id: String, player_won: bool) -> void:
	super.finish_trainer_battle(finished_trainer_id, player_won)
	if finished_trainer_id.strip_edges() == trainer_id and player_won:
		_won_in_current_map_visit = true


func _load_trainer_progress() -> void:
	await super._load_trainer_progress()
	if trainer_progress_state != STATE_FIRST_ENCOUNTER and not _won_in_current_map_visit:
		queue_free()


func _configure_vision_area() -> void:
	super._configure_vision_area()
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
