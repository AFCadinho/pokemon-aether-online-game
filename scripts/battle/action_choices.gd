extends PanelContainer

signal action_selected(action: String)

@onready var buttons: Array[Button] = [
	$GridContainer/FightButton,
	$GridContainer/PartyButton,
	$GridContainer/RunButton,
	$GridContainer/BagButton
]

func _select_button(active_button: Button) -> void:
	# Zet alle knoppen terug naar hun normale staat zodra een knop is gekozen
	for button in buttons:
		button.disabled = false
		button.modulate = Color(1, 1, 1)
	
	# Disable de actieve knop en maak hem een beetje grijs als visueel indicatie
	active_button.disabled = true
	active_button.modulate = Color(0.7, 0.7, 0.7)

func set_selected_action(action: String) -> void:
	if action == "fight":
		_select_button($GridContainer/FightButton)
	elif action == "bag":
		_select_button($GridContainer/BagButton)
	elif action == "party":
		_select_button($GridContainer/PartyButton)
	elif action == "run":
		_select_button($GridContainer/RunButton)

func _on_fight_button_pressed() -> void:
	set_selected_action("fight")
	action_selected.emit("fight")


func _on_bag_button_pressed() -> void:
	set_selected_action("bag")
	action_selected.emit("bag")

func _on_party_button_pressed() -> void:
	set_selected_action("party")
	action_selected.emit("party")

func _on_run_button_pressed() -> void:
	set_selected_action("run")
	action_selected.emit("run")
