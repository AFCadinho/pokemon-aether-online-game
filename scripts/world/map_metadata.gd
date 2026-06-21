extends Node2D

@export var map_id := ""
@export var map_region_name := ""
@export var map_display_name := ""
@export var location_id := ""
@export var location_name := ""
@export var region_id := ""
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/routes/route1.ogg"


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_location_metadata() -> Dictionary:
	return {
		"locationId": location_id if location_id.strip_edges() != "" else map_id,
		"locationName": location_name if location_name.strip_edges() != "" else map_display_name,
		"regionId": region_id if region_id.strip_edges() != "" else map_region_name.to_lower().replace(" ", "_"),
		"regionName": map_region_name,
		"mapId": map_id,
	}


func get_music_track_path() -> String:
	return music_track_path
