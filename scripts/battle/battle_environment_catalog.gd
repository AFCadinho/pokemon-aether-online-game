extends RefCounted

class_name BattleEnvironmentCatalog

const DEFAULT_ENVIRONMENT_ID := &"grass"
const PVP_STADIUM_ENVIRONMENT_ID := &"pvp_stadium"

const PROFILES: Dictionary = {
	DEFAULT_ENVIRONMENT_ID: preload("res://resources/battle/environments/grass.tres"),
	PVP_STADIUM_ENVIRONMENT_ID: preload("res://resources/battle/environments/pvp_stadium.tres"),
}


static func get_profile(
	environment_id: StringName,
	fallback_id: StringName = DEFAULT_ENVIRONMENT_ID
) -> BattleEnvironmentProfile:
	var normalized_id := _normalize_environment_id(environment_id)
	if PROFILES.has(normalized_id):
		return PROFILES[normalized_id] as BattleEnvironmentProfile
	var normalized_fallback_id := _normalize_environment_id(fallback_id)
	if PROFILES.has(normalized_fallback_id):
		return PROFILES[normalized_fallback_id] as BattleEnvironmentProfile
	return PROFILES[DEFAULT_ENVIRONMENT_ID] as BattleEnvironmentProfile


static func has_profile(environment_id: StringName) -> bool:
	return PROFILES.has(_normalize_environment_id(environment_id))


static func _normalize_environment_id(environment_id: StringName) -> StringName:
	return StringName(
		str(environment_id).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	)
