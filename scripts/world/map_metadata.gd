extends Node2D

@export var map_id := ""
@export var map_region_name := ""
@export var map_display_name := ""
@export var world_access_group_id := ""
@export var world_access_group_label := ""
@export_enum("exterior", "interior", "route", "wilderness", "transition") var world_access_area_type := "exterior"
@export var location_id := ""
@export var location_name := ""
@export var region_id := ""
@export var encounter_area_id := ""
@export_group("Battle")
@export_enum("grass", "water", "cave") var battle_environment_id := "grass"
@export_group("")
@export_enum("outdoor", "indoor", "dark") var lighting_profile := "outdoor"
@export_enum("outdoor", "disabled") var weather_profile := "outdoor"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.0
# An explicit track ID always wins. Leave this empty for a regular interior
# that should inherit the track associated with its town or city music profile.
@export var music_track_id := ""
@export var music_profile_id := ""


func _ready() -> void:
	if encounter_area_id.strip_edges() != "":
		await _load_encounter_area_metadata()


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	var floor_mask := get_node_or_null("FloorVisibilityMask")
	if floor_mask != null and floor_mask.has_method("get_active_floor_display_name"):
		var floor_display_name := str(floor_mask.call("get_active_floor_display_name")).strip_edges()
		if floor_display_name != "":
			return floor_display_name
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_location_metadata() -> Dictionary:
	return {
		"locationId": location_id if location_id.strip_edges() != "" else map_id,
		"locationName": location_name if location_name.strip_edges() != "" else get_map_display_name(),
		"regionId": region_id if region_id.strip_edges() != "" else map_region_name.to_lower().replace(" ", "_"),
		"regionName": map_region_name,
		"mapId": map_id,
		"battleEnvironmentId": battle_environment_id,
	}


func get_battle_environment_id() -> String:
	return battle_environment_id


func get_music_track_id() -> String:
	return music_track_id


func get_music_profile_id() -> String:
	return music_profile_id


func get_lighting_profile() -> String:
	return lighting_profile


func get_weather_profile() -> String:
	return weather_profile


func get_wild_encounter_area_id() -> String:
	return encounter_area_id


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	if encounter_type != "grass":
		return false

	return randf() <= grass_encounter_chance


func _load_encounter_area_metadata() -> void:
	var metadata_service := get_node_or_null("/root/EncounterMetadataService")
	if metadata_service == null or not metadata_service.has_method("get_encounter_area_metadata"):
		return

	var response: Dictionary = await metadata_service.call("get_encounter_area_metadata", encounter_area_id)
	if not response.get("success", false):
		push_warning("Encounter metadata failed for %s: %s" % [
			encounter_area_id,
			str(response.get("error", "Unknown API error")),
		])
		return

	var metadata: Dictionary = response.get("metadata", {})
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	var grass_metadata: Dictionary = encounter_types.get("grass", {})
	grass_encounter_chance = clampf(float(grass_metadata.get("encounterChance", grass_encounter_chance)), 0.0, 1.0)


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)
