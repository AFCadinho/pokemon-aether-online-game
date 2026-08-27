@tool
extends TrainerNPC

class_name WaterBoundTrainer


func _ready() -> void:
	movement_behavior = "idle"
	super._ready()
	if not Engine.is_editor_hint():
		_validate_water_tile.call_deferred()


## Water-bound trainers can spot and battle players on an adjacent walkway, but
## their swimming sprite must never leave the water tile where it was placed.
func walk_to_player(body: Node2D) -> void:
	if body == null:
		return
	var direction := _get_cardinal_direction(body.global_position - global_position)
	if direction == Vector2.ZERO:
		return
	facing_direction = direction
	_set_idle_frame(direction)


func _validate_water_tile() -> void:
	var water_layer := _find_map_layer("Water")
	if water_layer == null:
		push_error("WaterBoundTrainer: Water layer not found for %s." % trainer_id)
		return
	var water_cell := water_layer.local_to_map(water_layer.to_local(global_position))
	if water_layer.get_cell_source_id(water_cell) < 0:
		push_error(
			"WaterBoundTrainer: %s must be placed on a Water tile, got %s."
			% [trainer_id, water_cell]
		)


func _find_map_layer(layer_name: String) -> TileMapLayer:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("find_map_tilemap_layer"):
			return ancestor.call("find_map_tilemap_layer", layer_name) as TileMapLayer
		ancestor = ancestor.get_parent()
	return null
