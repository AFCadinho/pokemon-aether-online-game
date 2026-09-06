extends SceneTree

const MARKER := preload("res://scripts/battle/battle_ui/ai5_research_marker.gd")
const BATTLE_PATH := "res://scripts/battle/battle.gd"
const API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	_check_context_gate()
	await _check_live_interface_uses_current_turn()
	_check_battle_wiring()
	_check_marker_payload()
	quit(1 if failed else 0)


func _check_context_gate() -> void:
	var research := _research_response()
	_check(MARKER.has_research_context(research), "a complete campaign response enables the live marker")
	_check(not MARKER.has_research_context({"battleId": "battle-1"}), "ordinary NPC and training responses remain excluded")
	_check(not MARKER.has_research_context({
		"battleId": "battle-1",
		"ai5Playtest": {"campaignId": "fake"},
	}), "partial or forged-looking client context cannot enable the marker")


func _check_live_interface_uses_current_turn() -> void:
	var marker := MARKER.new()
	root.add_child(marker)
	await process_frame
	var configured: bool = marker.configure(
		_research_response(), Callable(self, "_current_turn"),
		Callable(self, "_submit_marker"), Callable(self, "_translate")
	)
	_check(configured, "valid research context constructs the in-battle marker")
	marker.call("_open_marker")
	_check(marker.marked_turn == 16, "archived marker defaults to the last completed turn")
	_check(marker.modal.visible, "the category and note dialog opens for that turn")
	marker.queue_free()


func _research_response() -> Dictionary:
	return {
		"battleId": "battle-1",
		"ai5Playtest": {
			"campaignId": "ai5-playtest-v2-pilot-10",
			"policyRevision": "npc-ai-level5-expected-score-v1",
			"phase": "pilot",
			"assignmentIndex": 0,
		},
	}


func _current_turn() -> int:
	return 17


func _submit_marker(_turn: int, _category: String, _note: String) -> Dictionary:
	return {"success": true}


func _translate(key: String, replacements: Dictionary = {}) -> String:
	return key.replace("{turn}", str(replacements.get("turn", "")))


func _check_battle_wiring() -> void:
	var overlay_script := load(OVERLAY_PATH) as Script
	_check(overlay_script != null and overlay_script.can_instantiate(), "sparring overlay compiles with project autoloads")
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(
		not battle_source.contains("\n\t\t_configure_ai5_research_marker(api_response)"),
		"retired research markers are no longer wired into live battles"
	)
	_check(
		overlay_source.contains("set_tab_hidden(pvp_ai_sparring_tabs.get_tab_count() - 1, true)")
		and overlay_source.contains('"retired": true'),
		"research campaign is hidden and locally retired"
	)
	_check(
		not overlay_source.contains("pvp_ai5_playtest_flag_turn")
		and not overlay_source.contains("_on_ai5_playtest_flag_pressed"),
		"the ambiguous post-battle manual turn form is removed"
	)


func _check_marker_payload() -> void:
	var api_source := FileAccess.get_file_as_string(API_PATH)
	_check(api_source.contains('"note": note.strip_edges().left(2000)'), "notes are bounded before leaving the client")
	_check(api_source.contains('{"turn": maxi(1, turn)'), "the current battle turn cannot be submitted as turn zero")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
