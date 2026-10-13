extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
## Deliberately authored mip bytes and invisible RGB must survive both codecs.
func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	ProjectSettings.set_setting("rendering/textures/webp_compression/compression_method", 6)
	ProjectSettings.set_setting("rendering/textures/webp_compression/lossless_compression_factor", 100.0)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var cases := 0
	for format in [Image.FORMAT_L8, Image.FORMAT_LA8, Image.FORMAT_R8, Image.FORMAT_RG8, Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		var empty := Image.create_empty(4, 4, true, format)
		var bytes := empty.get_data()
		for i in bytes.size(): bytes[i] = (i * 37 + 19) % 256
		if format == Image.FORMAT_RGBA8:
			# Keep nonzero colour under alpha=0, including an authored low mip.
			for i in range(3, bytes.size(), 8): bytes[i] = 0
		var image := Image.create_from_data(4, 4, true, format, bytes)
		var texture := ImageTexture.create_from_image(image)
		texture.resource_name = "authored-mip-test"
		texture.set_meta("proof", {"keep": true, "kind": "opaque-and-invisible-colour"})
		assert(texture.get_image().get_data() == bytes, "Source GPU roundtrip changed test pixels")
		var report := encode_texture(texture, args[0].path_join(str(format)), "textures/test.res")
		assert(not report.has("hold"))
		for codec in ["png", "webp"]:
			assert(report.codecs[codec].exact and report.codecs[codec].mips.size() == 3)
			var candidate := ResourceLoader.load(report.codecs[codec].path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			assert(normalized_signature(candidate) == normalized_signature(texture))
		# Regenerated mips and a changed colour hidden by alpha must be rejected.
		var regenerated := image.duplicate() as Image
		regenerated.clear_mipmaps()
		assert(regenerated.generate_mipmaps() == OK)
		var regenerated_texture := ImageTexture.create_from_image(regenerated)
		regenerated_texture.resource_name = texture.resource_name
		regenerated_texture.set_meta("proof", texture.get_meta("proof"))
		assert(normalized_signature(regenerated_texture) != normalized_signature(texture))
		var changed := bytes.duplicate()
		changed[0] ^= 1
		var bad := ImageTexture.create_from_image(Image.create_from_data(4, 4, true, format, changed))
		bad.resource_name = texture.resource_name
		bad.set_meta("proof", texture.get_meta("proof"))
		assert(normalized_signature(bad) != normalized_signature(texture))
		cases += 1
	var override := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
	override.set_size_override(Vector2i(8, 8))
	assert(encode_texture(override, args[0], "textures/override.res").hold == "non_native_texture_size_override")
	print("LOSSLESS_TEXTURE_UNIT_OK formats=", cases, " mip_chains=12 hidden_colour=true altered_pixels_rejected=true regenerated_mips_rejected=true override_held=true")
	quit()
