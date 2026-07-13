extends HBoxContainer

class_name BattleVsPanelContainer

@onready var player_1_label: Label = $NamesPanel/MarginContainer/HBoxContainer/Player1
@onready var player_2_label: Label = $NamesPanel/MarginContainer/HBoxContainer/Player2
@onready var player_1_timer_panel: PanelContainer = $Player1TimerPanel
@onready var player_2_timer_panel: PanelContainer = $Player2TimerPanel
@onready var player_1_timer_state_label: Label = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerStateLabel
@onready var player_2_timer_state_label: Label = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerStateLabel
@onready var player_1_timer_label: Label = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerLabel
@onready var player_2_timer_label: Label = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerLabel
@onready var player_1_timer_bar: ProgressBar = $Player1TimerPanel/MarginContainer/VBoxContainer/Player1TimerBar
@onready var player_2_timer_bar: ProgressBar = $Player2TimerPanel/MarginContainer/VBoxContainer/Player2TimerBar

var _player_1_timer: Dictionary = {}
var _player_2_timer: Dictionary = {}
var _player_1_reconnect: Dictionary = {}
var _player_2_reconnect: Dictionary = {}


func _process(_delta: float) -> void:
	if not _player_1_reconnect.is_empty():
		_render_reconnect(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, _player_1_reconnect)
	if not _player_2_reconnect.is_empty():
		_render_reconnect(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, _player_2_reconnect)


func hide_decision_timers(clear_reconnect_state := false) -> void:
	if clear_reconnect_state:
		_player_1_reconnect.clear()
		_player_2_reconnect.clear()
	player_1_timer_panel.visible = false
	player_2_timer_panel.visible = false
	player_1_timer_label.visible = false
	player_2_timer_label.visible = false
	player_1_timer_state_label.visible = false
	player_2_timer_state_label.visible = false
	player_1_timer_bar.visible = false
	player_2_timer_bar.visible = false


func show_decision_timers(player_1_timer: Dictionary, player_2_timer: Dictionary) -> void:
	_player_1_timer = player_1_timer.duplicate(true)
	_player_2_timer = player_2_timer.duplicate(true)
	player_1_timer_panel.visible = true
	player_2_timer_panel.visible = true
	if _player_1_reconnect.is_empty():
		_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, player_1_timer)
	if _player_2_reconnect.is_empty():
		_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, player_2_timer)


func show_reconnect_timer(display_side: String, reconnect_deadline_at: String, grace_seconds: int, server_now: String = "") -> void:
	var deadline_unix := float(Time.get_unix_time_from_datetime_string(reconnect_deadline_at))
	if deadline_unix <= 0.0 or grace_seconds <= 0:
		return
	var anchor_unix := Time.get_unix_time_from_system()
	if server_now != "":
		var parsed_server_now := float(Time.get_unix_time_from_datetime_string(server_now))
		if parsed_server_now > 0.0:
			anchor_unix = parsed_server_now
	var remaining_ms := maxi(int(ceil((deadline_unix - anchor_unix) * 1000.0)), 0)
	var reconnect := {
		"expiresTicksMs": Time.get_ticks_msec() + remaining_ms,
		"graceSeconds": grace_seconds,
	}
	if display_side == "p1":
		_player_1_reconnect = reconnect
		player_1_timer_panel.visible = true
		_render_reconnect(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, reconnect)
	elif display_side == "p2":
		_player_2_reconnect = reconnect
		player_2_timer_panel.visible = true
		_render_reconnect(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, reconnect)


func clear_reconnect_timer(display_side: String) -> void:
	if display_side == "p1":
		_player_1_reconnect.clear()
		_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, _player_1_timer)
	elif display_side == "p2":
		_player_2_reconnect.clear()
		_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, _player_2_timer)


func has_active_reconnect_timer() -> bool:
	return not _player_1_reconnect.is_empty() or not _player_2_reconnect.is_empty()


func _render_reconnect(state_label: Label, time_label: Label, bar: ProgressBar, reconnect: Dictionary) -> void:
	var remaining_ms := maxi(int(reconnect.get("expiresTicksMs", 0)) - Time.get_ticks_msec(), 0)
	var remaining_seconds := int(ceil(float(remaining_ms) / 1000.0))
	var grace_seconds := maxi(int(reconnect.get("graceSeconds", 0)), 1)
	state_label.visible = true
	time_label.visible = true
	bar.visible = true
	state_label.text = "Disconnected"
	time_label.text = "Reconnect %02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]
	bar.value = clampf(100.0 * float(remaining_seconds) / float(grace_seconds), 0.0, 100.0)
	var urgent := remaining_seconds <= 10
	state_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE
	time_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE


func _set_timer(state_label: Label, time_label: Label, bar: ProgressBar, timer: Dictionary) -> void:
	var state := str(timer.get("state", "WAITING"))
	var has_frozen_waiting_countdown := state == "WAITING" and int(timer.get("decisionMaximumMs", 0)) > 0
	var has_countdown := state in ["SCHEDULED", "DECIDING", "EXPIRED"] or has_frozen_waiting_countdown
	state_label.visible = true
	time_label.visible = has_countdown
	bar.visible = has_countdown
	state_label.text = _timer_state_text(timer)
	time_label.text = _timer_time_text(timer)
	bar.value = _timer_progress(timer)
	var urgent := (
		str(timer.get("state", "")) == "DECIDING"
		and int(timer.get("effectiveDecisionRemainingMs", 999999)) <= 5000
	)
	state_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE
	time_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE


func _timer_state_text(timer: Dictionary) -> String:
	var state := str(timer.get("state", "WAITING"))
	if state in ["SCHEDULED", "DECIDING", "EXPIRED"]:
		return "%s · %s" % [_decision_text(str(timer.get("decisionKind", ""))), _state_text(state)]
	return _state_text(state)


func _timer_time_text(timer: Dictionary) -> String:
	var state := str(timer.get("state", "WAITING"))
	if state == "SCHEDULED":
		return "Starts %s" % _format_ms(int(timer.get("scheduledRemainingMs", 0)))
	elif state in ["DECIDING", "EXPIRED", "WAITING"] and int(timer.get("decisionMaximumMs", 0)) > 0:
		return "Time %s" % _format_ms(int(timer.get("effectiveDecisionRemainingMs", 0)))
	return ""


func _timer_progress(timer: Dictionary) -> float:
	var state := str(timer.get("state", "WAITING"))
	if state == "EXPIRED":
		return 0.0
	if state == "SCHEDULED":
		return 100.0
	if state in ["DECIDING", "WAITING"]:
		var maximum := int(timer.get("decisionMaximumMs", 0))
		if maximum > 0:
			return clampf(100.0 * float(timer.get("effectiveDecisionRemainingMs", 0)) / float(maximum), 0.0, 100.0)
	return 0.0


func _format_ms(value: int) -> String:
	var seconds: int = maxi(value, 0) / 1000
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _state_text(value: String) -> String:
	match value:
		"DECIDING": return "Choosing"
		"SCHEDULED": return "Scheduled"
		"PAUSED": return "Paused"
		"EXPIRED": return "Time expired"
		_: return "Waiting"


func _decision_text(value: String) -> String:
	match value:
		"TEAM_PREVIEW": return "Team Preview"
		"FORCED_SWITCH": return "Forced Switch"
		_: return "Move"
