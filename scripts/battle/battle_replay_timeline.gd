extends RefCounted

## Versioned presentation data only: never invokes the battle engine or API.
var frames: Array = []
var turn_indices: Dictionary = {}
var _checkpoints: Dictionary = {}

func load_recording(recording: Dictionary) -> bool:
	frames.clear()
	turn_indices.clear()
	_checkpoints.clear()
	if int(recording.get("schemaVersion", 0)) != 1:
		return false
	var values: Variant = recording.get("frames", [])
	if not values is Array or values.is_empty() or values.size() > 1000:
		return false
	var last_seq := -1
	var battle_id := ""
	for value: Variant in values:
		if not value is Dictionary or not value.get("state", {}) is Dictionary or not value.get("events", []) is Array:
			return false
		if battle_id == "":
			battle_id = str(value.get("battleId", ""))
		if battle_id == "" or str(value.get("battleId", "")) != battle_id:
			return false
		for event: Variant in value.get("events", []):
			if not event is Dictionary:
				return false
			var seq := int(event.get("eventSeq", -1))
			if seq < 0 or (last_seq >= 0 and seq != last_seq + 1):
				return false
			last_seq = seq
		var turn := int(value.get("state", {}).get("turn", 0))
		if not turn_indices.has(turn):
			turn_indices[turn] = frames.size()
		frames.append(value)
	return bool((frames.back() as Dictionary).get("state", {}).get("ended", false))

func index_for_turn(turn: int) -> int:
	var found := 0
	for key: int in turn_indices:
		if key <= turn:
			found = int(turn_indices[key])
	return found

func turn_at(index: int) -> int:
	return int((frames[clampi(index, 0, frames.size() - 1)] as Dictionary).get("state", {}).get("turn", 0))

func events_through(index: int) -> Array:
	var events: Array = []
	for i in range(clampi(index + 1, 0, frames.size())):
		events.append_array((frames[i] as Dictionary).get("events", []))
	return events

func state_through(index: int) -> BattleState:
	var state := BattleState.new()
	var start := 0
	for checkpoint: int in _checkpoints:
		if checkpoint <= index and checkpoint + 1 > start:
			start = checkpoint + 1
			state = _copy_state(_checkpoints[checkpoint])
	for i in range(start, clampi(index + 1, 0, frames.size())):
		var frame: Dictionary = (frames[i] as Dictionary).duplicate(true)
		# Terminal projections may no longer carry either side's request. Retain
		# the last known roster, then apply the recorded final damage/faint events.
		var requests: Dictionary = state.requests.duplicate(true)
		for side: String in ["p1", "p2"]:
			var request: Variant = frame.get("requests", {}).get(side, {})
			if request is Dictionary and not request.is_empty():
				requests[side] = request
		frame["requests"] = requests
		state.load_from_api_response(frame, true, -1, true)
		if i % 5 == 0:
			_checkpoints[i] = _copy_state(state)
	return state

func _copy_state(source: BattleState) -> BattleState:
	var result := BattleState.new()
	for property: Dictionary in source.get_script().get_script_property_list():
		var key := str(property.get("name", ""))
		var value: Variant = source.get(key)
		if value is Dictionary or value is Array:
			result.set(key, value.duplicate(true))
		elif typeof(value) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
			result.set(key, value)
	return result
