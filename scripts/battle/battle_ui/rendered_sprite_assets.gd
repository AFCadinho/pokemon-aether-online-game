extends RefCounted
## Manifest-driven local rendered assets. No species, form, or shiny inference.
## The approved catalog is built by sprite_factory after a human review.
## Local preview requires a separate explicit environment variable.

static var _cache: Dictionary = {}
const BATTLE_DISPLAY_SCALE_MULTIPLIER := 1.2


static func load_frames(species: String, side: String, shiny: bool) -> SpriteFrames:
	var catalog_path := OS.get_environment("POKEAETHER_RENDERED_CATALOG")
	var preview_path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG")
	var preview := not preview_path.is_empty()
	if preview:
		catalog_path = preview_path
	if catalog_path.is_empty() or side not in ["front", "back"]:
		return null
	var catalog := _json(catalog_path)
	if int(catalog.get("schema", 0)) != 1 or str(catalog.get("mode", "")) != ("preview" if preview else "approved"):
		return null
	var key := _catalog_key(species, shiny)
	var entries: Dictionary = catalog.get("entries", {})
	var entry: Dictionary = entries.get(key, {})
	var path := str(entry.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(entry.get("sha256", "")):
		return null
	var manifest := _json(path)
	if int(manifest.get("schema", 0)) != 1 or str(manifest.get("species", "")) + ":" + str(manifest.get("variant", "")) != key:
		return null
	if not _allowed(str(manifest.get("status", "")), preview):
		return null
	var fps := float(manifest.get("fps", 0))
	if int(manifest.get("cell_size", 0)) != 512 or fps not in [24.0, 60.0]:
		return null
	var cache_key := path + ":" + str(entry.get("sha256")) + ":" + side + ":" + str(preview)
	if _cache.has(cache_key):
		return _cache[cache_key] as SpriteFrames
	var views: Dictionary = manifest.get("views", {})
	var actions: Dictionary = views.get(side, {})
	var presentation: Dictionary = manifest.get("presentation", {})
	var present: Dictionary = presentation.get(side, {})
	if actions.is_empty() or present.is_empty():
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("rendered_asset", true)
	frames.set_meta("rendered_actions", actions)
	frames.set_meta("rendered_root", path.get_base_dir())
	frames.set_meta("rendered_preview", preview)
	frames.set_meta("rendered_presentation", present)
	frames.set_meta("rendered_display_scale_multiplier", BATTLE_DISPLAY_SCALE_MULTIPLIER)
	frames.set_meta("hd_poc_fps", fps)
	if not ensure_action_loaded(frames, "idle"):
		return null
	_cache[cache_key] = frames
	return frames


static func _catalog_key(species: String, shiny: bool) -> String:
	return species.strip_edges().to_lower().replace(" ", "-").replace("_", "-") + (":shiny" if shiny else ":normal")


static func _allowed(status: String, preview: bool) -> bool:
	return status == "approved" or (preview and status == "needs_review")


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func ensure_action_loaded(frames: SpriteFrames, action: String) -> bool:
	if frames == null or not frames.has_meta("rendered_asset"):
		return false
	if frames.has_animation(action):
		return frames.get_frame_count(action) > 0
	var actions: Dictionary = frames.get_meta("rendered_actions", {})
	var entry: Dictionary = actions.get(action, {})
	if not _allowed(str(entry.get("status", "")), bool(frames.get_meta("rendered_preview", false))):
		return false
	var pages: Array = entry.get("pages", [])
	var textures: Array[AtlasTexture] = []
	var root := str(frames.get_meta("rendered_root", ""))
	for value: Variant in pages:
		if not value is Dictionary:
			return false
		var page: Dictionary = value
		var file := str(page.get("file", ""))
		if file.is_absolute_path() or ".." in file or not file.ends_with(".png"):
			return false
		var path := root.path_join(file)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(page.get("sha256", "")):
			return false
		var columns := int(page.get("columns", 0))
		var count := int(page.get("count", 0))
		if columns < 1 or columns > 8 or count < 1 or count > 64:
			return false
		var im := Image.load_from_file(path)
		if im == null or im.get_width() != columns * 512 or im.get_height() != int(ceil(float(count) / columns)) * 512:
			return false
		var texture := ImageTexture.create_from_image(im)
		for index: int in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2((index % columns)*512, int(index / columns)*512, 512, 512)
			atlas.filter_clip = true
			textures.append(atlas)
	if textures.is_empty() or textures.size() != int(entry.get("count", 0)):
		return false
	# Commit only after every page passed; a broken action cannot poison fallback.
	frames.add_animation(action)
	frames.set_animation_speed(action, float(frames.get_meta("hd_poc_fps", 24.0)))
	frames.set_animation_loop(action, bool(entry.get("loop", false)))
	for texture: AtlasTexture in textures:
		frames.add_frame(action, texture)
	return true


static func speed_for(frames: SpriteFrames, action: String) -> float:
	var actions: Dictionary = frames.get_meta("rendered_actions", {})
	var entry: Dictionary = actions.get(action, {})
	return maxf(float(entry.get("speed", 1.0)), 0.01)
