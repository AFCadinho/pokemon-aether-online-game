@tool
extends Node2D

const MapCharacterBlocking := preload("res://scripts/world/map_character_blocking.gd")

@export var map_data: Resource


func get_map_id() -> String:
	return str(map_data.get("map_id")) if map_data != null else ""


func get_map_display_name() -> String:
	return str(map_data.get("map_display_name")) if map_data != null else ""


func get_map_region_name() -> String:
	return str(map_data.get("region_name")) if map_data != null else ""


func get_location_metadata() -> Dictionary:
	if map_data == null:
		return {}

	var location_id := str(map_data.get("location_id"))
	var location_name := str(map_data.get("location_name"))
	var map_id := str(map_data.get("map_id"))
	var map_display_name := str(map_data.get("map_display_name"))
	var region_id := str(map_data.get("region_id"))
	var region_name := str(map_data.get("region_name"))
	return {
		"locationId": location_id if location_id.strip_edges() != "" else map_id,
		"locationName": location_name if location_name.strip_edges() != "" else map_display_name,
		"regionId": region_id,
		"regionName": region_name,
		"mapId": map_id,
	}


func get_music_track_path() -> String:
	return str(map_data.get("music_track_path")) if map_data != null else ""


func get_wild_encounter_area_id() -> String:
	return str(map_data.get("encounter_area_id")) if map_data != null else ""


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)
