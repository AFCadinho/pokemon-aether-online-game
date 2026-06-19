extends Node2D

@export var map_id := "kanto_pallet_town"
@export var map_region_name := "Kanto"
@export var map_display_name := "Pallet Town"
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_music_track_path() -> String:
	return music_track_path


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
