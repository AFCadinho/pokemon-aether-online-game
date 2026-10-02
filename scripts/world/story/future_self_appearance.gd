extends RefCounted

const Appearance := preload("res://scripts/services/character_appearance_service.gd")


static func build_state(player_appearance: Dictionary) -> Dictionary:
	var state := player_appearance.duplicate(true)
	state.merge({
		"top": "Mysterious_Shirt",
		"bottom": "Mysterious_Trousers",
		"shoes": "Mysterious_Shoes",
		"facegear": "Mysterious_Mask",
		"hair": "", "headgear": "", "facial_hair": "", "cape": "",
	}, true)
	return state


static func build_overworld_frames(state: Dictionary) -> SpriteFrames:
	var gender := Appearance.normalize_gender(str(state.get("gender", "male")))
	var body_id := Appearance.resolve_body_model_id(str(state.get("body", "")), gender)
	var body := Appearance.get_skin_tinted_body_frames(
		body_id, gender, Appearance.BODY_MOVEMENT_DEFAULT,
		str(state.get("skin_tone", Appearance.DEFAULT_SKIN_TONE))
	)
	if body == null:
		return null
	# Match Mt. Moon's layer order, then flatten it so BaseNPC movement and
	# battle staging can use the same synchronized directional animations.
	var layers: Array[SpriteFrames] = [body]
	for category: String in ["bottom", "shoes", "top"]:
		layers.append(Appearance.get_part_frames(category, str(state[category]), gender))
	layers.append(Appearance.get_tinted_part_frames(
		"eyes", Appearance.get_default_part_id("eyes", gender), gender,
		Appearance.BODY_MOVEMENT_DEFAULT,
		Color.from_string(str(state.get("eye_color", "white")), Color.WHITE)
	))
	layers.append(Appearance.get_part_frames("facegear", str(state["facegear"]), gender))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: StringName in body.get_animation_names():
		frames.add_animation(animation)
		frames.set_animation_speed(animation, body.get_animation_speed(animation))
		frames.set_animation_loop(animation, body.get_animation_loop(animation))
		for index: int in range(body.get_frame_count(animation)):
			var frame_size := Vector2i(body.get_frame_texture(animation, index).get_size())
			var image := Image.create(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			for layer: SpriteFrames in layers:
				if layer == null or not layer.has_animation(animation):
					continue
				var texture := layer.get_frame_texture(animation, index)
				var source := Appearance._get_texture_image(texture)
				if source == null:
					continue
				source.convert(Image.FORMAT_RGBA8)
				image.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)
			frames.add_frame(animation, ImageTexture.create_from_image(image), body.get_frame_duration(animation, index))
	return frames
