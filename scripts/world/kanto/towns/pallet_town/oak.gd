extends DialogueNPC

@export var starter_gift_dialogue_id := ""
@export var starter_confirmed_dialogue_id := ""
@export var starter_received_dialogue_id := ""
@export var starter_gift_dialogue_lines: Array[String] = [
	"Ah, there you are!",
	"Your father has collected and cared for Pokemon from every region over the years.",
	"Before he left, Dadinho prepared a Pokemon especially for you and entrusted it to me. It has been waiting here as his surprise.",
]
@export var starter_confirmed_dialogue_lines: Array[String] = [
	"{pokemon}... So this is the partner Dadinho prepared for you.",
	"He knew exactly which Pokemon would suit you.",
	"You received {pokemon}!",
]
@export var starter_received_dialogue_lines: Array[String] = [
	"Take good care of {pokemon}. Dadinho entrusted that partner to you.",
]

var is_creating_starter := false
var last_starter_claim_already_completed := false
var quest_turn_in_id := ""
var quest_turn_in_quest_id := ""
var quest_turn_in_step_id := ""
var quest_turn_in_dialogue_id := ""
var quest_turn_in_completed_dialogue_id := ""


func _ready() -> void:
	display_name = "Prof. Oak"
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	if _is_gary_starter_sequence_active():
		return {
			"success": true,
			"handled": true,
			"status": "gary_starter_sequence_active",
		}
	return await super._run_story_or_legacy_interaction(body, trigger)


func interact_with_player(player: Node2D) -> void:
	if is_creating_starter or _is_gary_starter_sequence_active():
		return

	is_creating_starter = true
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		is_creating_starter = false
		await GameErrorDialogService.show_report_to_staff_message()
		return
	if _is_quest_turn_in_available():
		await _turn_in_quest_item(player)
		is_creating_starter = false
		return

	var options_result: Dictionary = await PlayerPartyStateService.get_starter_options()
	if not bool(options_result.get("success", false)):
		is_creating_starter = false
		await GameErrorDialogService.show_report_to_staff_message()
		return

	if bool(options_result.get("alreadyClaimed", false)):
		PlayerSave.flags["received_starter"] = true
		var claimed_species_name := str(options_result.get("selectedSpeciesName", "your Pokemon")).strip_edges()
		if claimed_species_name.is_empty():
			claimed_species_name = "your Pokemon"
		is_creating_starter = false
		await show_dialogue(
			_format_dialogue_lines(
				await _resolve_dialogue_lines(starter_received_dialogue_id, starter_received_dialogue_lines),
				claimed_species_name
			)
		)
		return

	var choices_value: Variant = options_result.get("choices", [])
	if not (choices_value is Array) or (choices_value as Array).is_empty():
		is_creating_starter = false
		await GameErrorDialogService.show_report_to_staff_message()
		return

	await show_dialogue(await _resolve_dialogue_lines(starter_gift_dialogue_id, starter_gift_dialogue_lines))
	var selected_choice: Dictionary = await _choose_starter(choices_value as Array)
	if selected_choice.is_empty():
		is_creating_starter = false
		return

	var selected_species_id := str(selected_choice.get("speciesId", "")).strip_edges()
	var selected_species_name := str(selected_choice.get("name", selected_species_id)).strip_edges()
	_prepare_gary_starter_sequence()
	var create_result: Dictionary = await give_starter_pokemon(selected_species_id)
	is_creating_starter = false
	if not bool(create_result.get("success", false)):
		_cancel_gary_starter_sequence()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	var claimed_name := _claimed_species_name(create_result)
	if not claimed_name.is_empty():
		selected_species_name = claimed_name
	PlayerSave.flags["received_starter"] = true
	PlayerSave.flags["starter_species"] = selected_species_id
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text(
			"ui.oaks_lab.starter_received",
			{"pokemon": selected_species_name}
		)
	)
	if last_starter_claim_already_completed:
		_cancel_gary_starter_sequence()
		await show_dialogue(
			_format_dialogue_lines(
				await _resolve_dialogue_lines(starter_received_dialogue_id, starter_received_dialogue_lines),
				selected_species_name
			)
		)
	else:
		await show_dialogue(
			_format_dialogue_lines(
				await _resolve_dialogue_lines(starter_confirmed_dialogue_id, starter_confirmed_dialogue_lines),
				selected_species_name
			)
		)
		_schedule_gary_starter_sequence(player, create_result)


func _schedule_gary_starter_sequence(player: Node2D, create_result: Dictionary) -> void:
	var gary := get_parent().get_node_or_null("Gary")
	if gary == null or not gary.has_method("begin_starter_sequence"):
		push_warning("Oak: Gary is unavailable for the starter battle sequence.")
		return
	gary.call_deferred(
		"begin_starter_sequence",
		player,
		str(create_result.get("rivalStarterSpeciesId", "")),
		str(create_result.get("rivalStarterSpeciesName", "")),
		str(create_result.get("rivalTrainerId", ""))
	)


func _prepare_gary_starter_sequence() -> void:
	var gary := get_parent().get_node_or_null("Gary")
	if gary != null and gary.has_method("prepare_starter_sequence"):
		gary.call("prepare_starter_sequence")


func _cancel_gary_starter_sequence() -> void:
	var gary := get_parent().get_node_or_null("Gary")
	if gary != null and gary.has_method("cancel_pending_starter_sequence"):
		gary.call("cancel_pending_starter_sequence")


