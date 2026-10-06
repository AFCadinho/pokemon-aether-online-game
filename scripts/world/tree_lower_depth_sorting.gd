extends RefCounted

# The approved 64x128 evergreen, expressed as eight 32px RGBA tile hashes.
# Exact artwork works with both dense and compact atlases, independent of GIDs.
# Unknown artwork, alternative/flipped tiles and incomplete trees stay put.
const EVERGREEN_PARTS := {
	Vector2i(0, 0): "08b923787bd75fa45694a08e208f4988a7b93cc02f37879592977a2286986844",
	Vector2i(1, 0): "9bf02e8d9e64329a0b157130d1029ae5aacc459913e0715eb7afb95b03cc14e5",
	Vector2i(0, 1): "8a9a379139f7b2e0501be57dd4d618d505020958926615f6646427802af88896",
	Vector2i(1, 1): "599ad73b7eb77b97548154beda67f6c6bae1f887665005c38be76efcd5ca01d2",
	Vector2i(0, 2): "4606c7b7912e5570e35f31929344bb1c1a41a44af8c004fcd99293634c3be7f5",
	Vector2i(1, 2): "6128c62400a011407104ff47e045c9230ab8ec6d8d0813378fca695d620b69ae",
	Vector2i(0, 3): "1377675954ed320a98a055274f43d205fb309d580e8afd2b547410780b2eb714",
	Vector2i(1, 3): "7e0aadf74f969e4d9ac03187b52c67897c2e9442512e2790566a1fb8c06abc5c",
}
const BOTTOM_LAYER_NAMES := ["TreeBottom", "Tree Bottom", "StructureBottom", "StructureBottomVisual"]
const DEPTH_LAYER_META := &"pao_tree_lower_depth_layer"
const LowerVisualDepth := preload("res://scripts/world/lower_visual_depth_sorting.gd")
const STRUCTURE_GROUP_META := LowerVisualDepth.STRUCTURE_GROUP_META
const FAMILY := {"name": "Tree", "size": Vector2i(2, 4), "upper_rows": 2, "parts": EVERGREEN_PARTS}


static func build_depth_layers(top: TileMapLayer, group_root: Node2D) -> int:
	return LowerVisualDepth.build_depth_layers(top, group_root, FAMILY, BOTTOM_LAYER_NAMES, DEPTH_LAYER_META)
