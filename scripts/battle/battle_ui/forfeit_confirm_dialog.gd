extends PanelContainer

signal confirmed
signal cancelled

@onready var yes_button: Button = $MarginContainer/VBoxContainer/ButtonRow/YesButton
@onready var no_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NoButton


func _ready() -> void:
	visible = false
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)


func show_dialog() -> void:
	visible = true
	no_button.grab_focus()


func hide_dialog() -> void:
	visible = false


func _on_yes_pressed() -> void:
	hide_dialog()
	confirmed.emit()


func _on_no_pressed() -> void:
	hide_dialog()
	cancelled.emit()
