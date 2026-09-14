extends Node

const IDLE_ANIMATION := "idle"
const MAX_RESPONSE_BYTES := 4 * 1024 * 1024
const CACHE_LIMIT := 96
const DOWNLOAD_ATTEMPTS := 3
const DOWNLOAD_RETRY_SECONDS := 0.35
const PREFETCH_CONCURRENCY := 4

class LoadTicket extends RefCounted:
	signal completed
	var result: Dictionary = {}

var _cache: Dictionary = {}
var _in_flight: Dictionary = {}
var _prefetch_queue: Array[Dictionary] = []
var _prefetch_queued_keys: Dictionary = {}
var _prefetch_active := 0
var _release_config_cache: Dictionary = {}
var _release_config_ticket: LoadTicket


func is_available() -> bool:
	return OS.has_feature("web")


func load_frames(
	asset_id: String, side: String, is_shiny: bool = false, sprite_style: String = "animated"
) -> Dictionary:
	if not is_available():
		return {}
	var identity := _sprite_identity(asset_id, side, is_shiny, sprite_style)
	var cache_key := str(identity.get("cache_key", ""))
	if cache_key == "":
		return {}
	if _cache.has(cache_key):
		return _cache[cache_key]
	if _in_flight.has(cache_key):
		var existing_ticket := _in_flight[cache_key] as LoadTicket
		await existing_ticket.completed
		return existing_ticket.result

	var ticket := LoadTicket.new()
	_in_flight[cache_key] = ticket
	var result := await _load_frames_uncached(identity)
	if not result.is_empty():
		_remember(cache_key, result)
	ticket.result = result
	_in_flight.erase(cache_key)
	ticket.completed.emit()
	return result


func get_cached_frames(
	asset_id: String, side: String, is_shiny: bool = false, sprite_style: String = "animated"
) -> Dictionary:
	var identity := _sprite_identity(asset_id, side, is_shiny, sprite_style)
	var cache_key := str(identity.get("cache_key", ""))
	return _cache.get(cache_key, {}) if cache_key != "" else {}


func prefetch(entries: Array) -> void:
	if not is_available():
		return
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var identity := _sprite_identity(
			str(entry.get("species", entry.get("asset_id", ""))),
			str(entry.get("side", "front")),
			bool(entry.get("shiny", false)),
			str(entry.get("style", "animated"))
		)
		var cache_key := str(identity.get("cache_key", ""))
		if cache_key == "" or _cache.has(cache_key) or _in_flight.has(cache_key) or _prefetch_queued_keys.has(cache_key):
			continue
		var queued_entry := entry.duplicate(true)
		queued_entry["cache_key"] = cache_key
		_prefetch_queue.append(queued_entry)
		_prefetch_queued_keys[cache_key] = true
	_drain_prefetch_queue()


func prefetch_and_wait(entries: Array) -> void:
	prefetch(entries)
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		await load_frames(
			str(entry.get("species", entry.get("asset_id", ""))),
			str(entry.get("side", "front")),
			bool(entry.get("shiny", false)),
			str(entry.get("style", "animated"))
		)


func _drain_prefetch_queue() -> void:
	while _prefetch_active < PREFETCH_CONCURRENCY and not _prefetch_queue.is_empty():
		var entry := _prefetch_queue.pop_front() as Dictionary
		_prefetch_active += 1
		_run_prefetch.call_deferred(entry)


func _run_prefetch(entry: Dictionary) -> void:
	await load_frames(
		str(entry.get("species", entry.get("asset_id", ""))),
		str(entry.get("side", "front")),
		bool(entry.get("shiny", false)),
		str(entry.get("style", "animated"))
	)
	_prefetch_queued_keys.erase(str(entry.get("cache_key", "")))
	_prefetch_active = maxi(_prefetch_active - 1, 0)
	_drain_prefetch_queue()


func _sprite_identity(
	asset_id: String, side: String, is_shiny: bool, sprite_style: String
) -> Dictionary:
	var catalog_style := _catalog_style(sprite_style)
	var normalized_id := _normalize_segment(asset_id)
	if catalog_style == "" or normalized_id == "":
		return {}
	var side_folder := ("shiny_" if is_shiny else "") + ("back" if side == "back" else "front")
	return {
		"catalog_style": catalog_style,
		"normalized_id": normalized_id,
		"side_folder": side_folder,
		"cache_key": "%s/%s/%s" % [catalog_style, side_folder, normalized_id],
	}


