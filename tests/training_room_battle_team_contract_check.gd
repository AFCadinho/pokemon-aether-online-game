extends SceneTree

const TRAINING_TEAM_CONTEXT := preload("res://scripts/battle/battle_training_team_context.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const AI5_RESEARCH_MARKER_PATH := "res://scripts/battle/battle_ui/ai5_research_marker.gd"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const TRAINER_CATALOG_PATH := "res://data/npc_portraits/showdown_trainer_catalog.json"
const AI_VETERAN_TEXTURE_PATH := "res://assets/sprites/trainer_cards/showdown/veteran-gen7.png"

var failed := false


func _init() -> void:
	_check_private_team_is_the_only_canonical_roster()
	_check_private_details_survive_battle_state_updates()
	_check_duplicate_species_keep_their_declared_slots()
	_check_battle_controller_isolates_training_from_player_save()
	_check_level_five_training_ai_uses_the_same_isolation_boundary()
	_check_ai5_playtest_uses_server_assignments_and_separate_consent()
	_check_room_requests_advertise_durable_timer_contracts()
	quit(1 if failed else 0)


func _check_private_team_is_the_only_canonical_roster() -> void:
	var account_party := [
		{"species": "Weedle"},
		{"species": "Weedle"},
		{"species": "Weedle"},
	]
	var private_team := [
		{"species": "Garchomp", "nature": "Jolly"},
		{"species": "Lopunny", "nature": "Adamant"},
	]
	var roster := TRAINING_TEAM_CONTEXT.build_canonical_roster(private_team, "p1")

	_check(account_party.size() == 3, "test fixture contains the unrelated account Weedles")
	_check(roster.size() == 2, "Training Room roster uses the submitted private team size")
	_check(str(roster[0].get("species")) == "Garchomp", "Training Room slot one comes from Pokepaste")
	_check(str(roster[1].get("species")) == "Lopunny", "Training Room slot two comes from Pokepaste")
	_check(not roster.any(func(entry: Dictionary) -> bool: return entry.get("species") == "Weedle"), "account party Pokemon cannot enter the Training Room roster")
	_check(str(roster[0].get("pokemonKey")) == "p1:slot:1", "private team receives stable canonical slot identity")


func _check_private_details_survive_battle_state_updates() -> void:
	var private_team := [{
		"species": "Garchomp",
		"nature": "Jolly",
		"ability": "Rough Skin",
		"stats": {"hp": 357, "atk": 359, "def": 226, "spa": 176, "spd": 207, "spe": 333},
		"moves": ["Earthquake", "Swords Dance", "Stealth Rock", "Outrage"],
		"moveData": [{"name": "Earthquake", "pp": 16, "maxPp": 16}],
	}]
	var roster := TRAINING_TEAM_CONTEXT.build_canonical_roster(private_team, "p1")
	var display_team := TRAINING_TEAM_CONTEXT.build_display_team(roster, [{
		"ident": "p1: Garchomp",
		"species": "Garchomp",
		"condition": "212/357",
		"hp": 212,
		"maxHp": 357,
		"active": true,
		"partySlot": 1,
	}], "p1")
	var display: Dictionary = display_team[0]

	_check(str(display.get("nature")) == "Jolly", "hover keeps the submitted nature")
	_check(str(display.get("ability")) == "Rough Skin", "hover keeps the submitted ability")
	_check((display.get("stats") as Dictionary).get("spe") == 333, "hover keeps calculated Pokepaste stats")
	_check((display.get("moves") as Array).size() == 4, "hover keeps all submitted moves")
	_check(int(display.get("hp")) == 212 and bool(display.get("active")), "live HP and active state overlay the private snapshot")


func _check_duplicate_species_keep_their_declared_slots() -> void:
	var private_team := [
		{"species": "Weedle", "nature": "Jolly"},
		{"species": "Weedle", "nature": "Timid"},
	]
	var roster := TRAINING_TEAM_CONTEXT.build_canonical_roster(private_team, "p1")
	var display_team := TRAINING_TEAM_CONTEXT.build_display_team(roster, [
		{"species": "Weedle", "condition": "10/20", "partySlot": 1},
		{"species": "Weedle", "condition": "18/20", "partySlot": 2},
	], "p1")

	_check(str(display_team[0].get("nature")) == "Jolly", "first duplicate retains slot-one private metadata")
	_check(str(display_team[1].get("nature")) == "Timid", "second duplicate retains slot-two private metadata")
	_check(str(display_team[1].get("condition")) == "18/20", "duplicate live state resolves by canonical slot")


func _check_battle_controller_isolates_training_from_player_save() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(source.contains("pvp_battle_purpose == \"training\""), "battle controller recognizes Training Room purpose")
	_check(source.contains("display_response.get(\"ownTeam\", [])"), "battle controller captures the private imported team")
	_check(source.contains("if _is_training_room_battle():\n\t\treturn null"), "Training Room display cannot fall back to PlayerSave Pokemon")
	_check(source.contains("and not _is_training_room_battle():\n\t\t\t_heal_local_party_after_pvp_battle()"), "Training Room completion does not heal or persist the account party")
	_check(source.contains("func _sync_player_save_party_status_from_battle_state() -> void:\n\tif _is_training_room_battle():\n\t\treturn"), "Training Room responses cannot write HP or status into PlayerSave")
	_check(source.contains("func _sync_player_save_from_battle_state() -> void:\n\tif _is_training_room_battle():\n\t\treturn"), "Training battle render events cannot replace the saved party with an imported team")
	_check(source.contains("var skip_party_battle_sync := (\n\t\t_is_training_room_battle()"), "Training battle completion cannot save imported party or happiness state")


func _check_level_five_training_ai_uses_the_same_isolation_boundary() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var api_source := FileAccess.get_file_as_string(BATTLE_API_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	var trainer_catalog_source := FileAccess.get_file_as_string(TRAINER_CATALOG_PATH)
	_check(
		battle_source.contains("return training_ai_battle or (_is_pvp_battle() and pvp_battle_purpose == \"training\")"),
		"AI5 battles inherit every Training Room party-persistence safeguard"
	)
	_check(
		battle_source.contains("if training_ai_battle:\n\t\tpvp_battle_purpose = \"training\"\n\t\t_capture_pvp_local_canonical_roster(api_response)"),
		"AI training captures the imported private team before rendering its party rails"
	)
	_check(
		battle_source.contains("if _is_training_room_battle():\n\t\treturn _get_lead_selection_team_data(\"p1\")")
		and battle_source.contains("var selected_player_pokemon := _get_selected_trainer_player_pokemon()"),
		"AI training selects and renders its lead from the imported team instead of PlayerSave"
	)
	var roster_capture_start := battle_source.find("func _capture_pvp_local_canonical_roster")
	var roster_capture_end := battle_source.find("func _get_selected_trainer_player_pokemon", roster_capture_start)
	var roster_capture_source := battle_source.substr(
		roster_capture_start,
		roster_capture_end - roster_capture_start
	)
	_check(
		roster_capture_source.contains("\t\treturn\n\n\tfor index in range(PlayerSave.party.size())"),
		"Training rosters cannot append account-party Pokemon after the imported team"
	)
	_check(
		api_source.contains("/battle/pvp/training/ai/battles")
		and api_source.contains("\"teamId\": ai_team_id")
		and api_source.contains("\"aiMode\": ai_mode")
		and api_source.contains("\"archetype\": ai_archetype"),
		"AI creation sends the mode, archetype and selected stable team identity"
	)
	_check(
		overlay_source.contains("_selected_pvp_training_ai_team_id()")
		and overlay_source.contains("_selected_pvp_training_ai_mode()")
		and overlay_source.contains("_selected_pvp_training_ai_archetype()")
		and overlay_source.contains("ui.pvp.training.ai.team_random"),
		"Training Room exposes server-backed AI mode, archetype and team selectors"
	)
	_check(
		world_source.contains("active_battle_kind = \"training_ai\"")
		and world_source.contains("response.get(\"trainerName\", \"AI Level 5\")")
		and world_source.contains("\"_battle_sprite_id\": \"showdown_veteran_gen7\"")
		and world_source.contains("battle_environment_id,\n\t\ttrue"),
		"World starts the selected AI mode as a non-rewarding Veteran training battle"
	)
	_check(
		FileAccess.file_exists(AI_VETERAN_TEXTURE_PATH)
		and trainer_catalog_source.contains("\"id\": \"showdown_veteran_gen7\"")
		and trainer_catalog_source.contains(AI_VETERAN_TEXTURE_PATH),
		"AI5 Veteran identity resolves to an existing Showdown catalog texture"
	)


func _check_ai5_playtest_uses_server_assignments_and_separate_consent() -> void:
	var api_source := FileAccess.get_file_as_string(BATTLE_API_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var marker_source := FileAccess.get_file_as_string(AI5_RESEARCH_MARKER_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(
		api_source.contains("/battle/pvp/training/ai/playtest/battles")
		and api_source.contains("\"consentAcknowledged\": consent_acknowledged")
		and not api_source.contains("create_ai5_playtest_battle(\n\trequest_node: HTTPRequest,\n\tplayer: Dictionary,\n\tteam_text"),
		"AI5 research sends explicit consent and cannot submit a player-authored team"
	)
	_check(
		overlay_source.contains("_create_pvp_ai_sparring_tab")
		and overlay_source.contains("pvp_ai5_playtest_tabs")
		and overlay_source.contains("pvp_ai5_playtest_start_button")
		and overlay_source.contains("nextAssignment")
		and overlay_source.contains("completedBattles")
		and battle_source.contains("flag_ai5_playtest_turn")
		and marker_source.contains("note_input"),
		"AI5 research shows assignments and statistics, with live categorized turn notes in battle"
	)


func _check_room_requests_advertise_durable_timer_contracts() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_API_PATH)
	_check(source.count("\"timerContractVersions\": [1]") >= 3, "room create, room join, and Ranked advertise timer contract v1")
	_check(source.count("\"decisionContractVersions\": [1]") >= 3, "room create and join advertise decision contract v1")
	_check(source.count("\"battleCommandContractVersions\": [1]") >= 3, "room create and join advertise command contract v1")
	_check(source.contains("\"timerTierId\": timer_tier_id"), "room creation sends the selected default timer tier")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
