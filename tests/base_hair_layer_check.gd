extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const TEST_HAIR_COLOR := Color("#5a3728")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_hair_frames := APPEARANCE.get_part_frames(
		"hair",
		APPEARANCE.BASE_HAIR_ID,
		"male"
	)
	_check(base_hair_frames != null, "the hidden base-hair spritesheet is imported")
	_check(
		not APPEARANCE.get_available_part_ids("hair", "male").has(APPEARANCE.BASE_HAIR_ID)
			and not APPEARANCE.get_available_part_ids("hair", "female").has(APPEARANCE.BASE_HAIR_ID),
		"the base-hair layer is not exposed as an equippable hairstyle"
	)
	_check(
		APPEARANCE.resolve_hair_render_id("") == APPEARANCE.BASE_HAIR_ID
			and APPEARANCE.resolve_hair_render_id("__none__") == APPEARANCE.BASE_HAIR_ID
			and APPEARANCE.resolve_hair_render_id("Adinho_Hair") == "Adinho_Hair",
		"unequipped hair renders the base layer without changing equipped hairstyle IDs"
	)
	var standalone_base_hair_render := APPEARANCE.get_tinted_part_frames(
		"hair",
		APPEARANCE.BASE_HAIR_ID,
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		TEST_HAIR_COLOR,
		true
	)
	_check(
		_opaque_pixels_match_color(standalone_base_hair_render, TEST_HAIR_COLOR),
		"the standalone base layer uses the selected hair colour"
	)
	for renderer_path: String in [
		"res://scripts/world/player.gd",
		"res://scripts/world/remote_player_avatar.gd",
		"res://scripts/ui/login_screen.gd",
		"res://scripts/ui/ui_overlay.gd",
		"res://scripts/ui/donator_store_popup.gd",
		"res://scripts/ui/aether_atelier_popup.gd",
	]:
		_check(
			FileAccess.get_file_as_string(renderer_path).contains("resolve_hair_render_id"),
			"%s resolves unequipped hair to the standard base layer" % renderer_path
		)

	for hairstyle: Dictionary in [
		{"gender": "male", "id": "Hair", "color": Color("#5a3728")},
		{"gender": "male", "id": "Adinho_Hair", "color": Color("#813a2f")},
		{"gender": "male", "id": "IronFanton_Hair", "color": Color("#d6b66b")},
		{"gender": "male", "id": "Aether_Male_Hair_01", "color": Color("#813a2f")},
		{"gender": "male", "id": "Aether_Male_Hair_02", "color": Color("#d6b66b")},
		{"gender": "male", "id": "Aether_Male_Hair_03", "color": Color("#2b5f64")},
		{"gender": "female", "id": "Hair", "color": Color("#6b4632")},
		{"gender": "female", "id": "Aether_Blossom_Hair_Chroma", "color": Color("#a64f70")},
		{"gender": "female", "id": "Aether_Female_Hair_01", "color": Color("#a9afb8")},
		{"gender": "female", "id": "Aether_Female_Hair_02", "color": Color("#6b5c91")},
	]:
		var gender := str(hairstyle.get("gender", ""))
		var hairstyle_id := str(hairstyle.get("id", ""))
		var hair_color := hairstyle.get("color", Color.WHITE) as Color
		var authored_frames := APPEARANCE.get_part_frames("hair", hairstyle_id, gender)
		var previous_render := APPEARANCE._build_tinted_sprite_frames(
			authored_frames,
			hair_color,
			true
		)
		var rendered_frames := APPEARANCE.get_tinted_part_frames(
			"hair",
			hairstyle_id,
			gender,
			APPEARANCE.BODY_MOVEMENT_DEFAULT,
			hair_color,
			true
		)
		_check(
			_frames_are_equal(previous_render, rendered_frames),
			"%s renders without pixels from the hidden bald hairstyle" % hairstyle_id
		)

	for gender: String in ["male", "female"]:
		var body_id := (
			APPEARANCE.DEFAULT_FEMALE_BODY_ID
			if gender == "female"
			else APPEARANCE.DEFAULT_MALE_BODY_ID
		)
		var body_frames := APPEARANCE.get_body_frames(body_id, gender)
		var gender_base_hair_frames := APPEARANCE.get_part_frames(
			"hair",
			APPEARANCE.BASE_HAIR_ID,
			gender
		)
		_check(
			_body_uses_skin_under_base_hair(body_frames, gender_base_hair_frames),
			"%s body uses skin pixels beneath the base-hair layer" % gender
		)

	for movement_style: String in [
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		APPEARANCE.BODY_MOVEMENT_FISH,
		APPEARANCE.BODY_MOVEMENT_RIDE,
	]:
		_check(
			APPEARANCE.get_tinted_part_frames(
				"hair",
				"Adinho_Hair",
				"male",
				movement_style,
				TEST_HAIR_COLOR,
				true
			) != null,
			"custom hair renders for %s movement" % movement_style
		)

	quit(1 if failed else 0)


func _frames_are_equal(first_frames: SpriteFrames, second_frames: SpriteFrames) -> bool:
	if first_frames == null or second_frames == null:
		return false
	if first_frames.get_animation_names() != second_frames.get_animation_names():
		return false
	for animation_name_text: String in first_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if first_frames.get_frame_count(animation_name) != second_frames.get_frame_count(animation_name):
			return false
		for frame_index: int in range(first_frames.get_frame_count(animation_name)):
			var first_image := APPEARANCE._get_texture_image(
				first_frames.get_frame_texture(animation_name, frame_index)
			)
			var second_image := APPEARANCE._get_texture_image(
				second_frames.get_frame_texture(animation_name, frame_index)
			)
			if first_image == null or second_image == null:
				return false
			if first_image.get_size() != second_image.get_size():
				return false
			for y: int in range(first_image.get_height()):
				for x: int in range(first_image.get_width()):
					if not first_image.get_pixel(x, y).is_equal_approx(second_image.get_pixel(x, y)):
						return false
	return true


func _opaque_pixels_match_color(frames: SpriteFrames, expected_color: Color) -> bool:
	if frames == null:
		return false
	var found_opaque_pixel := false
	for animation_name_text: String in frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		for frame_index: int in range(frames.get_frame_count(animation_name)):
			var image := APPEARANCE._get_texture_image(
				frames.get_frame_texture(animation_name, frame_index)
			)
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					var pixel := image.get_pixel(x, y)
					if pixel.a <= 0.001:
						continue
					found_opaque_pixel = true
					if not pixel.is_equal_approx(expected_color):
						return false
	return found_opaque_pixel


func _body_uses_skin_under_base_hair(
	body_frames: SpriteFrames,
	base_hair_frames: SpriteFrames
) -> bool:
	if body_frames == null or base_hair_frames == null:
		return false
	for animation_name_text: String in base_hair_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if not body_frames.has_animation(animation_name):
			return false
		for frame_index: int in range(base_hair_frames.get_frame_count(animation_name)):
			var body_image := APPEARANCE._get_texture_image(
				body_frames.get_frame_texture(animation_name, frame_index)
			)
			var base_hair_image := APPEARANCE._get_texture_image(
				base_hair_frames.get_frame_texture(animation_name, frame_index)
			)
			for y: int in range(base_hair_image.get_height()):
				for x: int in range(base_hair_image.get_width()):
					if base_hair_image.get_pixel(x, y).a <= 0.001:
						continue
					if not APPEARANCE._is_skin_palette_pixel(body_image.get_pixel(x, y)):
						return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
