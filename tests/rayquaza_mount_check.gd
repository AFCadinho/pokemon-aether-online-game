extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const DIRECTIONS := ["down", "left", "right", "up"]

var mount_id := "rayquaza"
var unlock_item_id := "rayquaza-mount"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_large_mask_coordinates()
	for variant: Array in [["rayquaza", "rayquaza-mount"], ["rayquaza_shiny", "shiny-rayquaza-mount"]]:
		mount_id = str(variant[0])
		unlock_item_id = str(variant[1])
		_check_entitlement_and_frames()
		_check_actual_riders()
		await _check_local_and_remote_players()
	_check_variant_rigs()
	print("Rayquaza mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_entitlement_and_frames() -> void:
	_check(Mounts.get_mount_id_for_unlock_item(unlock_item_id) == mount_id, "item resolves to Rayquaza")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", [unlock_item_id]) == [mount_id], "ownership unlocks only Rayquaza")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", []).is_empty(), "Rayquaza requires its item")
	_check(Mounts.resolve_mount_id_for_mode(mount_id, "surf") == "", "Rayquaza uses land movement rules")
	_check(Icons.load_icon(unlock_item_id) != null, "Bag uses the Rayquaza sprite as item icon")
	var frames := Mounts.get_mount_frames(mount_id)
	var foreground := Mounts.get_mount_foreground_frames(mount_id)
	_check(frames != null and foreground != null, "large mount and foreground load")
	if frames == null or foreground == null:
		return
	for direction: String in DIRECTIONS:
		var walk := StringName("walk_" + direction)
		var idle := StringName("idle_" + direction)
		_check(frames.get_frame_count(walk) == 4 and frames.get_frame_count(idle) == 1, "%s has movement and idle frames" % direction)
		_check(frames.get_animation_speed(walk) == 4.0, "Rayquaza's movement has a gentle flight rhythm")
		_check(foreground.get_animation_speed(walk) == 4.0, "foreground uses the same flight rhythm")
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
		var mounted := Mounts.get_mounted_rider_frames(base, mount_id, {}, {}, true)
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
	local.set("base_look_position", local.get_node("Look").position)
	local.set("active_mount_id", mount_id)
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
	_check(local.get_node("Look/Rider").position == Vector2(Mounts.get_rider_frame_offset(mount_id, "left", 1)), "local rider follows the larger mount bob")
	var avatar: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(avatar)
	avatar.call("apply_state", {
		"userId": 1, "displayName": Mounts.get_mount_display_name(mount_id) + " rider", "gender": "female",
		"position": {"x": 32, "y": 32}, "facingDirection": "right",
		"movement": {"isMoving": true, "activityStyle": "ride", "mountId": mount_id,
			"startPosition": {"x": 0, "y": 32}, "targetPosition": {"x": 32, "y": 32}, "duration": 0.065},
	})
	var remote_mount: AnimatedSprite2D = avatar.get("mount_sprite")
	var remote_body: AnimatedSprite2D = avatar.call("_get_body_sprite")
	_check_runtime_frame_sizes(remote_mount, remote_body, "remote")
	remote_mount.frame = 1
	_check(remote_body.frame == 1 and not remote_body.is_playing(), "remote rider uses one seated pose with the current mask frame")
	var expected := Vector2(Mounts.get_rider_frame_offset(mount_id, "right", 1))
	_check((avatar.get("rider_node") as Node2D).position == expected, "remote rider follows the larger mount bob")
	_check_hover_visuals(local, avatar)
	local.queue_free()
	avatar.queue_free()
	await process_frame


