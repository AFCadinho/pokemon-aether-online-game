extends RefCounted
## Reuses existing controls/signals. Applied once by the dedicated screen host.
static func _move(node: Node, battle: Node) -> void:
	node.owner = null
	node.reparent(battle, false)
	node.owner = battle

static func apply(battle: Control) -> void:
	battle.set_meta("immersive_battle_ui", true)
	var hud_tracker := preload("res://scripts/battle/battle_ui/immersive_hud.gd").new()
	hud_tracker.battle = battle
	battle.add_child(hud_tracker)
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
	dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rail: Control = battle.get_node("%BattleLogRail")
	_move(rail, battle)
	rail.z_index = 90
	rail.hide()
	var calc: Control = battle.get_node("%CalcLogButton")
	_move(calc, battle)
	calc.custom_minimum_size = Vector2(130, 36)
	calc.z_index = 90
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
	prompt.offset_top = -155
	prompt.offset_bottom = -99
	var update := func():
		var width := battle.size.x
		var height := battle.size.y
		dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		dock.position = Vector2(16, height - 122)
		dock.size = Vector2(width * 0.55 - 28, 106)
		rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		rail.position = Vector2(18, 150)
		rail.size = Vector2(310, maxf(220, height - 340))
		log_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		log_button.position = Vector2(18, 100)
		log_button.size = Vector2(95, 32)
		calc.position = Vector2(120, 100)
		calc.size = Vector2(130, 36)
	battle.resized.connect(update)
	update.call()
	stage_view._update_stage_transform.call_deferred()
