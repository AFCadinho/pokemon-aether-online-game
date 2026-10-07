extends "res://scripts/ui/login_screen.gd"

signal reply
var profile_requests := 0
var previews := 0
var delayed := false
var profile: Dictionary = {}

func _refresh_player_preview() -> void:
	previews += 1

func _load_preview_profile() -> Dictionary:
	profile_requests += 1
	if delayed:
		await reply
	return profile
