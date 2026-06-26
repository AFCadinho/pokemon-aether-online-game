extends Node

class_name PlayerData # PlayerSave Autoload

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")

signal party_changed

var player_name := "Player"
var player_id := ""
var gender := "male"
var is_staff := false
var party: Array[Pokemon] = []
var money := 0
var playtime_seconds := 0
var appearance_body_id: String = CharacterAppearanceService.DEFAULT_BODY_ID
var appearance_hair_id: String = CharacterAppearanceService.DEFAULT_MALE_HAIR_ID
var appearance_headgear_id: String = CharacterAppearanceService.DEFAULT_MALE_HEADGEAR_ID
var appearance_facegear_id := ""
var appearance_top_id: String = CharacterAppearanceService.DEFAULT_MALE_TOP_ID
var appearance_bottom_id: String = CharacterAppearanceService.DEFAULT_MALE_BOTTOM_ID
var appearance_shoes_id: String = CharacterAppearanceService.DEFAULT_MALE_SHOES_ID
var appearance_hair_color: String = CharacterAppearanceService.DEFAULT_HAIR_COLOR
var appearance_skin_tone: String = CharacterAppearanceService.DEFAULT_SKIN_TONE
var appearance_eye_color: String = CharacterAppearanceService.DEFAULT_EYE_COLOR
var appearance_hair_style_index := 0
var flags := {}

func to_battle_dict() -> Dictionary:
	return {
		"playerId": player_id,
		"name": player_name,
		"team": _party_to_battle_team()
	}

func _party_to_battle_team() -> Array:
	var battle_team := []

	for pokemon in party:
		battle_team.append(pokemon.to_battle_dict())

	return battle_team

func add_pokemon(pokemon: Pokemon) -> void:
	if party.size() >= 6:
		return

	pokemon.ensure_instance_id()
	party.append(pokemon)
	party_changed.emit()

func to_party_state() -> Dictionary:
	var party_data: Array = []
	for pokemon in party:
		if pokemon == null:
			continue
		party_data.append(pokemon.to_persistence_dict())

	return {
		"party": party_data,
	}


func to_battle_state() -> Dictionary:
	var team: Array = []
	for index in range(party.size()):
		var pokemon: Pokemon = party[index]
		if pokemon == null:
			continue

		team.append(pokemon.to_battle_state_dict(index + 1))

	return {
		"team": team,
	}

func replace_party_from_state(party_data: Array) -> void:
	var loaded_party: Array[Pokemon] = []
	for pokemon_value: Variant in party_data:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
		if pokemon == null:
			push_warning("PlayerSave: skipped persisted Pokemon: %s" % PokemonFactory.last_error_message)
			continue

		pokemon.ensure_instance_id()
		loaded_party.append(pokemon)
		if loaded_party.size() >= 6:
			break

	party = loaded_party
	party_changed.emit()

func to_appearance_state() -> Dictionary:
	return {
		"gender": gender,
		"body": appearance_body_id,
		"hair": CharacterAppearanceService.serialize_part_id(appearance_hair_id),
		"hair_style_index": appearance_hair_style_index,
		"headgear": CharacterAppearanceService.serialize_part_id(appearance_headgear_id),
		"facegear": CharacterAppearanceService.serialize_part_id(appearance_facegear_id),
		"top": CharacterAppearanceService.serialize_part_id(appearance_top_id),
		"bottom": CharacterAppearanceService.serialize_part_id(appearance_bottom_id),
		"shoes": CharacterAppearanceService.serialize_part_id(appearance_shoes_id),
		"legs": CharacterAppearanceService.serialize_part_id(appearance_bottom_id),
		"feet": CharacterAppearanceService.serialize_part_id(appearance_shoes_id),
		"hair_color": appearance_hair_color,
		"skin_tone": appearance_skin_tone,
		"eye_color": appearance_eye_color,
	}

