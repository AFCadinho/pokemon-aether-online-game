extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
var current_mount_id := "glaceon"
var current_item_id := "glaceon-mount"
const DIRECTIONS := ["down", "left", "right", "up"]
const FACING := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for mount_id: String in ["glaceon"]:
		current_mount_id = mount_id
		current_item_id = mount_id.replace("_", "-") + "-mount"
		await _check_mount()
	print("Glaceon mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_mount() -> void:
	_check(Mounts.get_mount_id_for_unlock_item(current_item_id) == current_mount_id, "unlock item resolves")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", [current_item_id]) == [current_mount_id], "item unlocks only its mount")
	_check(Mounts.is_mount_unlocked(current_mount_id, [current_item_id + "-bound"]), "bound entitlement works")
	_check(not Mounts.is_mount_unlocked(current_mount_id, []), "ownership required")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = root.get_node("ItemLocalization").call("get_catalog", locale)
		var localized: Dictionary = catalog.get(current_item_id, {})
		_check(not str(localized.get("name", "")).is_empty() and not str(localized.get("shortDesc", "")).is_empty(), "localized mount item in " + locale)
	_check(Mounts.resolve_mount_id_for_mode(current_mount_id, "surf").is_empty(), "land mount cannot bypass surf rules")
	var icon := Icons.load_icon(current_item_id)
	_check(icon != null and icon.get_size() == Vector2(64, 64), "dedicated Bag icon loads")
	var mount := Mounts.get_mount_frames(current_mount_id)
	var foreground := Mounts.get_mount_foreground_frames(current_mount_id)
	var mask := Mounts._get_mask_image(current_mount_id)
	_check(mount != null and foreground != null and mask != null, "runtime atlases load")
	if mount == null or foreground == null or mask == null:
		quit(1)
		return
	var source := Mounts._load_mount_texture("res://assets/followers/GLACEON.png").get_image()
	var expected_seats := [Vector2i(0, -30), Vector2i(14, -26), Vector2i(-14, -26), Vector2i(0, -20)]
	for row in range(4):
		var anim := StringName("walk_" + DIRECTIONS[row])
		_check(mount.get_frame_count(anim) == 4, "four walking phases")
		_check(mount.get_animation_speed(anim) == 5.0, "walking tempo")
		_check(foreground.get_animation_speed(anim) == mount.get_animation_speed(anim), "foreground tempo synchronized")
		for col in range(4):
			var seat: Vector2i = expected_seats[row]
			if row in [1, 2]:
				seat.y += 2 * (col % 2)
			_check(Mounts.get_rider_frame_offset(current_mount_id, DIRECTIONS[row], col) == seat, "lower seated fit and synchronized bob")
			var frame := Mounts._get_texture_image(mount.get_frame_texture(anim, col))
			var fg := Mounts._get_texture_image(foreground.get_frame_texture(anim, col))
			_check(frame.get_size() == Vector2i(224, 224), "padded frame size")
			var native_pixels := true
			var matching_layers := true
			for y in range(224):
				for x in range(224):
					var pixel := frame.get_pixel(x, y)
					var expected := Color.TRANSPARENT
					if Rect2i(80, 68, 64, 64).has_point(Vector2i(x, y)):
						expected = source.get_pixel(x - 80 + col * 64, y - 68 + row * 64)
					if pixel.a != expected.a or (pixel.a > 0 and pixel != expected):
						native_pixels = false
					var front := fg.get_pixel(x, y)
					var hidden := mask.get_pixel(x + col * 224, y + row * 224).a > 0
					if hidden != (front.a > 0) or (front.a > 0 and front != pixel):
						matching_layers = false
			_check(native_pixels, "original 1x follower pixels preserved, without added scaling")
			_check(matching_layers, "foreground uses source pixels and matches rider mask")
			if row in [1, 2]:
				# Known interior pixels of the far upper ear and near hanging flap.
				var far_x := 32 if row == 1 else 31
				var near_x := 24 if row == 1 else 39
				var far_point := Vector2i(80 + far_x, 68 + 24 + 2 * (col % 2))
				var near_point := Vector2i(80 + near_x, 68 + 46 + 2 * (col % 2))
				_check(frame.get_pixelv(far_point).a > 0 and fg.get_pixelv(far_point).a == 0, "far ear stays behind rider")
				_check(fg.get_pixelv(near_point).a > 0, "near head flap remains ahead of rider")
			if row == 3:
				_check(fg.is_invisible(), "rear view keeps mount behind rider")
	for gender: String in ["male", "female"]:
		await _check_avatars(gender)


func _check_avatars(gender: String) -> void:
	var save := root.get_node("PlayerSave")
	save.set("gender", gender)
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	root.add_child(local)
	local.set("base_look_position", local.get_node("Look").position)
	local.set("active_mount_id", current_mount_id)
	local.set("activity_style", "ride")
	local.call("_cache_appearance_sprites")
	local.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID if gender == "male" else Appearance.DEFAULT_FEMALE_BODY_ID)
	local.call("_connect_mount_frame_sync")
	local.call("_sync_mount_visual")
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.call("apply_state", {"userId": 1, "displayName": "Glaceon rider", "gender": gender, "position": {"x": 0, "y": 0}, "facingDirection": "down", "movement": {"isMoving": false, "activityStyle": "ride", "mountId": current_mount_id}})
	for avatar: Node2D in [local, remote]:
		var mount := avatar.get_node("Look/MountSprite") as AnimatedSprite2D
		var body := avatar.get_node("Look/Rider/BodySprite") as AnimatedSprite2D
		var foreground := avatar.get_node("Look/MountForegroundSprite") as AnimatedSprite2D
		var rider := avatar.get_node("Look/Rider") as Node2D
		_check(mount.visible and foreground.visible, "local/remote mount layers visible")
		for row in range(4):
			avatar.call("_sync_mount_animation", true, FACING[row])
			avatar.call("_sync_activity_layer_offsets")
			for col in range(4):
				mount.frame = col
				_check(body.frame == col and foreground.frame == col, "rider mask and foreground follow mount frame")
				_check(not body.is_playing(), "rider keeps static seated pose")
				_check(rider.position == Vector2(Mounts.get_rider_frame_offset(current_mount_id, DIRECTIONS[row], col)), "runtime uses directional seat offsets")
				_check(body.sprite_frames.get_frame_texture(body.animation, col).get_size() == Vector2(64, 64), "player retains original frame size")
			avatar.call("_sync_mount_animation", false, FACING[row])
			_check(mount.frame == 0 and body.frame == 0 and foreground.frame == 0, "idle returns all layers to first phase")
			_check(not mount.is_playing(), "idle is stationary")
		var look_before: Vector2 = avatar.get_node("Look").position
		avatar.call("_update_mount_hover", 0.7)
		_check(avatar.get_node("Look").position == look_before, "walking mount does not levitate")
	local.queue_free()
	remote.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(current_mount_id + ": " + message)
