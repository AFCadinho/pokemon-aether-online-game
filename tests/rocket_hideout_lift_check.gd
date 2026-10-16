extends SceneTree

class RecordingExit extends Area2D:
	var entries := 0
	func _on_body_entered(_body: Node2D) -> void:
		entries += 1

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := (load("res://scenes/overworld/kanto/towns/celadon_city/rocket_hideout_b1f.tscn") as PackedScene).instantiate()
	for child: Node in map.get_node("Exits").get_children():
		if str(child.name).begins_with("LiftTo"):
			child.set_script(RecordingExit)
	root.add_child(map)
	current_scene = map
	var player := Node2D.new()
	player.name = "Player"
	player.position = Vector2(976, 1104)
	map.get_node("Entities/Players").add_child(player)
	var lift := map.get_node("Entities/Interactables/Lift")
	var game := root.get_node("GameState")
	_check(not game.is_overworld_input_locked(), "Lift starts without an input lock")
	lift._start_manual_interaction(player)
	await process_frame
	var menu := map.get_node("RocketHideoutLiftMenu")
	var dialog := menu.get_child(0) as AetherConfirmationDialog
	var choice := dialog.find_child("Floors", true, false) as OptionButton
	_check(lift.is_interacting and game.is_overworld_input_locked(), "Floor menu pauses player movement")
	_check(choice.item_count == 2 and choice.get_item_text(0) == "B2F" and choice.get_item_text(1) == "B4F", "B1F offers both other lift floors")
	dialog.canceled.emit()
	await process_frame
	await process_frame
	_check(not lift.is_interacting and not game.is_overworld_input_locked(), "Cancel releases interaction and movement locks")
	_check(map.get_node("Exits/LiftToB2F").entries == 0 and map.get_node("Exits/LiftToB4F").entries == 0, "Cancel does not travel")
	lift._start_manual_interaction(player)
	await process_frame
	menu = map.get_node("RocketHideoutLiftMenu")
	dialog = menu.get_child(0) as AetherConfirmationDialog
	choice = dialog.find_child("Floors", true, false) as OptionButton
	choice.select(1)
	dialog.confirmed.emit()
	await process_frame
	await process_frame
	_check(map.get_node("Exits/LiftToB2F").entries == 0 and map.get_node("Exits/LiftToB4F").entries == 1, "Confirmation invokes only the selected authorized exit")
	_check(not game.is_overworld_input_locked() and not lift.is_interacting, "Interaction lock is released before travel")
	for language: String in ["en", "nl"]:
		var strings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/" + language + ".json"))
		_check(strings.has("ui.rocket_hideout.lift.title") and strings.has("ui.rocket_hideout.lift.prompt"), "Localized lift menu " + language)
	current_scene = null
	map.free()
	print("ROCKET_HIDEOUT_LIFT ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
