extends SceneTree

var failed := false


class FakeActor extends Node2D:
	var faced_position := Vector2.ZERO
	var moved_path: Array[String] = []

	func get_feet_position() -> Vector2:
		return global_position + Vector2(0, 8)

	func face_world_position(world_position: Vector2) -> void:
		faced_position = world_position

	func story_move_path(path: Array[String]) -> bool:
		moved_path = path.duplicate()
		return true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_action_allowlist()
	await _test_safe_action_execution()
	_test_movement_helper_contract()
	_test_story_battle_error_feedback()
	_test_hook_and_api_integration_contract()
	quit(1 if failed else 0)


func _test_action_allowlist() -> void:
	var runner := get_root().get_node_or_null("StorySequenceRunner")
	_expect(runner != null, "StorySequenceRunner is registered as an autoload")
	if runner == null:
		return

	var valid_actions := [
		{"type": "dialogue", "dialogueId": "story.oak.intro"},
		{"type": "wait", "durationMs": 10000},
		{"type": "face_actor", "actor": "self", "target": "player"},
		{"type": "move_actor", "actor": "player", "path": ["up", "left"]},
		{"type": "battle", "trainerId": "kanto_oak_1"},
	]
	_expect(bool(runner.validate_actions(valid_actions).get("success", false)), "catalog-v2 action contract is accepted")
	_expect(not bool(runner.validate_actions([]).get("success", false)), "empty action sequences fail closed")
	_expect(
		not bool(runner.validate_actions([{"type": "teleport"}]).get("success", false)),
		"unknown action types fail closed"
	)
	_expect(
		not bool(runner.validate_actions([{"type": "wait", "durationMs": 10001}]).get("success", false)),
		"wait duration is bounded by the wire contract"
	)
	var roundtrip_actions: Variant = JSON.parse_string(JSON.stringify(valid_actions))
	_expect(
		bool(runner.validate_actions(roundtrip_actions).get("success", false)),
		"JSON roundtrip preserves semantic integer actions"
	)
	_expect(
		not bool(runner.validate_actions([{"type": "wait", "durationMs": 1.5}]).get("success", false)),
		"wait rejects fractional numeric values"
	)
	_expect(
		not bool(runner.validate_actions([{"type": "wait", "durationMs": INF}]).get("success", false))
		and not bool(runner.validate_actions([{"type": "wait", "durationMs": NAN}]).get("success", false))
		and not bool(runner.validate_actions([{"type": "wait", "durationMs": true}]).get("success", false)),
		"wait rejects non-finite numbers and booleans"
	)
	_expect(
		not bool(runner.validate_actions([
			{"type": "dialogue", "dialogueId": "story.oak.intro", "extra": true},
		]).get("success", false)),
		"actions with unknown fields fail closed"
	)
	_expect(
		not bool(runner.validate_actions([
			{"type": "face_actor", "actor": "self", "target": "self"},
		]).get("success", false)),
		"face_actor requires different allowlisted actors"
	)
	_expect(
		not bool(runner.validate_actions([
			{"type": "move_actor", "actor": "player", "path": ["diagonal"]},
		]).get("success", false)),
		"move_actor rejects non-grid directions"
	)
	_expect(
		not bool(runner.validate_actions([
			{"type": "battle", "trainerId": "kanto_oak_1"},
			{"type": "wait", "durationMs": 0},
		]).get("success", false)),
		"battle is only allowed as the final action"
	)


func _test_safe_action_execution() -> void:
	var runner := get_root().get_node("StorySequenceRunner")
	var game_state := get_root().get_node("GameState")
	var host := FakeActor.new()
	var player := FakeActor.new()
	get_root().add_child(host)
	get_root().add_child(player)
	host.global_position = Vector2(32, 64)
	player.global_position = Vector2(96, 128)

	game_state.unlock_input()
	game_state.lock_overworld_input()
	var result: Dictionary = await runner.run_sequence([
		{"type": "face_actor", "actor": "self", "target": "player"},
		{"type": "move_actor", "actor": "player", "path": ["up", "right"]},
		{"type": "wait", "durationMs": 0},
	], host, player)
	_expect(bool(result.get("success", false)), "allowlisted non-content actions execute in order")
	_expect(host.faced_position == player.get_feet_position(), "face_actor only resolves self/player targets")
	_expect(player.moved_path == ["up", "right"], "movement delegates only to story_move_path")
	_expect(
		game_state.overworld_input_locked and not game_state.input_locked and not game_state.ui_input_locked,
		"runner restores the caller input lock after the sequence"
	)
	game_state.unlock_input()
	host.queue_free()
	player.queue_free()


