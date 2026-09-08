extends SceneTree

const WeatherScene := preload("res://scenes/world/weather/overworld_weather_controller.tscn")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var original: bool = settings.get("weather_effects")
	settings.set("weather_effects", true)
	var controller := WeatherScene.instantiate()
	controller.transition_duration = 0.0
	root.add_child(controller)
	await process_frame
	controller.set_server_weather("rain")
	_check(controller.rain_particles.emitting and controller.is_processing(), "rain renders while enabled")
	settings.set("weather_effects", false)
	settings.settings_changed.emit()
	_check(not controller.rain_particles.emitting and not controller.rain_ground_effects.emitting, "settings disable particles and ground effects")
	_check(not controller.is_processing(), "clear weather stops frame layout processing")
	controller.set_creator_weather_effects_visible(true)
	_check(controller.rain_particles.emitting, "explicit creator preview is retained")
	controller.clear_creator_weather_effects_override()
	_check(not controller.rain_particles.emitting, "leaving preview restores player preference")
	settings.set("weather_effects", true)
	settings.settings_changed.emit()
	_check(controller.rain_particles.emitting, "re-enabling restores server weather")
	var old_position: Vector2 = controller.rain_particles.position
	var original_transform := root.canvas_transform
	root.canvas_transform = Transform2D(0.0, Vector2(64, 0))
	controller._update_viewport_layout()
	_check(controller.rain_particles.position != old_position, "moving camera updates weather bounds")
	root.canvas_transform = original_transform
	controller.free()
	settings.set("weather_effects", original)
	settings.settings_changed.emit()
	await process_frame
	print("weather_settings_performance_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
