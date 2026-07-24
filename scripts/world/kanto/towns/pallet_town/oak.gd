extends DialogueNPC

@export var starter_gift_dialogue_id := ""
@export var starter_received_dialogue_id := ""
@export var starter_gift_dialogue_lines: Array[String] = [
	"Ah, there you are!",
	"Take this Charmander with you.",
	"You received Charmander!",
]
@export var starter_received_dialogue_lines: Array[String] = [
	"Take good care of Charmander!",
]

var is_creating_starter := false
var create_pokemon_request: HTTPRequest
var last_starter_claim_already_completed := false


func _ready() -> void:
	display_name = "Prof. Oak"
	create_pokemon_request = HTTPRequest.new()
	add_child(create_pokemon_request)
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()


func interact_with_player(_player: Node2D) -> void:
	if is_creating_starter:
		return

	if PlayerSave.flags.get("received_starter", false):
		await show_dialogue(await _resolve_dialogue_lines(starter_received_dialogue_id, starter_received_dialogue_lines))
		return

	is_creating_starter = true
	var starter_pokemon: Pokemon = await give_starter_pokemon("Charmander")
	is_creating_starter = false
	if starter_pokemon == null:
		await GameErrorDialogService.show_report_to_staff_message()
		return

	PlayerSave.flags["received_starter"] = true
	if last_starter_claim_already_completed:
		await show_dialogue(await _resolve_dialogue_lines(starter_received_dialogue_id, starter_received_dialogue_lines))
	else:
		await show_dialogue(await _resolve_dialogue_lines(starter_gift_dialogue_id, starter_gift_dialogue_lines))


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	starter_gift_dialogue_id = _get_metadata_dialogue_id(metadata, "starterGiftDialogueId", "starter_gift_dialogue_id", starter_gift_dialogue_id)
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
	
func give_starter_pokemon(pokemon_name: String) -> Pokemon:
	last_starter_claim_already_completed = false
	var response: Dictionary = await PokemonDataApiClient.create_pokemon(
		create_pokemon_request,
		{
			"species": pokemon_name,
			"level": 5,
		}
	)
	if not bool(response.get("success", false)):
		push_warning("Oak.give_starter_pokemon failed: %s" % str(response.get("error", "Unknown error")))
		return null

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		push_warning("Oak.give_starter_pokemon failed: response did not include Pokemon data.")
		return null

	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_value as Dictionary)
	if pokemon == null:
		push_warning("Oak.give_starter_pokemon failed: backend Pokemon payload could not be loaded.")
		return null

	var create_result: Dictionary = await PlayerPartyStateService.claim_starter(pokemon_value as Dictionary)
	if not bool(create_result.get("success", false)):
		push_warning("Oak.give_starter_pokemon failed: Pokemon could not be saved: %s" % str(create_result.get("error", "Unknown error")))
		return null
	last_starter_claim_already_completed = bool(create_result.get("alreadyClaimed", false))

	var owned_pokemon_response: Dictionary = {}
	var owned_pokemon_response_value: Variant = create_result.get("pokemon", {})
	if owned_pokemon_response_value is Dictionary:
		owned_pokemon_response = owned_pokemon_response_value as Dictionary

	var owned_pokemon_value: Variant = owned_pokemon_response.get("pokemon", {})
	if owned_pokemon_value is Dictionary:
		var owned_pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(owned_pokemon_value as Dictionary)
		if owned_pokemon != null:
			return owned_pokemon

	return pokemon
	
	
