extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar_script := load("res://scripts/world/remote_player_avatar.gd") as Script
	var avatar := avatar_script.new() as Node2D
	root.add_child(avatar)
	await _check_pointer_input(avatar)
	avatar.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_pointer_input(avatar: Node2D) -> void:
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
	_check(requests == [7, 7], "touching the wild indicator forwards one spectate request")
	avatar.visible = false
	root.push_input(click, true)
	_check(requests.size() == 2, "hidden avatars cannot receive indicator clicks")
	avatar.visible = true
	avatar.apply_state(_player_state("trainer", "trainer-click-test"))
	point = indicator.get_global_transform_with_canvas() * indicator.anchor_position
	click.position = point
	root.push_input(click, true)
	_check(requests == [7, 7, 7], "NPC indicators also forward a real click")
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
