extends Control

class_name BattleStageViewport

const DEFAULT_DESIGN_SIZE := Vector2(1152.0, 648.0)

@export var design_size := DEFAULT_DESIGN_SIZE
@onready var battle_stage: Control = %BattleStage


func _ready() -> void:
	clip_contents = true
	if not resized.is_connected(_update_stage_transform):
		resized.connect(_update_stage_transform)
	_update_stage_transform.call_deferred()


func get_design_size() -> Vector2:
	return design_size


func get_stage_scale() -> float:
	if battle_stage == null:
		return 1.0
	return battle_stage.scale.x


func _update_stage_transform() -> void:
	if battle_stage == null:
		return

	var safe_design_size := Vector2(
		maxf(design_size.x, 1.0),
		maxf(design_size.y, 1.0)
	)
	var available_size := size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return

	var uniform_scale := minf(
		available_size.x / safe_design_size.x,
		available_size.y / safe_design_size.y
	)
	var rendered_size := safe_design_size * uniform_scale

	battle_stage.size = safe_design_size
	battle_stage.scale = Vector2.ONE * uniform_scale
	battle_stage.position = ((available_size - rendered_size) * 0.5).round()
