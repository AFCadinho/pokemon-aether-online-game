extends RefCounted
## Initial pose-reviewed pilot. Frame markers use the native clip clock, not
## sprite frames or wall time. Unreviewed moves retain their existing timeline.
const PILOTS := {
	"pikachu:thunderbolt": {"action": "special_attack", "frames": 120.0, "impact_frame": 48.0,
		"sounds": {"PRSFX- Thunderbolt2.wav": 20.0, "PRSFX- Thunderbolt1.wav": 48.0}},
	"pikachu:tackle": {"action": "physical_attack", "frames": 110.0, "impact_frame": 42.0,
		"sounds": {"PRSFX- Tackle.wav": 42.0}},
	"blastoise:icebeam": {"action": "special_attack", "frames": 407.5, "impact_frame": 120.0,
		"sounds": {"PRSFX- Ice Beam.wav": 120.0}},
}

static func profile(species: String, move: String, action: String, timing: Dictionary) -> Dictionary:
	var key := species.trim_suffix("@shiny") + ":" + move.to_lower().replace(" ", "").replace("-", "")
	var candidate: Dictionary = PILOTS.get(key, {})
	var spec: Dictionary = timing.get(action, {})
	if candidate.is_empty() or candidate.action != action or spec.is_empty():
		return {}
	if not is_equal_approx(float(spec.get("frames", 0)), candidate.frames) or bool(spec.get("loop", false)):
		return {}
	return candidate.duplicate(true)

static func audio_plan(source: Dictionary, pilot: Dictionary) -> Dictionary:
	if source.is_empty() or pilot.is_empty():
		return source
	var result := source.duplicate(true)
	var seen := {}
	var cues: Array[Dictionary] = []
	for cue: Dictionary in source.get("cues", []):
		var name := str(cue.event.get("name", ""))
		if seen.has(name) or not pilot.sounds.has(name):
			continue
		seen[name] = true
		cues.append({"at_seconds": float(pilot.sounds[name]) / 60.0, "event": cue.event.duplicate(true)})
	# Never silently omit an unreviewed source sound after a catalog revision.
	for cue: Dictionary in source.get("cues", []):
		if not pilot.sounds.has(str(cue.event.get("name", ""))):
			return source
	cues.sort_custom(func(a, b): return a.at_seconds < b.at_seconds)
	result.cues = cues
	result.duration_seconds = float(pilot.impact_frame) / 60.0
	result.speed_scale = 1.0
	result.native_clock = true
	return result

static func damage_index(events: Array, move_index: int) -> int:
	if move_index < 0 or move_index >= events.size() or not events[move_index] is Dictionary:
		return -1
	var move: Dictionary = events[move_index]
	var target := str(move.get("target", "")).strip_edges().to_lower()
	if move.get("type") != "move" or target.is_empty() or target == str(move.get("actor", "")).strip_edges().to_lower():
		return -1
	var hit := -1
	for index in range(move_index + 1, events.size()):
		if not events[index] is Dictionary:
			return -1
		var event: Dictionary = events[index]
		var kind := str(event.get("type", ""))
		if kind in ["move", "turn", "switch", "drag", "win"]:
			break
		if kind == "damage" and str(event.get("source", "")).is_empty():
			if hit >= 0: # Multi-hit/spread/recoil need their own reviewed beat.
				return -1
			if str(event.get("target", "")).strip_edges().to_lower() != target:
				return -1
			hit = index
		elif hit < 0 and kind not in ["criticalHit", "effectiveness"]:
			return -1
	return hit
