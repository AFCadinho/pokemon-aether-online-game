extends SceneTree

const DayNightControllerScript := preload("res://scripts/world/day_night_controller.gd")
const NightLightScene := preload("res://scenes/world/lighting/night_light.tscn")
const WorldTimeServiceScript := preload("res://scripts/services/world_time_service.gd")
const VIRIDIAN_CITY_SCENE_PATH := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"

var failed := false


func _init() -> void:
	var world_time_service: Node = WorldTimeServiceScript.new()
	world_time_service.name = "WorldTimeService"
	root.add_child(world_time_service)
	world_time_service.call("set_debug_time", 12)

	var world := Node2D.new()
	world.name = "World"
	world.add_to_group("world")
	var canvas_modulate := CanvasModulate.new()
	canvas_modulate.name = "WorldCanvasModulate"
	world.add_child(canvas_modulate)
	var controller: Node = DayNightControllerScript.new()
	controller.name = "DayNightController"
	controller.set("canvas_modulate_path", NodePath("../WorldCanvasModulate"))
	world.add_child(controller)
	var night_light: Node = NightLightScene.instantiate()
	world.add_child(night_light)
	root.add_child(world)
	await process_frame

	var point_light := night_light.get_node("PointLight2D") as PointLight2D
	_check_true(not point_light.enabled, "night light is disabled during daytime")
	_check_approx(point_light.energy, 0.0, "daytime light energy is zero")

	world_time_service.call("set_debug_time", 0)
	_check_true(point_light.enabled, "night light enables at midnight")
	_check_approx(point_light.energy, float(night_light.get("max_energy")), "midnight reaches configured maximum energy")

	world_time_service.call("set_debug_time", 19)
	_check_true(point_light.energy > 0.0, "night light fades in during dusk")
	_check_true(point_light.energy < float(night_light.get("max_energy")), "dusk remains below maximum light energy")

	controller.call("set_lighting_profile", "indoor")
	_check_true(not point_light.enabled, "indoor profile disables outdoor night lights")
	_check_approx(point_light.energy, 0.0, "indoor profile clears light energy")

	_check_viridian_pilot_contract()
	world_time_service.call("clear_debug_time")
	world.queue_free()
	world_time_service.queue_free()
	quit(1 if failed else 0)


func _check_viridian_pilot_contract() -> void:
	var scene_source := FileAccess.get_file_as_string(VIRIDIAN_CITY_SCENE_PATH)
	var script_source := FileAccess.get_file_as_string("res://scripts/world/night_light.gd")
	_check_true(script_source.contains('call_deferred("_connect_day_night_controller")'), "initial world load defers light-controller discovery until World is ready")
	_check_true(scene_source.contains('[node name="NightLights" type="Node2D" parent="."'), "Viridian City owns a hand-maintained light layer")
	var light_count := scene_source.count('instance=ExtResource("21_night_light")')
	_check_true(light_count >= 3, "Viridian City retains broad nighttime lamp coverage")
	_check_true(scene_source.count("light_color = Color(1, 0.72, 0.38, 1)") == light_count, "Viridian lamps share the verified warm light treatment")


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %f, got %f)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
