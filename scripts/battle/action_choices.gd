extends PanelContainer

signal action_selected(action: String)

@onready var buttons: Array[Button] = [
	$GridContainer/FightButton,
	$GridContainer/PartyButton,
	$GridContainer/RunButton,
	$GridContainer/BagButton
]

var disabled_actions := {}
var all_actions_disabled := false
var selected_action := ""

func _select_button(active_button: Button) -> void:
	selected_action = _get_action_for_button(active_button)
	# Zet alle knoppen terug naar hun normale staat zodra een knop is gekozen
	for button in buttons:
		button.disabled = false
		button.modulate = Color(1, 1, 1)
	
	# Disable de actieve knop en maak hem een beetje grijs als visueel indicatie
	active_button.disabled = true
	active_button.modulate = Color(0.7, 0.7, 0.7)
	_apply_disabled_actions()

func set_selected_action(action: String) -> void:
	if action == "fight":
		_select_button($GridContainer/FightButton)
	elif action == "bag":
		_select_button($GridContainer/BagButton)
	elif action == "party":
		_select_button($GridContainer/PartyButton)
	elif action == "run":
		_select_button($GridContainer/RunButton)

func set_action_disabled(action: String, is_disabled: bool) -> void:
	disabled_actions[action] = is_disabled
	_apply_disabled_actions()

func set_all_actions_disabled(is_disabled: bool) -> void:
	all_actions_disabled = is_disabled
	_apply_disabled_actions()

func _apply_disabled_actions() -> void:
	for button in buttons:
		button.disabled = false
		button.modulate = Color(1, 1, 1)

	if all_actions_disabled:
		for button in buttons:
			button.disabled = true
			button.modulate = Color(0.7, 0.7, 0.7)

		return

	var selected_button := _get_action_button(selected_action)
	if selected_button != null:
		selected_button.disabled = true
		selected_button.modulate = Color(0.7, 0.7, 0.7)

	for action in disabled_actions:
		if not bool(disabled_actions[action]):
			continue

		var button := _get_action_button(str(action))
		if button == null:
			continue

		button.disabled = true
		button.modulate = Color(0.7, 0.7, 0.7)

func _get_action_button(action: String) -> Button:
	if action == "fight":
		return $GridContainer/FightButton
	if action == "bag":
		return $GridContainer/BagButton
	if action == "party":
		return $GridContainer/PartyButton
	if action == "run":
		return $GridContainer/RunButton

	return null

func _get_action_for_button(button: Button) -> String:
	if button == $GridContainer/FightButton:
		return "fight"
	if button == $GridContainer/BagButton:
		return "bag"
	if button == $GridContainer/PartyButton:
		return "party"
	if button == $GridContainer/RunButton:
		return "run"

	return ""

func _on_fight_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("fight", false)):
		return

	set_selected_action("fight")
	action_selected.emit("fight")


func _on_bag_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("bag", false)):
		return

	set_selected_action("bag")
	action_selected.emit("bag")

func _on_party_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("party", false)):
		return

	set_selected_action("party")
	action_selected.emit("party")

func _on_run_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("run", false)):
		return

	set_selected_action("run")
	action_selected.emit("run")
