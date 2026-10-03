extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const DIRECTIONS := ["down", "left", "right", "up"]
const HEAD_ROWS := {29: Vector2i(31, 33), 30: Vector2i(30, 34), 31: Vector2i(30, 34), 32: Vector2i(29, 35), 33: Vector2i(29, 35)}

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Mounts.get_mount_id_for_unlock_item("shadow-lugia-mount") == "shadow_lugia", "item resolves to Shadow Lugia")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["shadow-lugia-mount"]) == ["shadow_lugia"], "ownership unlocks only Shadow Lugia")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", []).is_empty(), "mount requires its item")
	_check(Mounts.resolve_mount_id_for_mode("shadow_lugia", "surf") == "", "hover retains land movement rules")
	_check(Icons.load_icon("shadow-lugia-mount") != null, "Bag mount icon loads")
	_check_animation_and_overlap()
	_check_riders()
	await _check_players()
	print("Shadow Lugia mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_animation_and_overlap() -> void:
	var frames := Mounts.get_mount_frames("shadow_lugia")
	var foreground := Mounts.get_mount_foreground_frames("shadow_lugia")
	_check(frames != null and foreground != null, "mount and foreground load")
	if frames == null or foreground == null:
		return
	for direction: String in DIRECTIONS:
		var walk := StringName("walk_" + direction)
		_check(frames.get_frame_count(walk) == 4 and frames.get_frame_count(StringName("idle_" + direction)) == 1, "movement and idle frames load")
		_check(frames.get_animation_speed(walk) == 4.0 and foreground.get_animation_speed(walk) == 4.0, "layers share the flight rhythm")
		var images: Array[Image] = []
		for index in range(4):
			var body := Mounts._get_texture_image(frames.get_frame_texture(walk, index))
			var front := Mounts._get_texture_image(foreground.get_frame_texture(walk, index))
			_check(body.get_size() == Vector2i(128, 128) and front.get_size() == Vector2i(128, 128), "mount layers stay 128px")
			images.append(body)
			if direction == "down":
				_check(front.get_pixel(62, 58).a == 0.0, "foreground does not redraw the tail near the head tip")
				_check(front.get_pixel(62, 78) == body.get_pixel(62, 78) and front.get_pixel(62, 78).a > 0.0, "lower face remains in front of the rider")
			else:
				_check(front.get_used_rect().size == Vector2i.ZERO, "only down-facing head has a foreground layer")
		_check(images[0].get_data() == images[2].get_data() and images[1].get_data() == images[3].get_data(), "approved A-B-A-B wing loop is preserved")
		_check(images[0].get_data() != images[1].get_data(), "two distinct wing poses animate")
	var mask := Mounts._get_mask_image("shadow_lugia")
	var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.MAGENTA)
	for index in range(4):
		var offset := Mounts.get_rider_frame_offset("shadow_lugia", "down", index)
		var result := Mounts._transform_rider_frame(source, mask, 0, index, offset, Vector2i(128, 128))
		var mount_image := Mounts._get_texture_image(frames.get_frame_texture(&"walk_down", index))
		# Test the actual approved silhouette above the broad foreground region.
		# The tail curves left of this head; a rectangular mask would expose it.
		for y in range(21, 34):
			for x in range(25, 37):
				var span: Vector2i = HEAD_ROWS.get(y, Vector2i.ZERO)
				var point := Vector2i(x * 2, y * 2)
				var on_head := x >= span.x and x < span.y and mount_image.get_pixelv(point).a > 0.0
				var rider_pixel := point - Vector2i(32, 32) - offset
				_check(result.get_pixelv(rider_pixel).a == (0.0 if on_head else 1.0), "head stays before rider; tail fork, shaft and curved edge stay behind, frame %d pixel %s" % [index, point])


