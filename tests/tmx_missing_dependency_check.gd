extends SceneTree

func _init() -> void:
	var parser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd").new()
	var path := "res://tests/fixtures/tiled/missing_tileset.tmx"
	var selected := "res://tests/fixtures/tiled/visual_only_tileset.tsx"
	assert(parser.parse_tmx(path).map.tilesets[0].has("external_error"))
	assert(parser.parse_tmx(path, {"missing.tsx": "res://does-not-exist.tsx"}).map.tilesets[0].has("external_error"))
	var repaired: Dictionary = parser.parse_tmx(path, {"missing.tsx": selected})
	assert(repaired.get("success", false))
	assert(repaired.map.tilesets[0].source_path == selected)
	assert(repaired.map.tilesets[0].image.path == ProjectSettings.globalize_path("res://assets/tilesets/fiver/tiles_env2_floors32.png"))
	assert(not parser.parse_tmx("res://tests/fixtures/tiled/visual_only_regular.tmx", {"visual_only_tileset.tsx": "res://does-not-exist.tsx"}).map.tilesets[0].has("external_error"))
	print("TMX_MISSING_DEPENDENCY_CHECK success=true (missing reported, explicit repair, image base, existing dependency preserved)")
	quit(0)
