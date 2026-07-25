extends Node

@export_file("*.ogg") var music_track_path := ""
@export var music_profile_id := ""


func get_music_track_path() -> String:
	return music_track_path


func get_music_profile_id() -> String:
	return music_profile_id
