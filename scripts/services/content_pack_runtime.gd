extends RefCounted
## Desktop cosmetics only. Pack selection is frozen until the next game start.
const PokemonCryResolver := preload("res://scripts/services/pokemon_cry_resolver.gd")
const STORE_SCRIPT_PATH := "res://launcher/scripts/content_pack_store.gd"
const STORE_MAX_FILE_BYTES := 64 * 1024 * 1024
const STORE_SELECTABLE_CATEGORIES: Array[String] = ["cries", "battle_sprites", "followers"]
static var _entries: Dictionary = {}
static var _cache: Dictionary = {}
static var _pokemon_sprite_roots: Array[String] = []
static var _sprite_collection_styles: Dictionary = {}
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
	if OS.has_feature("web") or OS.has_feature("web_preview"):
		return
	# The browser export intentionally excludes launcher/. Load the desktop-only
	# store after the web guard so shared callers such as PokemonAssets still
	# compile and can provide the bundled HOME icons in browser builds.
	var store_script := load(STORE_SCRIPT_PATH) as Script
	if store_script == null:
		return
	var store: Variant = store_script.new(_mods_directory())
	_pokemon_sprite_roots = store.sprite_collection_directories()
	var packs: Dictionary = {}
	for pack in store.installed():
		packs[pack.id] = pack
	var selected: Dictionary = store.selected_by_category()
	for category: String in STORE_SELECTABLE_CATEGORIES:
		var pack_id := str(selected.get(category, ""))
		var pack: Dictionary = packs.get(pack_id, {})
		var pack_assets: Dictionary = pack.get("assets", {})
		if category == "battle_sprites":
			for collection: Dictionary in pack_assets.get("sprite_collections", {}).values():
				var style := str(collection.get("style", ""))
				var collection_directory: String = store.asset_directory(
					pack_id, str(collection.get("directory", ""))
				)
				if not style.is_empty() and not collection_directory.is_empty():
					_sprite_collection_styles[style] = true
		for key: String in pack_assets.get(category, {}):
			var entry: Dictionary = pack_assets[category][key].duplicate(true)
			entry["path"] = store.asset_path(pack_id, entry.file)
			if entry.path.is_empty():
				continue
			_entries[category + "/" + key] = [entry]


static func _mods_directory() -> String:
	var launcher_directory := OS.get_environment("POKEAETHER_MODS_DIR").strip_edges()
	if not launcher_directory.is_empty():
		return launcher_directory
	var game_mods := ProjectSettings.globalize_path("user://mods")
	# A direct Godot editor run has PokeAether's user:// root, while the local
	# launcher stores packs under its own root. Reuse that selection for local
	# cosmetic review; released games still receive the explicit environment path.
	var launcher_userdata := ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir()
	var launcher_mods := launcher_userdata.path_join("PokeAether Launcher/mods")
	if FileAccess.file_exists(launcher_mods.path_join("enabled.json")):
		return launcher_mods
	if FileAccess.file_exists(game_mods.path_join("enabled.json")):
		return game_mods
	return game_mods


static func cry(species: String) -> AudioStream:
	initialize()
	var direct_key := species_key(species)
	var resolved_key := PokemonCryResolver.new().get_cry_key(species)
	var cache_key := "cries/" + direct_key + ":" + resolved_key
	if _cache.has(cache_key):
		return _cache[cache_key] as AudioStream
	for key in [direct_key, resolved_key, resolved_key.to_lower(), direct_key.to_upper().replace("-", "")]:
		for entry: Dictionary in _entries.get("cries/" + key, []):
			var file := FileAccess.open(entry.path, FileAccess.READ)
			if file == null or file.get_length() > STORE_MAX_FILE_BYTES:
				continue
			var bytes := file.get_buffer(file.get_length())
			if bytes.size() < 4 or bytes.slice(0, 4).get_string_from_ascii() != "OggS":
				continue
			var stream := AudioStreamOggVorbis.load_from_buffer(bytes)
			if stream != null:
				_remember(cache_key, stream)
				return stream
	_remember(cache_key, null)
	return null


static func get_pokemon_sprite_roots() -> Array[String]:
	initialize()
	return _pokemon_sprite_roots.duplicate()


static func has_sprite_collection_style(style: String) -> bool:
	initialize()
	return _sprite_collection_styles.has(style)

static func _texture(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24 or file.get_length() > STORE_MAX_FILE_BYTES:
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
