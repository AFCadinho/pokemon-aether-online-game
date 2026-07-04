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


func get_move_animation_hold_seconds() -> float:
	return MOVE_ANIMATION_HOLD_SECONDS


func get_damage_animation_hold_seconds() -> float:
	return DAMAGE_ANIMATION_HOLD_SECONDS


func get_stat_change_animation_hold_seconds() -> float:
	return STAT_CHANGE_ANIMATION_HOLD_SECONDS


func get_battle_message_hold_seconds(event: Dictionary, battle_message: String) -> float:
	if battle_message == "":
		return 0.0

	match str(event.get("type", "")):
		"move":
			return MOVE_MESSAGE_HOLD_SECONDS
		"switch", "drag":
			return SWITCH_MESSAGE_HOLD_SECONDS
		"heal":
			return HEAL_MESSAGE_HOLD_SECONDS
		"mega", "primal":
			return MEGA_MESSAGE_HOLD_SECONDS
		"fieldEffect", "pokemonEffect", "ability", "statChange", "status", "fail", "cant", "miss", "effectiveness", "hitCount", "criticalHit":
			return EFFECT_MESSAGE_HOLD_SECONDS
		"win":
			return RESULT_MESSAGE_HOLD_SECONDS

	return DEFAULT_MESSAGE_HOLD_SECONDS
