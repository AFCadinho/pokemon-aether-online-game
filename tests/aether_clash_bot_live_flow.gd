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
	get_tree().create_timer(300).timeout.connect(func(): _fail("LIVE_FLOW_TIMEOUT"))
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
	await get_tree().create_timer(55).timeout # No human preview choice.
	await battle._on_forfeit_confirmed()
	if not battle.battle_finished:
		_fail("FORFEIT")
		return
	while not result_received:
		await get_tree().process_frame
	print("LIVE_GODOT_FLOW_OK npc=true portal=true collision=true battle=true result=true")
	_cleanup()
	# Match the ordinary overlay's deferred scene teardown before engine shutdown.
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	battle = null
	get_tree().quit(0)

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
	get_tree().quit(1)
