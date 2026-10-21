extends "res://tests/fixtures/cycling_road_player_probe.gd"

var rendered_activity_style := ""


func _is_facing_water_tile() -> bool:
	return true


func set_activity_style(style: String) -> void:
	rendered_activity_style = style


func _spawn_water_ripple_effect(_position: Vector2, _kind: String, _require_water := true) -> void:
	pass
