extends SceneTree

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
const CollisionAuthoring := preload("res://tools/guild_furniture_collision_authoring.gd")

func _init() -> void:
	var data := Catalog.load_data()
	var tiles: TileSet = load("res://assets/guild_base/furniture/furniture.tileset.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/world/guild_base/furniture"))
	var prefix := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	for item: Dictionary in data.items:
		if not str(item.id).begins_with(prefix):
			continue
		var collision_layer := CollisionAuthoring.load_existing_layer(str(item.scenePath))
		if collision_layer == null:
			collision_layer = CollisionAuthoring.create_layer(item)
		var root := Node2D.new()
		root.name = str(item.id).to_pascal_case()
		root.set_script(Furniture)
		root.furniture_id = str(item.id)
		root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var art_layers: Array = item.get("artLayers", [item.tiles])
		for layer_index: int in range(art_layers.size()):
			var visual := TileMapLayer.new()
			visual.name = "Visual" if layer_index == 0 else "ArtLayer%d" % layer_index
			visual.tile_set = tiles
			visual.position = Vector2(item.visualOffset[0], item.visualOffset[1])
			var art: Array = art_layers[layer_index]
			for y: int in range(art.size()):
				for x: int in range(art[y].size()):
					var gid := int(art[y][x])
					if gid > 0:
						var coordinates: Array = Catalog.atlas[str(gid)]
						visual.set_cell(Vector2i(x, y), 0, Vector2i(coordinates[0], coordinates[1]))
			root.add_child(visual)
			visual.owner = root
		root.add_child(collision_layer)
		collision_layer.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		var error := ResourceSaver.save(packed, str(item.scenePath))
		root.free()
		if error != OK:
			push_error("Could not save furniture: " + str(item.id))
			quit(1)
			return
	print("Generated ", data.items.size(), " reusable furniture scenes.")
	quit(0)
