extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("staff_teleport_popup.custom_minimum_size = Vector2(900, 700)"), "Staff Teleporter has room for two-column workflows")
	_check(source.contains("var teleport_shell_style := _make_glass_panel_style(14)") and not source.contains('staff_teleport_popup.add_theme_stylebox_override("panel", _make_gold_panel_style'), "Staff Teleporter uses the modern glass shell")
	_check(source.contains('"ui.staff.teleport.subtitle"'), "Header explains the teleporter's purpose")
	_check(source.contains('"ui.staff.teleport.self"') and source.contains('"ui.staff.teleport.player_actions"'), "Self and player workflows remain separate")
	_check(source.contains("func _build_staff_teleport_self_workspace") and source.contains('"ui.staff.teleport.destinations"'), "Self workflow has a dedicated destination browser")
	_check(source.contains('"ui.staff.teleport.selected_destination"'), "Self workflow summarizes the selected destination")
	_check(source.contains("func _build_staff_teleport_player_workspace") and source.contains('"ui.staff.teleport.online_players"'), "Player workflow has a persistent online-player browser")
	_check(source.contains('"ui.staff.teleport.selected_player"'), "Player workflow summarizes the selected player")
	_check(source.contains('"ui.staff.teleport.go_to_player"') and source.contains('"ui.staff.teleport.move_player_safely"'), "Player actions use clear directional language")
	_check(source.contains('_apply_button_style(staff_teleport_send_player_button, "danger")'), "Moving another player is visually treated as a sensitive action")
	_check(source.contains("staff_teleport_player_results.visible = true"), "Online-player results remain visible after selection")
	_check(source.contains('LocalizationManager.text("common.loading")'), "Destination and player loading states are visible")
	_check(source.contains("_can_teleport_self()") and source.contains("_can_teleport_to_player()") and source.contains("_can_teleport_other_player()"), "Existing permission gates remain intact")
	_check(source.contains("ModeratorTeleportService.teleport_self") and source.contains("ModeratorTeleportService.teleport_to_player") and source.contains("ModeratorTeleportService.teleport_player"), "Existing authoritative teleport actions remain intact")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
