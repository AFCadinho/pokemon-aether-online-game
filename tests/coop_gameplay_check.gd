extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	_expect(service.ORDINARY_TRAINERS.size() == 8, "ordinary trainer slice is explicitly bounded")
	for trainer: String in service.ORDINARY_TRAINERS:
		_expect(service.trainer_entity(trainer) == trainer, "ordinary trainer uses its own canonical entity")
	_expect(service.trainer_entity("kanto_route_1_youngster_liam").is_empty() and service.trainer_entity("kanto_viridian_forest_bug_catcher_sammy").is_empty(), "single-Pokemon trainers cannot silently duplicate their roster")
	var activity := {"reservationId": "fixture", "battleId": "coop-fixture", "status": "active"}
	service.apply_state({"party": {"leaderId": 1}, "invitations": [], "activity": activity,
		"view": {"battleId": "coop-fixture", "revision": 2, "decisionId": "coop-1", "locked": false,
			"legalActions": [{"type": "move", "slot": 1, "target": 1}]}})
	service.apply_view({"battleId": "coop-fixture", "revision": 1, "decisionId": "coop-1", "locked": true})
	_expect(service.view["revision"] == 2, "out-of-order snapshots do not roll back the client")
	service.pending_command = {"decisionId": "coop-1", "idempotencyKey": "retry"}
	service.apply_view({"battleId": "coop-fixture", "revision": 3, "decisionId": "coop-1", "locked": true})
	_expect(service.pending_command.is_empty(), "a locked own choice confirms an uncertain submission")
	service.apply_view({"battleId": "someone-else", "revision": 99})
	_expect(service.view["revision"] == 3, "another battle cannot replace the current snapshot")
	service.apply_state({"activity": {"reservationId": "fixture", "battleId": "coop-fixture", "status": "finished"}})
	service.apply_state({"activity": activity})
	_expect(service.activity["status"] == "finished", "late active snapshots cannot reopen a completed battle")
	var first: String = service.new_id()
	var second: String = service.new_id()
	_expect(first.length() == 36 and first != second and first[14] == "4", "request keys are independent UUIDs")
	var controls = load("res://scripts/battle/coop_controls.gd").new()
	controls.battle_mode = true
	root.add_child(controls)
	_expect(controls.get_child_count() > 0, "functional battle controls mount")
	service.view = {"positions": [{"controller": "p1", "details": "Leader"}, {"controller": "p3", "details": "Partner"}]}
	_expect(controls._target_label(-1, "p3") == "Leader" and controls._target_label(-2, "p1") == "Partner", "target locations keep the same meaning for both players")
	var host := Control.new()
	host.visible = false
	root.add_child(host)
	var mounted_world = load("res://tests/fixtures/coop_world_fixture.gd").new()
	mounted_world.battle_ui_host = host
	mounted_world.coop_world_ready = true
	mounted_world._on_coop_state_changed()
	_expect(host.visible and mounted_world.active_battle_kind == "coop" and host.get_child_count() == 1, "co-op entry shows the normally hidden battle host")
	mounted_world._on_coop_state_changed()
	_expect(host.get_child_count() == 1, "repeated snapshots do not mount duplicate battle controls")
	mounted_world.free()
	host.queue_free()
	var story := root.get_node("StoryService")
	story.apply_story({"quests": [{"questId": "oaks_parcel", "status": "completed"}, {"questId": "reach_viridian_city", "status": "completed"}]})
	var gary = load("res://scripts/world/npcs/base_npc.gd").new()
	gary.npc_id = "kanto_route_22_gary_oak"
	gary.visibility_required_quest_id = "oaks_parcel"
	gary.visibility_hidden_quest_id = "reach_viridian_city"
	service.party = {"leaderId": 1}
	_expect(gary._is_story_visibility_active(), "progressed helpers can still interact with Gary while in a party")
	service.party = {}
	_expect(not gary._is_story_visibility_active(), "solo Gary visibility remains unchanged")
	story.reset_story()
	service.party = {"leaderId": 1}
	_expect(not gary._is_story_visibility_active(), "co-op visibility does not skip Gary's prerequisite")
	gary.free()
	service.reset()
	_expect(service.party.is_empty() and service.view.is_empty() and service.pending_command.is_empty(), "logout drops another account's view and retry keys")
	controls.queue_free()
	var world = load("res://scripts/world/world.gd")
	_expect(world != null and world.can_instantiate(), "world compiles with co-op entry and recovery hooks")
	await process_frame
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
