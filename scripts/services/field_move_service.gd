extends Node

class_name FieldMoveServiceNode


func find_party_pokemon_for_move(move_id: String) -> Pokemon:
	var normalized_move_id := _normalize_move_id(move_id)
	if normalized_move_id == "":
		return null

	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null and _pokemon_knows_move(pokemon, normalized_move_id):
			return pokemon
	return null


func can_use_field_move(move_id: String) -> Dictionary:
	var pokemon := find_party_pokemon_for_move(move_id)
	if pokemon == null:
		return {
			"success": false,
			"error": "A Pokemon in your party must know %s." % _format_move_name(move_id),
		}
	return {
		"success": true,
		"pokemon": pokemon,
	}


func _pokemon_knows_move(pokemon: Pokemon, move_id: String) -> bool:
	for move_value: Variant in pokemon.moves:
		if not (move_value is Dictionary):
			continue
		var move_data: Dictionary = move_value as Dictionary
		if _normalize_move_id(str(move_data.get("id", move_data.get("move", "")))) == move_id:
			return true
	return false


func _normalize_move_id(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


func _format_move_name(move_id: String) -> String:
	return _normalize_move_id(move_id).replace("-", " ").capitalize()
