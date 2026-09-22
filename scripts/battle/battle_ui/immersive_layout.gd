extends RefCounted
## Reuses existing controls/signals. Applied once by the dedicated screen host.
static func _move(node: Node, battle: Node) -> void:
	node.owner = null
	node.reparent(battle, false)
	node.owner = battle

static func apply(battle: Control) -> void:
	battle.set_meta("immersive_battle_ui", true)
	battle.get_node("%CalcPanel").set_meta("immersive_calculator", true)
	var calc_scroll: ScrollContainer = battle.get_node("%CalcPanel/CalcScroll")
	calc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	calc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var typography := preload("res://scripts/battle/battle_ui/immersive_typography.gd").new()
	typography.name = "ImmersiveTypography"
	typography.battle = battle
	battle.add_child(typography)
	var hud_tracker := preload("res://scripts/battle/battle_ui/immersive_hud.gd").new()
	hud_tracker.battle = battle
	battle.add_child(hud_tracker)
	var portraits := preload("res://scripts/battle/battle_ui/immersive_portraits.gd").new()
	portraits.battle = battle
	battle.add_child(portraits)
	var camera_input := preload("res://scripts/battle/battle_ui/immersive_camera_input.gd").new()
	camera_input.name = "ImmersiveCameraInput"
	camera_input.battle = battle
	battle.add_child(camera_input)
	battle.get_node("%MovesGrid").custom_minimum_size = Vector2(400, 188)
	var frame: Control = battle.get_node("%BattleFrame")
	_move(frame, battle)
	battle.move_child(frame, 0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var margin: MarginContainer = frame.get_node("MarginContainer")
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
	var stage_view = battle.get_node("%BattleStageViewport")
	stage_view.expand_design = true
	var opponent_rail: Control = battle.get_node("%OpponentStagePartyRail")
	opponent_rail.anchor_left = 1.0
	opponent_rail.anchor_right = 1.0
	opponent_rail.offset_left = -74
	opponent_rail.offset_right = -18
	var dock: Control = battle.get_node("%ActionsDock")
	_move(dock, battle)
	dock.z_index = 70
	dock.scale = Vector2.ONE * 0.8
	dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	battle.get_node("%ContextPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var party: Control = battle.get_node("%PlayerPartyGrid")
	var switch_label := Label.new()
	switch_label.name = "PartySwitchLabel"
	switch_label.text = "Switch"
	switch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	switch_label.custom_minimum_size = Vector2(124, 34)
	switch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_label.add_theme_color_override("font_color", Color("f0faff"))
	var switch_style := StyleBoxFlat.new()
	switch_style.bg_color = Color("10334ff5")
	switch_style.border_color = Color("62d7ff")
	switch_style.set_border_width_all(2)
	switch_style.set_corner_radius_all(7)
	switch_style.content_margin_left = 10
	switch_style.content_margin_right = 10
	switch_label.add_theme_stylebox_override("normal", switch_style)
	party.get_parent().add_child(switch_label)
	party.get_parent().move_child(switch_label, party.get_index())
	switch_label.visible = party.visible
	party.visibility_changed.connect(func(): switch_label.visible = party.visible)
	var rail: Control = battle.get_node("%BattleLogRail")
	_move(rail, battle)
	rail.z_index = 90
	rail.hide()
	battle.get_node("%BattleLogPanel/MarginContainer/VBoxContainer/BattleLogText").custom_minimum_size.y = 100
	var calc: Control = battle.get_node("%CalcLogButton")
	_move(calc, battle)
	calc.custom_minimum_size = Vector2(130, 36)
	calc.z_index = 90
	calc.hide()
	var menu := Button.new()
	menu.name = "ResetCameraButton"
	menu.text = "↺"
	menu.tooltip_text = "Reset camera and zoom"
	menu.theme = calc.theme
	menu.add_theme_stylebox_override("normal", calc.get_theme_stylebox("normal"))
	battle.get_node("%BattleStage").add_child(menu)
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("071323fa")
	popup_style.border_color = Color("329bdf")
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(8)
	popup_style.content_margin_left = 12
	popup_style.content_margin_right = 12
	menu.add_theme_stylebox_override("normal",popup_style)
	menu.pressed.connect(func():
		var presenter = battle.animation_router.model_presenter
		if is_instance_valid(presenter):
			presenter.reset_user_camera())
	battle.get_node("%ActionChoices").hide()
	battle.get_node("%HBoxContainer").hide()
	battle.get_node("BattleBackdrop").hide()
	var log_button: Button = battle.get_node("%BattleLogButton")
	log_button.custom_minimum_size = Vector2(95, 32)
	log_button.add_theme_font_size_override("font_size", 16)
	log_button.text = "Battle log"
	var hud: Control = battle.get_node("%PlayerHudPanel")
	hud.position = Vector2(80, 58)
	var prompt: Control = battle.get_node("%CurrentActionPanel")
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color("061222c7")
	prompt_style.border_color = Color("329bdfb0")
	prompt_style.set_border_width_all(1)
	prompt_style.border_width_left = 3
	prompt_style.set_corner_radius_all(12)
	prompt_style.shadow_color = Color("02081155")
	prompt_style.shadow_size = 5
	prompt.add_theme_stylebox_override("panel",prompt_style)
	prompt.offset_top = -187
	prompt.offset_bottom = -131
	var update := func():
		var width := battle.size.x
		var height := battle.size.y
		dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var center_left := width * 0.25
		var center_right := width - 354
		dock.position = Vector2(center_left, height - 129)
		dock.size = Vector2((center_right - center_left) / 0.8, 136)
		rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		rail.position = Vector2(18, 150)
		rail.size = Vector2(310, maxf(180, height - 420))
		log_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		log_button.position = Vector2(18, 100)
		log_button.size = Vector2(95, 32)
		calc.position = Vector2(120, 100)
		calc.size = Vector2(130, 36)
	battle.resized.connect(update)
	update.call()
	stage_view._update_stage_transform.call_deferred()
