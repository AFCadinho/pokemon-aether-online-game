extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
## Full-catalog texture-only study; scene and animation bytes stay unchanged.
func encode_texture(texture: Texture2D, directory: String, relative: String) -> Dictionary:
	assert(texture is ImageTexture)
	var image := texture.get_image()
	var state := texture_state(texture)
	var row := {"path": relative, "image_signature": Audit.image_signature(image), "state_signature": normalized_signature(state),
		"width": image.get_width(), "height": image.get_height(), "format": image.get_format(), "mipmaps": image.get_mipmap_count(),
		"decoded_bytes": image.get_data_size(), "codecs": {}}
	# PNG/WebP are 8-bit codecs. Compressed or higher precision source images
	# remain untouched; no lossy conversion is made to force eligibility.
	if image.is_compressed() or image.get_format() > Image.FORMAT_RGBA8:
		row["hold"] = "source_format_outside_lossless_8bit_scope"
		return row
	if texture.get_size() != Vector2(image.get_width(), image.get_height()):
		row["hold"] = "non_native_texture_size_override"
		return row
	for codec in ["png"]:
		var header := PackedByteArray()
		header.resize(20)
		header.encode_u16(0, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		# Godot 4.6 PortableCompressedTexture2D::DataFormat: PNG=2, WebP=3.
		header.encode_u16(2, 2 if codec == "png" else 3)
		header.encode_u32(4, image.get_format())
		header.encode_u32(8, image.get_mipmap_count() + 1)
		header.encode_u32(12, image.get_width())
		header.encode_u32(16, image.get_height())
		var mips := []
		var exact := true
		var started := Time.get_ticks_usec()
		for level in image.get_mipmap_count() + 1:
			var original: Image = mip_image(image, level)
			var bytes: PackedByteArray = original.save_png_to_buffer() if codec == "png" else original.save_webp_to_buffer(false, 1.0)
			assert(not bytes.is_empty())
			var decoded := Image.new()
			assert((decoded.load_png_from_buffer(bytes) if codec == "png" else decoded.load_webp_from_buffer(bytes)) == OK)
			decoded.convert(original.get_format())
			var same := Audit.image_signature(decoded) == Audit.image_signature(original)
			exact = exact and same
			mips.append({"level": level, "width": original.get_width(), "height": original.get_height(), "encoded_bytes": bytes.size(),
				"source_sha256": Audit.digest(original.get_data()), "decoded_sha256": Audit.digest(decoded.get_data()), "exact": same})
			if codec == "png":
				# Native PNG resources require Godot's four-byte "PNG " wrapper;
				# load_png_from_buffer above intentionally checks the standard PNG.
				var wrapped := "PNG ".to_utf8_buffer()
				wrapped.append_array(bytes)
				bytes = wrapped
			var size := PackedByteArray()
			size.resize(4)
			size.encode_u32(0, bytes.size())
			header.append_array(size)
			header.append_array(bytes)
		var result := {"exact": exact, "mips": mips, "encode_usec": Time.get_ticks_usec() - started}
		if exact:
			var candidate := PortableCompressedTexture2D.new()
			candidate.keep_compressed_buffer = true
			candidate.call("_set_data", header)
			candidate.resource_name = texture.resource_name
			candidate.resource_local_to_scene = texture.resource_local_to_scene
			candidate.set_size_override(texture.get_size())
			for name in texture.get_meta_list(): candidate.set_meta(name, texture.get_meta(name))
			assert(texture_state(candidate) == state, "Portable texture decoded state changed")
			var path := directory.path_join(codec).path_join(relative)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			assert(ResourceSaver.save(candidate, path, ResourceSaver.FLAG_COMPRESS) == OK)
			assert(ResourceLoader.get_dependencies(path).is_empty())
			var persisted := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			assert(persisted != null and texture_state(persisted) == state, "Saved texture roundtrip changed pixels or mips")
			result["path"] = path
		row.codecs[codec] = result
	return row

func _run() -> void:
	assert(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility")
	PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	var asset: Dictionary = config.asset
	var checked := Pair.inspect(config.path, asset)
	assert(str(checked.error).is_empty(), str(checked.error))
	assert(Pair.mount_checked(config.path, asset, checked).is_empty())
	var rows := []
	for member: Dictionary in asset.pair_manifest.files:
		if not str(member.path).begins_with("textures/"): continue
		var texture := ResourceLoader.load(str(asset.pair_manifest.resource_root).path_join(member.path), "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(texture != null)
		if args[0] == "encode":
			rows.append(encode_texture(texture, directory, member.path))
		else:
			var duplicate := texture.duplicate(true) as Texture2D
			assert(duplicate != null and texture_state(duplicate) == texture_state(texture), "Cold duplicate changed pixels")
			rows.append({"path": member.path, "state_signature": normalized_signature(texture_state(texture)), "deep_duplicate_exact": true})
		if rows.size() % 16 == 0: await process_frame
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "complete": true, "prototype_only": true, "production_approved": false,
		"asset_id": asset.asset_id, "pack_sha256": asset.sha256, "input_sha256": FileAccess.get_sha256(args[1]),
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "textures": rows}) + "\n")
	file.close()
	print("LOSSLESS_TEXTURE_ENGINE_OK full-audit ", args[0], " ", asset.asset_id, " textures=",rows.size())
	quit()
