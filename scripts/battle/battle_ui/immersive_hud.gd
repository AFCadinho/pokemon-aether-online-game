extends Node
## Screen-space presentation only; the existing battle owns every control/signal.
var battle: Control
var initialized := [false, false]

func _ready() -> void:
	process_priority = 100

func _process(delta: float) -> void:
	var stage: Control = battle.battle_stage
	var area := stage.size
	# Legacy visibility refreshes still run; the floating rail owns its bounds.
	battle.get_node("%ActionChoices").hide()
	battle.battle_log_toggle_button.hide()
	battle.calc_log_button.hide()
	_place(battle.battle_log_rail, Vector2(18,150), Vector2(310,maxf(180,battle.size.y - 420)), 1.0)
	var team_preview: Control = battle.get_node("%PlayerStagePartyRail")
	_place(team_preview, Vector2(18, 90), team_preview.size, 0.75)
	var opponent_rail: Control = battle.get_node("%OpponentStagePartyRail")
	_place(opponent_rail, Vector2(area.x - 62, 90), opponent_rail.size, 0.75)
	_place(battle.get_node("%MovesGrid"), Vector2(area.x - 340, area.y - 170), Vector2(400, 188), 0.8)
	_place(battle.get_node("%UtilityActions"), Vector2(area.x - 204, area.y - 210), Vector2(178, 34), 0.8)
	_place(stage.get_node("ImmersiveBattleMenu"), Vector2(area.x - 52, area.y - 210), Vector2(36, 28), 1.0)
	var mechanics: Control = battle.get_node("%MechanicsPanel")
	_place(mechanics, Vector2(area.x - 332, area.y - 233), mechanics.size, minf(0.5,120.0 / maxf(1,mechanics.size.x)))
	var center_left := area.x * 0.25
	var center_width := area.x - 354 - center_left
	_place(battle.get_node("%CurrentActionPanel"), Vector2(center_left, area.y - 155), Vector2(center_width / 0.7, 56), 0.7)
	# Stage and root HUD have distinct logical coordinate systems.
	var to_battle := battle.get_global_transform().affine_inverse() * stage.get_global_transform()
	var dock: Control = battle.get_node("%ActionsDock")
	var dock_factor := minf(0.8, center_width / 1000.0) * stage.scale.x
	_place(dock, to_battle * Vector2(center_left,area.y - 95), Vector2(center_width * stage.scale.x / dock_factor,106),dock_factor)
	var header: Control = battle.get_node("%VSPanelContainer")
	_place(header, Vector2((area.x - header.size.x * 0.65) * 0.5, 12), header.size, 0.65)
	var turn: Control = battle.get_node("%BattleStatusPanel")
	_place(turn, Vector2(94, 14), turn.size, 0.6)
	var presenter = battle.animation_router.model_presenter
	if is_instance_valid(presenter) and is_instance_valid(presenter.mode_label):
		presenter.mode_label.hide()
	for index in 2:
		var hud: Control = battle.player_hud_panel if index == 0 else battle.enemy_hud_panel
		var extent := hud.size * 0.65
		var target := Vector2(area.x * (0.27 if index == 0 else 0.73) - extent.x * 0.5, 160)
		if is_instance_valid(presenter) and presenter.active:
			var bounds: Rect2 = presenter._visual_rect(index)
			if bounds.has_area():
				var top := stage.get_global_transform().affine_inverse() * Vector2(bounds.get_center().x, bounds.position.y)
				target = top - Vector2(extent.x * 0.5, extent.y + 12)
		elif is_instance_valid(presenter):
			var box = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
			var bounds: Rect2 = box.get_single_sprite_hover_rect()
			if bounds.has_area():
				var top := stage.get_global_transform().affine_inverse() * Vector2(bounds.get_center().x, bounds.position.y)
				target = top - Vector2(extent.x * 0.5, extent.y + 12)
		target.x = clampf(target.x, 16, area.x - extent.x - 16)
		target.y = clampf(target.y, 62, area.y - 230 - extent.y)
		var position_next := hud.position.lerp(target, 1.0 - exp(-12.0 * delta)) if initialized[index] else target
		_place(hud, position_next, hud.size, 0.65)
		initialized[index] = true
		var effects: Control = battle.get_node("%SideFieldEffectsPanel" if index == 0 else "%SideFieldEffectsPanel2")
		_place(effects, hud.position + Vector2(0, extent.y + 4), effects.size, 0.75)

func _place(control: Control, point: Vector2, dimensions: Vector2, factor: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = dimensions
	control.position = point
	control.scale = Vector2.ONE * factor
