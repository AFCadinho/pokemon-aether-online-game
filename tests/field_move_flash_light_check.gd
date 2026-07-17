extends SceneTree

const FlashLightScene := preload("res://scenes/world/lighting/field_move_flash_light.tscn")

var failed := false


func _init() -> void:
	var flash_light := FlashLightScene.instantiate()
	root.add_child(flash_light)
	await process_frame
	var point_light := flash_light.get_node("PointLight2D") as PointLight2D

	flash_light.call("set_darkness_intensity", 0.0)
	var day_result: Dictionary = flash_light.call("activate") as Dictionary
	_check_true(not bool(day_result.get("success", false)), "Flash is rejected during daytime")
	_check_true(not point_light.enabled, "Flash light remains disabled during daytime")

	flash_light.call("set_darkness_intensity", 1.0)
	var night_result: Dictionary = flash_light.call("activate") as Dictionary
	_check_true(bool(night_result.get("success", false)), "Flash activates in full darkness")
	_check_true(point_light.enabled, "Flash enables the player light")
	_check_approx(point_light.energy, float(flash_light.get("max_energy")), "full darkness reaches configured light energy")
	_check_true(float(flash_light.get("light_texture_scale")) >= 2.0, "Flash uses a large player-centered circle")

	flash_light.call("set_darkness_intensity", 0.5)
	_check_true(point_light.energy > 0.0 and point_light.energy < float(flash_light.get("max_energy")), "Flash follows dusk intensity smoothly")
	flash_light.call("set_darkness_intensity", 0.0)
	_check_true(bool(flash_light.get("active")), "temporary daylight or map profiles preserve the active Flash state")
	_check_true(not point_light.enabled, "preserved Flash state stays visually hidden without darkness")
	flash_light.call("set_darkness_intensity", 1.0)
	_check_true(point_light.enabled, "Flash becomes visible again after a dark map switch")
	var toggle_result: Dictionary = flash_light.call("activate") as Dictionary
	_check_true(bool(toggle_result.get("deactivated", false)), "using Flash again explicitly turns it off")
	_check_true(not bool(flash_light.get("active")) and not point_light.enabled, "explicit toggle clears both Flash state and light")

	var controller_source := FileAccess.get_file_as_string("res://scripts/world/day_night_controller.gd")
	var metadata_source := FileAccess.get_file_as_string("res://scripts/world/map_metadata.gd")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check_true(controller_source.contains("LIGHTING_PROFILE_DARK"), "day/night controller supports future dark maps")
	_check_true(metadata_source.contains('"outdoor", "indoor", "dark"'), "map metadata exposes the dark lighting profile")
	_check_true(world_source.contains('normalized_move_id != "flash"'), "world dispatch keeps direct move handling explicit")
	_check_true(world_source.contains("func _validate_active_flash_source"), "world removes Flash only after all valid sources disappear")
	flash_light.queue_free()
	quit(1 if failed else 0)


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
