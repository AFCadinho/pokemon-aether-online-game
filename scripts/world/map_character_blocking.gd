extends RefCounted

class_name MapCharacterBlocking

const NPC_CONTAINER_PATHS: Array[String] = [
	"Entities/NPCs",
]
const ROUTE_GATES_LAYER_NAME := "RouteGates"


static func is_position_blocked_by_character(map_node: Node, world_position: Vector2) -> bool:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container != null and _is_position_blocked_by_character_node(container, world_position):
			return true

	return false


static func get_closed_route_gate_npc(map_node: Node, world_position: Vector2) -> Node:
	if not _is_route_gate_tile(map_node, world_position):
		return null

	var gate_npc: Node = _get_first_closed_gate_npc(map_node)
	if gate_npc != null:
		return gate_npc

	return null


static func _is_position_blocked_by_character_node(node: Node, world_position: Vector2) -> bool:
	for child: Node in node.get_children():
		if child.has_method("blocks_world_position") and child.blocks_world_position(world_position):
			return true

		if _is_position_blocked_by_character_node(child, world_position):
			return true

	return false


static func _is_route_gate_tile(map_node: Node, world_position: Vector2) -> bool:
	var route_gates: TileMapLayer = map_node.get_node_or_null(ROUTE_GATES_LAYER_NAME) as TileMapLayer
	if route_gates == null:
		return false

	var local_position := route_gates.to_local(world_position)
	var tile_position := route_gates.local_to_map(local_position)
	return route_gates.get_cell_source_id(tile_position) != -1


static func _get_first_closed_gate_npc(map_node: Node) -> Node:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container == null:
			continue

		var gate_npc: Node = _get_first_closed_gate_npc_in_node(container)
		if gate_npc != null:
			return gate_npc

	return null


static func _get_first_closed_gate_npc_in_node(node: Node) -> Node:
	for child: Node in node.get_children():
		if child.has_method("is_gate_open") and not child.is_gate_open():
			return child

		var gate_npc: Node = _get_first_closed_gate_npc_in_node(child)
		if gate_npc != null:
			return gate_npc

	return null
