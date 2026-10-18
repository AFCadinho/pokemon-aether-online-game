extends RefCounted

# Godot 4's Compatibility canvas items accept 15 point lights. The default
# 16x16 tile batches can intersect more city lamps than that, so camera culling
# changes which lights make the list. Four-tile batches keep those lists local.
const RENDERING_QUADRANT_SIZE := 4


static func configure_map(map: Node) -> void:
	if map == null or map.get_node_or_null("NightLights") == null:
		return
	_configure_layers(map)


static func _configure_layers(node: Node) -> void:
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		if layer.visible:
			layer.rendering_quadrant_size = mini(
				layer.rendering_quadrant_size, RENDERING_QUADRANT_SIZE
			)
	for child: Node in node.get_children():
		_configure_layers(child)
