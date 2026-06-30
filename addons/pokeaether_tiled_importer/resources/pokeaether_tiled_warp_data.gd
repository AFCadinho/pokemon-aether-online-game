@tool
extends Resource
class_name PokeAetherTiledWarpData

@export var warp_id := ""
@export var rect := Rect2()
@export var target_map_id := ""
@export var target_scene_path := ""
@export var target_spawn_name := ""
@export var enabled := true
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
