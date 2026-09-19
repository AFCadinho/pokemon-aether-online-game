extends SceneTree
const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var overlay: Node = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	root.size = Vector2i(1000, 420)
	var index := 0
	for species: String in ["charizard", "articuno", "dragonite", "pikachu"]:
		var frames := Assets.load_preview_frames(species, "front", false)
		assert(frames != null)
		var full: Rect2 = frames.get_meta("rendered_visual_bounds")
		var portrait: Rect2 = overlay.call("_rendered_portrait_rect", frames, Vector2(235, 155))
		assert(portrait.has_area())
		var old_scale: float = min(235.0 / full.size.x, 155.0 / full.size.y)
		var new_scale := 235.0 / portrait.size.x
		assert(new_scale <= old_scale * 1.2201)
		print("%s summary portrait enlargement %.2fx" % [species, new_scale / old_scale])
		for row in 2:
			var label := Label.new()
			label.text = species + (" / full bounds" if row == 0 else " / portrait")
			label.position = Vector2(index * 250 + 8, row * 200 + 8)
			root.add_child(label)
			var panel := Control.new()
			panel.position = Vector2(index * 250 + 8, row * 200 + 35)
			panel.size = Vector2(235, 155)
			panel.clip_contents = true
			root.add_child(panel)
			var background := ColorRect.new()
			background.size = panel.size
			background.color = Color("202735")
			panel.add_child(background)
			var sprite := Sprite2D.new()
			sprite.texture = frames.get_frame_texture("idle", 0)
			sprite.position = panel.size * 0.5
			var rect := full if row == 0 else portrait
			sprite.offset = Vector2(256, 256) - rect.get_center()
			sprite.scale = Vector2.ONE * (old_scale if row == 0 else new_scale)
			panel.add_child(sprite)
		index += 1
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pokeaether-portrait-review.png")
	for property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		(overlay.get(property) as Node).free()
	overlay.free()
	print("Portrait bounds checks PASS")
	quit()
