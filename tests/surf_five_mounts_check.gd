extends "res://tests/primal_kyogre_surf_check.gd"

const SURF_FIVE := ["wailmer", "drednaw", "mantine", "basculegion", "wailord"]
const InteractionChecks := preload("res://tests/kyogre_interaction_height_check.gd")


func _run() -> void:
	var inventory := root.get_node("InventoryService")
	root.get_node("AuthService").current_user = {"id": 123}
	inventory.cached_inventory_user_id = 123
	inventory.cached_inventory_items = []
	var actor := _new_local()
	var feet: Vector2 = actor.call("get_feet_position")
	var look: Vector2 = actor.get_node("Look").position
	var collision: Vector2 = actor.get_node("DetectionShape").position
	for id: String in SURF_FIVE:
		_check(actor.call("_resolve_owned_surf_mount", id) == "lapras", "unowned " + id + " falls back to Lapras")
		inventory.cached_inventory_items.append({"itemId": id + "-mount", "quantity": 1})
		_check(actor.call("_resolve_owned_surf_mount", id) == id, "admin grant unlocks " + id)
		_check(Mounts.get_mount_movement_mode(id) == "surf", id + " belongs to Surf")
		_check(Mounts.resolve_mount_id_for_mode(id, "land").is_empty(), id + " cannot enter the land slot")
		_check_water_pixels(id)
	inventory.cached_inventory_items.append({"itemId": "primal-kyogre-mount", "quantity": 1})
	var remote := load("res://scripts/world/remote_player_avatar.gd").new() as Node2D
	root.add_child(remote)
	remote.set_process(false)
	var npc: Node2D = load("res://scenes/npcs/overworld_pokemon.tscn").instantiate()
	npc.set_script(InteractionChecks.ProbeNPC)
	root.add_child(npc)
	var sequence := ["primal_kyogre"] + SURF_FIVE + ["lapras", "wailmer"]
	for gender: String in ["male", "female"]:
		var save := root.get_node("PlayerSave")
		save.gender = gender
		save.appearance_body_id = Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID
		for id: String in sequence:
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
						var mount: AnimatedSprite2D = avatar.get_node("Look/MountSprite")
						mount.frame = phase
						avatar.call("_on_mount_frame_changed")
						var water: AnimatedSprite2D = avatar.get("mount_water_contact")
						_check((water != null and water.visible) == (id != "lapras"), "switch updates contact visibility")
						_check(water not in avatar.get("appearance_sprites"), "water stays outside clothing masking")
						if id in SURF_FIVE:
							_check(water.animation == mount.animation and water.frame == phase and not water.is_playing(), "contact and wake stay synchronized")
							_check(water.get_parent() == avatar.get_node("Look/MountForegroundSprite") and water.z_index == 0, "contact uses the actor's map depth")
					_check(actor.get_node("Look/Rider").position == remote.get_node("Look/Rider").position, "local and remote seats match")
					for expected: AnimatedSprite2D in fresh.get_node("Look/Rider").get_children():
						var actual: AnimatedSprite2D = actor.get_node("Look/Rider").get_node(NodePath(str(expected.name)))
						_check(actual.visible == expected.visible, "switch preserves rider layer visibility")
						if actual.visible and expected.visible:
							var a := Mounts._get_texture_image(actual.sprite_frames.get_frame_texture(actual.animation, actual.frame))
							var b := Mounts._get_texture_image(expected.sprite_frames.get_frame_texture(expected.animation, expected.frame))
							_check(a.get_data() == b.get_data(), "switch matches a freshly composed rider")
				if id in SURF_FIVE:
					_check(actor.call("get_interaction_position") == feet, "new mounts do not inherit Kyogre interaction height")
					npc.global_position = feet + direction * 32
					for _frame in range(4):
						await physics_frame
					await process_frame
					Input.action_press("interact")
					_check(npc.call("_can_start_manual_interaction"), "same-row adjacent NPC passes the complete interaction gate")
					Input.action_release("interact")
					for offset: Vector2 in [-direction * 32, direction * 64, direction * 32 + direction.orthogonal() * 32]:
						npc.global_position = feet + offset
						_check(not npc.call("_is_player_facing_npc", actor), "rear, distant and diagonal NPCs remain out of reach")
			_check(actor.call("get_feet_position") == feet and actor.get_node("Look").position == look and actor.get_node("DetectionShape").position == collision, "mount switches preserve physical, visual and collision anchors")
			fresh.free()
	# The inherited fishing check compares actual local/remote player pixels.
	for id: String in SURF_FIVE:
		_check_fishing(actor, remote, id)
		for avatar: Node2D in [actor, remote]:
			_check(str(avatar.get("mount_water_contact").animation) == "idle_up", "fishing keeps contact without a moving wake")
	actor.set("active_mount_id", "")
	actor.call("_sync_mount_visual")
	_check(not actor.get("mount_water_contact").visible, "dismount clears contact")
	actor.free()
	remote.free()
	npc.free()
	await process_frame
	print("Five Surf mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_water_pixels(id: String) -> void:
	var back := Mounts.get_mount_frames(id)
	var front := Mounts.get_mount_foreground_frames(id)
	for direction: String in ["down", "left", "right", "up"]:
		for phase in range(4):
			var a := Mounts._get_texture_image(back.get_frame_texture("walk_" + direction, phase))
			var b := Mounts._get_texture_image(front.get_frame_texture("walk_" + direction, phase))
			var translucent := 0
			var overlap := false
			var bottom := -1
			for y in range(a.get_height()):
				for x in range(a.get_width()):
					var aa := a.get_pixel(x, y).a
					var ba := b.get_pixel(x, y).a
					if aa > 0.0 or ba > 0.0:
						bottom = y
					if (aa > 0.0 and aa < 1.0) or (ba > 0.0 and ba < 1.0):
						translucent += 1
					if aa > 0.0 and ba > 0.0:
						overlap = true
			_check(translucent > 0 and not overlap, id + " has submerged pixels without doubled translucent foreground")
			# The native swimming cycle moves fins/tails; check the resting silhouette.
			if phase == 0:
				_check(absi(bottom - 112) <= 3, id + " rests at the occupied tile instead of floating above it")
