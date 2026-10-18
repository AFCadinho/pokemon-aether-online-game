@tool
extends DialogueNPC

const COUNTER := preload("res://scripts/ui/casino_token_counter.gd")
var counter_open := false

func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false

func interact_with_player(_player: Node2D) -> void:
	if counter_open:
		return
	counter_open = true
	var world: Node = GameState.get_world()
	if world != null and world.has_method("save_current_player_state_now"):
		var saved: Dictionary = await world.call("save_current_player_state_now")
		if not bool(saved.get("success", false)):
			await GameErrorDialogService.show_response(saved)
			counter_open = false
			return
	var counter := COUNTER.new()
	add_child(counter)
	await counter.finished
	counter.queue_free()
	counter_open = false
