extends RefCounted
## Logical actions from the event renderer map only to native prepared clips.
## Missing reactions never fall back to an attack or a sprite effect.
const CLIPS := {
	"idle": ["idle"], "sleep": ["sleep"], "damage": ["damage"],
	"physical_attack": ["physical_attack", "special_attack"],
	"physical_attack_2": ["physical_attack_2", "physical_attack", "special_attack"],
	"special_attack": ["special_attack", "physical_attack"],
	"faint_start": ["faint_start"], "faint_loop": ["faint_loop"],
}

static func resolve(action: String, available: PackedStringArray, timing: Dictionary) -> Dictionary:
	for clip: String in CLIPS.get(action, []):
		if clip not in available or not timing.get(clip) is Dictionary:
			continue
		var spec: Dictionary = timing[clip]
		var frames: Variant = spec.get("frames")
		var speed: Variant = spec.get("speed")
		if not _positive_number(frames) or not _positive_number(speed):
			continue
		return {"action": clip, "clip": clip, "duration": float(frames) / 60.0,
			"speed": float(speed), "loop": clip == "faint_loop" or bool(spec.get("loop", false))}
	return {}

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0
