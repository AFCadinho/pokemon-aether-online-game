extends Panel

class_name BattleStatusPanel

@onready var turn_label: Label = $MarginContainer/HBoxContainer/TurnLabel
@onready var turn_separator_label: Label = $MarginContainer/HBoxContainer/SeperationLabel
@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel
@onready var local_timer_label: Label = $MarginContainer/HBoxContainer/LocalTimerLabel
@onready var opponent_timer_label: Label = $MarginContainer/HBoxContainer/OpponentTimerLabel

func reset_status() -> void:
	turn_label.visible = false
	turn_separator_label.visible = false
	timer_label.visible = false
	local_timer_label.visible = false
	opponent_timer_label.visible = false
	
func set_turn(turn: int) -> void:
	if turn > 0:
		turn_label.text = "Turn: " + str(turn)
		turn_label.visible = true
	else:
		turn_label.visible = false
		
func hide_timer() -> void:
	turn_separator_label.visible = false
	timer_label.visible = false
	local_timer_label.visible = false
	opponent_timer_label.visible = false

func show_bank_timers(local_timer: Dictionary, opponent_timer: Dictionary) -> void:
	turn_separator_label.visible = true
	local_timer_label.visible = true
	opponent_timer_label.visible = true
	local_timer_label.text = _participant_timer_text("You", local_timer)
	opponent_timer_label.text = _participant_timer_text("Opponent", opponent_timer)
	var urgent := int(local_timer.get("effectiveDecisionRemainingMs", 999999)) <= 5000 and str(local_timer.get("state")) == "DECIDING"
	local_timer_label.modulate = Color(1.0, 0.35, 0.25) if urgent else Color.WHITE

func _participant_timer_text(owner: String, timer: Dictionary) -> String:
	var state := str(timer.get("state", "WAITING"))
	var parts: Array[String] = ["%s %s" % [owner, _format_ms(int(timer.get("bankRemainingMs", 0)))]]
	var decision_label := _decision_text(str(timer.get("decisionKind", "")))
	if state == "SCHEDULED":
		parts.append("%s starts %s" % [decision_label, _format_ms(int(timer.get("scheduledRemainingMs", 0)))])
	elif state in ["DECIDING", "EXPIRED"]:
		parts.append("%s %s" % [decision_label, _format_ms(int(timer.get("effectiveDecisionRemainingMs", 0)))])
	parts.append(_state_text(state))
	return " · ".join(parts)

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
