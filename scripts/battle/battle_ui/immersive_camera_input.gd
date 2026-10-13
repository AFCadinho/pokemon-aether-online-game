extends Node
var battle: Control
var dragging := false
var touches := {}
var touch_active := false
var pinch_distance := 0.0

func _presenter() -> Node:
	return battle.animation_router.model_presenter if is_instance_valid(battle) else null

func _zoom_by(presenter: Node, factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0: return
	var limits: Vector2 = presenter.camera_zoom_limits()
	presenter.user_camera_zoom = clampf(presenter.user_camera_zoom * factor, limits.x, limits.y)

func _rotate_by(presenter: Node, delta: Vector2) -> void:
	presenter.user_camera_yaw = wrapf(presenter.user_camera_yaw - delta.x * 0.006, -PI, PI)
	presenter.user_camera_pitch = clampf(presenter.user_camera_pitch - delta.y * 0.004, -0.12, 0.65)

func _clear_pointer() -> void:
	dragging = false
	touches.clear()
	touch_active = false
	pinch_distance = 0.0

func _may_rotate(presenter: Node) -> bool:
	if get_node("/root/SettingsManager").battle_presentation_mode != "3d":
		return false
	# Screen-space attack effects use captured anchors: keep those shots stable.
	if not presenter.active: return false
	for index in presenter._slot_count():
		if presenter.current_actions[index] not in ["idle", "sleep"] or presenter.lifecycle[index] not in ["idle", "hidden", "empty"]:
			return false
	return true

func _can_start(point: Vector2, check_hover := true) -> bool:
	var presenter = _presenter()
	if not is_instance_valid(presenter) or not _may_rotate(presenter) or not battle.battle_stage.get_global_rect().has_point(point):
		return false
	var host = battle.get_parent().get_parent()
	if host.has_node("Cover") and host.get_node("Cover").visible:
		return false
	var hovered := get_viewport().gui_get_hovered_control() if check_hover else null
	while hovered != null:
		if hovered is BaseButton or hovered is LineEdit or hovered is TextEdit or hovered is RichTextLabel or hovered is ScrollContainer:
			return false
		hovered = hovered.get_parent() as Control
	var reset := battle.battle_stage.get_node_or_null("ResetCameraButton") as Control
	if reset != null and reset.is_visible_in_tree() and reset.get_global_rect().has_point(point): return false
	for key in ["MovesGrid","ActionsDock","UtilityActions","MechanicsPanel","PlayerStagePartyRail","OpponentStagePartyRail","BattleLogRail","CalcDrawer","PlayerHudPanel","EnemyHudPanel","VSPanelContainer","BattleStatusPanel","CurrentActionPanel"]:
		var control := battle.get_node_or_null("%"+key) as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return false
	if battle.has_meta("battle_chat_bridge") and battle.get_meta("battle_chat_bridge").contains_pointer(point):
		return false
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var owned := touch_active and touches.has(event.index)
		dragging = false
		if event.pressed and not event.canceled:
			touches[event.index] = event.position
			if touches.size() == 1:
				touch_active = _can_start(event.position, false)
			elif touches.size() == 2:
				touch_active = touch_active and _can_start(event.position, false)
				var positions: Array = touches.values()
				pinch_distance = positions[0].distance_to(positions[1])
			else:
				touch_active = false
				pinch_distance = 0.0
		else:
			touches.erase(event.index)
			# Lifting either finger ends the gesture; the remaining one must not
			# suddenly rotate the camera or turn a UI press into a camera drag.
			touch_active = false
			pinch_distance = 0.0
		if owned or touch_active: get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if not touches.has(event.index): return
		var previous: Vector2 = touches[event.index]
		touches[event.index] = event.position
		var presenter = _presenter()
		if not touch_active: return
		if not is_instance_valid(presenter) or not _may_rotate(presenter) or not _can_start(event.position, false):
			touch_active = false
			return
		if touches.size() == 1:
			_rotate_by(presenter, event.position - previous)
		elif touches.size() == 2:
			var positions: Array = touches.values()
			var distance: float = positions[0].distance_to(positions[1])
			if pinch_distance >= 24.0 and distance >= 24.0:
				_zoom_by(presenter, pinch_distance / distance)
			pinch_distance = distance
		get_viewport().set_input_as_handled()
		return
	# Godot also synthesizes mouse events for touches. Processing both would
	# double the one-finger rotation and fight the two-finger zoom.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not event.pressed or not _can_start(event.position):
			return
		var presenter = _presenter()
		var step := 0.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.90
		_zoom_by(presenter, step)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging = false
		elif _can_start(event.position):
			dragging = true
	elif event is InputEventMouseMotion and dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			dragging = false
			return
		var presenter = _presenter()
		if not is_instance_valid(presenter) or not _may_rotate(presenter):
			dragging = false
			return
		_rotate_by(presenter, event.relative)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_pointer()
