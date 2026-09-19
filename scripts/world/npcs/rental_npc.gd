@tool
extends DialogueNPC

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")
@export_enum("team", "pokemon") var rental_kind := "team"
var interaction_in_flight := false

func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false

func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false

func interact_with_player(_player: Node2D) -> void:
	if interaction_in_flight:
		return
	interaction_in_flight = true
	var world := GameState.get_world()
	if world != null and world.has_method("save_current_player_state_now"):
		var saved: Dictionary = await world.call("save_current_player_state_now")
		if not bool(saved.get("success", false)):
			await GameErrorDialogService.show_response(saved)
			interaction_in_flight = false
			return
	var menu := WORKSPACE.new()
	menu.kind = rental_kind
	add_child(menu)
	menu.open_vendor()
	await menu.finished
	menu.queue_free()
	interaction_in_flight = false
