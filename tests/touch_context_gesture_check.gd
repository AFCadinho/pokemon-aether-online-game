extends SceneTree

const Gesture := preload("res://scripts/ui/mobile/touch_context_gesture.gd")
var failures := 0
var events := {"tap": 0, "context": 0, "selected": 0}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(240, 100)
	root.add_child(button)
	button.pressed.connect(func() -> void: events.tap += 1)
	var menu := PopupMenu.new()
	menu.add_item("Context action")
	menu.id_pressed.connect(func(_id: int) -> void: events.selected += 1)
	root.add_child(menu)
	var gesture := Gesture.attach(button, func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			events.context += 1
			menu.position = Vector2i(120, 120)
			menu.popup()
	)
	await process_frame
	_mouse(true)
	_check(events.tap == 0 and gesture.pending, "touch press defers button activation")
	_mouse(false)
	_check(events.tap == 1 and events.context == 0, "short tap activates the existing button once")
	_mouse(true)
	gesture._process(0.51)
	_check(events.context == 1 and events.tap == 1, "holding opens the existing context action without a tap")
	_mouse(false)
	await process_frame
	_check(events.selected == 0 and events.tap == 1, "releasing a long press does not select a menu item or activate the button")
	menu.hide()
	gesture._finish()
	_mouse(true)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = Vector2(180, 150)
	motion.global_position = motion.position
	motion.relative = Vector2(60, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	gesture._process(0.51)
	_check(events.context == 1 and not gesture.pending, "moving cancels long press and hands control back to dragging")
	_mouse(false, Vector2(180, 150))
	_mouse(true)
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.pressed = true
	second_touch.position = Vector2(450, 450)
	root.push_input(second_touch, true)
	gesture._process(0.51)
	_mouse(false)
	_check(events.context == 1 and events.tap == 2, "a second finger cancels the pending context gesture")
	_mouse(true)
	button.hide()
	gesture._process(0.51)
	_mouse(false)
	_check(events.context == 1, "hidden controls cannot open a delayed menu")
	button.show()
	_mouse(true, Vector2(120, 150), 0)
	gesture._process(0.51)
	_mouse(false, Vector2(120, 150), 0)
	_check(events.tap == 3 and events.context == 1, "real mouse clicks retain their existing behavior")
	Input.set_emulate_mouse_from_touch(true)
	_native_touch(true)
	_check(gesture.pending, "native touch enters the gesture through Godot mouse emulation")
	_native_touch(false)
	_check(events.tap == 4, "native touch release activates the button exactly once")
	_native_touch(true)
	gesture._process(0.51)
	Input.flush_buffered_events()
	_native_touch(false)
	await process_frame
	_check(events.context == 2 and events.tap == 4 and events.selected == 0, "native long press and release open a menu without activating anything else")
	_check(not gesture.held, "releasing over an open popup also clears the gesture")
	menu.hide()
	_native_touch(true)
	_native_touch(false)
	_check(events.tap == 5, "the next touch after closing a context menu behaves normally")
	_native_touch(true)
	_native_touch(false, Vector2(120, 150), true)
	_check(events.tap == 5 and events.context == 2, "cancelled native touch does not activate a button")
	_native_touch(true)
	button.disabled = true
	gesture._process(0.51)
	_native_touch(false)
	_check(events.tap == 5 and events.context == 2, "a control disabled during the hold cannot activate")
	button.disabled = false
	_native_touch(true)
	gesture.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	gesture._process(0.51)
	_native_touch(false)
	_check(events.tap == 5 and events.context == 2, "focus loss cancels the hold and its release")
	button.free()
	menu.free()
	await _check_party()
	await _check_world_gesture()
	await _check_native_item_drag()
	await _check_remote_player()
	await _check_photo_touch()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func _check_party() -> void:
	var slot = load("res://scenes/interface/party_slot.tscn").instantiate()
	root.add_child(slot)
	slot.position = Vector2(100, 100)
	slot.size = Vector2(300, 100)
	var counts := {"drag": 0, "tap": 0, "context": 0}
	slot.drag_started.connect(func(_slot: int) -> void: counts.drag += 1)
	slot.clicked.connect(func(_slot: int) -> void: counts.tap += 1)
	slot.context_requested.connect(func(_slot: int, _position: Vector2) -> void: counts.context += 1)
	await process_frame
	var gesture: Node = slot.get_node("ClickButton/TouchContextGesture")
	_mouse(true)
	_check(counts.drag == 0, "party touch press does not start an immediate drag")
	gesture._process(0.51)
	_mouse(false)
	_check(counts.context == 1 and counts.tap == 0 and counts.drag == 0, "party hold requests its context menu without opening Summary or dragging")
	_mouse(true)
	_mouse(false)
	_check(counts.tap == 1 and counts.drag == 1, "party short tap retains the existing click flow")
	slot.free()

func _check_world_gesture() -> void:
	var gesture := Gesture.new()
	root.add_child(gesture)
	var counts := {"tap": 0, "context": 0}
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = Vector2(700, 400)
	gesture.begin_touch(touch, func(_position: Vector2) -> void: counts.context += 1, func() -> void: counts.tap += 1)
	gesture._process(0.51)
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	_check(counts.context == 1 and counts.tap == 0, "world-player touch hold shares the context gesture and suppresses interaction on release")
	touch.pressed = true
	gesture.begin_touch(touch, func(_position: Vector2) -> void: counts.context += 1, func() -> void: counts.tap += 1)
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	_check(counts.context == 1 and counts.tap == 1, "world-player short tap keeps the existing interaction action")
	gesture.free()

func _mouse(pressed: bool, position := Vector2(120, 150), device := InputEvent.DEVICE_ID_EMULATION) -> void:
	var event := InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func _native_touch(pressed: bool, position := Vector2(120, 150), canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.window_id = root.get_window_id()
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _native_drag(position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.window_id = root.get_window_id()
	event.position = root.get_final_transform() * position
	event.relative = root.get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _check_native_item_drag() -> void:
	var slot := HotbarBagItemSlot.new()
	slot.hotbar_item = {"id": "repel", "gameplay": {"action": "repel"}}
	slot.position = Vector2(100, 100)
	slot.size = Vector2(240, 100)
	root.add_child(slot)
	var context_requests := []
	Gesture.attach(slot, func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			context_requests.append(event)
	)
	await process_frame
	_native_touch(true)
	_native_drag(Vector2(180, 150), Vector2(60, 0))
	_native_drag(Vector2(200, 150), Vector2(20, 0))
	_check(root.gui_is_dragging() and context_requests.is_empty(), "moving an item starts Godot's existing native drag without opening its menu")
	_native_touch(false, Vector2(200, 150))
	_check(not root.gui_is_dragging(), "lifting the item finger finishes the native drag")
	slot.free()

func _check_remote_player() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var avatar = load("res://tests/support/touch_remote_avatar_probe.gd").new()
	avatar.position = Vector2(700, 400)
	avatar.presence_state = {"userId": 123, "displayName": "Touch fixture"}
	world.add_child(avatar)
	var contexts := []
	avatar.interaction_requested.connect(func(state: Dictionary, position: Vector2) -> void: contexts.append([state, position]))
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var controls = load("res://scripts/ui/mobile/mobile_controls.gd").new()
	layer.add_child(controls)
	await process_frame
	_native_touch(true, Vector2(700, 390))
	_check(avatar.touch_context_gesture != null and not controls._mouse_tracking and controls._touches.is_empty(), "touching another player reserves its context gesture before the movement pad")
	avatar.touch_context_gesture._process(0.51)
	_native_touch(false, Vector2(700, 390))
	await process_frame
	_check(contexts.size() == 1 and contexts[0][0].userId == 123 and not Input.is_action_pressed("interact"), "holding another player dispatches its existing context without world interaction")
	_native_touch(true, Vector2(700, 390))
	_native_touch(false, Vector2(700, 390))
	_check(Input.is_action_pressed("interact"), "short tapping another player preserves ordinary world interaction")
	controls._process(0.13)
	world.free()

func _check_photo_touch() -> void:
	var photo = load("res://scenes/interface/content_creator_photo_mode.tscn").instantiate()
	root.add_child(photo)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.zoom = Vector2(2, 2)
	photo.camera = camera
	photo.active = true
	photo.show()
	await process_frame
	var point := root.get_visible_rect().size - Vector2(70, 70)
	_native_touch(true, point)
	_native_drag(point - Vector2(40, 20), Vector2(-40, -20))
	_native_touch(false, point - Vector2(40, 20))
	_check(camera.position.is_equal_approx(Vector2(20, 10)) and photo.camera_touch_index == -1, "photo camera pans with one finger and releases cleanly at the current zoom")
	photo.active = false
	photo.free()
	camera.free()

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
