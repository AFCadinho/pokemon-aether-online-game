extends "res://scripts/ui/ui_overlay.gd"

var fixture_pokemon := Pokemon.new("Pidgey", 18)

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _find_party_pokemon_by_owned_id(pokemon_id: int) -> Pokemon:
	return fixture_pokemon if pokemon_id == 77 else null

func _show_next_move_learn_prompt() -> void:
	pass

func _show_next_evolution_prompt() -> void:
	pass

func _can_use_dev_tools() -> bool:
	return false
