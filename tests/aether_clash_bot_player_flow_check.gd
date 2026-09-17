extends Node

# Real NPC/menu, GuildService normalization, map collision and overlay dispatch.
# Only HTTP replies and overlay engine startup are fixtures; no live account.
const MENU := preload("res://scripts/ui/aether_clash_bot_challenge_menu.gd")
const CAPTAIN := preload("res://scenes/npcs/aether_clash_bot_captain_npc.tscn")
const DUEL := preload("res://scenes/overworld/aether_clash/aether_clash_duel.tscn")
var failed := false

class FixtureService extends GuildServiceNode:
	var state: Dictionary = {}
	var requests: Array[Dictionary] = []
	func _authenticated_request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
		requests.append({"path": path, "method": method, "body": {} if body.is_empty() else JSON.parse_string(body)})
		var response: Dictionary = state.session
		if path.ends_with("/options"):
			response = {"available": true, "canChallenge": true, "maxBotCount": 20}
		elif path.ends_with("/portal-sessions"):
			response = {"sessions": [{"session": state.session, "role": "participant"}]}
		elif path.ends_with("/enter"):
			response = {"role": "participant", "session": state.session, "state": {}}
		elif path.ends_with("/arena-state"):
			response = state
		elif path.ends_with("/engagements"):
			response = {"id": "flow-engagement", "sessionId": state.session.id,
				"matchId": "flow-match", "sourceUserId": 1, "targetUserId": 100}
		return {"success": true, "body": response.duplicate(true)}

class FixtureCaptain extends "res://scripts/world/npcs/aether_clash_bot_captain_npc.gd":
	var service: FixtureService
	var confirmations := 0
	func _load_training_options() -> Dictionary:
		return await service.load_aether_clash_bot_options()
	func _create_training_challenge(count: int, tier_id: String, access: String, ai_policy: String, reward_attempt: bool) -> Dictionary:
		return await service.create_aether_clash_bot_challenge(count, tier_id, access, ai_policy, reward_attempt)
	func show_dialogue(_lines: Array[String] = [], _speaker := "") -> bool:
		confirmations += 1
		return true

class FixtureDuel extends "res://scripts/world/aether_clash_duel.gd":
	var service: FixtureService
	func _engagement_service() -> Node:
		return service

class FixtureOverlay extends Node:
	var starts: Array = []
	func start_aether_clash_pvp_match(match_id: String, engagement_id: String) -> bool:
		starts.append([match_id, engagement_id])
		return true

