extends "res://scripts/world/map_metadata.gd"


signal arena_state_changed(state: Dictionary)
signal engagement_contact_requested(source_user_id: int, target_user_id: int, method: String)

const INSTANCE_MAP_PREFIX := "aether_clash_duel:"
const ARENA_STATE_REFRESH_SECONDS := 1.0
const START_BARRIER_HALF_HEIGHT := 24.0
const ENGAGEMENT_RING_SCRIPT: Script = preload("res://scripts/world/aether_clash_engagement_ring.gd")
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const ENGAGEMENT_RADIUS := 28.0
const ENGAGEMENT_CONTACT_DISTANCE := ENGAGEMENT_RADIUS * 2.0
const ENGAGEMENT_SYNC_SECONDS := 0.1
const ENGAGEMENT_CONTACT_COOLDOWN_MSEC := 750
const STAGING_EJECTION_GRACE_MSEC := 2000
const LEAVE_DIALOG_INPUT_OWNER: StringName = &"aether_clash_leave_dialog"

# Keep these references untyped: this map can be hot-loaded before Godot has
# refreshed its global class cache for the newly added child scripts.
@onready var start_barrier = $StartBarrier
@onready var arena_hud = $ArenaHud
@onready var arena_zones = $ArenaZones

var instance_session_id := ""
var arena_session: Dictionary = {}
var arena_state_request_active := false
var has_received_arena_state := false
var arena_state_timer: Timer
var viewer_role := "spectator"
var viewer_side := ""
var arena_players: Dictionary = {}
var engaged_player_ids: Dictionary = {}
var engagement_requests_in_flight: Dictionary = {}
var engagement_sync_elapsed := 0.0
var last_engagement_contact_msec: Dictionary = {}
var staging_ejection_deadline_msec := 0
var leave_confirmation = null
var leave_request_active := false


func _ready() -> void:
	add_to_group("aether_clash_duel_controller")
	engagement_contact_requested.connect(_on_engagement_contact_requested)
	if not ChatRealtimeService.message_received.is_connected(_on_realtime_message_received):
		ChatRealtimeService.message_received.connect(_on_realtime_message_received)
	arena_state_timer = Timer.new()
	arena_state_timer.name = "ArenaStateRefreshTimer"
	arena_state_timer.wait_time = ARENA_STATE_REFRESH_SECONDS
	arena_state_timer.timeout.connect(_refresh_arena_state)
	add_child(arena_state_timer)
	# The canonical scene is also used as a staff preview. Runtime state is only
	# enabled after world.gd assigns an isolated aether_clash_duel:<session> id.
	arena_hud.visible = false
	start_barrier.set_barrier_raised(false, false)
	arena_zones.set_phase("entry_open")


func _process(delta: float) -> void:
	engagement_sync_elapsed += delta
	if engagement_sync_elapsed >= ENGAGEMENT_SYNC_SECONDS:
		engagement_sync_elapsed = 0.0
		_sync_engagement_rings()
	_process_staging_ejection()


func _exit_tree() -> void:
	_clear_engagement_rings()
	GameState.release_overworld_input_lock(LEAVE_DIALOG_INPUT_OWNER)
	_free_leave_confirmation()


func configure_aether_clash_instance(instance_map_id: String) -> void:
	var normalized_id := instance_map_id.strip_edges()
	if not normalized_id.begins_with(INSTANCE_MAP_PREFIX):
		return
	var session_id := normalized_id.trim_prefix(INSTANCE_MAP_PREFIX).strip_edges()
	if session_id.is_empty():
		return
	map_id = normalized_id
	location_id = normalized_id
	instance_session_id = session_id
	arena_session.clear()
	arena_players.clear()
	engaged_player_ids.clear()
	engagement_requests_in_flight.clear()
	viewer_role = "spectator"
	viewer_side = ""
	has_received_arena_state = false
	arena_hud.show_syncing()
	start_barrier.set_barrier_raised(true, false)
	arena_state_timer.start()
	_refresh_arena_state.call_deferred()


func is_clash_active() -> bool:
	return str(arena_session.get("status", "")) in ["roster_locked", "active", "finishing"]


func can_launch_projectile() -> bool:
	return is_clash_active() and not start_barrier.is_barrier_raised()


