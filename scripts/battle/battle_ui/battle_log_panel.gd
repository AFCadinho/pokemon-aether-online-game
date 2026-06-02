extends Panel

class_name BattleLogPanel

@onready var log_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/BattleLogText

func clear_log() -> void:
	log_text.text = ""
	
func add_message(message: String) -> void:
	if log_text.text == "":
		log_text.text = message
	else:
		log_text.text += "\n" + message
		
func toggle_log() -> void:
	visible = not visible
	
func is_open() -> bool:
	return visible

func add_turn_header(turn: int) -> void:
	if log_text.text != "":
		log_text.text += "\n\n"
		
	log_text.text += "Turn %s" % turn
	
func add_blank_line() -> void:
	if log_text.text == "":
			return

	if not log_text.text.ends_with("\n"):
			log_text.text += "\n"
