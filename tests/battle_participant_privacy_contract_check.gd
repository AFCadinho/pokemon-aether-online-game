extends SceneTree

const BATTLE_API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"
const REALTIME_PATH := "res://scripts/services/pvp_battle_realtime_service.gd"


func _init() -> void:
	var api_source := FileAccess.get_file_as_string(BATTLE_API_PATH)
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
	print("PASS battle_participant_privacy_contract_check")
	quit(0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)
