extends Node

# Only visual state is coalesced. WorldPresenceService keeps the authoritative
# roster and its revisions synchronously; gameplay/recovery messages never use
# this queue. Run after the realtime autoloads have polled their sockets.
signal player_state_ready(state: Dictionary)
signal player_removal_ready(user_id: int)
signal batch_processed

const PROCESS_BUDGET_USEC := 2000
const MAX_UPDATES_PER_FRAME := 32

var pending: Dictionary = {}
var order: Array[int] = []
var cursor := 0


func _init() -> void:
	process_priority = 100
	set_process(false)


func _ready() -> void:
	set_process(not pending.is_empty())


func queue_update(state: Dictionary) -> void:
	var user_id := int(state.get("userId", 0))
	if user_id <= 0:
		return
	_queue(user_id, state.duplicate(true))


func queue_removal(user_id: int) -> void:
	if user_id > 0:
		_queue(user_id, null)


func replace_snapshot(states: Array, existing_user_ids: Array) -> void:
	clear()
	var incoming: Dictionary = {}
	for value: Variant in states:
		if value is Dictionary and int(value.get("userId", 0)) > 0:
			incoming[int(value.userId)] = value
	# Remove existing avatars missing from the replacement before adding new
	# ones. Discarding old pending spawns prevents ghosts after a fresh snapshot.
	for value: Variant in existing_user_ids:
		var user_id := int(value)
		if not incoming.has(user_id):
			queue_removal(user_id)
	for state: Dictionary in incoming.values():
		queue_update(state)


func clear() -> void:
	pending.clear()
	order.clear()
	cursor = 0
	set_process(false)


func _queue(user_id: int, state: Variant) -> void:
	if not pending.has(user_id):
		order.append(user_id)
	pending[user_id] = state
	set_process(true)


func _process(_delta: float) -> void:
	drain()


func drain(budget_usec: int = PROCESS_BUDGET_USEC, limit: int = MAX_UPDATES_PER_FRAME) -> int:
	var deadline := Time.get_ticks_usec() + maxi(budget_usec, 0)
	var processed := 0
	while cursor < order.size() and processed < maxi(limit, 0):
		# A single avatar operation cannot be interrupted halfway. Include its
		# signal callbacks in the budget and stop before starting another one.
		if processed > 0 and Time.get_ticks_usec() >= deadline:
			break
		var user_id := order[cursor]
		cursor += 1
		var state: Variant = pending[user_id]
		pending.erase(user_id)
		processed += 1
		if state is Dictionary:
			player_state_ready.emit(state)
		else:
			player_removal_ready.emit(user_id)
	if cursor == order.size():
		clear()
	elif cursor >= 64:
		order = order.slice(cursor)
		cursor = 0
	if processed > 0:
		batch_processed.emit()
	return processed
