extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var save := root.get_node("PlayerSave")
	var previous_gender: String = save.gender
	var previous_hat: String = save.appearance_headgear_id
	save.gender = "male"
	var player = load("res://scenes/player.tscn").instantiate()
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	remote.current_body_gender = "male"
	for style: String in ["walk", "fish", "ride"]:
		player.body_sprite_frames_movement_style = style
		remote.current_body_movement_style = style
		for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			player.last_direction = direction
			remote.last_direction = direction
			for hat: String in ["TeamRocket_Cap", "Cap"]:
				save.appearance_headgear_id = hat
				remote.current_appearance_state = {"headgear": hat}
				var actual: Vector2 = player._get_activity_layer_offset("headgear")
				var other: Vector2 = remote._get_activity_layer_offset("headgear")
				var expected := Vector2.ZERO
				if hat == "Cap":
					if style == "fish":
						expected = Vector2(0, -10) if direction == Vector2.DOWN else Vector2(12, 1) if direction == Vector2.LEFT else Vector2(-12, 1) if direction == Vector2.RIGHT else Vector2(0, 1)
					elif style == "ride":
						expected = Vector2.ZERO if direction == Vector2.UP else Vector2(-4, 4) if direction == Vector2.LEFT else Vector2(4, 4) if direction == Vector2.RIGHT else Vector2(0, 4)
				_check(actual == expected and other == expected, "%s %s %s local and remote offsets match the authored pose" % [hat, style, direction])
	# Exercise the live synchronization methods, not just sheet frame counts.
	var body_sprite := AnimatedSprite2D.new()
	body_sprite.name = "BodySprite"
	body_sprite.sprite_frames = APPEARANCE.get_body_frames("Gen4_Base_v1", "male")
	player.add_child(body_sprite)
	player.master_appearance_sprite = body_sprite
	player.appearance_sprites.append(body_sprite)
	remote.appearance_sprites.append(body_sprite)
	player.activity_style = "walk"
	remote.current_activity_style = "walk"
	var live_parts: Array[AnimatedSprite2D] = []
	for category: String in ["top", "bottom", "shoes", "headgear"]:
		var id := {"top": "TeamRocket_Shirt", "bottom": "TeamRocket_Trousers", "shoes": "TeamRocket_Shoes", "headgear": "TeamRocket_Cap"}[category] as String
		for is_remote: bool in [false, true]:
			var part := AnimatedSprite2D.new()
			part.sprite_frames = APPEARANCE.get_part_frames(category, id, "male")
			player.add_child(part)
			live_parts.append(part)
			if is_remote:
				remote.appearance_sprites.append(part)
			else:
				player.appearance_sprites.append(part)
	for direction: String in ["down", "left", "right", "up"]:
		for index: int in range(4):
			body_sprite.play(StringName("walk_" + direction))
			body_sprite.set_frame_and_progress(index, 0.4)
			player._sync_appearance_sprite_frames()
			for part: AnimatedSprite2D in remote.appearance_sprites:
				remote._sync_sprite_to_body(part)
			var matches := true
			for part: AnimatedSprite2D in live_parts:
				matches = matches and part.animation == body_sprite.animation and part.frame == index and is_equal_approx(part.frame_progress, 0.4)
			_check(matches, "%s step %s all outfit layers follow local and remote body timing" % [direction, index])
	player.free()
	remote.free()
	save.gender = previous_gender
	save.appearance_headgear_id = previous_hat
	var body := (load("res://assets/player/male/body/Gen4_Base_v1.png") as Texture2D).get_image()
	var boots := (load("res://assets/player/male/shoes/TeamRocket_Shoes.png") as Texture2D).get_image()
	var shirt := (load("res://assets/player/male/top/TeamRocket_Shirt.png") as Texture2D).get_image()
	# The torso material and chest mark must move with the body, independently
	# of the raised arm's bounding box. A whole-shirt rescale breaks this.
	for row: int in [0, 3]:
		var idle_head_y := body.get_region(Rect2i(0, row * 64, 64, 64)).get_used_rect().position.y
		for col: int in [1, 3]:
			var step_head_y := body.get_region(Rect2i(col * 64, row * 64, 64, 64)).get_used_rect().position.y
			var torso_matches := true
			for y: int in range(40, 54):
				# Keep inside the chest; side contour gaps change with the arms.
				for x: int in range(28, 34):
					torso_matches = torso_matches and shirt.get_pixel(x, row * 64 + y) == shirt.get_pixel(col * 64 + x, row * 64 + y + step_head_y - idle_head_y)
			_check(torso_matches, "row %s step %s collar and torso follow the body's vertical displacement" % [row, col])
	for style: String in ["walk", "fish", "ride"]:
		var frames := APPEARANCE.get_part_frames("headgear", "TeamRocket_Cap", "male", style)
		for col: int in range(4):
			var hat := frames.get_frame_texture(&"walk_up", col).get_image()
			var seen_cap := false
			var passed_cap := false
			var contiguous := true
			for y: int in range(hat.get_height()):
				var occupied := false
				for x: int in range(hat.get_width()):
					occupied = occupied or hat.get_pixel(x, y).a > 0.5
				if occupied:
					contiguous = contiguous and not passed_cap
					seen_cap = true
				elif seen_cap:
					passed_cap = true
			_check(seen_cap and contiguous, "%s rear frame %s has no detached stripe below the cap" % [style, col])
	for row: int in range(4):
		for col: int in range(4):
			var covered := true
			var sole_count := 0
			for y: int in range(58, 64):
				for x: int in range(12, 52):
					var point := Vector2i(col * 64 + x, row * 64 + y)
					if body.get_pixelv(point).a > 0.5:
						covered = covered and boots.get_pixelv(point).a > 0.5
						sole_count += 1
			_check(covered and sole_count > 0, "row %s frame %s boots cover the actual body toes" % [row, col])
		for col: int in [0, 2]:
			if row in [0, 3]:
				_check(boots.get_pixel(col * 64 + 30, row * 64 + 56).a == 0, "idle boots remain separated at the crotch")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
