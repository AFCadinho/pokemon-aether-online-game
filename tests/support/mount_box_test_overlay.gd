extends "res://scripts/ui/ui_overlay.gd"

var messages: Array[String] = []
var tracker_opens := 0

func _add_chat_message(text: String, _use_bbcode: bool = false, _category: String = CHAT_CATEGORY_SYSTEM) -> void:
	messages.append(text)

func _show_shiny_tracker(_tab: String = "pokemon") -> void:
	tracker_opens += 1
