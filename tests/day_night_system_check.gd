extends SceneTree

const DayNightControllerScript := preload("res://scripts/world/day_night_controller.gd")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const WorldTimeServiceScript := preload("res://scripts/services/world_time_service.gd")
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const OAKS_LAB_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"

var failed := false


func _init() -> void:
	var world_time_service: Node = WorldTimeServiceScript.new()
	world_time_service.name = "WorldTimeService"
	root.add_child(world_time_service)
	_check_color(DayNightControllerScript.color_for_seconds(12.0 * 3600.0), Color.WHITE, "day preserves the existing colors")
	_check_color(DayNightControllerScript.color_for_seconds(0.0), Color("65718f"), "midnight uses the night tint")
	_check_true(
		DayNightControllerScript.color_for_seconds(6.0 * 3600.0) != Color.WHITE,
		"dawn remains visibly distinct from daytime"
	)
	_check_approx(DayNightControllerScript.night_intensity_for_seconds(12.0 * 3600.0), 0.0, "day has no night intensity")
	_check_approx(DayNightControllerScript.night_intensity_for_seconds(0.0), 1.0, "midnight has full night intensity")

	world_time_service.call("set_debug_time", 0)
	var host := Node2D.new()
	var canvas_modulate := CanvasModulate.new()
	canvas_modulate.name = "WorldCanvasModulate"
	host.add_child(canvas_modulate)
	var controller: Node = DayNightControllerScript.new()
	controller.name = "DayNightController"
	controller.set("canvas_modulate_path", NodePath("../WorldCanvasModulate"))
	host.add_child(controller)
	root.add_child(host)
	await process_frame

	controller.call("set_lighting_profile", "outdoor")
	_check_color(canvas_modulate.color, Color("65718f"), "outdoor profile applies the shared midnight tint")

	var indoor_map: Node = MapMetadataScript.new()
	indoor_map.set("lighting_profile", "indoor")
	controller.call("apply_map", indoor_map)
	_check_color(canvas_modulate.color, Color.WHITE, "indoor profile bypasses world modulation")

	var dark_map: Node = MapMetadataScript.new()
	dark_map.set("lighting_profile", "dark")
	controller.call("apply_map", dark_map)
	_check_color(canvas_modulate.color, Color("65718f"), "dark profile applies stable darkness independent of time")
	_check_approx(float(controller.get("current_night_intensity")), 1.0, "dark profile exposes full darkness to local lights")

	var unknown_map := Node2D.new()
	controller.call("apply_map", unknown_map)
	_check_color(canvas_modulate.color, Color("65718f"), "maps without metadata safely default to outdoor")
	controller.call("set_creator_lighting_override", 12.0, 1.0)
	_check_color(canvas_modulate.color, Color.WHITE, "creator daylight preset locally overrides midnight")
	controller.call("set_creator_lighting_override", 0.0, 0.8)
	_check_approx(canvas_modulate.color.r, Color("65718f").r * 0.8, "creator brightness adjusts the selected lighting preset")
	controller.call("clear_creator_lighting_override")
	_check_color(canvas_modulate.color, Color("65718f"), "closing creator lighting restores live world time")

	_check_scene_contracts()
	world_time_service.call("clear_debug_time")
	host.queue_free()
	indoor_map.queue_free()
	dark_map.queue_free()
	unknown_map.queue_free()
	world_time_service.queue_free()
	quit(1 if failed else 0)


func _check_scene_contracts() -> void:
	var world_scene_source := FileAccess.get_file_as_string(WORLD_SCENE_PATH)
	var world_script_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	var day_night_source := FileAccess.get_file_as_string("res://scripts/world/day_night_controller.gd")
	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_SCRIPT_PATH)
	var oaks_lab_source := FileAccess.get_file_as_string(OAKS_LAB_SCENE_PATH)
	_check_true(world_scene_source.contains('[node name="WorldCanvasModulate" type="CanvasModulate"'), "world owns one canvas modulator")
	_check_true(
		day_night_source.contains("func set_creator_lighting_override(")
		and day_night_source.contains("func clear_creator_lighting_override()"),
		"day/night controller exposes a reversible local creator override"
	)
	_check_true(world_scene_source.contains('[node name="DayNightController" type="Node"'), "world owns the day/night controller")
	_check_true(world_script_source.count("_apply_day_night_for_map(") >= 4, "initial load and both map-switch paths apply lighting")
	_check_true(ui_source.contains("WorldTimeService.get_utc_datetime()"), "location clock uses the shared time source")
	_check_true(oaks_lab_source.contains('lighting_profile = "indoor"'), "Oak's Lab explicitly opts out of outdoor lighting")


func _check_color(actual: Color, expected: Color, label: String) -> void:
	_check_true(actual.is_equal_approx(expected), "%s (expected %s, got %s)" % [label, expected, actual])


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %f, got %f)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
