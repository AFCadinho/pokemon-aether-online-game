extends SceneTree

const GameStateScript := preload("res://scripts/core/game_state.gd")

var failed := false


func _init() -> void:
	var state := GameStateScript.new()
	state.acquire_overworld_input_lock(&"story_sequence")
	_expect(state.is_overworld_input_locked(), "Scoped story lock blocks overworld input")
	state.unlock_overworld_input()
	_expect(
		state.is_overworld_input_locked(),
		"A legacy interaction unlock cannot release a scoped story lock"
	)
	state.release_overworld_input_lock(&"story_sequence")
	_expect(not state.is_overworld_input_locked(), "The owning story sequence releases its lock")
	state.acquire_overworld_input_lock(&"story_sequence")
	state.clear_world_runtime_state()
	_expect(not state.is_overworld_input_locked(), "Changing maps clears orphaned scoped locks")
	state.free()
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
