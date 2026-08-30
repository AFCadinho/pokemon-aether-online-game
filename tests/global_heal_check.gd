extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const WALLET_SERVICE_PATH := "res://scripts/services/player_wallet_service.gd"
const HEAL_SERVICE_PATH := "res://scripts/services/party_heal_service.gd"
const GAME_STATE_PATH := "res://scripts/core/game_state.gd"
const LOADING_SCREEN_PATH := "res://scripts/ui/loading_screen.gd"

var failed := false


func _init() -> void:
	var overlay := FileAccess.get_file_as_string(OVERLAY_PATH)
	var scene := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var wallet_service := FileAccess.get_file_as_string(WALLET_SERVICE_PATH)
	var heal_service := FileAccess.get_file_as_string(HEAL_SERVICE_PATH)
	var game_state := FileAccess.get_file_as_string(GAME_STATE_PATH)
	var loading_screen := FileAccess.get_file_as_string(LOADING_SCREEN_PATH)

	_check(scene.contains('[node name="BuffSlot6"'), "Global Heal has a sixth global action slot after five community goals")
	_check(scene.contains('[node name="GlobalHealSection"'), "Global Heal has dedicated activation controls")
	_check(scene.contains('text = "ui.buff.global_heal.receive_requests"'), "activation controls expose the request preference")
	_check(overlay.contains('"cost": 25000'), "Global Heal defaults to the requested 25,000 price")
	_check(overlay.contains('PlayerWalletService.activate_global_heal()'), "activation uses the authoritative wallet endpoint")
	_check(
		overlay.contains('(is_global_heal and str(buff.get("state", "available")) == "cooldown")'),
		"Global Heal lights up during cooldown and stays subdued while available"
	)
	_check(overlay.contains('message_type == "system.global_heal_requested"'), "realtime Global Heal broadcasts reach the UI")
	_check(
		overlay.contains('_receive_global_heal_request(message, true)')
			and overlay.contains('func _show_global_heal_activation_notification'),
		"realtime Global Heal broadcasts show a deduplicated activation card"
	)
	_check(
		overlay.contains('func _apply_global_heal_cooldown_state(state: Dictionary)')
			and overlay.contains('_apply_global_heal_cooldown_state(message)'),
		"realtime Global Heal broadcasts synchronize the cooldown UI"
	)
	_check(overlay.contains('bool(state.get("eventActive", false))'), "active requests are recovered after reconnecting")
	_check(overlay.contains("if _is_world_battle_active():") and overlay.contains("pending_global_heal_request"), "requests remain pending during battles")
	_check(
		overlay.contains('int(response.get("status", 0)) == 409')
			and overlay.contains("and _is_world_battle_active()"),
		"battle-blocked acceptance remains pending for a later retry"
	)
	_check(overlay.contains('ui.buff.global_heal.disable_future'), "the request dialog can disable future prompts")
	_check(not overlay.contains("get_vbox()"), "the request dialog uses supported Godot dialog APIs")
	_check(wallet_service.contains('GLOBAL_HEAL_ENDPOINT := "/game/global-heal"'), "wallet service exposes Global Heal state and activation")
	_check(heal_service.contains('func accept_global_heal(event_id: String)'), "party heal service accepts an individual event")
	_check(
		overlay.contains('SfxManager.play("pokemon_recovery")')
			and overlay.contains('response.get("alreadyAccepted", false)'),
		"a newly accepted Global Heal plays the recovery sound once"
	)
	_check(
		heal_service.contains('func acknowledge_global_heal(event_id: String)')
			and overlay.contains('await PartyHealService.acknowledge_global_heal(event_id)'),
		"Global Heal is acknowledged before its one-time prompt is shown"
	)
	_check(
		overlay.contains('acknowledgement.get("alreadyAcknowledged", false)')
			and overlay.contains("pending_global_heal_request.clear()"),
		"an event already seen on this or another client is not prompted again"
	)
	_check(heal_service.contains('func party_needs_heal(party: Array)'), "full parties do not receive unnecessary prompts")
	_check(game_state.contains("var global_heal_requests_enabled := true"), "Global Heal requests default to enabled")
	_check(loading_screen.contains('preferences.get("globalHealRequestsEnabled", true)'), "the account preference loads before entering the world")
	var english_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	var english: Dictionary = english_value as Dictionary if english_value is Dictionary else {}
	_check(
		str(english.get("ui.buff.global_heal.description", ""))
			== "Every online Trainer can choose to fully heal their party. Players in battle can choose afterwards.",
		"Global Heal uses simple player-facing copy"
	)
	_check(
		str(english.get("ui.buff.global_heal.no_aetherite", ""))
			== "You do not get Aetherite for this.",
		"the Aetherite note uses plain language"
	)

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
		"res://localization/zh_CN.json",
	]:
		var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(locale_path))
		var catalog: Dictionary = catalog_value as Dictionary if catalog_value is Dictionary else {}
		_check(catalog.has("ui.buff.global_heal.name"), "%s contains the Global Heal name" % locale_path.get_file())
		_check(
			str(catalog.get("ui.buff.global_heal.no_aetherite", "")).strip_edges() != "",
			"%s explains that Global Heal awards no Aetherite" % locale_path.get_file()
		)
		_check(
			str(catalog.get("ui.reward_card.global_buff_activated", "")).strip_edges() != ""
				and str(catalog.get("ui.reward_card.global_heal_activated_by", "")).strip_edges() != "",
			"%s contains localized global buff card labels" % locale_path.get_file()
		)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
