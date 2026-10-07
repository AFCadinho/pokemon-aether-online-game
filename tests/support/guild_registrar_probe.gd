extends "res://scripts/world/npcs/guild_registrar_npc.gd"

var shown_lines: Array[String] = []
var confirmation_state: Dictionary = {}
var confirmation_count := 0
var accept_purchase := false


func show_dialogue(lines: Array[String] = [], _speaker_name_override := "") -> bool:
	shown_lines.append_array(lines)
	return true


func _confirm_purchase(state: Dictionary) -> bool:
	confirmation_state = state.duplicate(true)
	confirmation_count += 1
	return accept_purchase
