extends SceneTree

const TRAINING_TEAM_CONTEXT := preload("res://scripts/battle/battle_training_team_context.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"

var failed := false


func _init() -> void:
	_check_private_team_is_the_only_canonical_roster()
	_check_private_details_survive_battle_state_updates()
	_check_duplicate_species_keep_their_declared_slots()
	_check_battle_controller_isolates_training_from_player_save()
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
