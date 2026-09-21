extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")

var failed := false


func _init() -> void:
	for category_and_id: Array in [
		["hair", "Wishmaker_Hair"],
		["facegear", "Wishmaker_Earrings"],
		["top", "Wishmaker_Dress"],
		["shoes", "Wishmaker_Shoes"],
	]:
		var category: String = category_and_id[0]
		var part_id: String = category_and_id[1]
		_check(APPEARANCE.get_available_part_ids(category, "female").has(part_id),
			"%s is available to female Trainers" % part_id)
		_check(not APPEARANCE.get_available_part_ids(category, "male").has(part_id),
			"%s is hidden from male Trainers" % part_id)
		var frames := APPEARANCE.get_part_frames(category, part_id, "female")
		_check(frames != null and frames.get_frame_count(&"walk_down") == 4,
			"%s has a complete overworld walk sheet" % part_id)
		if frames != null:
			var frame := frames.get_frame_texture(&"walk_down", 0)
			_check(frame != null and frame.get_size() == Vector2(80, 80),
				"%s preserves the supplied 80 pixel artwork" % part_id)

	var outfit_icon := APPEARANCE.get_cosmetic_item_icon("wishmaker-outfit", "male")
	_check(outfit_icon != null, "Wishmaker Outfit resolves to a cosmetic preview")
	_check(APPEARANCE.get_cosmetic_item_allowed_genders("wishmaker-outfit") == ["female"],
		"Wishmaker Outfit is female-only")
	_check(not APPEARANCE.is_tintable_part("hair", "Wishmaker_Hair"),
		"Wishmaker Hair retains its supplied colour")
	_check(APPEARANCE.get_eyebrows_for_hair("Wishmaker_Hair", "female") == "",
		"Wishmaker Hair does not show unrelated eyebrows")
	_check(APPEARANCE.get_directional_part_z_index("facegear", "Wishmaker_Earrings", "up", 8) == 5,
		"Wishmaker Earrings sit below hair when facing up")

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
