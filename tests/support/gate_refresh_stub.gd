extends "res://scripts/world/npcs/gate_npc.gd"

var next_access_allowed := false
var refresh_count := 0
var last_force_refresh := false


func _ready() -> void:
	super._ready()
	set_process(false)


func _load_gate_metadata() -> Dictionary:
	return {"success": true, "metadata": {}}


func _refresh_transition_access(force_refresh := false) -> Dictionary:
	refresh_count += 1
	last_force_refresh = force_refresh
	transition_access = {"allowed": next_access_allowed}
	transition_access_resolved = true
	_sync_guard_presence()
	return {"success": true, "access": transition_access}