func _test_movement_helper_contract() -> void:
	var npc := _source("res://scripts/world/npcs/base_npc.gd")
	var player := _source("res://scripts/world/player.gd")
	_expect(
		npc.contains("func can_story_move_path(path: Array[String]) -> bool:")
		and npc.contains("func story_move_path(path: Array[String]) -> bool:")
		and npc.contains("direction_name not in STORY_PATH_DIRECTIONS"),
		"BaseNPC exposes a bounded cardinal story path"
	)
	_expect(
		player.contains("func can_story_move_path(path: Array[String]) -> bool:")
		and player.contains("func story_move_path(path: Array[String]) -> bool:")
		and player.contains("direction_name not in STORY_PATH_DIRECTIONS"),
		"player exposes a bounded cardinal story path"
	)


func _test_story_battle_error_feedback() -> void:
	var hook_script := load("res://scripts/world/story/story_hook.gd") as GDScript
	var hook := hook_script.new() as Node
	_expect(
		bool(hook.call("_is_player_actionable_sequence_error", {
			"status": 409,
			"detail": {
				"code": "pokemon_level_cap_party_ineligible",
				"levelCap": 18,
			},
		})),
		"story battles expose an actionable party level-cap rejection"
	)
	_expect(
		not bool(hook.call("_is_player_actionable_sequence_error", {
			"status": "trainer_identity_mismatch",
		})),
		"internal story sequence failures keep the safe generic error"
	)
	hook.free()


