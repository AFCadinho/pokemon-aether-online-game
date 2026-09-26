extends SceneTree

class FakeDialogueBox extends Control:
	var is_open := false


class FakeUiOverlay extends Node:
	var blocked_rect := Rect2(1300, 430, 120, 140)

	func is_point_over_visible_ui(position: Vector2) -> bool:
		return blocked_rect.has_point(position)

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var battle_layer := CanvasLayer.new()
	battle_layer.name = "BattleUILayer"
	world.add_child(battle_layer)
	var battle_host := Control.new()
	battle_host.name = "BattleUIHost"
	battle_host.hide()
	battle_layer.add_child(battle_host)
	var dialogue_layer := CanvasLayer.new()
	dialogue_layer.name = "DialogueBox"
	world.add_child(dialogue_layer)
	var dialogue_box := FakeDialogueBox.new()
	dialogue_box.name = "Box"
	dialogue_layer.add_child(dialogue_box)
	var fake_ui_overlay := FakeUiOverlay.new()
	fake_ui_overlay.add_to_group("ui_overlay")
	world.add_child(fake_ui_overlay)
	var layer := load("res://scenes/interface/mobile/mobile_controls.tscn").instantiate() as CanvasLayer
	world.add_child(layer)
	var controls := layer.get_node("MobileControls") as Control
	var point := Vector2(800, 600)
	await process_frame

	_send_touch(controls, 0, point, true)
	_check(not Input.is_action_pressed("interact") and not Input.is_action_pressed("move_right"),
		"touch begins without moving or interacting")
	_send_touch(controls, 0, point, false)
	_check(Input.is_action_pressed("interact"), "short tap interacts from any world position")
	controls._process(0.13)
	_check(not Input.is_action_pressed("interact"), "tap interaction releases automatically")

	controls.set("_recent_touch_msec", -1000)
	var ui_button_point := Vector2(1360, 480)
	_send_mouse_button(controls, ui_button_point, true)
	_send_mouse_button(controls, ui_button_point, false)
	_check(not Input.is_action_pressed("interact"), "clicking visible UI is not converted into world interaction")
	_check(not bool(controls.get("_mouse_tracking")), "visible UI click does not start the floating joystick")
	_send_touch(controls, 6, ui_button_point, true)
	_send_touch(controls, 6, ui_button_point, false)
	_check(not Input.is_action_pressed("interact"), "touching visible UI is not converted into world interaction")

	controls.set("_recent_touch_msec", -1000)
	_send_mouse_button(controls, point, true)
	_check(not Input.is_action_pressed("interact"), "mouse press does not interact before release")
	_send_mouse_button(controls, point, false)
	_check(Input.is_action_pressed("interact"), "short click on free world space interacts")
	controls._process(0.13)
	_check(not Input.is_action_pressed("interact"), "mouse click interaction releases automatically")

	_send_mouse_button(controls, point, true)
	_send_mouse_motion(controls, point + Vector2.LEFT * 85.0)
	_check(Input.is_action_pressed("move_left"), "mouse drag opens the floating joystick and moves")
	_send_mouse_button(controls, point + Vector2.LEFT * 85.0, false)
	_check(not Input.is_action_pressed("move_left"), "releasing mouse drag stops movement")

	_send_touch(controls, 1, point, true)
	var touches: Dictionary = controls.get("_touches")
	var held_touch: Dictionary = touches[1]
	held_touch.started_msec = Time.get_ticks_msec() - 200
	touches[1] = held_touch
	controls.set("_touches", touches)
	controls._process(0.01)
	_check(int(controls.get("_joystick_index")) == 1, "holding a thumb opens the floating joystick")
	_send_drag(controls, 1, point + Vector2.RIGHT * 85.0)
	_check(Input.is_action_pressed("move_right"), "sliding the thumb moves right")
	_send_drag(controls, 1, point + Vector2.UP * 85.0)
	_check(Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_right"),
		"changing direction releases the previous movement")
	_send_touch(controls, 2, Vector2(1200, 480), true)
	_send_touch(controls, 2, Vector2(1200, 480), false)
	_check(Input.is_action_pressed("interact") and Input.is_action_pressed("move_up"),
		"a second finger can interact while the first moves")
	_send_touch(controls, 1, point + Vector2.UP * 85.0, false)
	_check(not Input.is_action_pressed("move_up"), "lifting the thumb stops movement")
	controls._process(0.13)
	_check(not Input.is_action_pressed("interact"), "second-finger interaction also releases")

	_send_touch(controls, 3, point, true)
	_send_drag(controls, 3, point + Vector2.LEFT * 85.0)
	_check(Input.is_action_pressed("move_left"), "dragging quickly activates movement")
	battle_host.show()
	controls._process(0.0)
	_check(not Input.is_action_pressed("move_left") and int(controls.get("_joystick_index")) == -1,
		"battle activation releases all touch movement")
	_send_touch(controls, 3, point + Vector2.LEFT * 85.0, false)
	_check(not Input.is_action_pressed("interact"), "old touch release cannot interact during battle")
	battle_host.hide()
	_send_touch(controls, 4, point, true)
	_send_drag(controls, 4, point + Vector2.DOWN * 85.0)
	_check(Input.is_action_pressed("move_down"), "movement resumes after battle")
	controls.notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	_check(not Input.is_action_pressed("move_down") and int(controls.get("_joystick_index")) == -1,
		"pausing Android releases held movement")
	_send_touch(controls, 4, point + Vector2.DOWN * 85.0, false)
	_check(not Input.is_action_pressed("interact"), "old touch release cannot interact after pause")

	_send_touch(controls, 5, point, true)
	_send_drag(controls, 5, point + Vector2.RIGHT * 85.0)
	dialogue_box.is_open = true
	controls._process(0.0)
	_check(not Input.is_action_pressed("move_right") and int(controls.get("_joystick_index")) == -1,
		"opening dialogue releases held world movement")
	_send_touch(controls, 5, point + Vector2.RIGHT * 85.0, false)
	_check(not Input.is_action_pressed("interact"), "old touch release cannot interact during dialogue")

	world.queue_free()
	await process_frame
	if failures == 0:
		print("mobile_controls_check: PASS")
	quit(failures)


func _send_touch(controls: Control, index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	if pressed:
		controls._unhandled_input(event)
	else:
		controls._input(event)


func _send_drag(controls: Control, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	controls._input(event)


func _send_mouse_button(controls: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	if pressed:
		controls._unhandled_input(event)
	else:
		controls._input(event)


func _send_mouse_motion(controls: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	controls._input(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("mobile_controls_check: %s" % message)
