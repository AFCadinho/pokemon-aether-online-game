extends Panel

class_name BattleStatusPanel

@onready var turn_label: Label = $MarginContainer/HBoxContainer/TurnLabel
@onready var turn_separator_label: Label = $MarginContainer/HBoxContainer/SeperationLabel
@onready var timer_label: Label = $MarginContainer/HBoxContainer/TimerLabel

var current_turn := 0
var localization_manager: Node


func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)


func reset_status() -> void:
	current_turn = 0
	turn_label.visible = false
	turn_separator_label.visible = false
	timer_label.visible = false
	
func set_turn(turn: int) -> void:
	current_turn = turn
	if turn > 0:
		turn_label.text = _t("battle.status.turn", {"turn": turn})
		turn_label.visible = true
	else:
		turn_label.visible = false
		
func hide_timer() -> void:
	turn_separator_label.visible = false
	timer_label.visible = false


func _on_locale_changed(_locale: String) -> void:
	if current_turn > 0:
		set_turn(current_turn)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