func _load_frames_uncached(identity: Dictionary) -> Dictionary:
	var catalog_style := str(identity.get("catalog_style", ""))
	var normalized_id := str(identity.get("normalized_id", ""))
	var side_folder := str(identity.get("side_folder", ""))

	var release := await _get_release_config()
	var configured_styles: Variant = release.get("spriteStyles", {})
	var base_root := ""
	if configured_styles is Dictionary:
		var configured_bases: Variant = (configured_styles as Dictionary).get(catalog_style, {})
		if configured_bases is Dictionary:
			base_root = str((configured_bases as Dictionary).get(side_folder, "")).trim_suffix("/")
	if base_root == "":
		var route := "/pokemon-assets/gen5" if catalog_style == "pixel" else "/pokemon-assets/battle"
		base_root = WebRuntime.api_base_url().trim_suffix("/api") + route + "/" + side_folder
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
	var visual_bounds := _calculate_visual_bounds(metadata, image)
	var frames := _build_frames(metadata, image)
	if frames == null:
		return {}
	var result := {
		"frames": frames,
		"style": catalog_style,
		"render_scale": maxf(float(metadata.get("render_scale", metadata.get("scale", 1.0))), 1.0),
		"frame_size": Vector2(float(metadata.get("frame_width", 0)), float(metadata.get("frame_height", 0))),
		"visual_bounds": visual_bounds,
	}
	return result


func _get_release_config() -> Dictionary:
	var bridge_config := WebRuntime.web_release_config()
	if _has_sprite_styles(bridge_config):
		_release_config_cache = bridge_config
		return bridge_config
	if _has_sprite_styles(_release_config_cache):
		return _release_config_cache
	if _release_config_ticket != null:
		var existing_ticket := _release_config_ticket
		await existing_ticket.completed
		return existing_ticket.result

	var ticket := LoadTicket.new()
	_release_config_ticket = ticket
	var result: Dictionary = {}
	var origin := WebRuntime.api_base_url().trim_suffix("/api")
	if origin != "":
		var response := await _download(origin + "/web-release-config.json")
		if not response.is_empty():
			var parsed: Variant = JSON.parse_string(
				(response.body as PackedByteArray).get_string_from_utf8()
			)
			if parsed is Dictionary and _has_sprite_styles(parsed as Dictionary):
				result = parsed as Dictionary
				_release_config_cache = result
	ticket.result = result
	_release_config_ticket = null
	ticket.completed.emit()
	return result


func _has_sprite_styles(config: Dictionary) -> bool:
	var styles: Variant = config.get("spriteStyles", {})
	return styles is Dictionary and not (styles as Dictionary).is_empty()


func _download(url: String) -> Dictionary:
	for attempt: int in range(DOWNLOAD_ATTEMPTS):
		var result := await _download_once(url)
		if not result.is_empty():
			return result
		if attempt + 1 < DOWNLOAD_ATTEMPTS:
			await get_tree().create_timer(DOWNLOAD_RETRY_SECONDS).timeout
	return {}


func _download_once(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	# Let the browser select its normal GET headers. A custom Accept header adds
	# no value here and can trigger an unnecessary R2 CORS preflight in stricter
	# browser/network combinations.
	var start_error := request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
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


func _catalog_style(sprite_style: String) -> String:
	if sprite_style == "static":
		return ""
	return "pixel" if sprite_style == "pixel" else "animated"


func _build_frames(metadata: Dictionary, image: Image) -> SpriteFrames:
	var definitions: Variant = metadata.get("frames", [])
	if not (definitions is Array) or (definitions as Array).is_empty():
		return null
	var result := SpriteFrames.new()
	result.remove_animation("default")
	result.add_animation(IDLE_ANIMATION)
	result.set_animation_loop(IDLE_ANIMATION, true)
	result.set_animation_speed(IDLE_ANIMATION, maxf(float(metadata.get("speed", 1.0)), 0.01))
	# Keep one GPU texture per downloaded sheet. Creating a separate ImageTexture
	# for every frame is especially costly in WebGL (some species have 96+ frames)
	# and can leave the immediate HOME fallback visible while textures are built.
	var sheet_texture := ImageTexture.create_from_image(image)
	if sheet_texture == null:
		return null
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
		var texture := AtlasTexture.new()
		texture.atlas = sheet_texture
		texture.region = Rect2(region)
		# Battle sprites use linear filtering. Clip sampling to this atlas region
		# so transparent frame edges cannot borrow dark pixels from a neighbouring
		# animation frame and render them as long horizontal or vertical seams.
		texture.filter_clip = true
		result.add_frame(IDLE_ANIMATION, texture, maxf(float(definition.get("duration", 1.0)), 0.01))
	return result if result.get_frame_count(IDLE_ANIMATION) > 0 else null


func _calculate_visual_bounds(metadata: Dictionary, image: Image) -> Rect2:
	var definitions: Variant = metadata.get("frames", [])
	if image == null or not (definitions is Array):
		return Rect2()
	var combined_bounds := Rect2()
	var has_bounds := false
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
		var used_rect := image.get_region(region).get_used_rect()
		if not used_rect.has_area():
			continue
		var bounds := Rect2(Vector2(used_rect.position), Vector2(used_rect.size))
		combined_bounds = combined_bounds.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined_bounds if has_bounds else Rect2()


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
