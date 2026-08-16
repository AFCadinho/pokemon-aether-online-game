extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"
const HEAL_NPC_PATH := "res://scripts/world/npcs/heal_npc.gd"

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var heal_npc_source := FileAccess.get_file_as_string(HEAL_NPC_PATH)

	_expect(
		world_source.contains("func end_wild_battle(keep_overworld_locked := false)"),
		"Battle cleanup supports keeping the overworld locked for blackout respawns"
	)
	_expect(
		world_source.contains("_begin_blackout_respawn_transition()\n\tend_wild_battle(should_respawn_after_loss)"),
		"Blackout locking starts before battle cleanup can resume autosaves"
	)
	_expect(
		world_source.contains("authorized_teleport_in_progress = true")
		and world_source.contains("authorized_teleport_locked_overworld = true"),
		"Blackout respawns use the authorized teleport lock"
	)
	_expect(
		world_source.contains("while is_saving_player_position:\n\t\tawait get_tree().process_frame")
		and world_source.find("while is_saving_player_position:") < world_source.find(
			"var result: Dictionary = await PlayerGameStateService.respawn_player()"
		),
		"Blackout respawn waits for an in-flight position save before changing the server destination"
	)
	_expect(
		world_source.contains('SfxManager.play("pokemon_recovery")'),
		"Blackout recovery plays the Pokémon healing sound"
	)
	_expect(
		heal_npc_source.contains('@export var respawn_spawn_marker := "HealNPC"')
		and heal_npc_source.contains('"spawnMarker": respawn_spawn_marker.strip_edges()'),
		"Heal NPCs persist a stable scene spawn marker with the numeric fallback position"
	)
	_expect(
		world_source.contains(
			"await get_tree().physics_frame\n"
			+ "\tposition_result = _position_player_at_authorized_teleport_state(target_map, state)"
		),
		"Authorized teleports reapply their destination after the first map physics frame"
	)
	_expect(
		world_source.contains('saved_state.get("teleportAcknowledgementRequired", false)')
		and world_source.contains(
			"var ack_result: Dictionary = await _ack_authorized_teleport_state(saved_state)"
		),
		"Login recovers a teleport acknowledgement interrupted by a client shutdown"
	)
	_expect(
		world_source.contains("PlayerGameStateService.acknowledge_player_teleport("),
		"Teleport acknowledgements send only the server-issued revision"
	)
	_expect(
		world_source.contains(
			'var teleport_command_id := _optional_string(state.get("teleportCommandId"))'
		)
		and world_source.contains(
			"func _optional_string(value: Variant) -> String:\n"
			+ "\tif value == null:\n"
			+ "\t\treturn \"\""
		),
		"Blackout respawn acknowledgements omit a null staff command ID"
	)
	var ack_position := world_source.find(
		"var ack_result: Dictionary = await _ack_authorized_teleport_state(state)"
	)
	var loading_release_position := world_source.find("is_loading_map = false", ack_position)
	_expect(
		ack_position >= 0 and loading_release_position > ack_position,
		"The map transition barrier remains active until the teleport destination is acknowledged"
	)
	_expect(
		world_source.contains("camera.reset_smoothing()\n\tcamera.force_update_scroll()"),
		"Map camera limits immediately scroll to the teleported player"
	)

	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
