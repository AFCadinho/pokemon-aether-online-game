extends RefCounted

class_name BattleMessageTiming

const MOVE_ANIMATION_HOLD_SECONDS := 0.12
const DAMAGE_ANIMATION_HOLD_SECONDS := 0.08
const STAT_CHANGE_ANIMATION_HOLD_SECONDS := 0.25

const DEFAULT_MESSAGE_HOLD_SECONDS := 0.32
const MOVE_MESSAGE_HOLD_SECONDS := 0.20
const SWITCH_MESSAGE_HOLD_SECONDS := 0.32
const RESULT_MESSAGE_HOLD_SECONDS := 0.55
const EFFECT_MESSAGE_HOLD_SECONDS := 0.32
const HEAL_MESSAGE_HOLD_SECONDS := 0.35
const MEGA_MESSAGE_HOLD_SECONDS := 0.60
const RESIDUAL_MESSAGE_HOLD_SECONDS := 0.18


func get_move_animation_hold_seconds() -> float:
	return MOVE_ANIMATION_HOLD_SECONDS


func get_damage_animation_hold_seconds() -> float:
	return DAMAGE_ANIMATION_HOLD_SECONDS


func get_stat_change_animation_hold_seconds() -> float:
	return STAT_CHANGE_ANIMATION_HOLD_SECONDS


func get_battle_message_hold_seconds(event: Dictionary, battle_message: String) -> float:
	if battle_message == "":
		return 0.0

	if _is_low_impact_residual_event(event):
		return RESIDUAL_MESSAGE_HOLD_SECONDS

	match str(event.get("type", "")):
		"move":
			return MOVE_MESSAGE_HOLD_SECONDS
		"switch", "drag":
			return SWITCH_MESSAGE_HOLD_SECONDS
		"heal":
			return HEAL_MESSAGE_HOLD_SECONDS
		"mega", "primal", "zPower":
			return MEGA_MESSAGE_HOLD_SECONDS
		"fieldEffect", "pokemonEffect", "ability", "statChange", "status", "fail", "cant", "miss", "effectiveness", "hitCount", "criticalHit":
			return EFFECT_MESSAGE_HOLD_SECONDS
		"win":
			return RESULT_MESSAGE_HOLD_SECONDS

	return DEFAULT_MESSAGE_HOLD_SECONDS


func _is_low_impact_residual_event(event: Dictionary) -> bool:
	match str(event.get("type", "")):
		"damage":
			return _is_residual_source(str(event.get("source", "")))
		"heal":
			return _is_residual_source(str(event.get("source", "")))
		"fieldEffect":
			return _is_residual_field_effect(event)
		"pokemonEffect":
			return _is_residual_pokemon_effect(event)

	return false


func _is_residual_field_effect(event: Dictionary) -> bool:
	var state := str(event.get("state", "")).strip_edges().to_lower()
	if state == "upkeep" or state == "end":
		return true

	return _is_residual_source(str(event.get("effect", "")))


func _is_residual_pokemon_effect(event: Dictionary) -> bool:
	var state := str(event.get("state", "")).strip_edges().to_lower()
	if state == "activate" or state == "end":
		return _is_residual_source(str(event.get("effect", "")))

	return false


func _is_residual_source(raw_source: String) -> bool:
	var source := _normalize_effect_key(raw_source)
	match source:
		"sandstorm", "hail", "snow", "raindance", "sunnyday", "desolateland", "primordialsea", "deltastream":
			return true
		"brn", "burn", "psn", "poison", "tox", "toxic":
			return true
		"leftovers", "blacksludge", "grassyterrain", "aquaring", "ingrain", "leechseed":
			return true
		"stealthrock", "spikes", "toxicspikes", "stickyweb":
			return true
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return true
		"electricterrain", "mistyterrain", "psychicterrain", "trickroom", "tailwind", "reflect", "lightscreen", "auroraveil":
			return true

	return false


func _normalize_effect_key(value: String) -> String:
	var cleaned := value.strip_edges().to_lower()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()
	if cleaned.contains(":"):
		cleaned = cleaned.split(":")[-1].strip_edges()

	return cleaned.replace(" ", "").replace("-", "").replace("_", "")
