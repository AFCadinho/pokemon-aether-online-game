extends RefCounted


static func find_tilemap_layer(root: Node, layer_names: Array[String]) -> TileMapLayer:
	if root == null or not is_instance_valid(root):
		return null

	for layer_name: String in layer_names:
		var direct_layer := root.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if direct_layer != null:
			return direct_layer

	return _find_tilemap_layer_recursive(root, layer_names)


static func _find_tilemap_layer_recursive(node: Node, layer_names: Array[String]) -> TileMapLayer:
	var tilemap_layer := node as TileMapLayer
	if tilemap_layer != null and layer_names.has(str(tilemap_layer.name)):
		return tilemap_layer

	for child: Node in node.get_children():
		var child_layer := _find_tilemap_layer_recursive(child, layer_names)
		if child_layer != null:
			return child_layer

	return null
