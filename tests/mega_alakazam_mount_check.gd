extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const MOUNT := "mega_alakazam"
const DIRECTIONS := ["down", "left", "right", "up"]
const FACING := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Mounts.get_mount_id_for_unlock_item("mega-alakazam-mount") == MOUNT, "grant item resolves to mount")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["mega-alakazam-mount"]) == [MOUNT], "item unlocks only Alakazam")
	_check(Mounts.is_mount_unlocked(MOUNT, ["mega-alakazam-mount-bound"]), "bound item retains entitlement")
	_check(not Mounts.is_mount_unlocked(MOUNT, []), "ownership required")
	_check(Mounts.resolve_mount_id_for_mode(MOUNT, "surf") == "", "levitation keeps land movement rules")
	_check(Icons.load_icon("mega-alakazam-mount") != null, "Bag icon loads")
	var frames := Mounts.get_mount_frames(MOUNT)
	var front := Mounts.get_mount_foreground_frames(MOUNT)
	var mask := Mounts._get_mask_image(MOUNT)
	_check(frames != null and front != null and mask != null, "all three runtime sheets load")
	if frames == null or front == null or mask == null:
		quit(1)
		return
	for row in range(4):
		var animation := StringName("walk_" + DIRECTIONS[row])
		_check(frames.get_frame_count(animation) == 4, "four animation frames")
		_check(frames.get_animation_speed(animation) == front.get_animation_speed(animation), "foreground rhythm matches mount")
		for col in range(4):
			var creature := Mounts._get_texture_image(frames.get_frame_texture(animation, col))
			var foreground := Mounts._get_texture_image(front.get_frame_texture(animation, col))
			_check(creature.get_size() == Vector2i(224, 224), "large runtime frames retain concept scale")
			_check((foreground.get_used_rect().size != Vector2i.ZERO) == (row == 3), "only rear body overlays rider")
			var silhouette_matches := true
			var colors_match := true
			for y in range(224):
				for x in range(224):
					var pixel := foreground.get_pixel(x, y)
					if (mask.get_pixel(x + col * 224, y + row * 224).a > 0.0) != (pixel.a > 0.0):
						silhouette_matches = false
					if pixel.a > 0.0 and pixel != creature.get_pixel(x, y):
						colors_match = false
			_check(silhouette_matches, "rider mask follows exact foreground silhouette")
			_check(colors_match, "foreground retains original creature colors")
	for gender: String in ["male", "female"]:
		var body := Appearance.DEFAULT_MALE_BODY_ID if gender == "male" else Appearance.DEFAULT_FEMALE_BODY_ID
		var original := Appearance.get_body_frames(body, gender, "ride")
		var mounted := Mounts.get_mounted_rider_frames(original, MOUNT, {}, {}, true)
		for row in range(4):
			var animation := StringName("walk_" + DIRECTIONS[row])
			var source := Mounts._get_texture_image(original.get_frame_texture(animation, 0))
			for col in range(4):
				var result := Mounts._get_texture_image(mounted.get_frame_texture(animation, col))
				_check(result.get_size() == Vector2i(64, 64), "rider remains original size")
				_check_masked_layer(source, result, mask, row, col, Mounts.get_rider_frame_offset(MOUNT, DIRECTIONS[row], col))
	await _check_runtime()
	print("Mega Alakazam mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_runtime() -> void:
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	root.add_child(local)
	local.set("base_look_position", local.get_node("Look").position)
	local.set("active_mount_id", MOUNT)
	local.set("activity_style", "ride")
	local.call("_cache_appearance_sprites")
	local.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID)
	local.call("_connect_mount_frame_sync")
	local.call("_sync_mount_visual")
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.call("apply_state", {"userId": 1, "displayName": "Alakazam rider", "gender": "female", "position": {"x": 0, "y": 0}, "facingDirection": "up", "movement": {"isMoving": false, "activityStyle": "ride", "mountId": MOUNT}})
	var mask := Mounts._get_mask_image(MOUNT)
	for player: Node2D in [local, remote]:
		var mount := player.get_node("Look/MountSprite") as AnimatedSprite2D
		var body := player.get_node("Look/Rider/BodySprite") as AnimatedSprite2D
		var overlay := player.get_node("Look/MountForegroundSprite") as AnimatedSprite2D
		var rider := player.get_node("Look/Rider") as Node2D
		_check(mount.visible and overlay.visible, "actual avatar loads both mount layers")
		for row in range(4):
			player.call("_sync_mount_animation", true, FACING[row])
			player.call("_sync_activity_layer_offsets")
			for col in range(4):
				mount.frame = col
				_check(body.frame == col and not body.is_playing(), "mount frame selects static seated pose and mask")
				_check(overlay.frame == col, "foreground synchronizes")
				_check(rider.position == Vector2(Mounts.get_rider_frame_offset(MOUNT, DIRECTIONS[row], col)), "actual rider uses approved directional position")
				var shadow := player.get_node("MountHoverShadow") as Node2D
				_check(rider.global_position.x == shadow.global_position.x, "rider stays horizontally above the player's ground anchor in every frame")
			player.call("_sync_mount_animation", false, FACING[row])
			_check(rider.position == player.get("base_rider_position"), "turning while idle keeps the normal player foot origin")
			var grounded_look: Vector2 = (player.get_node("Look") as Node2D).position - player.call("_get_mount_hover_offset")
			_check(grounded_look == player.get("base_look_position"), "only levitation lifts the normal player origin")
			for category: String in ["hair", "eyes", "eyebrows"]:
				var name := str({"hair": "HairSprite", "eyes": "EyesSprite", "eyebrows": "EyebrowsSprite"}[category])
				var sprite := player.get_node("Look/Rider/" + name) as AnimatedSprite2D
				var method := "_get_player_appearance_part_id" if player == local else "_get_appearance_part_id"
				var part_id: String = player.call(method, category)
				var original: SpriteFrames = player.call("_get_appearance_part_frames", category, part_id, "ride")
				var animation := StringName("walk_" + DIRECTIONS[row])
				_check(original != null and sprite.sprite_frames != null, "head layers load")
				if original == null or sprite.sprite_frames == null:
					continue
				var source := Mounts._get_texture_image(original.get_frame_texture(animation, 0))
				for col in range(4):
					var result := Mounts._get_texture_image(sprite.sprite_frames.get_frame_texture(animation, col))
					var offset := Mounts.get_rider_frame_offset(MOUNT, DIRECTIONS[row], col) + Vector2i(sprite.offset)
					_check_masked_layer(source, result, mask, row, col, offset)
		var before := player.position
		player.call("_sync_mount_animation", false, Vector2.UP)
		var look_before := (player.get_node("Look") as Node2D).position
		player.call("_update_mount_hover", 0.6)
		_check((player.get_node("Look") as Node2D).position != look_before, "idle levitation moves rendering")
		_check(player.position == before, "levitation does not move ground/collision anchor")
	local.queue_free()
	remote.queue_free()
	await process_frame


func _check_masked_layer(source: Image, result: Image, mask: Image, row: int, col: int, offset: Vector2i) -> void:
	var matches := true
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var point := Vector2i(80, 80) + offset + Vector2i(x, y)
			var expected := source.get_pixel(x, y)
			if Rect2i(0, 0, 224, 224).has_point(point) and mask.get_pixelv(point + Vector2i(col * 224, row * 224)).a > 0.0:
				expected = Color.TRANSPARENT
			var actual := result.get_pixel(x, y)
			if actual.a != expected.a or (expected.a > 0.0 and actual != expected):
				matches = false
	_check(matches, "original ride pixels retained outside exact rear body mask")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