func _check_riders() -> void:
	for gender: String in ["male", "female"]:
		var body_id: String = Appearance.DEFAULT_MALE_BODY_ID if gender == "male" else Appearance.DEFAULT_FEMALE_BODY_ID
		var base := Appearance.get_body_frames(body_id, gender, Appearance.BODY_MOVEMENT_RIDE)
		var mounted := Mounts.get_mounted_rider_frames(base, "shadow_lugia", {}, {}, true)
		_check(mounted != null and mounted != base, "rider receives the mask")
		if mounted == null or base == null:
			return
		for direction: String in DIRECTIONS:
			var animation := StringName("walk_" + direction)
			var original := Mounts._get_texture_image(base.get_frame_texture(animation, 0))
			for index in range(4):
				var image := mounted.get_frame_texture(animation, index).get_image()
				_check(image.get_size() == Vector2i(64, 64), "player keeps original size")
				if direction == "up":
					_check(_visible_pixels_equal(image, original), "rear view preserves rider pixels")
				else:
					_check(_opaque_count(image) < _opaque_count(original), "%s %s masks overlapping head or far leg" % [gender, direction])


func _check_players() -> void:
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	root.add_child(local)
	local.set("base_look_position", local.get_node("Look").position)
	local.set("active_mount_id", "shadow_lugia")
	local.set("activity_style", "ride")
	local.call("_cache_appearance_sprites")
	local.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID)
	local.call("_connect_mount_frame_sync")
	local.call("_sync_mount_visual")
	local.call("_sync_mount_animation", true, Vector2.DOWN)
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.call("apply_state", {
		"userId": 1, "displayName": "Shadow Lugia rider", "gender": "female",
		"position": {"x": 32, "y": 32}, "facingDirection": "down",
		"movement": {"isMoving": true, "activityStyle": "ride", "mountId": "shadow_lugia",
			"startPosition": {"x": 32, "y": 0}, "targetPosition": {"x": 32, "y": 32}, "duration": 0.065},
	})
	var local_mount := local.get_node("Look/MountSprite") as AnimatedSprite2D
	var local_body := local.get_node("Look/Rider/BodySprite") as AnimatedSprite2D
	var remote_mount: AnimatedSprite2D = remote.get("mount_sprite")
	var remote_body: AnimatedSprite2D = remote.call("_get_body_sprite")
	for pair: Array in [[local_mount, local_body], [remote_mount, remote_body]]:
		var mount := pair[0] as AnimatedSprite2D
		var body := pair[1] as AnimatedSprite2D
		_check(mount.visible and mount.sprite_frames != null and body.sprite_frames != null, "runtime rider and mount load")
		mount.frame = 1
		_check(body.frame == 1 and not body.is_playing(), "runtime rider uses the seated pose with the current mask")
		_check(mount.sprite_frames.get_frame_texture(mount.animation, 1).get_size() == Vector2(128, 128), "runtime mount size is correct")
		_check(body.sprite_frames.get_frame_texture(body.animation, 1).get_size() == Vector2(64, 64), "runtime rider size is correct")
	var position_before := local.position
	local.call("_sync_mount_animation", false, Vector2.DOWN)
	remote.call("_sync_mount_animation", false, Vector2.DOWN)
	var look := local.get_node("Look") as Node2D
	var before := look.position
	local.call("_update_mount_hover", 0.6)
	remote.call("_update_mount_hover", 0.6)
	_check(look.position.y != before.y, "mount hovers while idle")
	_check(local.position == position_before, "hover preserves tile and collision position")
	_check((local.get_node("MountHoverShadow") as Node2D).visible, "ground shadow is visible")
	_check(local.call("_get_mount_hover_offset") == remote.call("_get_mount_hover_offset"), "local and remote hover together")
	local.queue_free()
	remote.queue_free()
	await process_frame


func _visible_pixels_equal(first: Image, second: Image) -> bool:
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			# Transparent source RGB is discarded by the rider transform.
			if a.a != b.a or (a.a > 0.0 and a != b):
				return false
	return true


func _opaque_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
