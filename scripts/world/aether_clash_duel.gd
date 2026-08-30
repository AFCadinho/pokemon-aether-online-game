extends "res://scripts/world/map_metadata.gd"


signal arena_state_changed(state: Dictionary)

const INSTANCE_MAP_PREFIX := "aether_clash_duel:"
const ARENA_STATE_REFRESH_SECONDS := 1.0
const START_BARRIER_HALF_HEIGHT := 24.0

# Keep these references untyped: this map can be hot-loaded before Godot has
# refreshed its global class cache for the newly added child scripts.
@onready var start_barrier = $StartBarrier
@onready var arena_hud = $ArenaHud

var instance_session_id := ""
var arena_session: Dictionary = {}
var arena_state_request_active := false
var has_received_arena_state := false
var arena_state_timer: Timer


func _ready() -> void:
	add_to_group("aether_clash_duel_controller")
	arena_state_timer = Timer.new()
	arena_state_timer.name = "ArenaStateRefreshTimer"
	arena_state_timer.wait_time = ARENA_STATE_REFRESH_SECONDS
	arena_state_timer.timeout.connect(_refresh_arena_state)
	add_child(arena_state_timer)
	# The canonical scene is also used as a staff preview. Runtime state is only
	# enabled after world.gd assigns an isolated aether_clash_duel:<session> id.
	arena_hud.visible = false
	start_barrier.set_barrier_raised(false, false)


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
	start_barrier.set_barrier_raised(barrier_should_be_raised, animate_lowering)
	arena_hud.apply_arena_state(payload)
	has_received_arena_state = true
	arena_state_changed.emit(payload.duplicate(true))


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
