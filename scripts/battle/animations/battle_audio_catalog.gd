extends RefCounted
## Reads shared timing/audio metadata only. Never requests sheet/background resources.
const Timeline = preload("res://scripts/battle/animations/battle_sound_timeline.gd")
var catalogs := {}
var plans := {}

func get_plan(kind: String, key: String) -> Dictionary:
	var cache_key := kind + ":" + key
	if plans.has(cache_key):
		return plans[cache_key]
	if kind not in ["move", "effect"]:
		return {}
	if not catalogs.has(kind):
		var path := "res://data/battle_move_animations.json" if kind == "move" else "res://data/battle_effect_animations.json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		catalogs[kind] = parsed if parsed is Dictionary else {}
	var catalog: Dictionary = catalogs[kind]
	var resolved := str(catalog.get("aliases", {}).get(key, key))
	var config: Dictionary = catalog.get("moves" if kind == "move" else "effects", {}).get(resolved, {})
	var path := str(config.get("data_path", ""))
	if not FileAccess.file_exists(path):
		plans[cache_key] = {}
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return {}
	var plan := Timeline.compile(data, config)
	if not plan.is_empty():
		plan.sound_paths = config.get("sound_paths", {}).duplicate(true)
		plan.speed_scale = float(config.get("speed_scale", 1.0))
		if not is_finite(plan.speed_scale) or plan.speed_scale <= 0:
			return {}
	plans[cache_key] = plan
	return plan
