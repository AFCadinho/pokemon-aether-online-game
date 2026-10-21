extends "res://scripts/world/npcs/gate_npc.gd"

var spoken: Array[String] = []
var access_refreshes := 0

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _load_gate_metadata() -> Dictionary:
	return {"success": true}

func _refresh_transition_access(_force_refresh := false) -> Dictionary:
	access_refreshes += 1
	return {"success": true}

func _resolve_dialogue_lines(reference: String, _fallback: Array) -> Array[String]:
	return [reference]

func show_dialogue(lines: Array[String] = [], _speaker_name_override := "") -> bool:
	spoken.append_array(lines)
	return true
