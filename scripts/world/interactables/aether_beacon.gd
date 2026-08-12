@tool
extends WorldInteractable

class_name AetherBeacon

@export var destination_id := ""
@export_range(0.5, 4.0, 0.1) var animation_speed := 1.4

@onready var floating_visual: Node2D = get_node_or_null("FloatingVisual")
@onready var glow: CanvasItem = get_node_or_null("FloatingVisual/Glow")
@onready var ring: Node2D = get_node_or_null("FloatingVisual/Ring")

var _animation_time := 0.0
var _base_visual_position := Vector2.ZERO


func _ready() -> void:
	interactable_kind = "aether_beacon"
	display_name = LocalizationManager.text("world.aether_beacon.name")
	if floating_visual != null:
		_base_visual_position = floating_visual.position
	super._ready()


func _process(delta: float) -> void:
	_animate_placeholder(delta)
	if not Engine.is_editor_hint():
		await super._process(delta)


func interact_with_player(_player: Node2D) -> void:
	if destination_id.strip_edges().is_empty():
		await show_dialogue(
			[LocalizationManager.text("world.aether_beacon.dormant")],
			display_name
		)
		return
	var result: Dictionary = await TransitService.attune(destination_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.transit_unavailable")
		return
	var body := result.get("body", {}) as Dictionary
	if bool(body.get("newlyAttuned", false)):
		await show_dialogue([
			LocalizationManager.text("world.aether_beacon.attuned"),
			LocalizationManager.text("world.aether_beacon.keeper_hint"),
		], display_name)
		return
	await show_dialogue(
		[LocalizationManager.text("world.aether_beacon.already_attuned")],
		display_name
	)


func _animate_placeholder(delta: float) -> void:
	_animation_time += delta * animation_speed
	if floating_visual != null:
		floating_visual.position = _base_visual_position + Vector2(0.0, sin(_animation_time) * 3.0)
	if ring != null:
		ring.rotation = _animation_time * 0.42
	if glow != null:
		glow.modulate.a = 0.34 + (sin(_animation_time * 1.7) + 1.0) * 0.13
