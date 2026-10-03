extends Control

const HOLD_MSEC := 150
const DRAG_START_DISTANCE := 28.0
const DEAD_ZONE := 24.0
const PAD_RADIUS := 108.0
const KNOB_TRAVEL := 58.0
const INTERACT_PULSE_SECONDS := 0.12

var _touches: Dictionary = {}
var _joystick_index := -1
var _joystick_center := Vector2.ZERO
var _move_action := ""
var _interact_time_left := 0.0
var _mouse_tracking := false
var _mouse_start := Vector2.ZERO
var _mouse_position := Vector2.ZERO
var _mouse_started_msec := 0
var _mouse_joystick_active := false
var _recent_touch_msec := -1000


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all()


func _process(delta: float) -> void:
	if not _controls_available():
		_release_all()
		return
	if _interact_time_left > 0.0:
		_interact_time_left = maxf(_interact_time_left - delta, 0.0)
		if _interact_time_left == 0.0:
			Input.action_release("interact")
	if _joystick_index != -1:
		return
	var now := Time.get_ticks_msec()
	if _mouse_tracking and not _mouse_joystick_active and now - _mouse_started_msec >= HOLD_MSEC:
		_activate_mouse_joystick()
	for index: int in _touches:
		var touch: Dictionary = _touches[index]
		if now - int(touch.started_msec) >= HOLD_MSEC:
			_activate_joystick(index)
			break


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_available():
		return
	# These controls run before world actors and consume pointer presses for
	# tap/drag movement. Offer nearby spectate targets the press first.
	if _try_nearby_battle_spectate(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_recent_touch_msec = Time.get_ticks_msec()
		if (
			not touch.pressed
			or _touches.has(touch.index)
			or _is_pointer_over_visible_ui(touch.position)
		):
			return
		_touches[touch.index] = {
			"start": touch.position,
			"position": touch.position,
			"started_msec": _recent_touch_msec,
		}
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if (
			mouse_button.button_index != MOUSE_BUTTON_LEFT
			or not mouse_button.pressed
			or _mouse_tracking
			or _is_pointer_over_visible_ui(mouse_button.position)
			or Time.get_ticks_msec() - _recent_touch_msec < HOLD_MSEC
		):
			return
		_mouse_tracking = true
		_mouse_start = mouse_button.position
		_mouse_position = mouse_button.position
		_mouse_started_msec = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()


func _try_nearby_battle_spectate(event: InputEvent) -> bool:
	var screen_position: Vector2
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return false
		screen_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			return false
		screen_position = touch_event.position
	else:
		return false
	if _is_pointer_over_visible_ui(screen_position):
		return false
	for indicator in get_tree().get_nodes_in_group("nearby_pve_battle_indicators"):
		if indicator.get_viewport() != get_viewport():
			continue
		if bool(indicator.call("try_spectate_at_screen_position", screen_position, "mobile_controls")):
			return true
	return false


func _is_pointer_over_visible_ui(position: Vector2) -> bool:
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	return (
		overlay != null
		and overlay.has_method("is_point_over_visible_ui")
		and bool(overlay.call("is_point_over_visible_ui", position))
	)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_tracking:
		var motion := event as InputEventMouseMotion
		_mouse_position = motion.position
		if not _mouse_joystick_active and motion.position.distance_to(_mouse_start) >= DRAG_START_DISTANCE:
			_activate_mouse_joystick()
		if _mouse_joystick_active:
			_set_move_action(_direction_for(motion.position - _joystick_center))
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and _mouse_tracking:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
			return
		_mouse_position = mouse_button.position
		if not _mouse_joystick_active and Time.get_ticks_msec() - _mouse_started_msec >= HOLD_MSEC:
			_activate_mouse_joystick()
		if _mouse_joystick_active:
			_set_move_action("")
			_mouse_joystick_active = false
			_joystick_index = -1
			queue_redraw()
		elif mouse_button.position.distance_to(_mouse_start) < DRAG_START_DISTANCE:
			_pulse_interact()
		_mouse_tracking = false
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_recent_touch_msec = Time.get_ticks_msec()
		if not _touches.has(drag.index):
			return
		var touch: Dictionary = _touches[drag.index]
		touch.position = drag.position
		_touches[drag.index] = touch
		if _joystick_index == -1 and drag.position.distance_to(touch.start) >= DRAG_START_DISTANCE:
			_activate_joystick(drag.index)
		if _joystick_index == drag.index:
			_set_move_action(_direction_for(drag.position - _joystick_center))
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var release := event as InputEventScreenTouch
		_recent_touch_msec = Time.get_ticks_msec()
		if release.pressed or not _touches.has(release.index):
			return
		var touch: Dictionary = _touches[release.index]
		if _joystick_index == release.index:
			_set_move_action("")
			_joystick_index = -1
			queue_redraw()
		elif release.position.distance_to(touch.start) < DRAG_START_DISTANCE:
			_pulse_interact()
		_touches.erase(release.index)
		get_viewport().set_input_as_handled()


func _controls_available() -> bool:
	var battle_host := get_node_or_null("../../BattleUILayer/BattleUIHost") as Control
	if battle_host != null and battle_host.visible:
		return false
	var dialogue_box := get_node_or_null("../../DialogueBox/Box") as Control
	if dialogue_box != null and dialogue_box.get("is_open") == true:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit)