func is_world_barrier_step_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	if not start_barrier.is_barrier_raised():
		return false
	if is_equal_approx(from_position.y, to_position.y):
		return false
	var barrier_y: float = float(start_barrier.global_position.y)
	var from_distance: float = absf(from_position.y - barrier_y)
	var to_distance: float = absf(to_position.y - barrier_y)
	if from_distance <= START_BARRIER_HALF_HEIGHT:
		# A player already touching the barrier may back away, but cannot pass
		# through to the equally close tile on the other side.
		return to_distance <= from_distance
	var crosses_center: bool = (
		(from_position.y < barrier_y and to_position.y > barrier_y)
		or (from_position.y > barrier_y and to_position.y < barrier_y)
	)
	return crosses_center or to_distance <= START_BARRIER_HALF_HEIGHT


func is_world_actor_step_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	if not is_clash_active() or not _is_local_active_participant():
		return false

	for exit_side: String in ["blue", "red"]:
		if _enters_rect(from_position, to_position, _zone_rect(exit_side)):
			_request_leave_confirmation.call_deferred()
			return true

	var local_user_id := _local_user_id()
	for user_id_value: Variant in arena_players.keys():
		var user_id := int(user_id_value)
		if user_id == local_user_id:
			continue
		var actor := _actor_for_user_id(user_id)
		if actor == null:
			continue
		var actor_position := (actor as Node2D).global_position
		var from_distance := from_position.distance_to(actor_position)
		var to_distance := to_position.distance_to(actor_position)
		if to_distance > ENGAGEMENT_CONTACT_DISTANCE:
			continue
		# Let overlapping players back away instead of permanently pinning them.
		if from_distance <= ENGAGEMENT_CONTACT_DISTANCE and to_distance > from_distance:
			continue
		var other_side := str(arena_players.get(user_id, ""))
		if (
			other_side != viewer_side
			and not engaged_player_ids.has(local_user_id)
			and not engaged_player_ids.has(user_id)
		):
			_emit_engagement_contact(local_user_id, user_id, "player_contact")
		return true
	return false


func request_projectile_engagement(
	from_position: Vector2,
	to_position: Vector2,
	source_user_id: int
) -> int:
	if not is_clash_active() or not arena_players.has(source_user_id):
		return 0
	var source_side := str(arena_players.get(source_user_id, ""))
	var nearest_user_id := 0
	var nearest_progress := INF
	for user_id_value: Variant in arena_players.keys():
		var user_id := int(user_id_value)
		if (
			user_id == source_user_id
			or str(arena_players.get(user_id, "")) == source_side
			or engaged_player_ids.has(source_user_id)
			or engaged_player_ids.has(user_id)
		):
			continue
		var actor := _actor_for_user_id(user_id)
		if actor == null:
			continue
		var hit_progress := _segment_circle_hit_progress(
			from_position,
			to_position,
			(actor as Node2D).global_position,
			ENGAGEMENT_RADIUS
		)
		if hit_progress >= 0.0 and hit_progress < nearest_progress:
			nearest_progress = hit_progress
			nearest_user_id = user_id
	if nearest_user_id > 0:
		_emit_engagement_contact(source_user_id, nearest_user_id, "projectile")
	return nearest_user_id


func _refresh_arena_state() -> void:
	if arena_state_request_active or instance_session_id.is_empty():
		return
	arena_state_request_active = true
	var result: Dictionary = await GuildService.load_aether_clash_arena_state(instance_session_id)
	arena_state_request_active = false
	if instance_session_id.is_empty() or not bool(result.get("success", false)):
		return
	_apply_arena_state(result)


