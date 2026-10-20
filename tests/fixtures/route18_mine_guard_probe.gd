extends "res://scripts/world/npcs/gate_npc.gd"
var server_access := {"allowed":false,"reasonCode":"ROCK_SMASH_LEVEL_REQUIRED","dialogueId":"kanto_route_18_mine_guard_blocked"}
var spoken: Array = []
var refreshes := 0
func _ready() -> void:
	_ready_base_npc()
	add_to_group("world_transition_denial_presenters")
func _process(_delta: float) -> void:
	pass
func _load_gate_metadata() -> Dictionary:
	return {"success":true}
func _refresh_transition_access(force_refresh := false) -> Dictionary:
	if force_refresh: refreshes += 1
	transition_access = server_access.duplicate(true)
	transition_access_resolved = true
	return {"success":true,"access":transition_access}
func _resolve_dialogue_lines(reference: String,_fallback: Array) -> Array[String]:
	return [reference]
func show_dialogue(lines: Array[String] = [],_speaker_name_override := "") -> bool:
	spoken.append_array(lines)
	return true
