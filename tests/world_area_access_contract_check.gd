extends SceneTree

const PROJECT_PATH := "res://project.godot"
const SERVICE_PATH := "res://scripts/services/world_transition_service.gd"
const AUTH_SERVICE_PATH := "res://scripts/services/auth_service.gd"
const MAP_EXIT_PATH := "res://scripts/world/map_exit.gd"
const GATE_NPC_PATH := "res://scripts/world/npcs/gate_npc.gd"
const WORLD_PATH := "res://scripts/world/world.gd"
const ROUTE_1_PATH := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
const CATALOG_BUILDER_PATH := "res://tools/world_access_catalog_builder.gd"
const CATALOG_GENERATOR_SCENE_PATH := "res://tools/generate_world_access_catalog.tscn"
const GENERATED_CATALOG_PATH := "res://generated/world_access_catalog.json"

var failed := false


func _init() -> void:
	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	var auth_service_source := FileAccess.get_file_as_string(AUTH_SERVICE_PATH)
	var map_exit_source := FileAccess.get_file_as_string(MAP_EXIT_PATH)
	var gate_source := FileAccess.get_file_as_string(GATE_NPC_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var route_source := FileAccess.get_file_as_string(ROUTE_1_PATH)
	var catalog_builder_source := FileAccess.get_file_as_string(CATALOG_BUILDER_PATH)

	_expect(
		project_source.contains(
			'WorldTransitionService="*res://scripts/services/world_transition_service.gd"'
		),
		"World transition service is registered as an autoload"
	)
	_expect(
		service_source.contains('"/game/world/transitions/%s/access"')
		and service_source.contains('"/game/world/transitions/%s/enter"'),
		"Client uses the transition-scoped preview and authoritative enter endpoints"
	)
	_expect(
		service_source.contains("transition_access_cache[normalized_transition_id] = access"),
		"Transition previews are cached for synchronous NPC collision checks"
	)
	_expect(
		auth_service_source.contains("WorldTransitionService.clear_cache()"),
		"Account switches clear transition access cached for the previous player"
	)
	_expect(
		map_exit_source.contains("func _resolve_arrival_facing_direction")
		and map_exit_source.contains('player.get("last_direction")')
		and map_exit_source.contains("arrival_facing_direction")
		and service_source.contains('JSON.stringify({"facingDirection": normalized_facing_direction})')
		and map_exit_source.contains('world.call("apply_authorized_teleport_state", state)'),
		"Map exits preserve entry direction through the server-authoritative destination state"
	)
	_expect(
		map_exit_source.contains('return "%s__%s" % [source_map_id, str(name).to_snake_case()]'),
		"Configured map exits derive stable transition IDs when none is explicit"
	)
	_expect(
		map_exit_source.contains('world.call("cancel_authorized_teleport")')
		and map_exit_source.contains('"world_transition_denial_presenters"'),
		"Denied transitions release the teleport lock and route presentation to the guard"
	)
	_expect(
		world_source.contains("func begin_authorized_teleport(ignore_player_movement := false)")
		and world_source.contains("not ignore_player_movement"),
		"Boundary transitions can authorize while a tile movement is finishing"
	)
	_expect(
		world_source.contains("func _is_allowed_authorized_teleport_scene_path")
		and world_source.contains('normalized_path.begins_with("res://scenes/overworld/")')
		and world_source.contains('normalized_path.ends_with(".tscn")'),
		"Authorized teleports refuse non-overworld client scene paths"
	)
	_expect(
		world_source.contains("active_remote_authorized_teleport_command_id")
		and world_source.contains("completed_remote_authorized_teleport_commands")
		and world_source.contains("func _retry_pending_remote_authorized_teleport"),
		"Remote staff teleports deduplicate commands and retry after transient activity"
	)
	_expect(
		gate_source.contains('@export var guarded_transition_id := ""')
		and gate_source.contains("WorldTransitionService.get_transition_access("),
		"Gate NPCs depend on a transition policy instead of an area or role list"
	)
	_expect(
		not gate_source.contains("LEGACY_STAFF_ROLE_IDS")
		and gate_source.contains('"world:areas:access-in-progress"'),
		"Legacy gates use the explicit permission and contain no hardcoded staff roles"
	)
	_expect(
		route_source.contains('guarded_transition_id = "route_1_to_viridian_city"')
		and route_source.contains('transition_id = "route_1_to_viridian_city"'),
		"Route 1 guard and exit share one stable transition identifier"
	)
	_expect(
		FileAccess.file_exists(CATALOG_GENERATOR_SCENE_PATH)
		and FileAccess.file_exists(GENERATED_CATALOG_PATH)
		and catalog_builder_source.contains('scene_path.contains("/reusable_interiors/")'),
		"World access is generated from concrete overworld scenes"
	)

	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
