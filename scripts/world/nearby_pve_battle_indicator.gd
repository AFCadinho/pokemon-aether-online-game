extends Node2D

class_name NearbyPveBattleIndicator

signal spectate_requested(target_user_id: int)

const POKE_BALL := preload("res://assets/items/icons/POKEBALL.png")
const GREAT_BALL := preload("res://assets/items/icons/GREATBALL.png")
const DEFAULT_ANCHOR_POSITION := Vector2(0, -92)

var target_user_id := 0
var battle_kind := ""
var sprite: Sprite2D
var glow_sprite: Sprite2D
var area: Area2D
var elapsed := 0.0
var hover_amount := 0.0
var anchor_position := DEFAULT_ANCHOR_POSITION


func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	glow_sprite = Sprite2D.new()
	var glow_gradient := Gradient.new()
	glow_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	glow_gradient.colors = PackedColorArray([
		Color(0.35, 0.72, 1.0, 0.58),
		Color(0.12, 0.42, 0.8, 0.2),
		Color(0.03, 0.16, 0.4, 0.0),
	])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = glow_gradient
	glow_texture.width = 64
	glow_texture.height = 64
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_sprite.texture = glow_texture
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_sprite.material = glow_material
	add_child(glow_sprite)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 0.56
	add_child(sprite)
	area = Area2D.new()
	area.position = anchor_position
	area.collision_layer = 128
	area.collision_mask = 0
	area.priority = 100.0
	area.monitoring = false
	area.monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 38.0
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(_on_input)
	area.mouse_entered.connect(func(): hover_amount = 1.0)
	area.mouse_exited.connect(func(): hover_amount = 0.0)
	add_child(area)
	_apply_kind()


func configure(
	user_id: int,
	kind: String,
	next_anchor_position: Vector2 = DEFAULT_ANCHOR_POSITION
) -> void:
	target_user_id = user_id
	battle_kind = kind.strip_edges().to_lower()
	anchor_position = next_anchor_position
	if is_node_ready():
		area.position = anchor_position
		_apply_kind()


func _apply_kind() -> void:
	visible = target_user_id > 0 and battle_kind in ["wild", "trainer"]
	if sprite != null:
		sprite.texture = POKE_BALL if battle_kind == "wild" else GREAT_BALL
	if area != null:
		area.input_pickable = visible
	if not visible:
		hover_amount = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	var wave := sin(elapsed * 3.2)
	var animated_position := anchor_position + Vector2(0, wave * 3.0)
	if sprite != null:
		sprite.position = animated_position
		sprite.rotation = elapsed * 2.4
		sprite.scale = Vector2.ONE * lerpf(0.56, 0.66, hover_amount)
		sprite.modulate = Color.WHITE.lerp(Color(0.82, 0.94, 1.0), hover_amount)
	if glow_sprite != null:
		glow_sprite.position = animated_position
		var pulse_scale := 0.7 + (wave + 1.0) * 0.035
		glow_sprite.scale = Vector2.ONE * pulse_scale * lerpf(1.0, 1.35, hover_amount)
		glow_sprite.modulate = Color(0.72, 0.9, 1.0, lerpf(0.58, 1.0, hover_amount))


func _on_input(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and visible:
			spectate_requested.emit(target_user_id)
			get_viewport().set_input_as_handled()
