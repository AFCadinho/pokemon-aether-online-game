extends Node2D

class_name AetherClashBattleIndicator

signal spectate_requested(user_id: int, room_code: String)

const BASE_POSITION := Vector2(0, -142)

@onready var ball_sprite: Sprite2D = $BallSprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var click_area: Area2D = $ClickArea

var player_user_id := 0
var room_code := ""
var clickable := false
var animation_time := 0.0


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
	glow_sprite.scale = Vector2.ONE * (0.88 + (wave + 1.0) * 0.04)


func configure(user_id: int, next_room_code: String, allow_click: bool) -> void:
	player_user_id = user_id
	room_code = next_room_code.strip_edges().to_upper()
	clickable = allow_click and player_user_id > 0 and not room_code.is_empty()
	if is_node_ready():
		_apply_clickability()


func _apply_clickability() -> void:
	if click_area == null:
		return
	click_area.input_pickable = clickable
	modulate = Color.WHITE if clickable else Color(0.88, 0.9, 1.0, 0.92)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not clickable or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	spectate_requested.emit(player_user_id, room_code)
	get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	if clickable:
		ball_sprite.scale = Vector2.ONE * 0.84


func _on_mouse_exited() -> void:
	ball_sprite.scale = Vector2.ONE * 0.72


func _exit_tree() -> void:
	if not is_queued_for_deletion():
		queue_free()
