extends SceneTree

# Run in a fresh, empty project: missing pack dependencies cannot fall back to
# the source checkout. Visual-only; no accounts/backend/gameplay scene entry.
const SCOPES := {
	"misty": ["route_3", "mt_moon_1f", "mt_moon_b1f", "mt_moon_b2f", "route_4", "cerulean_city", "cerulean_gym", "cerulean_bike_shop", "cerulean_house_template_blue", "route_24", "route_25", "bills_house"],
	"aether": ["waiting_area", "aether_clash_duel", "aether_clash_battle_royale"],
	"core": ["pallet_town_compact", "route_1", "viridian_city", "lobby", "pewter_city", "pewter_gym", "kanto_route_2", "kanto_route_22", "viridian_forest", "rivals_house", "pewter_house", "pokemon_center", "pokemon_school", "viridian_house_template", "transition_building_vertical"],
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or (not SCOPES.has(args[0]) and args[0] != "desktop") or FileAccess.file_exists("res://scenes/world.tscn"):
		push_error("Requires an empty project and arguments SCOPE PACK ABSOLUTE_FINGERPRINT_JSON.")
		quit(2)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	if not ProjectSettings.load_resource_pack(args[1], false):
		quit(1)
		return
	var valid := true
	var maps := 0
	var visual_ids: Array = expected.keys() if args[0] == "desktop" else SCOPES[args[0]]
	if args[0] == "desktop" and visual_ids.size() != 33:
		push_error("Desktop probe requires the complete approved 33-map baseline.")
		quit(2)
		return
	for id in visual_ids:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null or not expected.has(id):
			valid = false
			continue
		var root := scene.instantiate()
		var layers: Array[TileMapLayer] = []
		_collect(root, layers)
		var cells := 0
		var tiles := {}
		var textures := {}
		var bytes := 0
		for layer in layers:
			valid = valid and int(layer.tile_set.get_meta("tiled_compact_atlas_version", 0)) == 1
			for index in layer.tile_set.get_source_count():
				var source := layer.tile_set.get_source(layer.tile_set.get_source_id(index)) as TileSetAtlasSource
				var texture := source.texture as PortableCompressedTexture2D if source != null else null
				if texture == null:
					valid = false
					continue
				valid = valid and texture.get_compression_mode() == PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS and texture.get_width() <= 4096 and texture.get_height() <= 4096
				if not textures.has(texture.resource_path):
					textures[texture.resource_path] = true
					bytes += texture.get_width() * texture.get_height() * 4
			for cell in layer.get_used_cells():
				var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
				var coords := layer.get_cell_atlas_coords(cell)
				var alternative := layer.get_cell_alternative_tile(cell) & ~(4096 | 8192 | 16384)
				valid = valid and source != null and source.has_tile(coords) and source.has_alternative_tile(coords, alternative)
				tiles["%d/%s/%d" % [layer.get_cell_source_id(cell), coords, alternative]] = true
				cells += 1
		valid = valid and cells == expected[id].cells and layers.size() == expected[id].layers and tiles.size() == expected[id].usedTiles and bytes == expected[id].baseRGBABytes
		root.free()
		maps += 1
	print("EXPORTED_ATLAS_MODULE ", JSON.stringify({"scope": args[0], "maps": maps, "success": valid}))
	quit(0 if valid else 1)

func _collect(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		layers.append(node)
	for child in node.get_children():
		_collect(child, layers)
