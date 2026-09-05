extends Node

class_name PlayerData # PlayerSave Autoload

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")

signal party_changed
signal gym_badges_changed

var player_name := "Player"
var player_id := ""
var gender := "male"
var is_staff := false
var party: Array[Pokemon] = []
var money := 0
var bank_money := 0
var gems := 0
var aetherite := 0
var battle_points := 0
var playtime_seconds := 0
var appearance_body_id: String = CharacterAppearanceService.DEFAULT_BODY_ID
var appearance_hair_id: String = CharacterAppearanceService.DEFAULT_MALE_HAIR_ID
var appearance_headgear_id: String = CharacterAppearanceService.DEFAULT_MALE_HEADGEAR_ID
var appearance_facial_hair_id := ""
var appearance_facegear_id := ""
var appearance_top_id: String = CharacterAppearanceService.DEFAULT_MALE_TOP_ID
var appearance_bottom_id: String = CharacterAppearanceService.DEFAULT_MALE_BOTTOM_ID
var appearance_shoes_id: String = CharacterAppearanceService.DEFAULT_MALE_SHOES_ID
var appearance_hair_color: String = ""
var appearance_skin_tone: String = CharacterAppearanceService.DEFAULT_SKIN_TONE
var appearance_eye_color: String = ""
var appearance_facegear_color: String = "#ffffff"
var appearance_facial_hair_color: String = "#ffffff"
var appearance_top_color: String = "#ffffff"
var appearance_bottom_color: String = "#ffffff"
var appearance_shoes_color: String = "#ffffff"
var appearance_hair_style_index := 0
var flags := {}
var earned_gym_badges: Array[String] = []

func apply_account_identity(user: Dictionary) -> void:
	player_name = str(user.get("displayName", user.get("username", "Player"))).strip_edges()
	if player_name == "":
		player_name = "Player"
	player_id = ""
	for key: String in ["id", "userId", "user_id"]:
		var value := str(user.get(key, "")).strip_edges()
		if value != "":
			player_id = value
			break
	gender = CharacterAppearanceService.normalize_gender(str(user.get("gender", "male")))
	is_staff = _user_has_staff_role(user)
	flags.erase("join_date")
	var join_date := str(user.get("createdAt", user.get("created_at", ""))).strip_edges()
	if join_date != "":
		flags["join_date"] = join_date
	ensure_body_matches_gender()


func reset_account_state() -> void:
	player_name = "Player"
	player_id = ""
	gender = "male"
	is_staff = false
	party = []
	money = 0
	bank_money = 0
	gems = 0
	aetherite = 0
	battle_points = 0
	playtime_seconds = 0
	flags = {}
	earned_gym_badges.clear()
	appearance_body_id = CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	appearance_hair_id = CharacterAppearanceService.DEFAULT_MALE_HAIR_ID
	appearance_headgear_id = CharacterAppearanceService.DEFAULT_MALE_HEADGEAR_ID
	appearance_facial_hair_id = ""
	appearance_facegear_id = ""
	appearance_top_id = CharacterAppearanceService.DEFAULT_MALE_TOP_ID
	appearance_bottom_id = CharacterAppearanceService.DEFAULT_MALE_BOTTOM_ID
	appearance_shoes_id = CharacterAppearanceService.DEFAULT_MALE_SHOES_ID
	appearance_hair_color = CharacterAppearanceService.resolve_hair_color("", gender)
	appearance_skin_tone = CharacterAppearanceService.DEFAULT_SKIN_TONE
	appearance_eye_color = CharacterAppearanceService.resolve_eye_color("", gender)
	appearance_facegear_color = "#ffffff"
	appearance_facial_hair_color = "#ffffff"
	appearance_top_color = "#ffffff"
	appearance_bottom_color = "#ffffff"
	appearance_shoes_color = "#ffffff"
	appearance_hair_style_index = 0
	ensure_body_matches_gender(true)
	party_changed.emit()
	gym_badges_changed.emit()


