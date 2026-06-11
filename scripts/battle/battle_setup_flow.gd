extends RefCounted

class_name BattleSetupFlow

var event_text_formatter


func setup(formatter) -> void:
	event_text_formatter = formatter


func get_wild_battle_start_messages(player_species: String, opponent_species: String) -> Array[String]:
	return event_text_formatter.format_wild_battle_start_messages(player_species, opponent_species)


func get_trainer_battle_start_messages(
	player_species: String,
	opponent_species: String,
	trainer_data: Dictionary,
	fallback_trainer_name: String
) -> Array[String]:
	return event_text_formatter.format_trainer_battle_start_messages(
		player_species,
		opponent_species,
		get_trainer_name(trainer_data, fallback_trainer_name)
	)


func get_trainer_name(trainer_data: Dictionary, fallback_trainer_name: String) -> String:
	var trainer_name := str(trainer_data.get("name", fallback_trainer_name))
	if trainer_name == "":
		return "Trainer"

	return trainer_name
