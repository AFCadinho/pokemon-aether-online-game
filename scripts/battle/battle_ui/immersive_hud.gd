extends Node
## Screen-space presentation only; the existing battle owns every control/signal.
var battle: Control
var initialized := [false, false]

func _process(delta: float) -> void:
	var stage: Control = battle.battle_stage
	var area := stage.size
	battle.get_node("%PlayerStagePartyRail").hide()
	_place(battle.get_node("%MovesGrid"), Vector2(area.x - 340, area.y - 170), Vector2(400, 188), 0.8)
	_place(battle.get_node("%UtilityActions"), Vector2(area.x - 162, area.y - 210), Vector2(178, 34), 0.8)
	var mechanics: Control = battle.get_node("%MechanicsPanel")
	_place(mechanics, Vector2(area.x - 410, area.y - 95), mechanics.size, 0.65)
	_place(battle.get_node("%CurrentActionPanel"), Vector2(20, area.y - 143), Vector2(630, 56), 0.7)
	var header: Control = battle.get_node("%VSPanelContainer")
	_place(header, Vector2((area.x - header.size.x * 0.65) * 0.5, 12), header.size, 0.65)
	var turn: Control = battle.get_node("%BattleStatusPanel")
	_place(turn, Vector2(16, 12), turn.size, 0.7)
	var presenter = battle.animation_router.model_presenter
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
