extends RefCounted
## Presentation-independent event selection. A visual/audio driver owns the
## frame clock and playback; this module does not load textures or play sounds.
## Keep legacy duplicate keys, custom overrides, order, volume and pitch intact.

static func compile(data: Dictionary, config: Dictionary = {}) -> Dictionary:
	var fps: Variant = data.get("fps", 20)
	var frames: Variant = data.get("frames")
	if not (fps is int or fps is float) or not is_finite(float(fps)) or float(fps) <= 0 or not frames is Array or frames.is_empty():
		return {}
	var start := clampi(int(config.get("animation_start_frame", 0)), 0, frames.size() - 1)
	var end := int(config.get("animation_end_frame", -1))
	end = frames.size() - 1 if end < 0 else maxi(start, mini(end, frames.size() - 1))
	var played := {}
	var cues: Array[Dictionary] = []
	for frame in range(start, end + 1):
		for event in take_frame(data.get("timings", []), config.get("custom_sound_events", []), frame, bool(config.get("disable_data_sound_events", false)), played):
			cues.append({"at_seconds": (frame - start) / float(fps), "event": event})
	# One source-frame interval is displayed even for a single-frame animation.
	return {"duration_seconds": (end - start + 1) / float(fps), "cues": cues}

static func take_frame(timings: Array, custom: Array, index: int, disable_data: bool, played: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in timings:
		if not value is Dictionary:
			continue
		var event: Dictionary = value
		if int(event.get("type", -1)) != 0 or int(event.get("frame", -1)) != index:
			continue
		var key := "%s:%s:%s" % [event.frame, event.type, event.get("name", "")]
		if played.has(key):
			continue
		played[key] = true
		if not disable_data:
			result.append(event.duplicate(true))
	for value: Variant in custom:
		if not value is Dictionary or int(value.get("frame", -1)) != index:
			continue
		var name := str(value.get("name", "")).strip_edges()
		var key := "custom:%s:%s" % [index, name]
		if name.is_empty() or played.has(key):
			continue
		played[key] = true
		result.append({"name": name, "volume": float(value.get("volume", 100.0)), "pitch": float(value.get("pitch", 100.0))})
	return result
