extends RefCounted
## Manifest-driven local rendered assets. No species, form, or shiny inference.
## The approved catalog is built by sprite_factory after a human review.
## Local preview requires a separate explicit environment variable.

static var _cache: Dictionary = {}
static var _cache_order: Array[String] = []
static var _preview_cache_order: Array[String] = []
static var _active_preview_decodes := 0
const BATTLE_DISPLAY_SCALE_MULTIPLIER := 1.3
const CACHE_LIMIT := 2
const PREVIEW_CACHE_LIMIT := 16
const LOCAL_PREVIEW_CATALOG_POINTER := "res://.pokeaether/rendered-preview-catalog"


static func load_frames(species: String, side: String, shiny: bool) -> SpriteFrames:
	if side not in ["front", "back"]:
		return null
	var resolved := _resolve_asset(species, shiny)
	if resolved.is_empty():
		return null
	var path := str(resolved.path)
	var manifest: Dictionary = resolved.manifest
	var preview := bool(resolved.preview)
	var cache_key := path + ":" + str(resolved.sha256) + ":" + side + ":" + str(preview) + ":animated"
	if _cache.has(cache_key):
		_touch_cache_key(cache_key, false)
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
	frames.set_meta("rendered_frame_size", Vector2(512, 512))
	frames.set_meta("hd_poc_fps", float(manifest.get("fps", 0)))
	if not ensure_action_loaded(frames, "idle"):
		return null
	frames.set_meta("rendered_portrait_bounds", _rect_from_array((actions.get("idle", {}) as Dictionary).get("portrait_bounds", [])))
	_remember_frames(cache_key, frames, false)
	return frames


static func load_preview_frames(species: String, side: String, shiny: bool) -> SpriteFrames:
	if side not in ["front", "back"]:
		return null
	var resolved := _resolve_asset(species, shiny)
	if resolved.is_empty():
		return null
	var path := str(resolved.path)
	var manifest: Dictionary = resolved.manifest
	var preview := bool(resolved.preview)
	var cache_key := path + ":" + str(resolved.sha256) + ":" + side + ":" + str(preview) + ":still"
	if _cache.has(cache_key):
		_touch_cache_key(cache_key, true)
		return _cache[cache_key] as SpriteFrames
	var actions: Dictionary = (manifest.get("views", {}) as Dictionary).get(side, {})
	var idle: Dictionary = actions.get("idle", {})
	var present: Dictionary = (manifest.get("presentation", {}) as Dictionary).get(side, {})
	if idle.is_empty() or present.is_empty() or not _allowed(str(idle.get("status", "")), preview):
		return null
	var source := _preview_frame_source(path, side, idle, preview)
	if source.is_empty():
		return null
	var image_path := str(source.path)
	if not FileAccess.file_exists(image_path) or FileAccess.get_sha256(image_path) != str(source.sha256):
		return null
	var im := Image.load_from_file(image_path)
	if im == null or im.get_size() != Vector2i(512, 512) or im.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]:
		return null
	# Use the complete idle union when available so the still-to-animation swap
	# does not change scale or center once streaming finishes.
	var visual_bounds := _rect_from_array(idle.get("visual_bounds", []))
	if not visual_bounds.has_area():
		visual_bounds = _rect_from_array(source.get("visual_bounds", []))
	if not visual_bounds.has_area():
		visual_bounds = Rect2(im.get_used_rect())
	if not visual_bounds.has_area():
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	frames.add_frame("idle", ImageTexture.create_from_image(im))
	frames.set_meta("rendered_asset", true)
	frames.set_meta("rendered_static_preview", true)
	frames.set_meta("rendered_portrait_bounds", _rect_from_array(idle.get("portrait_bounds", [])))
	frames.set_meta("rendered_actions", {})
	frames.set_meta("rendered_root", path.get_base_dir())
	frames.set_meta("rendered_preview", preview)
	frames.set_meta("rendered_presentation", present)
	frames.set_meta("rendered_display_scale_multiplier", BATTLE_DISPLAY_SCALE_MULTIPLIER)
	frames.set_meta("rendered_frame_size", Vector2(512, 512))
	frames.set_meta("rendered_visual_bounds", visual_bounds)
	frames.set_meta("hd_poc_fps", float(manifest.get("fps", 0)))
	_remember_frames(cache_key, frames, true)
	return frames


