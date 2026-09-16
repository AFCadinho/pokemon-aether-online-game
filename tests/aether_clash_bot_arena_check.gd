extends SceneTree

var failed := false
var contacts: Array = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var duel = load("res://scenes/overworld/aether_clash/aether_clash_duel.tscn").instantiate()
	root.add_child(duel)
	await process_frame
	duel.instance_session_id = "bot-arena-test"
	duel.engagement_contact_requested.disconnect(Callable(duel, "_on_engagement_contact_requested"))
	duel.engagement_contact_requested.connect(func(source: int, target: int, method: String): contacts.append([source, target, method]))
	var save := root.get_node("PlayerSave")
	var original_id: String = save.player_id
	save.player_id = "1"
	var human := Node2D.new()
	human.add_to_group("player")
	root.add_child(human)
	human.global_position = Vector2(240, 4112)
	var state := _payload("entry_open")
	duel.call("_apply_arena_state", state)
	var actors: Dictionary = duel.bot_actors
	_check(actors.size() == 1, "Server-owned bot renders without a remote player")
	var bot := actors.get(2) as Node2D
	if bot == null:
		quit(1)
		return
	_check(bot.global_position == Vector2(336, 4112), "Bot renders at its fixed anchor")
	_check(not bot.is_in_group("remote_player_avatar") and not bot.is_in_group("npc") and not bot.has_method("interact_with_player"), "Bot has no social/presence/NPC interactions")
	_check(str(bot.nameplate.text).contains("[BOT]"), "Training bots are labelled")
	_check(bot.nameplate.text == "Trainer 1 [BOT]", "Small training rosters show full bot names")
	state.session.botCount = 21
	duel.call("_apply_arena_state", state)
	_check(bot.nameplate.text == "[BOT] 1", "Large training rosters retain compact bot labels")
	state.session.botCount = 1
	duel.call("_apply_arena_state", state)
	_check(duel.bot_actors[2] == bot, "Repeated snapshots reuse the actor")
	_check(not duel.call("is_world_actor_step_blocked", Vector2(240, 4112), Vector2(288, 4112)), "Entry phase cannot trigger contact battles")
	state = _payload("active")
	duel.call("_apply_arena_state", state)
	_check(duel.call("is_world_actor_step_blocked", Vector2(240, 4112), Vector2(288, 4112)), "Active contact blocks entry into the bot ring")
	_check(contacts == [[1, 2, "player_contact"]], "Contact uses the ordinary player_contact request")
	_check(not duel.call("is_world_actor_step_blocked", Vector2(304, 4112), Vector2(272, 4112)), "Player can back away from contact")
	state["arenaPlayers"][1]["engagementId"] = "engagement-fixture"
	state["arenaPlayers"][1]["engagementRoomCode"] = "CLASH-FIXTURE"
	duel.call("_apply_arena_state", state)
	duel.call("_sync_battle_indicators")
	_check(bot.sprite.modulate.a < 1.0, "Engaged bot is visibly busy")
	_check(bot.get_node_or_null("AetherClashBattleIndicator") != null, "Bot uses the existing battle indicator")
	contacts.clear()
	duel.call("is_world_actor_step_blocked", Vector2(240, 4112), Vector2(288, 4112))
	_check(contacts.is_empty(), "Busy bot cannot start another contact")
	state = _payload("active")
	duel.call("_apply_arena_state", state)
	_check(bot.global_position == Vector2(336, 4112) and bot.sprite.modulate.a == 1.0, "Surviving bot returns free at the same anchor")
	state["arenaPlayers"] = [{"userId": 1, "side": "blue"}]
	duel.call("_apply_arena_state", state)
	_check(duel.bot_actors.is_empty() and duel.call("_actor_for_user_id", 2) == null, "Eliminated bot disappears from rendering and contact lookup")
	state = _payload("active")
	state["arenaPlayers"][1]["bot"]["actorKey"] = "clash-bot:another-session:1"
	duel.call("_apply_arena_state", state)
	_check(duel.bot_actors.is_empty(), "Other-session bot snapshots are not rendered")
	duel.call("_apply_arena_state", _payload("completed"))
	_check(duel.bot_actors.is_empty(), "Terminal sessions cannot retain bots")
	duel.call("_apply_arena_state", _payload("active"))
	duel.call("configure_aether_clash_instance", "aether_clash_duel:new-session")
	_check(duel.bot_actors.is_empty(), "Changing instances clears all old bot actors")
	duel.queue_free()
	human.queue_free()
	save.player_id = original_id
	await process_frame
	quit(1 if failed else 0)


func _payload(status: String) -> Dictionary:
	return {"success": true, "viewerRole": "participant", "viewerSide": "blue",
		"session": {"id": "bot-arena-test", "status": status, "challengerGuild": {"name": "Humans"}, "challengedGuild": {"name": "Trainers [BOT]"}},
		"arenaPlayers": [{"userId": 1, "side": "blue"}, {"userId": 2, "side": "red", "bot": {
			"actorKey": "clash-bot:bot-arena-test:1", "displayName": "Trainer 1 [BOT]",
			"spriteId": "trainer_class_ace_trainer_m", "x": 336, "y": 4112}}]}


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
	else:
		print("PASS ", label)
