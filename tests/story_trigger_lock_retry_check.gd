extends SceneTree

var failed := false


class FakeStoryHook extends Node:
	var interaction_count := 0
	var result := {"success": true, "status": "completed"}

	func is_configured() -> bool:
		return true

	func try_handle_interaction(
		_story_host: Node,
		_body: Node2D,
		_trigger_type: String
	) -> Dictionary:
		interaction_count += 1
		return result


class FakeStoryHost extends Node2D:
	var abort_count := 0

	func abort_story_sequence() -> void:
		abort_count += 1


func _init() -> void:
	_run_check.call_deferred()


func _run_check() -> void:
	var game_state := root.get_node("GameState")
	var trigger_script := load("res://scripts/world/story/story_trigger.gd") as GDScript
	var trigger := trigger_script.new() as Area2D
	var trigger_collision := CollisionShape2D.new()
	var trigger_shape := RectangleShape2D.new()
	trigger_shape.size = Vector2(32.0, 32.0)
	trigger_collision.shape = trigger_shape
	trigger.add_child(trigger_collision)
	var hook := FakeStoryHook.new()
	trigger.add_child(hook)
	root.add_child(trigger)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector2(64.0, 0.0)
	var player_collision := CollisionShape2D.new()
	var player_shape := RectangleShape2D.new()
	player_shape.size = Vector2(16.0, 16.0)
	player_collision.shape = player_shape
	player.add_child(player_collision)
	root.add_child(player)

	await physics_frame
	game_state.lock_overworld_input()
	player.position = Vector2.ZERO
	await physics_frame
	await physics_frame

	_check(hook.interaction_count == 0, "locked story entry waits")
	_check(trigger.get("_pending_body") == player, "locked story entry remains pending")

	game_state.unlock_overworld_input()
	await process_frame
	await process_frame

	_check(hook.interaction_count == 1, "pending story entry runs after unlock")
	_check(trigger.get("_pending_body") == null, "completed story entry clears pending player")
	_check(not bool(game_state.is_overworld_input_locked()), "story entry releases its own input lock")

	player.position = Vector2(64.0, 0.0)
	await physics_frame
	await physics_frame
	trigger.set("required_quest_id", "travel_through_mt_moon")
	trigger.set("required_step_id", "cross_mt_moon")
	var story_service := root.get_node("StoryService")
	story_service.apply_story({"quests": [{
		"questId": "travel_through_mt_moon", "status": "active",
		"steps": [{"stepId": "cross_mt_moon", "status": "locked"}],
	}]})
	player.position = Vector2.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	_check(hook.interaction_count == 1, "inactive ambush step does not resolve an interaction")
	_check(not bool(game_state.is_overworld_input_locked()), "inactive ambush step does not stop walking")

	story_service.apply_story({"quests": [{
		"questId": "travel_through_mt_moon", "status": "active",
		"steps": [{"stepId": "cross_mt_moon", "status": "active"}],
	}]})
	await process_frame
	await process_frame
	_check(hook.interaction_count == 2, "choosing a fossil while inside the area activates the pending ambush")
	_check(not bool(game_state.is_overworld_input_locked()), "active ambush releases its input lock")

	player.position = Vector2(64.0, 0.0)
	await physics_frame
	await physics_frame
	story_service.apply_story({"quests": [{
		"questId": "travel_through_mt_moon", "status": "completed",
		"steps": [{"stepId": "cross_mt_moon", "status": "completed"}],
	}]})
	player.position = Vector2.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	_check(hook.interaction_count == 2, "completed ambush does not resolve again on return")
	_check(not bool(game_state.is_overworld_input_locked()), "completed ambush does not stop walking")

	trigger.set("required_quest_id", "")
	player.position = Vector2(64.0, 0.0)
	await physics_frame
	await physics_frame
	var host := FakeStoryHost.new()
	host.name = "FakeHost"
	root.add_child(host)
	trigger.set("story_host_path", trigger.get_path_to(host))
	hook.result = {"success": false, "status": "sequence_failed"}
	player.position = Vector2.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	_check(host.abort_count == 1, "failed sequence restores its cinematic host")
	_check(not bool(game_state.is_overworld_input_locked()), "failed sequence releases its input lock")
	host.queue_free()
	trigger.set("_owns_overworld_lock", true)
	game_state.lock_overworld_input()
	trigger.queue_free()
	await process_frame
	_check(not bool(game_state.is_overworld_input_locked()), "removing a trigger releases the lock it owns")

	player.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
