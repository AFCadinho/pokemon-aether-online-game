extends RefCounted

const LayerResolver := preload("res://scripts/world/map_layer_resolver.gd")
const LAYER_DIRECTIONS := {
	"SpinUp": Vector2.UP,
	"SpinDown": Vector2.DOWN,
	"SpinLeft": Vector2.LEFT,
	"SpinRight": Vector2.RIGHT,
}
const STOP_LAYER := "SpinStop"
const TILE_DURATION := 0.12
const TURN_DURATION := 0.07
const TURN_DIRECTIONS: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]

var map_owner: Node
var layers: Dictionary = {}
var active := false
var direction := Vector2.ZERO
var elapsed := 0.0
var _stopped_position := Vector2.INF
var _visited: Dictionary = {}


func refresh_layers(map: Node) -> void:
	map_owner = map
	layers.clear()
	var names: Array = LAYER_DIRECTIONS.keys() + [STOP_LAYER]
	for layer_name: String in names:
		var layer := LayerResolver.find_tilemap_layer(map, [layer_name])
		if layer != null:
			layers[layer_name] = layer
			# Marker artwork is for authoring; the imported floor stays visible.
			layer.hide()
			layer.collision_enabled = false
			layer.navigation_enabled = false


func try_begin(world_position: Vector2) -> bool:
	if layers.is_empty():
		return false
	if world_position != _stopped_position:
		_stopped_position = Vector2.INF
	if active or world_position == _stopped_position or has_stop(world_position):
		return false
	direction = direction_at(world_position)
	if direction == Vector2.ZERO:
		return false
	active = true
	elapsed = 0.0
	_visited.clear()
	return true


func next_direction(world_position: Vector2) -> Vector2:
	if not active or has_stop(world_position):
		return Vector2.ZERO
	var arrow := direction_at(world_position)
	if arrow != Vector2.ZERO:
		direction = arrow
	# A closed painted loop must release the player instead of trapping input.
	var state := Vector3(world_position.x, world_position.y, TURN_DIRECTIONS.find(direction))
	if _visited.has(state):
		return Vector2.ZERO
	_visited[state] = true
	return direction


func stop(world_position: Vector2) -> void:
	active = false
	direction = Vector2.ZERO
	_stopped_position = world_position
	_visited.clear()


func reset() -> void:
	stop(Vector2.INF)
	elapsed = 0.0


func direction_at(world_position: Vector2) -> Vector2:
	for layer_name: String in LAYER_DIRECTIONS:
		if _has_tile(layer_name, world_position):
			return LAYER_DIRECTIONS[layer_name]
	return Vector2.ZERO


func has_stop(world_position: Vector2) -> bool:
	return _has_tile(STOP_LAYER, world_position)


func visual_direction() -> Vector2:
	return TURN_DIRECTIONS[int(elapsed / TURN_DURATION) % TURN_DIRECTIONS.size()]


func _has_tile(layer_name: String, world_position: Vector2) -> bool:
	var layer := layers.get(layer_name) as TileMapLayer
	return is_instance_valid(layer) and layer.get_cell_source_id(layer.local_to_map(layer.to_local(world_position))) >= 0
