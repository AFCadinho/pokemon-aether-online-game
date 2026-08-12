extends SceneTree

const PROJECT_PATH := "res://project.godot"
const SERVICE_PATH := "res://scripts/services/world_transition_service.gd"
const LOCKED_DOOR_PATH := "res://scripts/world/interactables/locked_door_interactable.gd"
const LOCKED_DOOR_SCENE_PATH := "res://scenes/world/interactables/locked_door_interactable.tscn"
const AUTH_SERVICE_PATH := "res://scripts/services/auth_service.gd"
const MAP_EXIT_PATH := "res://scripts/world/map_exit.gd"
const GATE_NPC_PATH := "res://scripts/world/npcs/gate_npc.gd"
const GATE_SCENE_PATH := "res://scenes/npcs/gate_npc.tscn"
const WORLD_PATH := "res://scripts/world/world.gd"
const ROUTE_1_PATH := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
const ROUTE_22_PATH := "res://scenes/overworld/kanto/routes/kanto_route_22.tscn"
const PALLET_TOWN_PATH := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const PEWTER_CITY_PATH := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
const VIRIDIAN_CITY_PATH := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
const CATALOG_BUILDER_PATH := "res://tools/world_access_catalog_builder.gd"
const CATALOG_GENERATOR_SCENE_PATH := "res://tools/generate_world_access_catalog.tscn"
const GENERATED_CATALOG_PATH := "res://generated/world_access_catalog.json"
const LEGACY_STAFF_CATALOG_PATH := "res://generated/staff_teleport_catalog.json"
const LEGACY_STAFF_GENERATOR_PATH := "res://tools/generate_staff_teleport_catalog.py"

var failed := false


