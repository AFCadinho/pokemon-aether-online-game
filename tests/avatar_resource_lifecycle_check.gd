extends SceneTree

const MountServiceScript := preload("res://scripts/services/mount_service.gd")

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var script := load("res://scripts/world/remote_player_avatar.gd") as Script
	var parent := Node2D.new()
	root.add_child(parent)
	var avatar: Node2D = script.new()
	parent.add_child(avatar)
	var pixels: Array = []
	pixels.resize(1024)
	pixels.fill(0)
	var state := {"userId": 1, "displayName": "Test", "facingDirection": "down",
		"position": {"x": 32, "y": 32}, "guildEmblem": {"palette": ["#ffffffff"], "pixels": pixels}}
	avatar.apply_state(state)
	var first: Texture2D = avatar.guild_emblem.texture
	state.position.x = 64
	avatar.apply_state(state)
	_check(first == avatar.guild_emblem.texture, "movement preserves the guild texture")
	var other: Node2D = script.new()
	parent.add_child(other)
	other.apply_state(state)
	_check(other.guild_emblem.texture == first, "avatars share an identical guild texture")
	state.guildEmblem.palette[0] = "#ff0000ff"
	avatar.apply_state(state)
	_check(first != avatar.guild_emblem.texture, "changed palette refreshes the emblem")
	state.guildEmblem = {}
	avatar.apply_state(state)
	_check(not avatar.guild_emblem.visible, "leaving a guild removes the emblem")
	avatar.last_direction = Vector2.RIGHT
	avatar._update_animation(false)
	var body: AnimatedSprite2D = avatar._get_body_sprite()
	_check(body.animation == &"idle_right", "idle facing updates immediately")
	avatar._update_animation(true)
	_check(body.animation == &"walk_right" and body.is_playing(), "starting movement starts walking")
	avatar._update_animation(false)
	_check(body.animation == &"idle_right" and not body.is_playing(), "stopping movement restores idle")
	state.facingDirection = "right"
	state.movement = {
		"isMoving": true,
		"activityStyle": "ride",
		"mountId": "cyclizar",
		"startPosition": {"x": 64, "y": 32},
		"targetPosition": {"x": 96, "y": 32},
		"duration": 0.065,
	}
	state.position.x = 96
	avatar.apply_state(state)
	avatar.mount_sprite.frame = 2
	var hair: AnimatedSprite2D = avatar._get_appearance_sprite("HairSprite")
	_check(
		body.animation == &"walk_right" and body.frame == 2 and not body.is_playing(),
		"remote rider uses Cyclizar's current masked frame without animating its pose"
	)
	_check(
		hair.animation == &"walk_right" and hair.frame == 2 and not hair.is_playing(),
		"remote outfit layers use the same masked Cyclizar frame as the body"
	)
	var expected_rider_position: Vector2 = avatar.base_rider_position + Vector2(
		MountServiceScript.get_rider_frame_offset("cyclizar", "right", 2)
	)
	_check(
		avatar.rider_node.position == expected_rider_position,
		"remote rider follows Cyclizar's current animation frame"
	)
	_check(
		avatar.mount_foreground_sprite.frame == avatar.mount_sprite.frame,
		"remote mount foreground follows Cyclizar's current animation frame"
	)
	state.erase("movement")
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		avatar.last_direction = direction
		avatar._update_animation(true)
		var expected_offset := Vector2.ZERO
		if direction == Vector2.LEFT:
			expected_offset = Vector2(-4, 4)
		elif direction == Vector2.RIGHT:
			expected_offset = Vector2(4, 4)
		elif direction == Vector2.DOWN:
			expected_offset = Vector2(0, 4)
		_check(hair.offset == expected_offset,
			"remote mounted hair aligns immediately after turning %s" % direction)
		avatar.mount_sprite.frame = 2
		avatar._update_animation(true)
		_check(hair.animation == body.animation and hair.frame == body.frame and body.frame == 2,
			"remote mounted layers retain their mask frame between animation ticks")
	parent.hide()
	state.position.x = 128
	avatar.apply_state(state)
	_check(avatar.target_position.x == 128, "hidden avatars retain received positions")
	_check(avatar.look_node.process_mode == Node.PROCESS_MODE_DISABLED, "hidden appearance animation is suspended")
	parent.show()
	avatar._update_animation(false)
	_check(avatar.look_node.process_mode == Node.PROCESS_MODE_INHERIT, "showing players restores animation processing")
	parent.free()
	var scene := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	var overlay := scene.instantiate()
	var summary: Node = overlay.pokemon_summary_sprite_loader
	var pokedex: Node = overlay.pokedex_sprite_loader
	overlay.free()
	_check(not is_instance_valid(summary) and not is_instance_valid(pokedex), "freeing UI also frees detached preview loaders")
	await process_frame
	await process_frame
	print("avatar_resource_lifecycle_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
