extends SceneTree

const BATTLE_API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"
const BATTLE_PATH := "res://scripts/battle/battle.gd"
const HOVER_SERVICE_PATH := "res://scripts/battle/battle_pokemon_hover_service.gd"
const REALTIME_PATH := "res://scripts/services/pvp_battle_realtime_service.gd"
const PublicPokemonKnowledge := preload("res://scripts/battle/battle_public_pokemon_knowledge.gd")


func _init() -> void:
	var api_source := FileAccess.get_file_as_string(BATTLE_API_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	var hover_service_source := FileAccess.get_file_as_string(HOVER_SERVICE_PATH)
	var realtime_source := FileAccess.get_file_as_string(REALTIME_PATH)

	_check(
		not api_source.contains('"/battle/pvp/rooms/%s?playerId='),
		"room reads do not let the client select a participant side"
	)
	_check(
		not api_source.contains('?viewerId=%s&ident=%s'),
		"Pokemon knowledge reads do not let the client select a viewer"
	)
	var damage_payload_start := api_source.find("func _build_damage_calc_payload(")
	var damage_payload_end := api_source.find("\nfunc ", damage_payload_start + 1)
	var damage_payload_source := api_source.substr(
		damage_payload_start,
		damage_payload_end - damage_payload_start
	)
	_check(
		not damage_payload_source.contains('"viewerId"'),
		"damage calculation authority comes from the authenticated session"
	)
	_check(
		realtime_source.contains('if message_type == "pvp.choice_confirmed":') \
			and realtime_source.contains("_apply_timer_projection_from_battle_response(message)"),
		"a public opponent confirmation can still change the battle timer to Waiting"
	)
	var embedded_knowledge := PublicPokemonKnowledge.from_pokemon_data({
		"ident": "p2: Tapu Koko",
		"moves": [{"name": "Hidden Power"}],
		"knowledge": {
			"confirmedMoves": [
				{"name": "Volt Switch", "pp": 19.0, "maxpp": 20.0, "private": "hidden"},
			],
			"confirmedAbility": "Electric Surge",
			"statChanges": {"spe": 1.0, "atk": 1.5},
			"privateSet": {"item": "Choice Specs"},
		},
	})
	_check(
		embedded_knowledge.get("confirmedMoves", []) == [
			{"name": "Volt Switch", "pp": 19, "maxpp": 20},
		],
		"side-preview hover keeps only server-confirmed public moves"
	)
	_check(
		str(embedded_knowledge.get("confirmedAbility", "")) == "Electric Surge",
		"side-preview hover keeps a confirmed public ability"
	)
	_check(
		embedded_knowledge.get("statChanges", {}) == {"spe": 1},
		"side-preview hover accepts integral JSON numbers and rejects fractions"
	)
	var pressure_pp_hover := PublicPokemonKnowledge.with_max_pp_assumption([
		{"name": "Thunderbolt", "pp": 13, "maxpp": 15},
	])
	_check(
		pressure_pp_hover == [
			{"name": "Thunderbolt", "pp": 22, "maxpp": 24},
		],
		"side-preview hover preserves Pressure's two-PP use with the max-PP display assumption"
	)
	_check(
		not embedded_knowledge.has("privateSet") \
			and not JSON.stringify(embedded_knowledge).contains("Hidden Power") \
			and not JSON.stringify(embedded_knowledge).contains("Choice Specs"),
		"side-preview hover cannot consume unconfirmed set data"
	)
	_check(
		battle_source.contains("public_confirmed_only\n\t)") \
			and hover_service_source.contains("var pokemon_info: Dictionary = await _fetch_hover_pokemon_info(") \
			and hover_service_source.contains("PublicPokemonKnowledge.from_pokemon_data(pokemon_data)"),
		"public side-preview uses server-confirmed knowledge with a sanitized embedded fallback"
	)
	var item_reveal := PublicPokemonKnowledge.confirmed_item_reveal_from_event({
		"type": "pokemonEffect",
		"target": "p2a: Great Tusk",
		"effect": "item: Protective Pads",
		"state": "activate",
	})
	_check(
		item_reveal == {
			"ident": "p2a: Great Tusk",
			"item": "Protective Pads",
		},
		"direct item activations are retained for subsequent hover cards"
	)
	print("PASS battle_participant_privacy_contract_check")
	quit(0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)
