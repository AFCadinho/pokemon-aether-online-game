extends Node

# Disposable harness only. The session arrives on stdin and stays in memory.
# No login, auth persistence, fixture HTTP responses, or production URLs.
const CAPTAIN := preload("res://scenes/npcs/aether_clash_bot_captain_npc.tscn")
const MENU := preload("res://scripts/ui/aether_clash_bot_challenge_menu.gd")
const DUEL := preload("res://scenes/overworld/aether_clash/aether_clash_duel.tscn")
const BATTLE := preload("res://scenes/battle/battle.tscn")
var presence := WebSocketPeer.new()
var battle
var started := false
var result_received := false
var heartbeat := 0.0
var session_id := ""
var watchdog: Timer

class AutomatedCaptain extends "res://scripts/world/npcs/aether_clash_bot_captain_npc.gd":
	var acknowledged := false
	func show_dialogue(_lines: Array[String] = [], _speaker := "") -> bool:
		acknowledged = true
		return true

func _process(delta: float) -> void:
	presence.poll()
	while presence.get_available_packet_count() > 0:
		presence.get_packet() # World payloads are never logged.
	heartbeat += delta
	if heartbeat >= 5.0 and presence.get_ready_state() == WebSocketPeer.STATE_OPEN:
		heartbeat = 0.0
		presence.send_text('{"type":"ping"}')

func _ready() -> void:
	if OS.get_environment("AETHER_CLASH_LIVE_TEST_DISPOSABLE_DB") != "true" or OS.get_environment("POKEAETHER_GATEWAY_URL") != "http://127.0.0.1:8000":
		_fail("ISOLATION_GUARD")
		return
	# Unlike a long-lived SceneTreeTimer, this watchdog belongs to the driver
	# and is destroyed when the completed driver leaves the tree.
	watchdog = Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 300.0
	watchdog.timeout.connect(_fail.bind("LIVE_FLOW_TIMEOUT"))
	add_child(watchdog)
	watchdog.start()
	var parser := JSON.new()
	if parser.parse(OS.read_string_from_stdin()) != OK or not parser.data is Dictionary:
		_fail("FIXTURE_INPUT")
		return
	var fixture: Dictionary = parser.data
	AuthService.session_token = str(fixture.token)
	AuthService.current_user = {"id": fixture.userId, "username": "clashbotlive01"}
	PlayerSave.player_id = str(fixture.userId)
	fixture.clear()
	var party := await PlayerPartyStateService.refresh_party()
	if not party.get("success", false) or PlayerSave.party.size() != 6:
		_fail("PARTY_LOAD")
		return
	var status := presence.connect_to_url(ClientBuild.append_websocket_query("ws://127.0.0.1:8000/ws/world-presence?token=" + AuthService.session_token.uri_encode()))
	if status != OK:
		_fail("PRESENCE_CONNECT")
		return
	while presence.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await get_tree().process_frame
	if presence.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_fail("PRESENCE_OPEN")
		return
	_send_presence("aether_clash_lobby", Vector2(1168, 1360))
	await get_tree().create_timer(1).timeout
	var captain := CAPTAIN.instantiate()
	captain.set_script(AutomatedCaptain)
	add_child(captain)
	captain.interact_with_player(null)
	var menus: Array = []
	while menus.is_empty() and captain.interaction_in_flight:
		await get_tree().process_frame
		menus = captain.get_children().filter(func(n: Node): return n.get_script() == MENU)
	if menus.is_empty() or not menus[0].can_start:
		_fail("NPC_OPTIONS")
		return
	menus[0].bot_count.get_line_edit().text = "10"
	menus[0].dialog.confirmed.emit()
	while captain.interaction_in_flight:
		await get_tree().process_frame
	if not captain.acknowledged:
		_fail("NPC_CHALLENGE")
		return
	print("LIVE_GODOT_STAGE npc_challenge")
	var sessions := await GuildService.load_aether_clash_portal_sessions()
	if not sessions.get("success", false) or sessions.get("sessions", []).size() != 1:
		_fail("PORTAL_SESSIONS")
		return
	session_id = str(sessions.sessions[0].session.id)
	var portal_position := {"mapId": "aether_clash_lobby", "mapScenePath": "res://scenes/overworld/aether_clash/aether_clash_lobby.tscn",
		"position": {"x": 864, "y": 624}, "facingDirection": "up"}
	var walk := await PlayerGameStateService.save_player_position(portal_position)
	if not walk.get("success", false):
		_fail("PORTAL_POSITION")
		return
	_send_presence("aether_clash_lobby", Vector2(864, 624))
	await get_tree().create_timer(1).timeout
	var entry := await GuildService.enter_aether_clash_portal(session_id)
	if not entry.get("success", false) or entry.get("role", "") != "participant":
		_fail("PORTAL_ENTRY")
		return
	var state: Dictionary = entry.state
	var ack := await PlayerGameStateService.acknowledge_player_teleport(int(state.get("teleportRevision", 0)))
	if not ack.get("success", false):
		_fail("PORTAL_TELEPORT_ACK")
		return
	var position: Dictionary = state.position
	_send_presence(str(state.mapId), Vector2(float(position.x), float(position.y)))
	print("LIVE_GODOT_STAGE portal_entry")
	var duel := DUEL.instantiate()
	add_child(duel)
	await get_tree().process_frame
	duel.instance_session_id = session_id
	var arena: Dictionary = {}
	while str(arena.get("session", {}).get("status", "")) != "active":
		arena = await GuildService.load_aether_clash_arena_state(session_id)
		if not arena.get("success", false):
			_fail("ARENA_STATE")
			return
		duel._apply_arena_state(arena)
		await get_tree().create_timer(1).timeout
	if duel.bot_actors.size() != 10:
		_fail("BOT_ACTORS")
		return
	var bot_id: int = duel.bot_actors.keys()[0]
	var anchor: Vector2 = duel.bot_actors[bot_id].global_position
	var human := Node2D.new()
	human.add_to_group("player")
	add_child(human)
	human.global_position = anchor - Vector2(96, 0)
	_send_presence(str(state.mapId), anchor - Vector2(48, 0))
	await get_tree().create_timer(1).timeout
	add_to_group("ui_overlay")
	if not duel.is_world_actor_step_blocked(human.global_position, anchor - Vector2(48, 0)):
		_fail("COLLISION")
		return
	while not started:
		await get_tree().process_frame
	print("LIVE_GODOT_STAGE battle_started")
	# Let the human lead expire, then require the real Turn 1 controls to open
	# after the intro rather than waiting for the 30-second schedule fallback.
	var preview_deadline := Time.get_ticks_msec() + 10000
	while not battle.team_preview_lead_selection_active:
		if Time.get_ticks_msec() >= preview_deadline:
			_fail("AUTO_LEAD_PREVIEW_MISSING")
			return
		await get_tree().process_frame
	var intro_deadline := Time.get_ticks_msec() + 45000
	while battle.team_preview_lead_selection_active or not battle.battle_actions_ready:
		if Time.get_ticks_msec() >= intro_deadline:
			_fail("AUTO_LEAD_INTRO_TIMEOUT")
			return
		await get_tree().process_frame
	var controls_deadline := Time.get_ticks_msec() + 8000
	while battle.battle_input_locked:
		if Time.get_ticks_msec() >= controls_deadline:
			print("LIVE_GODOT_DIAGNOSTIC phase=", battle.pvp_last_phase,
				" next=", battle.pvp_last_next_phase,
				" fence=", not battle.pvp_pending_presentation_fence.is_empty(),
				" scheduleHold=", battle._is_pvp_presentation_hold_active(),
				" scheduleBatch=", battle.pvp_presentation_schedule_source_batch_id != "",
				" renderedSeq=", battle.pvp_event_queue.last_rendered_seq,
				" ackPending=", not battle.pvp_pending_render_ack_completion.is_empty(),
				" ackRetry=", battle.pvp_render_ack_retry_active,
				" phaseRelease=", battle.pvp_last_phase_update_phase)
			_fail("TURN1_MOVES_LOCKED_AFTER_AUTO_LEAD")
			return
		await get_tree().process_frame
	print("LIVE_GODOT_STAGE auto_lead_turn1_controls_ready")
	await battle._on_forfeit_confirmed()
	if not battle.battle_finished:
		_fail("FORFEIT")
		return
	while not result_received:
		await get_tree().process_frame
	# The real client keeps running after Continue. This short-lived driver must
	# let the ordinary terminal party heal/save finish before destroying autoloads
	# and clearing the in-memory session. Never cancel or bypass these requests.
	print("LIVE_GODOT_STAGE party_housekeeping pending=", _pending_party_requests())
	var drain_deadline := Time.get_ticks_msec() + 10000
	while _pending_party_requests() > 0:
		if Time.get_ticks_msec() >= drain_deadline:
			_fail("PARTY_SHUTDOWN_TIMEOUT")
			return
		await get_tree().process_frame
	_cleanup()
	# Match the ordinary overlay's deferred scene teardown before engine shutdown.
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	battle = null
	print("LIVE_GODOT_FLOW_OK npc=true portal=true collision=true battle=true result=true")
	_finish(0)

