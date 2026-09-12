extends Node

const ASSET_BASE := "/pokemon-assets/gen5"
const IDLE_ANIMATION := "idle"
const MAX_RESPONSE_BYTES := 4 * 1024 * 1024
const CACHE_LIMIT := 96

var _cache: Dictionary = {}


func is_available() -> bool:
	return OS.has_feature("web")


func load_frames(asset_id: String, side: String, is_shiny: bool = false) -> Dictionary:
	if not is_available():
		return {}
	var normalized_id := _normalize_segment(asset_id)
	var side_folder := ("shiny_" if is_shiny else "") + ("back" if side == "back" else "front")
	if normalized_id == "":
		return {}
	var cache_key := "%s/%s" % [side_folder, normalized_id]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var release := WebRuntime.web_release_config()
	var configured_bases: Variant = release.get("spriteBases", {})
	var base_root := ""
	if configured_bases is Dictionary:
		base_root = str((configured_bases as Dictionary).get(side_folder, "")).trim_suffix("/")
	if base_root == "":
		base_root = WebRuntime.api_base_url().trim_suffix("/api") + ASSET_BASE + "/" + side_folder
	if base_root == "":
		return {}
	var base_url := "%s/%s" % [base_root, normalized_id]
	var metadata_result := await _download(base_url + "/animation.json")
	if metadata_result.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string((metadata_result.body as PackedByteArray).get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	var metadata := parsed as Dictionary
	var image_name := str(metadata.get("image", "sheet.png"))
	if image_name != "sheet.png":
		return {}
	var image_result := await _download(base_url + "/sheet.png")
	if image_result.is_empty():
		return {}
	var image := Image.new()
	if image.load_png_from_buffer(image_result.body as PackedByteArray) != OK:
		return {}
	var frames := _build_frames(metadata, image)
	if frames == null:
		return {}
	var result := {
		"frames": frames,
		"render_scale": maxf(float(metadata.get("render_scale", metadata.get("scale", 1.0))), 1.0),
		"frame_size": Vector2(float(metadata.get("frame_width", 0)), float(metadata.get("frame_height", 0))),
	}
	_remember(cache_key, result)
	return result


func _download(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	var start_error := request.request(url, PackedStringArray(["Accept: application/json,image/png"]), HTTPClient.METHOD_GET)
	if start_error != OK:
		request.queue_free()
		return {}
	var completed: Array = await request.request_completed
	request.queue_free()
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
		return {}
	var body := completed[3] as PackedByteArray
	if body.is_empty() or body.size() > MAX_RESPONSE_BYTES:
		return {}
	return {"body": body}


func _build_frames(metadata: Dictionary, image: Image) -> SpriteFrames:
	var definitions: Variant = metadata.get("frames", [])
	if not (definitions is Array) or (definitions as Array).is_empty():
		return null
	var result := SpriteFrames.new()
	result.remove_animation("default")
	result.add_animation(IDLE_ANIMATION)
	result.set_animation_loop(IDLE_ANIMATION, true)
	result.set_animation_speed(IDLE_ANIMATION, maxf(float(metadata.get("speed", 1.0)), 0.01))
	for definition_value: Variant in definitions as Array:
		if not (definition_value is Dictionary):
			continue
		var definition := definition_value as Dictionary
		var region := Rect2i(
			int(definition.get("x", 0)), int(definition.get("y", 0)),
			int(definition.get("w", metadata.get("frame_width", 0))),
			int(definition.get("h", metadata.get("frame_height", 0)))
		)
		if region.size.x <= 0 or region.size.y <= 0 or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
			continue
		var texture := ImageTexture.create_from_image(image.get_region(region))
		result.add_frame(IDLE_ANIMATION, texture, maxf(float(definition.get("duration", 1.0)), 0.01))
	return result if result.get_frame_count(IDLE_ANIMATION) > 0 else null


func _remember(key: String, value: Dictionary) -> void:
	if _cache.size() >= CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
	_cache[key] = value


func _normalize_segment(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	var safe := ""
	for character in normalized:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			safe += character
	return safe.strip_edges().trim_prefix("-").trim_suffix("-")
