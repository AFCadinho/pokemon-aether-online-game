extends RefCounted

# The same logical frame is fitted inside every physical window, including
# ultrawide and portrait windows. Output pixel density never changes arena sight.
const FRAME_SIZE := Vector2i(1920, 1080)
const WORLD_VIEW_SIZE := Vector2(960, 540)


static func active_controller(tree: SceneTree) -> Node:
	if tree == null:
		return null
	for controller: Node in tree.get_nodes_in_group("aether_clash_duel_controller"):
		if controller.has_method("is_arena_view_locked") and controller.call("is_arena_view_locked"):
			return controller
	return null


static func is_locked(tree: SceneTree) -> bool:
	return active_controller(tree) != null
