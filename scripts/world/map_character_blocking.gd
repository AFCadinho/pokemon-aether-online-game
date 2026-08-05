extends RefCounted

class_name MapCharacterBlocking

const NPC_CONTAINER_PATHS: Array[String] = [
	"Entities/NPCs",
	"Entities/Pokemon",
	"Entities/Interactables",
	# Oudere/handgemaakte maps plaatsen dit direct onder de map-root.
	"Interactables",
]


static func is_position_blocked_by_character(map_node: Node, world_position: Vector2) -> bool:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container != null and _is_position_blocked_by_character_node(container, world_position):
			return true

	return false


static func get_closed_route_gate_npc(map_node: Node, world_position: Vector2) -> Node:
	for container_path: String in NPC_CONTAINER_PATHS:
		var container: Node = map_node.get_node_or_null(container_path)
		if container == null:
			continue
		var guard := _get_closed_transition_guard_at_position(container, world_position)
		if guard != null:
			return guard

	return _get_closed_gate_npc_at_position(map_node, world_position)


static func _is_position_blocked_by_character_node(node: Node, world_position: Vector2) -> bool:
	for child: Node in node.get_children():
		if child.has_method("blocks_world_position") and child.blocks_world_position(world_position):
			return true

		if _is_position_blocked_by_character_node(child, world_position):
			return true

	return false


static func _get_closed_transition_guard_at_position(node: Node, world_position: Vector2) -> Node:
	for child: Node in node.get_children():
		if (
			child.has_method("guards_world_position")
			and bool(child.call("guards_world_position", world_position))
		):
			return child

		var gate_npc := _get_closed_transition_guard_at_position(child, world_position)
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
