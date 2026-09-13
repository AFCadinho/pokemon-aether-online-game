extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DamageCalcPanel.new()
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	panel.add_child(content)
	root.add_child(panel)
	await process_frame
	panel.set_knowledge_snapshot({
		"viewerPokemon": [{
			"pokemonRef": "viewer:public-slot-1", "active": true, "fainted": true,
			"identity": {"state": "known", "value": "Charizard"},
			"level": {"state": "known", "value": 50},
			"hp": {"display": {"current": 0, "maximum": 153, "scale": "exact"}, "exact": {"current": 0, "maximum": 153}},
		}],
		"opponentPokemon": [{
			"pokemonRef": "opponent:public-slot-1", "active": true, "fainted": false,
			"identity": {"state": "known", "value": "Garchomp"},
			"level": {"state": "known", "value": 50},
			"hp": {"display": {"current": 88, "maximum": 100, "scale": "public_percent_100"}},
		}],
	})
	panel.show_error("Damage calculation failed.")
	await process_frame
	var viewer_selector := content.find_child("ViewerFormeSelector", true, false) as MenuButton
	var opponent_selector := content.find_child("OpponentFormeSelector", true, false) as MenuButton
	_check(viewer_selector != null and viewer_selector.text.begins_with("Charizard"), "Errors retain the selected fainted viewer profile")
	_check(opponent_selector != null and opponent_selector.text.begins_with("Garchomp"), "Errors retain the selected opponent profile")
	_check(_has_label_text(content, "Damage calculation failed."), "Errors remain visible below the known matchup")
	panel.queue_free()
	await process_frame
	if not failed:
		print("PASS: Calcdex error state retains the selected matchup")
	quit(1 if failed else 0)


func _has_label_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_label_text(child, expected):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
