extends Node

class_name OverworldDayNightController

signal lighting_changed(color: Color, night_intensity: float)

const LIGHTING_PROFILE_OUTDOOR := "outdoor"
const LIGHTING_PROFILE_INDOOR := "indoor"
const LIGHTING_PROFILE_DARK := "dark"
const DAY_COLOR := Color.WHITE
const NIGHT_COLOR := Color("65718f")
const DAWN_COLOR := Color("b8a9b2")
const DUSK_COLOR := Color("d3a48e")
const REFRESH_INTERVAL_SECONDS := 1.0

@export var canvas_modulate_path: NodePath

var current_lighting_profile := LIGHTING_PROFILE_OUTDOOR
var current_night_intensity := 0.0
var _refresh_elapsed := REFRESH_INTERVAL_SECONDS
var _world_time_service: Node
var _creator_lighting_override_active := false
var _creator_hour := -1.0
var _creator_exposure := 1.0

@onready var world_canvas_modulate: CanvasModulate = get_node_or_null(canvas_modulate_path) as CanvasModulate


func _ready() -> void:
	_world_time_service = get_node_or_null("/root/WorldTimeService")
	if _world_time_service != null:
		var refresh_callable := Callable(self, "_on_world_time_changed")
		if not _world_time_service.is_connected("time_changed", refresh_callable):
			_world_time_service.connect("time_changed", refresh_callable)
	_refresh_lighting()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL_SECONDS:
		return
	_refresh_lighting()


func apply_map(map_node: Node) -> void:
	var profile := LIGHTING_PROFILE_OUTDOOR
	if map_node != null and map_node.has_method("get_lighting_profile"):
		profile = str(map_node.call("get_lighting_profile"))
	set_lighting_profile(profile)


func set_lighting_profile(profile: String) -> void:
	var normalized_profile := profile.strip_edges().to_lower()
	if normalized_profile not in [LIGHTING_PROFILE_INDOOR, LIGHTING_PROFILE_DARK]:
		normalized_profile = LIGHTING_PROFILE_OUTDOOR
	current_lighting_profile = normalized_profile
	_refresh_lighting()


func set_creator_lighting_override(hour: float = -1.0, exposure: float = 1.0) -> void:
	_creator_lighting_override_active = true
	_creator_hour = hour
	_creator_exposure = clampf(exposure, 0.65, 1.4)
	_refresh_lighting()


func clear_creator_lighting_override() -> void:
	if not _creator_lighting_override_active:
		return
	_creator_lighting_override_active = false
	_creator_hour = -1.0
	_creator_exposure = 1.0
	_refresh_lighting()


func _refresh_lighting() -> void:
	_refresh_elapsed = 0.0
	var color := DAY_COLOR
	var night_intensity := 0.0
	if current_lighting_profile == LIGHTING_PROFILE_DARK:
		color = NIGHT_COLOR
		night_intensity = 1.0
	elif current_lighting_profile == LIGHTING_PROFILE_OUTDOOR:
		var seconds_since_midnight: float = _get_seconds_since_midnight()
		color = color_for_seconds(seconds_since_midnight)
		night_intensity = night_intensity_for_seconds(seconds_since_midnight)

	if _creator_lighting_override_active:
		if _creator_hour >= 0.0:
			var creator_seconds := wrapf(_creator_hour, 0.0, 24.0) * 3600.0
			color = color_for_seconds(creator_seconds)
			night_intensity = night_intensity_for_seconds(creator_seconds)
		color = Color(
			color.r * _creator_exposure,
			color.g * _creator_exposure,
			color.b * _creator_exposure,
			color.a
		)

	current_night_intensity = night_intensity
	if world_canvas_modulate != null:
		world_canvas_modulate.color = color
	lighting_changed.emit(color, night_intensity)


func _on_world_time_changed() -> void:
	_refresh_lighting()


func _get_seconds_since_midnight() -> float:
	if _world_time_service != null and _world_time_service.has_method("get_seconds_since_midnight"):
		return float(_world_time_service.call("get_seconds_since_midnight"))
	var date_time: Dictionary = Time.get_datetime_dict_from_system(true)
	return float(
		int(date_time.get("hour", 0)) * 3600
		+ int(date_time.get("minute", 0)) * 60
		+ int(date_time.get("second", 0))
	)


static func color_for_seconds(seconds_since_midnight: float) -> Color:
	var hour := wrapf(seconds_since_midnight / 3600.0, 0.0, 24.0)
	if hour < 5.0:
		return NIGHT_COLOR
	if hour < 6.0:
		return NIGHT_COLOR.lerp(DAWN_COLOR, hour - 5.0)
	if hour < 8.0:
		return DAWN_COLOR.lerp(DAY_COLOR, (hour - 6.0) / 2.0)
	if hour < 17.5:
		return DAY_COLOR
	if hour < 19.0:
		return DAY_COLOR.lerp(DUSK_COLOR, (hour - 17.5) / 1.5)
	if hour < 20.5:
		return DUSK_COLOR.lerp(NIGHT_COLOR, (hour - 19.0) / 1.5)
	return NIGHT_COLOR


static func night_intensity_for_seconds(seconds_since_midnight: float) -> float:
	var hour := wrapf(seconds_since_midnight / 3600.0, 0.0, 24.0)
	if hour < 5.0:
		return 1.0
	if hour < 8.0:
		return 1.0 - ((hour - 5.0) / 3.0)
	if hour < 17.5:
		return 0.0
	if hour < 20.5:
		return (hour - 17.5) / 3.0
	return 1.0
