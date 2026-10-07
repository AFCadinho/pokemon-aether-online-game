extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	root.add_child(local)
	local.call("set_display_name", "Mounted Trainer", true)
	local.call("set_creator_nameplate_visible", true)
	local.call("_setup_map_chat_bubble")
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.set_process(false)
	var baseline: Vector2 = local.get_node("Nameplate").position
	var count := 0
	for gender: String in ["male", "female"]:
		for id: String in Mounts.get_mount_ids_for_mode("land") + Mounts.get_mount_ids_for_mode("surf"):
			local.set("active_mount_id", id)
			local.set("activity_style", "ride")
			local.call("_apply_body_appearance", Appearance.DEFAULT_FEMALE_BODY_ID if gender == "female" else Appearance.DEFAULT_MALE_BODY_ID)
			local.call("_sync_mount_visual")
			remote.call("apply_state", _presence(id, gender))
			for direction: Vector2 in DIRECTIONS:
				for moving: bool in [false, true]:
					for actor: Node2D in [local, remote]:
						actor.set("last_direction", direction)
						if actor == local:
							actor.call("set_idle_frame")
						else:
							actor.call("_update_animation", moving)
						actor.call("_sync_mount_animation", moving, direction)
						var mount := actor.get_node("Look/MountSprite") as AnimatedSprite2D
						mount.pause()
						var plate := actor.get_node("Nameplate") as Control
						var stable_y := plate.position.y
						for frame in range(mount.sprite_frames.get_frame_count(mount.animation)):
							mount.frame = frame
							actor.call("_on_mount_frame_changed")
							actor.call("_update_mount_hover", 0.3)
							_check(is_equal_approx(plate.position.y, stable_y), "stable across animation/hover: " + id)
							var actual_top := _visible_top(actor.get_node("Look"), actor)
							_check(plate.position.y + _stack_bottom(plate) <= actual_top - 5.9, "clear rider and mount: %s %s %s" % [id, direction, gender])
							_check(plate.position.x == baseline.x, "name stays centered")
							count += 1
						var bubble: Node = actor.get("map_chat_bubble")
						_check(is_equal_approx(bubble.overhead_offset, plate.position.y - baseline.y), "chat follows nameplate")
			# Test the battle indicator created before the presence applies its mount.
			remote.call("apply_state", _presence(id, gender, true))
			var indicator: Node = remote.get("nearby_battle_indicator")
			_check(indicator.anchor_position == remote.call("_get_nearby_battle_indicator_anchor"), "spectate indicator follows mount changes")
	# Moving onto raised ground shifts the whole overhead stack with the Look.
	for actor: Node2D in [local, remote]:
		var before: float = actor.get_node("Nameplate").position.y
		actor.set("stair_visual_offset", Vector2(0, -16))
		actor.call("_apply_activity_visual_offset")
		_check(is_equal_approx(actor.get_node("Nameplate").position.y, before - 16), "nameplate follows stair elevation")
		actor.set("stair_visual_offset", Vector2.ZERO)
		actor.call("_apply_activity_visual_offset")
	# Changing an equipped visual must invalidate geometry through its new frames.
	var headgear := remote.get_node("Look/Rider/HeadgearSprite") as AnimatedSprite2D
	var tall_pixels := Image.create(64, 160, false, Image.FORMAT_RGBA8)
	tall_pixels.fill(Color.CYAN)
	var tall_frames := SpriteFrames.new()
	tall_frames.add_frame(&"default", ImageTexture.create_from_image(tall_pixels))
	headgear.sprite_frames = tall_frames
	headgear.animation = &"default"
	headgear.show()
	remote.call("_sync_nameplate_position")
	var tall_plate := remote.get_node("Nameplate") as Control
	_check(tall_plate.position.y + _stack_bottom(tall_plate) <= _visible_top(remote.get_node("Look"), remote) - 5.9, "new tall headgear clears nameplate")
	# Guild badge can extend lower than a short name card.
	var emblem := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	emblem.fill(Color.CYAN)
	var guild := remote.get_node("Nameplate/GuildEmblem") as TextureRect
	guild.texture = ImageTexture.create_from_image(emblem)
	guild.show()
	remote.get_node("Nameplate/GuildEmblemBackground").show()
	remote.call("_sync_nameplate_layout")
	var plate := remote.get_node("Nameplate") as Control
	_check(plate.position.y + _stack_bottom(plate) <= _visible_top(remote.get_node("Look"), remote) - 5.9, "guild badge clears mounted silhouette")
	for actor: Node2D in [local, remote]:
		actor.set("active_mount_id" if actor == local else "current_mount_id", "")
		actor.call("_sync_mount_visual")
		_check(actor.get_node("Nameplate").position == baseline, "dismount restores exact original nameplate position")
		_check(actor.get("map_chat_bubble").overhead_offset == 0.0, "dismount restores chat bubble")
	local.queue_free()
	remote.queue_free()
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			await _preview(arg.trim_prefix("--preview="))
	print("Mount nameplate checks: ", "FAILED" if failed else "PASS", " (", count, " rendered frame positions)")
	quit(1 if failed else 0)


func _presence(id: String, gender: String, battle := false) -> Dictionary:
	return {"userId": 1, "displayName": "adinho", "gender": gender, "appearance": Appearance.get_default_appearance(gender), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": id}, "activityState": "battle" if battle else "idle", "battleSpectate": {"kind": "wild"} if battle else {}}


# Independent current-frame geometry, including all actual node transforms.
func _visible_top(node: Node, actor: Node2D) -> float:
	var top := INF
	if node is AnimatedSprite2D and node.visible and node.sprite_frames != null:
		var texture: Texture2D = node.sprite_frames.get_frame_texture(node.animation, node.frame)
		if texture != null:
			var pixels := texture.get_image()
			if pixels.is_compressed():
				pixels.decompress()
			var used := Rect2(pixels.get_used_rect())
			if used.has_area():
				used.position += node.offset - (texture.get_size() * 0.5 if node.centered else Vector2.ZERO)
				var transform: Transform2D = actor.global_transform.affine_inverse() * node.global_transform
				top = (transform * used).position.y
	for child: Node in node.get_children():
		top = minf(top, _visible_top(child, actor))
	return top


func _stack_bottom(plate: Control) -> float:
	var bottom := -INF
	for child: Node in plate.get_children():
		if child is Control and child.visible:
			bottom = maxf(bottom, child.position.y + child.size.y)
	return bottom


func _preview(path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("253645")
	background.z_index = -4096
	viewport.add_child(background)
	var ids := ["giratina_origin", "ho_oh", "rayquaza", "lapras"]
	for row in range(2):
		for column in range(ids.size()):
			var actor: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
			viewport.add_child(actor)
			actor.set_process(false)
			actor.call("apply_state", _presence(ids[column], "male", true))
			actor.position = Vector2(140 + column * 280, 360 + row * 400)
			actor.scale = Vector2(2, 2)
			actor.set("last_direction", Vector2.DOWN if row == 0 else Vector2.LEFT)
			actor.call("_update_animation", false)
			var label := Label.new()
			label.text = ids[column]
			label.position = Vector2(20 + column * 280, 10 + row * 400)
			viewport.add_child(label)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	_check(viewport.get_texture().get_image().save_png(path) == OK, "preview saved")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
