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
	var diagnostic_root := Node.new()
	diagnostic_root.name = "PrivatePlayerNameMustNotBeRecorded"
	diagnostic_root.add_child(Button.new())
	diagnostic_root.add_child(Button.new())
	var counts: Dictionary = get_root().get_node("WebMemoryProbe").diagnostic_scene_node_types(diagnostic_root)
	passed = passed and counts == {"Node": 1, "Button": 2}
	var probe := get_root().get_node("WebMemoryProbe")
	var path := "res://assets/battles/animations/probe/sheet.png"
	var missing := "res://assets/battles/animations/probe/not-loaded.png"
	sheet.take_over_path(path)
	var audit: Dictionary = probe.diagnostic_cached_effect_textures([path, path, missing, "res://private/session", 123])
	passed = passed and audit.uniqueTextures == 1 and audit.estimatedRGBABytes == 64 * 32 * 4
	passed = passed and audit.paths == [{"path": path, "width": 64, "height": 32}]
	passed = passed and not ResourceLoader.has_cached(missing)
	var world_path := "res://assets/ui/probe/sheet.png"
	var world_sheet := ImageTexture.create_from_image(image)
	world_sheet.take_over_path(world_path)
	var world_missing := "res://generated/tiled_visuals/probe/not-loaded.texture.res"
	var world_audit: Dictionary = probe.diagnostic_cached_world_textures([world_path, world_path, world_missing,
		"user://session", "res://assets/ui/../../private/session", path, 123])
	passed = passed and world_audit.paths == [{"path": world_path, "width": 64, "height": 32}]
	passed = passed and world_audit.uniqueTextures == 1 and world_audit.estimatedRGBABytes == 64 * 32 * 4
	passed = passed and not ResourceLoader.has_cached(world_missing)
	passed = passed and probe.diagnostic_cached_effect_textures([world_path]).uniqueTextures == 0
	var bounded_paths: Array = []
	bounded_paths.resize(256)
	bounded_paths.append(world_path)
	passed = passed and probe.diagnostic_cached_world_textures(bounded_paths).uniqueTextures == 0
	var electric_path := "res://assets/battles/animations/electricterrain/PRAS- Electric.png"
	var electric := load(electric_path) as Texture2D
	var reused := load(electric_path) as Texture2D
	passed = passed and electric != null and electric == reused
	var electric_audit: Dictionary = probe.diagnostic_cached_effect_textures([electric_path, electric_path])
	passed = passed and electric_audit.uniqueTextures == 1
	passed = passed and electric_audit.estimatedRGBABytes == 960 * 4416 * 4
	diagnostic_root.free()
	service.free()
	print("web_memory_probe_check: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
