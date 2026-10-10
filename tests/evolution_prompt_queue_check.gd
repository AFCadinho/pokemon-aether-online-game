extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"
const POKEMON_ASSETS := preload("res://scripts/data/pokemon_assets.gd")

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
	call_deferred("_check_evolution_form_sprites")


func _check_evolution_form_sprites() -> void:
	for species: String in ["Marowak Alola", "Urshifu", "Urshifu Rapid-Strike"]:
		var sprite := POKEMON_ASSETS.load_home_sprite(species)
		_check(sprite != null, "%s evolution preview has an existing HOME sprite" % species)
	var rapid_shiny := POKEMON_ASSETS.load_home_sprite("Urshifu Rapid-Strike", true)
	_check(
		rapid_shiny != null and rapid_shiny.resource_path.ends_with("pokemon_home_shiny/urshifu-rapidstrike.png"),
		"Rapid Strike evolution uses its shiny form sprite instead of the normal fallback"
	)
	for species: String in ["maushold", "solgaleo", "lunala", "malamar", "sirfetchd", "kingambit", "annihilape", "wyrdeer", "runerigus", "alcremie", "ursaluna", "basculegion", "basculegion-f"]:
		for shiny: bool in [false, true]:
			var sprite := POKEMON_ASSETS.load_home_sprite(species, shiny)
			_check(sprite != null, "%s evolution preview loads (shiny=%s)" % [species, shiny])
	for species: String in ["Gourgeist", "Gourgeist Average", "gourgeist-average", "gourgeist-small", "gourgeist-large", "gourgeist-super"]:
		var normal := POKEMON_ASSETS.load_home_sprite(species)
		_check(normal != null and normal.resource_path.ends_with("pokemon_home/Gourgeist-Average.png"),
			"%s has an available normal HOME icon" % species)
		var shiny := POKEMON_ASSETS.load_home_sprite(species, true)
		var shiny_name := "gourgeist" if species in ["Gourgeist", "Gourgeist Average", "gourgeist-average"] else species
		_check(shiny != null and shiny.resource_path.ends_with("pokemon_home_shiny/%s.png" % shiny_name),
			"%s uses its shiny form icon" % species)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
