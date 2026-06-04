extends Panel

class_name CurrentActionPanel

const MAX_FONT_SIZE := 48
const MEDIUM_FONT_SIZE := 40
const SMALL_FONT_SIZE := 32
const MEDIUM_TEXT_LENGTH := 28
const SMALL_TEXT_LENGTH := 38

@onready var message_label: Label = $MarginContainer/CurrentActionLabel

func clear_message() -> void:
	message_label.text = ""
	visible = false
	
func set_message(message: String) -> void:
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", _get_message_font_size(message))
	visible = message != ""

func _get_message_font_size(message: String) -> int:
	if message.length() >= SMALL_TEXT_LENGTH:
		return SMALL_FONT_SIZE
	if message.length() >= MEDIUM_TEXT_LENGTH:
		return MEDIUM_FONT_SIZE

	return MAX_FONT_SIZE
