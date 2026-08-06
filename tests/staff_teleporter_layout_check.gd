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
	_check(source.contains("StaffTeleportSendConfirmation") and source.contains("popup_centered(Vector2i(520, 240))"), "Moving another player requires explicit confirmation")
	_check(source.contains('command_status == "applied"') and source.contains('command_status == "delivered"') and source.contains("Move queued for"), "Forced teleport reports queued, delivered, and applied command states")
	_check(source.contains("staff_teleport_player_results.visible = true"), "Online-player results remain visible after selection")
	_check(source.contains("staff_teleport_player_results.item_selected.connect(_on_staff_teleport_player_selected)") and not source.contains("staff_teleport_player_results.item_activated.connect(_on_staff_teleport_player_selected)") and source.contains("staff_teleport_player_results.deselect_all()"), "A single click confirms the selected online player")
	_check(source.contains('staff_teleport_player_action_mode = ""') and source.contains('"ui.staff.teleport.select_action_hint"'), "Player actions start with an explicit neutral choice")
	_check(source.contains("staff_teleport_player_note_caption.visible = show_to_player or show_send_safe") and source.contains("staff_teleport_player_reason_input.visible = show_to_player or show_send_safe"), "Staff note controls stay hidden until an action is chosen")
	_check(source.contains('_apply_button_style(staff_teleport_to_player_mode_button, "primary")') and source.contains('_apply_button_style(staff_teleport_send_player_mode_button, "danger")'), "Player action choices use distinct intent colors")
	_check(source.contains('LocalizationManager.text("common.loading")'), "Destination and player loading states are visible")
	_check(source.contains("staff_teleport_expanded_maps") and source.contains("staff_teleport_send_expanded_maps"), "Destination lists track collapsed map groups")
	_check(source.contains('var header_prefix := "▼" if is_expanded else "▶"'), "Map groups expose clear expanded and collapsed states")
	_check(source.contains('var search_active := map_query != "" or spawn_query != ""'), "Map and spawn searches automatically reveal matching points")
	_check(source.contains('replace("Pokémon", "Pokemon")') and source.contains("_staff_teleport_search_key"), "Staff destination labels use easy-to-type Pokemon spelling and accent-insensitive search")
	_check(source.contains("_can_teleport_self()") and source.contains("_can_teleport_to_player()") and source.contains("_can_teleport_other_player()"), "Existing permission gates remain intact")
	_check(source.contains("_can_ignore_staff_teleporter_overworld_lock()") and source.contains('"get_authorized_teleport_block_reason",'), "Staff teleports may bypass only their own modal movement lock")
	_check(source.contains("ModeratorTeleportService.teleport_self") and source.contains("ModeratorTeleportService.teleport_to_player") and source.contains("ModeratorTeleportService.teleport_player"), "Existing authoritative teleport actions remain intact")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
