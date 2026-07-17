extends SceneTree

const WeatherScene := preload("res://scenes/world/weather/overworld_weather_controller.tscn")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var metadata_source := FileAccess.get_file_as_string("res://scripts/world/map_metadata.gd")
	var oaks_lab_source := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn")
	_check_true(metadata_source.contains('@export_enum("outdoor", "disabled") var weather_profile'), "map metadata exposes an explicit weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(target_map)"), "authorized teleports apply the destination weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(new_map)"), "regular map transitions apply the destination weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(initial_map)"), "initial world setup applies the map weather policy")
	_check_true(oaks_lab_source.contains('weather_profile = "disabled"'), "Oak's Lab explicitly disables overworld weather")

	var controller := WeatherScene.instantiate() as OverworldWeatherController
	controller.transition_duration = 0.0
	root.add_child(controller)
	await process_frame
	var rain := controller.get_node("RainParticles") as GPUParticles2D
	var snow := controller.get_node("SnowParticles") as GPUParticles2D

	_check_true(controller is CanvasLayer, "weather renderer has a dedicated canvas layer")
	_check_equal(controller.layer, 1, "weather renders above overworld canvas items")
	_check_true(controller.follow_viewport_enabled, "weather layer follows the world camera")
	_check_true(not rain.local_coords and not snow.local_coords, "weather particles remain in world space when the camera moves")
	_check_equal(controller.get_effective_weather(), "clear", "weather defaults to clear")
	_check_true(not rain.emitting and not snow.emitting, "clear weather has no particle effect")

	controller.set_server_weather("rain")
	_check_equal(controller.get_effective_weather(), "rain", "server weather can select rain")
	_check_true(rain.emitting and rain.visible, "rain enables only rain particles")
	_check_true(not snow.emitting and not snow.visible, "rain keeps snow disabled")

	controller.set_debug_weather("snow")
	_check_true(controller.is_debug_weather_active(), "developer preview records an override")
	_check_equal(controller.get_effective_weather(), "snow", "developer snow overrides server rain")
	_check_true(snow.emitting and snow.visible, "snow preview enables snow particles")
	_check_true(not rain.emitting and not rain.visible, "snow preview disables rain particles")

	controller.set_server_weather("clear")
	_check_equal(controller.get_effective_weather(), "snow", "server updates do not replace an active preview")
	controller.clear_debug_weather()
	_check_equal(controller.get_effective_weather(), "clear", "reset returns to the latest server/default weather")
	_check_true(not rain.emitting and not snow.emitting, "reset to clear removes all weather particles")

	controller.set_debug_weather("unsupported")
	_check_equal(controller.get_effective_weather(), "clear", "unsupported weather safely normalizes to clear")
	controller.clear_debug_weather()
	controller.set_server_weather("rain")
	var disabled_map := MapMetadataScript.new()
	disabled_map.weather_profile = "disabled"
	controller.apply_map(disabled_map)
	_check_true(not controller.is_weather_enabled_for_current_map(), "maps can explicitly disable overworld weather")
	_check_equal(controller.get_effective_weather(), "clear", "disabled maps always render clear weather")
	_check_true(not rain.emitting and not snow.emitting, "disabled maps stop active weather particles")
	controller.set_server_weather("snow")
	_check_equal(controller.server_weather, "snow", "disabled maps still retain the latest server weather")
	var outdoor_map := MapMetadataScript.new()
	outdoor_map.weather_profile = "outdoor"
	controller.apply_map(outdoor_map)
	_check_equal(controller.get_effective_weather(), "snow", "weather returns after entering an enabled outdoor map")
	_check_true(snow.emitting and snow.visible, "the retained server weather resumes outdoors")
	disabled_map.free()
	outdoor_map.free()
	controller.queue_free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
