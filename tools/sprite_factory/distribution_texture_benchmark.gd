extends SceneTree


func _initialize() -> void:
	var config_path := OS.get_environment("POKEAETHER_DISTRIBUTION_BENCHMARK_CONFIG")
	if config_path.is_empty():
		push_error("Set POKEAETHER_DISTRIBUTION_BENCHMARK_CONFIG.")
		quit(2)
		return
	var payload = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not payload is Dictionary or payload.get("mode") != "encode":
		push_error("Invalid distribution benchmark config.")
		quit(3)
		return
	var results := []
	var jobs: Array = payload.get("jobs", [])
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		var result := _encode_job(job, int(payload.get("uastc_level", 0)))
		if result.has("error"):
			push_error(str(result.error))
			quit(4)
			return
		results.append(result)
		if (index + 1) % 50 == 0 or index + 1 == jobs.size():
			print("basis encoded %d/%d atlas pages" % [index + 1, jobs.size()])
	var report := {
		"schema": 1,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"uastc_level": int(payload.get("uastc_level", 0)),
		"jobs": results,
	}
	var result_file := FileAccess.open(str(payload.result), FileAccess.WRITE)
	if result_file == null:
		push_error("Could not create result file: %s" % payload.result)
		quit(5)
		return
	result_file.store_string(JSON.stringify(report, "  ") + "\n")
	result_file.close()
	quit()


func _encode_job(job: Dictionary, uastc_level: int) -> Dictionary:
	var image := Image.load_from_file(str(job.source))
	if image == null or image.is_empty():
		return {"error": "Could not load %s" % job.source}
	var output := str(job.output)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var encoded := _create_texture(
		image,
		PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL,
		uastc_level,
		1.0,
		output,
		bool(job.get("sample", false))
	)
	if encoded.has("error"):
		return encoded
	var result := {
		"key": job.key,
		"source": job.source,
		"width": image.get_width(),
		"height": image.get_height(),
		"basis_uastc": encoded,
	}
	if bool(job.get("sample", false)):
		result["samples"] = {}
		var stem := output.trim_suffix(".res")
		result.samples["basis_uastc_level4"] = _create_texture(
			image,
			PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL,
			4,
			1.0,
			stem + "-uastc-level4.res",
			true
		)
		result.samples["bptc"] = _create_texture(
			image, PortableCompressedTexture2D.COMPRESSION_MODE_BPTC, 0, 1.0, stem + "-bptc.res", true
		)
		result.samples["astc"] = _create_texture(
			image, PortableCompressedTexture2D.COMPRESSION_MODE_ASTC, 0, 1.0, stem + "-astc.res", true
		)
		result.samples["etc2"] = _create_texture(
			image, PortableCompressedTexture2D.COMPRESSION_MODE_ETC2, 0, 1.0, stem + "-etc2.res", true
		)
	return result


func _create_texture(
	image: Image,
	compression_mode: PortableCompressedTexture2D.CompressionMode,
	uastc_level: int,
	lossy_quality: float,
	output: String,
	save_decoded: bool,
) -> Dictionary:
	var texture := PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true
	if compression_mode == PortableCompressedTexture2D.COMPRESSION_MODE_BASIS_UNIVERSAL:
		texture.set_basisu_compressor_params(uastc_level, 0.0)
	var started := Time.get_ticks_usec()
	texture.create_from_image(image, compression_mode, false, lossy_quality)
	var encode_usec := Time.get_ticks_usec() - started
	var save_error := ResourceSaver.save(texture, output)
	if save_error != OK:
		return {"error": "Could not save %s: %s" % [output, error_string(save_error)]}
	var decoded := texture.get_image()
	var stored_format := decoded.get_format()
	var decoded_data_bytes := decoded.get_data_size()
	var result := {
		"path": output,
		"bytes": FileAccess.get_file_as_bytes(output).size(),
		"encode_usec": encode_usec,
		"stored_image_format": stored_format,
		"stored_data_bytes": decoded_data_bytes,
	}
	if save_decoded:
		if decoded.is_compressed():
			var decompress_error := decoded.decompress()
			if decompress_error != OK:
				return {"error": "Could not decompress sample %s: %s" % [output, error_string(decompress_error)]}
		var decoded_path := output + ".decoded.png"
		var png_error := decoded.save_png(decoded_path)
		if png_error != OK:
			return {"error": "Could not save decoded sample %s" % decoded_path}
		result["decoded_path"] = decoded_path
	return result
