extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var save := root.get_node("PlayerSave")
	var auth := root.get_node("AuthService")
	var inventory := root.get_node("InventoryService")
	var previous_user: Dictionary = auth.current_user
	var previous_inventory: Array = inventory.cached_inventory_items
	var previous_inventory_user: int = inventory.cached_inventory_user_id
	auth.current_user = {"id": 123}
	inventory.cached_inventory_user_id = 123
	inventory.cached_inventory_items = []
	var mounts := Mounts.get_mount_ids_for_mode("land")
	for id: String in mounts:
		inventory.cached_inventory_items.append({"itemId": Mounts.get_mount_unlock_item_id(id), "quantity": 1})
	var local := _new_local()
	var reference := _new_local()
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.set_process(false)
	for gender: String in ["male", "female"]:
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
		save.appearance_skin_tone = Appearance.DEFAULT_SKIN_TONE
		save.appearance_hair_color = Appearance.get_default_hair_color(gender)
		save.appearance_eye_color = Appearance.get_default_eye_color(gender)
		for category: String in ["top", "bottom", "shoes", "facegear", "facial_hair"]:
			save.set("appearance_%s_color" % category, "#ffffff")
		for category: String in ["hair", "headgear", "top", "bottom", "shoes", "facegear", "facial_hair"]:
			save.set("appearance_%s_id" % category, Appearance.get_default_part_id(category, gender))
		local.call("refresh_appearance")
		for target: String in mounts:
			# The fresh target is independent of the origin. Build it once, while
			# still checking every origin -> target transition and every pixel.
			reference.set("active_mount_id", target)
			reference.call("refresh_appearance")
			reference.call("_sync_mount_visual")
			var reference_samples := _capture_reference(reference)
			for origin: String in mounts:
				# Mount changes do not change the character's appearance. Use the
				# same live callback for setup instead of rebuilding that appearance.
				local.call("_on_mount_loadout_changed", "land", origin)
				_check(local.get("active_mount_id") == origin and local.get("land_mount_activity_active"), "origin mount is active before switching")
				remote.call("apply_state", _presence(gender, origin))
				# Exercise the live loadout callback without changing the riding pose.
				local.call("_on_mount_loadout_changed", "land", target)
				remote.call("apply_state", _presence(gender, target))
				for actor: Node2D in [local, remote]:
					_check(_matches_fresh_mount(actor, reference_samples), "%s %s switch %s -> %s keeps every rider layer" % [gender, "local" if actor == local else "remote", origin, target])
				var frames: SpriteFrames = local.get_node("Look/Rider/BodySprite").sprite_frames
				local.call("_sync_body_sprite_frames_for_movement")
				_check(local.get_node("Look/Rider/BodySprite").sprite_frames == frames, "unchanged mount reuses rider resources")
	inventory.cached_inventory_items = previous_inventory
	inventory.cached_inventory_user_id = previous_inventory_user
	auth.current_user = previous_user
	local.queue_free()
	reference.queue_free()
	remote.queue_free()
	await process_frame
	print("Mount switch rider checks: ", "FAILED" if failed else "PASS", " mounts=", mounts.size(), " transitions=", 2 * mounts.size() * mounts.size(), " actors=local+remote samples_per_actor=20")
	quit(1 if failed else 0)


func _new_local() -> Node2D:
	var actor: Node2D = load("res://scenes/player.tscn").instantiate()
	actor.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	root.add_child(actor)
	actor.set("activity_style", "ride")
	actor.set("land_mount_activity_active", true)
	return actor


func _presence(gender: String, id: String) -> Dictionary:
	return {"userId": 1, "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": id}}


func _capture_reference(reference: Node2D) -> Array:
	# Snapshot every reference pose once per gender/target. Replaying reference
	# animations for every origin also repeatedly rebuilds its rider frames.
	var samples := []
	var pixels := {}
	for direction: Vector2 in DIRECTIONS:
		for moving: bool in [false, true]:
			reference.set("last_direction", direction)
			reference.call("_sync_mount_animation", moving, direction)
			for frame in range(4 if moving else 1):
				reference.get_node("Look/MountSprite").frame = frame
				var layers := []
				for expected: AnimatedSprite2D in reference.get_node("Look/Rider").get_children():
					var layer := {"name": str(expected.name), "visible": expected.visible}
					if expected.visible:
						var texture := expected.sprite_frames.get_frame_texture(expected.animation, expected.frame)
						if not pixels.has(texture):
							var image := Mounts._get_texture_image(texture)
							pixels[texture] = [image.get_size(), image.get_data()]
						layer["pixels"] = pixels[texture]
					layers.append(layer)
				samples.append(layers)
	assert(samples.size() == 20)
	return samples


func _matches_fresh_mount(actor: Node2D, reference_samples: Array) -> bool:
	# Animation selects immutable frame textures. Read each selected texture once
	# per transition, but compare every visible animation sample with the baseline.
	var live_pixels := {}
	var sample_index := 0
	for direction: Vector2 in DIRECTIONS:
		for moving: bool in [false, true]:
			actor.set("last_direction", direction)
			actor.call("_sync_mount_animation", moving, direction)
			for frame in range(4 if moving else 1):
				actor.get_node("Look/MountSprite").frame = frame
				for expected: Dictionary in reference_samples[sample_index]:
					var actual := actor.get_node("Look/Rider").get_node(NodePath(expected.name)) as AnimatedSprite2D
					if actual.visible != expected.visible:
						return false
					if not expected.visible:
						continue
					var actual_texture := actual.sprite_frames.get_frame_texture(actual.animation, actual.frame)
					if not live_pixels.has(actual_texture):
						var image := Mounts._get_texture_image(actual_texture)
						live_pixels[actual_texture] = [image.get_size(), image.get_data()]
					var actual_pixels: Array = live_pixels[actual_texture]
					var expected_pixels: Array = expected.pixels
					if actual_pixels[0] != expected_pixels[0] or actual_pixels[1] != expected_pixels[1]:
						return false
				sample_index += 1
	assert(sample_index == reference_samples.size())
	return true


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
