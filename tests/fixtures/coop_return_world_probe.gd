extends "res://scripts/world/world.gd"

var reload_requests := 0
var present_results := false

func _ready() -> void:
	set_process(false)

func _publish_world_presence(_force := false) -> void:
	pass

func _sync_player_activity_state_for_current_tile() -> void:
	pass

func _reload_coop_world() -> void:
	reload_requests += 1

func _show_pending_coop_battle_result() -> void:
	if present_results:
		await super._show_pending_coop_battle_result()
