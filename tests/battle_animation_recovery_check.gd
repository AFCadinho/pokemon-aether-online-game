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
	box.queue_free()
	await get_tree().process_frame
	print("PASS battle_animation_recovery_check" if not failed else "FAIL battle_animation_recovery_check")
	get_tree().quit(1 if failed else 0)

func _attack(box: Node, done: Dictionary) -> void:
	await box.play_attack_tween()
	done["value"] = true

func _substitute(box: Node, done: Dictionary) -> void:
	await box.set_substitute_active(true)
	done["value"] = true

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
