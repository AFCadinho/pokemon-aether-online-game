extends Node
## Immutable release assets share a persistent, bounded Android cache.
const Cache := preload("res://scripts/services/mobile_asset_cache.gd")
var cache := Cache.new()
var _pending: Dictionary = {}
var _catalog: Dictionary = {}
var _catalog_loading := false
var _catalog_retry_at := 0

func fetch_url(url: String, sha := "", limit := 4 * 1024 * 1024) -> String:
	if not url.begins_with("https://") and not url.begins_with("http://127.0.0.1:"):
		return ""
	var cached := cache.read_path(url, sha, limit)
	if cached != "":
		return cached
	while _pending.has(url):
		await get_tree().process_frame
		cached = cache.read_path(url, sha, limit)
		if not _pending.has(url):
			return cached
	_pending[url] = true
	var request := HTTPRequest.new()
	request.timeout = 90.0 if limit > 4 * 1024 * 1024 else 15.0
	request.body_size_limit = limit
	request.download_file = cache.path_for(url) + ".partial"
	add_child(request)
	var path := ""
	if request.request(url) == OK:
		var result: Array = await request.request_completed
		if int(result[0]) == HTTPRequest.RESULT_SUCCESS and int(result[1]) == 200:
			path = cache.commit(url, request.download_file, sha, limit)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(request.download_file))
	request.queue_free()
	_pending.erase(url)
	return path

func release_prefix() -> String:
	var config: Dictionary = await get_tree().root.get_node("WebPokemonSpriteService")._get_release_config()
	var build := str(config.get("buildId", ""))
	if build == "" or "/" in build or ".." in build:
		return ""
	return get_tree().root.get_node("WebPokemonSpriteService")._asset_origin() + "/web/releases/" + build + "/"

func fetch(relative: String) -> String:
	if relative.begins_with("/") or ".." in relative or ":" in relative:
		return ""
	await _ensure_catalog()
	var entry: Variant = _catalog.get(relative)
	if not entry is Dictionary:
		return ""
	var prefix: String = await release_prefix()
	if prefix == "":
		return ""
	var segments := relative.split("/")
	for index in segments.size():
		segments[index] = segments[index].uri_encode()
	return await fetch_url(prefix + "/".join(segments), str(entry.sha256), int(entry.size))

func _ensure_catalog() -> void:
	while _catalog_loading:
		await get_tree().process_frame
	if not _catalog.is_empty() or Time.get_ticks_msec() < _catalog_retry_at:
		return
	_catalog_loading = true
	var prefix: String = await release_prefix()
	if prefix != "":
		var path: String = await fetch_url(prefix + "mobile-assets/catalog.json", "", 2 * 1024 * 1024)
		if path != "":
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				for key: Variant in parsed:
					var value: Variant = parsed[key]
					if value is Dictionary and str(value.get("sha256", "")).length() == 64 and str(value.sha256).is_valid_hex_number() and int(value.get("size", 0)) > 0 and int(value.size) <= 64 * 1024 * 1024:
						_catalog[key] = value
	_catalog_retry_at = Time.get_ticks_msec() + 20000
	_catalog_loading = false