func _is_gary_starter_sequence_active() -> bool:
	var gary := get_parent().get_node_or_null("Gary")
	return (
		gary != null
		and gary.has_method("is_starter_sequence_active")
		and bool(gary.call("is_starter_sequence_active"))
	)


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	starter_gift_dialogue_id = _get_metadata_dialogue_id(metadata, "starterGiftDialogueId", "starter_gift_dialogue_id", starter_gift_dialogue_id)
	starter_confirmed_dialogue_id = _get_metadata_dialogue_id(metadata, "starterConfirmedDialogueId", "starter_confirmed_dialogue_id", starter_confirmed_dialogue_id)
	starter_received_dialogue_id = _get_metadata_dialogue_id(metadata, "starterReceivedDialogueId", "starter_received_dialogue_id", starter_received_dialogue_id)
	quest_turn_in_id = str(metadata.get("questTurnInId", "")).strip_edges()
	quest_turn_in_quest_id = str(metadata.get("questTurnInQuestId", "")).strip_edges()
	quest_turn_in_step_id = str(metadata.get("questTurnInStepId", "")).strip_edges()
	quest_turn_in_dialogue_id = str(metadata.get("questTurnInDialogueId", "")).strip_edges()
	quest_turn_in_completed_dialogue_id = str(
		metadata.get("questTurnInCompletedDialogueId", "")
	).strip_edges()


func _is_quest_turn_in_available() -> bool:
	if (
		quest_turn_in_id.is_empty()
		or quest_turn_in_quest_id.is_empty()
		or quest_turn_in_step_id.is_empty()
	):
		return false
	var quest := StoryService.get_quest(quest_turn_in_quest_id)
	if str(quest.get("status", "")).to_lower() != "active":
		return false
	var steps_value: Variant = quest.get("steps", [])
	if not steps_value is Array:
		return false
	for step_value: Variant in steps_value as Array:
		if not step_value is Dictionary:
			continue
		var step := step_value as Dictionary
		if str(step.get("stepId", "")) == quest_turn_in_step_id:
			return str(step.get("status", "")).to_lower() == "active"
	return false


func _turn_in_quest_item(player: Node2D) -> void:
	await show_dialogue(await _resolve_dialogue_lines(
		quest_turn_in_dialogue_id,
		["Ah, that is the parcel I was waiting for! Let me take a look."]
	))
	var gary := get_parent().get_node_or_null("Gary")
	if gary != null and gary.has_method("prepare_parcel_return_departure"):
		gary.call("prepare_parcel_return_departure")
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null or not inventory_service.has_method("turn_in_npc_quest_item"):
		_cancel_pending_gary_parcel_departure(gary)
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var result: Dictionary = await inventory_service.call(
		"turn_in_npc_quest_item",
		quest_turn_in_id
	)
	if not bool(result.get("success", false)):
		_cancel_pending_gary_parcel_departure(gary)
		await GameErrorDialogService.show_response(result, "backend.error.reward_claim")
		return
	if not bool(result.get("storyRefreshSuccess", false)):
		push_warning("Oak: parcel turn-in succeeded but story refresh did not complete locally.")
	await show_dialogue(await _resolve_dialogue_lines(
		quest_turn_in_completed_dialogue_id,
		[
			"Thank you. This will be a great help to my research.",
			"You and your new partner handled your first errand well. Your journey has truly begun.",
		]
	))
	if bool(result.get("turnedIn", false)):
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.key_item.received_pokedex")
		)
	if gary != null and gary.has_method("play_parcel_return_departure"):
		await gary.call("play_parcel_return_departure", player)
	else:
		_cancel_pending_gary_parcel_departure(gary)


func _cancel_pending_gary_parcel_departure(gary: Node) -> void:
	if gary != null and gary.has_method("cancel_pending_parcel_return_departure"):
		gary.call("cancel_pending_parcel_return_departure")


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:
	var resolved_dialogue_id := dialogue_reference_id.strip_edges()
	if resolved_dialogue_id.is_empty():
		return fallback_lines

	var lines: Array[String] = await DialogueMetadataService.get_lines(resolved_dialogue_id)
	if lines.is_empty():
		push_warning("Oak: Dialogue metadata was empty for %s; falling back to inline dialogue." % resolved_dialogue_id)
		return fallback_lines

	return lines


func _choose_starter(choices: Array) -> Dictionary:
	var chooser := StarterChoiceDialog.new()
	get_tree().root.add_child(chooser)
	chooser.open(choices)
	var selected_value: Variant = await chooser.finished
	if selected_value is Dictionary:
		return selected_value as Dictionary
	return {}


func give_starter_pokemon(species_id: String) -> Dictionary:
	last_starter_claim_already_completed = false
	var create_result: Dictionary = await PlayerPartyStateService.claim_starter(species_id)
	if not bool(create_result.get("success", false)):
		push_warning("Oak.give_starter_pokemon failed: %s" % str(create_result.get("error", "Unknown error")))
		return create_result

	last_starter_claim_already_completed = bool(create_result.get("alreadyClaimed", false))
	var story_result: Dictionary = await PlayerGameStateService.refresh_story()
	if not bool(story_result.get("success", false)):
		push_warning(
			"Oak.give_starter_pokemon could not refresh story progress: %s"
			% str(story_result.get("error", "Unknown error"))
		)
	return create_result


func _claimed_species_name(create_result: Dictionary) -> String:
	var instance_value: Variant = create_result.get("pokemon", {})
	if not (instance_value is Dictionary):
		return ""
	var payload_value: Variant = (instance_value as Dictionary).get("pokemon", {})
	if not (payload_value is Dictionary):
		return ""
	var payload := payload_value as Dictionary
	return str(payload.get("species", payload.get("name", payload.get("speciesId", "")))).strip_edges()


func _format_dialogue_lines(lines: Array[String], pokemon_name: String) -> Array[String]:
	var formatted: Array[String] = []
	for line: String in lines:
		formatted.append(line.replace("{pokemon}", pokemon_name))
	return formatted
