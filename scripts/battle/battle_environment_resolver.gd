extends RefCounted

class_name BattleEnvironmentResolver

const Catalog := preload("res://scripts/battle/battle_environment_catalog.gd")

const WATER_ENCOUNTER_TYPES := {
	"surf": true,
	"fish": true,
	"fishing": true,
	"old_rod": true,
	"good_rod": true,
	"super_rod": true,
}


static func resolve(context: Dictionary) -> StringName:
	var explicit_id := _known_environment_id(context.get("explicit_environment_id", ""))
	if explicit_id != &"":
		return explicit_id

	var battle_kind := str(context.get("battle_kind", "")).strip_edges().to_lower()
	if battle_kind == "pvp":
		return Catalog.PVP_STADIUM_ENVIRONMENT_ID
	if battle_kind == "wild" and str(context.get("map_id", "")).strip_edges() == "aether_clash_lobby":
		return Catalog.PVP_STADIUM_ENVIRONMENT_ID

	if battle_kind == "wild":
		var encounter_type := _normalize_key(context.get("encounter_type", ""))
		if WATER_ENCOUNTER_TYPES.has(encounter_type) or bool(context.get("player_on_water", false)):
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_22":
				return &"route_22_water"
			return Catalog.WATER_ENVIRONMENT_ID

	# Route-specific scenery follows the battle location, including story rivals.
	# Explicit overrides, PvP and water encounters above retain their priority.
	if battle_kind in ["wild", "trainer"] and str(context.get("map_id", "")).strip_edges() == "kanto_route_22":
		return &"route_22"

	if battle_kind == "wild":
		if bool(context.get("player_on_tall_grass", false)):
			return Catalog.DEFAULT_ENVIRONMENT_ID

	var map_environment_id := _known_environment_id(context.get("map_environment_id", ""))
	if map_environment_id != &"":
		return map_environment_id

	return Catalog.DEFAULT_ENVIRONMENT_ID


static func _known_environment_id(value: Variant) -> StringName:
	var normalized_id := StringName(_normalize_key(value))
	return normalized_id if Catalog.has_profile(normalized_id) else &""


static func _normalize_key(value: Variant) -> String:
	return str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
