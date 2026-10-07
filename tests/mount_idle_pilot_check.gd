extends "res://tests/primal_kyogre_surf_check.gd"

const PILOT := ["arcanine", "arcanine_shiny", "lapras"]
const DIRS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]


func _run() -> void:
	var actor := _new_local()
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.set_process(false)
	var save := root.get_node("PlayerSave")
	for gender: String in ["male", "female"]:
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_MALE_BODY_ID if gender == "male" else Appearance.DEFAULT_FEMALE_BODY_ID
		for id: String in PILOT + ["gyarados", "rayquaza", "lapras"]:
			actor.set("active_mount_id", id)
			actor.set("activity_style", "ride")
			actor.call("refresh_appearance")
			actor.call("_sync_mount_visual")
			remote.call("apply_state", {"userId": 1, "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": id}})
			var feet: Vector2 = actor.call("get_feet_position")
			var look: Vector2 = actor.get_node("Look").position
			var collision: Vector2 = actor.get_node("DetectionShape").position
			var interaction: Vector2 = actor.call("get_interaction_position")
			for direction: Vector2 in DIRS:
				for avatar: Node2D in [actor, remote]:
					avatar.set("last_direction", direction)
					avatar.call("_sync_mount_animation", true, direction)
					avatar.call("_sync_mount_animation", false, direction)
					var mount: AnimatedSprite2D = avatar.get_node("Look/MountSprite")
					_check(mount.is_playing() == (id in PILOT), "only authored idle cycles play: " + id)
					_check(mount.frame == 0, "walk to idle begins at the approved standing pose")
					if id not in PILOT:
						continue
					mount.set_frame_and_progress(2, 0.4)
					for repeat in range(5):
						avatar.call("_sync_mount_animation", false, direction)
						if avatar == actor:
							avatar.call("set_idle_frame")
						else:
							avatar.call("_update_animation", false)
					_check(mount.frame == 2 and is_equal_approx(mount.frame_progress, 0.4), "repeated idle updates preserve the cycle")
					mount.pause()
					var plate: Vector2 = avatar.get_node("Nameplate").position
					for phase in range(4):
						mount.frame = phase
						avatar.call("_on_mount_frame_changed")
						var dir_name := str(mount.animation).trim_prefix("idle_")
						var offset := Mounts.get_rider_frame_offset(id, dir_name, phase, true)
						_check(avatar.get_node("Look/Rider").position == avatar.get("base_rider_position") + Vector2(offset), "rider follows the authored idle seat")
						_check(avatar.get_node("Nameplate").position == plate, "nameplate remains steady")
						var foreground: AnimatedSprite2D = avatar.get_node("Look/MountForegroundSprite")
						_check(foreground.animation == mount.animation and foreground.frame == phase, "foreground follows idle frame")
						for part: AnimatedSprite2D in avatar.get("appearance_sprites"):
							if part.visible and part.sprite_frames != null and part.sprite_frames.has_animation(mount.animation):
								_check(part.frame == phase and part.sprite_frames.get_frame_count(mount.animation) == 4 and not part.is_playing(), "every player layer follows the mount clock")
						_check(actor.call("get_feet_position") == feet and actor.get_node("Look").position == look and actor.get_node("DetectionShape").position == collision and actor.call("get_interaction_position") == interaction, "idle changes no gameplay anchor")
					# Real animation playback must emit frame changes, not merely load cels.
					var changes := [0]
					var callback := func(): changes[0] += 1
					mount.frame_changed.connect(callback)
					mount.speed_scale = 25.0
					avatar.call("_sync_mount_animation", false, direction)
					await create_timer(0.16).timeout
					_check(changes[0] > 0, "idle advances automatically")
					mount.speed_scale = 1.0
					mount.frame_changed.disconnect(callback)
					avatar.call("_sync_mount_animation", true, direction)
					_check(mount.is_playing() and str(mount.animation).begins_with("walk_") and mount.frame == 0, "walking resumes its own animation")
	# Fishing retains its independent rod/cast timing and approved seat.
	for avatar: Node2D in [actor, remote]:
		avatar.set("active_mount_id" if avatar == actor else "current_mount_id", "lapras")
		avatar.set("activity_style" if avatar == actor else "current_activity_style", "surf-fish")
		avatar.call("_sync_mount_visual")
		avatar.call("_sync_mount_animation", false, Vector2.DOWN)
		var mount: AnimatedSprite2D = avatar.get_node("Look/MountSprite")
		_check(not mount.is_playing() and mount.frame == 0, "fishing retains a steady mount and separate cast clock")
	actor.set("active_mount_id", "")
	actor.call("_sync_mount_visual")
	_check(not actor.get_node("Look/MountSprite").visible and actor.get_node("Look/Rider").position == actor.get("base_rider_position"), "dismount removes the idle offset")
	actor.free()
	remote.free()
	var preview: Node2D = load("res://scripts/ui/mount_rider_preview.gd").new()
	root.add_child(preview)
	preview.call("configure", "arcanine", Appearance.get_default_appearance("male"), "down", false)
	_check(not preview.get("mount_sprite").is_playing(), "Store Animation Off remains paused")
	preview.free()
	print("Mount idle pilot checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)
