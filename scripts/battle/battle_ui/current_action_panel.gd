extends Panel

class_name CurrentActionPanel

@onready var message_label: Label = $MarginContainer/CurrentActionLabel

func clear_message() -> void:
	message_label.text = ""
	visible = false
	
func set_message(message: String) -> void:
	message_label.text = message
	visible = message != ""
