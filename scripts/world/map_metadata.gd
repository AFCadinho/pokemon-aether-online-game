extends Node2D

@export var map_id := ""
@export var map_region_name := ""
@export var map_display_name := ""
@export_file("*.ogg") var music_track_path := "res://assets/audio/music/overworld/overworld_theme.ogg"


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_music_track_path() -> String:
	return music_track_path
