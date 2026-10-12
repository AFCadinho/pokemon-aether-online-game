extends "res://tests/primal_kyogre_surf_check.gd"


func _run() -> void:
	var id := "flying_nimbus"
	var item := "flying-nimbus-mount"
	_check(Mounts.get_unlocked_mount_ids_for_mode("land", [item]) == [id], "Nimbus grant unlocks the land picker")
	_check(not Mounts.is_mount_unlocked(id, []) and Mounts.is_mount_unlocked(id, [item + "-bound"]), "ownership and bound entitlement")
	_check(Mounts.resolve_mount_id_for_mode(id, "surf").is_empty(), "Nimbus retains land movement restrictions")
	_check(load("res://scripts/services/item_icon_resolver.gd").load_icon(item) != null, "inventory icon loads")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		_check(root.get_node("ItemLocalization").get_catalog(locale).has(item), "localized grant " + locale)
	var frames := Mounts.get_mount_frames(id)
	var foreground := Mounts.get_mount_foreground_frames(id)
	_check(frames != null and foreground != null and Mounts._get_mask_image(id) != null, "all mount layers load")
	var actor := _new_local()
	actor.set("surf_activity_active", false)
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.set_process(false)
	var feet: Vector2 = actor.call("get_feet_position")
	var interaction: Vector2 = actor.call("get_interaction_position")
	var collision: Vector2 = actor.get_node("DetectionShape").position
	for gender: String in ["male", "female"]:
		var save := root.get_node("PlayerSave")
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
		for selected: String in [id, "zekrom", id, ""]:
			actor.set("active_mount_id", selected)
			actor.call("refresh_appearance")
			actor.call("_sync_mount_visual")
			remote.call("apply_state", {"userId": 1, "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": selected}})
			for avatar: Node2D in [actor, remote]:
				var trail: Node2D = avatar.get("mount_nimbus_trail")
				_check(trail != null and trail.enabled == (selected == id), "switching toggles Nimbus-only effect")
				if selected != id:
					_check(not trail.visible and not trail.is_processing(), "switch and dismount fully stop trail")
					continue
				_check(trail.get_parent() == avatar.get_node("Look/MountSprite") and trail.show_behind_parent and trail.z_index == 0, "cloud occludes trail at actor world depth")
				for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
					avatar.set("last_direction", direction)
					for moving: bool in [true, false]:
						avatar.call("_sync_mount_animation", moving, direction)
						_check(trail.active == moving and trail.visible == moving, "trail only while moving")
						_check(trail.axis == -direction, "trail points opposite movement")
						var mount: AnimatedSprite2D = avatar.get_node("Look/MountSprite")
						mount.pause()
						var count := 4 if moving else 1
						_check(mount.sprite_frames.get_frame_count(mount.animation) == count, "native mount animation layout")
						var seat: Vector2 = avatar.get_node("Look/Rider").position
						for phase in range(count):
							mount.frame = phase
							avatar.call("_on_mount_frame_changed")
							_check(avatar.get_node("Look/Rider").position == seat, "stable seated pose in all movement phases")
							avatar.call("_update_mount_hover", 0.3)
							_check(avatar.get("mount_hover_visual").visual_offset.y >= -7 and avatar.get("mount_hover_visual").visual_offset.y <= -5, "one-pixel shared hover")
				_check(actor.call("get_feet_position") == feet and actor.call("get_interaction_position") == interaction and actor.get_node("DetectionShape").position == collision, "hover preserves gameplay anchors")
	actor.free()
	remote.free()
	await process_frame
	print("Flying Nimbus checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)
