@tool
extends Resource
class_name PokeAetherTiledEncounterRegionData

@export var encounter_region_id := ""
@export var encounter_area_id := ""
@export var encounter_type := "grass"
@export var encounter_chance := -1.0
@export var shape := "rectangle"
@export var rect := Rect2()
@export var points: PackedVector2Array = PackedVector2Array()
@export var source_layer_name := ""
@export var source_object_id := 0
@export var properties: Dictionary = {}
