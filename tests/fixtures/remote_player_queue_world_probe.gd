extends "res://scripts/world/world.gd"

var applied: Dictionary = {}
var removals: Array[int] = []
var heavy_visuals := false

func _ready() -> void:
	set_process(false)

func _apply_remote_player_visual_states(states: Array, _prune_missing := true) -> void:
	if heavy_visuals:
		OS.delay_msec(5)
	for state: Dictionary in states:
		applied[int(state.userId)] = state

func _remove_remote_player(user_id: int) -> void:
	applied.erase(user_id)
	removals.append(user_id)

func _sort_remote_player_avatar_nodes() -> void:
	pass