func _ready() -> void:
	var save := get_node("/root/PlayerSave")
	var original_id: String = save.player_id
	save.player_id = "1"
	var human := Node2D.new()
	human.add_to_group("player")
	add_child(human)
	var overlay := FixtureOverlay.new()
	overlay.add_to_group("ui_overlay")
	add_child(overlay)
	var base := ProjectSettings.globalize_path("res://")
	var manifest_path := base.path_join("../backend/account-service/data/aether_clash_bot_anchors.json")
	if not FileAccess.file_exists(manifest_path):
		manifest_path = base.path_join("../pokemon-aether-backend/account-service/data/aether_clash_bot_anchors.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for counts: Array in [[1, 10], [5, 20], [10, 10]]:
		var service := FixtureService.new()
		service.state = _state(int(counts[0]), int(counts[1]), manifest.positions)
		var captain := CAPTAIN.instantiate()
		captain.set_script(FixtureCaptain)
		captain.service = service
		add_child(captain)
		captain.interact_with_player(human)
		captain.interact_with_player(human)
		var menus: Array = captain.get_children().filter(func(n: Node): return n.get_script() == MENU)
		_check(menus.size() == 1, "NPC double interaction opens one setup menu")
		var menu = menus[0]
		menu.bot_count.get_line_edit().text = str(counts[1])
		if OS.get_cmdline_user_args().has("--capture") and counts[0] == 5:
			await _capture("menu")
		menu.dialog.confirmed.emit()
		await get_tree().process_frame
		_check(captain.confirmations == 1 and not captain.interaction_in_flight, "NPC confirms creation and releases interaction lock")
		var request: Dictionary = service.requests[1].body
		_check(request.botCount == counts[1] and not request.has("humanCount"), "Bot count is independent of guild attendance")
		captain.interact_with_player(human)
		var cancel_menus: Array = captain.get_children().filter(func(n: Node): return n.get_script() == MENU)
		cancel_menus[0].dialog.canceled.emit()
		await get_tree().process_frame
		_check(not captain.interaction_in_flight and captain.confirmations == 1, "Canceling setup releases the NPC without creating another training")
		var sessions := await service.load_aether_clash_portal_sessions()
		_check(sessions.sessions.size() == 1 and sessions.sessions[0].session.opponentKind == "bot_guild", "Created training survives portal session normalization")
		var entry := await service.enter_aether_clash_portal("flow-session")
		_check(entry.role == "participant", "Guild member enters through the ordinary portal contract")
		var duel := DUEL.instantiate()
		duel.set_script(FixtureDuel)
		duel.service = service
		add_child(duel)
		await get_tree().process_frame
		duel.instance_session_id = "flow-session"
		var arena := await service.load_aether_clash_arena_state("flow-session")
		duel._apply_arena_state(arena)
		_check(duel.arena_hud.challenger_count_label.text == str(counts[0]) and duel.arena_hud.challenged_count_label.text == str(counts[1]), "HUD shows independent human and bot entry counts")
		if OS.get_cmdline_user_args().has("--capture") and counts[0] == 5:
			var camera := Camera2D.new()
			camera.position = Vector2(1072, 4380)
			camera.zoom = Vector2(1.2, 1.2)
			duel.add_child(camera)
			camera.make_current()
			await _capture("arena")
		_check(duel.bot_actors.size() == counts[1] and duel.arena_players.size() == counts[0] + counts[1], "Unequal rosters render without a fixed 6v6 limit")
		_check(duel.bot_actors[100].nameplate.text == "Trainer 1 [BOT]", "Well-spaced bots show their full names")
		for actor: Node2D in duel.bot_actors.values():
			_check(actor.nameplate.get_minimum_size().x <= 144, "Named bot label fits the spaced anchors")
		var anchor: Vector2 = duel.bot_actors[100].global_position
		human.global_position = anchor - Vector2(96, 0)
		_check(not duel.is_world_actor_step_blocked(human.global_position, anchor - Vector2(48, 0)), "Entry window does not start a battle")
		service.state.session.status = "active"
		duel._apply_arena_state(await service.load_aether_clash_arena_state("flow-session"))
		_check(duel.arena_hud.challenger_count_label.text == str(counts[0]) and duel.arena_hud.challenged_count_label.text == str(counts[1]), "HUD retains unequal counts in the active phase")
		var previous_starts := overlay.starts.size()
		_check(duel.is_world_actor_step_blocked(human.global_position, anchor - Vector2(48, 0)), "Walking into a stationary bot triggers contact")
		await get_tree().process_frame
		_check(overlay.starts.size() == previous_starts + 1 and overlay.starts.back() == ["flow-match", "flow-engagement"], "Ordinary engagement response starts the battle overlay exactly once")
		await duel._on_realtime_message_received({"type": "aether_clash.engagement.started", "engagement": {
			"id": "flow-engagement", "sessionId": "flow-session", "matchId": "flow-match", "sourceUserId": 1, "targetUserId": 100}})
		_check(overlay.starts.size() == previous_starts + 1, "Repeated realtime engagement cannot start a duplicate battle")
		service.state.arenaPlayers.remove_at(int(counts[0]))
		duel._apply_arena_state(await service.load_aether_clash_arena_state("flow-session"))
		_check(not duel.bot_actors.has(100), "Eliminated bot leaves rendering and collision lookup")
		service.state.session.status = "completed"
		duel._apply_arena_state(await service.load_aether_clash_arena_state("flow-session"))
		_check(duel.bot_actors.is_empty(), "Completed training clears every bot")
		duel.free()
		captain.free()
		service.free()
	save.player_id = original_id
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _state(humans: int, bots: int, positions: Array) -> Dictionary:
	var players: Array = []
	for i in range(humans):
		players.append({"userId": i + 1, "side": "blue"})
	for i in range(bots):
		players.append({"userId": 100 + i, "side": "red", "bot": {
			"actorKey": "clash-bot:flow-session:%d" % (i + 1), "displayName": "Trainer %d [BOT]" % (i + 1),
			"spriteId": "trainer_class_ace_trainer_m", "x": positions[i][0], "y": positions[i][1]}})
	return {"success": true, "viewerRole": "participant", "viewerSide": "blue", "arenaPlayers": players,
		"session": {"id": "flow-session", "status": "entry_open", "opponentKind": "bot_guild", "botCount": bots,
			"entryCounts": {"challenger": humans, "challenged": bots}, "activeCounts": {"challenger": humans, "challenged": bots},
			"participantCounts": {"challenger": humans, "challenged": bots},
			"challengerGuild": {"name": "Humans"}, "challengedGuild": {"name": "Trainers [BOT]"}}}

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
	else:
		print("PASS ", label)

func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://clash-bot-review/%s.png" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://clash-bot-review"))
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "Rendered review image saved")
	print("CLASH_BOT_REVIEW_IMAGE=", ProjectSettings.globalize_path(path))
