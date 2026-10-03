extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar_script := load("res://scripts/world/remote_player_avatar.gd") as Script
	var avatar := avatar_script.new() as Node2D
	root.add_child(avatar)
	var mobile := load("res://scripts/ui/mobile/mobile_controls.gd").new() as Control
	root.add_child(mobile)
	await _check_pointer_input(avatar, mobile)
	_check(not mobile.get("_mouse_tracking") and (mobile.get("_touches") as Dictionary).is_empty(), "spectate presses do not start movement or interact tracking")
	mobile.queue_free()
	avatar.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_pointer_input(avatar: Node2D, mobile: Control) -> void:
	avatar.apply_state(_player_state("wild", "wild-click-test"))
	await process_frame
	var indicator := avatar.nearby_battle_indicator as Node2D
	var requests: Array[int] = []
	avatar.battle_spectate_requested.connect(func(user_id: int): requests.append(user_id))
	var previous_picking := root.physics_object_picking
	var previous_transform := root.canvas_transform
	root.physics_object_picking = false
	root.canvas_transform = Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(300, 240))
	var point: Vector2 = indicator.get_global_transform_with_canvas() * indicator.anchor_position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	_check(not mobile.get("_mouse_tracking"), "spectate click takes priority over tap/drag movement")
	_check(requests == [7], "wild indicator forwards a real click without physics picking under camera zoom")
	click.pressed = false
	root.push_input(click, true)
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(click, true)
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point + Vector2(150, 0)
	root.push_input(click, true)
	_check(requests.size() == 1, "release, right click and clicks outside the indicator do not spectate")
	_check(bool(mobile.get("_mouse_tracking")), "clicking outside the indicator still starts tap/drag movement")
	click.pressed = false
	root.push_input(click, true)
	click.pressed = true

	var blocker := Control.new()
	blocker.position = point - Vector2(40, 40)
	blocker.size = Vector2(80, 80)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(blocker)
	await process_frame
	click.position = point
	root.push_input(click, true)
	_check(requests.size() == 1, "an interface window blocks spectating through it")
	layer.queue_free()
	await process_frame

	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = true
	root.push_input(touch, true)
	_check((mobile.get("_touches") as Dictionary).is_empty(), "spectate touch does not start joystick tracking")
	_check(requests == [7, 7], "touching the wild indicator forwards one spectate request")
	avatar.visible = false
	root.push_input(click, true)
	_check(requests.size() == 2, "hidden avatars cannot receive indicator clicks")
	click.pressed = false
	root.push_input(click, true)
	click.pressed = true
	avatar.visible = true
	avatar.apply_state(_player_state("trainer", "trainer-click-test"))
	point = indicator.get_global_transform_with_canvas() * indicator.anchor_position
	click.position = point
	root.push_input(click, true)
	_check(requests == [7, 7, 7], "NPC indicators also forward a real click")
	root.physics_object_picking = true
	root.push_input(click, true)
	await physics_frame
	await process_frame
	_check(requests == [7, 7, 7, 7], "enabled physics picking does not duplicate spectate requests with movement controls")
	root.physics_object_picking = previous_picking
	root.canvas_transform = previous_transform


func _player_state(kind: String, battle_id: String) -> Dictionary:
	return {
		"userId": 7, "username": "Admin", "displayName": "Admin",
		"mapId": "route_25", "position": {"x": 64.0, "y": 64.0},
		"facingDirection": "down", "appearance": {"body": "Red"},
		"activityState": "battle", "battleSpectate": {"kind": kind, "battleId": battle_id},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failed = true
	push_error("FAIL: %s" % label)
