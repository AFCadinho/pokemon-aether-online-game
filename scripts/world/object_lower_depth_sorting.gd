extends RefCounted

const LowerVisualDepth := preload("res://scripts/world/lower_visual_depth_sorting.gd")

# The complete 32x160 lantern/post used on Viridian streets and its jail sides.
# Match the cap, lamp and upper shaft before moving the lower shaft and foot.
# Steps, paving and incomplete/unknown object artwork remain on their old layer.
const LANTERN_POST_PARTS := {
	Vector2i(0, 0): "6f329b7d99e0e915d809c0cf7b4320aceb8653d8290bf24b7f38b1a65b286c67",
	Vector2i(0, 1): "289497475cc5cbd613dc054068c613640eb4e9133a4c6219d62440f805c1f079",
	Vector2i(0, 2): "a9b61435c16972a80084150e6d66fdd42518158f00a802c430ef3ce76fbe17ce",
	Vector2i(0, 3): "4861d50ac916054132e85a46c96f2d612a1943715f760fd63a24b751ba9d528a",
	Vector2i(0, 4): "4dd3ba72dfc98699502baaada8c38079e4dfc680ec9b98269d3e583503e3ba30",
}
const BOTTOM_LAYER_NAMES := [
	"ObjectsBottom", "Objects Bottom", "ObjectBottom", "Object Bottom",
	"Objects", "ObjectsVisual", "ObjectVisual",
	"StructureBottom", "Structure Bottom", "StructureBottomVisual",
]
const DEPTH_LAYER_META := &"pao_object_lower_depth_layer"
const STRUCTURE_GROUP_META := LowerVisualDepth.STRUCTURE_GROUP_META
const FAMILY := {"name": "Object", "size": Vector2i(1, 5), "upper_rows": 3, "parts": LANTERN_POST_PARTS}


static func build_depth_layers(top: TileMapLayer, group_root: Node2D) -> int:
	return LowerVisualDepth.build_depth_layers(top, group_root, FAMILY, BOTTOM_LAYER_NAMES, DEPTH_LAYER_META)
