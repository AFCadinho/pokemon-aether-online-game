extends Node
## Reviewed per-map leaf bounds. Static scenery and MapExit authority stay intact.
const SLIDING = preload("res://scripts/world/sliding_map_door.gd")
const HINGED = preload("res://scripts/world/hinged_map_door.gd")
const DOUBLE = preload("res://scripts/world/double_sliding_map_door.gd")
const CATALOG_PATH := "res://resources/world/map_doors.json"
var doors: Dictionary = {}
var definitions: Array = []

func _ready() -> void:
	var map := get_parent()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	definitions = catalog.get(map.scene_file_path, [])
	for entry: Dictionary in definitions:
		var visual := map.get_node(entry.visual)
		var door: Node2D = (HINGED if entry.kind == "hinge" else (DOUBLE if entry.kind in ["gym", "double"] else SLIDING)).new()
		door.name = entry.id
		var b: Array = entry.bounds
		door.position = Vector2(b[0], b[1])
		door.panel_size = Vector2(b[2], b[3])
		door.z_index = 4
		var a: Array = entry.activation
		door.activation_rect = Rect2(a[0], a[1], a[2], a[3])
		door.animation_seconds = 0.24
		door.movement_sound_id = "sliding_door"
		door.access_enabled = entry.enabled
		door.players_path = NodePath("../../Entities/Players")
		if not str(entry.lock).is_empty():
			door.access_lock_path = NodePath("../../" + entry.lock)
		for layer: String in entry.layers:
			door.source_layers.append(NodePath("../" + layer))
			door.z_index = maxi(door.z_index, visual.get_node(layer).z_index + 1)
		if entry.has("depth_y"):
			door.z_as_relative = false
			door.z_index = int(entry.depth_y)
		if entry.kind == "double":
			door.curved_frame = false
		visual.add_child(door)
		doors[entry.id] = door

func prepare_player_arrival(spawn_name: String) -> void:
	for entry: Dictionary in definitions:
		if entry.enabled and spawn_name in entry.arrivals:
			doors[entry.id].prepare_for_arrival()
