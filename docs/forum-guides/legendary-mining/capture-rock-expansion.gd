extends SceneTree

const OUTPUT := "res://docs/forum-guides/legendary-mining/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(not root.get_node("AuthService").is_authenticated())
	root.get_node("LocalizationManager").set_locale("en")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "captures-rock-expansion.json"))
	assert(fixture.rocks.size() == 55)
	var skill := {
		"id": "rock_smash", "nameKey": "ui.skills.rock_smash.name",
		"descriptionKey": "ui.skills.rock_smash.description", "unlocked": true,
		"level": 75, "maxLevel": 100, "totalExperience": 42150,
		"experienceIntoLevel": 0, "experienceForNextLevel": 950, "progressPercent": 0,
		"stats": {"availableRocks": 53, "fossilChancePercent": 0.525},
		"rocks": fixture.rocks, "unlocks": [],
	}
	var skills = root.get_node("SkillsService")
	skills.skills = [skill]
	skills.state_loaded = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(824, 864)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var panel = load("res://scenes/interface/skills_panel.tscn").instantiate()
	viewport.add_child(panel)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(800, 840)
	panel.show()
	panel._select_skill("rock_smash")
	panel._select_detail_tab("catalog")
	for area in ["route_18", "rock_tunnel"]:
		var index: int = panel.target_town_order.find("ui.skills.rock_smash.location." + area)
		assert(index >= 0)
		panel.area_selector.select(index)
		panel._select_area(index)
		assert(panel.targets_container.get_child_count() == 8)
		await _frames()
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(OUTPUT + "04-daily-rocks-route18.png" if area == "route_18" else OUTPUT + "05-daily-rocks-rock-tunnel.png") == OK)
	panel.selected_detail_tab = "rewards"
	panel.rewards_section.catalog = fixture.rewards
	panel.rewards_section.player_level = 75
	panel._render_detail_tab(skill)
	await _frames()
	# Supply the successful catalog fixture and invalidate the unauthenticated request.
	panel.rewards_section.request_revision += 1
	panel.rewards_section.retry.hide()
	panel.rewards_section.catalog = fixture.rewards
	panel.rewards_section.category.select(0)
	panel.rewards_section._render()
	await _frames()
	await RenderingServer.frame_post_draw
	assert(not panel.rewards_section.retry.visible)
	assert(panel.rewards_section.summary.text.contains("75"))
	assert(viewport.get_texture().get_image().save_png(OUTPUT + "06-item-rewards.png") == OK)
	viewport.free()
	print("PASS: three native Skills previews, 55 catalog rocks, no authenticated account")
	quit()

func _frames() -> void:
	for frame in range(8):
		await process_frame
