extends SceneTree

class FakeHost extends Node2D:
	var dialogue_calls := 0
	var preflight_calls := 0
	var preflight_success := true

	func prepare_story_sequence() -> Dictionary:
		preflight_calls += 1
		return {"success": preflight_success}

	func show_dialogue(_lines: Array[String], _speaker_name := "") -> bool:
		dialogue_calls += 1
		return true


var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var runner_script := load("res://tests/fixtures/fake_story_sequence_runner.gd") as GDScript
	var runner := runner_script.new() as Node
	root.add_child(runner)
	runner.delay_frames = 4
	runner.replies = {
		"first": [
			{"success": false, "status": 0},
			_valid_dialogue("first"),
		],
		"second": [_valid_dialogue("second")],
	}
	var loaded: Dictionary = await runner._preload_dialogues([
		{"type": "dialogue", "dialogueId": "first"},
		{"type": "dialogue", "dialogueId": "second"},
		{"type": "dialogue", "dialogueId": "first"},
	])
	_check(bool(loaded.get("success", false)), "delayed story dialogues preload successfully")
	_check(runner.calls.get("first") == 2 and runner.calls.get("second") == 1,
		"temporary failure retries once and duplicate dialogue downloads once")

	runner.calls.clear()
	runner.replies = {"missing": [{"success": false, "status": 404}]}
	var host := FakeHost.new()
	root.add_child(host)
	var game_state := root.get_node("GameState")
	var before_lock: bool = game_state.input_locked
	var rejected: Dictionary = await runner.run_sequence([
		{"type": "dialogue", "dialogueId": "missing"},
	], host)
	_check(not bool(rejected.get("success", false)) and int(rejected.get("actionIndex", -1)) == 0,
		"missing dialogue fails before the cinematic begins")
	_check(runner.calls.get("missing") == 1 and host.dialogue_calls == 0,
		"permanent failure does not retry or present a partial scene")
	_check(game_state.input_locked == before_lock, "failed preflight restores the input lock")
	runner.calls.clear()
	runner.replies = {"ready": [_valid_dialogue("ready")]}
	host.preflight_success = false
	var missing_starter: Dictionary = await runner.run_sequence([
		{"type": "dialogue", "dialogueId": "ready"},
	], host)
	_check(str(missing_starter.get("status", "")) == "host_preflight_failed" and host.dialogue_calls == 0,
		"future starter failure stops the scene before any dialogue or cinematic")
	_check(host.preflight_calls == 1 and game_state.input_locked == before_lock,
		"host preflight failure restores input for a later retry")
	var controller_script := load("res://scripts/world/story/mt_moon_ambush_controller.gd") as GDScript
	var controller := controller_script.new() as Node2D
	_check(bool(controller.call("_has_starter_final_evolution", {
		"selectedSpeciesId": "bulbasaur",
		"choices": [{"speciesId": "bulbasaur", "evolutionPaths": [[
			{"speciesId": "bulbasaur"}, {"speciesId": "venusaur"},
		]]}],
	})), "Mt. Moon accepts an available final starter evolution")
	_check(not bool(controller.call("_has_starter_final_evolution", {
		"selectedSpeciesId": "bulbasaur", "choices": [],
	})), "Mt. Moon rejects missing starter data before the cinematic")
	controller.free()
	host.queue_free()
	runner.queue_free()
	print("story_dialogue_preflight_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _valid_dialogue(dialogue_id: String) -> Dictionary:
	return {"success": true, "metadata": {
		"id": dialogue_id, "dialogueId": dialogue_id, "lines": ["A line"],
	}}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		printerr("FAIL ", label)