func apply_appearance_state(appearance_state: Dictionary) -> void:
	var decoded_body_appearance: Dictionary = CharacterAppearanceService.decode_presence_body_appearance(str(appearance_state.get("body", "")))
	if not decoded_body_appearance.is_empty():
		var merged_appearance_state: Dictionary = appearance_state.duplicate()
		for key: Variant in decoded_body_appearance.keys():
			merged_appearance_state[key] = decoded_body_appearance[key]
		appearance_state = merged_appearance_state

	var body_id := str(appearance_state.get("body", "")).strip_edges()
	if body_id != "":
		appearance_body_id = CharacterAppearanceService.get_presence_body_base_id(body_id)

	appearance_hair_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("hair", appearance_hair_id)))
	if appearance_state.has("hair_style_index"):
		appearance_hair_style_index = max(int(appearance_state.get("hair_style_index", appearance_hair_style_index)), 0)
	appearance_headgear_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("headgear", appearance_headgear_id)))
	appearance_facegear_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("facegear", appearance_facegear_id)))
	appearance_top_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("top", appearance_top_id)))
	appearance_bottom_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("bottom", appearance_state.get("legs", appearance_bottom_id))))
	appearance_shoes_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("shoes", appearance_state.get("feet", appearance_shoes_id))))
	appearance_hair_color = str(appearance_state.get("hair_color", appearance_hair_color)).strip_edges()
	appearance_skin_tone = str(appearance_state.get("skin_tone", appearance_skin_tone)).strip_edges()
	appearance_eye_color = str(appearance_state.get("eye_color", appearance_eye_color)).strip_edges()
	if appearance_state.has("hair"):
		if appearance_hair_id != "":
			sync_hair_style_index_from_id()
	elif appearance_state.has("hair_style_index"):
		apply_hair_style_index_to_id()
	ensure_body_matches_gender(false)

func ensure_body_matches_gender(fill_empty_parts: bool = true) -> void:
	var body_ids: Array[String] = CharacterAppearanceService.get_available_body_ids(gender)
	if not body_ids.has(appearance_body_id):
		appearance_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID if gender == "female" else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
		fill_empty_parts = true
	ensure_layered_appearance_defaults(fill_empty_parts)

func ensure_layered_appearance_defaults(fill_empty_parts: bool = true) -> void:
	if not CharacterAppearanceService.body_supports_layered_parts(appearance_body_id, gender):
		return
	if fill_empty_parts and appearance_hair_id == "":
		appearance_hair_id = CharacterAppearanceService.get_default_part_id("hair", gender)
	if fill_empty_parts and appearance_headgear_id == "":
		appearance_headgear_id = CharacterAppearanceService.get_default_part_id("headgear", gender)
	if fill_empty_parts and appearance_top_id == "":
		appearance_top_id = CharacterAppearanceService.get_default_part_id("top", gender)
	if fill_empty_parts and appearance_bottom_id == "":
		appearance_bottom_id = CharacterAppearanceService.get_default_part_id("bottom", gender)
	if fill_empty_parts and appearance_shoes_id == "":
		appearance_shoes_id = CharacterAppearanceService.get_default_part_id("shoes", gender)
	if appearance_hair_color == "":
		appearance_hair_color = CharacterAppearanceService.DEFAULT_HAIR_COLOR
	if appearance_skin_tone == "":
		appearance_skin_tone = CharacterAppearanceService.DEFAULT_SKIN_TONE
	if appearance_eye_color == "":
		appearance_eye_color = CharacterAppearanceService.DEFAULT_EYE_COLOR
	if appearance_hair_id != "":
		sync_hair_style_index_from_id()

func sync_hair_style_index_from_id() -> void:
	var hair_ids: Array[String] = CharacterAppearanceService.get_available_part_ids("hair", gender)
	var hair_index: int = hair_ids.find(appearance_hair_id)
	appearance_hair_style_index = maxi(hair_index, 0)

func apply_hair_style_index_to_id() -> void:
	var hair_ids: Array[String] = CharacterAppearanceService.get_available_part_ids("hair", gender)
	if hair_ids.is_empty():
		return
	var clamped_index: int = clampi(appearance_hair_style_index, 0, hair_ids.size() - 1)
	appearance_hair_style_index = clamped_index
	appearance_hair_id = hair_ids[clamped_index]

func apply_battle_team_state(team: Array) -> void:
	var party_by_instance_id := {}
	var used_fallback_instances := {}

	for pokemon in party:
		pokemon.ensure_instance_id()
		party_by_instance_id[pokemon.instance_id] = pokemon

	for pokemon_data in team:
		if not (pokemon_data is Dictionary):
			continue

		var pokemon: Pokemon = null
		var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", "")))
		if instance_id != "" and party_by_instance_id.has(instance_id):
			pokemon = party_by_instance_id[instance_id] as Pokemon
		else:
			pokemon = _find_party_pokemon_for_team_entry(pokemon_data, used_fallback_instances)
		if pokemon == null:
			continue

		if instance_id != "":
			used_fallback_instances[instance_id] = true
		else:
			used_fallback_instances[pokemon.instance_id] = true
		var hp_data := _get_battle_hp_data(pokemon_data)
		if hp_data.is_empty() and not _has_battle_move_data(pokemon_data):
			continue

		if not hp_data.is_empty():
			_apply_hp_data_to_pokemon(pokemon, hp_data)

		_apply_move_data_to_pokemon(pokemon, pokemon_data)

	party_changed.emit()

