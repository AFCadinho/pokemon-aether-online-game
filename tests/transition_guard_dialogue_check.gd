extends SceneTree

class PassageStoryHook extends Node:
	var attempts := 0
	var handled := true
	func is_configured() -> bool:
		return true
	func try_handle_interaction(_host: Node, _player: Node2D, trigger: String) -> Dictionary:
		assert(trigger == "interact")
		attempts += 1
		return {"success": true, "handled": handled}

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := "res://scenes/overworld/kanto/transition_buildings/"
	var count := 0
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".tscn"): continue
		var scene: Node = load(directory + file).instantiate()
		_check(scene.get_node("Entities/NPCs/GateNPC").separate_passage_dialogue, file + " separates conversation from access denial")
		count += 1
		scene.free()
	_check(count == 12, "all twelve transition buildings audited")
	var guard: Node = load("res://scenes/npcs/gate_npc.tscn").instantiate()
	guard.set_script(load("res://tests/fixtures/transition_guard_dialogue_probe.gd"))
	guard.separate_passage_dialogue = true
	guard.guard_role = "transition_guard"
	guard.requires_party_pokemon = false
	guard.allowed_dialogue_id = "greeting"
	guard.blocked_dialogue_id = "closed"
	guard.passage_closed = true
	root.add_child(guard)
	var player := Node2D.new()
	root.add_child(player)
	var hook := PassageStoryHook.new()
	guard.add_child(hook)
	await guard._run_story_or_legacy_interaction(player, "interact")
	_check(guard.spoken == ["greeting"] and hook.attempts == 0 and guard.access_refreshes == 0, "talking at a closed gate greets without running denial or story")
	await guard.on_route_gate_blocked(player)
	_check(hook.attempts == 1 and guard.spoken == ["greeting"], "blocked grid movement runs the quest hook without a duplicate warning")
	hook.handled = false
	await guard.on_route_gate_blocked(player)
	_check(guard.spoken.back() == "closed", "unhandled passage attempt uses local closure dialogue")
	await guard.present_world_transition_denied({"allowed": false, "dialogueId": "server_denial"}, player)
	_check(hook.attempts == 3 and guard.spoken.back() == "server_denial", "exit denial falls back to the authoritative server dialogue")
	hook.handled = true
	var before: int = guard.spoken.size()
	await guard.present_world_transition_denied({"allowed": false, "dialogueId": "server_denial"}, player)
	_check(hook.attempts == 4 and guard.spoken.size() == before, "exit denial also runs quest completion without duplicate dialogue")
	guard.passage_closed = false
	guard.transition_access = {"allowed": true}
	guard.transition_access_resolved = true
	guard._sync_guard_presence()
	_check(guard.visible and guard.is_gate_open(), "counter attendant stays available after passage opens")
	await guard.interact_with_player(player)
	_check(guard.spoken.back() == "greeting", "open gate still uses the ordinary greeting")
	guard.separate_passage_dialogue = false
	guard.passage_closed = true
	await guard.interact_with_player(player)
	_check(guard.spoken.back() == "closed", "other GateNPC users retain their existing behavior")
	player.free()
	guard.free()
	print("TRANSITION_GUARD_DIALOGUE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