func _user_has_staff_role(user: Dictionary) -> bool:
	var roles_value: Variant = user.get("roles", [])
	if not roles_value is Array:
		return false
	for role_value: Variant in roles_value as Array:
		if not role_value is Dictionary:
			continue
		var role: Dictionary = role_value as Dictionary
		var role_id := str(role.get("id", "")).strip_edges().to_lower()
		var category := str(role.get("category", "")).strip_edges().to_lower()
		if category == "staff" or role_id in [
			"owner",
			"senior_staff",
			"admin",
			"developer",
			"gamemaster",
			"moderator",
		]:
			return true
	return false


func reset_gameplay_progress() -> void:
	var join_date: Variant = flags.get("join_date", null)
	party = []
	money = 0
	bank_money = 0
	aetherite = 0
	battle_points = 0
	playtime_seconds = 0
	flags = {}
	earned_gym_badges.clear()
	if join_date != null:
		flags["join_date"] = join_date

	appearance_body_id = (
		CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID
		if gender == "female"
		else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	)
	appearance_hair_id = CharacterAppearanceService.get_default_part_id("hair", gender)
	appearance_headgear_id = CharacterAppearanceService.get_default_part_id("headgear", gender)
	appearance_facial_hair_id = ""
	appearance_facegear_id = ""
	appearance_top_id = CharacterAppearanceService.get_default_part_id("top", gender)
	appearance_bottom_id = CharacterAppearanceService.get_default_part_id("bottom", gender)
	appearance_shoes_id = CharacterAppearanceService.get_default_part_id("shoes", gender)
	appearance_hair_color = CharacterAppearanceService.resolve_hair_color("", gender)
	appearance_skin_tone = CharacterAppearanceService.DEFAULT_SKIN_TONE
	appearance_eye_color = CharacterAppearanceService.resolve_eye_color("", gender)
	appearance_facegear_color = "#ffffff"
	appearance_facial_hair_color = "#ffffff"
	appearance_top_color = "#ffffff"
	appearance_bottom_color = "#ffffff"
	appearance_shoes_color = "#ffffff"
	appearance_hair_style_index = 0
	ensure_body_matches_gender(true)
	party_changed.emit()
	gym_badges_changed.emit()


func apply_gym_badge_state(state: Dictionary) -> void:
	var badge_keys: Array[String] = []
	var badge_values: Variant = state.get("badges", [])
	if badge_values is Array:
		for badge_value: Variant in badge_values:
			if not (badge_value is Dictionary):
				continue
			var badge: Dictionary = badge_value as Dictionary
			if not bool(badge.get("earned", false)):
				continue
			var region := str(badge.get("region", "")).strip_edges().to_lower()
			var badge_id := str(badge.get("badgeId", badge.get("id", ""))).strip_edges().to_lower()
			if region == "" or badge_id == "":
				continue
			var badge_key := "%s:%s" % [region, badge_id]
			if badge_key not in badge_keys:
				badge_keys.append(badge_key)
	earned_gym_badges = badge_keys
	gym_badges_changed.emit()


func has_gym_badge(region: String, badge_id: String) -> bool:
	var badge_key := "%s:%s" % [
		region.strip_edges().to_lower(),
		badge_id.strip_edges().to_lower(),
	]
	return badge_key in earned_gym_badges


func gym_badge_count() -> int:
	return earned_gym_badges.size()


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


func get_first_usable_party_slot() -> int:
	for index in range(party.size()):
		var pokemon: Pokemon = party[index] as Pokemon
		if pokemon == null or pokemon.species.strip_edges() == "":
			continue
		if pokemon.has_saved_hp_state and pokemon.current_hp <= 0:
			continue
		return index + 1

	return -1

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
		"facial_hair": CharacterAppearanceService.serialize_part_id(appearance_facial_hair_id),
		"facegear": CharacterAppearanceService.serialize_part_id(appearance_facegear_id),
		"top": CharacterAppearanceService.serialize_part_id(appearance_top_id),
		"bottom": CharacterAppearanceService.serialize_part_id(appearance_bottom_id),
		"shoes": CharacterAppearanceService.serialize_part_id(appearance_shoes_id),
		"legs": CharacterAppearanceService.serialize_part_id(appearance_bottom_id),
		"feet": CharacterAppearanceService.serialize_part_id(appearance_shoes_id),
		"hair_color": appearance_hair_color,
		"skin_tone": appearance_skin_tone,
		"eye_color": appearance_eye_color,
		"facegear_color": appearance_facegear_color,
		"facial_hair_color": appearance_facial_hair_color,
		"top_color": appearance_top_color,
		"bottom_color": appearance_bottom_color,
		"shoes_color": appearance_shoes_color,
	}

