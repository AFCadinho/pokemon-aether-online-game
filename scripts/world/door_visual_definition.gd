extends Resource

class_name DoorVisualDefinition

## Een herbruikbare beschrijving van een deur die uit meerdere maptiles bestaat.
## De animator gebruikt deze later om de gevel statisch te houden en alleen de
## panelen binnen `panel_bounds` te animeren.
@export var door_type := ""
@export var source_layer_name := "StructuresBottom"
@export var source_cells: Array[Vector2i] = []
@export var synthetic_atlas_cells: Dictionary = {}
@export var overlay_layer_name := ""
@export var overlay_cells_to_erase: Array[Vector2i] = []
@export var panel_bounds := Rect2()
@export var trigger_cell := Vector2i.ZERO
@export var opening_color := Color(0.035, 0.045, 0.06, 1.0)
@export var open_offset := Vector2(10.0, 0.0)
@export_range(0.0, 1.0, 0.01) var tween_seconds := 0.16
