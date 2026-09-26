extends RefCounted
## Baked world-space clearance, sampled using the AnimationPlayer clip clock.
## No animation tracks, sound events, or playback durations are modified.
const Placement = preload("model_placement.gd")
const ACTIONS := ["physical_attack", "physical_attack_2", "special_attack", "damage", "sleep", "faint_start", "faint_loop", "mega_appeal"]

static func resolve(profile: Dictionary, placement: Dictionary, hash: String, timing: Dictionary) -> Dictionary:
	if profile.get("schema") != 1 or not placement.get("calibrated", false) or profile.get("sha256") != hash:
		return {}
	for key in ["scale", "yaw_degrees", "lift"]:
		if not Placement._finite_number(profile.get(key)) or not is_equal_approx(float(profile[key]), float(placement[key])):
			return {}
	var clips: Variant = profile.get("clips")
	if not clips is Dictionary:
		return {}
	for action in clips:
		if action not in ACTIONS or not timing.has(action) or not clips[action] is Dictionary:
			return {}
		var clip: Dictionary = clips[action]
		var duration: Variant = clip.get("duration")
		var samples: Variant = clip.get("offsets")
		if not Placement._finite_number(duration) or duration <= 0 or duration > 120:
			return {}
		if not is_equal_approx(float(duration), float(timing[action].get("frames", 0)) / 60.0):
			return {}
		if not samples is Array or samples.size() != ceili(float(duration) * 60.0) + 1:
			return {}
		if clip.get("intent") != ("grounded_rest" if action == "sleep" else "clearance_only"):
			return {}
		for offset in samples:
			if not Placement._finite_number(offset) or float(offset) < (-float(placement.lift) if action == "sleep" else 0.0):
				return {}
	return clips

static func offset(clips: Dictionary, action: String, time: float) -> float:
	if not clips.has(action) or not is_finite(time):
		return 0.0
	var clip: Dictionary = clips[action]
	var samples: Array = clip.offsets
	var frame := clampf(time, 0.0, float(clip.duration)) * 60.0
	var index := mini(floori(frame), samples.size() - 2)
	var start := index / 60.0
	var end := minf((index + 1) / 60.0, float(clip.duration))
	return lerpf(float(samples[index]), float(samples[index + 1]), clampf((time - start) / (end - start), 0.0, 1.0))

static func advance(current: float, target: float, delta: float) -> float:
	# Raising must never lag behind floor clearance. Lowering is eased, including
	# sleep entry and returning from an attack, without extending the clip.
	return maxf(target, lerpf(current, target, 1.0 - exp(-maxf(delta, 0.0) * 18.0)))
