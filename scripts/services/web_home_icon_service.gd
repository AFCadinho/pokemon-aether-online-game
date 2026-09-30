extends Node

## Mutable textures let existing synchronous UI consumers refresh without rebuilding
## PC slots, summaries or Pokédex cards when an on-demand image arrives.
const PokemonAssets := preload("res://scripts/data/pokemon_assets.gd")
const CACHE_LIMIT := 256
const CONCURRENCY := 4
const RETRY_SECONDS := 20.0
var _cache: Dictionary = {}
var _queue: Array[Dictionary] = []
var _active := 0
var _catalog: Dictionary = {}
var _catalog_loading := false
var _catalog_retry_at := 0.0
var _files: Dictionary = {}
var _visible: Array[Dictionary] = []
var _visibility_elapsed := 0.0

func get_icon(species: String, shiny := false, cropped := false) -> Texture2D:
	var key := "%s|%s" % [species.strip_edges().to_lower(), str(shiny)]
	if not _cache.has(key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		var placeholder := PokemonAssets.load_unknown_icon().get_image()
		var entry := {"species": species, "shiny": shiny, "full": ImageTexture.create_from_image(placeholder),
			"party": ImageTexture.create_from_image(placeholder), "loading": false, "ready": false, "retry_at": 0.0}
		_cache[key] = entry
	var entry: Dictionary = _cache[key]
	if not entry.loading and not entry.ready and _now() >= float(entry.retry_at):
		entry.loading = true
		_queue.append(entry)
		_drain.call_deferred()
	return entry.party if cropped else entry.full

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _drain() -> void:
	while _active < CONCURRENCY and not _queue.is_empty():
		_active += 1
		_load_entry(_queue.pop_front())

func _load_entry(entry: Dictionary) -> void:
	await _ensure_catalog()
	var image: Image
	for folder: String in (["shiny", "normal"] if entry.shiny else ["normal"]):
		var files: Dictionary = _catalog.get(folder, {})
		for candidate: String in PokemonAssets._get_home_sprite_names(str(entry.species)):
			if not files.has(candidate):
				continue
			image = await _load_image(str(files[candidate]))
			if image != null:
				break
		if image != null:
			break
	if image != null:
		apply_image(entry, image)
	entry.ready = image != null
	entry.loading = false
	entry.retry_at = _now() + RETRY_SECONDS
	_active -= 1
	_drain()

static func apply_image(entry: Dictionary, image: Image) -> void:
	(entry.full as ImageTexture).set_image(image)
	var bounds := PokemonAssets._get_visible_bounds(image)
	var party_image := image
	if bounds.size != Vector2i.ZERO:
		party_image = image.get_region(PokemonAssets._pad_bounds(bounds, image.get_size(), PokemonAssets.PARTY_ICON_CROP_PADDING))
	(entry.party as ImageTexture).set_image(party_image)

func _ensure_catalog() -> void:
	while _catalog_loading:
		await get_tree().process_frame
	if not _catalog.is_empty() or _now() < _catalog_retry_at:
		return
	_catalog_loading = true
	var bytes := await _download(_asset_url("home-icons/catalog.json"))
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary and parsed.get("normal") is Dictionary and parsed.get("shiny") is Dictionary:
		_catalog = parsed
	_catalog_retry_at = _now() + RETRY_SECONDS
	_catalog_loading = false

func _load_image(relative: String) -> Image:
	# Catalog entries are filenames, never arbitrary URLs or traversal paths.
	if not relative.begins_with("home-icons/") or ".." in relative or not relative.ends_with(".png"):
		return null
	while _files.has(relative) and _files[relative] == null:
		await get_tree().process_frame
	if _files.has(relative):
		return _files[relative] as Image
	_files[relative] = null
	var bytes := await _download(_asset_url(relative))
	var image := Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK or image.get_width() > 2048 or image.get_height() > 2048:
		_files.erase(relative)
		return null
	_files[relative] = image
	# Only a bounded set of decoded images is retained. UI textures survive eviction.
	if _files.size() > CACHE_LIMIT:
		for path: String in _files.keys():
			if _files[path] != null and path != relative:
				_files.erase(path)
				break
	return image

func _asset_url(relative: String) -> String:
	var origin := WebRuntime.api_base_url().trim_suffix("/api")
	var config := WebRuntime.web_release_config()
	var prefix := ""
	if not config.is_empty():
		prefix = "web/releases/%s/" % str(config.get("buildId", ""))
	return origin + "/" + prefix + relative

func _download(url: String) -> PackedByteArray:
	var request := HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 2 * 1024 * 1024
	add_child(request)
	if request.request(url) != OK:
		request.queue_free()
		return PackedByteArray()
	var result: Array = await request.request_completed
	request.queue_free()
	return result[3] as PackedByteArray if int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200 else PackedByteArray()


func bind_visible(control: TextureRect, species: String, shiny := false) -> void:
	control.texture = PokemonAssets.load_unknown_icon()
	_visible.append({"control": weakref(control), "species": species, "shiny": shiny})

func _process(delta: float) -> void:
	_visibility_elapsed += delta
	if _visibility_elapsed < 0.15:
		return
	_visibility_elapsed = 0.0
	for index in range(_visible.size() - 1, -1, -1):
		var entry: Dictionary = _visible[index]
		var control: TextureRect = entry.control.get_ref() as TextureRect
		if control == null:
			_visible.remove_at(index)
			continue
		if not control.is_visible_in_tree() or control.size == Vector2.ZERO:
			continue
		var rect := control.get_global_rect()
		var visible := rect.intersects(control.get_viewport_rect())
		var parent := control.get_parent()
		while visible and parent != null:
			if parent is ScrollContainer:
				visible = rect.intersects((parent as ScrollContainer).get_global_rect())
			parent = parent.get_parent()
		if visible:
			control.texture = get_icon(str(entry.species), bool(entry.shiny), true)
			_visible.remove_at(index)


func load_icon(species: String, shiny := false) -> Texture2D:
	var texture := get_icon(species, shiny)
	var key := "%s|%s" % [species.strip_edges().to_lower(), str(shiny)]
	var entry: Dictionary = _cache[key]
	while entry.loading:
		await get_tree().process_frame
	return texture
