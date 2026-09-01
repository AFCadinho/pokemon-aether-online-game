extends SceneTree

const Policy := preload("res://scripts/battle/wild_battle_presentation_policy.gd")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const EVENT_RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_policy_boundaries()
	_check_battle_flow_contract()
	_check_wait_suppression_contract()
	quit(1 if failed else 0)


func _check_policy_boundaries() -> void:
	_check(
		Policy.is_confirmed_local_win(true, false, true, "p1"),
		"confirmed local wild wins can skip their winner message"
	)
	_check(
		not Policy.is_confirmed_local_win(false, false, true, "p1"),
		"Trainer wins cannot skip the wild winner message"
	)
	_check(
		not Policy.is_confirmed_local_win(true, true, true, "p1"),
		"PvP wins cannot skip the wild winner message"
	)
	_check(
		Policy.should_fast_finish_win(true, false, false, true, "p1"),
		"disabled animations fast-finish a confirmed local wild win"
	)
	_check(
		Policy.should_fast_finish_win(true, false, false, true, "Player 1"),
		"Showdown Player 1 winner labels fast-finish wild wins"
	)
	_check(
		Policy.should_fast_finish_win(true, false, false, true, "Leaf", "p1", "Leaf"),
		"named local winners fast-finish wild wins"
	)
	_check(
		not Policy.should_fast_finish_win(true, false, true, true, "p1"),
		"enabled animations preserve the standard wild ending"
	)
	_check(
		not Policy.should_fast_finish_win(false, false, false, true, "p1"),
		"Trainer battles never use the wild fast finish"
	)
	_check(
		not Policy.should_fast_finish_win(true, true, false, true, "p1"),
		"PvP battles never use the wild fast finish"
	)
	_check(
		not Policy.should_fast_finish_win(true, false, false, false, "p1"),
		"non-terminal wild responses keep rendering normally"
	)
	_check(
		not Policy.should_fast_finish_win(true, false, false, true, "p2"),
		"wild losses keep the standard terminal presentation"
	)
	_check(
		not Policy.should_fast_finish_win(true, false, false, true, ""),
		"draws and missing winners cannot fast-finish"
	)


func _check_battle_flow_contract() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var move_source := _function_source(source, "func _on_moves_grid_move_selected(")
	var fast_policy_source := _function_source(source, "func _should_fast_finish_wild_win(")
	var result_policy_source := _function_source(source, "func _should_skip_wild_win_result(")
	var resolved_source := _function_source(source, "func _render_resolved_player_choice_response(")
	var response_source := _function_source(source, "func _render_opponent_response(")
	var render_source := _function_source(source, "func _render_battle_events(")
	var finish_source := _function_source(source, "func _finish_if_battle_ended(")

	_check(
		move_source.contains("var skip_wild_win_result := _should_skip_wild_win_result()")
			and move_source.contains("var fast_finish_wild_win := _should_fast_finish_wild_win()")
			and move_source.contains("fast_finish_wild_win,\n\t\tskip_wild_win_result")
			and move_source.contains("_finish_if_battle_ended({}, skip_wild_win_result)"),
		"move responses independently select wait suppression and winner-message removal"
	)
	_check(
		fast_policy_source.contains("battle_type == BattleType.WILD")
			and fast_policy_source.contains("_is_pvp_battle()")
			and fast_policy_source.contains("SettingsManager.battle_animations")
			and fast_policy_source.contains("battle_state.is_battle_ended()")
			and fast_policy_source.contains("battle_state.get_winner()")
			and result_policy_source.contains("battle_type == BattleType.WILD")
			and result_policy_source.contains("_is_pvp_battle()")
			and result_policy_source.contains("battle_state.is_battle_ended()")
			and result_policy_source.contains("battle_state.get_winner()"),
		"battle controller derives both terminal modes from scoped authoritative state"
	)
	_check(
		resolved_source.contains("suppress_presentation_waits := false")
			and resolved_source.contains("suppress_terminal_win_presentation := false")
			and resolved_source.contains("suppress_presentation_waits,\n\t\tsuppress_terminal_win_presentation"),
		"resolved move rendering forwards both optional terminal presentation controls"
	)
	_check(
		response_source.contains("suppress_presentation_waits := false")
			and response_source.contains("suppress_terminal_win_presentation := false")
			and response_source.contains("suppress_presentation_waits,\n\t\tsuppress_terminal_win_presentation"),
		"non-PvP event rendering keeps full state processing in fast mode"
	)
	_check(
		render_source.contains("if not (suppress_terminal_win_presentation and event_type == \"win\"):")
			and render_source.contains("event_renderer.render_event(event_data, presentation, suppress_presentation_waits)"),
		"confirmed wild wins skip only the terminal winner presentation"
	)
	_check(
		finish_source.contains("skip_result_hold := false")
			and finish_source.contains("if not skip_result_hold:")
			and finish_source.contains("_finish_battle(finish_result)"),
		"fast mode skips only the final hold before the shared battle completion"
	)


func _check_wait_suppression_contract() -> void:
	var source := FileAccess.get_file_as_string(EVENT_RENDERER_PATH)
	var render_source := _function_source(source, "func render_event(")
	var wait_source := _function_source(source, "func _wait(")

	_check(
		render_source.contains("suppress_presentation_waits := false")
			and render_source.contains("suppress_presentation_waits"),
		"event rendering preserves standard waits by default"
	)
	_check(
		wait_source.contains("if suppressed or seconds <= 0.0 or host_node == null:"),
		"suppressed waits return without creating presentation timers"
	)


func _function_source(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
