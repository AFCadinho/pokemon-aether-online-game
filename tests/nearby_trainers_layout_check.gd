extends SceneTree

const COORDINATOR_PATH := "res://scripts/ui/player_interaction_coordinator.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(COORDINATOR_PATH)

	_check(source.contains("const PANEL_WIDTH := 410.0"), "Nearby Trainers has room for readable trainer cards")
	_check(source.contains("const WINDOW_Z_INDEX := 1002"), "Nearby Trainers renders above chat tabs")
	_check(source.contains('title.text = "Nearby Trainers"'), "Roster uses the player-facing Nearby Trainers title")
	_check(source.contains('subtitle.text = "Trainers currently exploring this map"'), "Header explains the roster scope")
	_check(source.contains("NEARBY_TRAINERS_ICON"), "Roster reuses the dedicated nearby-trainer icon")
	_check(source.contains("func _create_player_row"), "Roster renders structured trainer cards")
	_check(source.contains('nearby_label.text = "NEARBY"'), "Trainer rows expose live presence")
	var open_context_block := source.get_slice("func open_context_for_player", 1).get_slice("func close_topmost", 0)
	_check(not open_context_block.contains("close_players_panel()"), "Selecting a roster trainer keeps the live list available")
	_check(source.contains("func _create_empty_roster_state"), "Roster has a dedicated empty state")
	_check(source.contains('title.text = "No trainers nearby"'), "Empty state clearly reports that the map is quiet")
	_check(source.contains("func _refresh_context_status"), "Trainer actions expose relationship and loading status")
	_check(source.contains('context_actions.add_child(_context_section_label("TRAINER ACTIONS"))'), "Primary trainer actions are grouped")
	_check(source.contains('context_actions.add_child(_context_section_label("SOCIAL"))'), "Friend and block actions are grouped separately")
	_check(source.contains('\"Inspect profile, badges and stats\"'), "Trainer Card action explains its destination")
	_check(source.contains('\"Start a private conversation\"'), "Private Message action explains its destination")
	_check(source.contains('\"Invite this trainer to trade\"'), "Trade remains available when capabilities allow it")
	_check(source.contains('"default" if _is_blocked(current_target) else "danger"'), "Blocking remains visually marked as a sensitive action")
	_check(source.contains("var context_close_button := _compact_close_button()"), "Trainer actions use a compact header close control")
	_check(source.contains("func _glass_panel_style"), "Roster and action menu share the modern glass surface")
	_check(source.contains("players.sort_custom(_compare_players)"), "Roster ordering remains deterministic")
	_check(source.contains("roster_changed.is_connected"), "Visible roster still updates from realtime presence")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
