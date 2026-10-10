extends Node

# Only touch-generated mouse events enter this gesture. Real mouse clicks retain
# their existing timing. Delaying the left press keeps buttons and custom party/
# PC drags idle until we know whether this is a tap, drag, or context request.
const HOLD_SECONDS := 0.5
const MOVE_TOLERANCE := 10.0
const CONTEXT_RELEASE_DEVICE := -37

var target: Control
var input_handler: Callable
var context_handler: Callable
var tap_handler: Callable
var pending := false
var held := false
var cancelled := false
var tracking_touch := false
var touch_index := -1
var start_position := Vector2.ZERO
var duration := 0.0
var context_windows: Array[Window] = []


static func attach(control: Control, handler: Callable) -> Node:
	var existing := control.get_node_or_null("TouchContextGesture")
	if existing != null:
		existing.input_handler = handler
		return existing
	var gesture := load("res://scripts/ui/mobile/touch_context_gesture.gd").new() as Node
	gesture.name = "TouchContextGesture"
	gesture.target = control
	gesture.input_handler = handler
	control.add_child(gesture)
	control.gui_input.connect(gesture._on_gui_input)
	return gesture


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			start_position = target.get_global_transform_with_canvas() * mouse.position
			_begin()
			target.accept_event()
			return
	input_handler.call(event)


# World-player hit testing runs before the mobile movement pad. It shares the
# same timer/cancellation rules, but a short tap keeps the world's interact action.
func begin_touch(event: InputEventScreenTouch, on_context: Callable, on_tap: Callable) -> void:
	tracking_touch = true
	touch_index = event.index
	start_position = event.position
	context_handler = on_context
	tap_handler = on_tap
	_begin()


func _begin() -> void:
	if not tracking_touch:
		touch_index = -1
	pending = true
	held = false
	cancelled = false
	duration = 0.0
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if not pending:
		return
	if target != null and (not target.is_visible_in_tree() or (target is BaseButton and target.disabled)):
		pending = false
		cancelled = true
		return
	duration += delta
	if duration < HOLD_SECONDS:
		return
	pending = false
	held = true
	# Clear the engine's emulated left-button state before opening a PopupMenu.
	# Otherwise its opening-button release could immediately select a menu item.
	var release := _mouse_event(MOUSE_BUTTON_LEFT, false)
	release.device = CONTEXT_RELEASE_DEVICE
	release.window_id = get_window().get_window_id()
	release.position = get_viewport().get_final_transform() * start_position
	release.global_position = release.position
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	if not held:
		return
	if tracking_touch:
		context_handler.call(start_position)
	else:
		input_handler.call(_local_context_event())
	_watch_context_release()


func _watch_context_release() -> void:
	# A PopupMenu owns a separate Viewport, so the original Control's _input
	# may never see the opening finger lift. Observe that window as well.
	context_windows.append(get_window())
	for node: Node in get_tree().root.find_children("*", "Window", true, false):
		var window := node as Window
		if window.visible and window != get_window():
			context_windows.append(window)
	for window: Window in context_windows:
		window.window_input.connect(_on_context_window_input)


func _on_context_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Keep suppression active through this event's GUI propagation.
		_finish.call_deferred()
	elif event is InputEventScreenTouch and not event.pressed and event.index == touch_index:
		_finish.call_deferred()


func _input(event: InputEvent) -> void:
	if event.device == CONTEXT_RELEASE_DEVICE:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Godot dispatches the emulated mouse press before its native touch.
			# Associate that first touch with this gesture; later fingers cancel it.
			if not tracking_touch and touch_index == -1 and touch.position.distance_to(start_position) <= MOVE_TOLERANCE:
				touch_index = touch.index
				return
			pending = false
			cancelled = true
		elif touch.canceled or (not tracking_touch and touch.position.distance_to(start_position) > MOVE_TOLERANCE):
			pending = false
			cancelled = true
		if not touch.pressed and tracking_touch and touch.index == touch_index:
			get_viewport().set_input_as_handled()
			if pending and not touch.canceled:
				tap_handler.call()
			pending = false
			cancelled = true
			# Keep swallowing the paired emulated mouse release for this frame.
			_finish.call_deferred()
		return
	if tracking_touch and event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_index:
			if drag.position.distance_to(start_position) > MOVE_TOLERANCE:
				pending = false
				cancelled = true
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouse or event.device != InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		if pending and not tracking_touch and event.position.distance_to(start_position) > MOVE_TOLERANCE:
			# Hand the original press back to Godot, then let this motion and its
			# release use the existing native/custom drag path.
			_finish()
			get_viewport().push_input(_mouse_event(MOUSE_BUTTON_LEFT, true), true)
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if tracking_touch:
			# The native touch release follows this emulated release and decides
			# whether a short world tap should interact.
			get_viewport().set_input_as_handled()
			return
		var was_tap: bool = pending and not tracking_touch and not event.canceled
		var position: Vector2 = event.position
		_finish()
		if was_tap:
			get_viewport().push_input(_mouse_event(MOUSE_BUTTON_LEFT, true), true)
			var release := _mouse_event(MOUSE_BUTTON_LEFT, false)
			release.position = position
			release.global_position = position
			get_viewport().push_input(release, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# A fresh primary press also recovers a gesture whose lift was lost
		# during an OS focus change or a closed popup.
		_finish()


func _mouse_event(button: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = start_position
	event.global_position = start_position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	return event


func _local_context_event() -> InputEventMouseButton:
	var event := _mouse_event(MOUSE_BUTTON_RIGHT, true)
	event.position = target.get_global_transform_with_canvas().affine_inverse() * start_position
	event.global_position = target.get_global_transform() * event.position
	return event


func _finish() -> void:
	for window: Window in context_windows:
		if is_instance_valid(window) and window.window_input.is_connected(_on_context_window_input):
			window.window_input.disconnect(_on_context_window_input)
	context_windows.clear()
	pending = false
	held = false
	cancelled = false
	tracking_touch = false
	set_process(false)
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pending = false
		cancelled = true
