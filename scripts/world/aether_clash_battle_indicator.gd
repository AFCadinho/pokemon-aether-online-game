extends Node2D

class_name AetherClashBattleIndicator

signal spectate_requested(user_id: int, room_code: String)

const BASE_POSITION := Vector2(0, -142)
const FALLBACK_CLICK_RADIUS := 38.0

@onready var ball_sprite: Sprite2D = $BallSprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var click_area: Area2D = $ClickArea

var player_user_id := 0
var room_code := ""
var clickable := false
var animation_time := 0.0
var hover_amount := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	_apply_clickability()


func _process(delta: float) -> void:
	animation_time += delta
	var wave := sin(animation_time * 3.2)
	ball_sprite.position = BASE_POSITION + Vector2(0, wave * 3.0)
	ball_sprite.rotation = animation_time * 2.4
	glow_sprite.position = ball_sprite.position
	var pulse_scale := 0.88 + (wave + 1.0) * 0.04
	glow_sprite.scale = Vector2.ONE * pulse_scale * lerpf(1.0, 1.5, hover_amount)
	glow_sprite.modulate = Color(1.0, 0.9, 1.0, lerpf(0.58, 1.0, hover_amount))
	ball_sprite.scale = Vector2.ONE * lerpf(0.72, 0.86, hover_amount)
	ball_sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.88, 1.0), hover_amount)


func configure(user_id: int, next_room_code: String, allow_click: bool) -> void:
	var previous_user_id := player_user_id
	var previous_room_code := room_code
	var previous_clickable := clickable
	player_user_id = user_id
	room_code = next_room_code.strip_edges().to_upper()
	clickable = allow_click and player_user_id > 0 and not room_code.is_empty()
	if is_node_ready():
		_apply_clickability()
		if (
			previous_user_id != player_user_id
			or previous_room_code != room_code
			or previous_clickable != clickable
		):
			_trace("battle_indicator_configured", {
				"userId": player_user_id,
				"roomCode": room_code,
				"clickable": clickable,
				"inputPickable": click_area.input_pickable,
			})


func _apply_clickability() -> void:
	if click_area == null:
		return
	click_area.input_pickable = clickable
	if not clickable:
		hover_amount = 0.0
	modulate = Color.WHITE if clickable else Color(0.88, 0.9, 1.0, 0.92)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_trace("battle_indicator_area_input", {
		"userId": player_user_id,
		"roomCode": room_code,
		"clickable": clickable,
		"pressed": mouse_event.pressed,
		"screenPosition": _vector_payload(mouse_event.position),
	})
	if not mouse_event.pressed or not request_spectate("area_input"):
		return
	get_viewport().set_input_as_handled()


func contains_world_point(world_position: Vector2) -> bool:
	return (
		clickable
		and get_click_world_position().distance_to(world_position) <= FALLBACK_CLICK_RADIUS
	)


func get_click_world_position() -> Vector2:
	if click_area != null and is_instance_valid(click_area):
		return click_area.global_position
	return global_position + BASE_POSITION


func request_spectate(source: String) -> bool:
	if not clickable or player_user_id <= 0 or room_code.is_empty():
		_trace("battle_indicator_request_rejected", {
			"source": source,
			"userId": player_user_id,
			"roomCode": room_code,
			"clickable": clickable,
		})
		return false
	_trace("battle_indicator_request_emitted", {
		"source": source,
		"userId": player_user_id,
		"roomCode": room_code,
	})
	spectate_requested.emit(player_user_id, room_code)
	return true


func _on_mouse_entered() -> void:
	if clickable:
		hover_amount = 1.0


func _on_mouse_exited() -> void:
	hover_amount = 0.0


func _exit_tree() -> void:
	if not is_queued_for_deletion():
		queue_free()


func _trace(event: String, fields: Dictionary = {}) -> void:
	var payload := fields.duplicate(true)
	payload["event"] = event
	print("[AetherClashTrace] %s" % JSON.stringify(payload))


func _vector_payload(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}
