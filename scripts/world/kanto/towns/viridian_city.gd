extends Node2D

@export var map_id := "kanto_viridian_city"
@export var map_region_name := "Kanto"
@export var map_display_name := "Viridian City"
@export var location_id := "kanto.viridian_city"
@export var location_name := "Viridian City"
@export var region_id := "kanto"
@export var encounter_area_id := "kanto_viridian_city"
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"


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


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	return false


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)
