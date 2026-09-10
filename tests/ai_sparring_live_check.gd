extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var panel = load("res://scripts/ui/ai_sparring_live.gd").new()
	panel.hide()
	root.add_child(panel)
	await process_frame
	panel.entries = [
		{"battleId": "a", "playerName": "Ash", "difficulty": "ai4", "tierId": "none"},
		{"battleId": "b", "playerName": "Misty", "difficulty": "active", "tierId": "aether-ou"}]
	panel.search.text = "ASH"
	assert(panel.filtered_entries().size() == 1)
	assert(panel.filtered_entries()[0].battleId == "a")
	panel.search.text = ""
	panel.tier.select(2)
	assert(panel.filtered_entries().size() == 1)
	panel.difficulty.select(1)
	assert(panel.filtered_entries().is_empty())
	panel.tier.select(0)
	panel.difficulty.select(0)
	panel.watch_blocked = func(): return true
	panel.render()
	assert(panel.rows.get_child_count() == 2)
	for card in panel.rows.get_children():
		assert(card.get_child(0).get_child(1).disabled)
	panel.watch_blocked = func(): return false
	panel.entries[0]["spectators"] = 8
	panel.render()
	assert(panel.rows.get_child(0).get_child(0).get_child(1).disabled)
	assert(not panel.rows.get_child(1).get_child(0).get_child(1).disabled)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		assert(not panel.refresh.text.begins_with("ui."))
		assert(not panel.search.placeholder_text.begins_with("ui."))
	panel.queue_free()
	await process_frame
	print("AI Sparring live UI: PASS")
	quit(0)
