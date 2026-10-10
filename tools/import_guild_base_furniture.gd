extends SceneTree

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")

func _init() -> void:
	var data := Catalog.load_data()
	var tiles: TileSet = load("res://assets/guild_base/furniture/furniture.tileset.tres")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/world/guild_base/furniture"))
	for item: Dictionary in data.items:
		var root := Node2D.new()
		root.name = str(item.id).to_pascal_case()
		root.set_script(Furniture)
		root.furniture_id = str(item.id)
		root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var visual := TileMapLayer.new()
		visual.name = "Visual"
		visual.tile_set = tiles
		visual.position = Vector2(item.visualOffset[0], item.visualOffset[1])
		for y: int in range(item.tiles.size()):
			for x: int in range(item.tiles[y].size()):
				var gid := int(item.tiles[y][x])
				if gid > 0:
					var coordinates: Array = Catalog.atlas[str(gid)]
					visual.set_cell(Vector2i(x, y), 0, Vector2i(coordinates[0], coordinates[1]))
		root.add_child(visual)
		visual.owner = root
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
