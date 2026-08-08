extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

const ALPHA_APPEARANCE := {
	"gender": "male",
	"body": "Gen4_Base_v1",
	"hair": "Adinho_Hair",
	"facial_hair": "Adinho_Beard",
	"skin_tone": "#f8d0b8",
	"hair_color": "#9b5a2e",
	"facial_hair_color": "#6b321d",
	"eye_color": "#2774d8",
}
const BRAVO_APPEARANCE := {
	"gender": "female",
	"body": "Gen4_Base_v2",
	"hair": "Caitlin_Hair",
	"skin_tone": "#3f271f",
	"hair_color": "#d7c06c",
	"eye_color": "#56b86c",
}

var failed := false


func _ready() -> void:
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await get_tree().process_frame

	var canonical_snapshot := _build_snapshot()
	battle.battle_type = 1 # BattleType.TRAINER
	battle.pvp_room_code = "spectator-test"
	battle.pvp_viewer_role = "spectator"
	battle.action_flow.set_local_player_id("p1")
	battle.spectator_latest_raw_response = canonical_snapshot.duplicate(true)
	battle.battle_state.load_from_api_response(canonical_snapshot, false)
	battle._show_pvp_trainers(canonical_snapshot)
	battle._update_battle_presentation("snapshot_reconciliation")
	await get_tree().process_frame

	_check_side_identities(
		battle,
		"Alpha", ALPHA_APPEARANCE, "Bravo", BRAVO_APPEARANCE,
		"Pikachu", "Eevee", "initial"
	)
	battle.player_trainer_sprite.show_command("Alpha command")
	battle.enemy_trainer_sprite.show_command("Bravo command")

	battle._on_spectator_switch_sides_pressed()
	await get_tree().process_frame

	_check(battle.action_flow.local_player_id == "p2", "spectator perspective maps canonical p2 to the left side")
	_check_side_identities(
		battle,
		"Bravo", BRAVO_APPEARANCE, "Alpha", ALPHA_APPEARANCE,
		"Eevee", "Pikachu", "swapped"
	)
	_check(not battle.player_trainer_sprite.command_callout.visible, "left trainer callout is cleared when its owner changes")
	_check(not battle.enemy_trainer_sprite.command_callout.visible, "right trainer callout is cleared when its owner changes")

	remove_child(battle)
	battle.free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)


func _build_snapshot() -> Dictionary:
	return {
		"success": true,
		"viewerRole": "spectator",
		"battleId": "spectator-identity-test",
		"players": {
			"p1": {"name": "Alpha", "appearance": ALPHA_APPEARANCE.duplicate(true)},
			"p2": {"name": "Bravo", "appearance": BRAVO_APPEARANCE.duplicate(true)},
		},
		"requests": {
			"p1": _build_request("p1", ["Pikachu", "Garchomp"]),
			"p2": _build_request("p2", ["Eevee", "Snorlax"]),
		},
		"state": {"turn": 1},
		"field": {"effects": []},
		"events": [],
		"eventBatches": [],
	}


func _build_request(player_id: String, species_list: Array[String]) -> Dictionary:
	var team: Array = []
	for species in species_list:
		team.append({
			"ident": "%sa: %s" % [player_id, species],
			"details": "%s, L50" % species,
			"species": species,
			"displaySpecies": species,
			"level": 50,
			"active": team.is_empty(),
			"condition": "100/100",
			"hp": 100,
			"maxHp": 100,
			"fainted": false,
		})
	return {
		"wait": true,
		"side": {"pokemon": team},
		"active": [{"moves": []}] if not team.is_empty() else [],
	}


func _check_side_identities(
	battle: Node,
	left_name: String,
	left_appearance: Dictionary,
	right_name: String,
	right_appearance: Dictionary,
	left_lead_species: String,
	right_lead_species: String,
	phase: String
) -> void:
	var left_stage := _stage_appearance(battle.player_trainer_sprite)
	var right_stage := _stage_appearance(battle.enemy_trainer_sprite)
	var panel := battle.vs_panel_container as BattleVsPanelContainer
	_check(left_stage.get("skin_tone") == left_appearance.get("skin_tone"), "%s left trainer avatar follows its player" % phase)
	_check(right_stage.get("skin_tone") == right_appearance.get("skin_tone"), "%s right trainer avatar follows its player" % phase)
	_check(panel.player_1_label.text == left_name, "%s left name follows its player" % phase)
	_check(panel.player_2_label.text == right_name, "%s right name follows its player" % phase)
	_check(
		panel.player_1_portrait.appearance_state.get("eye_color") == left_appearance.get("eye_color"),
		"%s left name portrait follows its player" % phase
	)
	_check(
		panel.player_2_portrait.appearance_state.get("eye_color") == right_appearance.get("eye_color"),
		"%s right name portrait follows its player" % phase
	)
	_check(
		_portrait_avatar_appearance(panel.player_1_portrait).get("eye_color") == left_appearance.get("eye_color"),
		"%s left portrait renderer follows its player" % phase
	)
	_check(
		_portrait_avatar_appearance(panel.player_2_portrait).get("eye_color") == right_appearance.get("eye_color"),
		"%s right portrait renderer follows its player" % phase
	)
	_check(
		_battle_stage_lead_species(battle.player_stage_party_grid) == left_lead_species,
		"%s left party rail follows its player" % phase
	)
	_check(
		_battle_stage_lead_species(battle.opponent_party_grid) == right_lead_species,
		"%s right party rail follows its player" % phase
	)
	_check(
		_battle_stage_lead_species(battle.player_stage_party_grid) == left_lead_species,
		"%s visible left party icons follow their player" % phase
	)
	_check(
		_battle_stage_lead_species(battle.opponent_party_grid) == right_lead_species,
		"%s visible right party icons follow their player" % phase
	)


func _battle_stage_lead_species(party_grid: PartyGrid) -> String:
	if party_grid == null or party_grid.current_party_data.is_empty():
		return ""
	var first_value: Variant = party_grid.current_party_data[0]
	return str((first_value as Dictionary).get("species", "")) if first_value is Dictionary else ""


func _portrait_avatar_appearance(portrait: TrainerHeadPortrait) -> Dictionary:
	if portrait == null or portrait.avatar == null:
		return {}
	var appearance_value: Variant = portrait.avatar.get("current_appearance_state")
	return appearance_value as Dictionary if appearance_value is Dictionary else {}


func _stage_appearance(trainer_sprite: BattleTrainerSprite) -> Dictionary:
	if trainer_sprite == null or trainer_sprite.player_avatar == null:
		return {}
	var appearance_value: Variant = trainer_sprite.player_avatar.get("current_appearance_state")
	return appearance_value as Dictionary if appearance_value is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
