extends RefCounted

class_name BattleVoiceTiming

const MOVE_BASE_SECONDS := 0.40
const MOVE_MAX_SECONDS := 0.62
const DODGE_SECONDS := 0.70
const SWITCH_BASE_SECONDS := 0.45
const SWITCH_MAX_SECONDS := 0.80
const LONG_TEXT_THRESHOLD := 32
const EXTRA_SECONDS_PER_CHARACTER := 0.012


static func get_minimum_read_seconds(command_kind: String, message: String) -> float:
	var normalized_kind := command_kind.strip_edges().to_lower()
	if normalized_kind == "dodge":
		return DODGE_SECONDS

	var base_seconds := SWITCH_BASE_SECONDS if normalized_kind == "switch" else MOVE_BASE_SECONDS
	var max_seconds := SWITCH_MAX_SECONDS if normalized_kind == "switch" else MOVE_MAX_SECONDS
	var extra_characters := maxi(message.strip_edges().length() - LONG_TEXT_THRESHOLD, 0)
	return clampf(
		base_seconds + float(extra_characters) * EXTRA_SECONDS_PER_CHARACTER,
		base_seconds,
		max_seconds
	)
