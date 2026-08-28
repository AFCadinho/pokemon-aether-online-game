@tool
extends DialogueNPC

class_name CeruleanMountainGuide

const WEST_SITE := "west"
const WEST_LEVEL := 20

@export var west_destination_position := Vector2(112, 1520)


func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false


func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false


func interact_with_player(_player: Node2D) -> void:
	var state_result: Dictionary = await RockSmashService.load_state()
	if not bool(state_result.get("success", false)):
		await GameErrorDialogService.show_response(state_result, "backend.error.rock_smash_unavailable")
		return
	var state := state_result.get("state", {}) as Dictionary
	var level := int(state.get("level", 0))
	if not bool(state.get("unlocked", false)) or level < WEST_LEVEL:
		await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.level_locked", {"level": WEST_LEVEL})])
		return

	await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.intro")])
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("relocate_player_within_current_map"):
		await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.travel_failed")])
		return
	var result: Dictionary = await world.call("relocate_player_within_current_map", west_destination_position)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.rock_smash_unavailable")


func can_access_site(site_id: String, rock_smash_level: int) -> bool:
	return site_id == WEST_SITE and rock_smash_level >= WEST_LEVEL