static func load_frames_async(species: String, side: String, shiny: bool, on_ready: Callable = Callable(), is_current: Callable = Callable()) -> SpriteFrames:
	if side not in ["front", "back"]:
		return null
	var resolved := _resolve_asset(species, shiny)
	if resolved.is_empty():
		return null
	var path := str(resolved.path)
	var manifest: Dictionary = resolved.manifest
	var preview := bool(resolved.preview)
	var cache_key := path + ":" + str(resolved.sha256) + ":" + side + ":" + str(preview) + ":animated"
	if _cache.has(cache_key):
		_touch_cache_key(cache_key, false)
		return _cache[cache_key] as SpriteFrames
	var actions: Dictionary = (manifest.get("views", {}) as Dictionary).get(side, {})
	var idle: Dictionary = actions.get("idle", {})
	var present: Dictionary = (manifest.get("presentation", {}) as Dictionary).get(side, {})
	if idle.is_empty() or present.is_empty() or not _allowed(str(idle.get("status", "")), preview):
		return null
	var tree := Engine.get_main_loop() as SceneTree
	var pages: Array = idle.get("pages", [])
	if pages.is_empty():
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("rendered_asset", true)
	frames.set_meta("rendered_actions", actions)
	frames.set_meta("rendered_root", path.get_base_dir())
	frames.set_meta("rendered_preview", preview)
	frames.set_meta("rendered_presentation", present)
	frames.set_meta("rendered_display_scale_multiplier", BATTLE_DISPLAY_SCALE_MULTIPLIER)
	frames.set_meta("rendered_frame_size", Vector2(512, 512))
	frames.set_meta("hd_poc_fps", float(manifest.get("fps", 0)))
	frames.add_animation("idle")
	frames.set_animation_speed("idle", float(manifest.get("fps", 0)))
	# A partial sequence must never loop back to frame zero.
	frames.set_animation_loop("idle", false)
	var visual_bounds := _rect_from_array(idle.get("visual_bounds", []))
	var has_declared_bounds := visual_bounds.has_area()
	frames.set_meta("rendered_portrait_bounds", _rect_from_array(idle.get("portrait_bounds", [])))
	var uploaded := 0
	for page_index: int in pages.size():
		while _active_preview_decodes >= 2:
			if is_current.is_valid() and not is_current.call():
				return null
			await tree.process_frame
		if is_current.is_valid() and not is_current.call():
			return null
		var page: Dictionary = pages[page_index]
		var thread := Thread.new()
		if thread.start(_decode_action_pages.bind(path.get_base_dir(), {"pages": [page]})) != OK:
			return null
		_active_preview_decodes += 1
		while thread.is_alive():
			await tree.process_frame
		var decoded: Dictionary = thread.wait_to_finish()
		_active_preview_decodes -= 1
		if is_current.is_valid() and not is_current.call():
			return null
		var images: Array = decoded.get("images", [])
		if images.size() != 1:
			push_warning("Rendered preview page failed validation: " + str(page.get("file", "")))
			return null
		var page_image := images[0] as Image
		var columns := int(page.get("columns", 0))
		var count := int(page.get("count", 0))
		for frame_index: int in count:
			var cell := page_image.get_region(Rect2i(
				(frame_index % columns) * 512,
				int(frame_index / columns) * 512,
				512,
				512
			))
			if not has_declared_bounds:
				var used := cell.get_used_rect()
				if used.has_area():
					visual_bounds = visual_bounds.merge(Rect2(used)) if visual_bounds.has_area() else Rect2(used)
			frames.add_frame("idle", ImageTexture.create_from_image(cell))
			uploaded += 1
			if uploaded % 4 == 0:
				await tree.process_frame
		# Old manifests without union bounds wait until complete to avoid resizing
		# mid-animation. New packages provide stable whole-action bounds.
		if has_declared_bounds and on_ready.is_valid() and (not is_current.is_valid() or is_current.call()):
			frames.set_meta("rendered_visual_bounds", visual_bounds)
			on_ready.call(frames)
	if uploaded != int(idle.get("count", 0)) or not visual_bounds.has_area():
		return null
	frames.set_meta("rendered_visual_bounds", visual_bounds)
	frames.set_animation_loop("idle", bool(idle.get("loop", false)))
	_remember_frames(cache_key, frames, false)
	return frames


static func _decode_action_pages(root: String, action: Dictionary) -> Dictionary:
	var images: Array[Image] = []
	var pages: Array = action.get("pages", [])
	for value: Variant in pages:
		if not value is Dictionary:
			return {}
		var page := value as Dictionary
		var file := str(page.get("file", ""))
		if file.is_absolute_path() or ".." in file or not file.ends_with(".png"):
			return {}
		var page_path := root.path_join(file)
		if not FileAccess.file_exists(page_path) or FileAccess.get_sha256(page_path) != str(page.get("sha256", "")):
			return {}
		var columns := int(page.get("columns", 0))
		var count := int(page.get("count", 0))
		if columns < 1 or columns > 8 or count < 1 or count > 64:
			return {}
		var im := Image.load_from_file(page_path)
		if im == null or im.get_width() != columns * 512 or im.get_height() != int(ceil(float(count) / columns)) * 512:
			return {}
		images.append(im)
	return {"images": images}


