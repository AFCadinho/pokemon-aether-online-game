extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var panel = load("res://scenes/interface/skills_panel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	_check(panel.rewards_tab_button != null, "Rock Smash has a Rewards tab")
	var rewards = panel.rewards_section
	rewards.player_level = 25
	rewards.catalog = {
		"level": 50, "itemChancePercent": 30, "fossilChancePercent": 0.4,
		"items": [{"itemId": "pearl", "quantity": 1, "chancePercent": 6.6}, {"itemId": "resonite-ore", "quantity": 1, "chancePercent": 1.8}],
		"fossils": [{"itemId": "old-amber", "quantity": 1, "chancePercent": 0.08}],
		"rocks": [{"requiredLevel": 50, "money": 1225, "experience": 70}],
		"experienceMultiplier": 2,
	}
	rewards._render()
	_check(rewards.rows.get_child_count() == 2, "Items renders only its category")
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
