extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _settle() -> void:
	for frame in range(3):
		await process_frame

func _motion(point: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 900)
	root.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	await _settle()
	var start := store.position
	var handle := store.find_child("StoreDragHeader", true, false) as Control
	var pointer := handle.get_global_rect().position + Vector2(150, 30)
	_motion(pointer)
	_button(pointer, true)
	_motion(pointer + Vector2(40, 50), true)
	await _settle()
	_check(store.position.is_equal_approx(start + Vector2(40, 50)), "Dragging the heading moves the Store with the cursor")
	_button(pointer + Vector2(40, 50), false)
	var released := store.position
	_motion(pointer + Vector2(80, 80))
	_check(store.position == released, "Releasing the mouse stops dragging")
	store._fit_store_window()
	await _settle()
	var info_point := store.currency_info_button.get_global_rect().get_center()
	_motion(info_point)
	_button(info_point, true)
	_button(info_point, false)
	await _settle()
	_check(store.currency_info_dialog != null and store.currency_info_dialog.visible and not store.store_dragging, "Header information button opens without dragging")
	store._hide_currency_info()
	host.position = Vector2(24, 36)
	host.scale = Vector2.ONE * 1.25
	await _settle()
	start = store.position
	pointer = handle.get_global_rect().position + Vector2(180, 35)
	_motion(pointer)
	_button(pointer, true)
	_motion(pointer + Vector2(50, 50), true)
	await _settle()
	_check(store.position.is_equal_approx(start + Vector2(40, 40)), "Dragging respects the parent UI scale")
	_motion(Vector2(10000, -10000), true)
	await _settle()
	var footprint := Rect2(store.position, store.size * store.scale)
	_check(Rect2(Vector2.ZERO, host.size).encloses(footprint), "Dragging beyond screen edges keeps the whole Store visible")
	_button(Vector2(10000, -10000), false)
	host.size = Vector2(800, 600)
	await _settle()
	footprint = Rect2(store.position, store.size * store.scale)
	_check(Rect2(Vector2.ZERO, host.size).encloses(footprint), "Resizing keeps the scaled Store inside the screen")
	store.store_dragging = true
	store.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(not store.store_dragging, "Losing window focus ends dragging")
	host.scale = Vector2.ONE
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 900)
	await _settle()
	var close_button: Button
	for button in handle.find_children("*", "Button", true, false):
		if button.text == "×":
			close_button = button
	var close_point := close_button.get_global_rect().get_center()
	_motion(close_point)
	_button(close_point, true)
	_button(close_point, false)
	_check(not store.visible and not store.store_dragging, "Header close button still closes the Store")
	store.show()
	store.store_dragging = true
	store.close_store()
	_check(not store.store_dragging, "Closing the Store ends dragging")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
