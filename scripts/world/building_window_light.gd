extends OverworldNightLight

class_name OverworldBuildingWindowLight

@export var window_size := Vector2(32.0, 16.0)
@export var window_color := Color("ffdda0")
@export_range(0.0, 1.0, 0.01) var max_window_alpha := 0.32
@export var light_offset := Vector2(0.0, 8.0)

@onready var window_glow: Polygon2D = $WindowGlow


func _ready() -> void:
	_refresh_window_appearance()
	super()


func set_night_intensity(night_intensity: float) -> void:
	super(night_intensity)
	if window_glow == null:
		return

	var normalized_intensity: float = clampf(night_intensity, 0.0, 1.0)
	var eased_intensity: float = smoothstep(0.0, 1.0, normalized_intensity)
	var glow_color := window_color
	glow_color.a = max_window_alpha * eased_intensity
	window_glow.color = glow_color
	window_glow.visible = eased_intensity > 0.001


func _refresh_window_appearance() -> void:
	var safe_size := Vector2(maxf(window_size.x, 1.0), maxf(window_size.y, 1.0))
	var half_size: Vector2 = safe_size * 0.5
	window_glow.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	point_light.position = light_offset
