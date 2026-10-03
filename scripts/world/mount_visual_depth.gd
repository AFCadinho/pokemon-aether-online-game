extends RefCounted

# Mount parts share the actor's world Z. Their original Z values become local
# scene order instead, so map objects cannot slip between rider and mount.
const ENABLED_META := &"mount_world_depth_enabled"
const Z_META := &"mount_local_layer_z"
const INDEX_META := &"mount_original_child_index"


static func configure(look: Node2D, enabled: bool) -> bool:
	if look == null or bool(look.get_meta(ENABLED_META, false)) == enabled:
		return false
	look.set_meta(ENABLED_META, enabled)
	_set_depth_recursive(look, enabled)
	return true


static func set_layer_z(item: CanvasItem, depth: int) -> void:
	if item.has_meta(Z_META):
		if int(item.get_meta(Z_META)) == depth and item.z_index == 0:
			return
		item.set_meta(Z_META, depth)
		item.z_index = 0
		_order_children(item.get_parent())
	else:
		item.z_index = depth


static func _set_depth_recursive(node: Node, enabled: bool) -> void:
	var item := node as CanvasItem
	if item != null and item.z_as_relative:
		if enabled:
			item.set_meta(Z_META, item.z_index)
			item.z_index = 0
		elif item.has_meta(Z_META):
			item.z_index = int(item.get_meta(Z_META))
			item.remove_meta(Z_META)
	for child: Node in node.get_children():
		if enabled:
			child.set_meta(INDEX_META, child.get_index())
		_set_depth_recursive(child, enabled)
	if enabled:
		_order_children(node)
	else:
		var children := node.get_children()
		children.sort_custom(func(a: Node, b: Node) -> bool:
			return int(a.get_meta(INDEX_META, a.get_index())) < int(b.get_meta(INDEX_META, b.get_index()))
		)
		for index in range(children.size()):
			var child: Node = children[index]
			if child.get_index() != index:
				node.move_child(child, index)
			child.remove_meta(INDEX_META)


static func _order_children(parent: Node) -> void:
	if parent == null:
		return
	var children := parent.get_children()
	children.sort_custom(func(a: Node, b: Node) -> bool:
		var a_z := int(a.get_meta(Z_META, 0))
		var b_z := int(b.get_meta(Z_META, 0))
		if a_z != b_z:
			return a_z < b_z
		return int(a.get_meta(INDEX_META, a.get_index())) < int(b.get_meta(INDEX_META, b.get_index()))
	)
	for index in range(children.size()):
		if children[index].get_index() != index:
			parent.move_child(children[index], index)
