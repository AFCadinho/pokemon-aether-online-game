extends SceneTree

const Mounts = preload("res://scripts/services/mount_service.gd")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/mount_movement_player.gd"))
	root.add_child(player)
	for duration in [0.065, 0.14, 0.22]:
		for fps in [30, 40, 50, 60, 120, 144]:
			_reset(player, duration)
			for frame in range(fps * 3):
				player._advance_tile_movement(1.0 / fps)
			_check(absf(player.position.x - 3.0 / duration * 32.0) <= 1.0,
				"consistent distance at %d FPS, duration %s" % [fps, duration])
			_check(player.completed == int(3.0 / duration), "each crossed tile emits a step")
	_reset(player, 0.065)
	for frame in range(100):
		player._advance_tile_movement(0.01)
		player._advance_tile_movement(0.03)
	_check(absf(player.position.x - 4.0 / 0.065 * 32.0) <= 1.0, "variable frame pacing retains time")
	for boundary in ["stop_after", "exit_after", "input_allowed"]:
		_reset(player, 0.065)
		player.set(boundary, false if boundary == "input_allowed" else 1)
		player._advance_tile_movement(0.1)
		_check(player.position.x == 32.0 and player.completed == 1 and not player.is_moving,
			"remaining time stops at " + boundary)
	_reset(player, 0.065)
	player._advance_tile_movement(5.0)
	_check(player.completed <= 2 and player.position.x <= 50.0, "long hitch has bounded recovery")
	player.free()
	_check_resources()
	print("Mount performance checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)

func _reset(player, duration: float) -> void:
	player.position = Vector2.ZERO
	player.completed = 0
	player.stop_after = -1
	player.exit_after = -1
	player.input_allowed = true
	player.move_duration = duration
	player._try_start_move(Vector2.RIGHT)

func _check_resources() -> void:
	var offset: Vector2i = Mounts.get_rider_frame_offset("cyclizar", "left", 0)
	var definition: Dictionary = Mounts.get_mount_definition("cyclizar")
	definition.clear()
	_check(Mounts.get_rider_frame_offset("cyclizar", "left", 0) == offset, "public definitions remain isolated")
	_check(Mounts.get_rider_frame_offset("missing-mount", "left", 0) == Vector2i.ZERO, "unknown mount is safe")
	var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.set_pixel(20, 20, Color.RED)
	source.set_pixel(21, 20, Color(0, 1, 0, 0.5))
	var mask := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	mask.set_pixel(30, 10, Color.WHITE)
	var result: Image = Mounts._transform_rider_frame(source, mask, 0, 0, Vector2i(10, -10))
	_check(result.get_pixel(20, 20).a == 0.0, "offset mask still hides covered pixel")
	_check(result.get_pixel(21, 20) == source.get_pixel(21, 20), "partial alpha stays intact")
	_check(result.get_used_rect() == Rect2i(21, 20, 1, 1), "transparent padding remains transparent")
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", ImageTexture.create_from_image(source))
	var first: SpriteFrames = Mounts.get_mounted_rider_frames(frames, "cyclizar")
	_check(first == Mounts.get_mounted_rider_frames(frames, "cyclizar"), "repeated appearance reuses frames")
	for index in range(Mounts.RIDER_FRAMES_CACHE_LIMIT + 1):
		Mounts.get_mounted_rider_frames(frames, "cyclizar", {"down": [index, 0]})
	_check(Mounts._rider_frames_cache.size() <= Mounts.RIDER_FRAMES_CACHE_LIMIT, "appearance churn has bounded cache")
	_check(first.get_frame_texture(&"default", 0).get_image() != null, "eviction preserves frames held by active riders")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
