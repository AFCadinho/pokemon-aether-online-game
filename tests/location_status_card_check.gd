extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(scene_source.contains('[node name="HeaderRow"'), "location card has a compact header")
	_check(scene_source.contains('[node name="StatusRow"'), "location card has a separate status row")
	_check(scene_source.contains('[node name="TimeOfDayLabel"'), "location card displays the time of day")
	_check(scene_source.contains('[node name="WeatherLabel"'), "location card displays overworld weather")
	_check(not scene_source.contains('[node name="LocationIcon"'), "decorative waypoint no longer consumes card space")
	_check(script_source.contains("WorldPresenceService.weather_changed.connect(_on_location_weather_changed)"), "weather changes refresh the card")
	_check(script_source.contains('weather_controller.get_effective_weather()'), "developer weather previews refresh the card")
	_check(script_source.contains('time_of_day_label.text = "Morning"'), "morning has a readable status")
	_check(script_source.contains('time_of_day_label.text = "Afternoon"'), "afternoon has a readable status")
	_check(script_source.contains('time_of_day_label.text = "Evening"'), "evening has a readable status")
	_check(script_source.contains('time_of_day_label.text = "Night"'), "night has a readable status")

	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
