extends Node2D

var player_nearby := false
var is_creating_starter := false
var create_pokemon_request: HTTPRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create_pokemon_request = HTTPRequest.new()
	add_child(create_pokemon_request)


func _process(_delta: float) -> void:
	if not player_nearby:
		return

	if _is_ui_typing():
		return

	if Input.is_action_just_pressed("interact"):
		var dialogue_box = get_tree().current_scene.get_node("DialogueBox/Box")

		if dialogue_box.is_open:
			return

		talk()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit

func talk() -> void:
	if is_creating_starter:
		return

	var dialogue_box = get_tree().current_scene.get_node("DialogueBox/Box")
	
	if PlayerSave.flags.get("received_starter", false):
		dialogue_box.start_dialogue([
			"Take god care of Charmander!"
		])
		return
	else:
		is_creating_starter = true
		var starter_pokemon = await give_starter_pokemon("Charmander")
		is_creating_starter = false
		if starter_pokemon == null:
			await GameErrorDialogService.show_report_to_staff_message()
			return

		PlayerSave.add_pokemon(starter_pokemon)		
		
		PlayerSave.flags["received_starter"] = true
		
		dialogue_box.start_dialogue([
			"Ah, there you are!",
			"Take this Charmander with you.",
			"You received Charmander!"
		],
		"Prof. Oak"
		)
	
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
	
	
