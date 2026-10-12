extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var auth := root.get_node("AuthService")
	var existing := root.get_node("EncounterGuardService")
	existing.set_process(false)
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	auth.current_user = {"id": 1}
	auth.session_token = "guard-check"
	var service = load("res://tests/support/encounter_guard_transport.gd").new()
	root.add_child(service)
	service.set_process(false)
	service.session_token = auth.session_token
	var challenge: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/encounter_guard_challenge.json"))
	var now := Time.get_unix_time_from_system()
	var locked := {"locked": true, "active": false, "expired": false, "remaining": 0, "battleId": "wild-check", "serverTime": now, "expiresAt": now + 60, "attemptsRemaining": 3, "challenge": challenge}
	service.apply_state(locked)
	await process_frame
	_check(paused and service.backdrop.visible, "rare encounter pauses gameplay and covers the screen")
	_check(service.layer.layer > 1000, "challenge appears above world transition overlays")
	_check(service.grid.get_child_count() == 6, "six real server PNG symbols render")
	_check(service.prompt.text.contains("→"), "prompt specifies the required order")
	for button: Button in service.grid.get_children():
		_check(button.icon != null and button.custom_minimum_size.x >= 112, "symbol offers a large click target")
	await service._choose(str(challenge.options[0].id), service.grid.get_child(0))
	await service._choose(str(challenge.options[1].id), service.grid.get_child(1))
	_check(service.requests.is_empty() and paused, "two clicks cannot dismiss the lock")
	var rotated: Dictionary = locked.duplicate(true)
	rotated.serverTime = now + 1
	rotated.challenge.id = "new-challenge"
	rotated.attemptsRemaining = 2
	service.response = {"success": true, "encounterGuard": rotated}
	await service._choose(str(challenge.options[2].id), service.grid.get_child(2))
	_check(paused and service.choices.is_empty(), "incorrect answer rotates the challenge and keeps gameplay paused")
	var request: Dictionary = service.requests[0]
	_check(request.suffix == "/unlock" and request.body.choices == [str(challenge.options[0].id), str(challenge.options[1].id), str(challenge.options[2].id)], "three clicks send opaque identities in order")
	_check(request.body.challengeId == challenge.id and request.body.battleId == "wild-check", "answer is bound to challenge and battle")
	service.apply_state(locked)
	_check(service.challenge_id == "new-challenge", "a stale poll cannot restore an old challenge")
	service.response = {"success": true, "encounterGuard": {"locked": false, "remaining": 0, "battleId": "wild-check", "serverTime": now + 2}}
	for i in range(3):
		await service._choose(str(challenge.options[i].id), service.grid.get_child(i))
	_check(not paused and not service.backdrop.visible, "only accepted server unlock resumes gameplay")
	service.apply_state({"locked": false, "waitingForPartner": true, "serverTime": now + 2.5})
	_check(paused and service.backdrop.visible and not service.grid.visible, "co-op partner waits without receiving another player’s challenge")
	var active := {"locked": false, "active": true, "remaining": 2999, "serverTime": now + 3}
	service.apply_state(active)
	_check(service.badge.visible and service.badge.text.contains("2999"), "remaining encounter charge is visible")
	service.apply_state({"locked": false, "active": false, "remaining": 0, "serverTime": now + 4})
	_check(not service.badge.visible, "depletion removes the active charge badge")
	var policy = load("res://scripts/ui/inventory_item_use_policy.gd")
	_check(policy.overworld_consumable_action({"id": "encounter-guard"}) == "activate_encounter_guard", "guard dispatches without a Pokemon target even from older Bag projections")
	_check(load("res://scripts/services/item_icon_resolver.gd").load_icon("encounter-guard") != null, "item has its own shield icon")
	# Compile the world and Bag paths touched by this feature, too.
	_check(load("res://scripts/world/world.gd").can_instantiate(), "world start/resume guard paths compile")
	_check(load("res://scripts/ui/ui_overlay.gd").can_instantiate(), "Bag and hotbar guard dispatch compile")
	locked.serverTime = now + 5
	service.apply_state(locked)
	service.deadline_msec = Time.get_ticks_msec() - 1
	service.polling = true
	service.submitting = true
	service._process(0)
	_check(not service.logged_out and paused, "local timer does not discard a pending last-second answer")
	service.apply_state({"locked": false, "battleId": "wild-check", "serverTime": now + 6})
	_check(not service.logged_out and not paused, "server accepts a timely answer even after local countdown reaches zero")
	locked.serverTime = now + 7
	service.apply_state(locked)
	service.apply_state({"locked": false, "battleId": "", "serverTime": now + 8})
	_check(service.logged_out and not paused, "server timeout cleanup logs out even when the realtime notice was missed")
	service.queue_free()
	await process_frame
	auth.session_token = ""
	auth.current_user = {}
	print("Encounter Guard check: ", failures, " failures")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
