extends RefCounted

class_name MapCharacterBlocking

const NPC_CONTAINER_PATHS: Array[String] = [
	"Entities/NPCs",
	"Entities/Pokemon",
	"Entities/Interactables",
	# Oudere/handgemaakte maps plaatsen dit direct onder de map-root.
	"Interactables",
]
const ROUTE_GATES_LAYER_NAME := "RouteGates"


static func is_position_blocked_by_character(map_node: Node, world_position: Vector2) -> bool:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container != null and _is_position_blocked_by_character_node(container, world_position):
			return true

	return false


static func get_closed_route_gate_npc(map_node: Node, world_position: Vector2) -> Node:
	var route_gate_match := _get_route_gate_match(map_node, world_position)
	if bool(route_gate_match.get("found", false)):
		var route_gate_id := str(route_gate_match.get("route_gate_id", "")).strip_edges()
		var gate_npc: Node = null
		if route_gate_id.is_empty():
			gate_npc = _get_first_closed_gate_npc(map_node)
		else:
			gate_npc = _get_closed_route_gate_npc_by_id(map_node, route_gate_id)
		if gate_npc != null:
			return gate_npc

	return _get_closed_gate_npc_at_position(map_node, world_position)


static func _is_position_blocked_by_character_node(node: Node, world_position: Vector2) -> bool:
	for child: Node in node.get_children():
		if child.has_method("blocks_world_position") and child.blocks_world_position(world_position):
			return true

		if _is_position_blocked_by_character_node(child, world_position):
			return true

	return false


static func _get_route_gate_match(map_node: Node, world_position: Vector2) -> Dictionary:
	var route_gates := map_node.get_node_or_null(ROUTE_GATES_LAYER_NAME)
	if route_gates == null:
		return {}

	return _get_route_gate_match_in_node(route_gates, world_position)


static func _get_route_gate_match_in_node(node: Node, world_position: Vector2) -> Dictionary:
	if node is TileMapLayer:
		var route_gate_layer := node as TileMapLayer
		var local_position := route_gate_layer.to_local(world_position)
		var tile_position := route_gate_layer.local_to_map(local_position)
		if route_gate_layer.get_cell_source_id(tile_position) != -1:
			return {
				"found": true,
				"route_gate_id": str(route_gate_layer.get_meta("route_gate_id", "")),
			}

	for child: Node in node.get_children():
		var child_match := _get_route_gate_match_in_node(child, world_position)
		if bool(child_match.get("found", false)):
			return child_match

	return {}


static func _get_closed_route_gate_npc_by_id(map_node: Node, route_gate_id: String) -> Node:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container == null:
			continue

		var gate_npc := _get_closed_route_gate_npc_by_id_in_node(container, route_gate_id)
		if gate_npc != null:
			return gate_npc

	return null


static func _get_closed_route_gate_npc_by_id_in_node(node: Node, route_gate_id: String) -> Node:
	for child: Node in node.get_children():
		if (
			child.has_method("is_gate_open")
			and child.has_method("handles_route_gate")
			and bool(child.handles_route_gate(route_gate_id))
			and not child.is_gate_open()
		):
			return child

		var gate_npc := _get_closed_route_gate_npc_by_id_in_node(child, route_gate_id)
		if gate_npc != null:
			return gate_npc

	return null


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


static func _get_closed_gate_npc_at_position(map_node: Node, world_position: Vector2) -> Node:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container == null:
			continue

		var gate_npc: Node = _get_closed_gate_npc_at_position_in_node(container, world_position)
		if gate_npc != null:
			return gate_npc

	return null


static func _get_closed_gate_npc_at_position_in_node(node: Node, world_position: Vector2) -> Node:
	for child: Node in node.get_children():
		if (
			child.has_method("is_gate_open")
			and not child.is_gate_open()
			and child.has_method("blocks_world_position")
			and child.blocks_world_position(world_position)
		):
			return child

		var gate_npc: Node = _get_closed_gate_npc_at_position_in_node(child, world_position)
		if gate_npc != null:
			return gate_npc

	return null