func _activate_joystick(index: int) -> void:
	if _joystick_index != -1 or _mouse_joystick_active or not _touches.has(index):
		return
	_joystick_index = index
	var touch: Dictionary = _touches[index]
	_joystick_center = touch.start
	_set_move_action(_direction_for(touch.position - _joystick_center))
	queue_redraw()


func _activate_mouse_joystick() -> void:
	if _mouse_joystick_active or _joystick_index != -1 or not _mouse_tracking:
		return
	_mouse_joystick_active = true
	_joystick_center = _mouse_start
	_set_move_action(_direction_for(_mouse_position - _joystick_center))
	queue_redraw()


func _direction_for(delta: Vector2) -> String:
	if delta.length() < DEAD_ZONE:
		return ""
	if absf(delta.x) > absf(delta.y):
		return "move_right" if delta.x > 0.0 else "move_left"
	return "move_down" if delta.y > 0.0 else "move_up"


func _set_move_action(action: String) -> void:
	if _move_action == action:
		return
	if _move_action != "":
		Input.action_release(_move_action)
	_move_action = action
	if _move_action != "":
		Input.action_press(_move_action)


func _pulse_interact() -> void:
	if _interact_time_left == 0.0:
		Input.action_press("interact")
	_interact_time_left = INTERACT_PULSE_SECONDS


func _release_all() -> void:
	var had_joystick := _joystick_index != -1 or _mouse_joystick_active
	_set_move_action("")
	if _interact_time_left > 0.0:
		Input.action_release("interact")
		_interact_time_left = 0.0
	_touches.clear()
	_mouse_tracking = false
	_mouse_joystick_active = false
	_joystick_index = -1
	if had_joystick:
		queue_redraw()


func _draw() -> void:
	var center := Vector2.ZERO
	var point := Vector2.ZERO
	if _mouse_joystick_active:
		center = _joystick_center
		point = _mouse_position
	elif _joystick_index != -1 and _touches.has(_joystick_index):
		center = _joystick_center
		var touch: Dictionary = _touches[_joystick_index]
		point = touch.position
	else:
		return
	var knob: Vector2 = center + (point - center).limit_length(KNOB_TRAVEL)
	draw_circle(center, PAD_RADIUS, Color(0.04, 0.08, 0.15, 0.63))
	draw_arc(center, PAD_RADIUS - 2.0, 0.0, TAU, 64, Color(0.57, 0.78, 1.0, 0.82), 3.0)
	draw_circle(center, 73.0, Color(0.17, 0.3, 0.48, 0.45))
	draw_circle(knob, 43.0, Color(0.3, 0.47, 0.72, 0.88))
	draw_arc(knob, 41.0, 0.0, TAU, 48, Color(0.8, 0.9, 1.0, 0.95), 2.5)
