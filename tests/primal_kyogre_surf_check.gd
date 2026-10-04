extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory := root.get_node("InventoryService")
	var auth := root.get_node("AuthService")
	auth.current_user = {"id": 123}
	inventory.cached_inventory_user_id = 123
	inventory.cached_inventory_items = []
	var actor := _new_local()
	_check_side_waterline(actor)
	_check(actor.call("_resolve_owned_surf_mount", "primal_kyogre") == "lapras", "unowned saved Surf selection falls back to Lapras")
	inventory.cached_inventory_items = [{"itemId": "primal-kyogre-mount", "quantity": 1}]
	_check(actor.call("_resolve_owned_surf_mount", "primal_kyogre") == "primal_kyogre", "grant unlocks the selected Surf mount")
	_check(Mounts.get_mount_movement_mode("primal_kyogre") == "surf", "Kyogre belongs to Surf")
	_check(Mounts.resolve_mount_id_for_mode("primal_kyogre", "land").is_empty(), "Kyogre cannot be used as a land mount")
	var save := root.get_node("PlayerSave")
	var remote := load("res://scripts/world/remote_player_avatar.gd").new() as Node2D
	root.add_child(remote)
	remote.set_process(false)
	for gender: String in ["male", "female"]:
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
		for id: String in ["lapras", "primal_kyogre", "lapras", "primal_kyogre"]:
			actor.call("_on_mount_loadout_changed", "surf", id)
			var fresh := _new_local()
			fresh.set("active_mount_id", id)
			fresh.call("refresh_appearance")
			fresh.call("_sync_mount_visual")
			remote.call("apply_state", {"userId": 1, "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "surf", "mountId": id}})
			for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
				for avatar: Node2D in [actor, fresh, remote]:
					avatar.set("last_direction", direction)
					avatar.call("_sync_mount_animation", true, direction)
					avatar.get_node("Look/MountSprite").pause()
				for phase in range(4):
					for avatar: Node2D in [actor, fresh, remote]:
						avatar.get_node("Look/MountSprite").frame = phase
						avatar.call("_on_mount_frame_changed")
					_check(actor.get_node("Look/Rider").position == remote.get_node("Look/Rider").position, "local and remote seats match")
					for expected: AnimatedSprite2D in fresh.get_node("Look/Rider").get_children():
						var actual: AnimatedSprite2D = actor.get_node("Look/Rider").get_node(NodePath(str(expected.name)))
						_check(actual.visible == expected.visible, "mount switch preserves rider layer visibility")
						if actual.visible and expected.visible:
							var a := Mounts._get_texture_image(actual.sprite_frames.get_frame_texture(actual.animation, actual.frame))
							var b := Mounts._get_texture_image(expected.sprite_frames.get_frame_texture(expected.animation, expected.frame))
							_check(a.get_data() == b.get_data(), "mount switch matches freshly composed rider pixels")
			fresh.free()
	actor.set("activity_style", "surf-fish")
	actor.call("refresh_appearance")
	actor.call("_sync_mount_visual")
	remote.call("apply_state", {"userId": 1, "gender": "female", "appearance": Appearance.get_default_appearance("female"), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "surf-fish", "mountId": "primal_kyogre"}})
	for direction: String in ["down", "left", "right", "up"]:
		_check(actor.call("_get_surf_fish_rider_offset", direction) == remote.call("_get_surf_fish_rider_offset", direction), "fishing seat matches remotely")
	_check(actor.call("_get_surf_fish_rider_offset", "left") == Vector2(0,4), "Kyogre fishing stays on its own seat")
	for avatar: Node2D in [actor, remote]:
		_check(avatar.get_node("Look/MountForegroundSprite").sprite_frames == Mounts.get_mount_foreground_frames("primal_kyogre"), "fishing keeps Kyogre's tail behind the rider")
	for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		for avatar: Node2D in [actor, remote]:
			avatar.set("last_direction", direction)
			avatar.call("_sync_mount_animation", false, direction)
		actor.call("set_idle_frame")
		remote.call("_update_animation", false)
		var local_body: AnimatedSprite2D = actor.get_node("Look/Rider/BodySprite")
		var remote_body: AnimatedSprite2D = remote.get_node("Look/Rider/BodySprite")
		var local_image := Mounts._get_texture_image(local_body.sprite_frames.get_frame_texture(local_body.animation, 0))
		var remote_image := Mounts._get_texture_image(remote_body.sprite_frames.get_frame_texture(remote_body.animation, 0))
		_check(local_image.get_data() == remote_image.get_data(), "entering fishing builds matching local and remote body masks")
	actor.free()
	remote.free()
	await process_frame
	print("Primal Kyogre Surf checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_side_waterline(actor: Node2D) -> void:
	var frames := Mounts.get_mount_frames("primal_kyogre")
	for direction: String in ["left", "right"]:
		var previous_height := INF
		for phase in range(4):
			var texture := frames.get_frame_texture(StringName("walk_" + direction), phase)
			var pixels := Mounts._get_texture_image(texture)
			# These nose-tip columns exclude the fins extending below the hull.
			var nose_x := 32 if direction == "left" else 160
			var bottom := -1
			for y in range(pixels.get_height()):
				if pixels.get_pixel(nose_x, y).a > 0.0:
					bottom = y
			_check(bottom >= 0, "side hull measurement contains artwork")
			var mount: AnimatedSprite2D = actor.get_node("Look/MountSprite")
			var waterline := mount.to_global(Vector2(nose_x, bottom) - Vector2(pixels.get_size()) / 2.0).y - actor.global_position.y
			_check(waterline >= -16.0 and waterline <= 16.0, "side hull reaches the occupied water tile")
			if previous_height != INF:
				_check(absf(waterline - previous_height) <= 1.0, "swimming keeps the hull at a stable waterline")
			previous_height = waterline


func _new_local() -> Node2D:
	var actor: Node2D = load("res://scenes/player.tscn").instantiate()
	actor.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	root.add_child(actor)
	actor.set("activity_style", "ride")
	actor.set("surf_activity_active", true)
	actor.set("active_mount_id", "lapras")
	actor.call("refresh_appearance")
	actor.call("_sync_mount_visual")
	return actor


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
