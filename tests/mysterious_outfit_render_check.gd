extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const REMOTE_AVATAR_PATH := "res://scripts/world/remote_player_avatar.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for gender: String in ["female", "male"]:
		_check_full_outfit_coverage(gender)
		_check_patreon_placeholder_assets(gender)
	_check_front_cape_opacity()
	_check_local_frame_sync()
	await _check_remote_frame_sync()
	quit(1 if failed else 0)


func _check_full_outfit_coverage(gender: String) -> void:
	var body_id := Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
	var body := Appearance.get_body_frames(body_id, gender)
	var parts: Array[SpriteFrames] = [
		Appearance.get_part_frames("bottom", "Mysterious_Trousers", gender),
		Appearance.get_part_frames("shoes", "Mysterious_Shoes", gender),
		Appearance.get_part_frames("top", "Mysterious_Shirt", gender),
		Appearance.get_part_frames("facegear", "Mysterious_Mask", gender),
	]
	if body == null or parts.has(null):
		_check(false, "%s Mysterious Outfit layers load" % gender)
		return
	for animation: StringName in [&"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
		for frame: int in range(4):
			var body_image := body.get_frame_texture(animation, frame).get_image()
			var part_images: Array[Image] = []
			for part: SpriteFrames in parts:
				part_images.append(part.get_frame_texture(animation, frame).get_image())
			for y: int in range(36, 64):
				for x: int in range(64):
					var body_pixel := body_image.get_pixel(x, y)
					if body_pixel.a < 0.5 or body_pixel.r < 0.4 \
							or body_pixel.r < body_pixel.g * 1.12 \
							or body_pixel.g < body_pixel.b * 1.12:
						continue
					var covered := false
					for part_image: Image in part_images:
						if part_image.get_pixel(x, y).a > 0.5:
							covered = true
							break
					if not covered:
						_check(false, "%s %s frame %d exposes skin at %d,%d" % [gender, animation, frame, x, y])
						return
	_check(true, "%s Mysterious Outfit covers skin below the cape in every walking frame" % gender)


func _check_patreon_placeholder_assets(gender: String) -> void:
	for part: Dictionary in [
		{"category": "facegear", "id": "Patreon_Supporter_Mask"},
		{"category": "top", "id": "Patreon_Supporter_Shirt"},
		{"category": "bottom", "id": "Patreon_Supporter_Trousers"},
		{"category": "shoes", "id": "Patreon_Supporter_Shoes"},
	]:
		var frames := Appearance.get_part_frames(part["category"], part["id"], gender)
		_check(frames != null, "%s %s Patreon placeholder assets load" % [gender, part["id"]])
		if frames == null:
			return
		for animation: StringName in [&"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
			_check(frames.has_animation(animation) and frames.get_frame_count(animation) == 4,
				"%s %s has all %s placeholder frames" % [gender, part["id"], animation])


func _check_front_cape_opacity() -> void:
	for frame: int in range(4):
		var male_images := _outfit_frame_images("male", &"walk_down", frame)
		var female_images := _outfit_frame_images("female", &"walk_down", frame)
		for y: int in range(48, 60):
			for x: int in range(16, 48):
				if _is_opaque(male_images, x, y) and not _is_opaque(female_images, x, y):
					_check(false, "female front frame %d leaves a cape opening at %d,%d" % [frame, x, y])
					return
	_check(true, "female front cape has the same complete hem silhouette as male in every frame")


func _outfit_frame_images(gender: String, animation: StringName, frame: int) -> Array[Image]:
	var body_id := Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
	var images: Array[Image] = [Appearance.get_body_frames(body_id, gender).get_frame_texture(animation, frame).get_image()]
	for part: Dictionary in _outfit_parts():
		images.append(Appearance.get_part_frames(part["category"], part["id"], gender).get_frame_texture(animation, frame).get_image())
	return images


func _is_opaque(images: Array[Image], x: int, y: int) -> bool:
	for image: Image in images:
		if image.get_pixel(x, y).a > 0.5:
			return true
	return false


func _check_local_frame_sync() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.set("look_node", player.get_node("Look"))
	player.call("_cache_appearance_sprites")
	var body := player.get_node("Look/Rider/BodySprite") as AnimatedSprite2D
	body.sprite_frames = Appearance.get_body_frames(Appearance.DEFAULT_MALE_BODY_ID, "male")
	for part: Dictionary in _outfit_parts():
		var sprite := player.get_node("Look/Rider/%s" % part["sprite"]) as AnimatedSprite2D
		sprite.sprite_frames = Appearance.get_part_frames(part["category"], part["id"], "male")
	body.animation = &"walk_left"
	body.play()
	body.frame = 1
	_check(_all_outfit_layers_match(player.get_node("Look/Rider"), body), "local outfit follows a body-frame change immediately")
	player.free()


func _check_remote_frame_sync() -> void:
	var avatar: Node2D = (load(REMOTE_AVATAR_PATH) as Script).new() as Node2D
	root.add_child(avatar)
	avatar.call("_apply_appearance_state", {
		"body": Appearance.DEFAULT_MALE_BODY_ID,
		"top": "Mysterious_Shirt",
		"bottom": "Mysterious_Trousers",
		"shoes": "Mysterious_Shoes",
		"facegear": "Mysterious_Mask",
	})
	var body := avatar.call("_get_body_sprite") as AnimatedSprite2D
	body.animation = &"walk_left"
	body.play()
	body.frame = 1
	_check(_all_outfit_layers_match(avatar.get_node("Look/Rider"), body), "remote outfit follows a body-frame change immediately")
	avatar.queue_free()
	await process_frame


func _outfit_parts() -> Array[Dictionary]:
	return [
		{"sprite": "BottomSprite", "category": "bottom", "id": "Mysterious_Trousers"},
		{"sprite": "ShoesSprite", "category": "shoes", "id": "Mysterious_Shoes"},
		{"sprite": "TopSprite", "category": "top", "id": "Mysterious_Shirt"},
		{"sprite": "FaceGearSprite", "category": "facegear", "id": "Mysterious_Mask"},
	]


func _all_outfit_layers_match(rider: Node, body: AnimatedSprite2D) -> bool:
	for part: Dictionary in _outfit_parts():
		var sprite := rider.get_node(part["sprite"]) as AnimatedSprite2D
		if sprite == null or not sprite.visible or sprite.animation != body.animation \
				or sprite.frame != body.frame:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error(message)
