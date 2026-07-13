extends Panel

class_name BattleStatusPanel

@onready var turn_label: Label = $MarginContainer/HBoxContainer/TurnLabel
@onready var turn_separator_label: Label = $MarginContainer/HBoxContainer/SeperationLabel
@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel

func reset_status() -> void:
	turn_label.visible = false
	turn_separator_label.visible = false
	timer_label.visible = false
	
func set_turn(turn: int) -> void:
	if turn > 0:
		turn_label.text = "Turn: " + str(turn)
		turn_label.visible = true
	else:
		turn_label.visible = false
		
func hide_timer() -> void:
	turn_separator_label.visible = false
	timer_label.visible = false
