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


func hide_bank_timers() -> void:
	player_1_timer_panel.visible = false
	player_2_timer_panel.visible = false
	player_1_timer_label.visible = false
	player_2_timer_label.visible = false
	player_1_timer_state_label.visible = false
	player_2_timer_state_label.visible = false
	player_1_timer_bar.visible = false
	player_2_timer_bar.visible = false


func show_bank_timers(player_1_timer: Dictionary, player_2_timer: Dictionary) -> void:
	player_1_timer_panel.visible = true
	player_2_timer_panel.visible = true
	_set_timer(player_1_timer_state_label, player_1_timer_label, player_1_timer_bar, player_1_timer)
	_set_timer(player_2_timer_state_label, player_2_timer_label, player_2_timer_bar, player_2_timer)


func _set_timer(state_label: Label, time_label: Label, bar: ProgressBar, timer: Dictionary) -> void:
	state_label.visible = true
	time_label.visible = true
	bar.visible = true
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
	var bank_text := "Bank %s" % _format_ms(int(timer.get("bankRemainingMs", 0)))
	if state == "SCHEDULED":
		return "%s · Starts %s" % [bank_text, _format_ms(int(timer.get("scheduledRemainingMs", 0)))]
	elif state in ["DECIDING", "EXPIRED"]:
		return "%s · Decision %s" % [bank_text, _format_ms(int(timer.get("effectiveDecisionRemainingMs", 0)))]
	return bank_text


func _timer_progress(timer: Dictionary) -> float:
	var state := str(timer.get("state", "WAITING"))
	if state == "EXPIRED":
		return 0.0
	if state == "SCHEDULED":
		return 100.0
	if state == "DECIDING":
		var maximum := int(timer.get("decisionMaximumMs", 0))
		if maximum > 0:
			return clampf(100.0 * float(timer.get("effectiveDecisionRemainingMs", 0)) / float(maximum), 0.0, 100.0)
	var bank_maximum := int(timer.get("bankMaximumMs", 0))
	if bank_maximum <= 0:
		return 0.0
	return clampf(100.0 * float(timer.get("bankRemainingMs", 0)) / float(bank_maximum), 0.0, 100.0)


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