func _find_party_pokemon_for_team_entry(pokemon_data: Dictionary, used_fallback_instances: Dictionary) -> Pokemon:
	var metadata_slot := int(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", -1)))
	if metadata_slot > 0:
		var slot_index := metadata_slot - 1
		if slot_index >= 0 and slot_index < party.size():
			var slot_pokemon: Pokemon = party[slot_index]
			if (
				slot_pokemon != null
				and not used_fallback_instances.has(slot_pokemon.instance_id)
				and _party_pokemon_matches_team_entry_species(slot_pokemon, pokemon_data)
			):
				return slot_pokemon

	var species := str(pokemon_data.get("species", pokemon_data.get("species_id", pokemon_data.get("name", "")))).strip_edges().to_lower()
	if species == "":
		species = str(pokemon_data.get("ident", "")).strip_edges().to_lower()
		if species.contains(": "):
			species = species.split(": ", false)[1]

	for slot_pokemon in party:
		if used_fallback_instances.has(slot_pokemon.instance_id):
			continue
		if species != "" and _normalize_species_for_battle_compare(slot_pokemon.species) != _normalize_species_for_battle_compare(species):
			continue

		return slot_pokemon

	return null

func _party_pokemon_matches_team_entry_species(pokemon: Pokemon, pokemon_data: Dictionary) -> bool:
	if pokemon == null:
		return false

	var species := str(pokemon_data.get("species", pokemon_data.get("species_id", pokemon_data.get("displaySpecies", pokemon_data.get("name", ""))))).strip_edges()
	if species == "":
		species = str(pokemon_data.get("ident", "")).strip_edges()
		if species.contains(": "):
			species = species.split(": ", false)[1]
	if species == "":
		return true

	return _normalize_species_for_battle_compare(pokemon.species) == _normalize_species_for_battle_compare(species)

func _normalize_species_for_battle_compare(species: String) -> String:
	return species.strip_edges().to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")

func _has_battle_move_data(pokemon_data: Variant) -> bool:
	if not (pokemon_data is Dictionary):
		return false

	var pokemon_state: Dictionary = pokemon_data as Dictionary
	return pokemon_state.has("moves") or pokemon_state.has("moveSlots") or pokemon_state.has("baseMoves")

func _apply_move_data_to_pokemon(pokemon: Pokemon, pokemon_data: Dictionary) -> void:
	var move_slots_value: Variant = pokemon_data.get("moves", pokemon_data.get("moveSlots", pokemon_data.get("baseMoves", [])))
	if not (move_slots_value is Array):
		return

	var move_slots: Array = move_slots_value as Array
	if move_slots.is_empty() and pokemon.moves.is_empty():
		return

	var updated_moves: Array = pokemon.moves.duplicate(true)
	if updated_moves.is_empty():
		# In case party state only has move names, initialize from battle state.
		for move_index in range(min(move_slots.size(), 4)):
			var move_data: Dictionary = _normalize_battle_move_state(move_slots[move_index])
			if move_data.is_empty():
				continue
			updated_moves.append(move_data)
	else:
		var max_slots: int = min(updated_moves.size(), move_slots.size())
		for move_index in range(max_slots):
			var current_move_value: Variant = updated_moves[move_index]
			var current_state: Dictionary = {}
			if current_move_value is Dictionary:
				current_state = (current_move_value as Dictionary).duplicate(true)

			var next_state: Dictionary = _normalize_battle_move_state(move_slots[move_index], current_state)
			if next_state.is_empty():
				continue

			updated_moves[move_index] = next_state

		var total_slots: int = move_slots.size()
		if total_slots > updated_moves.size():
			for move_index in range(updated_moves.size(), min(total_slots, 4)):
				var next_state: Dictionary = _normalize_battle_move_state(move_slots[move_index])
				if next_state.is_empty():
					continue
				updated_moves.append(next_state)

	pokemon.moves = updated_moves.slice(0, 4)

func _normalize_battle_move_state(move_value: Variant, fallback_move: Dictionary = {}) -> Dictionary:
	var normalized_move: Dictionary = fallback_move.duplicate(true)
	if move_value is Dictionary:
		var move_data: Dictionary = move_value as Dictionary
		var fallback_name: String = str(fallback_move.get("name", "")).strip_edges()
		var fallback_id: String = str(fallback_move.get("id", "")).strip_edges()

		var move_name: String = str(move_data.get("name", move_data.get("move", ""))).strip_edges()
		var move_id: String = str(move_data.get("id", move_data.get("move", ""))).strip_edges()
		if move_name == "" and move_id != "":
			move_name = move_id.replace("-", " ").replace("_", " ")

		if move_name != "":
			normalized_move["name"] = _title_case_move_name(move_name)
		if move_id != "":
			normalized_move["id"] = move_id.to_lower()
		if not normalized_move.has("name") and fallback_name != "":
			normalized_move["name"] = fallback_name
		if not normalized_move.has("id") and fallback_id != "":
			normalized_move["id"] = fallback_id

		if not normalized_move.has("name") and normalized_move.has("id"):
			normalized_move["name"] = _title_case_move_name(str(normalized_move.get("id", "")))

		var fallback_pp: int = _safe_int(
			_get_first_dictionary_value(
				normalized_move,
				["pp", "currentPp", "currentPP", "current_pp"],
				0
			)
		)
		var current_pp: int = _safe_int(
			_get_first_dictionary_value(
				move_data,
				["pp", "currentPp", "currentPP", "current_pp"],
				fallback_pp
			)
		)
		var fallback_max_pp: int = _safe_int(
			_get_first_dictionary_value(
				normalized_move,
				["maxPp", "maxpp", "maxPP", "max_pp"],
				fallback_pp
			)
		)
		var max_pp: int = _safe_int(
			_get_first_dictionary_value(
				move_data,
				["maxPp", "maxpp", "maxPP", "max_pp"],
				fallback_max_pp
			)
		)
		if max_pp <= 0:
			max_pp = max(current_pp, 0)
		if current_pp < 0:
			current_pp = 0
		current_pp = min(current_pp, max_pp)

		normalized_move["pp"] = current_pp
		normalized_move["maxPp"] = max_pp
		normalized_move["maxpp"] = max_pp
		return normalized_move

	if move_value is String:
		var move_name := String(move_value).strip_edges()
		if move_name == "":
			return {}
		normalized_move["id"] = move_name.to_lower()
		normalized_move["name"] = _title_case_move_name(move_name)
		if not normalized_move.has("pp"):
			var current_pp: int = _safe_int(_get_first_dictionary_value(normalized_move, ["pp", "currentPp", "currentPP", "current_pp"], 0))
			var max_pp: int = _safe_int(_get_first_dictionary_value(normalized_move, ["maxPp", "maxpp", "maxPP", "max_pp"], current_pp))
			if max_pp <= 0:
				max_pp = max(current_pp, 0)
			current_pp = min(current_pp, max_pp)

			normalized_move["pp"] = current_pp
			normalized_move["maxPp"] = max_pp
			normalized_move["maxpp"] = normalized_move["maxPp"]
		return normalized_move

	return {}


func _get_first_dictionary_value(dictionary: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if dictionary.has(key):
			return dictionary.get(key)

	return fallback

func _safe_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback
	if value is int:
		return max(int(value), 0)
	if value is float:
		return max(int(value), 0)
	if str(value).is_valid_int():
		return max(int(value), 0)
	return fallback

func _title_case_move_name(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized == "":
		return ""

	var words: PackedStringArray = normalized.split(" ", false)
	for index in range(words.size()):
		var word := words[index]
		if word.length() == 0:
			continue
		words[index] = word.substr(0, 1).to_upper() + word.substr(1).to_lower()

	if words.size() > 1:
		return " ".join(words)

	var dashed_words: PackedStringArray = normalized.split("-", false)
	for index in range(dashed_words.size()):
		var word := dashed_words[index]
		if word.length() == 0:
			continue
		dashed_words[index] = word.substr(0, 1).to_upper() + word.substr(1).to_lower()

	if dashed_words.size() > 1:
		return "-".join(dashed_words)

	return normalized.substr(0, 1).to_upper() + normalized.substr(1).to_lower()

func _apply_hp_data_to_pokemon(pokemon: Pokemon, hp_data: Dictionary) -> void:
	var current_hp := int(hp_data.get("current_hp", pokemon.current_hp))
	var max_hp := int(hp_data.get("max_hp", pokemon.max_hp))

	if current_hp <= 0 and max_hp == 1:
		pokemon.current_hp = 0
		pokemon.has_saved_hp_state = true
		return

	if max_hp == 100 and pokemon.max_hp != 100:
		var hp_percent := int(clamp(current_hp, 0, 100))
		pokemon.current_hp = int(round((float(hp_percent) / 100.0) * float(pokemon.max_hp)))
	else:
		pokemon.max_hp = max(max_hp, 1)
		pokemon.current_hp = int(clamp(current_hp, 0, pokemon.max_hp))

	pokemon.has_saved_hp_state = true

func _get_battle_hp_data(pokemon_data: Dictionary) -> Dictionary:
	if pokemon_data.has("hp"):
		return {
			"current_hp": int(pokemon_data.get("hp", 0)),
			"max_hp": int(pokemon_data.get("maxHp", 1)),
		}

	if bool(pokemon_data.get("fainted", false)):
		return {
			"current_hp": 0,
		}

	return {}