func apply_appearance_state(appearance_state: Dictionary) -> void:
	var decoded_body_appearance: Dictionary = CharacterAppearanceService.decode_presence_body_appearance(str(appearance_state.get("body", "")))
	if not decoded_body_appearance.is_empty():
		var merged_appearance_state: Dictionary = appearance_state.duplicate()
		for key: Variant in decoded_body_appearance.keys():
			merged_appearance_state[key] = decoded_body_appearance[key]
		appearance_state = merged_appearance_state

	var previous_body_id := appearance_body_id
	var body_id := CharacterAppearanceService.normalize_legacy_optional_text(
		appearance_state.get("body", "")
	)
	var source_body_id := previous_body_id
	if body_id != "":
		source_body_id = CharacterAppearanceService.get_presence_body_base_id(body_id)
		appearance_body_id = CharacterAppearanceService.resolve_body_model_id(source_body_id, gender)

	appearance_hair_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("hair", appearance_hair_id)))
	if appearance_state.has("hair_style_index"):
		appearance_hair_style_index = max(int(appearance_state.get("hair_style_index", appearance_hair_style_index)), 0)
	appearance_headgear_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("headgear", appearance_headgear_id)))
	appearance_facial_hair_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("facial_hair", appearance_facial_hair_id)))
	appearance_facegear_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("facegear", appearance_facegear_id)))
	appearance_top_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("top", appearance_top_id)))
	appearance_bottom_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("bottom", appearance_state.get("legs", appearance_bottom_id))))
	appearance_shoes_id = CharacterAppearanceService.deserialize_part_id(str(appearance_state.get("shoes", appearance_state.get("feet", appearance_shoes_id))))
	appearance_hair_color = CharacterAppearanceService.resolve_hair_color(
		str(appearance_state.get("hair_color", appearance_hair_color)),
		gender
	)
	appearance_skin_tone = CharacterAppearanceService.resolve_skin_tone(
		source_body_id,
		str(appearance_state.get("skin_tone", appearance_skin_tone)),
		gender
	)
	appearance_eye_color = CharacterAppearanceService.resolve_eye_color(
		str(appearance_state.get("eye_color", appearance_eye_color)),
		gender
	)
	appearance_facegear_color = _resolve_optional_chroma_color(
		appearance_state.get("facegear_color", appearance_facegear_color)
	)
	appearance_facial_hair_color = _resolve_optional_chroma_color(
		appearance_state.get("facial_hair_color", appearance_facial_hair_color)
	)
	appearance_top_color = _resolve_optional_chroma_color(
		appearance_state.get("top_color", appearance_top_color)
	)
	appearance_bottom_color = _resolve_optional_chroma_color(
		appearance_state.get("bottom_color", appearance_bottom_color)
	)
	appearance_shoes_color = _resolve_optional_chroma_color(
		appearance_state.get("shoes_color", appearance_shoes_color)
	)
	if appearance_state.has("hair"):
		if appearance_hair_id != "":
			sync_hair_style_index_from_id()
	elif appearance_state.has("hair_style_index"):
		apply_hair_style_index_to_id()
	ensure_body_matches_gender(false)


func _resolve_optional_chroma_color(value: Variant) -> String:
	var normalized_color := CharacterAppearanceService.normalize_legacy_optional_text(value)
	return "#ffffff" if normalized_color == "" else normalized_color


