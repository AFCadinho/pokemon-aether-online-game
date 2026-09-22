extends Node
var battle: Control
var dragging := false

func _may_rotate(presenter: Node) -> bool:
	# Screen-space attack effects use captured anchors: keep those shots stable.
	return presenter.active and presenter.current_actions[0] in ["idle","sleep"] and presenter.current_actions[1] in ["idle","sleep"] and presenter.lifecycle[0] in ["idle","hidden","empty"] and presenter.lifecycle[1] in ["idle","hidden","empty"]

func _can_start(point: Vector2) -> bool:
	var presenter = battle.animation_router.model_presenter
	if not is_instance_valid(presenter) or not _may_rotate(presenter) or not battle.battle_stage.get_global_rect().has_point(point):
		return false
	var host = battle.get_parent().get_parent()
	if host.has_node("Cover") and host.get_node("Cover").visible:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is BaseButton or hovered is LineEdit or hovered is TextEdit or hovered is RichTextLabel or hovered is ScrollContainer:
			return false
		hovered = hovered.get_parent() as Control
	for key in ["MovesGrid","ActionsDock","UtilityActions","MechanicsPanel","PlayerStagePartyRail","OpponentStagePartyRail","BattleLogRail","CalcDrawer","PlayerHudPanel","EnemyHudPanel","VSPanelContainer","BattleStatusPanel","CurrentActionPanel"]:
		var control := battle.get_node_or_null("%"+key) as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return false
	if battle.has_meta("battle_chat_bridge") and battle.get_meta("battle_chat_bridge").contains_pointer(point):
		return false
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not event.pressed or not _can_start(event.position):
			return
		var presenter = battle.animation_router.model_presenter
		var step := 0.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.90
		presenter.user_camera_zoom = clampf(
			presenter.user_camera_zoom * step,
			presenter.USER_CAMERA_ZOOM_MIN,
			presenter.USER_CAMERA_ZOOM_MAX
		)
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
		var presenter = battle.animation_router.model_presenter
		if not is_instance_valid(presenter) or not _may_rotate(presenter):
			dragging = false
			return
		presenter.user_camera_yaw = wrapf(presenter.user_camera_yaw - event.relative.x * 0.006,-PI,PI)
		presenter.user_camera_pitch = clampf(presenter.user_camera_pitch - event.relative.y * 0.004,-0.12,0.65)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
