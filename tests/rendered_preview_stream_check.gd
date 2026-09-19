extends SceneTree

const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")
var sprite: AnimatedSprite2D
var started := 0
var first_ready_ms := -1
var first_count := 0
var last_frame := 0
var advanced := false
var cancelled := false
var last_tick := 0
var max_gap_ms := 0


func _initialize() -> void:
	_run.call_deferred()


func _observe() -> void:
	var now := Time.get_ticks_msec()
	if last_tick > 0:
		max_gap_ms = maxi(max_gap_ms, now - last_tick)
	last_tick = now
	if sprite.frame > last_frame:
		advanced = true
	last_frame = sprite.frame


func _ready_frames(frames: SpriteFrames) -> void:
	if first_ready_ms < 0:
		first_ready_ms = Time.get_ticks_msec() - started
		first_count = frames.get_frame_count("idle")
		assert(first_count == 8, "Playback must begin at the first eight-frame block")
		assert(not frames.get_animation_loop("idle"), "Partial sequences must not loop")
		sprite.sprite_frames = frames
		sprite.play("idle")
	elif not sprite.is_playing():
		sprite.play()


func _run() -> void:
	sprite = AnimatedSprite2D.new()
	root.add_child(sprite)
	process_frame.connect(_observe)
	Assets._cache.clear()
	Assets._cache_order.clear()
	started = Time.get_ticks_msec()
	var frames: SpriteFrames = await Assets.load_frames_async("dragonite", "front", false, _ready_frames)
	assert(frames != null and frames.get_frame_count("idle") == 91)
	assert(frames.get_animation_speed("idle") == 60.0)
	assert(frames.get_animation_loop("idle"))
	assert(first_ready_ms >= 0 and first_count < frames.get_frame_count("idle"))
	assert(advanced, "Animation must advance before full load completes")
	var expected_frame := int((Time.get_ticks_msec() - started - first_ready_ms) * 0.060)
	assert(absi(sprite.frame - expected_frame) <= 3, "Appending pages must preserve playback position and cadence")
	print("Progressive Dragonite: first motion-ready block=%dms, complete=%dms, max process gap=%dms" % [first_ready_ms, Time.get_ticks_msec() - started, max_gap_ms])
	var cancel_after_first := func(_frames: SpriteFrames) -> void: cancelled = true
	var is_current := func() -> bool: return not cancelled
	var back: SpriteFrames = await Assets.load_frames_async("dragonite", "back", false, cancel_after_first, is_current)
	assert(back == null and cancelled)
	assert(Assets._active_preview_decodes == 0)
	assert(Assets._cache_order.size() == 1, "Incomplete animations must not enter cache")
	var cached: SpriteFrames = await Assets.load_frames_async("dragonite", "front", false)
	assert(cached == frames)
	process_frame.disconnect(_observe)
	sprite.queue_free()
	print("Progressive preview playback, cancellation and complete-cache checks PASS")
	quit()