func _finish(exit_code: int) -> void:
	# Destroy the completed driver, its watchdog and request children before
	# engine shutdown. Use a tree-owned Timer, not a SceneTreeTimer whose
	# timeout signal would still be on the stack when quit starts.
	var tree := get_tree()
	if watchdog != null:
		watchdog.stop()
	var shutdown_timer := Timer.new()
	shutdown_timer.one_shot = true
	shutdown_timer.autostart = true
	shutdown_timer.wait_time = 0.25
	shutdown_timer.timeout.connect(tree.quit.bind(exit_code))
	# The isolation guard can fail while root is still mounting autoloads.
	tree.root.add_child.call_deferred(shutdown_timer)
	queue_free()

func _pending_party_requests() -> int:
	var count := 0
	for service: Node in [PartyHealService, PlayerPartyStateService]:
		for child: Node in service.get_children():
			if child is HTTPRequest:
				count += 1
	return count

func start_aether_clash_pvp_match(match_id: String, _engagement_id: String) -> bool:
	var request := HTTPRequest.new()
	add_child(request)
	var response := await BattleApiClient.start_pvp_match_battle(request, match_id)
	request.queue_free()
	if not response.get("success", false):
		_fail("BATTLE_START")
		return false
	battle = BATTLE.instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.battle_ended.connect(func(_result: Dictionary): result_received = true)
	battle.setup_pvp_battle_from_response(PlayerSave.party[0], response)
	started = true
	return true

func _send_presence(map_id: String, position: Vector2) -> void:
	presence.send_text(JSON.stringify({"type": "position", "mapId": map_id,
		"position": {"x": position.x, "y": position.y}, "activityState": "idle"}))

func _cleanup() -> void:
	presence.close()
	AuthService.session_token = ""
	AuthService.current_user.clear()
	PlayerSave.party.clear()

func _fail(code: String) -> void:
	print("LIVE_GODOT_FAILURE code=", code)
	_cleanup()
	_finish(1)
