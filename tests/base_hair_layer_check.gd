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

	var authored_adinho_frames := APPEARANCE.get_part_frames("hair", "Adinho_Hair", "male")
	var previous_adinho_render := APPEARANCE._build_tinted_sprite_frames(
		authored_adinho_frames,
		TEST_HAIR_COLOR,
		true
	)
	var layered_adinho_render := APPEARANCE.get_tinted_part_frames(
		"hair",
		"Adinho_Hair",
		"male",
		APPEARANCE.BODY_MOVEMENT_DEFAULT,
		TEST_HAIR_COLOR,
		true
	)
	_check(
		_frames_preserve_opaque_overlay(previous_adinho_render, layered_adinho_render),
		"the base-hair layer cannot alter existing Adinho hairstyle pixels"
	)
	_check(
		_count_added_opaque_pixels(previous_adinho_render, layered_adinho_render) > 0,
		"the base-hair layer fills the transparent gap in the Adinho hairstyle"
	)
	_check(
		_added_pixels_match_color(
			previous_adinho_render,
			layered_adinho_render,
			TEST_HAIR_COLOR
		),
		"newly filled base-hair pixels use the selected hair colour"
	)

	for hairstyle: Dictionary in [
		{"gender": "male", "id": "Hair", "color": Color("#5a3728")},
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
		var layered_render := APPEARANCE.get_tinted_part_frames(
			"hair",
			hairstyle_id,
			gender,
			APPEARANCE.BODY_MOVEMENT_DEFAULT,
			hair_color,
			true
		)
		_check(
			_frames_are_equal(previous_render, layered_render),
			"%s remains pixel-identical where it already covers the base layer" % hairstyle_id
		)

	var fixed_blossom_frames := APPEARANCE.get_part_frames(
		"hair",
		"Aether_Blossom_Hair",
		"female"
	)
	var female_base_hair_frames := APPEARANCE.get_part_frames(
		"hair",
		APPEARANCE.BASE_HAIR_ID,
		"female"
	)
	_check(
		_underlay_is_fully_covered(female_base_hair_frames, fixed_blossom_frames),
		"the fixed-colour Blossom hairstyle already fully covers the base layer"
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
			"base-hair composition renders for %s movement" % movement_style
		)

	quit(1 if failed else 0)


func _frames_preserve_opaque_overlay(overlay_frames: SpriteFrames, layered_frames: SpriteFrames) -> bool:
	if overlay_frames == null or layered_frames == null:
		return false
	for animation_name_text: String in overlay_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if not layered_frames.has_animation(animation_name):
			return false
		if (
			overlay_frames.get_frame_count(animation_name)
			!= layered_frames.get_frame_count(animation_name)
		):
			return false
		for frame_index: int in range(overlay_frames.get_frame_count(animation_name)):
			var overlay_image := APPEARANCE._get_texture_image(
				overlay_frames.get_frame_texture(animation_name, frame_index)
			)
			var layered_image := APPEARANCE._get_texture_image(
				layered_frames.get_frame_texture(animation_name, frame_index)
			)
			if not _image_preserves_opaque_overlay(overlay_image, layered_image):
				return false
	return true


func _image_preserves_opaque_overlay(overlay_image: Image, layered_image: Image) -> bool:
	if overlay_image == null or layered_image == null:
		return false
	if overlay_image.get_size() != layered_image.get_size():
		return false
	for y: int in range(overlay_image.get_height()):
		for x: int in range(overlay_image.get_width()):
			var overlay_pixel := overlay_image.get_pixel(x, y)
			if overlay_pixel.a <= 0.001:
				continue
			if not overlay_pixel.is_equal_approx(layered_image.get_pixel(x, y)):
				return false
	return true


func _count_added_opaque_pixels(overlay_frames: SpriteFrames, layered_frames: SpriteFrames) -> int:
	if overlay_frames == null or layered_frames == null:
		return 0
	var added_pixels := 0
	for animation_name_text: String in overlay_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		for frame_index: int in range(overlay_frames.get_frame_count(animation_name)):
			var overlay_image := APPEARANCE._get_texture_image(
				overlay_frames.get_frame_texture(animation_name, frame_index)
			)
			var layered_image := APPEARANCE._get_texture_image(
				layered_frames.get_frame_texture(animation_name, frame_index)
			)
			for y: int in range(overlay_image.get_height()):
				for x: int in range(overlay_image.get_width()):
					if (
						overlay_image.get_pixel(x, y).a <= 0.001
						and layered_image.get_pixel(x, y).a > 0.001
					):
						added_pixels += 1
	return added_pixels


func _added_pixels_match_color(
	overlay_frames: SpriteFrames,
	layered_frames: SpriteFrames,
	expected_color: Color
) -> bool:
	if overlay_frames == null or layered_frames == null:
		return false
	for animation_name_text: String in overlay_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		for frame_index: int in range(overlay_frames.get_frame_count(animation_name)):
			var overlay_image := APPEARANCE._get_texture_image(
				overlay_frames.get_frame_texture(animation_name, frame_index)
			)
			var layered_image := APPEARANCE._get_texture_image(
				layered_frames.get_frame_texture(animation_name, frame_index)
			)
			for y: int in range(overlay_image.get_height()):
				for x: int in range(overlay_image.get_width()):
					if overlay_image.get_pixel(x, y).a > 0.001:
						continue
					var layered_pixel := layered_image.get_pixel(x, y)
					if layered_pixel.a <= 0.001:
						continue
					if not layered_pixel.is_equal_approx(expected_color):
						return false
	return true


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


func _underlay_is_fully_covered(
	underlay_frames: SpriteFrames,
	overlay_frames: SpriteFrames
) -> bool:
	if underlay_frames == null or overlay_frames == null:
		return false
	for animation_name_text: String in underlay_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		if not overlay_frames.has_animation(animation_name):
			return false
		for frame_index: int in range(underlay_frames.get_frame_count(animation_name)):
			var underlay_image := APPEARANCE._get_texture_image(
				underlay_frames.get_frame_texture(animation_name, frame_index)
			)
			var overlay_image := APPEARANCE._get_texture_image(
				overlay_frames.get_frame_texture(animation_name, frame_index)
			)
			for y: int in range(underlay_image.get_height()):
				for x: int in range(underlay_image.get_width()):
					if (
						underlay_image.get_pixel(x, y).a > 0.001
						and overlay_image.get_pixel(x, y).a <= 0.001
					):
						return false
	return true


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
