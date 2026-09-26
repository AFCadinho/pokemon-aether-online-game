extends SceneTree

const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	var dialogue_scene := load(DIALOGUE_BOX_SCENE_PATH) as PackedScene
	var dialogue_layer := dialogue_scene.instantiate()
	root.add_child(dialogue_layer)
	await process_frame
	var dialogue_box := dialogue_layer.get_node("Box")

	game_state.unlock_input()
	game_state.lock_overworld_input()
	dialogue_box.start_dialogue(["First", "Second"], "Oak")
	_check(bool(game_state.input_locked), "open dialogue locks all input")
	_check(
		dialogue_box.has_method("_input"),
		"dialogue box listens for left mouse input alongside the interaction key"
	)
	dialogue_box.set("touch_input_enabled", true)
	dialogue_box.set("just_started", false)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	dialogue_box._input(touch)
	_check(int(dialogue_box.get("current_line_index")) == 1,
		"one touch advances one dialogue line")
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	dialogue_box._input(emulated_mouse)
	_check(int(dialogue_box.get("current_line_index")) == 1,
		"emulated mouse click does not advance a second line on mobile")
	dialogue_box.hide_dialogue()
	_check(
		not bool(game_state.input_locked)
		and bool(game_state.overworld_input_locked)
		and not bool(game_state.ui_input_locked),
		"closing dialogue preserves its caller's overworld lock"
	)

	dialogue_box.hide_dialogue()
	_check(
		bool(game_state.overworld_input_locked),
		"closing an already closed dialogue cannot release another owner's lock"
	)

	game_state.unlock_input()
	game_state.lock_input()
	dialogue_box.start_dialogue(["Sequence"], "Oak")
	dialogue_box.hide_dialogue()
	_check(
		bool(game_state.input_locked)
		and bool(game_state.overworld_input_locked)
		and bool(game_state.ui_input_locked),
		"closing dialogue preserves a full story-sequence lock"
	)

	game_state.unlock_input()
	game_state.acquire_ui_input_lock(&"story_sequence")
	dialogue_box.start_dialogue(["Owned UI lock"], "Oak")
	dialogue_box.hide_dialogue()
	_check(
		not bool(game_state.input_locked)
		and bool(game_state.ui_input_locked),
		"closing dialogue preserves an owner-based UI lock"
	)
	game_state.release_ui_input_lock(&"story_sequence")
	_check(
		not bool(game_state.ui_input_locked),
		"releasing the final UI lock owner restores mouse input"
	)

	game_state.unlock_input()
	dialogue_layer.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
