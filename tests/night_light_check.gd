extends SceneTree

const DayNightControllerScript := preload("res://scripts/world/day_night_controller.gd")
const NightLightScene := preload("res://scenes/world/lighting/night_light.tscn")
const NightGlowScene := preload("res://scenes/world/lighting/night_glow.tscn")
const WorldTimeServiceScript := preload("res://scripts/services/world_time_service.gd")
const CERULEAN_CITY_SCENE_PATH := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
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
	var night_glow: Node = NightGlowScene.instantiate()
	world.add_child(night_glow)
	root.add_child(world)
	await process_frame

	var point_light := night_light.get_node("PointLight2D") as PointLight2D
	var glow_sprite := night_glow.get_node("GlowSprite") as Sprite2D
	_check_true(not point_light.enabled, "night light is disabled during daytime")
	_check_approx(point_light.energy, 0.0, "daytime light energy is zero")
	_check_true(not glow_sprite.visible, "optimized glow is hidden during daytime")

	world_time_service.call("set_debug_time", 0)
	_check_true(point_light.enabled, "night light enables at midnight")
	_check_approx(point_light.energy, float(night_light.get("max_energy")), "midnight reaches configured maximum energy")
	_check_true(glow_sprite.visible, "optimized glow appears at midnight")
	_check_approx(glow_sprite.modulate.a, float(night_glow.get("max_glow_alpha")), "midnight reaches configured glow opacity")

	world_time_service.call("set_debug_time", 19)
	_check_true(point_light.energy > 0.0, "night light fades in during dusk")
	_check_true(point_light.energy < float(night_light.get("max_energy")), "dusk remains below maximum light energy")
	_check_true(glow_sprite.modulate.a > 0.0, "optimized glow fades in during dusk")
	_check_true(glow_sprite.modulate.a < float(night_glow.get("max_glow_alpha")), "dusk glow remains below maximum opacity")

	controller.call("set_lighting_profile", "indoor")
	_check_true(not point_light.enabled, "indoor profile disables outdoor night lights")
	_check_approx(point_light.energy, 0.0, "indoor profile clears light energy")
	_check_true(not glow_sprite.visible, "indoor profile hides the optimized glow")

	_check_viridian_pilot_contract()
	_check_cerulean_optimized_glow_contract()
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


func _check_cerulean_optimized_glow_contract() -> void:
	var scene_source := FileAccess.get_file_as_string(CERULEAN_CITY_SCENE_PATH)
	_check_true(scene_source.contains('path="res://scenes/world/lighting/night_glow.tscn"'), "Cerulean uses the batchable glow scene")
	_check_true(scene_source.count('instance=ExtResource("8_ex4qq")') == 52, "Cerulean retains all hand-placed nighttime glows")
	var optimized_glow := NightGlowScene.instantiate()
	_check_true(optimized_glow.get_node_or_null("PointLight2D") == null, "optimized glow creates no point light")
	var glow_sprite := optimized_glow.get_node("GlowSprite") as Sprite2D
	var glow_material := glow_sprite.material as CanvasItemMaterial
	_check_true(glow_sprite.z_index == 4, "optimized glow lights buildings without drawing over actors")
	_check_true(glow_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "optimized glow uses additive batching")
	_check_true(glow_material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "optimized glow avoids recursive light work")
	optimized_glow.free()


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %f, got %f)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
