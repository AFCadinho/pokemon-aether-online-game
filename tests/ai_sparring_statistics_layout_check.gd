extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay := (load("res://scripts/ui/ui_overlay.gd") as Script).new() as CanvasLayer
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var page := overlay.call("_create_ai_sparring_stats_page") as MarginContainer
	var background := ColorRect.new()
	background.color = Color("#080f19")
	viewport.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var manager := root.get_node("LocalizationManager")
	var previous_locale := str(manager.get("current_locale"))
	for locale: String in ["en", "nl"]:
		manager.call("set_locale", locale)
		for width: int in [900, 520, 360]:
			viewport.size = Vector2i(width, 800)
			overlay.set("pvp_ai_sparring_stats_data", {"success": true, "bots": [
				{"bot": "ai4", "version": "v1", "completed": 2, "unconfirmed": 1, "sufficient": false},
				{"bot": "ai5", "version": "v5", "completed": 124, "unconfirmed": 0, "winRate": 0.62, "averageTurns": 32, "nativeRate": 0.99, "fallbackRate": 0.01, "sufficient": true}
			]})
			overlay.call("_render_ai_sparring_stats")
			for frame: int in range(8):
				await process_frame
			var list := overlay.get("pvp_ai_sparring_stats_list") as VBoxContainer
			for bot: String in ["ai4", "ai5"]:
				var card := list.get_node("AiSparringStatsCard_" + bot) as PanelContainer
				_check(card.get_global_rect().end.x <= width + 1, "Card fits viewport: " + locale + str(width))
				var grid := card.find_child("Metrics", true, false) as GridContainer
				_check(grid.columns == (1 if width == 360 else 3 if width == 900 and bot == "ai5" else 2), "Responsive columns: " + locale + str(width) + bot)
				for tile: Control in grid.get_children():
					_check(tile.get_global_rect().end.x <= card.get_global_rect().end.x, "Tile stays within card")
			var capture_dir := OS.get_environment("AI5_STATS_CAPTURE_DIR")
			if not capture_dir.is_empty():
				await RenderingServer.frame_post_draw
				_check(viewport.get_texture().get_image().save_png(capture_dir.path_join("stats-%s-%d.png" % [locale, width])) == OK, "Capture saved")
	manager.call("set_locale", previous_locale)
	page.free()
	background.free()
	viewport.free()
	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	await process_frame
	print("AI Sparring statistics layout: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
