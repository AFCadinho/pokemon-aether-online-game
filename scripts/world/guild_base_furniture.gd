@tool
extends Node2D

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
@export var furniture_id := ""
var placement: Dictionary = {}
var room: Node2D
var is_preview := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		var layer := get_node_or_null("Collision") as TileMapLayer
		if layer != null:
			layer.hide()
			layer.collision_enabled = false

func configure(map: Node2D, value: Dictionary, preview := false) -> void:
	room = map
	placement = value.duplicate(true)
	is_preview = preview
	var spec := Catalog.item(furniture_id)
	var rectangle := Catalog.footprint(placement)
	position = Vector2(rectangle.position.x, rectangle.end.y) * 32
	z_as_relative = false
	z_index = 2 if bool(spec.get("drawOnFloor", false)) or str(spec.category) == "floor" or (str(spec.placement) == "wall" and not bool(spec.blocksMovement)) else clampi(int(position.y) - 1, -4096, 4094)
	if bool(spec.resizable):
		var visual := get_node("Visual") as TileMapLayer
		visual.clear()
		visual.position = Vector2(0, -rectangle.size.y * 32)
		for y: int in range(rectangle.size.y):
			for x: int in range(rectangle.size.x):
				var row := 0 if y == 0 else (2 if y == rectangle.size.y - 1 else 1)
				var column := 0 if x == 0 else (2 if x == rectangle.size.x - 1 else 1)
				var coordinates: Array = Catalog.atlas[str(int(spec.tiles[row][column]))]
				visual.set_cell(Vector2i(x, y), 0, Vector2i(coordinates[0], coordinates[1]))

func configure_surface(map: Node2D, value: Dictionary, parent_spec: Dictionary, preview := false) -> void:
	room = map
	placement = value.duplicate(true)
	is_preview = preview
	var offset: Array = parent_spec.surfaceSlots[int(value.slot)]
	position = Vector2(offset[0], offset[1])
	z_as_relative = true
	z_index = 1

func blocks_world_position(world_position: Vector2) -> bool:
	if is_preview or not is_instance_valid(room) or placement.is_empty():
		return false
	return Vector2i((room.to_local(world_position) / 32).floor()) in Catalog.movement_cells(placement)

static func instantiate_placement(map: Node2D, value: Dictionary, all_placements: Array, preview := false) -> Node2D:
	var spec := Catalog.item(str(value.furnitureId))
	var object: Node2D = load(str(spec.scenePath)).instantiate()
	object.configure(map, value, preview)
	for child_placement: Dictionary in all_placements:
		if str(child_placement.get("parentId", "")) != str(value.id):
			continue
		var child_spec := Catalog.item(str(child_placement.furnitureId))
		var child: Node2D = load(str(child_spec.scenePath)).instantiate()
		child.configure_surface(map, child_placement, spec, preview)
		object.add_child(child)
	return object
