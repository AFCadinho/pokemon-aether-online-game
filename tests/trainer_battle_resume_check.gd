extends Node

const BattleScene := preload("res://scenes/battle/battle.tscn")
const Factory := preload("res://scripts/data/pokemon_factory.gd")
var failed := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var pokemon := Factory.create_pokemon_from_backend_payload({"species": "Pikachu", "level": 25, "condition": "100/100", "moves": ["Thunderbolt"]})
	var battle = BattleScene.instantiate()
	add_child(battle)
	var snapshot := {
		"success": true, "battleId": "trainer-resume-fixture", "eventSeq": 41,
		"state": {"turn": 7, "ended": false},
		"decisions": {"p1": {"status": "ACTIVE", "decisionId": "original-choice", "decisionGeneration": 7, "kind": "move"}},
		"requests": {
			"p1": {"side": {"pokemon": [{"ident": "p1: Pikachu", "species": "Pikachu", "active": true, "metadataSlot": 1, "condition": "37/100 par", "hp": 37, "maxHp": 100}]}, "active": [{"moves": [{"move": "Thunderbolt", "id": "thunderbolt", "pp": 3, "maxpp": 15}]}]},
			"p2": {"wait": true, "side": {"pokemon": [{"ident": "p2: Eevee", "species": "Eevee", "active": true, "metadataSlot": 1, "condition": "60/100", "hp": 60, "maxHp": 100}]}},
		},
		"trainerTeam": [
			{"species": "Eevee", "level": 25, "metadataSlot": 1, "ident": "p2: Eevee"},
			{"species": "Charmander", "level": 25, "metadataSlot": 2, "ident": "p2: Charmander"},
		],
		"events": [
			{"type": "turn", "turn": 1, "eventSeq": 1},
			{"type": "switch", "target": "p2a: Charmander", "pokemonKey": "p2:slot:2", "metadataSlot": 2, "eventSeq": 2},
			{"type": "damage", "target": "p1a: Pikachu", "hp": 1, "maxHp": 100, "condition": "1/100", "eventSeq": 40},
		],
	}
	var resumed: bool = await battle.resume_trainer_battle_from_response(pokemon, {"name": "Resume Fixture"}, snapshot)
	_check(resumed and battle.battle_actions_ready, "resumed battle accepts input")
	_check(battle.last_rendered_event_seq == 41, "snapshot establishes the event cursor")
	_check(battle.battle_state.get_active_player_pokemon("p1").get("condition") == "37/100 par", "old damage is not replayed over current HP/status")
	_check(battle.battle_state.get_active_decision("p1").get("decisionId") == "original-choice", "original decision survives resume")
	_check(battle.battle_state.requests.p1.active[0].moves[0].pp == 3, "remaining PP survives resume")
	_check(not battle.battle_log_panel.log_buffer.is_empty(), "battle log is restored without replaying old events")
	_check(bool(battle.opponent_party_reveal_policy.revealed_slots.get(1, false)), "current active trainer Pokemon stays visible after resume")
	_check(bool(battle.opponent_party_reveal_policy.revealed_slots.get(2, false)), "previously switched trainer Pokemon stays visible after resume")
	snapshot.requests.p1["forceSwitch"] = [true]
	snapshot.requests.p1.erase("active")
	snapshot.decisions.p1["decisionKind"] = "FORCED_SWITCH"
	resumed = await battle.resume_trainer_battle_from_response(pokemon, {"name": "Resume Fixture"}, snapshot)
	_check(resumed and battle._local_player_needs_force_switch_ui(), "forced replacement remains available after resume")
	await get_tree().create_timer(0.5).timeout
	battle.queue_free()
	await get_tree().process_frame
	print("PASS trainer_battle_resume_check" if not failed else "FAIL trainer_battle_resume_check")
	get_tree().quit.call_deferred(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
