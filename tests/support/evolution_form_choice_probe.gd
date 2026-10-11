extends "res://scripts/ui/ui_overlay.gd"

var fixture_pokemon := Pokemon.new("Tandemaus", 25)
var submitted: Dictionary = {}

func _ready() -> void:
	pokemon_summary_sprite_loader.free()
	pokemon_summary_sprite_loader = null
	pokedex_sprite_loader.free()
	pokedex_sprite_loader = null

func _process(_delta: float) -> void:
	pass

func _find_party_pokemon_by_owned_id(_pokemon_id: int) -> Pokemon:
	return fixture_pokemon

func _request_evolution_choice(pokemon_id: int, target_species_id: String, confirm: bool) -> Dictionary:
	submitted = {"pokemonId": pokemon_id, "targetSpeciesId": target_species_id, "confirm": confirm}
	return {"success": false, "error": "Fixture save rejected"}
