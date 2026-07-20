extends SceneTree

const ACTION_FLOW_PATH := "res://scripts/battle/battle_action_flow.gd"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	var action_flow_source := FileAccess.get_file_as_string(ACTION_FLOW_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var apply_index := action_flow_source.find("func apply_response(")
	var apply_next_index := action_flow_source.find("\nfunc ", apply_index + 1)
	var apply_source := action_flow_source.substr(apply_index, apply_next_index - apply_index)

	_check(apply_source.contains("load_battle_state: bool = true"), "action flow exposes an explicit canonical-state render barrier")
	_check(apply_source.contains("if load_battle_state:\n\t\tbattle_state.load_from_api_response"), "deferred responses do not mutate visible BattleState")
	_check(apply_source.find("ability_response_handler.call(display_response)") < apply_source.find("if load_battle_state:"), "public response metadata remains available while state is deferred")
	_check(battle_source.contains("_should_defer_pvp_canonical_state_until_render(display_response)"), "PvP responses activate the canonical-state render barrier")
	_check(battle_source.contains("response[\"requests\"] = battle_state.requests.duplicate(true)"), "terminal restore retains the event-applied winner presentation")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
