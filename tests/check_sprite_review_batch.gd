extends SceneTree
## Focused local review-batch resolver check. Requires explicit preview catalog env.
const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var expected_preview_path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG").strip_edges()
	if expected_preview_path.is_empty() and FileAccess.file_exists(Assets.LOCAL_PREVIEW_CATALOG_POINTER):
		expected_preview_path = FileAccess.get_file_as_string(Assets.LOCAL_PREVIEW_CATALOG_POINTER).strip_edges()
	assert(Assets._preview_catalog_path() == expected_preview_path)
	Assets._cache.clear()
	Assets._cache_order.clear()
	for index: int in Assets.CACHE_LIMIT + 2:
		Assets._remember_frames("review-cache-test-%d" % index, SpriteFrames.new())
	assert(Assets._cache.size() == Assets.CACHE_LIMIT)
	assert(not Assets._cache.has("review-cache-test-0"))
	assert(not Assets._cache.has("review-cache-test-1"))
	Assets._touch_cache_key("review-cache-test-2")
	Assets._remember_frames("review-cache-test-new", SpriteFrames.new())
	assert(Assets._cache.has("review-cache-test-2"))
	Assets._cache.clear()
	Assets._cache_order.clear()
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
	for species: String in reviewed_species:
		for side: String in ["front", "back"]:
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
	assert(Assets.load_frames("meowth", "front", true) == null)
	print("SCVI review batch preview/fallback checks PASS")
	quit()
