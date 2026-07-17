extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var scene_source := FileAccess.get_file_as_string(OVERLAY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(scene_source.contains('[node name="HeaderRow"'), "location card has a compact header")
	_check(scene_source.contains('[node name="LocationLabel" type="Label" parent="Control/LocationPanel/MarginContainer/VBoxContainer/HeaderRow"'), "location and region share the header row")
	_check(scene_source.contains('[node name="RegionBadge"'), "region is presented as compact metadata")
	_check(scene_source.contains('[node name="StatusRow"'), "location card has a separate status row")
	_check(scene_source.contains('[node name="TimeOfDayLabel"'), "location card displays the time of day")
	_check(scene_source.contains('[node name="WeatherLabel"'), "location card displays overworld weather")
	_check(not scene_source.contains('[node name="LocationIcon"'), "decorative waypoint no longer consumes card space")
	_check(scene_source.contains("custom_minimum_size = Vector2(332, 66)"), "location card uses a compact readable footprint")
	_check(scene_source.contains("custom_minimum_size = Vector2(32, 32)"), "location card action icon has a readable size")
	_check(scene_source.contains('[node name="WildPokemonButton" type="TextureButton" parent="Control/LocationPanel/MarginContainer/VBoxContainer/HeaderRow"]'), "wild encounter radar occupies the card header")
	_check(scene_source.count("theme_override_font_sizes/font_size = 13") >= 4, "location card status text remains readable")
	_check(script_source.contains("region_label.text = _get_current_map_region_name().to_upper()"), "region badge refreshes with the map")
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
