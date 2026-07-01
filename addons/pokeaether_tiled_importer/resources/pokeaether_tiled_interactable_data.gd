@tool
extends Resource
class_name PokeAetherTiledInteractableData

@export var interactable_id := ""
@export var interactable_kind := ""
@export var position := Vector2.ZERO
@export var display_name := ""
@export var dialogue_id := ""
@export var dialogue_lines: Array[String] = []
@export var scene_path := ""
@export var blocks_movement := true
@export var requires_facing := true
@export var blocked_tile_offset := Vector2i.ZERO
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
