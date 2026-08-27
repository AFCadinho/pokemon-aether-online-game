@tool
extends DialogueNPC

class_name CeruleanMountainReturn

@export var destination_position := Vector2(1680, 1904)


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.return_line")])
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("relocate_player_within_current_map"):
		await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.travel_failed")])
		return
	var result: Dictionary = await world.call("relocate_player_within_current_map", destination_position)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.rock_smash_unavailable")