func _apply_arena_state(payload: Dictionary) -> void:
	var next_session := _dictionary(payload.get("session", {})).duplicate(true)
	if next_session.is_empty():
		return
	var previous_status := str(arena_session.get("status", ""))
	var next_status := str(next_session.get("status", ""))
	var barrier_should_be_raised := next_status == "entry_open"
	var animate_lowering := (
		has_received_arena_state
		and previous_status == "entry_open"
		and not barrier_should_be_raised
	)
	arena_session = next_session
	viewer_role = str(payload.get("viewerRole", "spectator"))
	viewer_side = str(payload.get("viewerSide", ""))
	_apply_arena_players(payload.get("arenaPlayers", []))
	start_barrier.set_barrier_raised(barrier_should_be_raised, animate_lowering)
	arena_zones.set_phase(next_status)
	arena_hud.apply_arena_state(payload)
	has_received_arena_state = true
	if next_status in ["roster_locked", "active", "finishing"] and previous_status not in ["roster_locked", "active", "finishing"]:
		staging_ejection_deadline_msec = Time.get_ticks_msec() + STAGING_EJECTION_GRACE_MSEC
	_sync_engagement_rings()
	arena_state_changed.emit(payload.duplicate(true))


func _apply_arena_players(value: Variant) -> void:
	arena_players.clear()
	engaged_player_ids.clear()
	if not value is Array:
		return
	var resumable_engagement: Dictionary = {}
	for player_value: Variant in value:
		if not player_value is Dictionary:
			continue
		var player_state := player_value as Dictionary
		var user_id := int(player_state.get("userId", 0))
		var side := str(player_state.get("side", ""))
		if user_id > 0 and side in ["blue", "red"]:
			arena_players[user_id] = side
			var engagement_value: Variant = player_state.get("engagementId")
			var engagement_id := str(engagement_value).strip_edges() if engagement_value != null else ""
			if not engagement_id.is_empty():
				engaged_player_ids[user_id] = engagement_id
				var match_value: Variant = player_state.get("engagementMatchId")
				var match_id := str(match_value).strip_edges() if match_value != null else ""
				if user_id == _local_user_id() and not match_id.is_empty():
					resumable_engagement = {
						"id": engagement_id,
						"matchId": match_id,
						"sourceUserId": user_id,
					}
	if not resumable_engagement.is_empty():
		_begin_engagement_battle.call_deferred(resumable_engagement)


func _sync_engagement_rings() -> void:
	var active_phase := is_clash_active()
	for actor_value: Variant in _all_player_actors():
		var actor := actor_value as Node2D
		if actor == null:
			continue
		var user_id := _actor_user_id(actor)
		var should_show := active_phase and arena_players.has(user_id)
		var ring := actor.get_node_or_null("AetherClashEngagementRing")
		if not should_show:
			if ring != null:
				ring.queue_free()
			continue
		if ring == null:
			var ring_value: Variant = ENGAGEMENT_RING_SCRIPT.new()
			if not ring_value is Node2D:
				continue
			ring = ring_value as Node2D
			ring.name = "AetherClashEngagementRing"
			actor.add_child(ring)
		ring.set_meta("aether_clash_controller_id", get_instance_id())
		if ring.has_method("configure"):
			ring.call("configure", str(arena_players.get(user_id, "blue")))


func _clear_engagement_rings() -> void:
	var controller_id := get_instance_id()
	for actor_value: Variant in _all_player_actors():
		var actor := actor_value as Node2D
		if actor == null:
			continue
		var ring := actor.get_node_or_null("AetherClashEngagementRing")
		if ring == null:
			continue
		if int(ring.get_meta("aether_clash_controller_id", 0)) == controller_id:
			ring.queue_free()


func _all_player_actors() -> Array[Node2D]:
	var actors: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			actors.append(node as Node2D)
	for node: Node in get_tree().get_nodes_in_group("remote_player_avatar"):
		if node is Node2D:
			actors.append(node as Node2D)
	return actors


func _actor_for_user_id(user_id: int) -> Node2D:
	if user_id <= 0:
		return null
	if user_id == _local_user_id():
		for node: Node in get_tree().get_nodes_in_group("player"):
			if node is Node2D:
				return node as Node2D
	for node: Node in get_tree().get_nodes_in_group("remote_player_avatar"):
		if node is Node2D and int(node.get("user_id")) == user_id:
			return node as Node2D
	return null


func _actor_user_id(actor: Node) -> int:
	if actor.is_in_group("player"):
		return _local_user_id()
	var value: Variant = actor.get("user_id")
	return int(value) if value != null else 0


func _local_user_id() -> int:
	return int(str(PlayerSave.player_id).strip_edges())


func _is_local_active_participant() -> bool:
	var local_user_id := _local_user_id()
	return (
		viewer_role == "participant"
		and viewer_side in ["blue", "red"]
		and local_user_id > 0
		and arena_players.has(local_user_id)
	)


