extends SceneTree

var failed := false
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _run() -> void:
	var auth := root.get_node("AuthService")
	var old_token: String = auth.session_token
	var old_user: Dictionary = auth.current_user.duplicate(true)
	auth.current_user = {"id": 99999}
	auth.session_token = "battle-start-fixture"
	var api: Variant = load("res://tests/fixtures/battle_start_api_probe.gd").new()
	root.add_child(api)
	var request := HTTPRequest.new()
	root.add_child(request)
	var position := {"mapId": "fixture", "walkSteps": 10, "teleportRevision": 7}
	var saved := {"success": true, "hasState": true, "state": {"teleportRevision": 7}, "happinessUpdated": false}
	api.replies.assign([{"success": true, "battleId": "fixture", "positionResponse": saved}])
	var result: Dictionary = await api.create_triggered_wild_battle(request, {}, "fixture", "grass", {}, "", "", "", position)
	check(bool(result.get("success")) and api.requests.size() == 1, "Wild start uses one client request")
	check(api.requests[0].path == "/battle/wild-encounter/start" and api.requests[0].body.position == position, "Position revision and steps reach the batch boundary")
	api.requests.clear()
	api.replies.assign([{"success": true, "battleId": "trainer", "positionResponse": saved}])
	result = await api.create_trainer_battle(request, {}, "brock", true, position)
	check(api.requests.size() == 1 and api.requests[0].body.battle.isRematch, "Trainer start preserves rematch in one request")
	for reply: Dictionary in [{"success": false, "status": 503}, {"success": false, "status": 401}, {"success": false, "status": 404, "detail": "Trainer not found"}, {"success": false, "status": 404, "detail": "Not Found", "positionResponse": saved}, {"success": false, "code": 13}]:
		api.requests.clear()
		api.replies.assign([reply])
		result = await api.create_trainer_battle(request, {}, "brock", false, position)
		check(api.requests.size() == 1, "Errors and partial starts never replay a mutation: " + str(reply))
	api.requests.clear()
	api.replies.assign([{"success": true, "battleId": "missing-ack"}])
	result = await api.create_trainer_battle(request, {}, "brock", false, position)
	check(not bool(result.get("success", false)), "Missing position acknowledgement fails closed")
	api.change_session = true
	api.requests.clear()
	api.replies.assign([{"success": true, "positionResponse": saved}])
	result = await api.create_trainer_battle(request, {}, "brock", false, position)
	check(not bool(result.get("success", false)) and api.requests.size() == 1, "Changed session rejects delayed batch response")
	api.change_session = false
	auth.session_token = "battle-start-fixture"
	api.requests.clear()
	api.replies.assign([{"success": true, "playerLeadResponse": {"success": true}, "events": []}])
	result = await api.choose_default_leads(request, "trainer", 2)
	check(api.requests.size() == 1 and api.requests[0].body.slot == 2, "Default trainer leads use one request")
	api.requests.clear()
	api.replies.assign([{"success": false, "status": 404, "detail": "Not Found"}, {"success": true}, {"success": true, "events": []}])
	result = await api.choose_default_leads(request, "trainer", 2)
	check(api.requests.size() == 3 and bool(result.playerLeadResponse.success), "Only a missing batch route uses legacy player and NPC leads")
	check(api.requests[1].path == "/battle/trainer/lead" and api.requests[2].path == "/battle/trainer/npc/lead", "Legacy lead order stays intact")
	var position_service: Variant = root.get_node("PlayerGameStateService")
	position_service.set_script(load("res://tests/fixtures/battle_start_position_probe.gd"))
	api.requests.clear()
	api.replies.assign([{"success": false, "status": 404, "detail": "Not Found"}, {"success": true, "battleId": "legacy"}])
	result = await api.create_trainer_battle(request, {}, "brock", false, position)
	check(api.requests.size() == 2 and position_service.saves == 1 and bool(result.get("success")), "Older backend uses batch probe, position save, then legacy creation")
	check(position_service.saved_payload == position and api.requests[1].path == "/battle/trainer", "Legacy fallback keeps position state and original creation body")
	api.requests.clear()
	position_service.save_reply = {"success": false, "status": 409, "code": "forced_teleport_pending"}
	api.replies.assign([{"success": false, "status": 404, "detail": "Not Found"}])
	result = await api.create_trainer_battle(request, {}, "brock", false, position)
	check(api.requests.size() == 1 and not bool(result.get("success")), "Rejected fallback position prevents legacy creation")
	position_service.save_reply = saved
	api.requests.clear()
	api.replies.assign([{"success": false, "status": 403, "detail": {"code": "web_route_not_allowed"}}, {"success": true, "battleId": "legacy-web"}])
	result = await api.create_trainer_battle(request, {}, "brock", false, position)
	check(api.requests.size() == 2 and bool(result.get("success")), "An older browser bridge safely falls back after rejecting an unknown route")
	position_service.save_reply = {"success": true, "hasState": true, "state": {}, "happinessUpdated": true, "party": [{"ownedPokemonId": 12, "happiness": 72}]}
	api.requests.clear()
	api.replies.assign([{"success": false, "status": 404, "detail": "Not Found"}, {"success": true, "battleId": "legacy"}])
	result = await api.create_trainer_battle(request, {"team": [{"ownedPokemonId": 12, "happiness": 70}]}, "brock", false, position)
	check(api.requests[1].body.player.team[0].happiness == 72, "Legacy creation sees walking happiness applied by the preceding save")
	await _check_world_save(saved)
	auth.session_token = old_token
	auth.current_user = old_user
	api.queue_free()
	request.queue_free()
	await process_frame
	print("high_ping_battle_start_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_world_save(saved: Dictionary) -> void:
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://tests/fixtures/battle_start_world_probe.gd"))
	world.set_process(false)
	var actor := CharacterBody2D.new()
	world.add_child(actor)
	world.player = actor
	world.pending_happiness_walk_steps = 10
	world.current_teleport_revision = 6
	world.start_response = {"success": false, "error": "Fixture battle rejection", "positionResponse": saved}
	var result: Dictionary = await world._start_battle_with_position(Callable(world, "start_probe"))
	check(world.callback_calls == 1 and not bool(result.get("success")), "The combined callback supplies the final battle result")
	check(world.pending_happiness_walk_steps == 0 and world.current_teleport_revision == 7 and world.last_saved_position_signature == "fixture-position", "Successful position reconciles even when battle creation fails")
	check(not world.is_saving_player_position, "Position save lock releases after a combined start")
	world.pending_happiness_walk_steps = 10
	world.authorized_teleport_apply_failed_autosave_blocked = true
	result = await world._start_battle_with_position(Callable(world, "start_probe"))
	check(world.callback_calls == 1 and not bool(result.get("success")), "Interrupted teleport stops a combined start before HTTP")
	world.authorized_teleport_apply_failed_autosave_blocked = false
	world.change_session = true
	result = await world._start_battle_with_position(Callable(world, "start_probe"))
	check(not bool(result.get("success")) and world.pending_happiness_walk_steps == 10, "A stale session cannot reconcile another account's steps")
	check(not world.is_saving_player_position, "Session change releases the save lock")
	world.set_script(null)
	world.queue_free()
	await process_frame
