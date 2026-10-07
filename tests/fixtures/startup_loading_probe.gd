extends "res://scripts/ui/loading_screen.gd"

var login_notices := 0

func _ready() -> void:
	pass

func _return_to_login(_message: String) -> void:
	login_notices += 1
