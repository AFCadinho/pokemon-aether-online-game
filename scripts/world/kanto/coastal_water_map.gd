extends "res://scripts/world/map_metadata.gd"

# The Tiled importer keeps water in Ground. Point at one open-water tile in
# this visual so Surf recognizes the same imported atlas tile throughout it.
@export var water_reference_tile := Vector2i.ZERO
@onready var painted_water_layer: TileMapLayer = get_node_or_null("Tiles/Water") as TileMapLayer
@onready var ground_layer: TileMapLayer = get_node_or_null("Visual/Ground") as TileMapLayer

var water_source_id := -1
var water_atlas_coords := Vector2i(-1, -1)


func _ready() -> void:
	if ground_layer != null:
		water_source_id = ground_layer.get_cell_source_id(water_reference_tile)
		water_atlas_coords = ground_layer.get_cell_atlas_coords(water_reference_tile)
	super._ready()


func is_water_tile_for_actor(world_position: Vector2, _actor: Node) -> bool:
	# Explicit gameplay water also covers shore tiles that use a different atlas
	# tile from the imported open-water reference. Visibility is only visual.
	if painted_water_layer != null:
		var painted_tile := painted_water_layer.local_to_map(painted_water_layer.to_local(world_position))
		if painted_water_layer.get_cell_source_id(painted_tile) != -1:
			return true
	if ground_layer == null or water_source_id == -1:
		return false
	var tile := ground_layer.local_to_map(ground_layer.to_local(world_position))
	return ground_layer.get_cell_source_id(tile) == water_source_id \
		and ground_layer.get_cell_atlas_coords(tile) == water_atlas_coords