static func _resolve_asset(species: String, shiny: bool) -> Dictionary:
	var catalog_path := OS.get_environment("POKEAETHER_RENDERED_CATALOG")
	var preview_path := _preview_catalog_path()
	var preview := not preview_path.is_empty()
	if preview:
		catalog_path = preview_path
	if catalog_path.is_empty():
		return {}
	var catalog := _json(catalog_path)
	if int(catalog.get("schema", 0)) != 1 or str(catalog.get("mode", "")) != ("preview" if preview else "approved"):
		return {}
	var key := _catalog_key(species, shiny)
	var entries: Dictionary = catalog.get("entries", {})
	var entry: Dictionary = entries.get(key, {})
	var path := str(entry.get("path", ""))
	var manifest_hash := str(entry.get("sha256", ""))
	if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != manifest_hash:
		return {}
	var manifest := _json(path)
	if int(manifest.get("schema", 0)) != 1 or str(manifest.get("species", "")) + ":" + str(manifest.get("variant", "")) != key:
		return {}
	if not _allowed(str(manifest.get("status", "")), preview):
		return {}
	var fps := float(manifest.get("fps", 0))
	if int(manifest.get("cell_size", 0)) != 512 or fps not in [24.0, 60.0]:
		return {}
	return {"path": path, "sha256": manifest_hash, "manifest": manifest, "preview": preview}


static func _preview_frame_source(manifest_path: String, side: String, idle: Dictionary, preview: bool) -> Dictionary:
	var packaged: Dictionary = idle.get("preview_frame", {})
	if not packaged.is_empty():
		var file := str(packaged.get("file", ""))
		if file.is_absolute_path() or ".." in file or not file.ends_with(".png"):
			return {}
		return {
			"path": manifest_path.get_base_dir().path_join(file),
			"sha256": str(packaged.get("sha256", "")),
			"visual_bounds": packaged.get("visual_bounds", []),
		}
	if not preview:
		return {}
	# Compatibility for existing local review builds. Masters stay separate from
	# runtime packaging and are only consulted in explicit debug preview mode.
	var build_root := manifest_path.get_base_dir().get_base_dir()
	var relative := "masters/%s/idle/0000.png" % side
	var qc := _json(build_root.path_join("qc.json"))
	var expected := str((qc.get("files", {}) as Dictionary).get(relative, ""))
	if expected.is_empty():
		return {}
	return {"path": build_root.path_join(relative), "sha256": expected, "visual_bounds": []}


static func _preview_catalog_path() -> String:
	var preview_path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG").strip_edges()
	if not preview_path.is_empty() or not OS.is_debug_build():
		return preview_path
	if not FileAccess.file_exists(LOCAL_PREVIEW_CATALOG_POINTER):
		return ""
	return FileAccess.get_file_as_string(LOCAL_PREVIEW_CATALOG_POINTER).strip_edges()


static func _remember_frames(cache_key: String, frames: SpriteFrames, static_preview: bool = false) -> void:
	var order := _preview_cache_order if static_preview else _cache_order
	var limit := PREVIEW_CACHE_LIMIT if static_preview else CACHE_LIMIT
	if _cache.has(cache_key):
		_cache.erase(cache_key)
		order.erase(cache_key)
	while order.size() >= limit:
		var oldest: String = order.pop_front()
		_cache.erase(oldest)
	_cache[cache_key] = frames
	order.append(cache_key)


static func _touch_cache_key(cache_key: String, static_preview: bool = false) -> void:
	var order := _preview_cache_order if static_preview else _cache_order
	order.erase(cache_key)
	order.append(cache_key)


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
	var visual_bounds := _rect_from_array(entry.get("visual_bounds", []))
	var calculate_visual_bounds := action == "idle" and not visual_bounds.has_area()
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
			if calculate_visual_bounds:
				var cell := im.get_region(Rect2i(
					(index % columns) * 512,
					int(index / columns) * 512,
					512,
					512
				))
				var used := cell.get_used_rect()
				if used.has_area():
					var used_rect := Rect2(used)
					visual_bounds = used_rect if not visual_bounds.has_area() else visual_bounds.merge(used_rect)
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
	if action == "idle" and visual_bounds.has_area():
		frames.set_meta("rendered_visual_bounds", visual_bounds)
	return true


static func _rect_from_array(value: Variant) -> Rect2:
	if not value is Array:
		return Rect2()
	var values := value as Array
	if values.size() != 4:
		return Rect2()
	var rect := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	return rect if rect.has_area() else Rect2()


static func speed_for(frames: SpriteFrames, action: String) -> float:
	var actions: Dictionary = frames.get_meta("rendered_actions", {})
	var entry: Dictionary = actions.get(action, {})
	return maxf(float(entry.get("speed", 1.0)), 0.01)
