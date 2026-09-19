extends RefCounted
## Desktop cosmetics only. Pack selection is frozen until the next game start.
const Store := preload("res://launcher/scripts/content_pack_store.gd")
static var _entries: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded := false
const CACHE_LIMIT := 96

static func _remember(key: String, value: Variant) -> void:
	if _cache.size() >= CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
	_cache[key] = value

static func species_key(species: String) -> String:
	return species.strip_edges().to_lower().replace("’", "").replace("\'", "").replace(".", "").replace(":", "").replace("_", "-").replace(" ", "-")

static func initialize() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.has_feature("web"):
		return
	var directory := OS.get_environment("POKEAETHER_MODS_DIR")
	var store := Store.new(directory if not directory.is_empty() else "user://mods")
	var packs: Dictionary = {}
	for pack in store.installed():
		packs[pack.id] = pack
	for pack_id in store.enabled_ids():
		for category: String in packs.get(pack_id, {}).get("assets", {}):
			for key: String in packs[pack_id].assets[category]:
				var entry: Dictionary = packs[pack_id].assets[category][key].duplicate(true)
				entry["path"] = store.asset_path(pack_id, entry.file)
				if entry.path.is_empty():
					continue
				var lookup := category + "/" + key
				if not _entries.has(lookup):
					_entries[lookup] = []
				_entries[lookup].append(entry)

static func cry(species: String) -> AudioStream:
	initialize()
	var key := "cries/" + species_key(species)
	if _cache.has(key):
		return _cache[key] as AudioStream
	for entry: Dictionary in _entries.get(key, []):
		var file := FileAccess.open(entry.path, FileAccess.READ)
		if file == null or file.get_length() > Store.MAX_FILE_BYTES:
			continue
		var bytes := file.get_buffer(file.get_length())
		if bytes.size() < 4 or bytes.slice(0, 4).get_string_from_ascii() != "OggS":
			continue
		var stream := AudioStreamOggVorbis.load_from_buffer(bytes)
		if stream != null:
			_remember(key, stream)
			return stream
	_remember(key, null)
	return null

static func _texture(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24 or file.get_length() > Store.MAX_FILE_BYTES:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return null
	# Read PNG dimensions before decoding to bound texture memory.
	file.seek(16)
	file.big_endian = true
	var width := file.get_32()
	var height := file.get_32()
	if width < 1 or height < 1 or width > 8192 or height > 8192 or width * height > 16777216:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func battle_frames(species: String, side: String, shiny: bool) -> SpriteFrames:
	initialize()
	var key := "battle_sprites/%s:%s:%s" % [species_key(species), side, "shiny" if shiny else "normal"]
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	for entry: Dictionary in _entries.get(key, []):
		var texture := _texture(entry.path)
		if texture == null:
			continue
		var columns := int(entry.get("columns", 1))
		var rows := int(entry.get("rows", 1))
		if texture.get_width() % columns != 0 or texture.get_height() % rows != 0:
			continue
		var cell := Vector2(texture.get_width() / columns, texture.get_height() / rows)
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("idle")
		frames.set_animation_speed("idle", float(entry.get("fps", 10.0)))
		for index in range(int(entry.get("frames", 1))):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(Vector2(index % columns, index / columns) * cell, cell)
			frames.add_frame("idle", frame)
		frames.set_meta("content_pack_cell", cell)
		var anchor: Array = entry.get("anchor", [cell.x / 2.0, cell.y / 2.0])
		var offset: Array = entry.get("offset", [0, 0])
		frames.set_meta("content_pack_anchor", Vector2(anchor[0], anchor[1]))
		frames.set_meta("content_pack_offset", Vector2(offset[0], offset[1]))
		frames.set_meta("content_pack_scale", float(entry.get("scale", 1.0)))
		_remember(key, frames)
		return frames
	_remember(key, null)
	return null

static func follower_texture(species: String, shiny: bool) -> Texture2D:
	initialize()
	var key := "followers/%s:%s" % [species_key(species), "shiny" if shiny else "normal"]
	if _cache.has(key):
		return _cache[key] as Texture2D
	for entry: Dictionary in _entries.get(key, []):
		var texture := _texture(entry.path)
		if texture != null and texture.get_width() % 4 == 0 and texture.get_height() % 4 == 0:
			_remember(key, texture)
			return texture
	_remember(key, null)
	return null