func _init() -> void:
	var project_source := FileAccess.get_file_as_string(PROJECT_PATH)
	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	var locked_door_source := FileAccess.get_file_as_string(LOCKED_DOOR_PATH)
	var locked_door_scene_source := FileAccess.get_file_as_string(LOCKED_DOOR_SCENE_PATH)
	var auth_service_source := FileAccess.get_file_as_string(AUTH_SERVICE_PATH)
	var map_exit_source := FileAccess.get_file_as_string(MAP_EXIT_PATH)
	var gate_source := FileAccess.get_file_as_string(GATE_NPC_PATH)
	var gate_scene_source := FileAccess.get_file_as_string(GATE_SCENE_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var route_source := FileAccess.get_file_as_string(ROUTE_1_PATH)
	var route_22_source := FileAccess.get_file_as_string(ROUTE_22_PATH)
	var pallet_town_source := FileAccess.get_file_as_string(PALLET_TOWN_PATH)
	var pewter_city_source := FileAccess.get_file_as_string(PEWTER_CITY_PATH)
	var viridian_city_source := FileAccess.get_file_as_string(VIRIDIAN_CITY_PATH)
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
		service_source.contains('"/game/world/areas/%s/access"')
		and service_source.contains("func get_area_access")
		and service_source.contains("area_access_cache"),
		"Door locks use the shared server-authoritative world area access service"
	)
	_expect(
		locked_door_source.contains("get_area_access")
		and locked_door_source.contains("dialogueId")
		and locked_door_source.contains("blocks_movement = not allowed")
		and locked_door_scene_source.contains("LockedDoorInteractable"),
		"Locked door interactables block movement and display backend-provided reasons"
	)
	_expect(
		service_source.contains("transition_access_cache[normalized_transition_id] = access"),
		"Transition previews are cached for synchronous NPC collision checks"
	)
	_expect(
		service_source.contains('body.get("story", {})')
		and service_source.contains("StoryService.apply_story_if_not_stale(story)"),
		"Authorized transitions immediately apply their authoritative story projection"
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
		world_source.contains("ignore_player_movement := false,")
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
		world_source.contains('var spawn_marker_value: Variant = state.get("spawnMarker", "")')
		and world_source.contains("if spawn_marker_value != null:")
		and world_source.contains("_position_player_at_saved_state(map, state)"),
		"Authorized teleports with a null spawn marker use the exact saved position"
	)
	_expect(
		world_source.contains("active_remote_authorized_teleport_command_id")
		and world_source.contains("completed_remote_authorized_teleport_commands")
		and world_source.contains("func _retry_pending_remote_authorized_teleport"),
		"Remote staff teleports deduplicate commands and retry after transient activity"
	)
	_expect(
		gate_source.contains('@export_enum("attendant", "transition_guard")')
		and gate_source.contains('@export var guarded_transition_id := ""')
		and gate_source.contains("func guards_world_position")
		and gate_source.contains('exit.has_method("contains_world_position")')
		and gate_source.contains("WorldTransitionService.get_transition_access("),
		"Gate NPCs own an explicit role and derive transition blocking from their guarded exit"
	)
	_expect(
		gate_source.contains("transition_access_resolved")
		and gate_source.contains("func _sync_guard_presence()")
		and gate_source.contains("guard_role != GUARD_ROLE_TRANSITION")
		and gate_source.contains("not _are_local_gate_requirements_met()")
		and gate_source.contains("guard_role == GUARD_ROLE_TRANSITION and not guard_present")
		and gate_source.contains("return super.blocks_world_position(world_position)"),
		"Exterior transition guards appear only while server or local access is blocked"
	)
	_expect(
		gate_scene_source.contains("NPC_088_Policeman.png")
		and gate_scene_source.contains("trainer_cards/showdown/policeman-gen7.png"),
		"All route guards share the police overworld sprite and Showdown police portrait"
	)
	_expect(
		map_exit_source.contains("func handles_transition")
		and map_exit_source.contains("func contains_world_position"),
		"Map exits expose their identity and spatial zone to transition guards"
	)
	_expect(
		not gate_source.contains("LEGACY_STAFF_ROLE_IDS")
		and gate_source.contains('"world:areas:access-in-progress"'),
		"Legacy gates use the explicit permission and contain no hardcoded staff roles"
	)
	_expect(
		route_source.contains('guarded_transition_id = "route_1_to_viridian_city"')
		and route_source.contains('guard_role = "transition_guard"')
		and route_source.contains('transition_id = "route_1_to_viridian_city"')
		and route_source.contains('[node name="ViridianGuide"')
		and route_source.contains('position = Vector2(1072, 272)'),
		"Route 1 guard and exit share one stable transition identifier"
	)
	_expect(
		pallet_town_source.contains('guarded_transition_id = "kanto_pallet_town__to_route_1"')
		and pallet_town_source.contains('transition_id = "kanto_pallet_town__to_route_1"')
		and pallet_town_source.contains('guard_role = "transition_guard"')
		and pallet_town_source.contains('[node name="RouteGateNPC"')
		and pallet_town_source.contains('position = Vector2(1040, 208)'),
		"Pallet Town guard owns its starter-gated Route 1 transition"
	)
	_expect(
		viridian_city_source.contains('[node name="NorthRouteGuard"')
		and viridian_city_source.contains('guarded_transition_id = "kanto_viridian_city__to_route_2"')
		and viridian_city_source.contains('transition_id = "kanto_viridian_city__to_route_2"'),
		"Viridian City north guard protects the Route 2 transition"
	)
	_expect(
		viridian_city_source.contains('[node name="SouthRouteGuard"')
		and viridian_city_source.contains('guarded_transition_id = "kanto_viridian_city__to_route_1"')
		and viridian_city_source.contains('transition_id = "kanto_viridian_city__to_route_1"'),
		"Viridian City south guard protects the Route 1 transition"
	)
	_expect(
		viridian_city_source.contains('[node name="WestRouteGuard"')
		and viridian_city_source.contains('guarded_transition_id = "kanto_viridian_city__to_route_22"')
		and viridian_city_source.contains('transition_id = "kanto_viridian_city__to_route_22"')
		and viridian_city_source.contains('npc_id = "kanto_viridian_city_west_route_guard"'),
		"Viridian City west guard protects the Route 22 transition"
	)
	_expect(
		route_22_source.contains('map_id = "kanto_route_22"')
		and route_22_source.contains('[node name="FromViridianCity" type="Marker2D" parent="Spawns"')
		and route_22_source.contains('transition_id = "kanto_route_22__to_viridian_city"')
		and route_22_source.contains('target_spawn_name = "FromRoute22"')
		and route_22_source.contains('[node name="Collision" type="TileMapLayer" parent="."'),
		"Route 22 is a bounded gameplay map with a return transition to Viridian City"
	)
	_expect(
		viridian_city_source.count('instance=ExtResource("23_gate_npc")') == 3
		and viridian_city_source.contains('npc_id = "kanto_viridian_city_north_route_guard"')
		and viridian_city_source.contains('npc_id = "kanto_viridian_city_south_route_guard"')
		and viridian_city_source.contains('npc_id = "kanto_viridian_city_west_route_guard"'),
		"Viridian City has one uniquely identified guard at every route approach"
	)
	_expect(
		viridian_city_source.count('guard_role = "transition_guard"') == 3
		and not viridian_city_source.contains('[node name="RouteGates"')
		and not route_source.contains('[node name="RouteGates"')
		and not pallet_town_source.contains('[node name="RouteGates"')
		and not pewter_city_source.contains('[node name="RouteGates"'),
		"Transition guards replace every separate runtime RouteGates layer"
	)
	_expect(
		FileAccess.file_exists(CATALOG_GENERATOR_SCENE_PATH)
		and FileAccess.file_exists(GENERATED_CATALOG_PATH)
		and catalog_builder_source.contains('scene_path.contains("/reusable_interiors/")')
		and catalog_builder_source.contains('"spawnPoints": _sorted_dictionary(spawn_points)')
		and catalog_builder_source.contains('"safeForStaffTeleport"'),
		"World access is generated from concrete overworld scenes"
	)
	_expect(
		not FileAccess.file_exists(LEGACY_STAFF_CATALOG_PATH)
			and not FileAccess.file_exists(LEGACY_STAFF_GENERATOR_PATH),
		"Staff teleportation has no independent generated catalog"
	)

	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