func _zone_rect(side: String) -> Rect2:
	if arena_zones != null and arena_zones.has_method("get_zone_rect"):
		var value: Variant = arena_zones.call("get_zone_rect", side)
		if value is Rect2:
			return value as Rect2
	return Rect2()


func _enters_rect(from_position: Vector2, to_position: Vector2, rect: Rect2) -> bool:
	return rect.size != Vector2.ZERO and not rect.has_point(from_position) and rect.has_point(to_position)


func _process_staging_ejection() -> void:
	if staging_ejection_deadline_msec <= 0 or Time.get_ticks_msec() < staging_ejection_deadline_msec:
		return
	staging_ejection_deadline_msec = 0
	if not _is_local_active_participant():
		return
	var player := _actor_for_user_id(_local_user_id())
	var zone := _zone_rect(viewer_side)
	if player == null or not zone.has_point(player.global_position):
		return
	if not arena_zones.has_method("get_arena_exit_point") or not player.has_method("teleport_within_current_map"):
		return
	var exit_point: Vector2 = arena_zones.call("get_arena_exit_point", viewer_side)
	var facing := Vector2.DOWN if viewer_side == "blue" else Vector2.UP
	player.call("teleport_within_current_map", exit_point, facing)


func _request_leave_confirmation() -> void:
	if leave_request_active or leave_confirmation != null or not _is_local_active_participant():
		return
	var dialog := AETHER_CONFIRMATION_DIALOG_SCENE.instantiate()
	if dialog == null:
		return
	leave_confirmation = dialog
	dialog.name = "AetherClashLeaveConfirmation"
	# Keep arena confirmations in the HUD canvas. A world-space parent can place
	# an otherwise visible Control behind the map while its input lock remains.
	arena_hud.add_child(dialog)
	dialog.configure(
		_text("ui.aether_clash.leave.title", "Leave Aether Clash?"),
		_text("ui.aether_clash.leave.message", "Leaving eliminates you immediately. You cannot return to this Clash."),
		_text("ui.aether_clash.leave.confirm", "Leave Clash"),
		_text("common.cancel", "Cancel")
	)
	dialog.confirmed.connect(_confirm_leave_arena)
	dialog.canceled.connect(_close_leave_confirmation)
	dialog.popup_centered(Vector2i(560, 260))
	GameState.acquire_overworld_input_lock(LEAVE_DIALOG_INPUT_OWNER)


func _confirm_leave_arena() -> void:
	if leave_request_active:
		return
	leave_request_active = true
	_free_leave_confirmation()
	GameState.release_overworld_input_lock(LEAVE_DIALOG_INPUT_OWNER)
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		_leave_failed(_text("ui.aether_clash.leave.unavailable", "Leaving the Clash is unavailable right now."))
		return
	var begin_result: Dictionary = await world.call("begin_authorized_teleport", true, true)
	if not bool(begin_result.get("success", false)):
		_leave_failed(str(begin_result.get("error", "Leaving the Clash is unavailable right now.")))
		return
	var result: Dictionary = await GuildService.leave_aether_clash_arena(instance_session_id)
	if not bool(result.get("success", false)):
		if world.has_method("cancel_authorized_teleport_effect"):
			world.call("cancel_authorized_teleport_effect")
		else:
			world.call("cancel_authorized_teleport")
		_leave_failed(str(result.get("error", "Leaving the Clash failed.")))
		return
	if world.has_method("play_authorized_teleport_departure_effect"):
		await world.call("play_authorized_teleport_departure_effect")
	var apply_result: Dictionary = await world.call("apply_authorized_teleport_state", result.get("state", {}))
	if not bool(apply_result.get("success", false)):
		_show_system_message(str(apply_result.get("error", "The lobby teleport could not be applied.")))
	leave_request_active = false


func _close_leave_confirmation() -> void:
	_free_leave_confirmation()
	GameState.release_overworld_input_lock(LEAVE_DIALOG_INPUT_OWNER)


func _free_leave_confirmation() -> void:
	if leave_confirmation != null and is_instance_valid(leave_confirmation):
		leave_confirmation.queue_free()
	leave_confirmation = null


