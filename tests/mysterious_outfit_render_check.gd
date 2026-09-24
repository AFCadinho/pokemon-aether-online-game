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
