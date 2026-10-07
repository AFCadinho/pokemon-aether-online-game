extends SceneTree

const WorldPresenceServiceScript := preload("res://scripts/services/world_presence_service.gd")
const WaterRippleEffectScript := preload("res://scripts/world/water_ripple_effect.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_surf_follower_lifecycle_and_presence()
	_check_surf_moves_at_running_speed()
	_check_surf_ripples_render_below_mount()
	_check_water_position_restores_surf_without_rechecking_entitlement()
	_check_surf_can_cross_authorized_transitions()
	_check_presence_payload_and_signature_include_activity_style()
	_check_remote_avatar_resolves_replicated_surf_pose()
	_check_remote_surf_render_matches_local_pose_rules()
	_check_mount_animation_continues_across_tiles()
	quit(1 if failed else 0)


func _check_surf_follower_lifecycle_and_presence() -> void:
	var local_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	_expect(
		_function_source(local_source, "_start_surf_activity").contains("refresh_pokemon_follower()"),
		"starting or resuming Surf updates follower visibility"
	)
	var finish_source := _function_source(local_source, "_finish_surf_activity")
	_expect(
		finish_source.contains("refresh_pokemon_follower()")
		and finish_source.contains("reset_pokemon_follower_position()"),
		"leaving Surf restores the follower at the player's current position"
	)
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_expect(
		_function_source(world_source, "_get_current_follower_presence_state").contains(
			'and bool(player.call("is_surfing_activity_active"))'
		),
		"Surf also hides the follower in presence sent to other players"
	)


func _check_surf_moves_at_running_speed() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var movement_source := _function_source(source, "_get_current_tile_move_duration")
	var animation_source := _function_source(source, "_get_current_walk_animation_speed")
	_expect(
		movement_source.contains("if surf_activity_active:\n\t\treturn RUN_TILE_MOVE_DURATION"),
		"Surf completes tiles at the same speed as running"
	)
	_expect(
		animation_source.contains("if surf_activity_active:\n\t\treturn RUN_WALK_ANIMATION_SPEED"),
		"Surf animation cadence matches running speed"
	)


func _check_surf_ripples_render_below_mount() -> void:
	var ripple := WaterRippleEffectScript.new()
	var ripple_position := Vector2(64.0, 96.0)
	ripple.play(ripple_position, "surf_step")
	_expect(
		ripple.z_index < floori(ripple_position.y) - 1,
		"Surf ripples render below the player and its behind-rider mount layer"
	)
	ripple.free()


func _check_water_position_restores_surf_without_rechecking_entitlement() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var function_source := _function_source(source, "sync_activity_state_for_current_tile")
	_expect(
		function_source.contains("if _is_water_tile_at(global_position):")
		and function_source.contains("if not surf_activity_active:")
		and function_source.contains("_start_surf_activity(false)"),
		"a restored water position resumes Surf"
	)
	_expect(
		not function_source.contains("_has_party_field_move")
		and not function_source.contains("surf_unlocked"),
		"Surf restoration does not repeat the asynchronous entry entitlement check"
	)


func _check_surf_can_cross_authorized_transitions() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var block_source := _function_source(world_source, "_get_authorized_teleport_block_reason")
	_expect(
		block_source.contains('if bool(player.get("fishing_activity_active")):'),
		"active Fishing still blocks an authorized transition"
	)
	_expect(
		not block_source.contains('player.get("surf_activity_active")'),
		"active Surf may enter water map exits and authorized teleporters"
	)

	var map_exit_source := FileAccess.get_file_as_string("res://scripts/world/map_exit.gd")
	var transition_source := _function_source(map_exit_source, "_enter_authorized_transition")
	_expect(
		transition_source.contains('begin_authorized_teleport", true'),
		"map exits start their authorized transition while the player completes a tile move"
	)

	var apply_source := _function_source(world_source, "apply_authorized_teleport_state")
	var position_source := _function_source(world_source, "_position_player_at_authorized_teleport_state")
	_expect(
		apply_source.contains("player.call(\"reset_movement_state\")")
		and position_source.contains("_sync_player_activity_state_for_current_tile()"),
		"authorized arrivals reset the old activity and restore Surf only on water"
	)


func _check_presence_payload_and_signature_include_activity_style() -> void:
	var service := WorldPresenceServiceScript.new()
	var movement := service._build_movement_payload(
		{"isMoving": false, "activityStyle": "ride", "mountId": "lapras"}
	)
	_expect(
		str(movement.get("activityStyle", "")) == "ride",
		"world presence payload retains the local activity style"
	)
	_expect(
		str(movement.get("mountId", "")) == "lapras",
		"world presence payload retains the active Surf mount"
	)
	service.free()

	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var signature_source := _function_source(world_source, "_get_current_player_position_signature")
	_expect(
		signature_source.contains('player.call("get_activity_style")')
		and signature_source.contains('player.call("get_active_mount_id")')
		and signature_source.contains("active_mount_id,"),
		"presence signature changes when the Surf pose or mount changes"
	)


func _check_remote_avatar_resolves_replicated_surf_pose() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	var resolver_source := _function_source(source, "_resolve_activity_style")
	_expect(
		resolver_source.contains('movement_state.get("activityStyle"')
		and resolver_source.contains("normalize_movement_style"),
		"remote avatars resolve the replicated activity style"
	)
	_expect(
		source.contains("current_activity_style = _resolve_activity_style(state, movement_data)")
		and source.contains('movement_data.get("mountId"')
		and source.contains("return current_activity_style"),
		"remote avatars apply the replicated Surf pose and mount"
	)


func _check_remote_surf_render_matches_local_pose_rules() -> void:
	var local_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var remote_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	_expect(
		remote_source.contains(
			'const RIDE_STATIC_PART_CATEGORIES := ["hair", "headgear", "facial_hair", "facegear", "eyes", "eyebrows"]'
		),
		"remote Surf keeps the same layered parts static as the local pose"
	)
	_expect(
		remote_source.contains('"down": {\n'
			+ '\t\t\t"hair": Vector2(0.0, 4.0),')
		and remote_source.contains('"eyes": Vector2(0.0, 6.0)')
		and remote_source.contains('"left": {\n'
			+ '\t\t\t"hair": Vector2(-4.0, 4.0),')
		and remote_source.contains('"right": {\n'
			+ '\t\t\t"hair": Vector2(4.0, 4.0),'),
		"remote Surf uses the local direction-specific layer offsets"
	)
	_expect(
		_function_source(remote_source, "_update_animation").contains(
			"is_moving and not uses_static_pose"
		)
		and _function_source(remote_source, "_update_animation").contains(
			"_sync_activity_layer_offsets()"
		)
		and _function_source(remote_source, "_update_animation").contains(
			"_sync_mount_animation(is_moving, last_direction)"
		)
		and _function_source(local_source, "play_walk_animation").contains(
			"_sync_mount_animation(true, direction)"
		)
		and _function_source(remote_source, "_uses_static_activity_movement_pose").contains(
			"BODY_MOVEMENT_RIDE"
		)
		and _function_source(local_source, "_uses_static_activity_movement_pose").contains(
			"BODY_MOVEMENT_RIDE"
		),
		"local and remote riders stay stable while the Surf mount animates"
	)


func _check_mount_animation_continues_across_tiles() -> void:
	var local_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var local_walk_source := _function_source(local_source, "play_walk_animation")
	var mount_sync_source := _function_source(local_source, "_sync_mount_animation")
	_expect(
		local_walk_source.contains("_apply_static_activity_idle_pose(direction)")
		and not local_walk_source.contains("set_idle_frame()")
		and mount_sync_source.contains("animation_changed"),
		"local Surf keeps Lapras animation frames across chained tile moves"
	)

	var remote_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	var remote_mount_sync_source := _function_source(remote_source, "_sync_mount_animation")
	_expect(
		remote_mount_sync_source.contains("animation_changed"),
		"remote Surf keeps Lapras animation frames across replicated tile moves"
	)
	# Exercise playback rather than requiring a particular is_playing() guard:
	# play() on the same animation resumes without restarting its current frame.
	var frames: SpriteFrames = load("res://scripts/services/mount_service.gd").get_mount_frames("lapras")
	for script_path: String in ["res://scripts/world/player.gd", "res://scripts/world/remote_player_avatar.gd"]:
		var actor: Node2D = load(script_path).new()
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		actor.add_child(sprite)
		actor.set("mount_sprite", sprite)
		actor.set("activity_style" if script_path.ends_with("/player.gd") else "current_activity_style", "surf")
		for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			actor.call("_sync_mount_animation", true, direction)
			_expect(sprite.frame == 0 and sprite.is_playing(), "changing direction starts the correct walking cycle")
			sprite.set_frame_and_progress(2, 0.4)
			for repeat in range(5):
				actor.call("_sync_mount_animation", true, direction)
				_expect(sprite.frame == 2 and is_equal_approx(sprite.frame_progress, 0.4) and sprite.is_playing(), "chained local/remote Surf updates preserve animation progress")
		actor.free()


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
