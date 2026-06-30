@tool
extends Resource
class_name PokeAetherTiledTriggerData

@export var trigger_id := ""
@export var trigger_kind := ""
@export var event_id := ""
@export var once := false
@export var shape := "rectangle"
@export var rect := Rect2()
@export var points: PackedVector2Array = PackedVector2Array()
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
