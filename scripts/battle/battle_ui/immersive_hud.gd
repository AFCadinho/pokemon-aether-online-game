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
	_place(stage.get_node("ResetCameraButton"), Vector2(area.x - 110, 16), Vector2(32, 28), 1.0)
	var mechanics: Control = battle.get_node("%MechanicsPanel")
	_place(mechanics, Vector2(area.x - 332, area.y - 233), mechanics.size, minf(0.5,120.0 / maxf(1,mechanics.size.x)))
	var center_left := area.x * 0.25
	var center_width := area.x - 354 - center_left
	_place(battle.get_node("%CurrentActionPanel"), Vector2(center_left, area.y - 125), Vector2(center_width / 0.7, 44), 0.7)
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
	var realtime_3d: bool = is_instance_valid(presenter) and presenter.active
	stage.get_node("ResetCameraButton").visible = realtime_3d
	if not realtime_3d:
		_compose_sprite_battle(stage)
		_compose_2d_team_preview()
	else:
		# The 3D presenter retains its existing compact overlay composition.
		battle.player_team_preview_layer.position = Vector2(area.x * 0.30, area.y * 0.63)
		battle.enemy_team_preview_layer.position = Vector2(area.x * 0.70, area.y * 0.39)
	if is_instance_valid(presenter) and is_instance_valid(presenter.mode_label):
		presenter.mode_label.hide()
	var occupied := Rect2()
	for index in 2:
		var hud: Control = battle.player_hud_panel if index == 0 else battle.enemy_hud_panel
		var sprite_box = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var badges: Control = sprite_box.single_stat_stage_panel
		var extent := hud.size * 0.65
		var badge_height := badges.size.y * 0.5 if is_instance_valid(badges) and badges.visible else 0.0
		var target := Vector2(area.x * (0.27 if index == 0 else 0.73) - extent.x * 0.5, 160)
		var anchored_to_sprite := false
		if is_instance_valid(presenter) and presenter.active:
			var bounds: Rect2 = presenter._visual_rect(index)
			if bounds.has_area():
				var top := stage.get_global_transform().affine_inverse() * Vector2(bounds.get_center().x, bounds.position.y)
				target = top - Vector2(extent.x * 0.5, extent.y + 12)
				anchored_to_sprite = true
		elif is_instance_valid(presenter):
			var bounds: Rect2 = sprite_box.get_single_sprite_hover_rect()
			if bounds.has_area():
				var top := stage.get_global_transform().affine_inverse() * Vector2(bounds.get_center().x, bounds.position.y)
				# In 2D the indicator badges live below the HP panel. Reserve their
				# complete height so neither row covers the Pokémon sprite.
				target = top - Vector2(extent.x * 0.5, extent.y + badge_height + 18)
				anchored_to_sprite = true
		if not realtime_3d and badge_height > 0.0 and not anchored_to_sprite:
			target.y -= badge_height + 6
		target.x = clampf(target.x, 16, area.x - extent.x - 16)
		target.y = clampf(target.y, 62, area.y - 230 - extent.y)
		var position_next := hud.position.lerp(target, 1.0 - exp(-12.0 * delta)) if initialized[index] else target
		if index == 1 and occupied.intersects(Rect2(position_next, extent + Vector2(0, 48))):
			position_next.y = occupied.position.y - extent.y - 52
			if position_next.y < 62:
				position_next.y = occupied.end.y + 8
		_place(hud, position_next, hud.size, 0.65)
		occupied = Rect2(position_next, extent + Vector2(0, 48))
		initialized[index] = true
		if is_instance_valid(badges):
			badges.set_meta("immersive_positioned", true)
			var parent_inverse := (badges.get_parent() as CanvasItem).get_global_transform().affine_inverse()
			var badge_scale := 0.5 * stage.get_global_transform().get_scale().y / maxf(0.01, (badges.get_parent() as CanvasItem).get_global_transform().get_scale().y)
			_place(badges, parent_inverse * (stage.get_global_transform() * (hud.position + Vector2(0, extent.y + 3))), badges.size, badge_scale)
		var effects: Control = battle.get_node("%SideFieldEffectsPanel" if index == 0 else "%SideFieldEffectsPanel2")
		if realtime_3d:
			_place(effects, hud.position + Vector2(0, extent.y + badge_height + 6), effects.size, 0.5)
		else:
			# Side-wide conditions are separate from the active Pokémon's own
			# indicators. Keep them beside the HP panel, toward the screen edge.
			var effects_extent := effects.size * 0.5
			var effects_x := hud.position.x - effects_extent.x - 8 if index == 0 else hud.position.x + extent.x + 8
			effects_x = clampf(effects_x, 16, area.x - effects_extent.x - 16)
			var effects_y := hud.position.y + maxf(0, (extent.y - effects_extent.y) * 0.5)
			_place(effects, Vector2(effects_x, effects_y), effects.size, 0.5)

func _place(control: Control, point: Vector2, dimensions: Vector2, factor: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = dimensions
	control.position = point
	control.scale = Vector2.ONE * factor

func _compose_sprite_battle(stage: Control) -> void:
	# Move/scale each complete sprite box and platform together. Sprite-local
	# grounding, attack motion, substitutes and platform hazards stay unchanged.
	var factor := 0.82
	for index in 2:
		var center := Vector2(stage.size.x * (0.38 if index == 0 else 0.65), stage.size.y * (0.59 if index == 0 else 0.46))
		var platform: Control = battle.player_battle_platform if index == 0 else battle.enemy_battle_platform
		var box: Control = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var platform_origin := center - Vector2(250,150) * factor
		# Offsets between the original 1152×648 platform and sprite-box origins.
		var sprite_offset := Vector2(11,-37) if index == 0 else Vector2(23,-29)
		_place(platform, platform_origin, Vector2(600,250), factor)
		_place(box, platform_origin + sprite_offset * factor, Vector2(450,293), factor)

func _compose_2d_team_preview() -> void:
	# Keep the established compact formation, but anchor it to the same platform
	# surface used by the active 2D combatant. Each side retains the small offset
	# used by the Classic composition to account for the sprite perspective.
	for index in 2:
		var platform: Control = battle.player_battle_platform if index == 0 else battle.enemy_battle_platform
		var preview: Node2D = battle.player_team_preview_layer if index == 0 else battle.enemy_team_preview_layer
		var platform_center := platform.position + Vector2(250, 150) * platform.scale
		var perspective_offset := Vector2(-40, -29) if index == 0 else Vector2(28.5, -34)
		preview.position = platform_center + perspective_offset * platform.scale
