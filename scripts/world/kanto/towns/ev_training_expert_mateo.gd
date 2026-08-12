@tool
extends DialogueNPC

class_name EvTrainingExpertMateo

signal pokemon_selected(pokemon_id: int)

const QUEST_ID := "viridian_ev_training"

var quest_reward_id := ""
var quest_reward_received_dialogue_id := ""
var quest_reward_completed_dialogue_id := ""
var choice_layer: CanvasLayer
var choice_root: Control


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await show_dialogue(["I cannot begin the lesson right now."], display_name)
		return
	if StoryService.is_requirement_met(QUEST_ID, "return_to_mateo", "active"):
		await _claim_reward()
		return
	if StoryService.is_requirement_met(QUEST_ID, "allocate_training_evs", "active"):
		await _guide_allocation()
		return
	if StoryService.is_requirement_met(QUEST_ID, "defeat_training_targets", "active"):
		await _show_battle_progress()
		return
	if StoryService.is_requirement_met(QUEST_ID, "choose_focus", "active"):
		await _choose_focus()
		return
	if StoryService.is_requirement_met(QUEST_ID, "", "completed"):
		await show_dialogue(await _resolve_lines(
			quest_reward_completed_dialogue_id,
			["Choose a role before you train, then focus your Effort Values on that role."]
		))
		return
	await show_dialogue()


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	quest_reward_id = str(metadata.get("questRewardId", "")).strip_edges()
	quest_reward_received_dialogue_id = str(metadata.get("questRewardReceivedDialogueId", "")).strip_edges()
	quest_reward_completed_dialogue_id = str(metadata.get("questRewardCompletedDialogueId", "")).strip_edges()


func _choose_focus() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "Could not prepare the EV lesson.")
		return
	var tutorial: Dictionary = response.get("tutorial", {})
	var party: Array = tutorial.get("party", []) as Array
	if party.is_empty():
		await show_dialogue(["Bring at least one Pokemon in your party and return to me."], display_name)
		return
	await show_dialogue([
		"EV means Effort Value. A Pokemon that participates in a victory stores the Effort Values granted by the defeated species.",
		"First choose one Pokemon to focus on. I will look at its natural strengths and select a useful stat for this lesson.",
		"After four victories, I will show you how to apply those stored points through Party, Summary, and the EVs tab.",
	], display_name)
	var pokemon_id := await _show_party_prompt(party)
	if pokemon_id <= 0:
		return
	var focus_response: Dictionary = await EvTrainingService.select_focus_pokemon(pokemon_id)
	if not bool(focus_response.get("success", false)):
		await GameErrorDialogService.show_response(focus_response, "Could not select that Pokemon for the lesson.")
		return
	var focus: Dictionary = focus_response.get("tutorial", {})
	await show_dialogue([
		"%s's strongest natural direction is %s, so that will be our focus." % [str(focus.get("pokemonName", "Your Pokemon")), _stat_label(str(focus.get("stat", "")))],
		"Defeat four %s in the practice field. %s must take part in each battle to earn the Effort Values." % [str(focus.get("targetSpeciesName", "targets")), str(focus.get("pokemonName", "Your Pokemon"))],
		"My assistants at either entrance will let you in free while the lesson is active.",
	], display_name)


func _show_battle_progress() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	var tutorial: Dictionary = response.get("tutorial", {})
	await show_dialogue([
		"%s has participated in %d of %d victories over %s." % [str(tutorial.get("pokemonName", "Your Pokemon")), int(tutorial.get("defeated", 0)), int(tutorial.get("requiredDefeats", 4)), str(tutorial.get("targetSpeciesName", "the target"))],
		"Use either assistant to enter the practice field. The selected Pokemon must participate for the victory to count.",
	], display_name)


func _guide_allocation() -> void:
	var response: Dictionary = await EvTrainingService.get_session()
	var tutorial: Dictionary = response.get("tutorial", {})
	await show_dialogue([
		"The four %s Effort Values are now stored on %s. They do not improve its stats until you assign them." % [_stat_label(str(tutorial.get("stat", ""))), str(tutorial.get("pokemonName", "your Pokemon"))],
		"Open Party, inspect its Summary, choose the EVs tab, and select %s. Allocate all four stored points there." % _stat_label(str(tutorial.get("stat", ""))),
	], display_name)
	get_tree().call_group(
		"ui_overlay",
		"open_ev_training_allocation",
		int(tutorial.get("pokemonId", 0)),
		str(tutorial.get("stat", ""))
	)


func _claim_reward() -> void:
	var result: Dictionary = await InventoryService.claim_npc_item_reward(quest_reward_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "Could not claim Mateo's reward.")
		return
	await show_dialogue(await _resolve_lines(
		quest_reward_received_dialogue_id,
		["Well done. Take this Macho Brace and keep training with a purpose."]
	))
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		"EV training unlocked · Received Macho Brace"
	)


func _show_party_prompt(party: Array) -> int:
	_ensure_choice_panel()
	var list := choice_root.get_node("Panel/Margin/Layout/List") as VBoxContainer
	for child in list.get_children():
		child.queue_free()
	for candidate_value: Variant in party:
		if candidate_value is not Dictionary:
			continue
		var candidate := candidate_value as Dictionary
		var button := Button.new()
		button.text = "%s · Lv. %d · %s" % [str(candidate.get("name", "Pokemon")), int(candidate.get("level", 1)), _stat_label(str(candidate.get("stat", "")))]
		button.disabled = not bool(candidate.get("eligible", false))
		button.tooltip_text = "This Pokemon has no room for four more EVs." if button.disabled else "Focus on %s by defeating %s." % [_stat_label(str(candidate.get("stat", ""))), str(candidate.get("targetSpeciesName", "targets"))]
		button.pressed.connect(_select_pokemon.bind(int(candidate.get("pokemonId", 0))))
		list.add_child(button)
	var cancel := Button.new()
	cancel.text = LocalizationManager.text("common.cancel")
	cancel.pressed.connect(_select_pokemon.bind(0))
	list.add_child(cancel)
	choice_root.show()
	return await pokemon_selected


func _ensure_choice_panel() -> void:
	if choice_root != null and is_instance_valid(choice_root):
		return
	choice_layer = CanvasLayer.new()
	choice_layer.layer = 90
	add_child(choice_layer)
	choice_root = Control.new()
	choice_root.name = "ChoiceRoot"
	choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_root.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_layer.add_child(choice_root)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(420, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -180)
	choice_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Choose a focus Pokemon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var list := VBoxContainer.new()
	list.name = "List"
	layout.add_child(list)
	choice_root.hide()


func _select_pokemon(pokemon_id: int) -> void:
	choice_root.hide()
	pokemon_selected.emit(pokemon_id)


func _resolve_lines(dialogue_id: String, fallback: Array[String]) -> Array[String]:
	return await NpcDialogueService.resolve_lines(dialogue_id, fallback, "EvTrainingExpertMateo")


func _stat_label(stat: String) -> String:
	match stat:
		"hp": return "HP"
		"atk": return "Attack"
		"def": return "Defense"
		"spa": return "Special Attack"
		"spd": return "Special Defense"
		"spe": return "Speed"
	return stat.to_upper()
