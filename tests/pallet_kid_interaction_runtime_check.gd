extends Node2D

const PALLET_SCENE := preload("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
const DIALOGUE_SCENE := preload("res://scripts/ui/dialogue_box.tscn")
const CLOSE_SETTLE_SECONDS := 0.35
const WAIT_TIMEOUT_SECONDS := 2.0

class DummyPlayer:
	extends Node2D
	var last_direction := Vector2.UP

	func get_feet_position() -> Vector2:
		return global_position

	func face_world_position(world_position: Vector2) -> void:
		var delta := world_position - global_position
		last_direction = (
			Vector2(sign(delta.x), 0.0)
			if absf(delta.x) > absf(delta.y)
			else Vector2(0.0, sign(delta.y))
		)

var failed := false
var dialogue_finished_count := 0


func _ready() -> void:
	await _run_check()
	get_tree().quit(1 if failed else 0)


func _run_check() -> void:
	var map := PALLET_SCENE.instantiate()
	map.name = "CurrentMap"
	var leo := map.get_node("Entities/NPCs/PlayFamilyChild") as SynchronizedPlaymateNPC
	var pikachu := map.get_node("Entities/Pokemon/Pikachu") as BaseNPC
	leo.npc_id = ""
	leo.npc_definition_id = ""
	leo.npc_metadata_id = ""
	var test_lines: Array[String] = ["Come on, Pikachu! Up and down—keep up with me!"]
	leo.dialogue_lines = test_lines
	add_child(map)

	var player := DummyPlayer.new()
	player.name = "Player"
	player.global_position = leo.global_position + Vector2(0.0, 32.0)
	add_child(player)
	leo.player_nearby = true
	leo.nearby_player = player

	var dialogue_layer := DIALOGUE_SCENE.instantiate()
	dialogue_layer.name = "DialogueBox"
	add_child(dialogue_layer)
	var dialogue_box := dialogue_layer.get_node("Box")
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	await get_tree().process_frame
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await _wait_until(func() -> bool: return bool(dialogue_box.is_open), WAIT_TIMEOUT_SECONDS)
	_check(bool(dialogue_box.is_open), "Pallet Kid dialogue opens")
	_check(bool(leo.is_interacting), "Pallet Kid owns one active interaction")

	var frozen_position := leo.global_position
	pikachu.global_position += Vector2(0.0, 32.0)
	await get_tree().process_frame
	_check(leo.global_position == frozen_position, "Pallet Kid stays in place while talking")

	# Let DialogueBox consume its just-started guard before closing the one-line
	# dialogue with the same action used by the live client.
	await get_tree().process_frame
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().create_timer(CLOSE_SETTLE_SECONDS).timeout

	_check(not bool(dialogue_box.is_open), "Pallet Kid dialogue stays closed")
	_check(not bool(leo.is_interacting), "Pallet Kid releases interaction ownership")
	_check(dialogue_finished_count == 1, "Pallet Kid completes exactly one dialogue cycle")
	_check(not GameState.is_overworld_input_locked(), "Pallet Kid restores overworld input")
	_check(
		leo.global_position == pikachu.global_position + leo.movement_offset,
		"Pallet Kid resumes following Pikachu after dialogue"
	)


func _wait_until(predicate: Callable, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _on_dialogue_finished() -> void:
	dialogue_finished_count += 1


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
