extends SceneTree

const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(Assets._safe_image_file("front/idle-000.webp"))
	assert(Assets._safe_image_file("front/idle-000.png"))
	assert(not Assets._safe_image_file("../idle.webp"))
	assert(not Assets._safe_image_file("idle.jpg"))
	assert(Assets._stored_cell_rect({}) == Rect2(0, 0, 512, 512))
	assert(Assets._stored_cell_rect({"stored_cell_rect": [120, 80, 160, 240]}) == Rect2(120, 80, 160, 240))
	assert(not Assets._stored_cell_rect({"stored_cell_rect": [500, 500, 20, 20]}).has_area())

	var image := Image.create(160, 240, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var atlas := Assets._atlas_frame(
		ImageTexture.create_from_image(image),
		0,
		1,
		Rect2(120, 80, 160, 240)
	)
	assert(atlas.get_size() == Vector2(512, 512))
	assert(atlas.region == Rect2(0, 0, 160, 240))
	assert(atlas.margin == Rect2(120, 80, 352, 272))

	var catalog_path := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG")
	if not catalog_path.is_empty():
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		assert((catalog.get("entries", {}) as Dictionary).size() == 4)
		for species: String in ["diglett", "jigglypuff", "dragonite", "roaring-moon"]:
			for side: String in ["front", "back"]:
				var preview := Assets.load_preview_frames(species, side, false)
				assert(preview != null and preview.get_frame_count("idle") == 1)
				var frames := Assets.load_frames(species, side, false)
				assert(frames != null and frames.get_frame_count("idle") > 1)
				var texture := frames.get_frame_texture("idle", 0) as AtlasTexture
				assert(texture != null and texture.get_size() == Vector2(512, 512))
				assert(texture.margin.size != Vector2.ZERO)
				Assets._cache.clear()
				Assets._cache_order.clear()
				Assets._preview_cache_order.clear()
		var dragonite := Assets.load_frames("dragonite", "front", false)
		for action: String in ["physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]:
			assert(Assets.ensure_action_loaded(dragonite, action))
			assert(dragonite.get_frame_count(action) > 0)
		Assets._cache.clear()
		Assets._cache_order.clear()
		var streamed: SpriteFrames = await Assets.load_frames_async("dragonite", "front", false)
		assert(streamed != null and streamed.get_frame_count("idle") == 91)
		assert(await Assets.ensure_action_loaded_async(streamed, "physical_attack"))
		assert(streamed.get_frame_count("physical_attack") == 131)
	print("Trimmed WebP rendered sprite geometry checks PASS")
	quit()
