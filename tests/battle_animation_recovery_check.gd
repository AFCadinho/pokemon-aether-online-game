extends Node

const Wait := preload("res://scripts/battle/battle_animation_wait.gd")
var failed := false

class SlowRouter extends BattleAnimationRouter:
	signal release
	var delayed := true
	func play_damage_tween_for_target(_ident: String, _sound := "normal") -> void:
		if delayed:
			await release

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var box := load("res://scenes/battle/sprite_box.tscn").instantiate() as Control
	get_tree().root.add_child(box)
	box.single_sprite.visible = true
	await _check_dodge(box)
	var done := {"value": false}
	_attack(box, done)
	await get_tree().create_timer(0.03).timeout
	box.reset_battle_pose()
	await get_tree().create_timer(0.05).timeout
	_check(done["value"], "cancelled sprite tween releases its caller")
	done["value"] = false
	_substitute(box, done)
	await get_tree().create_timer(0.03).timeout
	box.clear_substitute_immediately()
	await get_tree().create_timer(0.05).timeout
	_check(done["value"] and not box.substitute_active, "cancelled substitute does not restore stale visibility")
	# Use an independent paused tween to prove the bounded wait as well.
	var paused := box.create_tween()
	paused.tween_interval(100.0)
	paused.pause()
	_check(not await Wait.for_tween(box, paused, 0.05), "paused tween times out")
	_check(not paused.is_valid(), "timeout retires only its own tween")
	var router := SlowRouter.new()
	var renderer := BattleEventRenderer.new()
	renderer.animation_router = router
	renderer.host_node = box
	renderer.message_timing = BattleMessageTiming.new()
	renderer.event_timeout_seconds = 0.05
	var updates: Array = []
	renderer.set_active_hud_hp_from_event = func(_target, event, previous): updates.append([event["marker"], previous])
	await renderer.render_event({"marker": "old"}, {"damage_target_ident": "p1a"}, true)
	_check(updates == [["old", true]], "stalled renderer returns within budget")
	router.delayed = false
	await renderer.render_event({"marker": "new"}, {"damage_target_ident": "p1a"}, true)
	router.release.emit()
	await get_tree().process_frame
	_check(updates == [["old", true], ["new", true], ["new", false]], "late callback cannot overwrite the newer HP presentation")
	box.reset_battle_pose()
	var expected_detached_position: Vector2 = box.single_sprite.position
	var expected_detached_scale: Vector2 = box.single_sprite.scale
	get_tree().root.remove_child(box)
	box.single_sprite.position = Vector2(999.0, 999.0)
	box.single_sprite.scale = Vector2(9.0, 9.0)
	box.reset_battle_pose()
	_check(
		box.single_sprite.position == expected_detached_position
			and box.single_sprite.scale == expected_detached_scale,
		"detached sprite boxes retain their cached battle pose"
	)
	box.free()
	await get_tree().process_frame
	print("PASS battle_animation_recovery_check" if not failed else "FAIL battle_animation_recovery_check")
	get_tree().quit(1 if failed else 0)

func _attack(box: Node, done: Dictionary) -> void:
	await box.play_attack_tween()
	done["value"] = true

func _check_dodge(box: Node) -> void:
	var base_position: Vector2 = box.single_sprite.position
	for direction in [-1.0, 1.0]:
		await box.play_dodge_tween(direction)
		_check(box.single_sprite.position == base_position + Vector2(32.0 * direction, -12.0), "both sides dodge away from their original position")
		await get_tree().create_timer(0.2).timeout
		_check(box.single_sprite.position != base_position, "dodge holds until the move has passed")
		await box.play_dodge_tween(direction, true)
		_check(box.single_sprite.position == base_position, "dodge returns exactly to the original pose")
	box.play_dodge_tween()
	await get_tree().create_timer(0.03).timeout
	box.reset_battle_pose()
	await get_tree().create_timer(0.15).timeout
	_check(box.single_sprite.position == base_position, "cancelled dodge cannot displace the restored pose")
	await box.set_substitute_active(true, false)
	var doll_position: Vector2 = box.substitute_sprite.position
	await box.play_dodge_tween()
	_check(box.substitute_sprite.position != doll_position, "visible substitute also dodges")
	box.reset_battle_pose()
	_check(box.substitute_sprite.position == doll_position, "cancel restores substitute pose")
	box.clear_substitute_immediately()
	var router := BattleAnimationRouter.new()
	router.setup(box, box, box.get_parent())
	var command_renderer := BattleEventRenderer.new()
	command_renderer.animation_router = router
	var commands: Array = []
	command_renderer.show_trainer_command = func(command):
		commands.append(command["kind"])
		if command["kind"] == "dodge":
			_check(box.single_sprite.position == base_position, "dodge callout fires at the start of the sprite movement")
		return {"shown": true, "minimum_read_seconds": 0.7}
	var command: Callable = await command_renderer._show_trainer_move_commands({}, "p1a", "Tackle", "p2a", "miss", true)
	_check(commands == ["move"], "resource loading and attacker motion do not announce dodge early")
	var synchronized_options := {"result": "miss", "on_dodge_started": command}
	await router._play_move_target_dodge("p2a", synchronized_options)
	_check(commands == ["move", "dodge"] and box.single_sprite.position != base_position, "callout and dodge share the same playback boundary")
	await router._play_move_target_dodge("p2a", synchronized_options, true)
	_check(commands == ["move", "dodge"], "returning does not repeat the dodge callout")
	command_renderer.cancel_render()
	command.call()
	_check(commands == ["move", "dodge"], "cancelled event cannot show a stale dodge command")
	var config := {"category": "physical_contact", "miss": {"enabled": true, "target_offset": [56, -20], "sheet_offset": [56, -20], "shift_visual_center": true}, "projectile": {"enabled": true, "path": [[0, 0], [100, 100]]}, "orb": {"center": [384, 96]}}
	for reverse in [false, true]:
		var hit := router._create_move_animation_node(config, {}, reverse)
		var miss := router._create_move_animation_node(config, {}, reverse)
		router._apply_move_animation_options(miss, config, {"result": "miss"})
		var actor := "p2a" if reverse else "p1a"
		var target := "p1a" if reverse else "p2a"
		router._apply_move_projectile_endpoint_anchors(hit, actor, target, box.get_parent(), config)
		router._apply_move_projectile_endpoint_anchors(miss, actor, target, box.get_parent(), config, {"result": "miss"})
		_check(hit.projectile_config == miss.projectile_config, "missed projectiles keep the same target on both sides")
		_check(hit.sprite_position_offset == miss.sprite_position_offset and hit.sparkle_center == miss.sparkle_center and hit.orb_config == miss.orb_config, "missed contact and centered effects stay on target")
		hit.free()
		miss.free()
	for result in ["hit", "immune", "fail", "miss"]:
		var options := {"result": result}
		await router._play_move_target_dodge("p2a", options)
		_check((box.single_sprite.position != base_position) == (result == "miss"), "only true misses trigger a dodge: " + result)
		_check(router._should_suppress_target_feedback_for_miss(config, options) == (result == "miss"), "misses suppress target impact feedback")
		box.reset_battle_pose()

func _substitute(box: Node, done: Dictionary) -> void:
	await box.set_substitute_active(true)
	done["value"] = true

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
