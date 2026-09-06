extends Node

const BattleScript := preload("res://scripts/battle/battle.gd")
const PARTY_CARD := preload("res://scenes/battle/party_hover_card.tscn")
const POKEMON_CARD := preload("res://scenes/battle/pokemon_hover_card.tscn")
const HoverService := preload("res://scripts/battle/battle_pokemon_hover_service.gd")

class HoverBattle extends BattleScript:
	func _position_pokemon_hover_card() -> void:
		pass

class FakeHoverService extends HoverService:
	var info_calls := 0
	var info_moves: Array = [{"name": "Thunderbolt", "pp": 24, "maxpp": 24}]

	func _fetch_hover_pokemon_info(_state: BattleState, _request: HTTPRequest, _pokemon: Dictionary, _viewer := "", ident := "") -> Dictionary:
		info_calls += 1
		return {"ident": ident, "confirmedMoves": info_moves.duplicate(true)}

	func get_hover_card_data(_state: BattleState, _info: HTTPRequest, _stats: HTTPRequest, pokemon: Dictionary, _abilities: Dictionary, _items: Dictionary = {}, _viewer := "", _ident := "", _species := "", _public := false) -> Dictionary:
		return {
			"requested_ident": pokemon.get("ident", ""),
			"species_metadata": {"types": ["electric"], "possibleAbilities": ["Static"]},
			"confirmed_moves": [
				{"name": "Thunderbolt", "pp": 8, "maxpp": 24},
				{"name": "Surf", "pp": 24, "maxpp": 24},
			],
		}

var failed := false

func _ready() -> void:
	# Exercise the actual controller and cards without starting unrelated stage
	# animation systems or making network requests.
	var battle := HoverBattle.new()
	battle.party_hover_card = PARTY_CARD.instantiate()
	battle.pokemon_hover_card = POKEMON_CARD.instantiate()
	add_child(battle.party_hover_card)
	add_child(battle.pokemon_hover_card)
	var service := FakeHoverService.new()
	battle.pokemon_hover_service = service
	battle.training_ai_battle = true
	battle.action_flow.set_local_player_id("p1")
	var pokemon := {"ident": "p1: Pikachu", "species": "Pikachu", "metadataSlot": 1, "moves": ["Thunderbolt"], "active": true}
	var request := {"side": {"pokemon": [pokemon]}, "active": [{"moves": [{"move": "Thunderbolt", "pp": 7, "maxpp": 24}]}]}
	battle.battle_state.requests = {"p1": request}
	var hover: Dictionary = await battle._get_owned_party_hover_data(pokemon)
	_check(hover.moves[0].pp == 7 and hover.moves[0].maxpp == 24, "imported active party hover uses live PP")
	_check(service.info_calls == 0, "live PP needs no info request")
	battle.party_hover_card.show_for_pokemon(hover)
	var row: Node = battle.party_hover_card.move_rows[0]
	_check(row.get_node("Label").text == "7/24", "party card actually renders live PP")
	# PvP display projections may lose `active` while keeping the same battle
	# identity. The live request must still win over saved/base-PP fallback.
	var projected_active := {"ident": "p1: Pikachu", "species": "Pikachu", "metadataSlot": 1, "moves": [{"name": "Thunderbolt", "pp": 7, "maxPp": 15}]}
	var projected_hover: Dictionary = await battle._get_owned_party_hover_data(projected_active)
	_check(projected_hover.moves[0].pp == 7 and projected_hover.moves[0].maxpp == 24, "identity-matched active hover uses live PP without active flag")
	battle._remember_active_player_party_moves()
	pokemon.active = false
	request.erase("active")
	hover = await battle._get_owned_party_hover_data(pokemon)
	_check(hover.moves[0].pp == 7, "imported benched Pokemon retains cached PP after switching")
	_check(service.info_calls == 0, "cached PP needs no info request")
	battle.player_party_moves_by_key.clear()
	hover = await battle._get_owned_party_hover_data(pokemon)
	_check(hover.moves[0].pp == 24 and service.info_calls == 1, "unseen imported bench resolves PP from authenticated Pokemon info")
	service.info_moves = [{"name": "Thunderbolt", "pp": 0, "maxpp": 24}]
	hover = await battle._get_owned_party_hover_data(pokemon)
	_check(hover.moves[0].pp == 0, "info fallback preserves exhausted PP")

	# Both raw spectator perspectives are presented with a local p1 side.
	# Even if stale private data exists, spectators must only render public moves.
	battle.training_ai_battle = false
	battle.pvp_room_code = "hover-pp-test"
	battle.pvp_viewer_role = "spectator"
	for perspective: String in ["p1", "p2"]:
		battle.action_flow.set_local_player_id(perspective)
		for side: String in ["p1", "p2"]:
			var display := {"ident": side + ": Pikachu", "species": "Pikachu", "active": true, "metadataSlot": 1}
			battle.battle_state.requests[side] = {"active": [{"moves": [{"move": "Secret Move", "pp": 2, "maxpp": 15}]}]}
			battle.hover_state.set_sprite_hover_player(side)
			await battle._show_pokemon_hover(display, display, side)
			_check(battle.pokemon_hover_card.current_confirmed_moves == [{"name": "Thunderbolt", "pp": 8, "maxpp": 24}], "spectator " + perspective + " sees public PP on " + side)
			_check(battle.pokemon_hover_card.move_labels[0].text.contains("8/24"), "spectator card renders maximum-PP scale once")

	battle.pvp_viewer_role = "participant"
	battle.action_flow.set_local_player_id("p1")
	var own := {"ident": "p1: Pikachu", "species": "Pikachu", "active": true, "metadataSlot": 1}
	battle.battle_state.requests.p1 = {"active": [{"moves": [{"move": "Thunderbolt", "pp": 2, "maxpp": 15}]}]}
	battle.hover_state.set_sprite_hover_player("p1")
	await battle._show_pokemon_hover(own, own, "p1")
	_check(battle.pokemon_hover_card.current_confirmed_moves[0].pp == 2 and battle.pokemon_hover_card.current_confirmed_moves[0].maxpp == 15, "participant sprite still uses exact owned PP")
	var saved_scale_source := Pokemon.new(
		"Samurott-Hisui",
		100,
		"",
		"",
		"Jolly",
		{},
		{},
		{},
		[{"name": "Flip Turn", "pp": 20, "maxPp": 20}],
	)
	var scaled_hover_moves: Array = battle._convert_battle_moves_to_owned_hover_scale(
		[{"move": "Flip Turn", "pp": 31, "maxpp": 32}],
		saved_scale_source,
	)
	_check(scaled_hover_moves[0].pp == 19 and scaled_hover_moves[0].maxpp == 20, "owned hover translates live battle PP to saved base PP")
	battle.party_hover_card.hide_card()
	battle.pokemon_hover_card.hide_card()
	battle.party_hover_card.queue_free()
	battle.pokemon_hover_card.queue_free()
	battle.free()
	await get_tree().process_frame
	if not failed:
		print("PASS battle_hover_pp_runtime_check")
	get_tree().quit(1 if failed else 0)

func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
