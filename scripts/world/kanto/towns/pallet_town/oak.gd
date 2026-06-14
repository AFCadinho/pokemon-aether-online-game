extends DialogueNPC

var is_creating_starter := false
var create_pokemon_request: HTTPRequest


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
		await show_dialogue([
			"Take good care of Charmander!"
		])
		return

	is_creating_starter = true
	var starter_pokemon: Pokemon = await give_starter_pokemon("Charmander")
	is_creating_starter = false
	if starter_pokemon == null:
		await GameErrorDialogService.show_report_to_staff_message()
		return

	PlayerSave.add_pokemon(starter_pokemon)
	PlayerSave.flags["received_starter"] = true

	await show_dialogue([
		"Ah, there you are!",
		"Take this Charmander with you.",
		"You received Charmander!"
	])
	
func give_starter_pokemon(pokemon_name: String) -> Pokemon:
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

	return pokemon
	
	
