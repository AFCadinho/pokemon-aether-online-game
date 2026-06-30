@tool
extends Resource
class_name PokeAetherTiledSpawnData

@export var spawn_id := ""
@export var position := Vector2.ZERO
@export var facing := "down"
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
