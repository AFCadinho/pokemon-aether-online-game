extends Node2D

class_name AetherClashStartBarrier

signal barrier_lowered

@onready var collision_shape: CollisionShape2D = $BarrierBody/CollisionShape2D
@onready var barrier_visual: Node2D = $BarrierVisual

var barrier_raised := true
var lowering_tween: Tween
var pulse_elapsed := 0.0


func _ready() -> void:
	_set_raised_immediately(true)


func _process(delta: float) -> void:
	if not barrier_raised or lowering_tween != null:
		return
	pulse_elapsed += delta
	barrier_visual.modulate.a = 0.82 + ((sin(pulse_elapsed * 4.0) + 1.0) * 0.09)


func set_barrier_raised(raised: bool, animate := false) -> void:
	if lowering_tween != null:
		lowering_tween.kill()
		lowering_tween = null
	if raised:
		_set_raised_immediately(true)
		return
	barrier_raised = false
	collision_shape.set_deferred("disabled", true)
	if not animate or not is_inside_tree():
		_set_raised_immediately(false)
		return
	barrier_visual.visible = true
	barrier_visual.position = Vector2.ZERO
	barrier_visual.scale = Vector2.ONE
	barrier_visual.modulate = Color.WHITE
	lowering_tween = create_tween().set_parallel(true)
	lowering_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lowering_tween.tween_property(barrier_visual, "position:y", 48.0, 0.75)
	lowering_tween.tween_property(barrier_visual, "scale:y", 0.05, 0.75)
	lowering_tween.tween_property(barrier_visual, "modulate:a", 0.0, 0.75)
	lowering_tween.finished.connect(_on_lowering_finished, CONNECT_ONE_SHOT)


func is_barrier_raised() -> bool:
	return barrier_raised


func _set_raised_immediately(raised: bool) -> void:
	barrier_raised = raised
	collision_shape.set_deferred("disabled", not raised)
	barrier_visual.visible = raised
	barrier_visual.position = Vector2.ZERO
	barrier_visual.scale = Vector2.ONE
	barrier_visual.modulate = Color.WHITE


func _on_lowering_finished() -> void:
	lowering_tween = null
	barrier_visual.visible = false
	barrier_lowered.emit()