func _leave_failed(message: String) -> void:
	leave_request_active = false
	_show_system_message(message)


func _show_system_message(message: String) -> void:
	get_tree().call_group("ui_overlay", "add_system_message", message)


func _on_engagement_contact_requested(
	source_user_id: int,
	target_user_id: int,
	method: String
) -> void:
	if (
		instance_session_id.is_empty()
		or source_user_id != _local_user_id()
		or engaged_player_ids.has(source_user_id)
		or engaged_player_ids.has(target_user_id)
	):
		return
	var pair_key := "%d:%d" % [mini(source_user_id, target_user_id), maxi(source_user_id, target_user_id)]
	if engagement_requests_in_flight.has(pair_key):
		return
	engagement_requests_in_flight[pair_key] = true
	var result: Dictionary = await GuildService.create_aether_clash_engagement(
		instance_session_id,
		target_user_id,
		method
	)
	engagement_requests_in_flight.erase(pair_key)
	if not bool(result.get("success", false)):
		_refresh_arena_state.call_deferred()
		var error_code := _response_error_code(result)
		if error_code not in [
			"aether_clash_contact_out_of_range",
			"aether_clash_player_engaged",
			"aether_clash_player_unavailable",
			"aether_clash_player_not_in_arena",
		]:
			_show_system_message(str(result.get("error", "The Aether Clash battle could not start.")))
		return
	await _begin_engagement_battle(result)


func _on_realtime_message_received(message: Dictionary) -> void:
	if str(message.get("type", "")).strip_edges().to_lower() != "aether_clash.engagement.started":
		return
	var engagement := _dictionary(message.get("engagement", {})).duplicate(true)
	if str(engagement.get("sessionId", "")).strip_edges() != instance_session_id:
		return
	await _begin_engagement_battle(engagement)


func _begin_engagement_battle(engagement: Dictionary) -> void:
	var engagement_id := str(engagement.get("id", "")).strip_edges()
	var match_id := str(engagement.get("matchId", "")).strip_edges()
	var source_user_id := int(engagement.get("sourceUserId", 0))
	var target_user_id := int(engagement.get("targetUserId", 0))
	if engagement_id.is_empty() or match_id.is_empty():
		return
	if source_user_id <= 0 and target_user_id <= 0:
		return
	if _local_user_id() not in [source_user_id, target_user_id]:
		return
	if source_user_id > 0:
		engaged_player_ids[source_user_id] = engagement_id
	if target_user_id > 0:
		engaged_player_ids[target_user_id] = engagement_id
	for overlay_value: Variant in get_tree().get_nodes_in_group("ui_overlay"):
		var overlay := overlay_value as Node
		if overlay != null and overlay.has_method("start_aether_clash_pvp_match"):
			await overlay.call("start_aether_clash_pvp_match", match_id, engagement_id)
			return
	_show_system_message("The Aether Clash battle interface is unavailable.")


func _response_error_code(response: Dictionary) -> String:
	var body := _dictionary(response.get("body", {}))
	var detail: Variant = body.get("detail", {})
	if detail is Dictionary:
		return str((detail as Dictionary).get("code", "")).strip_edges().to_lower()
	return str(body.get("code", "")).strip_edges().to_lower()


func _emit_engagement_contact(source_user_id: int, target_user_id: int, method: String) -> void:
	if source_user_id <= 0 or target_user_id <= 0:
		return
	var pair := "%d:%d:%s" % [mini(source_user_id, target_user_id), maxi(source_user_id, target_user_id), method]
	var now := Time.get_ticks_msec()
	if now - int(last_engagement_contact_msec.get(pair, -ENGAGEMENT_CONTACT_COOLDOWN_MSEC)) < ENGAGEMENT_CONTACT_COOLDOWN_MSEC:
		return
	last_engagement_contact_msec[pair] = now
	engagement_contact_requested.emit(source_user_id, target_user_id, method)


func _segment_circle_hit_progress(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return 0.0 if start.distance_to(center) <= radius else -1.0
	var progress := clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest := start + segment * progress
	return progress if closest.distance_to(center) <= radius else -1.0


func _text(key: String, fallback: String) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("text"):
		var translated := str(manager.call("text", key))
		if translated != key:
			return translated
	return fallback


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
