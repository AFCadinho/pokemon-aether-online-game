extends "res://tools/sprite_factory/catalog_mega_battle_review.gd"
## Visual-review captures while the separate native 120 Hz validator runs.
## An empty validation receipt deliberately prevents runtime qualification.
func _validate_motion(_entry: Dictionary, _model: Node3D, _player: AnimationPlayer, measured: Dictionary) -> Dictionary:
	measured["independent_motion_validation_pending"] = true
	measured["purpose"] = "visual_review_capture_only; not native motion qualification"
	return {}
