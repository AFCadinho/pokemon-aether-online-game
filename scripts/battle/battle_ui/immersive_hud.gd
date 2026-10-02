extends Node
## Screen-space presentation only; the existing battle owns every control/signal.
const COOP_SLOTS := ["p1", "p3", "p2", "p4"]
const COOP_HUD_SCENE := preload("res://scenes/battle/pokemon_hud_panel.tscn")
var battle: Control
var initialized := [false, false]
var coop_huds: Dictionary = {}
var coop_huds_active := false

func _ready() -> void:
	process_priority = 100

func _process(delta: float) -> void:
	if battle.has_meta("battle_entry_pending"):
		return
	var stage: Control = battle.battle_stage
	var area := stage.size
	# Legacy visibility refreshes still run; the floating rail owns its bounds.
	battle.get_node("%ActionChoices").hide()
	battle.battle_log_toggle_button.hide()
	battle.calc_log_button.hide()
	_place(battle.battle_log_rail, Vector2(18,150), Vector2(310,maxf(180,battle.size.y - 420)), 1.0)
	var team_preview: Control = battle.get_node("%PlayerStagePartyRail")
	var party_rail_top := Vector2(18, 90)
	var party_rail_scale := 0.75
	var chat_bridge: Node = battle.get_meta("battle_chat_bridge") as Node if battle.has_meta("battle_chat_bridge") else null
	if is_instance_valid(chat_bridge):
		var calculator: Control = chat_bridge.get("calculator_button") as Control
		if is_instance_valid(calculator):
			# Both controls live on different canvas layers. Reserve a screen-space
			# gap above the calculator when a shorter window compresses the field.
			var stage_screen := stage.get_global_transform_with_canvas()
			var rail_top_screen := (stage_screen * party_rail_top).y
			var calculator_top_screen := (calculator.get_global_transform_with_canvas() * Vector2.ZERO).y
			var rail_height := maxf(1.0, maxf(team_preview.size.y, team_preview.get_combined_minimum_size().y))
			var available := calculator_top_screen - rail_top_screen - 12.0
			party_rail_scale = minf(party_rail_scale,
				maxf(0.1, available / (rail_height * maxf(0.01, stage_screen.get_scale().y))))
	_place(team_preview, party_rail_top, team_preview.size, party_rail_scale)
	var opponent_rail: Control = battle.get_node("%OpponentStagePartyRail")
	_place(opponent_rail, Vector2(area.x - 62, 90), opponent_rail.size, 0.75)
	var player_portrait := stage.get_node_or_null("TrainerPortrait0") as Control
	var opponent_portrait := stage.get_node_or_null("TrainerPortrait1") as Control
	var field_indicators: Control = battle.field_timers_panel
	var field_anchor := Vector2(94, 12)
	if player_portrait != null:
		field_anchor = Vector2(player_portrait.position.x + player_portrait.size.x + 12, player_portrait.position.y)
	if battle.coop_mode:
		field_anchor = Vector2(130, 20)
	_place(field_indicators, field_anchor, field_indicators.size, 0.65)
	var settings := get_node("/root/SettingsManager")
	var ui_factor := float(settings.get("ui_scale")) / 100.0
	var window_fit := get_node("/root/WindowFit")
	var touch_factor := 1.5 if window_fit.call("is_mobile_browser_ui") else 1.0
	var move_scale := minf(0.8 * ui_factor * touch_factor, maxf(0.4, (area.x * 0.5) / 400.0))
	var move_delta := Vector2(400, 188) * (move_scale - 0.8)
	var moves_position := Vector2(area.x - 340, area.y - 170) - move_delta
	_place(battle.get_node("%MovesGrid"), moves_position, Vector2(400, 188), move_scale)
	var utility_position := Vector2(area.x - 204, moves_position.y - 40) - Vector2(178, 34) * (move_scale - 0.8)
	_place(battle.get_node("%UtilityActions"), utility_position, Vector2(178, 34), move_scale)
	var mechanics: Control = battle.get_node("%MechanicsPanel")
	_place(mechanics, Vector2(area.x - 332 - move_delta.x, utility_position.y - 23), mechanics.size, minf(0.5,120.0 / maxf(1,mechanics.size.x)))
	var center_left := area.x * 0.25
	var center_width := area.x - 354 - move_delta.x - center_left
	var prompt: Control = battle.get_node("%CurrentActionPanel")
	var prompt_y := area.y - 140.0
	var prompt_width := center_width
	var replay_transport: Control = null
	if battle.spectator_action_panel.visible:
		# The spectator card is taller than the normal action row. Reserve a
		# distinct message row above it, including after a browser resize.
		prompt_y = area.y - 141.0
	elif battle.replay_mode and is_instance_valid(battle.replay_controls):
		var transport_value: Variant = battle.replay_controls.get("transport_overlay")
		if is_instance_valid(transport_value):
			replay_transport = transport_value as Control
			# Replays add a second command surface. Keep transport beside the
			# message and reserve a clear row above the replay dock.
			var transport_size := replay_transport.get_combined_minimum_size()
			transport_size.x = maxf(transport_size.x, replay_transport.size.x)
			transport_size.y = maxf(transport_size.y, replay_transport.size.y)
			prompt_width = minf(
				prompt_width,
				maxf(180.0, area.x - transport_size.x - 40.0 - center_left)
			)
			prompt_y = area.y - 145.0
			replay_transport.set_anchors_preset(Control.PRESET_TOP_LEFT)
			replay_transport.size = transport_size
			replay_transport.position = Vector2(
				area.x - transport_size.x - 24.0,
				area.y - transport_size.y - 105.0
			)
	_place(prompt, Vector2(center_left, prompt_y), Vector2(prompt_width / 0.7, 44), 0.7)
	# Stage and root HUD have distinct logical coordinate systems.
	var to_battle := battle.get_global_transform().affine_inverse() * stage.get_global_transform()
	var dock: Control = battle.get_node("%ActionsDock")
	var dock_factor := minf(0.8, center_width / 1000.0) * stage.scale.x
	_place(dock, to_battle * Vector2(center_left,area.y - 95), Vector2(center_width * stage.scale.x / dock_factor,106),dock_factor)
	var header: Control = battle.get_node("%VSPanelContainer")
	_place(header, Vector2((area.x - header.size.x * 0.65) * 0.5, 12), header.size, 0.65)
	var turn: Control = battle.get_node("%BattleStatusPanel")
	var turn_scale := 0.6
	var opponent_portrait_left := opponent_portrait.position.x if opponent_portrait != null and opponent_portrait.visible else area.x - (62 if battle.coop_mode else 82)
	var turn_x := opponent_portrait_left - turn.size.x * turn_scale - 12
	_place(turn, Vector2(maxf(16, turn_x), 14), turn.size, turn_scale)
	var reset_camera: Control = stage.get_node("ResetCameraButton")
	var turn_extent := turn.size * turn_scale
	_place(reset_camera, Vector2(
		turn.position.x + (turn_extent.x - 32.0) * 0.5,
		turn.position.y + turn_extent.y + 6.0
	), Vector2(32, 28), 1.0)
	var presenter = battle.animation_router.model_presenter
	var realtime_3d: bool = is_instance_valid(presenter) and presenter.active
	reset_camera.visible = realtime_3d
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
		else:
			var bounds := Rect2()
			if battle.coop_mode and sprite_box.has_method("get_double_animation_visual_rect_in_node"):
				bounds = sprite_box.get_double_animation_visual_rect_in_node(stage)
			else:
				var global_bounds: Rect2 = sprite_box.get_single_sprite_hover_rect()
				if global_bounds.has_area():
					var inverse := stage.get_global_transform().affine_inverse()
					bounds = Rect2(inverse * global_bounds.position, inverse * global_bounds.end - inverse * global_bounds.position)
			if bounds.has_area():
				var top := Vector2(bounds.get_center().x, bounds.position.y)
				# In 2D the indicator badges live below the HP panel. Reserve their
				# complete height so neither row covers the Pokémon sprite.
				var doubles_indicator_clearance := 26.0 if battle.coop_mode else 0.0
				target = top - Vector2(extent.x * 0.5, extent.y + badge_height + doubles_indicator_clearance + 18)
				anchored_to_sprite = true
		if not realtime_3d and badge_height > 0.0 and not anchored_to_sprite:
			target.y -= badge_height + 6
		target.x = clampf(target.x, 16, area.x - extent.x - 16)
		target.y = clampf(target.y, 62, area.y - 230 - extent.y)
		var position_next := hud.position.lerp(target, 1.0 - exp(-12.0 * delta)) if initialized[index] else target
		# Keep the HP panel above a newly revealed or rising 3D model.
		# Easing upwards can otherwise leave it inside the model for a few frames.
		if realtime_3d and anchored_to_sprite:
			position_next.y = minf(position_next.y, target.y)
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
		var side_rail: Control = team_preview if index == 0 else opponent_rail
		var effects_extent := effects.size * 0.5
		var rail_extent := side_rail.size * side_rail.scale
		var effects_x := side_rail.position.x + rail_extent.x + 8 if index == 0 else side_rail.position.x - effects_extent.x - 8
		effects_x = clampf(effects_x, 16, area.x - effects_extent.x - 16)
		_place(effects, Vector2(effects_x, side_rail.position.y), effects.size, 0.5)
	_update_coop_3d_huds(stage, presenter, area, battle.coop_mode and realtime_3d and presenter.double_mode)

