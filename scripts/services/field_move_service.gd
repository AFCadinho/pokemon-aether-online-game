extends Node

class_name FieldMoveServiceNode

signal owned_charms_changed

const DIRECT_FIELD_MOVE_DEFINITIONS := {
	"flash": {
		"name": "Flash",
		"description": "Light the area around you in dark overworld locations.",
	},
}

var owned_charm_moves: Dictionary = {}


func _ready() -> void:
	refresh_owned_charms.call_deferred()


func refresh_owned_charms() -> void:
	if not AuthService.is_authenticated():
		return
	var result: Dictionary = await InventoryService.load_inventory()
	if bool(result.get("success", false)):
		update_owned_charms_from_inventory(result.get("items", []))


func update_owned_charms_from_inventory(items_value: Variant) -> void:
	owned_charm_moves.clear()
	if not (items_value is Array):
		owned_charms_changed.emit()
		return
	var items: Array = items_value as Array
	for item_value: Variant in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value as Dictionary
		var move_id := _normalize_move_id(str(item.get("fieldMove", item.get("field_move", ""))))
		if move_id != "":
			owned_charm_moves[move_id] = str(item.get("name", "Field Move Charm"))
	owned_charms_changed.emit()

func find_party_pokemon_for_move(move_id: String) -> Pokemon:
	var normalized_move_id := _normalize_move_id(move_id)
	if normalized_move_id == "":
		return null

	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null and _pokemon_knows_move(pokemon, normalized_move_id):
			return pokemon
	return null


func can_use_field_move(move_id: String) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var charm_name := str(owned_charm_moves.get(normalized_move_id, ""))
	if charm_name != "":
		return {
			"success": true,
			"source": "charm",
			"itemName": charm_name,
		}
	var pokemon := find_party_pokemon_for_move(move_id)
	if pokemon == null:
		return {
			"success": false,
			"error": "A Pokemon in your party must know %s or you need its Charm." % _format_move_name(move_id),
		}
	return {
		"success": true,
		"pokemon": pokemon,
	}


func is_direct_field_move(move_id: String) -> bool:
	return DIRECT_FIELD_MOVE_DEFINITIONS.has(_normalize_move_id(move_id))


func get_direct_field_move_definition(move_id: String) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var definition_value: Variant = DIRECT_FIELD_MOVE_DEFINITIONS.get(normalized_move_id, {})
	return (definition_value as Dictionary).duplicate(true) if definition_value is Dictionary else {}


func can_use_direct_field_move(move_id: String, pokemon_id := 0) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	if not is_direct_field_move(normalized_move_id):
		return {
			"success": false,
			"error": "%s is not a directly usable overworld move." % _format_move_name(normalized_move_id),
		}
	if pokemon_id <= 0:
		return can_use_field_move(normalized_move_id)

	for pokemon: Pokemon in PlayerSave.party:
		if pokemon == null or pokemon.owned_pokemon_id != pokemon_id:
			continue
		if not _pokemon_knows_move(pokemon, normalized_move_id):
			return {
				"success": false,
				"error": "%s no longer knows %s." % [pokemon.species, _format_move_name(normalized_move_id)],
			}
		return {
			"success": true,
			"source": "pokemon",
			"pokemon": pokemon,
		}
	return {
		"success": false,
		"error": "That Pokemon is no longer in your party.",
	}


func use_direct_field_move(move_id: String, pokemon_id := 0) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var availability := can_use_direct_field_move(normalized_move_id, pokemon_id)
	if not bool(availability.get("success", false)):
		return availability
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("use_direct_field_move"):
		return {"success": false, "error": "The overworld is not ready."}
	var result_value: Variant = world.call("use_direct_field_move", normalized_move_id, availability)
	if not (result_value is Dictionary):
		return {"success": false, "error": "The overworld action returned an invalid result."}
	return result_value as Dictionary


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
