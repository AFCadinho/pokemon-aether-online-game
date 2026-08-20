extends RefCounted

class_name OgerponBattleForm

const FORM_BY_MASK: Dictionary = {
	"wellspringmask": {
		"species": "Ogerpon Wellspring",
		"types": ["grass", "water"],
		"ability": "water-absorb",
		"ivyCudgelType": "water",
	},
	"hearthflamemask": {
		"species": "Ogerpon Hearthflame",
		"types": ["grass", "fire"],
		"ability": "mold-breaker",
		"ivyCudgelType": "fire",
	},
	"cornerstonemask": {
		"species": "Ogerpon Cornerstone",
		"types": ["grass", "rock"],
		"ability": "sturdy",
		"ivyCudgelType": "rock",
	},
}

const FORM_BY_SPECIES: Dictionary = {
	"ogerpon": {
		"species": "Ogerpon",
		"types": ["grass"],
		"ability": "defiant",
		"ivyCudgelType": "grass",
	},
	"ogerponwellspring": FORM_BY_MASK["wellspringmask"],
	"ogerponhearthflame": FORM_BY_MASK["hearthflamemask"],
	"ogerponcornerstone": FORM_BY_MASK["cornerstonemask"],
}


static func metadata(species: String, item: String = "") -> Dictionary:
	var species_key := _normalize_key(species)
	if not species_key.begins_with("ogerpon"):
		return {}

	# A live Tera forme is more specific than the held mask. Leave it to the
	# regular forme-change presentation instead of collapsing it back here.
	if species_key.ends_with("tera"):
		return {}

	var item_key := _normalize_key(item).trim_suffix("held")
	if FORM_BY_MASK.has(item_key):
		return (FORM_BY_MASK[item_key] as Dictionary).duplicate(true)
	if FORM_BY_SPECIES.has(species_key):
		return (FORM_BY_SPECIES[species_key] as Dictionary).duplicate(true)
	return (FORM_BY_SPECIES["ogerpon"] as Dictionary).duplicate(true)


static func resolve_species(species: String, item: String = "") -> String:
	var form := metadata(species, item)
	return str(form.get("species", species)).strip_edges()


static func apply_to_display_data(data: Dictionary, species: String, item: String = "") -> void:
	var form := metadata(species, item)
	if form.is_empty():
		return

	var battle_species := str(form.get("species", species))
	var ability := str(form.get("ability", ""))
	data["species"] = battle_species
	data["displaySpecies"] = battle_species
	data["types"] = (form.get("types", []) as Array).duplicate()
	data["ability"] = ability
	data["possibleAbilities"] = [ability]


static func apply_ivy_cudgel_type(moves: Array, species: String, item: String = "") -> Array:
	var form := metadata(species, item)
	var ivy_cudgel_type := str(form.get("ivyCudgelType", ""))
	if ivy_cudgel_type.is_empty():
		return moves

	var display_moves: Array = []
	for move_value: Variant in moves:
		if not (move_value is Dictionary):
			display_moves.append(move_value)
			continue
		var move_data := (move_value as Dictionary).duplicate(true)
		var move_key := _normalize_key(str(move_data.get(
			"id",
			move_data.get("move", move_data.get("name", ""))
		)))
		if move_key == "ivycudgel":
			move_data["type"] = ivy_cudgel_type
		display_moves.append(move_data)
	return display_moves


static func _normalize_key(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")