func _update_coop_3d_huds(stage: Control, presenter: Node, area: Vector2, enabled: bool) -> void:
	if not enabled:
		if coop_huds_active:
			battle.player_hud_panel.show()
			battle.enemy_hud_panel.show()
			if is_instance_valid(battle.coop_presenter):
				for panel: Control in battle.coop_presenter._stat_overlays.values():
					panel.scale = Vector2.ONE
				battle.coop_presenter._position_coop_stat_overlays.call_deferred()
		for card: Control in coop_huds.values():
			card.hide()
		coop_huds_active = false
		return
	if coop_huds.is_empty():
		for controller: String in COOP_SLOTS:
			var card: Control = COOP_HUD_SCENE.instantiate()
			card.name = "Coop3DHud" + controller
			stage.add_child(card)
			card.set_double_layout(false)
			card.set_experience_bar_enabled(false)
			card.z_index = 40
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.scale = Vector2.ONE * 0.5
			var row: Control = card.active_info_rows[0]
			var owner := Label.new()
			owner.name = "CoopOwnerLabel"
			owner.add_theme_font_size_override("font_size", 12)
			owner.add_theme_color_override("font_color", Color("67e8bf"))
			row.add_child(owner)
			row.move_child(owner, 0)
			coop_huds[controller] = card
	for controller: String in COOP_SLOTS:
		var card: Control = coop_huds[controller]
		var source: Control = battle.player_hud_panel if controller in ["p1", "p3"] else battle.enemy_hud_panel
		var source_row: Control = source.active_info_rows[1 if controller in ["p3", "p4"] else 0]
		var data_value: Variant = source_row.get_meta("battle_hud_data", {})
		if not presenter.handles(controller) or not source_row.visible or not data_value is Dictionary or (data_value as Dictionary).is_empty():
			card.hide()
			continue
		var data := data_value as Dictionary
		if card.get_meta("coop_source_data", {}) != data:
			card.set_pokemon_data(str(data.get("species", "")), int(data.get("level", 0)),
				int(data.get("current_hp", 0)), int(data.get("max_hp", 100)), str(data.get("status", "")),
				str(data.get("gender", "")), bool(data.get("is_shiny", false)), {}, str(data.get("display_name", "")))
			card.set_meta("coop_source_data", data.duplicate(true))
		var owner_source := source_row.get_node_or_null("CoopOwnerLabel") as Label
		var owner_target := card.active_info_rows[0].get_node("CoopOwnerLabel") as Label
		owner_target.text = owner_source.text if owner_source != null else ""
		var source_bar := source_row.get_node_or_null("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
		var target_bar := card.active_info_rows[0].get_node("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
		if source_bar != null and target_bar != null:
			target_bar.value = source_bar.value
		card.reset_size()
	var allied_sizes: Array[Vector2] = [coop_huds["p1"].size, coop_huds["p3"].size]
	var opponent_sizes: Array[Vector2] = [coop_huds["p2"].size, coop_huds["p4"].size]
	var layout := plan_3d_hud_layout(area, allied_sizes, opponent_sizes)
	for index in COOP_SLOTS.size():
		var controller: String = COOP_SLOTS[index]
		var card: Control = coop_huds[controller]
		var allied := index < 2
		var group_index := index if allied else index - 2
		var positions: Array[Vector2] = layout["allies"] if allied else layout["opponents"]
		card.scale = Vector2.ONE * float(layout["ally_scale"] if allied else layout["opponent_scale"])
		card.position = positions[group_index]
		if presenter.handles(controller) and not card.get_meta("coop_source_data", {}).is_empty():
			card.show()
		else:
			card.hide()
		var extent := card.size * card.scale
		var stat_panel: Control = battle.coop_presenter._stat_overlays.get(controller) as Control
		if is_instance_valid(stat_panel) and stat_panel.visible:
			stat_panel.scale = card.scale
			stat_panel.position = Vector2(card.position.x + (extent.x - stat_panel.size.x * stat_panel.scale.x) * 0.5, card.position.y + extent.y + 4.0)
	battle.player_hud_panel.hide()
	battle.enemy_hud_panel.hide()
	coop_huds_active = true

static func plan_3d_hud_layout(area: Vector2, allied_sizes: Array[Vector2], opponent_sizes: Array[Vector2]) -> Dictionary:
	var ally_positions: Array[Vector2] = []
	var opponent_positions: Array[Vector2] = []
	var ally_width := 0.0
	var opponent_width := 0.0
	for dimensions: Vector2 in allied_sizes:
		ally_width += dimensions.x
	for dimensions: Vector2 in opponent_sizes:
		opponent_width += dimensions.x
	var gap := 8.0
	var top := 84.0
	if opponent_sizes.size() >= 3:
		# A horde keeps the player's HP on the left and puts wild Pokémon in
		# a right-hand grid: three above, with the remaining two centered below.
		var first_row_count := mini(3, opponent_sizes.size())
		var second_row_count := opponent_sizes.size() - first_row_count
		var first_width := 0.0
		var second_width := 0.0
		var first_height := 0.0
		var second_height := 0.0
		for index in opponent_sizes.size():
			var dimensions: Vector2 = opponent_sizes[index]
			if index < first_row_count:
				first_width += dimensions.x
				first_height = maxf(first_height, dimensions.y)
			else:
				second_width += dimensions.x
				second_height = maxf(second_height, dimensions.y)
		var right_start := area.x * 0.39
		var right_margin := clampf(area.x * 0.06, 60.0, 96.0)
		var right_width := maxf(1.0, area.x - right_start - right_margin)
		var first_gaps := gap * maxi(0, first_row_count - 1)
		var second_gaps := gap * maxi(0, second_row_count - 1)
		var opponent_scale := minf(0.5,
			minf(maxf(1.0, right_width - first_gaps) / maxf(1.0, first_width),
				maxf(1.0, right_width - second_gaps) / maxf(1.0, second_width)))
		var first_x := right_start + (right_width - first_width * opponent_scale - first_gaps) * 0.5
		var second_x := right_start + (right_width - second_width * opponent_scale - second_gaps) * 0.5
		var second_y := top + first_height * opponent_scale + gap
		for index in opponent_sizes.size():
			var dimensions: Vector2 = opponent_sizes[index]
			if index < first_row_count:
				opponent_positions.append(Vector2(first_x, top))
				first_x += dimensions.x * opponent_scale + gap
			else:
				opponent_positions.append(Vector2(second_x, second_y))
				second_x += dimensions.x * opponent_scale + gap
		var grid_height := first_height * opponent_scale
		if second_row_count > 0:
			grid_height += gap + second_height * opponent_scale
		var ally_gaps := gap * maxi(0, allied_sizes.size() - 1)
		var ally_margin := clampf(area.x * 0.09, 72.0, 128.0)
		var ally_scale := minf(0.5, maxf(1.0, right_start - ally_margin - 16.0 - ally_gaps) / maxf(1.0, ally_width))
		var ally_height := 0.0
		for dimensions: Vector2 in allied_sizes:
			ally_height = maxf(ally_height, dimensions.y * ally_scale)
		var ally_y := top + maxf(0.0, (grid_height - ally_height) * 0.5)
		var ally_x := ally_margin
		for dimensions: Vector2 in allied_sizes:
			ally_positions.append(Vector2(ally_x, ally_y))
			ally_x += dimensions.x * ally_scale + gap
		return {"allies": ally_positions, "opponents": opponent_positions,
			"ally_scale": ally_scale, "opponent_scale": opponent_scale}
	var count := allied_sizes.size() + opponent_sizes.size()
	var team_gap := 28.0 if not allied_sizes.is_empty() and not opponent_sizes.is_empty() else 0.0
	var gaps := gap * maxi(0, count - 1) + team_gap
	var scale := minf(0.5, maxf(1.0, area.x - 32.0 - gaps) / maxf(1.0, ally_width + opponent_width))
	var row_width := (ally_width + opponent_width) * scale + gaps
	var row_x := (area.x - row_width) * 0.5
	for dimensions: Vector2 in allied_sizes:
		ally_positions.append(Vector2(row_x, top))
		row_x += dimensions.x * scale + gap
	row_x += team_gap
	for dimensions: Vector2 in opponent_sizes:
		opponent_positions.append(Vector2(row_x, top))
		row_x += dimensions.x * scale + gap
	return {"allies": ally_positions, "opponents": opponent_positions,
		"ally_scale": scale, "opponent_scale": scale}

func _place(control: Control, point: Vector2, dimensions: Vector2, factor: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = dimensions
	control.position = point
	control.scale = Vector2.ONE * factor

func _compose_sprite_battle(stage: Control) -> void:
	# Move/scale each complete sprite box and platform together. Sprite-local
	# grounding, attack motion, substitutes and platform hazards stay unchanged.
	# Doubles needs two distinct fields with room for both Pokémon on each side.
	# This path runs only while the realtime 3D presenter is inactive.
	var factor := 0.72 if battle.coop_mode else 0.82
	for index in 2:
		var center: Vector2
		if battle.coop_mode:
			center = Vector2(stage.size.x * (0.36 if index == 0 else 0.68), stage.size.y * (0.60 if index == 0 else 0.45))
		else:
			center = Vector2(stage.size.x * (0.38 if index == 0 else 0.65), stage.size.y * (0.59 if index == 0 else 0.46))
		var platform: Control = battle.player_battle_platform if index == 0 else battle.enemy_battle_platform
		var box: Control = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var sprite_platform_origin := center - Vector2(250,150) * factor
		var platform_scale := Vector2(factor * (1.25 if battle.coop_mode else 1.0), factor)
		var platform_origin := center - Vector2(250,150) * platform_scale
		if battle.coop_mode:
			# The grass image has a broad transparent top. Lift and widen only the
			# platform so both grounded sprites sit on its visible surface.
			platform_origin.y -= 18.0
		# Offsets between the original 1152×648 platform and sprite-box origins.
		var sprite_offset := Vector2(11,-37) if index == 0 else Vector2(23,-29)
		_place(platform, platform_origin, Vector2(600,250), factor)
		platform.scale = platform_scale
		_place(box, sprite_platform_origin + sprite_offset * factor, Vector2(450,293), factor)

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
