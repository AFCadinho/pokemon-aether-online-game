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

	# Ships and indoor gyms retain their arena even for a water encounter. Explicit/PvP wins.
	if battle_kind in ["wild", "trainer"]:
		match str(context.get("map_id", "")).strip_edges():
			"kanto_ss_anne_b1f", "kanto_ss_anne_1f", "kanto_ss_anne_2f", "kanto_ss_anne_3f": return &"ss_anne"
			"kanto_pewter_city_gym": return &"pewter_city_gym"
			"kanto_cerulean_city_gym": return &"cerulean_city_gym"

	if battle_kind == "wild":
		var encounter_type := _normalize_key(context.get("encounter_type", ""))
		if WATER_ENCOUNTER_TYPES.has(encounter_type) or bool(context.get("player_on_water", false)):
			if str(context.get("map_id", "")).strip_edges() == "kanto_pallet_town":
				return &"pallet_town_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_viridian_city":
				return &"viridian_city_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_1":
				return &"route_1_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_22":
				return &"route_22_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_2":
				return &"route_2_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_4":
				return &"route_4_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_cerulean_city":
				return &"cerulean_city_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_24":
				return &"route_24_water"
			if str(context.get("map_id", "")).strip_edges() == "kanto_route_25":
				return &"route_25_water"
			return Catalog.WATER_ENVIRONMENT_ID

	# Route-specific scenery follows the battle location, including story rivals.
	# Explicit overrides, PvP and water encounters above retain their priority.
	if battle_kind in ["wild", "trainer"]:
		var map_id := str(context.get("map_id", "")).strip_edges()
		if map_id == "kanto_pallet_town":
			return &"pallet_town"
		if map_id == "kanto_viridian_city":
			return &"viridian_city"
		if map_id == "kanto_pewter_city":
			return &"pewter_city"
		if map_id == "kanto_route_1":
			return &"route_1"
		if map_id == "kanto_route_22":
			return &"route_22"
		if map_id == "kanto_route_2":
			return &"route_2"
		if map_id == "kanto_route_4":
			return &"route_4"
		if map_id == "kanto_cerulean_city":
			return &"cerulean_city"
		if map_id == "kanto_route_24":
			return &"route_24"
		if map_id == "kanto_route_25":
			return &"route_25"
		if map_id == "kanto_route_3":
			return &"route_3"

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
