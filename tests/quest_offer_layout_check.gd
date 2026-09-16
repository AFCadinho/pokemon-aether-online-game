extends SceneTree

const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var layer := (load(DIALOGUE_BOX_SCENE_PATH) as PackedScene).instantiate()
	scene.add_child(layer)
	var dialogue := layer.get_node("Box")
	var quest := {
		"questId": "learn_to_pickpocket",
		"titleKey": "story.kanto.learn_to_pickpocket.title",
		"summaryKey": "story.kanto.learn_to_pickpocket.summary",
		"steps": [{"stepId": "pickpocket", "objectiveKey": "story.kanto.learn_to_pickpocket.child"}],
		"rewardPreviews": [
			{"type": "skill_experience", "skillId": "thieving", "experience": 500},
			{"type": "item", "itemId": "tm-thief", "quantity": 1},
			{"type": "item", "itemId": "black-glasses", "quantity": 1},
			{"type": "currency", "currency": "aetherite", "amount": 75},
		],
	}
	var original_content_scale_size := root.content_scale_size
	var first_large_panel_height := 0.0
	for viewport_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(720, 340)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await process_frame
		dialogue.call("start_quest_offer", quest, "Master Thief Rook")
		if viewport_size.y == 1080:
			_check((dialogue.get_node("PanelContainer") as Control).size.y < 650.0, "quest first frame does not fill the screen")
		await process_frame
		await process_frame
		var panel := dialogue.get_node("PanelContainer") as Control
		var scroll := dialogue.get_node("PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferScroll") as ScrollContainer
		var actions := dialogue.get_node("PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferActions") as HBoxContainer
		var rewards := dialogue.get_node("PanelContainer/MarginContainer/HBoxContainer/Panel/MarginContainer/VBoxContainer/QuestOfferScroll/QuestOfferContent/RewardCard/RewardMargin/RewardEntries") as HFlowContainer
		_check(panel.global_position.x >= 0.0 and panel.global_position.y >= 0.0, "quest panel starts inside %s viewport" % viewport_size)
		_check(panel.global_position.x + panel.size.x <= viewport_size.x + 1.0 and panel.global_position.y + panel.size.y <= viewport_size.y + 1.0, "quest panel fits %s viewport" % viewport_size)
		if viewport_size.y >= 720:
			_check(panel.global_position.y + panel.size.y / 2.0 < viewport_size.y / 2.0, "quest offer sits slightly above screen center")
		if viewport_size.y == 1080:
			_check(panel.size.y < 650.0, "quest panel stays content-sized on first and later openings")
			if first_large_panel_height == 0.0:
				first_large_panel_height = panel.size.y
			else:
				_check(absf(panel.size.y - first_large_panel_height) <= 24.0, "first and later quest openings use the same height")
		_check(actions.global_position.y + actions.size.y <= panel.global_position.y + panel.size.y, "quest action buttons remain visible at %s" % viewport_size)
		_check(scroll.visible and scroll.size.y >= 60.0, "quest details remain scrollable at %s" % viewport_size)
		if viewport_size.y < 400:
			_check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "low quest viewport can scroll to every reward")
		_check(rewards.get_child_count() == 4 and rewards.get_child(0) is PanelContainer, "quest rewards use separate compact cards")
		dialogue.call("hide_dialogue")
		await process_frame
	root.content_scale_size = original_content_scale_size
	root.size = Vector2i(1152, 648)
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS %s" % description)
	else:
		failed = true
		push_error("FAIL %s" % description)
