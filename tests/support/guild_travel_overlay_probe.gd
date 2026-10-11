extends "res://scripts/ui/ui_overlay.gd"

var travel_messages: Array[String] = []

func _ready() -> void:
	pass

func _add_chat_message(message: String, _use_bbcode: bool = false, _category: String = CHAT_CATEGORY_SYSTEM) -> void:
	travel_messages.append(message)
