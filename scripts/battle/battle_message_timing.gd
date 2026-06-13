extends RefCounted

class_name BattleMessageTiming

const MOVE_ANIMATION_HOLD_SECONDS := 0.35
const DAMAGE_ANIMATION_HOLD_SECONDS := 0.25
const STAT_CHANGE_ANIMATION_HOLD_SECONDS := 0.85

const DEFAULT_MESSAGE_HOLD_SECONDS := 0.70
const MOVE_MESSAGE_HOLD_SECONDS := 0.45
const SWITCH_MESSAGE_HOLD_SECONDS := 0.75
const RESULT_MESSAGE_HOLD_SECONDS := 0.90
const EFFECT_MESSAGE_HOLD_SECONDS := 0.85
const HEAL_MESSAGE_HOLD_SECONDS := 0.90


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
		"switch":
			return SWITCH_MESSAGE_HOLD_SECONDS
		"heal":
			return HEAL_MESSAGE_HOLD_SECONDS
		"fieldEffect", "pokemonEffect", "ability", "statChange", "status", "fail", "cant", "miss", "effectiveness", "hitCount":
			return EFFECT_MESSAGE_HOLD_SECONDS
		"win":
			return RESULT_MESSAGE_HOLD_SECONDS

	return DEFAULT_MESSAGE_HOLD_SECONDS
