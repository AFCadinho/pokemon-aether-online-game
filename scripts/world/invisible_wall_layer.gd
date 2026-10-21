@tool
extends TileMapLayer

# A separate, hand-editable puzzle layer. MapCharacterBlocking discovers this
# under Entities/Interactables; ordinary Tiles/Collision remains independent.
@export var blocking_enabled := true


func blocks_world_position(world_position: Vector2) -> bool:
	if not blocking_enabled:
		return false
	var cell := local_to_map(to_local(world_position))
	return get_cell_source_id(cell) != -1