func ensure_body_matches_gender(fill_empty_parts: bool = true) -> void:
	var source_body_id := appearance_body_id
	appearance_skin_tone = CharacterAppearanceService.resolve_skin_tone(
		source_body_id,
		appearance_skin_tone,
		gender
	)
	appearance_body_id = CharacterAppearanceService.resolve_body_model_id(source_body_id, gender)
	var body_ids: Array[String] = CharacterAppearanceService.get_available_body_model_ids(gender)
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
	appearance_hair_color = CharacterAppearanceService.resolve_hair_color(appearance_hair_color, gender)
	appearance_skin_tone = CharacterAppearanceService.resolve_skin_tone(
		appearance_body_id,
		appearance_skin_tone,
		gender
	)
	appearance_eye_color = CharacterAppearanceService.resolve_eye_color(appearance_eye_color, gender)
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
		var owned_pokemon_id := int(pokemon_data.get("ownedPokemonId", pokemon_data.get("owned_pokemon_id", 0)))
		if owned_pokemon_id > 0:
			for saved_pokemon: Pokemon in party:
				if saved_pokemon.owned_pokemon_id == owned_pokemon_id:
					pokemon = saved_pokemon
					break
			if pokemon == null or (instance_id != "" and pokemon.instance_id != instance_id):
				continue
		elif instance_id != "":
			# An explicit foreign identity must never fall back to slot/species.
			pokemon = party_by_instance_id.get(instance_id) as Pokemon
		else:
			pokemon = _find_party_pokemon_for_team_entry(pokemon_data, used_fallback_instances)
		if pokemon == null:
			continue

		if instance_id != "":
			used_fallback_instances[instance_id] = true
		else:
			used_fallback_instances[pokemon.instance_id] = true
		var hp_data := _get_battle_hp_data(pokemon_data)
		var status := _get_battle_status(pokemon_data)
		if hp_data.is_empty() and status == "" and not _has_battle_move_data(pokemon_data):
			continue

		if not hp_data.is_empty():
			_apply_hp_data_to_pokemon(pokemon, hp_data)
		pokemon.status = status

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
	if not updated_moves.is_empty() and _move_sets_have_no_overlap(updated_moves, move_slots):
		push_warning(
			"PlayerSave: skipped battle move sync for %s because incoming moves do not overlap existing moves." % pokemon.species
		)
		return

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


func _move_sets_have_no_overlap(existing_moves: Array, incoming_moves: Array) -> bool:
	var existing_ids := {}
	for move_value: Variant in existing_moves:
		var move_id := _get_move_identity_key(move_value)
		if move_id != "":
			existing_ids[move_id] = true

	if existing_ids.is_empty():
		return false

	var has_incoming_move := false
	for move_value: Variant in incoming_moves:
		var move_id := _get_move_identity_key(move_value)
		if move_id == "":
			continue
		has_incoming_move = true
		if existing_ids.has(move_id):
			return false

	return has_incoming_move


func _get_move_identity_key(move_value: Variant) -> String:
	var raw_value := ""
	if move_value is Dictionary:
		var move_data: Dictionary = move_value as Dictionary
		raw_value = str(move_data.get("id", move_data.get("name", move_data.get("move", ""))))
	else:
		raw_value = str(move_value)

	return raw_value.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")

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

func _get_battle_status(pokemon_data: Dictionary) -> String:
	var direct_status := _normalize_battle_status(str(pokemon_data.get("status", "")))
	if direct_status != "":
		return direct_status

	var condition := str(pokemon_data.get("condition", "")).strip_edges()
	for part_value: String in condition.split(" ", false):
		var status := _normalize_battle_status(part_value)
		if status != "":
			return status

	return ""

func _normalize_battle_status(value: String) -> String:
	match value.strip_edges().to_lower():
		"psn", "poison", "poisoned":
			return "psn"
		"tox", "toxic", "badly_poisoned", "badlypoisoned":
			return "tox"
		"brn", "burn", "burned":
			return "brn"
		"par", "paralysis", "paralyzed":
			return "par"
		"slp", "sleep", "sleeping", "asleep":
			return "slp"
		"frz", "freeze", "frozen":
			return "frz"

	return ""
