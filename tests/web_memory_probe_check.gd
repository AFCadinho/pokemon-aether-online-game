extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var service: Node = load("res://scripts/services/web_pokemon_sprite_service.gd").new()
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var sheet := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	for index in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(index * 32, 0, 32, 32)
		frames.add_frame("default", atlas)
	for index in 110:
		service.call("_remember", str(index), {"frames": frames})
	var stats: Dictionary = service.call("diagnostic_cache_stats")
	var passed: bool = stats.entries == 96 and stats.uniqueSheets == 1 and stats.estimatedRGBABytes == 64 * 32 * 4
	passed = passed and not get_root().get_node("WebMemoryProbe").enabled
	service.free()
	print("web_memory_probe_check: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
