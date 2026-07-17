extends SceneTree

const WeatherScene := preload("res://scenes/world/weather/overworld_weather_controller.tscn")

var failed := false


func _init() -> void:
	var controller := WeatherScene.instantiate() as OverworldWeatherController
	controller.transition_duration = 0.0
	root.add_child(controller)
	await process_frame
	var rain := controller.get_node("RainParticles") as GPUParticles2D
	var snow := controller.get_node("SnowParticles") as GPUParticles2D

	_check_true(controller is Node2D, "weather renderer participates in world space")
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
	controller.queue_free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
