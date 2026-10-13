extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
## Read externally encoded exact WebP mip chains; Godot decodes every byte.
func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3 and args[0] == "encode")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	var asset: Dictionary = config.asset
	var checked := Pair.inspect(config.path, asset)
	assert(str(checked.error).is_empty())
	assert(Pair.mount_checked(config.path, asset, checked).is_empty())
	var textures := []
	for row: Dictionary in config.buffers:
		var original := ResourceLoader.load(str(asset.pair_manifest.resource_root).path_join(row.path), "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(original is ImageTexture)
		var buffer := FileAccess.get_file_as_bytes(row.buffer_path)
		assert(Audit.digest(buffer) == row.buffer_sha256)
		var texture := PortableCompressedTexture2D.new()
		texture.keep_compressed_buffer = true
		texture.call("_set_data", buffer)
		texture.resource_name = original.resource_name
		texture.resource_local_to_scene = original.resource_local_to_scene
		texture.set_size_override(original.get_size())
		for name in original.get_meta_list(): texture.set_meta(name, original.get_meta(name))
		assert(texture_state(texture) == texture_state(original), "Strict WebP changed decoded texture data")
		var path := directory.path_join(row.path)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) == OK)
		var persisted := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		assert(texture_state(persisted) == texture_state(original))
		textures.append({"path": row.path, "native_path": path, "state_signature": normalized_signature(texture_state(texture))})
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "complete": true, "prototype_only": true, "production_approved": false,
		"asset_id": asset.asset_id, "pack_sha256": asset.sha256, "input_sha256": FileAccess.get_sha256(args[1]),
		"script_sha256": FileAccess.get_sha256(get_script().resource_path), "textures": textures}) + "\n")
	file.close()
	print("LOSSLESS_TEXTURE_ENGINE_OK strict-webp ",asset.asset_id," textures=",textures.size())
	quit()
