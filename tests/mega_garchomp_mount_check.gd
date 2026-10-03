extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
var current_mount_id := "mega_garchomp"
var current_item_id := "mega-garchomp-mount"
const DIRECTIONS := ["down", "left", "right", "up"]
const FACING := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
var failed := false
var approved_foreground: Image


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for mount_id: String in ["mega_garchomp"]:
		current_mount_id = mount_id
		current_item_id = mount_id.replace("_", "-") + "-mount"
		await _check_mount()
	print("Mega Garchomp mount checks: ", "FAILED" if failed else "PASS")
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
	var source := Mounts._load_mount_texture("res://assets/mounts/" + current_mount_id + "/source/mount.png").get_image()
	approved_foreground = Mounts._load_mount_texture("res://assets/mounts/mega_garchomp/source/foreground.png").get_image()
	approved_foreground.convert(Image.FORMAT_RGBA8)
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mounts/mega_garchomp/source/approved_v7.json"))[current_mount_id]
	for row in range(4):
		var anim := StringName("walk_" + DIRECTIONS[row])
		_check(mount.get_frame_count(anim) == 4, "four walking phases")
		_check(mount.get_animation_speed(anim) == 5.0, "approved walk tempo")
		_check(foreground.get_animation_speed(anim) == mount.get_animation_speed(anim), "foreground tempo synchronized")
		var seats: Array[Vector2i] = []
		for phase in range(4):
			var seat := Mounts.get_rider_frame_offset(current_mount_id, DIRECTIONS[row], phase)
			if not seats.has(seat):
				seats.append(seat)
			var approved_seat: Array = approved["riderOffsets"][DIRECTIONS[row]][phase]
			_check(seat == Vector2i(approved_seat[0], approved_seat[1] - 2), "approved V7 relative seating retained")
			var next := Mounts.get_rider_frame_offset(current_mount_id, DIRECTIONS[row], (phase + 1) % 4)
			_check(Vector2(seat - next).length() <= 6.0, "seat movement stays small across the loop seam")

		for col in range(4):
			var frame := Mounts._get_texture_image(mount.get_frame_texture(anim, col))
			var fg := Mounts._get_texture_image(foreground.get_frame_texture(anim, col))
			_check(frame.get_size() == Vector2i(192, 192), "padded frame size")
			var foot := frame.get_used_rect().end.y - 96 - 16
			_check(foot >= 12 and foot <= 16, "paws use ordinary player ground line")
			var art_matches := true
			var layers_match := true
			for y in range(192):
				for x in range(192):
					var pixel := frame.get_pixel(x, y)
					var point := Vector2i(x, y + 2)
					var expected := Color.TRANSPARENT
					if Rect2i(0, 0, 192, 192).has_point(point):
						expected = source.get_pixelv(point + Vector2i(col * 192, row * 192))
					if pixel.a != expected.a or (pixel.a > 0 and pixel != expected):
						art_matches = false
					var front_pixel := fg.get_pixel(x, y)
					var hidden := mask.get_pixel(x + col * 192, y + row * 192).a > 0.0
					if hidden != (front_pixel.a > 0.0) or (front_pixel.a > 0.0 and front_pixel != pixel):
						layers_match = false
			_check(art_matches, "approved artwork preserved exactly at native 2x scale")
			_check(layers_match, "mask and foreground follow creature pixels")
			_check_occlusion(frame, fg, row, col)
	for gender: String in ["male", "female"]:
		await _check_avatars(gender)


func _check_occlusion(frame: Image, foreground: Image, row: int, col: int) -> void:
	var same := true
	var protected_pixels := 0
	for y in range(192):
		for x in range(192):
			var actual := foreground.get_pixel(x,y)
			var expected := Color.TRANSPARENT
			if y+2 < 192:
				expected = approved_foreground.get_pixel(x+col*192,y+2+row*192)
			if actual.a != expected.a or (actual.a > 0 and actual != expected):
				same = false
			if actual.a > 0:
				protected_pixels += 1
	_check(same and protected_pixels > 0, "approved V7 head and dorsal-fin contours preserved in runtime foreground")
	if row == 0:
		_check(frame.get_data() == foreground.get_data(), "complete front head remains visible without a horizontal cutoff")


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
	remote.call("apply_state", {"userId": 1, "displayName": "Garchomp rider", "gender": gender, "position": {"x": 0, "y": 0}, "facingDirection": "down", "movement": {"isMoving": false, "activityStyle": "ride", "mountId": current_mount_id}})
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
