extends SceneTree

const OUTPUT := "res://docs/forum-guides/legendary-mining/"
const ORES := [
	{"tier": 1, "requiredLevel": 1, "itemId": "emberite-ore", "name": "Emberite Ore", "quantity": 2, "totalMoney": 20000, "sellPrice": 10000, "chancePercent": 1.0},
	{"tier": 2, "requiredLevel": 10, "itemId": "voltite-ore", "name": "Voltite Ore", "quantity": 1, "totalMoney": 25000, "sellPrice": 25000, "chancePercent": 0.75},
	{"tier": 3, "requiredLevel": 20, "itemId": "glacite-ore", "name": "Glacite Ore", "quantity": 1, "totalMoney": 50000, "sellPrice": 50000, "chancePercent": 0.5},
	{"tier": 4, "requiredLevel": 50, "itemId": "astralite-ore", "name": "Astralite Ore", "quantity": 1, "totalMoney": 100000, "sellPrice": 100000, "chancePercent": 0.35},
	{"tier": 5, "requiredLevel": 75, "itemId": "aetherium-ore", "name": "Aetherium Ore", "quantity": 1, "totalMoney": 250000, "sellPrice": 250000, "chancePercent": 0.25},
]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(not root.get_node("AuthService").is_authenticated())
	root.get_node("LocalizationManager").set_locale("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1088, 768)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene_root.add_child(viewport)
	var stage := Node2D.new()
	viewport.add_child(stage)
	var museum = load("res://scenes/overworld/kanto/towns/pewter_city/museum.tscn").instantiate()
	for npc in museum.get_node("Entities/NPCs").get_children():
		npc.npc_metadata_loaded = true
	stage.add_child(museum)
	await _frames()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(OUTPUT + "01-museum-ore-buyer.png") == OK)
	var buyer = museum.get_node("Entities/NPCs/CollectorHugo")
	buyer._confirm_sale.call_deferred({"quoteId": "public-capture-fixture", "items": ORES, "totalMoney": 445000})
	await _frames()
	var confirmation: Control
	for child in scene_root.get_children():
		if child is CanvasLayer:
			child.reparent(stage)
			confirmation = child.get_child(0)
			confirmation.popup_centered(Vector2i(560, 460))
	assert(confirmation != null and confirmation.visible and confirmation.get_viewport() == viewport)
	assert(confirmation.custom_content.get_child_count() == 5)
	await _frames()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(OUTPUT + "02-sell-all-confirmation.png") == OK)
	for child in stage.get_children():
		if child is CanvasLayer:
			child.get_child(0).canceled.emit()
	await process_frame
	museum.hide()
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 35)
	panel.custom_minimum_size = Vector2(668, 690)
	stage.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "Rock Smash · Rewards"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var rewards = load("res://scripts/ui/rock_smash_rewards.gd").new()
	rewards.custom_minimum_size = Vector2(630, 610)
	box.add_child(rewards)
	rewards.player_level = 100
	rewards.catalog = {"level": 100, "legendaryMining": ORES}
	rewards.category.select(3)
	rewards._render()
	await _frames()
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(image.get_region(Rect2i(210, 35, 668, 690)).save_png(OUTPUT + "03-legendary-mining-rewards.png") == OK)
	print("PASS museum, confirmation and native rewards captured without authentication")
	stage.free()
	viewport.free()
	scene_root.free()
	quit()

func _frames() -> void:
	for frame in range(8):
		await process_frame
