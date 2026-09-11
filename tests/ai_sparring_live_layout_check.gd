extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(880, 610)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel = load("res://scripts/ui/ai_sparring_live.gd").new()
	panel.hide()
	viewport.add_child(panel)
	panel.position = Vector2(16, 16)
	panel.size = Vector2(848, 578)
	await process_frame
	panel.entries = [
		{"battleId": "one", "playerName": "Admin", "playerAppearance": {"body": "Gen4_Base_v1", "skin_tone": "#d29b78"}, "opponentName": "Grandmaster Hard", "difficulty": "active", "tierId": "aether-ou", "tierName": "Aether OU", "turn": 10, "startedAt": "2026-09-10T12:00:00", "spectators": 0, "maxSpectators": 8},
		{"battleId": "two", "playerName": "Misty", "opponentName": "Scholar", "difficulty": "ai4", "tierId": "none", "tierName": "Open", "turn": 3, "startedAt": "2026-09-10T12:00:00", "spectators": 8, "maxSpectators": 8},
	]
	panel.watching = true
	panel.show()
	panel.render()
	panel.watching = false
	panel.render()
	for frame in range(5):
		await process_frame
	check(panel.search.custom_minimum_size.y >= 40, "Search is a generous primary control")
	check(panel.find_child("LiveBattlesBrowser", true, false) != null, "Search and filters share a visual surface")
	check(panel.rows.get_child_count() == 2, "Battle cards render")
	var first_card: PanelContainer = panel.rows.get_child(0)
	var first_watch: Button = first_card.get_child(0).get_child(2)
	var second_watch: Button = panel.rows.get_child(1).get_child(0).get_child(2)
	check(first_card.get_child(0).get_child(0).name == "LiveBattlePlayerPortrait", "Live card shows the public player portrait")
	check(first_watch.has_theme_stylebox_override("normal"), "Watch is a primary styled action")
	check(second_watch.disabled, "Full battle has a clear disabled action")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		for frame in range(2):
			await process_frame
		check(panel.refresh.size.x >= 104, "Refresh stays touch-friendly: " + locale)
		check(panel.search.size.x >= 400, "Search stays primary: " + locale)
	root.get_node("LocalizationManager").set_locale("en")
	panel.render()
	var capture := OS.get_environment("POKEAETHER_LIVE_CAPTURE")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(capture)
	panel.queue_free()
	viewport.queue_free()
	print("AI Sparring live layout: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
