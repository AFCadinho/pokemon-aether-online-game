extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var party_service_source := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	_check(
		source.contains("if _has_pending_evolution_prompt(pokemon_id, target_species_id):"),
		"Evolution prompts are deduplicated before entering the review queue"
	)
	_check(
		source.contains("if not _evolution_prompt_matches_current_species(prompt, pokemon):"),
		"Queued evolution prompts are revalidated against the current species"
	)
	_check(
		source.contains("_normalize_evolution_species_key(pokemon.species) == expected_species"),
		"A prompt becomes stale after its Pokemon has evolved"
	)
	_check(
		source.contains("func _announce_evolution_moves(")
		and source.contains('result.get("moveLearnCandidates", [])'),
		"Evolution moves reuse the move learning prompt queue"
	)
	_check(
		party_service_source.contains('body.get("learnedMoves", [])')
		and party_service_source.contains('body.get("moveLearnCandidates", [])'),
		"Evolution responses preserve automatic moves and replacement candidates"
	)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
