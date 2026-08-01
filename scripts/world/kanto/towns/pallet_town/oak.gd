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


func _ready() -> void:
	display_name = "Prof. Oak"
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func interact_with_player(_player: Node2D) -> void:
	if is_creating_starter:
		return

	is_creating_starter = true
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
	var create_result: Dictionary = await give_starter_pokemon(selected_species_id)
	is_creating_starter = false
	if not bool(create_result.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return

	var claimed_name := _claimed_species_name(create_result)
	if not claimed_name.is_empty():
		selected_species_name = claimed_name
	PlayerSave.flags["received_starter"] = true
	PlayerSave.flags["starter_species"] = selected_species_id
	if last_starter_claim_already_completed:
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


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	starter_gift_dialogue_id = _get_metadata_dialogue_id(metadata, "starterGiftDialogueId", "starter_gift_dialogue_id", starter_gift_dialogue_id)
	starter_confirmed_dialogue_id = _get_metadata_dialogue_id(metadata, "starterConfirmedDialogueId", "starter_confirmed_dialogue_id", starter_confirmed_dialogue_id)
	starter_received_dialogue_id = _get_metadata_dialogue_id(metadata, "starterReceivedDialogueId", "starter_received_dialogue_id", starter_received_dialogue_id)


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
