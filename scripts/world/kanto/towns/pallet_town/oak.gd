extends Node2D

var player_nearby := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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
	var dialogue_box = get_tree().current_scene.get_node("DialogueBox/Box")
	
	if PlayerSave.flags.get("received_starter", false):
		dialogue_box.start_dialogue([
			"Take god care of Charmander!"
		])
		return
	else:
		var starter_pokemon = give_starter_pokemon("Charmander")
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
	return PokemonFactory.create_pokemon(pokemon_name.to_lower(), 5)
	
	
