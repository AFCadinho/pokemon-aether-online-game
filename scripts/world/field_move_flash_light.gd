extends Node2D

class_name OverworldFieldMoveFlashLight

const MIN_DARKNESS_INTENSITY := 0.05

@export_range(0.0, 2.0, 0.05) var max_energy := 0.52
@export_range(0.5, 5.0, 0.05) var light_texture_scale := 2.5
@export var light_color := Color("fff8dc")

@onready var point_light: PointLight2D = $PointLight2D

var active := false
var current_darkness_intensity := 0.0
var _day_night_controller: Node


func _ready() -> void:
	point_light.color = light_color
	point_light.texture_scale = light_texture_scale
	_apply_light_state()
	call_deferred("_connect_day_night_controller")


func _exit_tree() -> void:
	if _day_night_controller == null or not is_instance_valid(_day_night_controller):
		return
	var lighting_callable := Callable(self, "_on_lighting_changed")
	if _day_night_controller.is_connected("lighting_changed", lighting_callable):
		_day_night_controller.disconnect("lighting_changed", lighting_callable)


func can_activate() -> bool:
	return current_darkness_intensity > MIN_DARKNESS_INTENSITY


func activate() -> Dictionary:
	if active:
		active = false
		_apply_light_state()
		return {
			"success": true,
			"deactivated": true,
		}
	if not can_activate():
		return {
			"success": false,
			"error": "Flash is only useful at night or in a dark location.",
		}
	active = true
	_apply_light_state()
	return {
		"success": true,
		"deactivated": false,
	}


func deactivate() -> void:
	active = false
	_apply_light_state()


func set_darkness_intensity(darkness_intensity: float) -> void:
	current_darkness_intensity = clampf(darkness_intensity, 0.0, 1.0)
	_apply_light_state()


func _apply_light_state() -> void:
	if point_light == null:
		return
	var visible_intensity := smoothstep(0.0, 1.0, current_darkness_intensity) if active else 0.0
	point_light.energy = max_energy * visible_intensity
	point_light.enabled = visible_intensity > 0.001


func _connect_day_night_controller() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		set_darkness_intensity(0.0)
		return
	_day_night_controller = world.get_node_or_null("DayNightController")
	if _day_night_controller == null or not _day_night_controller.has_signal("lighting_changed"):
		set_darkness_intensity(0.0)
		return
	var lighting_callable := Callable(self, "_on_lighting_changed")
	if not _day_night_controller.is_connected("lighting_changed", lighting_callable):
		_day_night_controller.connect("lighting_changed", lighting_callable)
	set_darkness_intensity(float(_day_night_controller.get("current_night_intensity")))


func _on_lighting_changed(_world_color: Color, darkness_intensity: float) -> void:
	set_darkness_intensity(darkness_intensity)
