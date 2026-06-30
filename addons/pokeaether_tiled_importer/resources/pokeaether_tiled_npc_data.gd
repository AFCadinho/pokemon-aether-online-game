@tool
extends Resource
class_name PokeAetherTiledNpcData

@export var npc_id := ""
@export var npc_kind := ""
@export var position := Vector2.ZERO
@export var facing := "down"
@export var scene_path := ""
@export var display_name := ""
@export var trainer_id := ""
@export var dialogue_id := ""
@export var sight_range_tiles := 0
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
