extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("LocalizationManager").set_locale("en")
	var panel = load("res://scenes/interface/skills_panel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	_check(panel.rewards_tab_button != null, "Rock Smash has a Rewards tab")
	var rewards = panel.rewards_section
	rewards.player_level = 25
	rewards.catalog = {
		"level": 50, "itemChancePercent": 30, "fossilChancePercent": 0.4,
		"items": [
			{"itemId": "pearl", "quantity": 1, "chancePercent": 5.1},
			{"itemId": "resonite-ore", "quantity": 1, "chancePercent": 1.8},
			{"itemId": "repel", "quantity": 1, "chancePercent": 0.6},
			{"itemId": "super-repel", "quantity": 1, "chancePercent": 0.6},
			{"itemId": "max-repel", "quantity": 1, "chancePercent": 0.3},
		],
		"fossils": [{"itemId": "old-amber", "quantity": 1, "chancePercent": 0.08}],
		"rocks": [{"requiredLevel": 50, "money": 1225, "experience": 70}],
		"experienceMultiplier": 2,
	}
	rewards._render()
	_check(rewards.rows.get_child_count() == 5, "Items renders only its category")
	for index in range(3):
		var labels: Array = rewards.rows.get_child(index + 2).find_children("*", "Label", true, false)
		_check(labels[0].text == ["Repel ×1", "Super Repel ×1", "Max Repel ×1"][index], "Rewards displays the Repel name and amount")
		_check(labels[1].text == ["0.6%", "0.6%", "0.3%"][index], "Rewards displays the per-smash Repel chance")
	_check(not rewards.preview_level.visible, "Level preview starts collapsed")
	_check(rewards.summary.text.contains("50"), "Preview identifies the reward level")
	rewards.category.select(1)
	rewards._render()
	_check(rewards.rows.get_child_count() == 1, "Fossils replaces the item list")
	_check(rewards._percent(0.125) == "0.125%", "Rare chances retain precision")
	rewards.category.select(2)
	rewards._render()
	_check(rewards.rows.get_child_count() == 3, "Money and XP include boost and guild context")
	rewards.catalog["fossils"] = []
	rewards.catalog["legendaryMining"] = [
		{"tier": 1, "requiredLevel": 1, "itemId": "emberite-ore", "chancePercent": 1, "sellPrice": 10000},
		{"tier": 5, "requiredLevel": 75, "itemId": "aetherium-ore", "chancePercent": 0.2625, "sellPrice": 250000},
	]
	rewards.category.select(3)
	rewards._render()
	_check(rewards.rows.get_child_count() == 4, "Legendary Mining shows ores, buyer and protection")
	var mining_labels: Array = rewards.rows.get_child(1).find_children("*", "Label", true, false)
	_check(mining_labels[0].text.contains("Aetherium Ore") and mining_labels[0].text.contains("75"), "Ore rows identify the rock tier requirement")
	_check(mining_labels[1].text.contains("0.2625%") and mining_labels[1].text.contains("250000"), "Ore rows show personal chance and sale value")
	rewards.category.select(1)
	rewards._render()
	_check(rewards.rows.get_child_count() == 1, "Locked fossils have an explanation")
	panel.selected_detail_tab = "progression"
	panel._render_detail_tab({"id": "thieving"})
	_check(not panel.rewards_tab_button.visible and not rewards.visible, "Other skills do not show Rock Smash rewards")
	panel.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + message)
	else:
		print("PASS " + message)
