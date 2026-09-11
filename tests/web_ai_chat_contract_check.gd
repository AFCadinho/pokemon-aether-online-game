extends SceneTree

var failures := 0


func _init() -> void:
	var battle_api := FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd")
	var overlay := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var chat := FileAccess.get_file_as_string("res://scripts/services/chat_realtime_service.gd")
	var player := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var preview_proxy := FileAccess.get_file_as_string("res://tools/serve_web_connected.py")
	_check(battle_api.contains('"/auth/web/ai-sparring/statistics" if OS.has_feature("web")'), "web AI statistics use the scoped endpoint")
	_check(battle_api.contains('"/auth/web/ai-sparring/history" if OS.has_feature("web")'), "web AI history uses the scoped endpoint")
	_check(not overlay.contains('if OS.has_feature("web"):\n\t\tawait _open_pvp_popup_section("AI Sparring")'), "the browser PvP button opens the mode chooser")
	_check(overlay.contains('_show_web_client_required("Ranked PvP")'), "Ranked remains visible but requires the client")
	_check(not overlay.contains("pvp_mode_casual_button.visible = false"), "custom PvP remains available in the browser")
	_check(chat.contains(' + "/ws/chat?token=%s"'), "browser chat keeps the authenticated realtime transport")
	_check(not player.contains('func check_for_wild_encounter(encounter_type: String, check_position: Vector2 = Vector2.INF) -> void:\n\tif OS.has_feature("web"):\n\t\treturn'), "browser walking can trigger wild encounters")
	_check(preview_proxy.contains('(\"POST\", \"/battle/trainer\")'), "connected preview admits NPC trainer battle creation")
	_check(preview_proxy.contains('@app.get(\"/news.json\")'), "connected preview serves current announcements")
	print("web_ai_chat_contract_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
