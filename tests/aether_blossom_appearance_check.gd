extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")

var failed := false


func _init() -> void:
	_check(
		APPEARANCE.normalize_hex_color_code("7A46C5") == "#7a46c5",
		"hex colours accept values without a hash"
	)
	_check(
		APPEARANCE.normalize_hex_color_code("#12abEF") == "#12abef",
		"hex colours normalize mixed casing"
	)
	_check(
		APPEARANCE.normalize_hex_color_code("#12345g") == "",
		"invalid hex colours are rejected"
	)
	for category_and_id_value: Variant in [
		["hair", "Aether_Blossom_Hair"],
		["facegear", "Aether_Blossom_Earrings"],
		["top", "Aether_Blossom_Dress"],
		["shoes", "Aether_Blossom_Shoes"],
	]:
		var category_and_id: Array = category_and_id_value as Array
		var category: String = category_and_id[0]
		var appearance_id: String = category_and_id[1]
		_check(
			APPEARANCE.get_available_part_ids(category, "female").has(appearance_id),
			"%s is imported for female models" % appearance_id
		)
		_check(
			not APPEARANCE.get_available_part_ids(category, "male").has(appearance_id),
			"%s is not exposed to male models" % appearance_id
		)
		_check(
			not APPEARANCE.is_free_part_id(category, appearance_id),
			"%s is a paid cosmetic" % appearance_id
		)
		_check(
			APPEARANCE.get_part_frames(category, appearance_id, "female") != null,
			"%s renders walking frames" % appearance_id
		)

	_check(
		not APPEARANCE.is_tintable_part("hair", "Aether_Blossom_Hair"),
		"Aether Blossom Hair preserves its original blue colour"
	)
	for category_and_id_value: Variant in [
		["hair", "Aether_Blossom_Hair_Chroma"],
		["facegear", "Aether_Blossom_Earrings_Chroma"],
		["shoes", "Aether_Blossom_Shoes_Chroma"],
	]:
		var category_and_id: Array = category_and_id_value as Array
		var category: String = category_and_id[0]
		var appearance_id: String = category_and_id[1]
		_check(
			APPEARANCE.get_available_part_ids(category, "female").has(appearance_id),
			"%s is imported for female models" % appearance_id
		)
		_check(
			APPEARANCE.is_tintable_part(category, appearance_id),
			"%s supports Chroma colours" % appearance_id
		)
	_check(
		not APPEARANCE.get_available_part_ids("top", "female").has("Aether_Blossom_Dress_Chroma"),
		"Aether Blossom Dress has no Chroma edition"
	)
	_check(
		not APPEARANCE.is_tintable_part("top", "Aether_Blossom_Dress"),
		"Aether Blossom Dress preserves its original colours"
	)
	for movement_style: String in [
		APPEARANCE.BODY_MOVEMENT_FISH,
		APPEARANCE.BODY_MOVEMENT_RIDE,
	]:
		_check(
			APPEARANCE.get_part_frames(
				"top",
				"Aether_Blossom_Dress",
				"female",
				movement_style
			) != null,
			"Aether Blossom Dress includes its %s pose" % movement_style
		)
		for shoes_id: String in ["Aether_Blossom_Shoes", "Aether_Blossom_Shoes_Chroma"]:
			_check(
				APPEARANCE.get_part_frames("shoes", shoes_id, "female", movement_style) != null,
				"%s includes its %s pose" % [shoes_id, movement_style]
			)
	_check(
		APPEARANCE.get_directional_part_z_index("facegear", "Aether_Blossom_Earrings", "up", 8) == 5,
		"Aether Blossom Earrings render below the hair while facing up"
	)
	_check(
		APPEARANCE.get_directional_part_z_index("facegear", "Aether_Blossom_Earrings_Chroma", "up", 8) == 5,
		"Aether Blossom Chroma Earrings also render below the hair while facing up"
	)
	for direction: String in ["down", "left", "right"]:
		_check(
			APPEARANCE.get_directional_part_z_index(
				"facegear",
				"Aether_Blossom_Earrings",
				direction,
				8
			) == 8,
			"Aether Blossom Earrings render above the hair while facing %s" % direction
		)
	_check(
		APPEARANCE.get_directional_part_z_index("facegear", "Adinho_Glasses", "up", 8) == 8,
		"directional layer change does not affect other facegear"
	)

	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
