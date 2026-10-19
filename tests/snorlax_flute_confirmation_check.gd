extends SceneTree

class WorldProbe extends Node2D:
	var calls: Array = []
	var battle_started_locked := false
	func start_triggered_wild_battle_for_area(area: String, kind: String, species: String, retry: bool, id: String) -> void:
		battle_started_locked = get_node("/root/GameState").is_overworld_input_locked()
		calls.append([area, kind, species, retry, id])

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := WorldProbe.new()
	root.add_child(world)
	current_scene = world
	world.add_to_group("world")
	var encounter: Node2D = load("res://tests/fixtures/snorlax_encounter_probe.gd").new()
	encounter.display_name = "Snorlax"
	encounter.encounter_id = "snorlax_route_12"
	encounter.encounter_area_id = "kanto_route_12"
	world.add_child(encounter)
	var game := root.get_node("GameState")
	await encounter._start_manual_interaction(null)
	_check(encounter.spoken.size() == 1 and world.calls.is_empty(), "Without flute: sleeping dialogue, no battle")
	_check(world.get_node_or_null("SnorlaxFluteConfirmation") == null and not game.is_overworld_input_locked(), "Without flute: no confirmation or leaked input lock")
	encounter.can_awaken = true
	encounter.spoken.clear()
	encounter._start_manual_interaction(null)
	await process_frame
	var dialog := world.get_node("SnorlaxFluteConfirmation").get_child(0) as AetherConfirmationDialog
	_check(dialog.visible and dialog.message_label.text.contains("Snorlax"), "Owning the flute opens the real confirmation dialog")
	_check(game.is_overworld_input_locked() and world.calls.is_empty(), "Confirmation owns input and waits before starting battle")
	encounter._start_manual_interaction(null)
	_check(world.get_child_count() == 2, "Repeated interaction cannot open a second prompt")
	dialog.cancel_button.pressed.emit()
	await process_frame
	_check(world.calls.is_empty() and encounter.spoken.is_empty() and not encounter.completed, "No keeps Snorlax asleep without an awakening or battle")
	_check(not game.is_overworld_input_locked() and not encounter.is_interacting, "No restores interaction and movement")
	encounter._start_manual_interaction(null)
	await process_frame
	dialog = world.get_node("SnorlaxFluteConfirmation").get_child(0) as AetherConfirmationDialog
	dialog.confirm_button.pressed.emit()
	await process_frame
	_check(world.calls == [["kanto_route_12", "static", "", true, "snorlax_route_12"]], "Yes starts the trusted static wild battle for Route 12 Snorlax")
	_check(encounter.spoken.size() == 1 and encounter.spoken[0].size() == 2, "Yes presents played-flute and awakening dialogue")
	_check(not world.battle_started_locked and not game.is_overworld_input_locked(), "Interaction releases input before the battle handoff")
	_check(not encounter.completed, "Starting a battle does not prematurely remove Snorlax")
	encounter._start_manual_interaction(null)
	await process_frame
	dialog = world.get_node("SnorlaxFluteConfirmation").get_child(0) as AetherConfirmationDialog
	dialog.close_button.pressed.emit()
	await process_frame
	_check(world.calls.size() == 1 and not game.is_overworld_input_locked(), "Closing the prompt cancels safely")
	encounter._start_manual_interaction(null)
	await process_frame
	encounter.queue_free()
	await process_frame
	await process_frame
	_check(world.get_node_or_null("SnorlaxFluteConfirmation") == null and not game.is_overworld_input_locked(), "Removing the actor closes its prompt and releases input")
	world.queue_free()
	await process_frame
	print("SNORLAX_FLUTE_CONFIRMATION: %d failures" % failures)
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)
