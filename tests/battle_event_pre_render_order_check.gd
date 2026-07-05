extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"

var failed := false


func _init() -> void:
	_check_pre_event_render_skips_final_team_hud_refresh()
	_check_non_pvp_switch_events_are_not_deduped_by_species()
	quit(1 if failed else 0)


func _check_pre_event_render_skips_final_team_hud_refresh() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _update_battle_presentation_before_event_render(events: Array) -> void:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "pre-event presentation function exists")
	_check_equal(function_source.contains("_update_hud_panels("), false, "pre-event presentation does not push final active HUD HP")
	_check_equal(function_source.contains("_update_hud_panels()"), false, "pre-event presentation does not push final team HUD")
	_check_equal(function_source.contains("_update_party_slots()"), false, "pre-event presentation does not push final party slots")


func _check_non_pvp_switch_events_are_not_deduped_by_species() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var function_index := source.find("func _should_dedupe_rendered_non_pvp_event(event_data: Dictionary) -> bool:")
	var next_function_index := source.find("\nfunc ", function_index + 1)
	var function_source := source.substr(function_index, next_function_index - function_index)

	_check_equal(function_index >= 0, true, "non-PvP dedupe function exists")
	_check_equal(function_source.contains("event_type == \"turn\""), true, "turn events are still deduped")
	_check_equal(function_source.contains("event_type == \"switch\""), false, "repeat switch events are not deduped by species")
	_check_equal(function_source.contains("event_type == \"drag\""), false, "repeat drag events are not deduped by species")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
