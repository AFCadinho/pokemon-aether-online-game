extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config_path := OS.get_environment("POKEAETHER_DISTRIBUTION_RUNTIME_CONFIG")
	if config_path.is_empty():
		push_error("Set POKEAETHER_DISTRIBUTION_RUNTIME_CONFIG.")
		quit(2)
		return
	var payload = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not payload is Dictionary or not payload.has("candidates"):
		push_error("Invalid runtime benchmark config.")
		quit(3)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(64, 64))
		DisplayServer.window_set_position(Vector2i(10000, 10000))
	Engine.max_fps = 60
	var output := {
		"schema": 1,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"candidates": [],
	}
	for candidate_value in payload.candidates:
		var candidate: Dictionary = candidate_value
		var measured := await _measure_candidate(candidate)
		output.candidates.append(measured)
		print("measured %s" % candidate.label)
	var result_file := FileAccess.open(str(payload.result), FileAccess.WRITE)
	if result_file == null:
		push_error("Could not create runtime result file.")
		quit(4)
		return
	result_file.store_string(JSON.stringify(output, "  ") + "\n")
	result_file.close()
	quit()


func _measure_candidate(candidate: Dictionary) -> Dictionary:
	var static_memory_before := OS.get_static_memory_usage()
	var passes := []
	for pass_index in range(2):
		var pass_groups := []
		for group_value in candidate.groups:
			var group: Dictionary = group_value
			pass_groups.append(await _load_group(candidate, group, false))
		passes.append(pass_groups)
	var playback := {}
	if candidate.has("playback"):
		playback = await _play(candidate, candidate.playback)
	return {
		"label": candidate.label,
		"kind": candidate.kind,
		"passes": passes,
		"playback": playback,
		"static_memory_before_bytes": static_memory_before,
		"static_memory_after_bytes": OS.get_static_memory_usage(),
		"static_memory_peak_bytes": OS.get_static_memory_peak_usage(),
	}


func _load_group(candidate: Dictionary, group: Dictionary, keep_textures: bool) -> Dictionary:
	var textures: Array[Texture2D] = []
	var file_usec := 0
	var decode_usec := 0
	var upload_usec := 0
	var stored_bytes := 0
	var decoded_bytes := 0
	var rss_before := _rss_bytes()
	for file_value in group.files:
		var path := str(file_value)
		var size_file := FileAccess.open(path, FileAccess.READ)
		if size_file == null:
			return {"error": "Could not stat %s" % path}
		stored_bytes += size_file.get_length()
		size_file.close()
		if candidate.kind == "resource":
			var load_started := Time.get_ticks_usec()
			var texture = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			file_usec += Time.get_ticks_usec() - load_started
			if not texture is Texture2D:
				return {"error": "Could not load texture resource %s" % path}
			textures.append(texture)
			decoded_bytes += int(group.get("block_bytes_per_file", 0))
		else:
			var file_started := Time.get_ticks_usec()
			var bytes := FileAccess.get_file_as_bytes(path)
			file_usec += Time.get_ticks_usec() - file_started
			var image := Image.new()
			var decode_started := Time.get_ticks_usec()
			var error := image.load_png_from_buffer(bytes) if candidate.kind == "png" else image.load_webp_from_buffer(bytes)
			decode_usec += Time.get_ticks_usec() - decode_started
			if error != OK:
				return {"error": "Could not decode %s" % path}
			decoded_bytes += image.get_width() * image.get_height() * 4
			var upload_started := Time.get_ticks_usec()
			textures.append(ImageTexture.create_from_image(image))
			RenderingServer.force_sync()
			upload_usec += Time.get_ticks_usec() - upload_started
	var rss_after := _rss_bytes()
	if not keep_textures:
		textures.clear()
	return {
		"group": group.label,
		"files": group.files.size(),
		"stored_bytes": stored_bytes,
		"decoded_or_block_bytes": decoded_bytes,
		"file_usec": file_usec,
		"decode_usec": decode_usec,
		"upload_usec": upload_usec,
		"rss_delta_bytes": max(0, rss_after - rss_before),
		"rss_before_bytes": rss_before,
		"rss_after_bytes": rss_after,
	}


func _play(candidate: Dictionary, playback: Dictionary) -> Dictionary:
	var textures: Array[Texture2D] = []
	for file_value in playback.files:
		var path := str(file_value)
		if candidate.kind == "resource":
			var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if not loaded is Texture2D:
				return {"error": "Could not load playback resource %s" % path}
			textures.append(loaded)
		else:
			var bytes := FileAccess.get_file_as_bytes(path)
			var image := Image.new()
			var error := image.load_png_from_buffer(bytes) if candidate.kind == "png" else image.load_webp_from_buffer(bytes)
			if error != OK:
				return {"error": "Could not decode playback page %s" % path}
			textures.append(ImageTexture.create_from_image(image))
	RenderingServer.force_sync()
	var sprite := Sprite2D.new()
	get_root().add_child(sprite)
	var frames: Array[AtlasTexture] = []
	var frame_count := int(playback.frame_count)
	var cell_width := int(playback.cell_width)
	var cell_height := int(playback.cell_height)
	var frames_per_page := int(playback.frames_per_page)
	var columns := int(playback.columns)
	for index in range(frame_count):
		var page_index := index / frames_per_page
		var local_index := index % frames_per_page
		var atlas := AtlasTexture.new()
		atlas.atlas = textures[page_index]
		atlas.region = Rect2(
			(local_index % columns) * cell_width,
			(local_index / columns) * cell_height,
			cell_width,
			cell_height
		)
		frames.append(atlas)
	var durations := []
	for warmup in range(60):
		sprite.texture = frames[warmup % frames.size()]
		await process_frame
	for iteration in range(360):
		var started := Time.get_ticks_usec()
		sprite.texture = frames[iteration % frames.size()]
		await process_frame
		durations.append(Time.get_ticks_usec() - started)
	sprite.queue_free()
	durations.sort()
	var over_20ms := 0
	for duration in durations:
		if duration > 20000:
			over_20ms += 1
	return {
		"frames": durations.size(),
		"median_usec": durations[durations.size() / 2],
		"p95_usec": durations[int(durations.size() * 0.95)],
		"p99_usec": durations[int(durations.size() * 0.99)],
		"maximum_usec": durations[-1],
		"frames_over_20ms": over_20ms,
	}


func _rss_bytes() -> int:
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null:
		return 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("VmRSS:"):
			var fields := line.replace("\t", " ").split(" ", false)
			if fields.size() >= 2:
				return int(fields[1]) * 1024
	return 0
