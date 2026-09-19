extends SceneTree
## Focused local review-batch resolver check. Requires explicit preview catalog env.
const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sprite_box_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	var preview_priority := sprite_box_source.find('if rendered != null and bool(rendered.get_meta("rendered_preview", false)):')
	var content_pack_lookup := sprite_box_source.find("var mod_frames := ContentPacks.battle_frames")
	assert(preview_priority >= 0 and preview_priority < content_pack_lookup)
	var expected_preview_path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG").strip_edges()
	if expected_preview_path.is_empty() and FileAccess.file_exists(Assets.LOCAL_PREVIEW_CATALOG_POINTER):
		expected_preview_path = FileAccess.get_file_as_string(Assets.LOCAL_PREVIEW_CATALOG_POINTER).strip_edges()
	assert(Assets._preview_catalog_path() == expected_preview_path)
	Assets._cache.clear()
	Assets._cache_order.clear()
	Assets._preview_cache_order.clear()
	for index: int in Assets.CACHE_LIMIT + 2:
		Assets._remember_frames("review-cache-test-%d" % index, SpriteFrames.new())
	assert(Assets._cache.size() == Assets.CACHE_LIMIT)
	assert(not Assets._cache.has("review-cache-test-0"))
	assert(not Assets._cache.has("review-cache-test-1"))
	Assets._touch_cache_key("review-cache-test-2")
	Assets._remember_frames("review-cache-test-new", SpriteFrames.new())
	assert(Assets._cache.has("review-cache-test-2"))
	for index: int in Assets.PREVIEW_CACHE_LIMIT + 2:
		Assets._remember_frames("review-preview-cache-test-%d" % index, SpriteFrames.new(), true)
	assert(Assets._preview_cache_order.size() == Assets.PREVIEW_CACHE_LIMIT)
	assert(not Assets._cache.has("review-preview-cache-test-0"))
	assert(not Assets._cache.has("review-preview-cache-test-1"))
	Assets._cache.clear()
	Assets._cache_order.clear()
	Assets._preview_cache_order.clear()
	var path := Assets._preview_catalog_path()
	assert(not path.is_empty())
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(catalog.get("mode") == "preview")
	assert((catalog.get("entries") as Dictionary).size() == 15)
	var reviewed_species := [
		"dragonite", "eevee", "roaring-moon", "lucario", "charizard", "pikachu", "articuno",
	]
	var expected_y_offsets := {
		"eevee": {"front": 62, "back": 62},
		"lucario": {"front": 64, "back": 73},
		"charizard": {"front": 85, "back": 83},
		"pikachu": {"front": 67, "back": 70},
		"articuno": {"front": 32, "back": 22},
	}
	var preview_load_msec := 0
	for species: String in reviewed_species:
		for side: String in ["front", "back"]:
			var preview_started := Time.get_ticks_msec()
			var preview_frames := Assets.load_preview_frames(species, side, false)
			preview_load_msec += Time.get_ticks_msec() - preview_started
			assert(preview_frames != null)
			assert(bool(preview_frames.get_meta("rendered_static_preview", false)))
			assert(preview_frames.get_frame_count("idle") == 1)
			assert((preview_frames.get_meta("rendered_visual_bounds", Rect2()) as Rect2).has_area())
			var frames := Assets.load_frames(species, side, false)
			assert(frames != null)
			assert(float(frames.get_meta("hd_poc_fps")) == 60.0)
			assert(frames.get_frame_count("idle") > 1)
			assert(frames.get_animation_loop("idle"))
			assert(is_equal_approx(
				float(frames.get_meta("rendered_display_scale_multiplier", 0.0)),
				1.3
			))
			var visual_bounds: Variant = frames.get_meta("rendered_visual_bounds", Rect2())
			assert(visual_bounds is Rect2 and (visual_bounds as Rect2).has_area())
			assert(not Assets.ensure_action_loaded(frames, "physical_attack"))
			if expected_y_offsets.has(species):
				var presentation: Dictionary = frames.get_meta("rendered_presentation")
				var offset: Array = presentation.get("position_offset", [])
				assert(offset.size() == 2)
				assert(int(offset[1]) == int(expected_y_offsets[species][side]))
	assert(Assets.load_frames("gardevoir", "front", false) == null)
	var shiny := Assets.load_frames("eevee", "front", true)
	assert(shiny != null and shiny.get_frame_count("idle") > 1)
	var shiny_preview := Assets.load_preview_frames("eevee", "front", true)
	assert(shiny_preview != null and shiny_preview.get_frame_count("idle") == 1)
	assert(Assets.load_frames("meowth", "front", true) == null)
	var async_started := Time.get_ticks_msec()
	var animated_dragonite: SpriteFrames = await Assets.load_frames_async("dragonite", "front", false)
	assert(animated_dragonite != null)
	assert(not bool(animated_dragonite.get_meta("rendered_static_preview", false)))
	assert(animated_dragonite.get_frame_count("idle") == 91)
	print("Animated Dragonite streamed in %d ms without blocking frames" % (Time.get_ticks_msec() - async_started))
	print("Lossless non-battle previews loaded in %d ms" % preview_load_msec)
	print("SCVI review batch preview/fallback checks PASS")
	quit()
