extends Node2D

class_name OverworldNightLight

@export var light_color := Color("ffd08a")
@export_range(0.0, 4.0, 0.05) var max_energy := 0.9
@export_range(0.1, 3.0, 0.05) var light_texture_scale := 0.8
@export_range(0.0, 1.0, 0.01) var max_glow_alpha := 0.25

@onready var point_light: PointLight2D = get_node_or_null("PointLight2D") as PointLight2D
@onready var glow_sprite: Sprite2D = get_node_or_null("GlowSprite") as Sprite2D

var _day_night_controller: Node


func _ready() -> void:
	if point_light != null:
		point_light.color = light_color
		point_light.texture_scale = light_texture_scale
	if glow_sprite != null:
		glow_sprite.scale = Vector2.ONE * light_texture_scale
	set_night_intensity(0.0)
	call_deferred("_connect_day_night_controller")


func _exit_tree() -> void:
	if _day_night_controller == null or not is_instance_valid(_day_night_controller):
		return
	var lighting_callable := Callable(self, "_on_lighting_changed")
	if _day_night_controller.is_connected("lighting_changed", lighting_callable):
		_day_night_controller.disconnect("lighting_changed", lighting_callable)


func set_night_intensity(night_intensity: float) -> void:
	var normalized_intensity: float = clampf(night_intensity, 0.0, 1.0)
	var eased_intensity: float = smoothstep(0.0, 1.0, normalized_intensity)
	if point_light != null:
		point_light.energy = max_energy * eased_intensity
		point_light.enabled = eased_intensity > 0.001
	if glow_sprite != null:
		var glow_color := Color(
			light_color.r * 1.2,
			light_color.g * 1.1,
			light_color.b,
			light_color.a
		)
		glow_color.a = max_glow_alpha * eased_intensity
		glow_sprite.modulate = glow_color
		glow_sprite.visible = eased_intensity > 0.001


func _connect_day_night_controller() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		set_night_intensity(0.0)
		return

	_day_night_controller = world.get_node_or_null("DayNightController")
	if _day_night_controller == null or not _day_night_controller.has_signal("lighting_changed"):
		set_night_intensity(0.0)
		return

	var lighting_callable := Callable(self, "_on_lighting_changed")
	if not _day_night_controller.is_connected("lighting_changed", lighting_callable):
		_day_night_controller.connect("lighting_changed", lighting_callable)
	set_night_intensity(float(_day_night_controller.get("current_night_intensity")))


func _on_lighting_changed(_world_color: Color, night_intensity: float) -> void:
	set_night_intensity(night_intensity)
