extends WorldInteractable

class_name PokemonTowerSpiritGate

const SCOPE_ITEM_ID := "silph-scope"


func is_passage_open() -> bool:
	return InventoryService.has_item(SCOPE_ITEM_ID)


func blocks_world_position(world_position: Vector2) -> bool:
	return not is_passage_open() and super.blocks_world_position(world_position)


func _can_start_manual_interaction() -> bool:
	return not is_passage_open() and super._can_start_manual_interaction()


func interact_with_player(player: Node2D) -> void:
	if is_passage_open():
		return
	var result: Dictionary = await StorySequenceRunner.run_sequence([
		{"type": "dialogue", "dialogueId": "kanto_pokemon_tower_spirit_warning"},
		{"type": "dialogue", "dialogueId": "kanto_pokemon_tower_player_scope_needed"},
	], self, player)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