func _check_hover_visuals(local: Node2D, remote: Node2D) -> void:
	var tile_position := local.position
	local.call("_sync_mount_animation", false, Vector2.LEFT)
	remote.call("_sync_mount_animation", false, Vector2.RIGHT)
	var look := local.get_node("Look") as Node2D
	var shadow := local.get_node("MountHoverShadow") as Node2D
	var initial_look := look.position
	var initial_shadow := shadow.position
	var initial_rider := (local.get_node("Look/Rider") as Node2D).global_position
	local.call("_update_mount_hover", 0.6)
	remote.call("_update_mount_hover", 0.6)
	_check(look.position.y != initial_look.y, "Rayquaza continues hovering while idle")
	_check((local.get_node("Look/Rider") as Node2D).global_position - initial_rider == look.position - initial_look, "rider and mount hover together")
	_check(shadow.visible and shadow.position == initial_shadow, "hover shadow stays on the ground")
	_check(local.position == tile_position, "hover does not move the collision or tile position")
	_check(local.call("_get_mount_hover_offset") == remote.call("_get_mount_hover_offset"), "local and remote use the same hover motion")
	var before_resync: Vector2 = remote.call("_get_mount_hover_offset")
	remote.call("_sync_mount_visual")
	_check(remote.call("_get_mount_hover_offset") == before_resync, "presence resync preserves hover phase")
	local.set("stair_visual_offset", Vector2(0, -6))
	local.call("_update_mount_hover", 0.0)
	_check(shadow.position == Vector2(0, -6), "shadow follows ground elevation on stairs")
	local.set("active_mount_id", "cyclizar")
	local.call("_sync_mount_visual")
	_check(local.call("_get_mount_hover_offset") == Vector2.ZERO and not shadow.visible, "switching to Cyclizar removes hover and shadow")
	_check(look.position == local.get("base_look_position") + local.call("_get_activity_visual_offset") + Vector2(0, -6), "ground mount restores its normal rendered position")
	remote.set("current_mount_id", "")
	remote.call("_sync_mount_visual")
	_check(remote.call("_get_mount_hover_offset") == Vector2.ZERO and not (remote.get_node("MountHoverShadow") as Node2D).visible, "dismount removes remote hover and shadow")
	_check(Mounts.get_mount_frames("cyclizar").get_animation_speed(&"walk_left") == Mounts.WALK_ANIMATION_SPEED, "Cyclizar keeps its existing movement rhythm")
	_check(Mounts.get_mount_frames("lapras").get_animation_speed(&"walk_left") == Mounts.WALK_ANIMATION_SPEED, "Lapras keeps its existing movement rhythm")
	var hover_script := load("res://scripts/world/mount_hover_visual.gd")
	var reference: Vector2
	for fps in [30, 60, 144]:
		var visual: Node2D = hover_script.new()
		visual.call("configure", Mounts.get_mount_definition(mount_id))
		for frame in range(fps * 3):
			visual.call("advance", 1.0 / fps)
		var result: Vector2 = visual.get("visual_offset")
		if fps == 30:
			reference = result
		_check(result == reference, "hover timing is independent of FPS")
		visual.free()


func _check_variant_rigs() -> void:
	var normal_definition := Mounts.get_mount_definition("rayquaza")
	var shiny_definition := Mounts.get_mount_definition("rayquaza_shiny")
	for key: String in normal_definition:
		if key not in ["displayName", "unlockItemId", "spriteSheet", "riderMaskSheet"]:
			_check(normal_definition[key] == shiny_definition.get(key), "normal and shiny share %s" % key)
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["rayquaza-mount"]) == ["rayquaza"], "normal item does not unlock shiny")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["shiny-rayquaza-mount"]) == ["rayquaza_shiny"], "shiny item does not unlock normal")
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", ["rayquaza-mount", "shiny-rayquaza-mount"]) == ["rayquaza", "rayquaza_shiny"], "both variants can be owned together")
	var normal := Mounts.get_mount_frames("rayquaza")
	var shiny := Mounts.get_mount_frames("rayquaza_shiny")
	_check(normal != null and shiny != null and normal != shiny, "variant textures use separate cached resources")
	if normal == null or shiny == null:
		return
	_check(Mounts._get_mask_image("rayquaza").get_data() == Mounts._get_mask_image("rayquaza_shiny").get_data(), "shiny uses the exact normal rider mask")
	for direction: String in DIRECTIONS:
		var animation := StringName("walk_" + direction)
		for index in range(4):
			var old := Mounts._get_texture_image(normal.get_frame_texture(animation, index))
			var new := Mounts._get_texture_image(shiny.get_frame_texture(animation, index))
			old.convert(Image.FORMAT_RGBA8)
			new.convert(Image.FORMAT_RGBA8)
			var old_bytes := old.get_data()
			var new_bytes := new.get_data()
			var same_alpha := old_bytes.size() == new_bytes.size()
			if same_alpha:
				for byte in range(3, old_bytes.size(), 4):
					if old_bytes[byte] != new_bytes[byte]:
						same_alpha = false
						break
			_check(same_alpha, "%s/%d shiny silhouette and placement match normal" % [direction, index])
			_check(old_bytes != new_bytes, "%s/%d uses the distinct shiny palette" % [direction, index])


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
