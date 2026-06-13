extends Node

@export_file("*.ogg") var music_track_path := "res://assets/audio/music/overworld/overworld_theme.ogg"


func get_music_track_path() -> String:
	return music_track_path
