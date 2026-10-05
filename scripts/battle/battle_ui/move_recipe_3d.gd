extends RefCounted
## Individually tunable first-pass recipes, separate from the approved renderers.
const DATA = preload("res://data/battle_move_recipes_3d.json")

static func key(move: String) -> String:
	return move.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(",", "").replace("'", "").replace("’", "").replace(".", "")

static func get_recipe(move: String) -> Dictionary:
	return DATA.data.moves.get(key(move), {})

static func supports(move: String) -> bool:
	return DATA.data.moves.has(key(move))

static func contact(move: String) -> bool:
	return bool(get_recipe(move).get("contact", false))

static func audio_plan(timing: Dictionary) -> Dictionary:
	var recipe := get_recipe(str(timing.get("move_key", "")))
	if recipe.is_empty() or timing.is_empty(): return {}
	var duration := float(timing.frames) / 60.0
	var impact := float(timing.impact_frame) / 60.0
	var launch := float(timing.launch_frame) / 60.0
	var cues: Array = []
	var paths := {}
	for value: Dictionary in recipe.audio:
		var role := str(value.role)
		var at := impact if role == "impact" else (duration * 0.08 if role == "cast" else launch)
		var end := minf(duration, at + duration * (0.28 if role == "impact" else 0.48))
		var event := {"name":value.name,"volume":value.volume,"pitch":value.pitch,
			"requires_hit":role == "impact","role":role,"end_seconds":end,"fade_seconds":duration*0.055}
		cues.append({"at_seconds":at,"event":event})
		paths[value.name] = value.path
	cues.sort_custom(func(a,b):return a.at_seconds<b.at_seconds)
	return {"cues":cues,"sound_paths":paths,"duration_seconds":duration,"speed_scale":1.0,"bounded_to_action":true}
