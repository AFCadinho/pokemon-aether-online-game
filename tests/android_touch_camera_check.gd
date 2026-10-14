extends "res://tests/battle_move_effects_3d_check.gd"
const Gesture = preload("res://scripts/battle/battle_ui/immersive_camera_input.gd")
class BattleFixture extends Control:
	var animation_router: Dictionary
	var battle_stage: Control
var gesture: Node

func touch(index: int, point: Vector2, down := true, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	event.canceled = canceled
	gesture._input(event)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	gesture._input(event)

func _run() -> void:
	_setup()
	SettingsManager.battle_presentation_mode = "3d"
	var host := Control.new()
	add_child(host)
	var cover := ColorRect.new()
	cover.name = "Cover"
	host.add_child(cover)
	cover.hide()
	var content := Control.new()
	host.add_child(content)
	var battle := BattleFixture.new()
	content.add_child(battle)
	battle.animation_router = {"model_presenter": stage}
	battle.battle_stage = Control.new()
	battle.add_child(battle.battle_stage)
	battle.battle_stage.size = Vector2(800, 600)
	var reset := Button.new()
	reset.name = "ResetCameraButton"
	battle.battle_stage.add_child(reset)
	reset.position = Vector2(700, 0)
	reset.size = Vector2(100, 60)
	gesture = Gesture.new()
	gesture.battle = battle
	battle.add_child(gesture)
	gesture.set_process_input(false)
	touch(0, Vector2(300, 200))
	drag(0, Vector2(320, 210))
	assert(is_equal_approx(stage.user_camera_yaw, -0.12))
	var yaw: float = stage.user_camera_yaw
	touch(1, Vector2(420, 210))
	drag(1, Vector2(520, 210))
	assert(is_equal_approx(stage.user_camera_zoom, stage.camera_zoom_limits().x), "Spreading fingers zooms in and clamps")
	assert(stage.user_camera_yaw == yaw, "Pinching does not orbit")
	drag(1, Vector2(345, 210))
	assert(stage.user_camera_zoom == stage.camera_zoom_limits().y, "Closing fingers zooms out and clamps")
	touch(1, Vector2(345, 210), false)
	drag(0, Vector2(400, 250))
	assert(stage.user_camera_yaw == yaw, "Remaining finger does not jump after a pinch")
	touch(0, Vector2(400, 250), false)
	touch(0, Vector2(300, 200))
	var synthetic := InputEventMouseMotion.new()
	synthetic.device = InputEvent.DEVICE_ID_EMULATION
	synthetic.relative = Vector2(100, 0)
	gesture._input(synthetic)
	assert(stage.user_camera_yaw == yaw, "Touch mouse emulation never applies a second orbit")
	touch(0, Vector2(300, 200), false, true)
	assert(gesture.touches.is_empty() and not gesture.touch_active)
	touch(0, Vector2(750, 20))
	drag(0, Vector2(400, 250))
	assert(stage.user_camera_yaw == yaw, "Camera reset button retains its touch")
	touch(0, Vector2(400, 250), false)
	cover.show()
	touch(0, Vector2(300, 200))
	assert(not gesture.touch_active, "Loading cover blocks gestures")
	touch(0, Vector2(300, 200), false)
	cover.hide()
	stage.current_actions[2] = "physical_attack"
	touch(0, Vector2(300, 200))
	assert(not gesture.touch_active, "A partner attack also locks the camera")
	touch(0, Vector2(300, 200), false)
	stage.current_actions[2] = "idle"
	touch(0, Vector2(300, 200))
	touch(1, Vector2(400, 200))
	touch(2, Vector2(500, 200))
	assert(not gesture.touch_active, "Third finger suspends the gesture")
	gesture._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(gesture.touches.is_empty() and not gesture.dragging)
	# Mouse wheel remains available on desktop.
	stage.reset_user_camera()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(300, 200)
	gesture._input(wheel)
	assert(is_equal_approx(stage.user_camera_zoom, 0.54), "Wheel zoom works from the shared close-up default")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	gesture._input(wheel)
	assert(is_equal_approx(stage.user_camera_zoom, 0.60))
	host.queue_free()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ANDROID_TOUCH_CAMERA_PASS pinch=true orbit=true clamps=true ui=true cancel=true desktop=true")
	get_tree().quit()
