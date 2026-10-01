extends SceneTree

var failed := false

class FakeThieving extends Node:
	var state_loaded := true
	var calls := 0
	var reply := {"success": true, "outcome": "success", "rewardMoney": 120, "experienceAwarded": 8}
	func is_unlocked() -> bool:
		return true
	func get_level() -> int:
		return 99
	func is_npc_attempted_today(_id: String) -> bool:
		return false
	func attempt_pickpocket(_id: String, _defer: bool) -> Dictionary:
		calls += 1
		await get_tree().create_timer(0.15).timeout
		return reply

class FakeStory extends Node:
	func refresh_story() -> Dictionary:
		return {}

class DummyPlayer extends Node2D:
	var style := ""
	func face_world_position(_position: Vector2) -> void:
		pass
	func set_activity_style(value: String) -> void:
		style = value
	func get_activity_style() -> String:
		return style
	func clear_activity_style() -> void:
		style = ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var script := load("res://scripts/ui/thieving_attempt_feedback.gd")
	var target := Node2D.new()
	target.position = Vector2(400, 300)
	root.add_child(target)
	var feedback = script.new()
	target.add_child(feedback)
	feedback.begin(target)
	feedback.set_process(false)
	_check(feedback.layer > 20, "Attempt meter renders above the HUD and nameplates")
	_check(feedback.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Attempt feedback does not block pointer input")
	feedback._process(0.25)
	_check(feedback.meter.value > 0 and feedback.meter.value < 85, "Attempt meter rises during the hand movement")
	feedback._process(1.0)
	_check(feedback.phase == "pending" and feedback.meter.value == 85, "Unconfirmed attempt stops short of completion")
	feedback._process(5.0)
	_check(feedback.phase == "pending" and not feedback.is_queued_for_deletion(), "Slow server response keeps the waiting meter visible")
	feedback.finish({"success": true, "outcome": "success", "rewardMoney": 120, "experienceAwarded": 8})
	_check(feedback.phase == "success" and feedback.meter.value == 100, "Confirmed success completes the meter")
	_check(feedback.detail.text.contains("120") and feedback.detail.text.contains("8"), "Success displays the authoritative money and XP")
	feedback._process(1.0)
	_check(feedback.is_queued_for_deletion(), "Result feedback clears automatically")
	await process_frame

	feedback = script.new()
	target.add_child(feedback)
	feedback.begin(target)
	feedback.set_process(false)
	feedback.finish({"success": true, "outcome": "caught"})
	_check(feedback.phase == "caught", "Confirmed detection has distinct feedback")
	feedback.finish({"success": false, "outcome": "success"})
	_check(feedback.phase == "error", "Failed request never presents a successful theft")
	target.position = Vector2.ZERO
	feedback._process(0)
	_check(feedback.panel.position.x >= 8 and feedback.panel.position.y >= 8, "Meter remains on screen at map edges")
	feedback.free()

	# Exercise the real NPC coroutine with isolated server and story services.
	var npc = load("res://scripts/world/npcs/base_npc.gd").new()
	var look := Node2D.new()
	look.name = "Look"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	look.add_child(sprite)
	npc.add_child(look)
	var feet := Marker2D.new()
	feet.name = "FeetMarker"
	npc.add_child(feet)
	var area := Area2D.new()
	area.name = "InteractionArea"
	npc.add_child(area)
	root.add_child(npc)
	var service := FakeThieving.new()
	root.add_child(service)
	var story := FakeStory.new()
	root.add_child(story)
	npc.ThievingService = service
	npc.PlayerGameStateService = story
	var player := DummyPlayer.new()
	root.add_child(player)
	npc._start_pickpocket(player)
	var actual = npc.get_node_or_null("ThievingAttemptFeedback")
	_check(actual != null and npc.is_interacting, "Real pickpocket attempt starts its meter while interaction is locked")
	await create_timer(0.58).timeout
	_check(actual.phase == "pending", "NPC meter waits during the server request")
	await create_timer(0.25).timeout
	_check(actual.phase == "success" and not npc.is_interacting, "Server success updates the meter and releases interaction")
	_check(service.calls == 1 and player.style == "", "One attempt submits once and restores the player's pose")
	await create_timer(1.0).timeout
	_check(npc.get_node_or_null("ThievingAttemptFeedback") == null, "Completed NPC attempt leaves no meter behind")
	npc.queue_free()
	player.queue_free()
	service.queue_free()
	story.queue_free()
	target.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
