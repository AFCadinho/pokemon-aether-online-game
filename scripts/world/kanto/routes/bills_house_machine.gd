extends WorldInteractable

class_name BillsHouseMachine

const BILL_MUGSHOT: Texture2D = preload("res://assets/sprites/trainer_cards/showdown/bill.png")
const BILL_QUEST_ID := "help_bill"
const BILL_COMPUTER_IDLE_DIALOGUE_ID := "kanto_bills_house_computer_idle"
const BILL_COMPUTER_COMPLETE_DIALOGUE_ID := "kanto_bills_house_computer_complete"

@export var trapped_bill_path: NodePath
@export var restored_bill_path: NodePath
@export var machine_flash_path: NodePath

var _story_dialogue_stage := 0


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	_story_dialogue_stage = 0
	var result := await super._run_story_or_legacy_interaction(body, trigger)
	if bool(result.get("success", false)) and bool(result.get("handled", false)):
		_apply_restored_visual_state()
		_present_ticket_reward(result.get("effects", []))
	return result


func interact_with_player(_player: Node2D) -> void:
	var dialogue_reference := BILL_COMPUTER_COMPLETE_DIALOGUE_ID if (
		StoryService.is_requirement_met(BILL_QUEST_ID, "", "completed")
	) else BILL_COMPUTER_IDLE_DIALOGUE_ID
	await _show_dialogue_reference(dialogue_reference)


func show_dialogue(
	lines: Array[String] = [],
	speaker_name_override := "",
	mugshot_override: Texture2D = null
) -> bool:
	if lines.is_empty():
		return await super.show_dialogue(lines, speaker_name_override, mugshot_override)
	var current_stage := _story_dialogue_stage
	_story_dialogue_stage += 1
	if current_stage == 2:
		await _play_cell_separation()
	var portrait := BILL_MUGSHOT if current_stage >= 2 else mugshot_override
	return await super.show_dialogue(lines, speaker_name_override, portrait)


func _play_cell_separation() -> void:
	var flash := get_node_or_null(machine_flash_path) as CanvasItem
	if flash != null:
		flash.visible = true
		flash.modulate.a = 0.0
		for _pulse: int in range(3):
			var pulse := create_tween()
			pulse.tween_property(flash, "modulate:a", 0.9, 0.12)
			pulse.tween_property(flash, "modulate:a", 0.0, 0.16)
			await pulse.finished
		flash.visible = false
	SfxManager.play("pokemon_recovery")
	_apply_restored_visual_state()
	await get_tree().create_timer(0.2).timeout


func _apply_restored_visual_state() -> void:
	var trapped_bill := get_node_or_null(trapped_bill_path) as CanvasItem
	var restored_bill := get_node_or_null(restored_bill_path) as CanvasItem
	if trapped_bill != null:
		trapped_bill.visible = false
	if restored_bill != null:
		restored_bill.visible = true


func _present_ticket_reward(effects_value: Variant) -> bool:
	var quantity := 0
	if effects_value is Array:
		for effect_value: Variant in effects_value as Array:
			if effect_value is not Dictionary:
				continue
			var effect := effect_value as Dictionary
			if bool(effect.get("alreadyGranted", false)):
				continue
			var grants_value: Variant = effect.get("grants", [])
			if grants_value is not Array:
				continue
			for grant_value: Variant in grants_value as Array:
				if grant_value is not Dictionary:
					continue
				var grant := grant_value as Dictionary
				if str(grant.get("itemId", "")).strip_edges().to_lower() == "ss-ticket":
					quantity += maxi(int(grant.get("quantity", 0)), 0)
	if quantity <= 0:
		return false
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.world.reward.story_item", {
			"item": ItemLocalization.display_name("ss-ticket"),
			"quantity": quantity,
		})
	)
	SfxManager.play("item_received")
	return true


func _show_dialogue_reference(dialogue_reference: String) -> bool:
	var response: Dictionary = await DialogueMetadataService.get_dialogue(dialogue_reference)
	if not bool(response.get("success", false)):
		return false
	var metadata := response.get("metadata", {}) as Dictionary
	var localized_lines: Array[String] = []
	for value: Variant in metadata.get("lines", []):
		var line := str(value).strip_edges()
		if not line.is_empty():
			localized_lines.append(line)
	if localized_lines.is_empty():
		return false
	return await super.show_dialogue(
		localized_lines,
		str(metadata.get("speakerName", display_name))
	)
