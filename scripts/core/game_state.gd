extends Node

signal pokemon_level_caps_changed

var player_position: Vector2 = Vector2.ZERO
var has_player_position := false
var player_direction: Vector2 = Vector2.DOWN

var current_map: Node = null
var prepared_world_state: Dictionary = {}

var input_locked := false
var overworld_input_locked := false
var overworld_input_lock_owners: Dictionary = {}
var ui_input_locked := false
var ui_input_lock_owners: Dictionary = {}
var world_debug_enabled := false
var repel_enabled := false
var show_follower := true
var running_shoes_enabled := false
var global_heal_requests_enabled := true
var selected_role_badge := ""
var fishing_skill_unlocked := false
var fishing_unlocked := false
var fishing_tier := 0
var fishing_level := 1
var fishing_total_experience := 0
var fishing_experience_into_level := 0
var fishing_experience_for_next_level := 25
var selected_fishing_rod_item_id := ""
var fishing_region := "kanto"
var fishing_region_badge_count := 0
var fishing_rods: Array = []
var surf_unlocked := true
var pokemon_level_cap := 100
var pokemon_trade_level_cap := 100
var pokemon_level_cap_region := "kanto"
var pokemon_level_cap_stage := ""
var pokemon_level_cap_badge_count := 0
var gameplay_reset_in_progress := false

func apply_pokemon_level_cap_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var previous_state := [
		pokemon_level_cap,
		pokemon_trade_level_cap,
		pokemon_level_cap_region,
		pokemon_level_cap_stage,
		pokemon_level_cap_badge_count,
	]
	pokemon_level_cap = clampi(int(state.get("levelCap", pokemon_level_cap)), 1, 100)
	pokemon_trade_level_cap = clampi(int(state.get("tradeLevelCap", pokemon_trade_level_cap)), 1, 100)
	pokemon_level_cap_region = str(state.get("region", pokemon_level_cap_region))
	pokemon_level_cap_stage = str(state.get("stageId", pokemon_level_cap_stage))
	pokemon_level_cap_badge_count = max(int(state.get("badgeCount", pokemon_level_cap_badge_count)), 0)
	var current_state := [
		pokemon_level_cap,
		pokemon_trade_level_cap,
		pokemon_level_cap_region,
		pokemon_level_cap_stage,
		pokemon_level_cap_badge_count,
	]
	if current_state != previous_state:
		pokemon_level_caps_changed.emit()

func begin_gameplay_reset() -> void:
	gameplay_reset_in_progress = true
	lock_input()

func cancel_gameplay_reset() -> void:
	gameplay_reset_in_progress = false
	unlock_input()

func reset_gameplay_runtime_state() -> void:
	player_position = Vector2.ZERO
	has_player_position = false
	player_direction = Vector2.DOWN
	current_map = null
	prepared_world_state = {}
	repel_enabled = false
	show_follower = true
	running_shoes_enabled = false
	global_heal_requests_enabled = true
	selected_role_badge = ""
	fishing_skill_unlocked = false
	fishing_unlocked = false
	fishing_tier = 0
	fishing_level = 1
	fishing_total_experience = 0
	fishing_experience_into_level = 0
	fishing_experience_for_next_level = 25
	selected_fishing_rod_item_id = ""
	fishing_region = "kanto"
	fishing_region_badge_count = 0
	fishing_rods = []
	surf_unlocked = true
	pokemon_level_cap = 100
	pokemon_trade_level_cap = 100
	pokemon_level_cap_region = "kanto"
	pokemon_level_cap_stage = ""
	pokemon_level_cap_badge_count = 0
	overworld_input_lock_owners.clear()
	ui_input_lock_owners.clear()

func finish_gameplay_reset() -> void:
	gameplay_reset_in_progress = false
	unlock_input()

func lock_input() -> void:
	input_locked = true
	overworld_input_locked = true
	ui_input_locked = true
	
func unlock_input() -> void:
	input_locked = false
	overworld_input_locked = not overworld_input_lock_owners.is_empty()
	ui_input_locked = not ui_input_lock_owners.is_empty()

func clear_world_runtime_state() -> void:
	current_map = null
	prepared_world_state = {}
	overworld_input_lock_owners.clear()
	ui_input_lock_owners.clear()
	if not gameplay_reset_in_progress:
		unlock_input()

func set_prepared_world_state(state: Dictionary) -> void:
	prepared_world_state = state

func consume_prepared_world_state() -> Dictionary:
	var state := prepared_world_state
	prepared_world_state = {}
	return state

func has_prepared_world_state() -> bool:
	return not prepared_world_state.is_empty()

func lock_overworld_input() -> void:
	overworld_input_locked = true

func unlock_overworld_input() -> void:
	overworld_input_locked = not overworld_input_lock_owners.is_empty()

func acquire_overworld_input_lock(owner_id: StringName) -> void:
	if owner_id.is_empty():
		return
	overworld_input_lock_owners[owner_id] = true
	overworld_input_locked = true

func release_overworld_input_lock(owner_id: StringName) -> void:
	if owner_id.is_empty():
		return
	overworld_input_lock_owners.erase(owner_id)
	overworld_input_locked = not overworld_input_lock_owners.is_empty()

func lock_ui_input() -> void:
	ui_input_locked = true

func unlock_ui_input() -> void:
	ui_input_locked = not ui_input_lock_owners.is_empty()

func acquire_ui_input_lock(owner_id: StringName) -> void:
	if owner_id.is_empty():
		return
	ui_input_lock_owners[owner_id] = true
	ui_input_locked = true

func release_ui_input_lock(owner_id: StringName) -> void:
	if owner_id.is_empty():
		return
	ui_input_lock_owners.erase(owner_id)
	ui_input_locked = not ui_input_lock_owners.is_empty()

func is_overworld_input_locked() -> bool:
	return input_locked or overworld_input_locked

func is_ui_input_locked() -> bool:
	return ui_input_locked

func get_world() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var grouped_world := tree.get_first_node_in_group("world")
	if grouped_world != null:
		return grouped_world

	var current_scene := tree.current_scene
	if current_scene != null and current_scene.has_method("load_map"):
		return current_scene

	return null

func reset_world_debug_log() -> void:
	if not world_debug_enabled:
		return

	var file := FileAccess.open("user://world_debug.log", FileAccess.WRITE)
	if file == null:
		return

	file.store_line("world debug started")

func debug_world(message: String) -> void:
	if not world_debug_enabled:
		return

	var full_message := "[world-debug] %s" % message
	print(full_message)

	var file := FileAccess.open("user://world_debug.log", FileAccess.READ_WRITE)
	if file == null:
		return

	file.seek_end()
	file.store_line(full_message)
