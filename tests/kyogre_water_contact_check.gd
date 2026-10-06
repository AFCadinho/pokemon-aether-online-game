extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var local := load("res://scenes/player.tscn").instantiate() as Node2D
	local.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	root.add_child(local)
	var remote := load("res://scripts/world/remote_player_avatar.gd").new() as Node2D
	root.add_child(remote)
	remote.set_process(false)
	for gender: String in ["male", "female"]:
		var save := root.get_node("PlayerSave")
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
		for id: String in ["primal_kyogre", "lapras", "primal_kyogre_shiny", "magikarp", "magikarp_shiny", "lapras", "primal_kyogre"]:
			var wet := id.begins_with("primal_kyogre") or id.begins_with("magikarp")
			local.set("active_mount_id", id)
			local.set("activity_style", "surf")
			local.call("refresh_appearance")
			local.call("_sync_mount_visual")
			remote.call("apply_state", {"userId": 1, "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "surf", "mountId": id}})
			for actor: Node2D in [local, remote]:
				var water: AnimatedSprite2D = actor.get("mount_water_contact")
				_check(water != null and water.visible == wet, id + " enables water contact only for configured mounts")
				_check(water not in actor.get("appearance_sprites"), "water never enters the player clothing/mask pipeline")
				if not wet:
					_check(water.sprite_frames == null, "switching away clears water frames")
					continue
				_check(water.get_parent() == actor.get_node("Look/MountForegroundSprite") and water.z_index == 0, "water shares actor world depth behind nearby map objects")
				for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
					for moving: bool in [false, true]:
						actor.call("_sync_mount_animation", moving, direction)
						var mount := actor.get_node("Look/MountSprite") as AnimatedSprite2D
						mount.pause()
						for phase in range(4 if moving else 1):
							mount.frame = phase
							actor.call("_on_mount_frame_changed")
							_check(water.animation == mount.animation and water.frame == phase and not water.is_playing(), "water follows direction/frame and cannot drift while paused")
			if wet:
				var normal := Mounts._get_mask_image(id)
				_check(normal.get_data() == Mounts._get_mask_image(id.trim_suffix("_shiny")).get_data(), "normal/shiny keep the same opaque rider mask")
				var frames := Mounts.get_mount_frames(id)
				var front := Mounts.get_mount_foreground_frames(id)
				var back_image := Mounts._get_texture_image(frames.get_frame_texture("walk_left", 0))
				var front_image := Mounts._get_texture_image(front.get_frame_texture("walk_left", 0))
				var translucent := 0
				var overlap := false
				for y in range(front_image.get_height()):
					for x in range(front_image.get_width()):
						var a := front_image.get_pixel(x, y).a
						if a > 0.0 and a < 1.0:
							translucent += 1
						if a > 0.0 and back_image.get_pixel(x, y).a > 0.0:
							overlap = true
				_check(translucent > (100 if id.begins_with("primal_kyogre") else 10) and not overlap, "submerged near fin stays translucent without duplicate drawing")
				var water_frames: SpriteFrames = local.get("mount_water_contact").sprite_frames
				var idle_water := Mounts._get_texture_image(water_frames.get_frame_texture("idle_left", 0))
				var moving_water := Mounts._get_texture_image(water_frames.get_frame_texture("walk_left", 0))
				_check(not idle_water.is_invisible() and idle_water.get_data() != moving_water.get_data(), "stationary contact foam differs from the swimming wake")
				local.set("activity_style", "surf-fish")
				local.call("refresh_appearance")
				local.call("_sync_mount_visual")
				local.call("_sync_mount_animation", false, Vector2.LEFT)
				_check(str(local.get("mount_water_contact").animation) == "idle_left", "fishing retains contact foam without a moving wake")
	# Kyogre's local contact replaces global step rings; fishing still splashes.
	for id: String in ["magikarp", "magikarp_shiny"]:
		local.set("active_mount_id", id)
		var before := root.get_child_count()
		local.call("_spawn_water_ripple_effect", Vector2.ZERO, "surf_step", false)
		_check(root.get_child_count() == before, id + " avoids a detached step ring")
	local.set("active_mount_id", "primal_kyogre")
	var count := root.get_child_count()
	local.call("_spawn_water_ripple_effect", Vector2.ZERO, "surf_step", false)
	_check(root.get_child_count() == count, "Kyogre avoids a detached step ring")
	local.call("_spawn_water_ripple_effect", Vector2.ZERO, "fish_cast", false)
	_check(root.get_child_count() == count + 1, "fishing ripple remains available")
	local.set("active_mount_id", "lapras")
	local.call("_spawn_water_ripple_effect", Vector2.ZERO, "surf_step", false)
	_check(root.get_child_count() == count + 2, "Lapras keeps its existing ripples")
	local.set("active_mount_id", "")
	local.call("_sync_mount_visual")
	_check(not local.get("mount_water_contact").visible, "dismount removes the water effect")
	local.free()
	remote.free()
	await process_frame
	print("Kyogre water-contact checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
