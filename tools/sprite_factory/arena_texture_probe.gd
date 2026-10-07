extends SceneTree
## Decode candidate texture payloads for an offline comparison, not gameplay.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or not ProjectSettings.load_resource_pack(args[0], false):
		push_error("Expected readable pack, texture list and output directory")
		quit(1)
		return
	var textures: Array = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	DirAccess.make_dir_recursive_absolute(args[2])
	var rows := []
	for item: Dictionary in textures:
		var path := "res://" + str(item.path)
		var texture: Texture2D = load(path)
		assert(texture != null)
		var image := texture.get_image()
		var row := {"path":item.path, "width": image.get_width(), "height":image.get_height(),
			"format":image.get_format(), "compressed":image.is_compressed(), "image_bytes":image.get_data_size(),
			"mipmaps":image.get_mipmap_count()}
		var result := image.decompress() if image.is_compressed() else OK
		row.decode_error = result
		if result == OK:
			image.convert(Image.FORMAT_RGBA8)
			var name: String = str(item.path).get_file().split(".png-")[0] + ".png"
			assert(image.save_png(args[2].path_join(name)) == OK)
			row.decoded = name
		rows.append(row)
	FileAccess.open(args[2].path_join("textures.json"), FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("ARENA_TEXTURE_PROBE_OK ", rows.size())
	quit()
