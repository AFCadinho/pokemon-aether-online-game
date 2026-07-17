extends SceneTree

const BuildingWindowLightScene := preload("res://scenes/world/lighting/building_window_light.tscn")
const DayNightControllerScript := preload("res://scripts/world/day_night_controller.gd")
const WorldTimeServiceScript := preload("res://scripts/services/world_time_service.gd")

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
	var building_light: Node = BuildingWindowLightScene.instantiate()
	building_light.set("window_size", Vector2(40.0, 20.0))
	world.add_child(building_light)
	root.add_child(world)
	await process_frame

	var window_glow := building_light.get_node("WindowGlow") as Polygon2D
	var point_light := building_light.get_node("PointLight2D") as PointLight2D
	_check_true(not window_glow.visible, "window overlay is hidden during daytime")
	_check_true(not point_light.enabled, "building glow is disabled during daytime")
	_check_approx(_polygon_width(window_glow.polygon), 40.0, "window width follows the instance setting")
	_check_approx(_polygon_height(window_glow.polygon), 20.0, "window height follows the instance setting")

	world_time_service.call("set_debug_time", 0)
	_check_true(window_glow.visible, "window overlay appears at midnight")
	_check_true(point_light.enabled, "building glow enables at midnight")
	_check_approx(window_glow.color.a, float(building_light.get("max_window_alpha")), "midnight reaches maximum window opacity")
	_check_approx(point_light.energy, float(building_light.get("max_energy")), "midnight reaches maximum building glow energy")

	world_time_service.call("set_debug_time", 19)
	_check_true(window_glow.color.a > 0.0, "window overlay fades in during dusk")
	_check_true(window_glow.color.a < float(building_light.get("max_window_alpha")), "dusk window remains below maximum opacity")

	controller.call("set_lighting_profile", "indoor")
	_check_true(not window_glow.visible, "indoor profile hides outdoor window lighting")
	_check_true(not point_light.enabled, "indoor profile disables the building glow")

	world_time_service.call("clear_debug_time")
	world.queue_free()
	world_time_service.queue_free()
	quit(1 if failed else 0)


func _polygon_width(polygon: PackedVector2Array) -> float:
	return polygon[1].x - polygon[0].x


func _polygon_height(polygon: PackedVector2Array) -> float:
	return polygon[2].y - polygon[1].y


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %f, got %f)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
