extends SceneTree

const WorldPresenceServiceScript := preload("res://scripts/services/world_presence_service.gd")

var failed := false


func _init() -> void:
	_check_water_position_restores_surf_without_rechecking_entitlement()
	_check_presence_payload_and_signature_include_activity_style()
	_check_remote_avatar_resolves_replicated_surf_pose()
	_check_remote_surf_render_matches_local_pose_rules()
	quit(1 if failed else 0)


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


func _check_presence_payload_and_signature_include_activity_style() -> void:
	var service := WorldPresenceServiceScript.new()
	var movement := service._build_movement_payload(
		{"isMoving": false, "activityStyle": "ride"},
		{},
		"",
		{}
	)
	_expect(
		str(movement.get("activityStyle", "")) == "ride",
		"world presence payload retains the local activity style"
	)
	service.free()

	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var signature_source := _function_source(world_source, "_get_current_player_position_signature")
	_expect(
		signature_source.contains('player.call("get_activity_style")')
		and signature_source.contains("activity_style,"),
		"presence signature changes when the Surf pose changes"
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
		and source.contains("return current_activity_style"),
		"remote avatars apply the replicated Surf pose to their body frames"
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
		and _function_source(remote_source, "_uses_static_activity_movement_pose").contains(
			"BODY_MOVEMENT_RIDE"
		)
		and _function_source(local_source, "_uses_static_activity_movement_pose").contains(
			"BODY_MOVEMENT_RIDE"
		),
		"local and remote Surf both use a static movement pose"
	)


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
