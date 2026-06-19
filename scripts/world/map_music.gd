extends Node

@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/routes/route1.ogg"


func get_music_track_path() -> String:
	return music_track_path
