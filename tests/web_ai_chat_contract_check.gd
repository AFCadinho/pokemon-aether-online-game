extends SceneTree

var failures := 0


func _init() -> void:
	var battle_api := FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd")
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var chat := FileAccess.get_file_as_string("res://scripts/services/chat_realtime_service.gd")
	_check(battle_api.contains('"/auth/web/ai-sparring/statistics" if OS.has_feature("web")'), "web AI statistics use the scoped endpoint")
	_check(battle_api.contains('"/auth/web/ai-sparring/history" if OS.has_feature("web")'), "web AI history uses the scoped endpoint")
	_check(overlay.contains('if OS.has_feature("web"):\n\t\tawait _open_pvp_popup_section("AI Sparring")'), "the browser PvP button opens AI Sparring directly")
	_check(overlay.contains("pvp_mode_ranked_button.visible = false"), "Ranked stays hidden in the browser")
	_check(overlay.contains("pvp_mode_casual_button.visible = false"), "custom PvP stays hidden in the browser")
	_check(chat.contains(' + "/ws/chat?token=%s"'), "browser chat keeps the authenticated realtime transport")
	print("web_ai_chat_contract_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
