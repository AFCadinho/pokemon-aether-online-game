extends Node2D

@export var map_id := "kanto_route_1"
@export var map_region_name := "Kanto"
@export var map_display_name := "Route 1"
@export var world_access_group_id := "kanto_route_1"
@export var world_access_group_label := "Route 1"
@export_enum("exterior", "interior", "route", "wilderness", "transition") var world_access_area_type := "route"
@export var location_id := "kanto.route_1"
@export var location_name := "Route 1"
@export var region_id := "kanto"
@export var encounter_area_id := "kanto_route_1"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.1
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/routes/route1.ogg"

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

func get_wild_encounter_area_id() -> String:
	return encounter_area_id

func get_music_track_path() -> String:
	return music_track_path

func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	if encounter_type != "grass":
		return false

	return randf() <= grass_encounter_chance

func _load_encounter_area_metadata() -> void:
	var response: Dictionary = await EncounterMetadataService.get_encounter_area_metadata(encounter_area_id)
	if not response.get("success", false):
		push_warning("Route 1 encounter metadata failed for %s: %s" % [
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
