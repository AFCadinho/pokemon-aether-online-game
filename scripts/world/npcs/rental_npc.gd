@tool
extends DialogueNPC

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")
const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
@export_enum("team", "pokemon") var rental_kind := "team"
var interaction_in_flight := false
signal rental_choice_resolved(action: String)

func _prefetches_dialogue_metadata_on_approach() -> bool:
	return false

func _loads_pickpocket_profile_from_npc_metadata() -> bool:
	return false

func interact_with_player(_player: Node2D) -> void:
	if interaction_in_flight:
		return
	interaction_in_flight = true
	while true:
		var action := await _show_rental_choice()
		if action == "explain":
			await show_dialogue(_rental_explanation(), display_name)
			continue
		if action != "rent":
			interaction_in_flight = false
			return
		break
	var world: Node = GameState.get_world()
	if world != null and world.has_method("save_current_player_state_now"):
		var saved: Dictionary = await world.call("save_current_player_state_now")
		if not bool(saved.get("success", false)):
			await GameErrorDialogService.show_response(saved)
			interaction_in_flight = false
			return
	var menu := WORKSPACE.new()
	menu.kind = rental_kind
	add_child(menu)
	menu.open_vendor()
	await menu.finished
	menu.queue_free()
	interaction_in_flight = false

func _show_rental_choice() -> String:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	var choice := OptionButton.new()
	choice.add_item("Rent a team" if rental_kind == "team" else "Rent a Pokémon")
	choice.add_item("How rentals work")
	choice.custom_minimum_size = Vector2(0, 42)
	dialog.add_custom_control(choice)
	dialog.style_option_button(choice)
	dialog.configure(
		display_name,
		"What would you like to do?",
		"Continue",
		"Not now"
	)
	dialog.confirmed.connect(func(): rental_choice_resolved.emit("rent" if choice.selected == 0 else "explain"), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): rental_choice_resolved.emit("close"), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 300))
	var action: String = await rental_choice_resolved
	layer.queue_free()
	return action

func _rental_explanation() -> Array[String]:
	if rental_kind == "team":
		return [
			"Choose a complete level-100 catalog team and rent it with Aetherite. You can rent one team at a time.",
			"The six fixed sets and held items stay together. Team rentals cannot be purchased permanently.",
			"The timer keeps running while you are offline. Rentals go to your PC, or to free party slots if your PC is full.",
		]
	return [
		"Create any legal level-100 Pokémon from a PokéPaste set or with the manual builder. Its rarity determines the Aetherite price.",
		"You may rent up to six Pokémon. An active rental can be purchased permanently, with its rental fee deducted from the total price.",
		"The submitted held item is included and locked during the rental, but is not transferred by permanent purchase. The rental specialist remains the Original Trainer, it never counts as caught, and a permanently purchased rental can never be traded.",
		"The rental timer also runs while you are offline.",
	]
