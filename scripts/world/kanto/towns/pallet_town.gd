extends Node2D

@export var map_id := "kanto_pallet_town"
@export var map_region_name := "Kanto"
@export var map_display_name := "Pallet Town"
@export var location_id := "kanto.pallet_town"
@export var location_name := "Pallet Town"
@export var region_id := "kanto"
@export var encounter_area_id := "kanto_pallet_town"
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.1
@export_range(0.0, 1.0, 0.01) var fish_encounter_chance := 1.0
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"


func _ready() -> void:
	await _load_encounter_area_metadata()


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_location_metadata() -> Dictionary:
	return {
		"locationId": location_id,
		"locationName": location_name,
		"regionId": region_id,
		"regionName": map_region_name,
		"mapId": map_id,
	}


func get_music_track_path() -> String:
	return music_track_path


func get_wild_encounter_area_id() -> String:
	return encounter_area_id


func get_wild_encounter_chance(encounter_type: String = "grass") -> float:
	match encounter_type.strip_edges().to_lower():
		"surf":
			return surf_encounter_chance
		"fish", "fishing":
			return fish_encounter_chance
		_:
			return 0.0


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	var encounter_chance := get_wild_encounter_chance(encounter_type)
	if encounter_chance <= 0.0:
		return false

	return randf() <= encounter_chance


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)


func _load_encounter_area_metadata() -> void:
	if encounter_area_id.strip_edges() == "":
		return

	var metadata_service := get_node_or_null("/root/EncounterMetadataService")
	if metadata_service == null or not metadata_service.has_method("get_encounter_area_metadata"):
		return

	var response: Dictionary = await metadata_service.call("get_encounter_area_metadata", encounter_area_id)
	if not response.get("success", false):
		push_warning("Pallet Town encounter metadata failed for %s: %s" % [
			encounter_area_id,
			str(response.get("error", "Unknown API error")),
		])
		return

	var metadata: Dictionary = response.get("metadata", {})
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	surf_encounter_chance = _metadata_encounter_chance(encounter_types, "surf", surf_encounter_chance)
	fish_encounter_chance = _metadata_encounter_chance(encounter_types, "fish", fish_encounter_chance)
	fish_encounter_chance = _metadata_encounter_chance(encounter_types, "fishing", fish_encounter_chance)


func _metadata_encounter_chance(encounter_types: Dictionary, encounter_type: String, fallback: float) -> float:
	var encounter_metadata: Dictionary = encounter_types.get(encounter_type, {})
	return clampf(float(encounter_metadata.get("encounterChance", fallback)), 0.0, 1.0)
