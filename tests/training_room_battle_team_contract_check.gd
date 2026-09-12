extends SceneTree

const TRAINING_TEAM_CONTEXT := preload("res://scripts/battle/battle_training_team_context.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const TRAINER_CATALOG_PATH := "res://data/npc_portraits/showdown_trainer_catalog.json"
const AI_VETERAN_TEXTURE_PATH := "res://assets/sprites/trainer_cards/showdown/veteran-gen7.png"

var failed := false


func _init() -> void:
	_check_private_team_is_the_only_canonical_roster()
	_check_private_details_survive_battle_state_updates()
	_check_duplicate_species_keep_their_declared_slots()
	_check_training_switches_preserve_canonical_slots()
	_check_battle_controller_isolates_training_from_player_save()
	_check_level_five_training_ai_uses_the_same_isolation_boundary()
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


func _check_training_switches_preserve_canonical_slots() -> void:
	var selected_raging_bolt := {
		"species": "Raging Bolt",
		"canonicalPartySlot": 1,
		"partySlot": 1,
		"pokemonKey": "p1:slot:1",
	}
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(
		TRAINING_TEAM_CONTEXT.get_canonical_slot(selected_raging_bolt) == 1,
		"Training AI switch submission preserves the imported-team slot identity"
	)
	_check(
		not battle_source.contains("resolve_mechanical_switch_slot"),
		"Training AI switch submission leaves canonical-to-request translation to the backend"
	)
	var capture_start := battle_source.find("func _capture_pvp_local_canonical_roster(")
	var capture_end := battle_source.find("\nfunc ", capture_start + 1)
	var capture_source := battle_source.substr(capture_start, capture_end - capture_start)
	_check(
		capture_source.contains("\t\treturn\n\n\tfor index in range(PlayerSave.party.size()):"),
		"Training AI canonical roster stops before account-party slots are appended"
	)
	_check(
		capture_source.contains("if _is_spectator_battle():\n\t\treturn\n\tif _is_training_room_battle():"),
		"Training spectators never require the participant's private Pokepaste"
	)


func _check_battle_controller_isolates_training_from_player_save() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(source.contains("pvp_battle_purpose == \"training\""), "battle controller recognizes Training Room purpose")
	_check(source.contains("display_response.get(\"ownTeam\", [])"), "battle controller captures the private imported team")
	_check(
		source.contains("if display_name_uses_default_ident:")
		and source.contains("event_text_formatter.resolve_pokemon_display_name("),
		"Training Room HUD resolves an unnicknamed base ident to the complete battle form name"
	)
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
		and api_source.contains("\"aiTeamText\": ai_team_text.strip_edges()")
		and api_source.contains("func clear_training_ai_match_history")
		and api_source.contains("\"aiMode\": ai_mode")
		and api_source.contains("ai_mode in [\"ai4\", \"shadow\", \"intermediate\", \"active\", \"elite\", \"nightmare\"]")
		and not api_source.contains("\"expert\"")
		and api_source.contains('"archetype": ai_archetype if ai_archetype.strip_edges() != "" else "random"')
		and api_source.contains('"tierId": normalized_tier_id')
		and overlay_source.contains("_selected_ai_sparring_tier_id()"),
		"AI creation sends the tier, mode, archetype and selected stable team identity"
	)
	_check(
		not api_source.contains("/training/ai/playtest")
		and not battle_source.contains("ai5_research")
		and not overlay_source.contains("ai5_playtest"),
		"Retired AI5 Research Campaign routes, markers and interface are absent"
	)
	_check(
		overlay_source.contains("_resolved_pvp_training_ai_team_id()")
		and overlay_source.contains("_selected_pvp_training_ai_team_source()")
		and overlay_source.contains("ui.pvp.training.ai.team_source_paste")
		and overlay_source.contains("_on_pvp_ai_sparring_history_clear_pressed")
		and overlay_source.contains("ui.pvp.ai_sparring.history.clear_message")
		and overlay_source.contains("_selected_pvp_training_ai_mode()")
		and overlay_source.contains("_selected_pvp_training_ai_archetype()")
		and overlay_source.contains("if \"ai4\" in raw_modes:")
		and overlay_source.contains("elif \"shadow\" in raw_modes:")
		and overlay_source.contains("ui.pvp.training.ai.team_random"),
		"Training Room prefers plain AI4 while retaining safe legacy-server compatibility"
	)
	_check(
		world_source.contains("active_battle_kind = \"training_ai\"")
		and world_source.contains("var trainer_name := _training_ai_battle_display_name(response)")
		and world_source.contains("\"_battle_sprite_id\": _training_ai_battle_sprite_id(response)")
		and world_source.contains("battle_environment_id,\n\t\ttrue"),
		"World starts the selected AI mode as a non-rewarding training battle with mode-specific art"
	)
	var helper_start := world_source.find("func _training_ai_battle_sprite_id(")
	var helper_end := world_source.find("\nfunc ", helper_start + 1)
	var helper := GDScript.new()
	helper.source_code = "extends RefCounted\n" + world_source.substr(helper_start, helper_end - helper_start)
	_check(helper.reload() == OK, "Sparring sprite selector compiles")
	var selector: RefCounted = helper.new()
	for mode: String in ["ai4", "shadow", "active", "intermediate", "elite", "nightmare"]:
		var expected := "showdown_scientist_gen7" if mode in ["ai4", "shadow"] else "showdown_veteran_gen7"
		_check(selector.call("_training_ai_battle_sprite_id", {"trainingAiMode": mode, "aiLevel": 5}) == expected, "Server mode selects the correct trainer: " + mode)
	_check(selector.call("_training_ai_battle_sprite_id", {"aiLevel": 4}) == "showdown_scientist_gen7", "Legacy AI4 response keeps Scholar art")
	var name_helper_start := world_source.find("func _training_ai_battle_display_name(")
	var name_helper_end := world_source.find("\nfunc ", name_helper_start + 1)
	var name_helper := GDScript.new()
	name_helper.source_code = "extends RefCounted\n" + world_source.substr(name_helper_start, name_helper_end - name_helper_start)
	_check(name_helper.reload() == OK, "Sparring display-name selector compiles")
	var name_selector: RefCounted = name_helper.new()
	_check(name_selector.call("_training_ai_battle_display_name", {"trainingAiMode": "ai4", "trainerName": "AI Level 4"}) == "Scholar", "Legacy AI4 names display as Scholar")
	_check(name_selector.call("_training_ai_battle_display_name", {"trainingAiMode": "active", "trainerName": "AI Level 5"}) == "Grandmaster Hard", "Legacy AI5 names display as Grandmaster Hard")
	_check(name_selector.call("_training_ai_battle_display_name", {"trainingAiMode": "intermediate"}) == "Grandmaster Intermediate", "Intermediate displays its Grandmaster difficulty")
	_check(name_selector.call("_training_ai_battle_display_name", {"trainingAiMode": "elite"}) == "Grandmaster Elite", "Elite displays its Grandmaster difficulty")
	_check(name_selector.call("_training_ai_battle_display_name", {"trainingAiMode": "nightmare"}) == "Grandmaster Nightmare", "Nightmare displays its Grandmaster difficulty")
	_check(trainer_catalog_source.contains('"id": "showdown_scientist_gen7"'), "Scholar battle art exists in the catalog")
	_check(
		FileAccess.file_exists(AI_VETERAN_TEXTURE_PATH)
		and trainer_catalog_source.contains("\"id\": \"showdown_veteran_gen7\"")
		and trainer_catalog_source.contains(AI_VETERAN_TEXTURE_PATH),
		"AI5 Veteran identity resolves to an existing Showdown catalog texture"
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
