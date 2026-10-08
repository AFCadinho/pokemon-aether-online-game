extends "res://scripts/ui/login_screen.gd"

var health_results: Array = []
var restore_results: Array = []
var restore_requests := 0
var saved_cards := 0
var statuses: Array[String] = []
var defer_restore := false
signal finish_restore

func _ready() -> void: pass
func _refresh_online_players() -> void: pass
func _apply_authenticated_player_profile() -> void: pass
func _apply_saved_session_preview_state() -> void: pass
func _show_saved_session_card() -> void: saved_cards += 1
func _log_server_health_error(_result: Dictionary) -> void: pass
func _apply_server_access_controls() -> void: pass
func _set_server_status(key: String, _color: Color) -> void:
	server_status_translation_key = key
	statuses.append(key)
func _set_online_players_status(_key: String, _values: Dictionary, _color: Color) -> void: pass
func _set_server_access_notice(_message: String = "", _key: String = "") -> void:
	server_access_notice_active = true
func _clear_server_access_notice() -> void:
	server_access_notice_active = false
func _request_server_health() -> Dictionary:
	await get_tree().process_frame
	return health_results.pop_front()
func _request_saved_session_restore() -> Dictionary:
	restore_requests += 1
	if defer_restore:
		await finish_restore
	else:
		await get_tree().process_frame
	return restore_results.pop_front()
