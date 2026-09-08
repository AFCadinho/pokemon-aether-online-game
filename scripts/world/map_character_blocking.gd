extends RefCounted

class_name MapCharacterBlocking

const NPC_CONTAINER_PATHS: Array[String] = [
	"Entities/NPCs",
	"Entities/Pokemon",
	"Entities/Interactables",
	# Oudere/handgemaakte maps plaatsen dit direct onder de map-root.
	"Interactables",
]


# Only cache topology; positions and story-dependent blocking stay live.
class BlockerIndex extends Node:
	var dirty := true
	var candidates: Array[Node] = []

	func _enter_tree() -> void:
		dirty = true
		get_tree().tree_changed.connect(_invalidate)

	func _exit_tree() -> void:
		get_tree().tree_changed.disconnect(_invalidate)

	func _invalidate() -> void:
		dirty = true


static func _candidates_for_map(map_node: Node) -> Array[Node]:
	var index: BlockerIndex
	if map_node.is_inside_tree():
		if map_node.has_meta("character_blocker_index"):
			index = map_node.get_meta("character_blocker_index") as BlockerIndex
		if not is_instance_valid(index):
			index = BlockerIndex.new()
			index.name = "CharacterBlockerIndex"
			map_node.add_child(index)
			map_node.set_meta("character_blocker_index", index)
		if not index.dirty:
			return index.candidates
	var candidates: Array[Node] = []
	for container_path: String in NPC_CONTAINER_PATHS:
		var container := map_node.get_node_or_null(container_path)
		if container != null:
			_collect_candidates(container, candidates)
	if index != null:
		index.candidates = candidates
		index.dirty = false
	return candidates


static func _collect_candidates(node: Node, candidates: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child.has_method("blocks_world_position") or child.has_method("guards_world_position"):
			candidates.append(child)
		_collect_candidates(child, candidates)


static func is_position_blocked_by_character(map_node: Node, world_position: Vector2) -> bool:
	for candidate: Node in _candidates_for_map(map_node):
		if is_instance_valid(candidate) and candidate.has_method("blocks_world_position") and candidate.blocks_world_position(world_position):
			return true
	return false


static func get_closed_route_gate_npc(map_node: Node, world_position: Vector2) -> Node:
	var candidates := _candidates_for_map(map_node)
	# Transition guards retain priority over ordinary blocking gate NPCs.
	for candidate: Node in candidates:
		if is_instance_valid(candidate) and candidate.has_method("guards_world_position") and candidate.guards_world_position(world_position):
			return candidate
	for candidate: Node in candidates:
		if (
			is_instance_valid(candidate)
			and candidate.has_method("is_gate_open")
			and not candidate.is_gate_open()
			and candidate.has_method("blocks_world_position")
			and candidate.blocks_world_position(world_position)
		):
			return candidate
	return null