func _test_hook_and_api_integration_contract() -> void:
	var game_state_service := get_root().get_node("PlayerGameStateService")
	var service := _source("res://scripts/services/player_game_state_service.gd")
	var runner := _source("res://scripts/services/story_sequence_runner.gd")
	var hook := _source("res://scripts/world/story/story_hook.gd")
	var trigger := _source("res://scripts/world/story/story_trigger.gd")
	var npc := _source("res://scripts/world/npcs/base_npc.gd")
	var interactable := _source("res://scripts/world/interactables/world_interactable.gd")
	var player := _source("res://scripts/world/player.gd")
	var project := _source("res://project.godot")

	_expect(
		service.contains('STORY_INTERACTION_ENDPOINT := "/game/story/interactions/%s"')
		and service.contains('endpoint := (STORY_INTERACTION_ENDPOINT % normalized_interaction_id.uri_encode()) + "/resolve"')
		and service.contains('endpoint := (STORY_INTERACTION_ENDPOINT % normalized_interaction_id.uri_encode()) + "/complete"'),
		"client API uses the resolve and complete interaction endpoints"
	)
	_expect(
		service.contains('"mapId": map_id.strip_edges()')
		and service.contains('"entityId": entity_id.strip_edges()')
		and service.contains('"trigger": trigger.strip_edges()')
		and service.contains('"requestId": normalized_request_id')
		and service.contains('"expectedRevision": expected_revision'),
		"client API sends the exact resolve and completion fields"
	)
	var roundtrip_resolve: Dictionary = JSON.parse_string(JSON.stringify({
		"handled": false,
		"interactionId": "oak_intro",
		"revision": 4,
		"actions": [],
		"completionRequired": false,
	})) as Dictionary
	_expect(
		bool(game_state_service.call("_is_valid_story_resolve_body", roundtrip_resolve)),
		"resolve accepts a JSON-roundtripped semantic integer revision"
	)
	var fractional_resolve := roundtrip_resolve.duplicate(true)
	fractional_resolve["revision"] = 4.5
	var negative_resolve := roundtrip_resolve.duplicate(true)
	negative_resolve["revision"] = -1
	_expect(
		not bool(game_state_service.call("_is_valid_story_resolve_body", fractional_resolve))
		and not bool(game_state_service.call("_is_valid_story_resolve_body", negative_resolve)),
		"resolve rejects fractional and negative revisions"
	)
	var request_id := "12345678-1234-4abc-8def-1234567890ab"
	var roundtrip_complete: Dictionary = JSON.parse_string(JSON.stringify({
		"requestId": request_id,
		"story": {"revision": 5, "quests": []},
		"effects": [],
	})) as Dictionary
	_expect(
		bool(game_state_service.call("_is_valid_story_complete_body", roundtrip_complete, request_id, 4)),
		"complete accepts matching canonical UUID, story projection, and effects"
	)
	var mismatched_complete := roundtrip_complete.duplicate(true)
	mismatched_complete["requestId"] = "87654321-4321-4abc-8def-1234567890ab"
	var noncanonical_complete := roundtrip_complete.duplicate(true)
	noncanonical_complete["requestId"] = "12345678-1234-4ABC-8def-1234567890ab"
	var fractional_complete := roundtrip_complete.duplicate(true)
	(fractional_complete["story"] as Dictionary)["revision"] = 5.5
	var missing_quests := roundtrip_complete.duplicate(true)
	(missing_quests["story"] as Dictionary).erase("quests")
	var missing_effects := roundtrip_complete.duplicate(true)
	missing_effects.erase("effects")
	var invalid_effects := roundtrip_complete.duplicate(true)
	invalid_effects["effects"] = {}
	var item_reward_effects := roundtrip_complete.duplicate(true)
	item_reward_effects["effects"] = [{
		"effectId": "grant_mom_ability_capsule",
		"rewardId": "mom_ability_capsule_reward",
		"alreadyGranted": false,
		"grants": [{
			"itemId": "ability-capsule",
			"name": "ability-capsule",
			"quantity": 1,
			"quantityAfter": 1,
		}],
	}]
	var malformed_effects := item_reward_effects.duplicate(true)
	((malformed_effects["effects"] as Array)[0] as Dictionary)["grants"] = [{
		"itemId": "ability-capsule",
		"quantity": 1,
	}]
	_expect(
		not bool(game_state_service.call("_is_valid_story_complete_body", mismatched_complete, request_id, 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", noncanonical_complete, str(noncanonical_complete["requestId"]), 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", fractional_complete, request_id, 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", missing_quests, request_id, 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", missing_effects, request_id, 4)),
		"complete fails closed on UUID mismatch/format and invalid story projection"
	)
	_expect(
		not bool(game_state_service.call("_is_valid_story_complete_body", invalid_effects, request_id, 4))
		and bool(game_state_service.call("_is_valid_story_complete_body", item_reward_effects, request_id, 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", malformed_effects, request_id, 4)),
		"client completion accepts only the trusted item-reward effect contract"
	)
	var stale_revision := roundtrip_complete.duplicate(true)
	(stale_revision["story"] as Dictionary)["revision"] = 4
	var jumped_revision := roundtrip_complete.duplicate(true)
	(jumped_revision["story"] as Dictionary)["revision"] = 6
	_expect(
		not bool(game_state_service.call("_is_valid_story_complete_body", stale_revision, request_id, 4))
		and not bool(game_state_service.call("_is_valid_story_complete_body", jumped_revision, request_id, 4)),
		"complete requires exactly one authoritative revision transition"
	)
	var story_service := get_root().get_node("StoryService")
	story_service.call("apply_story", {"revision": 8, "quests": []})
	var stale_applied := bool(story_service.call(
		"apply_story_if_not_stale",
		{"revision": 7, "quests": []}
	))
	var current_applied := bool(story_service.call(
		"apply_story_if_not_stale",
		{"revision": 9, "quests": []}
	))
	_expect(
		not stale_applied and current_applied and int(story_service.call("get_revision")) == 9,
		"idempotent completion replay cannot regress a newer local story projection"
	)
	story_service.call("reset_story")
	_expect(
		service.contains("not _is_nonnegative_integer(body.get(\"revision\"))")
		and service.contains('interaction_id != interaction_id.strip_edges()'),
		"resolve schema requires a trimmed interaction id and nonnegative semantic integer revision"
	)
	var resolve_position := hook.find("resolve_story_interaction")
	var identity_position := hook.find("interaction_identity_mismatch")
	var fallback_position := hook.find('if not bool(resolve_result.get("handled", false)):')
	var runner_position := hook.find("StorySequenceRunner.run_sequence")
	var complete_position := hook.find("complete_story_interaction")
	var apply_position := hook.find("StoryService.apply_story_if_not_stale")
	_expect(
		resolve_position >= 0
		and resolve_position < runner_position
		and runner_position < complete_position
		and complete_position < apply_position,
		"hook resolves, runs, acknowledges, then applies authoritative story state"
	)
	_expect(
		resolve_position < identity_position and identity_position < fallback_position,
		"hook verifies response identity before handled=false can reach legacy behavior"
	)
	_expect(
		hook.contains('if not bool(resolve_result.get("handled", false)):')
		and hook.contains('if not bool(resolve_result.get("completionRequired", false)):')
		and hook.find('"status": "pending_battle"') < complete_position,
		"hook only acknowledges completed sequences and never advances a pending battle"
	)
	_expect(
		hook.contains("for attempt: int in range(COMPLETE_ATTEMPTS):")
		and hook.contains("request_id,")
		and hook.contains("_is_retryable_completion_failure")
		and hook.contains("await InventoryService.load_inventory()"),
		"completion retries reuse one UUID inside a single hook call"
	)
	_expect(
		npc.contains('bool(result.get("success", false)) and result.has("handled") and not bool(result.get("handled", true))')
		and interactable.contains('bool(result.get("success", false)) and result.has("handled") and not bool(result.get("handled", true))'),
		"legacy behavior only follows an explicit successful handled=false response"
	)
	_expect(
		runner.contains("GameState.lock_input()")
		and runner.contains("DialogueBox restores")
		and runner.contains('"dialogue_not_presented"')
		and runner.contains('"status": "pending_battle"'),
		"sequence requires presented dialogue, stays locked, and leaves battle pending"
	)
	_expect(
		runner.contains('str(metadata.get("id", "")) != dialogue_id')
		and runner.contains('str(metadata.get("dialogueId", "")) != dialogue_id')
		and runner.contains('"status": "dialogue_identity_mismatch"')
		and runner.contains('str(trainer_metadata.get("id", "")) != trainer_id')
		and runner.contains('"status": "trainer_identity_mismatch"'),
		"sequence verifies fetched dialogue and trainer identities before side effects"
	)
	_expect(
		runner.contains('host.has_method("build_battle_trainer_metadata")')
		and runner.contains('host.call("build_battle_trainer_metadata", trainer_metadata)'),
		"story battles reuse the placed NPC's battle sprite and portrait"
	)
	_expect(
		npc.contains("func story_move_path(path: Array[String]) -> bool:")
		and player.contains("func story_move_path(path: Array[String]) -> bool:")
		and npc.contains(
			"if not can_story_move_path(path) or not _preflight_story_move_path(path):\n"
			+ "\t\treturn false\n\n\tis_npc_moving = true"
		)
		and player.contains(
			"if not can_story_move_path(path) or not _preflight_story_move_path(path):\n"
			+ "\t\treturn false\n\n\tstory_path_movement_active = true"
		)
		and npc.contains("not _has_story_movement_context()")
		and player.contains("not _has_story_movement_context()")
		and player.contains("if not story_path_movement_active:"),
		"NPC and player preflight full grid paths before any movement"
	)
	_expect(
		trigger.contains('"area_enter"')
		and trigger.contains("GameState.is_overworld_input_locked()")
		and trigger.contains("GameState.is_ui_input_locked()")
		and trigger.contains("_release_owned_overworld_lock()")
		and trigger.contains("return get_node_or_null(story_host_path)")
		and project.contains('StorySequenceRunner="*res://scripts/services/story_sequence_runner.gd"'),
		"area triggers fail closed on host config and respect existing lock ownership"
	)


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "can read %s" % path)
		return ""
	return file.get_as_text()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
