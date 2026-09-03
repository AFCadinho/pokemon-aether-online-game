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
	_check(marker.marked_turn == 17, "opening the marker captures the live turn automatically")
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
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(
		battle_source.contains("if training_ai_battle:\n\t\tpvp_battle_purpose = \"training\"\n\t\t_capture_pvp_local_canonical_roster(api_response)\n\t\t_configure_ai5_research_marker(api_response)"),
		"only the server-created training AI setup can consider the research marker"
	)
	_check(
		battle_source.contains("AI5_RESEARCH_MARKER.has_research_context(api_response)"),
		"the battle controller requires explicit campaign metadata"
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
