extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var script := load("res://scripts/battle/battle_ui/sprite_box.gd") as Script
	var first: Node = script.new()
	var second: Node = script.new()
	var frames: SpriteFrames = first._load_sprite_frames("charizard", "front", false)
	var shared: SpriteFrames = second._load_sprite_frames("charizard", "front", false)
	_check(frames == shared, "different loaders share a processed sprite")
	_check(first._get_sprite_frames_visual_bounds(frames) == second._get_sprite_frames_visual_bounds(shared), "shared bounds are restored")
	_check(first._get_sprite_frames_anchor(frames) == second._get_sprite_frames_anchor(shared), "shared anchor is restored")
	_check(first._get_sprite_frames_render_scale(frames) == second._get_sprite_frames_render_scale(shared), "shared render scale is restored")
	var cached_web_bounds := Rect2(2, 3, 4, 5)
	var prepared_web_bounds := Rect2(1, 2, 6, 7)
	first._set_sprite_frames_anchor(frames, Vector2(8, 9), Vector2(16, 18))
	first._set_sprite_frames_visual_bounds(frames, cached_web_bounds)
	first._apply_web_sprite_result_metadata(frames, {
		"frame_size": Vector2(16, 18),
		"render_scale": 1.0,
		"style": "animated",
		"visual_bounds": prepared_web_bounds,
	}, "charizard", "front", false)
	_check(
		first._get_sprite_frames_visual_bounds(frames) == prepared_web_bounds,
		"web frames reuse CPU-calculated bounds instead of rescanning GPU textures"
	)
	var image := Image.create(5, 4, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1, 1, 1, 5.0 / 255.0))
	image.set_pixel(3, 2, Color(1, 1, 1, 6.0 / 255.0))
	var bounds: Rect2 = first._calculate_texture_alpha_bounds(ImageTexture.create_from_image(image))
	_check(bounds == Rect2(3, 2, 1, 1), "alpha threshold and transparent margins are preserved")
	var small_home_scale: float = first._get_home_sprite_render_scale(Rect2(0, 0, 90, 140))
	_check(is_equal_approx(small_home_scale, first.HOME_SPRITE_RENDER_SCALE), "small HOME fallbacks keep their existing size")
	var large_home_bounds := Rect2(0, 0, 363, 403)
	var large_home_scale: float = first._get_home_sprite_render_scale(large_home_bounds)
	var large_home_display_size: Vector2 = (
		large_home_bounds.size
		* first.BATTLE_SPRITE_SCALE.x
		* first.BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER
		/ large_home_scale
	)
	_check(large_home_display_size.x <= first.HOME_SPRITE_MAX_DISPLAY_SIZE.x + 0.01, "wide HOME fallbacks fit the battle width budget")
	_check(large_home_display_size.y <= first.HOME_SPRITE_MAX_DISPLAY_SIZE.y + 0.01, "tall HOME fallbacks fit the battle height budget")
	_check(is_equal_approx(large_home_display_size.aspect(), large_home_bounds.size.aspect()), "HOME fallback scaling preserves aspect ratio")
	var retained := Resource.new()
	var cache := {}
	Appearance._remember_appearance_resource(cache, "retained", retained)
	for i in Appearance.APPEARANCE_CACHE_LIMIT + 10:
		Appearance._remember_appearance_resource(cache, str(i), Resource.new())
	_check(cache.size() == Appearance.APPEARANCE_CACHE_LIMIT, "appearance cache is bounded")
	_check(is_instance_valid(retained), "cache eviction does not free a referenced resource")
	var base := Appearance.get_body_frames(Appearance.DEFAULT_MALE_BODY_ID, "male")
	var tinted := Appearance._build_skin_tinted_sprite_frames(base, Color("#c58a5c"))
	for animation: StringName in base.get_animation_names():
		_check(tinted.get_frame_count(animation) == base.get_frame_count(animation), "tint keeps frame count")
		for index in base.get_frame_count(animation):
			var reference := Appearance._make_skin_tinted_texture(base.get_frame_texture(animation, index), Color("#c58a5c"))
			_check(reference.get_image().get_data() == tinted.get_frame_texture(animation, index).get_image().get_data(), "shared tinted frames retain pixel output")
	first.free()
	second.free()
	print("sprite_resource_cache_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
