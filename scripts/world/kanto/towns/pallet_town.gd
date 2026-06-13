extends Node2D

@export_file("*.ogg") var music_track_path := "res://assets/audio/music/overworld/overworld_theme.ogg"


func get_music_track_path() -> String:
	return music_track_path


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
