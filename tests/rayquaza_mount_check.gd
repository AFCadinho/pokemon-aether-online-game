extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const DIRECTIONS := ["down", "left", "right", "up"]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_entitlement_and_frames()
	_check_large_mask_coordinates()
	_check_actual_riders()
	await _check_local_and_remote_players()
	print("Rayquaza mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_entitlement_and_frames() -> void:
	_check(Mounts.get_mount_id_for_unlock_item("rayquaza-mount") == "rayquaza", "item resolves to Rayquaza")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["rayquaza-mount"]) == ["rayquaza"], "ownership unlocks only Rayquaza")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", []).is_empty(), "Rayquaza requires its item")
	_check(Mounts.resolve_mount_id_for_mode("rayquaza", "surf") == "", "Rayquaza uses land movement rules")
	_check(Icons.load_icon("rayquaza-mount") != null, "Bag uses the Rayquaza sprite as item icon")
	var frames := Mounts.get_mount_frames("rayquaza")
	var foreground := Mounts.get_mount_foreground_frames("rayquaza")
	_check(frames != null and foreground != null, "large mount and foreground load")
	if frames == null or foreground == null:
		return
	for direction: String in DIRECTIONS:
		var walk := StringName("walk_" + direction)
		var idle := StringName("idle_" + direction)
		_check(frames.get_frame_count(walk) == 4 and frames.get_frame_count(idle) == 1, "%s has movement and idle frames" % direction)
		for index in range(4):
			_check(Vector2i(frames.get_frame_texture(walk, index).get_size()) == Vector2i(128, 128), "Rayquaza frame remains 128px")
			_check(Vector2i(foreground.get_frame_texture(walk, index).get_size()) == Vector2i(128, 128), "foreground keeps mount dimensions")


func _check_large_mask_coordinates() -> void:
	# Sparse sentinel pixels exercise every atlas row/column, the center correction,
	# mask bounds and preserved alpha without relying on this mount's artwork.
	for row in range(4):
		for column in range(4):
			var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
			source.fill(Color.TRANSPARENT)
			source.set_pixel(20, 30, Color.RED)
			source.set_pixel(21, 30, Color(0, 1, 0, 0.5))
			source.set_pixel(0, 0, Color.WHITE)
			source.set_pixel(63, 63, Color.WHITE)
			var mask := Image.create(512, 512, false, Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)
			mask.set_pixel(column * 128 + 60, row * 128 + 70, Color.WHITE)
			var result := Mounts._transform_rider_frame(source, mask, row, column, Vector2i(8, 8), Vector2i(128, 128))
			_check(result.get_size() == Vector2i(64, 64), "large mount does not enlarge rider")
			_check(result.get_pixel(20, 30).a == 0.0, "large mask removes its centered rider pixel")
			_check(result.get_pixel(21, 30) == source.get_pixel(21, 30), "unmasked partial alpha is preserved")
			_check(result.get_pixel(0, 0) == Color.WHITE and result.get_pixel(63, 63) == Color.WHITE, "rider frame edges remain intact")
	# A rider pixel outside the mask's extent must still survive in its own texture.
	var edge := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	edge.fill(Color.TRANSPARENT)
	edge.set_pixel(0, 0, Color.WHITE)
	var empty := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	empty.fill(Color.TRANSPARENT)
	var shifted := Mounts._transform_rider_frame(edge, empty, 0, 0, Vector2i(-40, -40), Vector2i(128, 128))
	_check(shifted.get_pixel(0, 0) == Color.WHITE, "out-of-mask headgear is not clipped")


func _check_actual_riders() -> void:
	for gender: String in ["male", "female"]:
		var body_id: String = Appearance.DEFAULT_MALE_BODY_ID if gender == "male" else Appearance.DEFAULT_FEMALE_BODY_ID
		var base := Appearance.get_body_frames(body_id, gender, Appearance.BODY_MOVEMENT_RIDE)
		var mounted := Mounts.get_mounted_rider_frames(base, "rayquaza", {}, {}, true)
		_check(mounted != null and mounted != base, "%s body receives the large mount mask" % gender)
		if mounted == null or base == null:
			continue
		for direction: String in DIRECTIONS:
			var animation := StringName("walk_" + direction)
			var original := base.get_frame_texture(animation, 0).get_image()
			for index in range(4):
				var image := mounted.get_frame_texture(animation, index).get_image()
				_check(image.get_size() == Vector2i(64, 64), "real rider stays at original scale")
				if direction in ["left", "right"]:
					_check(_opaque_count(image) < _opaque_count(original), "Rayquaza hides the far leg in %s frame %d" % [direction, index])
				else:
					_check(_opaque_count(image) == _opaque_count(original), "unmasked direction keeps body pixels")


func _check_local_and_remote_players() -> void:
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	root.add_child(local)
	local.set("active_mount_id", "rayquaza")
	local.set("activity_style", "ride")
	local.call("_cache_appearance_sprites")
	local.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID)
	local.call("_connect_mount_frame_sync")
	local.call("_sync_mount_visual")
	_check_runtime_frame_sizes(local.get_node("Look/MountSprite"), local.get_node("Look/Rider/BodySprite"), "local")
	var mount := local.get_node("Look/MountSprite") as AnimatedSprite2D
	local.set("last_direction", Vector2.LEFT)
	local.call("_sync_mount_animation", true, Vector2.LEFT)
	mount.frame = 1
	_check(local.get_node("Look/Rider").position == Vector2(Mounts.get_rider_frame_offset("rayquaza", "left", 1)), "local rider follows the larger mount bob")
	var avatar: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(avatar)
	avatar.call("apply_state", {
		"userId": 1, "displayName": "Rayquaza rider", "gender": "female",
		"position": {"x": 32, "y": 32}, "facingDirection": "right",
		"movement": {"isMoving": true, "activityStyle": "ride", "mountId": "rayquaza",
			"startPosition": {"x": 0, "y": 32}, "targetPosition": {"x": 32, "y": 32}, "duration": 0.065},
	})
	var remote_mount: AnimatedSprite2D = avatar.get("mount_sprite")
	var remote_body: AnimatedSprite2D = avatar.call("_get_body_sprite")
	_check_runtime_frame_sizes(remote_mount, remote_body, "remote")
	remote_mount.frame = 1
	_check(remote_body.frame == 1 and not remote_body.is_playing(), "remote rider uses one seated pose with the current mask frame")
	var expected := Vector2(Mounts.get_rider_frame_offset("rayquaza", "right", 1))
	_check((avatar.get("rider_node") as Node2D).position == expected, "remote rider follows the larger mount bob")
	local.queue_free()
	avatar.queue_free()
	await process_frame


func _check_runtime_frame_sizes(mount: AnimatedSprite2D, body: AnimatedSprite2D, label: String) -> void:
	_check(mount.visible and mount.sprite_frames != null, "%s mount is visible" % label)
	_check(body.sprite_frames != null, "%s player body is loaded" % label)
	if mount.sprite_frames == null or body.sprite_frames == null:
		return
	_check(Vector2i(mount.sprite_frames.get_frame_texture(mount.animation, mount.frame).get_size()) == Vector2i(128, 128), "%s mount uses larger frames" % label)
	_check(Vector2i(body.sprite_frames.get_frame_texture(body.animation, body.frame).get_size()) == Vector2i(64, 64), "%s player remains original size" % label)


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
