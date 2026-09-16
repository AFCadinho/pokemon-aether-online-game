extends Control

const SLOTS := ["p2", "p4", "p1", "p3"]
const LOCATIONS := {"p1": -1, "p3": -2, "p2": 1, "p4": 2}
const ACCENT := Color("67e8bf")
const ANIMATION_WAIT := preload("res://scripts/battle/battle_animation_wait.gd")
const TARGET_OUTLINE_SHADER := """shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.42, 0.94, 1.0, 1.0);
void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 step_size = TEXTURE_PIXEL_SIZE * 2.0;
	float neighbor = min(min(texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, step_size.y)).a,
		texture(TEXTURE, UV - vec2(0.0, step_size.y)).a));
	float edge = step(0.1, base.a) * (1.0 - neighbor);
	COLOR = vec4(mix(base.rgb, glow_color.rgb, 0.12 + 0.88 * edge), base.a);
}
"""
var embedded_hosts: Dictionary = {}
var cards: Dictionary = {}
var selected_move := 0
var selected_target := ""
var displayed_cursor := -1
var displayed_battle := ""
var _decision := ""
var _revision := -1
var _playing := false
var _latest: Dictionary = {}
var _header: Label
var _connection: Label
var _prompt: Label
var _capture_status: Label
var _bag_open := false
var _capture_animation_pending := false
var _capture_target_controller := ""
var _capture_feedback_text := ""
var _capture_feedback_until_msec := 0
var _actions: VBoxContainer
var _log: RichTextLabel
var _epoch := 0
var _action_signature := ""
var _finished_return_started := false
var _finished_return_retry_available := false
var _loading_overlay: ColorRect
var _loading_label: Label
var _loading_cancel: Button
var _effects: Node
var _native_mode := false
var _native_moves: MovesGrid
var _native_log: BattleLogPanel
var _native_pokemon_hover: PokemonHoverCard
var _native_move_hover: MoveHoverCard
var _hovered_controller := ""
var _stat_overlays: Dictionary = {}
var _native_utility: Control
var _action_scroll: ScrollContainer
var _decision_overlay: ColorRect
var _decision_eyebrow: Label
var _decision_title: Label
var _decision_subtitle: Label
var _wait_button: Button
var _cancel_target_button: Button
var _native_turn: BattleStatusPanel
var _native_vs: BattleVsPanelContainer
var _native_party: PartyGrid
var _allied_party: PartyGrid
var _opponent_party: PartyGrid
var _first_trainer: BattleTrainerSprite
var _second_trainer: BattleTrainerSprite
var _trainer_identity := ""
var _native_attack_tween: Tween
var _native_animation_sprite: AnimatedSprite2D
var _native_animation_origin := Vector2.ZERO
var _target_sprite_materials: Dictionary = {}
var _target_glow_material: ShaderMaterial


func _ready() -> void:
	var field: GridContainer
	var effect_layer: Control
	if embedded_hosts.is_empty():
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var background := ColorRect.new()
		background.color = Color("101b29")
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(background)
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(scroll)
		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 24)
		scroll.add_child(margin)
		var layout := VBoxContainer.new()
		layout.add_theme_constant_override("separation", 14)
		margin.add_child(layout)
		_header = _label(layout, "CO-OP  /  CONNECTING", 28)
		_connection = _label(layout, "", 16)
		field = GridContainer.new()
		field.columns = 2
		field.add_theme_constant_override("h_separation", 24)
		field.add_theme_constant_override("v_separation", 12)
		layout.add_child(field)
		_prompt = _label(layout, "Waiting for the battle…", 22)
		_capture_status = _label(layout, "", 17)
		var deck := HBoxContainer.new()
		deck.add_theme_constant_override("separation", 24)
		layout.add_child(deck)
		_actions = VBoxContainer.new()
		_actions.custom_minimum_size.x = 440
		_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck.add_child(_actions)
		_log = RichTextLabel.new()
		_log.custom_minimum_size = Vector2(260, 190)
		_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck.add_child(_log)
		effect_layer = Control.new()
		effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(effect_layer)
	else:
		_native_mode = true
		var stage: Control = embedded_hosts["stage"]
		var prompt_panel: CurrentActionPanel = embedded_hosts["prompt"]
		var rail: Control = embedded_hosts["rail"]
		var dock_content: Control = embedded_hosts["dock_content"]
		_native_turn = embedded_hosts["turn"] as BattleStatusPanel
		_native_vs = embedded_hosts["vs"] as BattleVsPanelContainer
		_native_party = embedded_hosts["own_party"] as PartyGrid
		_allied_party = embedded_hosts["allied_party"] as PartyGrid
		_opponent_party = embedded_hosts["opponent_party"] as PartyGrid
		_first_trainer = embedded_hosts["trainer"] as BattleTrainerSprite
		_native_party.party_selected.connect(_select_switch)
		_second_trainer = preload("res://scenes/battle/battle_trainer_sprite.tscn").instantiate() as BattleTrainerSprite
		stage.add_child(_second_trainer)
		_first_trainer.position = Vector2(124, 476)
		_second_trainer.position = Vector2(184, 476)
		_first_trainer.scale = Vector2.ONE * 0.75
		_second_trainer.scale = Vector2.ONE * 0.75
		for side: String in ["player", "enemy"]:
			var sprite_box: Control = embedded_hosts[side + "_sprite"]
			sprite_box.set_double_sprite_horizontal_positions(158.0, 92.0)
		_position_native_targets.call_deferred()
		_log = RichTextLabel.new()
		_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_log.custom_minimum_size.y = 160
		rail.add_child(_log)
		_native_moves = embedded_hosts["moves"] as MovesGrid
		_native_log = embedded_hosts["log"] as BattleLogPanel
		_native_pokemon_hover = embedded_hosts["pokemon_hover"] as PokemonHoverCard
		_native_move_hover = embedded_hosts["move_hover"] as MoveHoverCard
		_native_utility = embedded_hosts["utility"] as Control
		_native_moves.move_selected.connect(_select_move)
		_native_moves.move_hovered.connect(_show_coop_move_hover)
		_native_moves.move_unhovered.connect(_hide_coop_move_hover)
		for party_grid: PartyGrid in [_native_party, _allied_party, _opponent_party]:
			party_grid.set_hover_enabled(true)
			party_grid.pokemon_hovered.connect(_show_coop_party_hover)
			party_grid.pokemon_unhovered.connect(_hide_coop_pokemon_hover)
		_native_utility.action_selected.connect(_on_native_utility_action)
		var bag: Button = stage.get_node("%BagButton")
		_wait_button = bag.duplicate(0) as Button
		_wait_button.name = "CoopWaitButton"
		_wait_button.text = "Wait"
		_wait_button.tooltip_text = "Skip your action. Your partner and wild Pokémon still act."
		bag.get_parent().add_child(_wait_button)
		bag.get_parent().move_child(_wait_button, 1)
		_wait_button.pressed.connect(func() -> void: _on_native_utility_action("wait"))
		_cancel_target_button = bag.duplicate(0) as Button
		_cancel_target_button.name = "CoopCancelTargetButton"
		_cancel_target_button.text = "Cancel"
		_cancel_target_button.tooltip_text = "Cancel target selection and choose a move again."
		bag.get_parent().add_child(_cancel_target_button)
		_cancel_target_button.pressed.connect(_cancel_target_selection)
		var utility: Control = stage.get_node("%UtilityActions")
		utility.offset_left = -244
		utility.offset_top = -240
		utility.offset_bottom = -204
		_native_moves.offset_top = -202
		_native_moves.offset_bottom = -14
		prompt_panel.offset_top = -70
		prompt_panel.offset_bottom = -14
		_native_vs.max_names_panel_width = 530.0
		for side: String in ["player", "enemy"]:
			var hud: Control = embedded_hosts[side + "_hud"]
			var controllers := ["p1", "p3"] if side == "player" else ["p2", "p4"]
			for row_index in range(hud.active_info_rows.size()):
				var row: Control = hud.active_info_rows[row_index]
				var owner_label := Label.new()
				owner_label.name = "CoopOwnerLabel"
				owner_label.add_theme_font_size_override("font_size", 12)
				owner_label.add_theme_color_override("font_color", ACCENT)
				owner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				row.add_child(owner_label)
				row.move_child(owner_label, 0)
				var stat_panel := preload("res://scenes/battle/stat_stage_panel.tscn").instantiate() as StatStagePanel
				stat_panel.name = "CoopStatStages" + controllers[row_index]
				stage.add_child(stat_panel)
				stat_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				stat_panel.z_index = 30
				_stat_overlays[controllers[row_index]] = stat_panel
		stage.resized.connect(_position_coop_stat_overlays)
		var target_shader := Shader.new()
		target_shader.code = TARGET_OUTLINE_SHADER
		_target_glow_material = ShaderMaterial.new()
		_target_glow_material.shader = target_shader
		for controller: String in SLOTS:
			var target := _button(stage, "", func() -> void: _select_target(controller))
			target.visible = false
			target.z_index = 60
			target.focus_mode = Control.FOCUS_NONE
			target.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseMotion and event.relative.length_squared() > 0.0:
					_focus_native_target(controller))
			# Keep adjacent targets separate: the two double sprites are only ~158 px apart.
			target.custom_minimum_size = Vector2(126, 152)
			target.size = Vector2(126, 152)
			var invisible_style := StyleBoxEmpty.new()
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				target.add_theme_stylebox_override(state, invisible_style)
			cards[controller] = {"target": target}
			var sprite := _native_sprite(controller)
			_target_sprite_materials[controller] = sprite.material if sprite != null else null
		stage.resized.connect(_position_native_targets)
		_position_native_targets()
		_prompt = prompt_panel.message_label
		_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_prompt.add_theme_font_size_override("font_size", 18)
		# Capture feedback belongs in the battlefield prompt, not below the party slots.
		_decision_overlay = ColorRect.new()
		_decision_overlay.name = "CoopDecisionOverlay"
		_decision_overlay.color = Color(0.02, 0.05, 0.09, 0.78)
		_decision_overlay.z_index = 65
		_decision_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		stage.add_child(_decision_overlay)
		_decision_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_decision_overlay.visible = false
		var decision_center := CenterContainer.new()
		_decision_overlay.add_child(decision_center)
		decision_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var decision_card := PanelContainer.new()
		decision_card.custom_minimum_size.x = 440.0
		var decision_style := StyleBoxFlat.new()
		decision_style.bg_color = Color("101d2d")
		decision_style.border_color = Color("3f91bb")
		decision_style.set_border_width_all(1)
		decision_style.set_corner_radius_all(16)
		decision_style.set_content_margin_all(22)
		decision_style.shadow_color = Color(0, 0, 0, 0.45)
		decision_style.shadow_size = 12
		decision_card.add_theme_stylebox_override("panel", decision_style)
		decision_center.add_child(decision_card)
		var decision_content := VBoxContainer.new()
		decision_content.add_theme_constant_override("separation", 9)
		decision_card.add_child(decision_content)
		_decision_eyebrow = Label.new()
		_decision_eyebrow.add_theme_font_size_override("font_size", 12)
		_decision_eyebrow.add_theme_color_override("font_color", Color("66d8ee"))
		decision_content.add_child(_decision_eyebrow)
		_decision_title = Label.new()
		_decision_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_decision_title.add_theme_font_size_override("font_size", 22)
		_decision_title.add_theme_color_override("font_color", Color("f4f8ff"))
		decision_content.add_child(_decision_title)
		_decision_subtitle = Label.new()
		_decision_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_decision_subtitle.add_theme_font_size_override("font_size", 13)
		_decision_subtitle.add_theme_color_override("font_color", Color("a8bacd"))
		decision_content.add_child(_decision_subtitle)
		var action_scroll := ScrollContainer.new()
		action_scroll.custom_minimum_size = Vector2(394, 46)
		decision_content.add_child(action_scroll)
		_action_scroll = action_scroll
		_actions = VBoxContainer.new()
		_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions.add_theme_constant_override("separation", 8)
		action_scroll.add_child(_actions)
		effect_layer = Control.new()
		effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(effect_layer)
	if not _native_mode:
		for controller: String in SLOTS:
			_create_card(field, controller)
	effect_layer.move_to_front()
	if _native_mode:
		_log.visible = false
	else:
		_log.scroll_following = true
		_log.bbcode_enabled = false
		_log.add_theme_font_size_override("normal_font_size", 17)
	effect_layer.name = "CoopEffectsLayer"
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects = load("res://scripts/battle/coop_battle_effects.gd").new()
	effect_layer.add_child(_effects)
	if not _native_mode:
		for controller: String in SLOTS:
			_effects.bind_pair(controller, controller, cards).prewarm_common_battle_sounds()
	CoopService.state_changed.connect(_sync)
	CoopService.request_failed.connect(_show_error)
	if _native_mode:
		_setup_loading_overlay()
	_sync()


func _setup_loading_overlay() -> void:
	_loading_overlay = ColorRect.new()
	_loading_overlay.name = "CoopBattleLoadingOverlay"
	_loading_overlay.color = Color(0.025, 0.07, 0.12, 1.0)
	_loading_overlay.z_index = 100
	_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(_loading_overlay)
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_loading_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 140)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("101c2b")
	card_style.border_color = Color("328dd4")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(14)
	card_style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	_loading_label = Label.new()
	_loading_label.text = "Starting co-op battle…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 22)
	_loading_label.add_theme_color_override("font_color", Color("d6f2ff"))
	content.add_child(_loading_label)
	var detail := Label.new()
	detail.text = "Syncing both Trainers and Pokémon"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", Color("a8bed2"))
	content.add_child(detail)
	_loading_cancel = Button.new()
	_loading_cancel.text = "Cancel"
	_loading_cancel.custom_minimum_size.y = 36
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color("132b41")
	cancel_style.border_color = Color("456d94")
	cancel_style.set_border_width_all(1)
	cancel_style.set_corner_radius_all(8)
	_loading_cancel.add_theme_stylebox_override("normal", cancel_style)
	_loading_cancel.pressed.connect(func() -> void:
		await CoopService.party_action("cancel", {"reservationId": CoopService.activity.get("reservationId", "")}))
	content.add_child(_loading_cancel)


func _create_card(parent: Control, controller: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not embedded_hosts.is_empty():
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c3040") if controller in ["p1", "p3"] else Color("302a3b")
	if not embedded_hosts.is_empty():
		style.bg_color.a = 0.78
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var name_label := _label(column, controller, 20)
	var canvas := Control.new()
	canvas.custom_minimum_size.y = 110
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	column.add_child(canvas)
	var sprite = load("res://scenes/battle/sprite_box.tscn").instantiate()
	sprite.web_sprite_upgrades_allowed = false
	canvas.add_child(sprite)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sprite.size = Vector2(450, 293)
	sprite.scale = Vector2(0.62, 0.62)
	canvas.resized.connect(func() -> void: sprite.position = Vector2(canvas.size.x * 0.5 - 152, canvas.size.y * 0.5 - 90))
	var hp := ProgressBar.new()
	hp.custom_minimum_size.y = 16
	hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(6)
	hp.add_theme_stylebox_override("fill", fill)
	column.add_child(hp)
	var info := _label(column, "Waiting…", 16)
	var target := _button(column, "Select target", func() -> void: _select_target(controller))
	target.visible = false
	cards[controller] = {"panel": panel, "name": name_label, "sprite": sprite, "hp": hp,
		"info": info, "target": target, "details": "", "canvas": canvas}


func _position_native_targets() -> void:
	if not _native_mode:
		return
	var stage: Control = embedded_hosts["stage"]
	for controller: String in SLOTS:
		var target: Button = cards[controller].target
		var sprite := _native_sprite(controller)
		if sprite != null:
			var center := stage.get_global_transform().affine_inverse() * sprite.global_position
			# Keep the old top edge but include the Pokémon's feet below its origin.
			target.position = center - Vector2(target.size.x * 0.5, target.size.y - 56.0)


func _sync() -> void:
	_latest = CoopService.view.duplicate(true)
	if _native_mode:
		_update_loading_overlay()
	if _native_mode:
		_sync_native_trainers()
		_native_vs.set_names("%s + %s" % [_trainer_name("p1"), _trainer_name("p3")], _opponent_title())
	var battle_id := str(_latest.get("battleId", ""))
	if battle_id != displayed_battle:
		if _native_mode:
			_native_pokemon_hover.hide_card()
			_native_move_hover.hide_card()
			_hovered_controller = ""
		_finished_return_started = false
		_finished_return_retry_available = false
		_epoch += 1
		_effects.cancel()
		_cancel_native_attack_tween()
		displayed_battle = battle_id
		displayed_cursor = -1
		_revision = -1
		selected_move = 0
		selected_target = ""
		if _native_mode:
			_native_log.clear_log()
		else:
			_log.clear()
			_log.add_text("Recent battle events\n")
		_apply_positions(_latest)
	if str(_latest.get("decisionId", "")) != _decision or _latest.get("locked", true):
		selected_move = 0
		selected_target = ""
		_bag_open = false
	_decision = str(_latest.get("decisionId", ""))
	if _native_mode and not _hovered_controller.is_empty():
		_show_coop_active_hover(_hovered_controller)
	_update_actions()
	if not _playing and _revision != int(_latest.get("revision", -1)):
		_present.call_deferred()


func _update_loading_overlay() -> void:
	var starting: bool = CoopService.activity.get("status") == "starting"
	_loading_overlay.visible = starting or (CoopService.activity.get("status") == "active" and CoopService.view.is_empty())
	_loading_cancel.visible = starting and CoopService.activity.get("canCancel", false)


func _process(_delta: float) -> void:
	if _native_mode and not _capture_feedback_text.is_empty() and Time.get_ticks_msec() >= _capture_feedback_until_msec:
		_capture_feedback_text = ""
		_action_signature = ""
		_update_actions()
	if _connection == null and not _native_mode:
		return
	if _native_mode:
		if _loading_overlay.visible:
			_loading_label.text = "Starting co-op battle" + ".".repeat(1 + int(Time.get_ticks_msec() / 500) % 3)
		_native_turn.hide_timer()
		_update_coop_sprite_hover()
		return
	_connection.text = "%s  ·  %s" % [
		"Partner connected" if CoopService.activity.get("partnerConnected", false) else "Partner disconnected — temporary AI after 30s",
		"Partner ready" if CoopService.view.get("partnerReady", false) else "Partner choosing"]
	if CoopService.activity.get("status") != "active":
		_connection.text = "Both Trainers share this battle. Progress and rewards are saved by the server."
	else:
		var field: Dictionary = CoopService.view.get("field", {})
		for effect in [field.get("weather", ""), field.get("terrain", "")]:
			if not str(effect).is_empty(): _connection.text += "  ·  " + str(effect).capitalize()


func _present() -> void:
	if _playing or _capture_animation_pending:
		return
	_playing = true
	_update_actions()
	var epoch := _epoch
	while _revision != int(_latest.get("revision", -1)):
		var snapshot := _latest.duplicate(true)
		var revision := int(snapshot.get("revision", -1))
		var cursor := int(snapshot.get("eventCursor", 0))
		var events: Array = snapshot.get("events", [])
		var fresh: Array = events.filter(func(event: Dictionary) -> bool: return int(event.get("seq", 0)) > displayed_cursor)
		# A capture receipt may arrive before the other Trainer commits a choice.
		# Do not consume its shared event cursor or freeze the chooser's controls.
		if fresh.any(func(event: Dictionary) -> bool: return event.get("kind") == "coopcapture" and not _capture_round_ready(snapshot, int(event.get("turn", -1)))):
			_playing = false
			_update_actions()
			return
		# Initial/reconnected snapshots and long gaps snap directly to authority.
		# Never replay old damage over current HP, or spend a minute catching up.
		var animate := displayed_cursor >= 0 and fresh.size() <= 20
		var batch_started := Time.get_ticks_msec()
		if displayed_cursor < 0:
			_apply_positions(snapshot)
		for event: Dictionary in fresh:
			_append_event(event)
			if animate and Time.get_ticks_msec() - batch_started < 6000:
				await _animate_event(event, fresh)
				if epoch != _epoch:
					_playing = false
					_present.call_deferred()
					return
		_apply_positions(snapshot)
		displayed_cursor = cursor
		_revision = revision
	_playing = false
	_update_actions()


func _apply_positions(snapshot: Dictionary) -> void:
	if _native_mode:
		_apply_native_positions(snapshot)
		return
	for controller: String in SLOTS:
		var found := false
		for position: Dictionary in snapshot.get("positions", []):
			if position.get("controller") != controller:
				continue
			found = true
			var card: Dictionary = cards[controller]
			if position.get("fainted", false):
				card.sprite.clear_pokemon()
			else:
				_set_details(controller, str(position.get("details", "")))
			var own: bool = controller == snapshot.get("participant")
			var role := "YOU" if own else "PARTNER" if controller in ["p1", "p3"] else "OPPONENT " + ("1" if controller == "p2" else "2")
			card.name.text = role + "  ·  " + str(position.get("details", ""))
			card.name.modulate = ACCENT if own else Color.WHITE
			card.hp.value = float(position.get("hpPercent", 0))
			card.hp.get_theme_stylebox("fill").bg_color = Color("f87171") if card.hp.value <= 20 else Color("facc6b") if card.hp.value <= 50 else ACCENT
			var health := "%s%% HP" % str(position.get("hpPercent", 0))
			if own:
				for pokemon: Dictionary in snapshot.get("ownTeam", []):
					if pokemon.get("active", false):
						health = "%s / %s HP" % [str(pokemon.get("hp", 0)), str(pokemon.get("maxHp", 0))]
			card.info.text = "FAINTED" if position.get("fainted", false) else health + "  " + str(position.get("status", "")).to_upper()
			var boosts: Dictionary = position.get("boosts", {})
			for stat: String in boosts:
				if int(boosts[stat]) != 0 and not position.get("fainted", false):
					card.info.text += "  %s %+d" % [stat.to_upper(), int(boosts[stat])]
			card.sprite.modulate.a = 0.25 if position.get("fainted", false) else 1.0
		if not found:
			cards[controller].sprite.clear_pokemon()
			cards[controller].name.text = _role(controller).to_upper() + "  ·  No active Pokémon"
			cards[controller].info.text = ""
			cards[controller].hp.value = 0
			cards[controller].details = ""


func _apply_native_positions(snapshot: Dictionary) -> void:
	_native_turn.set_turn(int(snapshot.get("turn", 0)))
	var own_team: Array = snapshot.get("ownTeam", [])
	_native_party.set_party(own_team)
	_native_party.set_empty_slots_visible(false)
	# Compact slots intentionally keep placeholders in singles. Doubles only
	# exposes this Trainer's actual roster, never their partner's switches.
	for index in range(_native_party.get_child_count()):
		(_native_party.get_child(index) as Control).visible = index < own_team.size()
	var partner_team: Array = snapshot.get("partnerTeam", [])
	var allied_team: Array = own_team + partner_team if snapshot.get("participant") == "p1" else partner_team + own_team
	_allied_party.set_party(allied_team)
	_allied_party.set_empty_slots_visible(true)
	var opponent_team: Array = []
	for index in range(mini(6, int(snapshot.get("opponentPartySize", 0)))):
		opponent_team.append({"unrevealed": true})
	for position: Dictionary in snapshot.get("positions", []):
		var controller := str(position.get("controller", ""))
		if controller not in ["p2", "p4"]:
			continue
		var index := 0 if controller == "p2" else 1
		if index >= opponent_team.size():
			continue
		opponent_team[index] = {"species": str(position.get("details", "")).split(",")[0].strip_edges(),
			"hp": int(position.get("hpPercent", 0)), "maxHp": 100,
			"types": position.get("types", []), "possibleAbilities": position.get("possibleAbilities", []),
			"speed": position.get("speed", {}),
			"fainted": bool(position.get("fainted", false)),
			"active": not bool(position.get("fainted", false)) and int(position.get("hpPercent", 0)) > 0}
		_opponent_party.set_party(opponent_team)
	_opponent_party.set_empty_slots_visible(false)
	var active: Dictionary = {}
	for position: Dictionary in snapshot.get("positions", []):
		active[str(position.get("controller", ""))] = position
	for side: String in ["player", "enemy"]:
		var controllers := ["p1", "p3"] if side == "player" else ["p2", "p4"]
		var sprite_box: Control = embedded_hosts[side + "_sprite"]
		var hud: Control = embedded_hosts[side + "_hud"]
		var species: Array[String] = []
		var shiny: Array[bool] = []
		for row_index in range(2):
			var controller: String = controllers[row_index]
			var owner_label: Label = hud.active_info_rows[row_index].get_node("CoopOwnerLabel")
			owner_label.text = (_trainer_name(controller) + (" · YOU" if controller == snapshot.get("participant") else "")) if side == "player" else "OPPONENT %s" % (row_index + 1)
			var position: Dictionary = active.get(controller, {})
			var stat_panel := _stat_overlays[controller] as StatStagePanel
			stat_panel.set_stat_stages(position.get("boosts", {}) if not position.get("fainted", false) else {})
			var details := str(position.get("details", ""))
			var name := details.split(",")[0].strip_edges() if not details.is_empty() else ""
			var fainted := bool(position.get("fainted", false))
			species.append("" if fainted else name)
			shiny.append(details.to_lower().contains("shiny"))
			if position.is_empty():
				hud.set_double_position(row_index, {})
				continue
			var level := 0
			var gender := ""
			for detail: String in details.split(","):
				var part := detail.strip_edges()
				if part.begins_with("L") and part.substr(1).is_valid_int():
					level = int(part.substr(1))
				elif part in ["M", "F"]:
					gender = part
			var hp := int(round(float(position.get("hpPercent", 0))))
			var max_hp := 100
			if controller == snapshot.get("participant"):
				for pokemon: Dictionary in snapshot.get("ownTeam", []):
					if pokemon.get("active", false):
						hp = int(pokemon.get("hp", hp))
						max_hp = maxi(1, int(pokemon.get("maxHp", max_hp)))
						break
			hud.set_double_position(row_index, {"species": name, "level": level,
				"gender": gender, "shiny": shiny[row_index], "hp": hp,
				"maxHp": max_hp, "status": str(position.get("status", ""))})
		sprite_box.set_double_pokemon_species(species[0], species[1],
			"back" if side == "player" else "front", shiny[0], shiny[1])
	_position_coop_stat_overlays.call_deferred()


func _position_coop_stat_overlays() -> void:
	if not _native_mode or _stat_overlays.is_empty():
		return
	var stage: Control = embedded_hosts["stage"]
	var inverse := stage.get_global_transform().affine_inverse()
	for controller: String in _stat_overlays:
		var panel := _stat_overlays[controller] as StatStagePanel
		if not panel.visible:
			continue
		var hud: Control = embedded_hosts["player_hud"] if controller in ["p1", "p3"] else embedded_hosts["enemy_hud"]
		var row_index := 1 if controller in ["p3", "p4"] else 0
		var row: Control = hud.active_info_rows[row_index]
		panel.reset_size()
		var row_rect := row.get_global_rect()
		var hud_rect := hud.get_global_rect()
		var center := inverse * Vector2(row_rect.get_center().x, hud_rect.end.y + 5.0)
		panel.position = Vector2(center.x - panel.size.x * 0.5, center.y)


func _set_details(controller: String, details: String, force := false) -> void:
	var card: Dictionary = cards[controller]
	if details.is_empty() or (not force and card.details == details and not card.sprite.current_single_species.is_empty()):
		return
	if force:
		card.sprite.clear_pokemon()
	card.details = details
	card.sprite.modulate = Color.WHITE
	card.sprite.set_single_pokemon_species(details.split(",")[0].strip_edges(), "back" if controller in ["p1", "p3"] else "front", details.contains(", shiny"))


func _update_actions() -> void:
	var signature := JSON.stringify([CoopService.activity.get("status"), CoopService.view.get("revision"),
		CoopService.pending_command.get("idempotencyKey"), selected_move, _playing, _bag_open])
	if signature == _action_signature:
		return
	_action_signature = signature
	if _native_mode:
		_sync_action_scroll.call_deferred()
		_native_moves.set_input_disabled(false)
		_native_moves.visible = false
		_native_utility.set_action_visible("bag", false)
		_native_utility.set_action_visible("run", false)
		_wait_button.visible = false
		_cancel_target_button.visible = false
		_native_party.set_selection_enabled(false)
	if not _native_mode:
		var last_capture: Dictionary = CoopService.view.get("lastCapture", {}) if CoopService.view.get("lastCapture") is Dictionary else CoopService.activity.get("lastCapture", {}) if CoopService.activity.get("lastCapture") is Dictionary else {}
		_capture_status.text = ""
		if not last_capture.is_empty():
			_capture_status.text = "Caught! Your Pokémon will be saved when the shared battle finishes." if last_capture.get("caught", false) else "The Pokémon escaped from your ball (%s shakes)." % str(last_capture.get("shakeCount", 0))
		var acquisitions: Array = CoopService.activity.get("captures", CoopService.view.get("captures", []))
		if not acquisitions.is_empty():
			var location: Dictionary = acquisitions[0].get("storageLocation", {})
			_capture_status.text = "Caught Pokémon saved to your party." if location.get("type") == "party" else "Caught Pokémon saved to your PC."
		_capture_status.visible = not _capture_status.text.is_empty()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for card: Dictionary in cards.values():
		card.target.visible = false
	if _native_mode:
		_refresh_target_highlight()
	var phase := str(CoopService.activity.get("status", "starting"))
	if not _native_mode:
		_header.text = "CO-OP  /  TURN %s" % str(CoopService.view.get("turn", 1))
	if phase in ["finished", "cancelled"]:
		var outcomes := {"win": "Victory — both Trainers won.", "loss": "Both teams were defeated.", "draw": "The battle ended in a draw."}
		_prompt.text = "Battle start cancelled." if phase == "cancelled" else str(outcomes.get(CoopService.activity.get("outcome"), "Battle finished."))
		if phase == "finished" and CoopService.activity.get("escaped", false):
			_prompt.text = "Both Trainers fled from the wild battle."
		elif phase == "finished" and CoopService.activity.get("forfeited", false):
			_prompt.text = "Both Trainers forfeited the battle."
		if phase == "finished" and not _finished_return_started:
			_finished_return_started = true
			_auto_return_after_finish.call_deferred()
		if phase == "cancelled" or _finished_return_retry_available:
			_button(_actions, "Return to the world", func() -> void:
				var world := GameState.get_world()
				if world != null: await world.call("finish_coop_activity"))
		return


	if phase == "starting" or CoopService.view.is_empty():
		_prompt.text = "Connecting both Trainers…"
		if CoopService.activity.get("canCancel", false) and not _native_mode:
			_button(_actions, "Cancel start", func() -> void: await CoopService.party_action("cancel", {"reservationId": CoopService.activity.reservationId}))
		return
	if not CoopService.pending_command.is_empty():
		_prompt.text = "Checking your choice…"
		_button(_actions, "Check / retry my choice", func() -> void: await CoopService.retry_command())
		return
	var exit_request: Dictionary = CoopService.view.get("exitRequest", {}) if CoopService.view.get("exitRequest") is Dictionary else {}
	if not exit_request.is_empty() and not CoopService.view.get("ended", false):
		var fleeing: bool = exit_request.get("type") == "run"
		if exit_request.get("requestedBy") == CoopService.view.get("participant"):
			_prompt.text = "Waiting for your partner to agree to flee…" if fleeing else "Waiting for your partner to agree to forfeit…"
		else:
			_prompt.text = "Your partner wants to flee. Do you agree?" if fleeing else "Your partner wants to forfeit. Both Trainers will lose. Do you agree?"
			for action: Dictionary in CoopService.view.get("legalActions", []):
				var staying: bool = action.get("type") == "reject-exit"
				var label := "Stay and choose again" if staying else "Agree to flee" if fleeing else "Agree to forfeit"
				if not _native_mode:
					label = "Stay — both choose again" if staying else "Agree — flee together" if fleeing else "Agree — forfeit together"
				_decision_button(label, "secondary" if staying else "primary", func() -> void: await CoopService.submit_action(action))
		return
	if _playing or CoopService.view.get("ended", false) or CoopService.view.get("locked", true):
		_prompt.text = "Saving the result…" if CoopService.view.get("ended", false) else "Battle in progress…" if _playing else "Waiting for the other actions…"
		_show_capture_feedback_in_prompt()
		return
	_prompt.text = "Choose a replacement from your team." if CoopService.view.get("forceSwitch", false) else "Choose a move, then its target — or switch your Pokémon."
	if _native_mode:
		var display_moves: Array = []
		for move: Dictionary in CoopService.view.get("moves", []):
			var prepared := move.duplicate()
			prepared["disabled"] = bool(move.get("disabled", false)) or _move_actions(int(move.get("slot", 0))).is_empty()
			display_moves.append(prepared)
		_native_moves.set_moves(display_moves)
		_native_moves.set_input_disabled(selected_move > 0)
		_native_moves.visible = not display_moves.is_empty() and not CoopService.view.get("forceSwitch", false) and not _bag_open
		_native_party.set_selection_enabled(true)
		for slot_index in range(_native_party.get_child_count()):
			var party_slot := _native_party.get_child(slot_index) as Button
			if party_slot == null:
				continue
			var legal := false
			for action: Dictionary in CoopService.view.get("legalActions", []):
				if action.get("type") == "switch" and int(action.get("slot", 0)) == slot_index + 1:
					legal = true
			party_slot.disabled = not legal
	var capture_options: Dictionary = CoopService.view.get("captureOptions", {}) if CoopService.view.get("captureOptions") is Dictionary else {}
	if not capture_options.is_empty():
		if _native_mode:
			_native_utility.set_action_visible("bag", true)
			_native_utility.set_action_label("bag", "BAG")
		else:
			var bag_button := _button(_actions, "Bag — catch your own target", func() -> void:
				_bag_open = not _bag_open
				selected_move = 0
				_update_actions())
			bag_button.tooltip_text = "Only your assigned wild Pokémon can be caught. Either Trainer can attack either target."
		if _bag_open:
			if not capture_options.get("storageAvailable", false):
				_label(_actions, "Your party and PC are full. No ball will be used.", 17)
			elif capture_options.get("balls", []).is_empty():
				_label(_actions, "You have no available Poké Balls.", 17)
			else:
				for ball: Dictionary in capture_options.get("balls", []):
					var item_id: String = str(ball.get("itemId", ""))
					var label := "%s    ×%s" % [item_id.replace("-", " ").capitalize(), str(ball.get("quantity", 0))]
					if _native_mode:
						_decision_button(label, "item", func() -> void: await _submit_capture_with_preview(item_id))
					else:
						_button(_actions, "%s ×%s — your target" % [item_id.replace("-", " ").capitalize(), str(ball.get("quantity", 0))], func() -> void: await _submit_capture_with_preview(item_id))
			if _native_mode:
				_decision_button("Back to battle", "secondary", func() -> void:
					_bag_open = false
					_action_signature = ""
					_update_actions())
	for action: Dictionary in CoopService.view.get("legalActions", []):
		if action.get("type") == "run":
			if _native_mode:
				_native_utility.set_action_visible("run", true)
				_native_utility.set_action_label("run", "Run")
			else:
				_button(_actions, "Run — ask your partner", func() -> void: await CoopService.submit_action(action))
		elif action.get("type") == "forfeit":
			if _native_mode:
				_native_utility.set_action_visible("run", true)
				_native_utility.set_action_label("run", "Forfeit")
			else:
				var forfeit_button := _button(_actions, "Forfeit — ask your partner", func() -> void: await CoopService.submit_action(action))
				forfeit_button.tooltip_text = "Both Trainers must agree. Forfeiting counts as a loss with the normal defeat penalty."
		elif action.get("type") == "wait":
			if _native_mode:
				_wait_button.visible = true
			else:
				var wait_button := _button(_actions, "Wait — skip my action", func() -> void: await CoopService.submit_action(action))
				wait_button.tooltip_text = "Use no PP and give your partner another catch attempt. Wild Pokémon still act."
	if not _native_mode:
		var moves := GridContainer.new()
		moves.columns = 2
		_actions.add_child(moves)
		for move: Dictionary in CoopService.view.get("moves", []):
			var slot := int(move.get("slot", 0))
			var choices := _move_actions(slot)
			var button := _button(moves, "%s  ·  %s PP" % [str(move.get("name", "")), str(move.get("pp", 0))], func() -> void: _select_move(slot))
			button.disabled = choices.is_empty()
			button.modulate = ACCENT if selected_move == slot else Color.WHITE
	if selected_move > 0:
		_prompt.text = "Choose a target: click a Pokémon or use arrows + Space. Cancel to choose another move."
		if _native_mode:
			_native_utility.set_action_visible("bag", false)
			_native_utility.set_action_visible("run", false)
			_wait_button.visible = false
			_cancel_target_button.visible = true
			_native_party.set_selection_enabled(false)
		else:
			_button(_actions, "Cancel target selection", _cancel_target_selection)
		var legal_targets: Array[String] = []
		for action: Dictionary in _move_actions(selected_move):
			for controller: String in SLOTS:
				if action.get("target") == LOCATIONS[controller]:
					cards[controller].target.visible = true
					if _native_mode:
						cards[controller].target.tooltip_text = "Target " + _role(controller)
					else:
						cards[controller].target.text = "Target " + _role(controller)
					if not legal_targets.has(controller):
						legal_targets.append(controller)
		if not legal_targets.has(selected_target):
			selected_target = ""
			for controller: String in SLOTS:
				if legal_targets.has(controller):
					selected_target = controller
					break
		_refresh_target_highlight()
	if not _native_mode:
		var switches := HBoxContainer.new()
		_actions.add_child(switches)
		for action: Dictionary in CoopService.view.get("legalActions", []):
			if action.get("type") != "switch": continue
			var pokemon: Dictionary = CoopService.view.get("ownTeam", [])[int(action.slot) - 1]
			_button(switches, "%s\n%s/%s HP" % [str(pokemon.get("species", "")), str(pokemon.get("hp", 0)), str(pokemon.get("maxHp", 0))], func() -> void: await CoopService.submit_action(action))
	else:
		_show_capture_feedback_in_prompt()


func _show_capture_feedback_in_prompt() -> void:
	if _native_mode and not _capture_feedback_text.is_empty():
		_prompt.text = _capture_feedback_text


func _submit_capture_with_preview(item_id: String) -> void:
	if _capture_animation_pending:
		return
	var options: Dictionary = CoopService.view.get("captureOptions", {}) if CoopService.view.get("captureOptions") is Dictionary else {}
	_capture_target_controller = str(options.get("targetController", "p2" if CoopService.view.get("participant") == "p1" else "p4"))
	_capture_animation_pending = _native_mode
	await CoopService.submit_capture(item_id)
	if not is_inside_tree():
		return
	_capture_animation_pending = false
	_action_signature = ""
	_update_actions()
	if _revision != int(_latest.get("revision", -1)):
		_present.call_deferred()


func _capture_round_ready(view: Dictionary, chosen_turn: int) -> bool:
	return (bool(view.get("locked", false)) and bool(view.get("partnerReady", false))) or int(view.get("turn", -1)) > chosen_turn or bool(view.get("ended", false))


func _play_native_capture_preview(item_id: String, accepted: Dictionary) -> void:
	var target := _native_sprite(_capture_target_controller)
	var capture_player: CaptureBallAnimationPlayer = embedded_hosts.get("capture_player") as CaptureBallAnimationPlayer
	if target == null or capture_player == null:
		return
	var center := target.get_global_transform_with_canvas().origin
	await capture_player.play_capture_preview(str(accepted.get("itemId", item_id)),
		clampi(int(accepted.get("shakeCount", 0)), 0, 3), bool(accepted.get("caught", false)),
		Rect2(center - Vector2(48, 48), Vector2(96, 96)))


func set_capture_target_visible(is_visible: bool) -> void:
	var target := _native_sprite(_capture_target_controller)
	if target != null:
		target.visible = is_visible


func _auto_return_after_finish() -> void:
	# A finished receipt can arrive before the last turn's event playback ends.
	# Let a confirmed throw and the final events reach the screen first.
	var capture_deadline := Time.get_ticks_msec() + 18000
	while is_inside_tree() and _capture_animation_pending and Time.get_ticks_msec() < capture_deadline:
		await get_tree().process_frame
	var playback_deadline := Time.get_ticks_msec() + 7000
	while is_inside_tree() and (_playing or _revision != int(_latest.get("revision", -1))) and Time.get_ticks_msec() < playback_deadline:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var world := GameState.get_world()
	if world != null:
		await world.call("finish_coop_activity")
	if not is_inside_tree():
		return
	if not is_instance_valid(world) or (CoopService.activity.get("status") == "finished" and not bool(world.get("coop_finishing"))):
		_finished_return_retry_available = true
		_action_signature = ""
		_update_actions()


func _move_actions(slot: int) -> Array:
	return CoopService.view.get("legalActions", []).filter(func(action: Dictionary) -> bool: return action.get("type") == "move" and action.get("slot") == slot)


func _sync_action_scroll() -> void:
	if _native_mode and is_instance_valid(_action_scroll):
		var action_count := _actions.get_child_count()
		_decision_overlay.visible = action_count > 0
		_action_scroll.visible = action_count > 0
		_action_scroll.custom_minimum_size.y = minf(224.0, maxf(46.0, float(action_count) * 56.0 + float(maxi(0, action_count - 1)) * 8.0))
		var exit_request: Dictionary = CoopService.view.get("exitRequest", {}) if CoopService.view.get("exitRequest") is Dictionary else {}
		var capture_options: Dictionary = CoopService.view.get("captureOptions", {}) if CoopService.view.get("captureOptions") is Dictionary else {}
		if _bag_open and not capture_options.is_empty():
			_decision_eyebrow.text = "BAG  /  POKÉ BALLS"
			_decision_title.text = "Choose a Poké Ball"
			_decision_subtitle.text = "Catch your assigned wild Pokémon. Your partner's target stays theirs."
		elif not exit_request.is_empty() and exit_request.get("requestedBy") != CoopService.view.get("participant"):
			_decision_eyebrow.text = "CO-OP  /  PARTNER REQUEST"
			_decision_title.text = "Flee together?" if exit_request.get("type") == "run" else "Forfeit together?"
			_decision_subtitle.text = "Both Trainers leave the battle if you agree." if exit_request.get("type") == "run" else "Both Trainers will lose if you agree."
		else:
			_decision_eyebrow.text = "CO-OP  /  BATTLE"
			_decision_title.text = _prompt.text
			_decision_subtitle.text = ""
		_decision_subtitle.visible = not _decision_subtitle.text.is_empty()


func _select_switch(slot: int) -> void:
	if _playing or selected_move > 0 or CoopService.view.get("locked", true):
		return
	for action: Dictionary in CoopService.view.get("legalActions", []):
		if action.get("type") == "switch" and int(action.get("slot", 0)) == slot:
			await CoopService.submit_action(action)
			return


func _on_native_utility_action(action: String) -> void:
	if not _native_mode or _playing or selected_move > 0 or CoopService.view.get("locked", true):
		return
	if action == "bag":
		_bag_open = not _bag_open
		selected_move = 0
		_update_actions()
	elif action in ["run", "wait"]:
		for choice: Dictionary in CoopService.view.get("legalActions", []):
			if choice.get("type") == action or (action == "run" and choice.get("type") == "forfeit"):
				await CoopService.submit_action(choice)
				return


func _select_move(slot: int) -> void:
	if selected_move > 0:
		return
	var actions := _move_actions(slot)
	if actions.is_empty() or _playing: return
	if actions.size() == 1 and not actions[0].has("target"):
		await CoopService.submit_action(actions[0])
		return
	selected_move = slot
	selected_target = ""
	_update_actions()


func _cancel_target_selection() -> void:
	if selected_move <= 0 or not CoopService.pending_command.is_empty():
		return
	selected_move = 0
	selected_target = ""
	_update_actions()


func _select_target(controller: String) -> void:
	if _playing or not CoopService.pending_command.is_empty() or selected_move <= 0:
		return
	for action: Dictionary in _move_actions(selected_move):
		if action.get("target") == LOCATIONS.get(controller):
			selected_target = controller
			_refresh_target_highlight()
			await CoopService.submit_action(action)
			return


func _input(event: InputEvent) -> void:
	if not _native_mode or selected_move <= 0 or _playing or not CoopService.pending_command.is_empty():
		return
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control is LineEdit or focused_control is TextEdit:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var targets: Array[String] = []
	for controller: String in SLOTS:
		if cards[controller].target.visible:
			targets.append(controller)
	if targets.is_empty():
		return
	match event.keycode:
		KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN:
			var direction := -1 if event.keycode in [KEY_LEFT, KEY_UP] else 1
			_focus_native_target(targets[posmod(targets.find(selected_target) + direction, targets.size())])
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER:
			get_viewport().set_input_as_handled()
			_select_target(selected_target)
		KEY_ESCAPE:
			_cancel_target_selection()
			get_viewport().set_input_as_handled()


func _focus_native_target(controller: String) -> void:
	if not _native_mode or selected_move <= 0 or not cards[controller].target.visible:
		return
	selected_target = controller
	_refresh_target_highlight()


func _refresh_target_highlight() -> void:
	if not _native_mode:
		return
	for controller: String in SLOTS:
		var target: Button = cards[controller].target
		var sprite := _native_sprite(controller)
		if sprite != null:
			sprite.material = _target_glow_material if target.visible and controller == selected_target else _target_sprite_materials.get(controller)


func _append_event(event: Dictionary) -> void:
	var controller := str(event.get("actor", ""))
	var actor := _combatant_name(controller)
	var text := ""
	match str(event.get("kind", "")):
		"turn": text = "— Turn %s —" % str(event.get("turn", ""))
		"move": text = "%s used %s!" % [actor, str(event.get("move", ""))]
		"coopcapture": text = "%s caught a wild Pokémon!" % _role(controller) if event.get("caught", false) else "The wild Pokémon escaped from %s's ball!" % _role(controller)
		"switch", "drag", "replace": text = _send_out_message(controller, str(event.get("details", "")))
		"faint": text = "%s fainted." % actor
		"-damage": text = "%s is at %s%% HP." % [actor, str(event.get("hpPercent", 0))]
		"-heal": text = "%s recovered health!" % actor
		"-status": text = "%s is %s!" % [actor, _status_name(str(event.get("status", "")))]
		"-curestatus": text = "%s recovered from its status!" % actor
		"-boost", "-unboost": text = "%s %s for %s!" % [_stat_name(str(event.get("stat", ""))), "rose" if event.get("kind") == "-boost" else "fell", actor]
		"-setboost": text = "%s changed for %s!" % [_stat_name(str(event.get("stat", ""))), actor]
		"-start", "-end": text = "%s's %s %s." % [actor, str(event.get("condition", "")).capitalize(), "ended" if event.kind == "-end" else "started"]
		"-miss": text = "%s's attack missed!" % actor
		"cant": text = "%s couldn't move!" % actor
		"win", "tie": text = "Battle ended."
	if not text.is_empty():
		if _native_mode:
			if event.get("kind") == "turn":
				_native_log.add_turn_header(int(event.get("turn", 0)))
			else:
				_native_log.add_message(text)
		else:
			_log.add_text(text + "\n")
			if _log.get_line_count() > 220:
				_log.remove_paragraph(0)


func _combatant_name(controller: String) -> String:
	for position: Dictionary in _latest.get("positions", []):
		if position.get("controller") != controller:
			continue
		var species := str(position.get("details", "")).split(",")[0].strip_edges()
		if not species.is_empty():
			if controller in ["p2", "p4"] and str(CoopService.activity.get("activityId", "")).begins_with("wild_"):
				return "Wild %s (%s)" % [species, "1" if controller == "p2" else "2"]
			return "%s's %s" % [_role(controller), species]
	return _role(controller)


func _stat_name(stat: String) -> String:
	return {"atk": "Attack", "def": "Defense", "spa": "Sp. Atk", "spd": "Sp. Def", "spe": "Speed", "accuracy": "accuracy", "evasion": "evasiveness"}.get(stat, stat)


func _status_name(status: String) -> String:
	return {"psn": "poisoned", "tox": "badly poisoned", "par": "paralyzed", "brn": "burned", "slp": "asleep", "frz": "frozen"}.get(status, status)


func _send_out_message(controller: String, details: String) -> String:
	var pokemon := details.split(",")[0].strip_edges()
	if pokemon.is_empty():
		return ""
	if controller in ["p2", "p4"]:
		return "A wild %s has appeared!" % pokemon if str(CoopService.activity.get("activityId", "")).begins_with("wild_") else "%s sent out %s!" % [_opponent_title(), pokemon]
	if controller == CoopService.view.get("participant"):
		return "Go! %s!" % pokemon
	if controller in ["p1", "p3"]:
		return "%s sent out %s!" % [_trainer_name(controller), pokemon]
	return ""


func _animate_event(event: Dictionary, batch: Array = []) -> void:
	if _native_mode:
		match str(event.get("kind", "")):
			"coopcapture":
				_capture_target_controller = str(event.get("target", ""))
				if SettingsManager.battle_animations:
					await _play_native_capture_preview(str(event.get("itemId", "poke-ball")), event)
				if event.get("actor") == CoopService.view.get("participant"):
					_capture_feedback_text = "Caught! Your Pokémon will be saved when the shared battle finishes." if event.get("caught", false) else "The Pokémon escaped from your ball (%s shakes)." % str(event.get("shakeCount", 0))
				else:
					_capture_feedback_text = "%s caught a wild Pokémon!" % _role(str(event.get("actor", ""))) if event.get("caught", false) else "%s's wild Pokémon escaped from the ball." % _role(str(event.get("actor", "")))
				_capture_feedback_until_msec = Time.get_ticks_msec() + 4000
			"move":
				if SettingsManager.battle_animations:
					await _play_native_attack(str(event.get("actor", "")))
			"-damage", "-heal":
				if SettingsManager.battle_animations and event.get("kind") == "-damage":
					await _play_native_hit(str(event.get("actor", "")))
				_apply_native_event_hp(event)
		return
	var actor := str(event.get("actor", ""))
	if not cards.has(actor): return
	var card: Dictionary = cards[actor]
	match str(event.get("kind", "")):
		"move":
			await _effects.play_move(event, batch, cards)
			return
		"-damage", "-heal":
			card.hp.value = float(event.get("hpPercent", 0))
			await _effects.play_feedback(event, cards)
			return
		"faint", "-boost", "-unboost":
			await _effects.play_feedback(event, cards)
			return
		"switch", "drag", "replace", "detailschange": _set_details(actor, str(event.get("details", "")), true)
		_: return
	await get_tree().create_timer(0.32 if event.get("kind") == "faint" else 0.22).timeout


func _apply_native_event_hp(event: Dictionary) -> void:
	var controller := str(event.get("actor", ""))
	if not event.has("hpPercent") or controller not in SLOTS:
		return
	var hud: Control = embedded_hosts["player_hud"] if controller in ["p1", "p3"] else embedded_hosts["enemy_hud"]
	var row_index := 1 if controller in ["p3", "p4"] else 0
	var hp_bar: ProgressBar = hud.active_info_rows[row_index].get_node_or_null("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
	if hp_bar != null:
		hp_bar.value = clampf(float(event.get("hpPercent", 0)), 0.0, 100.0)


func _native_sprite(controller: String) -> AnimatedSprite2D:
	if not _native_mode or controller not in SLOTS:
		return null
	var box: Control = embedded_hosts["player_sprite"] if controller in ["p1", "p3"] else embedded_hosts["enemy_sprite"]
	var sprite_path := "DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite" if controller in ["p1", "p2"] else "DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2"
	return box.get_node_or_null(sprite_path) as AnimatedSprite2D


func _update_coop_sprite_hover() -> void:
	var hovered := ""
	var mouse := get_global_mouse_position()
	for controller: String in SLOTS:
		var sprite := _native_sprite(controller)
		if sprite == null or not sprite.visible:
			continue
		var box: Control = embedded_hosts["player_sprite"] if controller in ["p1", "p3"] else embedded_hosts["enemy_sprite"]
		if (box.call("_get_sprite_hover_rect", sprite) as Rect2).has_point(mouse):
			hovered = controller
			break
	if hovered != _hovered_controller:
		_hovered_controller = hovered
		if hovered.is_empty():
			_hide_coop_pokemon_hover()
		else:
			_show_coop_active_hover(hovered)
	elif not hovered.is_empty() and _native_pokemon_hover.visible:
		_native_pokemon_hover.position_near_mouse(mouse, get_viewport_rect().size)


func _show_coop_active_hover(controller: String) -> void:
	for position: Dictionary in _latest.get("positions", []):
		if position.get("controller") != controller or position.get("fainted", false):
			continue
		var details := str(position.get("details", ""))
		var data := {"ident": controller + ": " + details.split(",")[0].strip_edges(),
			"species": details.split(",")[0].strip_edges(), "types": position.get("types", []),
			"possibleAbilities": position.get("possibleAbilities", []), "speed": position.get("speed", {}),
			"limitedBattleView": true, "status": position.get("status", ""),
			"hp": int(position.get("hpPercent", 0)), "maxHp": 100}
		var own: bool = controller == _latest.get("participant")
		var ability := ""
		var item := ""
		if own:
			for pokemon: Dictionary in _latest.get("ownTeam", []):
				if pokemon.get("active", false):
					data["hp"] = pokemon.get("hp", 0)
					data["maxHp"] = pokemon.get("maxHp", 1)
					var owned := _owned_hover_details(int(pokemon.get("slot", 0)), str(data.get("species", "")))
					data["possibleAbilities"] = owned.get("possibleAbilities", data.get("possibleAbilities", []))
					ability = str(owned.get("ability", ""))
					item = str(owned.get("item", ""))
					break
		_native_pokemon_hover.show_for_pokemon(data, _latest.get("moves", []) if own else [], item, ability,
			{}, data.get("speed", {}))
		_native_pokemon_hover.position_near_mouse(get_global_mouse_position(), get_viewport_rect().size)
		return


func _show_coop_party_hover(data: Dictionary, slot_rect: Rect2) -> void:
	if data.get("unrevealed", false):
		return
	_hovered_controller = ""
	var display := data.duplicate(true)
	display["limitedBattleView"] = true
	var owned := _owned_hover_details(int(data.get("slot", 0)), str(data.get("species", "")))
	if not owned.is_empty():
		display["types"] = owned.get("types", display.get("types", []))
		display["possibleAbilities"] = owned.get("possibleAbilities", [])
	_native_pokemon_hover.show_for_pokemon(display, owned.get("moves", []),
		str(owned.get("item", "")), str(owned.get("ability", "")), {}, display.get("speed", {}))
	_native_pokemon_hover.position_near_mouse(slot_rect.get_center(), get_viewport_rect().size)


func _owned_hover_details(slot: int, species: String) -> Dictionary:
	if slot < 1 or slot > PlayerSave.party.size():
		return {}
	var saved := PlayerSave.party[slot - 1] as Pokemon
	if saved == null or saved.species.to_lower() != species.to_lower():
		return {}
	return saved.to_battle_dict()


func _hide_coop_pokemon_hover() -> void:
	_hovered_controller = ""
	_native_pokemon_hover.hide_card()


func _show_coop_move_hover(data: Dictionary, slot_rect: Rect2) -> void:
	_native_move_hover.show_for_move(data)
	_native_move_hover.position_near_rect(slot_rect, get_viewport_rect().size)


func _hide_coop_move_hover() -> void:
	_native_move_hover.hide_card()


func _cancel_native_attack_tween() -> void:
	if _native_attack_tween != null and _native_attack_tween.is_valid():
		_native_attack_tween.kill()
	if is_instance_valid(_native_animation_sprite):
		_native_animation_sprite.position = _native_animation_origin
		_native_animation_sprite.modulate = Color.WHITE
	_native_attack_tween = null
	_native_animation_sprite = null


func _play_native_attack(controller: String) -> void:
	var sprite := _native_sprite(controller)
	if sprite == null or not sprite.visible:
		return
	_cancel_native_attack_tween()
	_native_animation_sprite = sprite
	_native_animation_origin = sprite.position
	var direction := Vector2(-24.0, 0.0) if controller in ["p2", "p4"] else Vector2(24.0, 0.0)
	_native_attack_tween = create_tween()
	_native_attack_tween.tween_property(sprite, "position", _native_animation_origin + direction, 0.09)
	_native_attack_tween.tween_property(sprite, "position", _native_animation_origin, 0.13)
	await ANIMATION_WAIT.for_tween(self, _native_attack_tween, 1.0)
	_cancel_native_attack_tween()


func _play_native_hit(controller: String) -> void:
	var sprite := _native_sprite(controller)
	if sprite == null or not sprite.visible:
		return
	_cancel_native_attack_tween()
	_native_animation_sprite = sprite
	_native_animation_origin = sprite.position
	_native_attack_tween = create_tween()
	_native_attack_tween.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.07)
	_native_attack_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	await ANIMATION_WAIT.for_tween(self, _native_attack_tween, 1.0)
	_cancel_native_attack_tween()


func _exit_tree() -> void:
	_cancel_native_attack_tween()


func _show_error(message: String) -> void:
	_prompt.text = message


func _role(controller: String) -> String:
	if _native_mode:
		if controller in ["p1", "p3"]:
			return _trainer_name(controller)
		if controller in ["p2", "p4"]:
			return "%s %s" % [_opponent_title(), "1" if controller == "p2" else "2"]
	if controller == CoopService.view.get("participant"): return "you"
	if controller in ["p1", "p3"]: return "partner"
	if controller == "p2": return "opponent 1"
	if controller == "p4": return "opponent 2"
	return "field"


func _party_member_id(controller: String) -> int:
	var leader_id := int(CoopService.party.get("leaderId", 0))
	if controller == "p1":
		return leader_id
	for member_id: Variant in CoopService.party.get("memberIds", []):
		if int(member_id) != leader_id:
			return int(member_id)
	return 0


func _trainer_name(controller: String) -> String:
	var names: Dictionary = CoopService.party.get("memberUsernames", {})
	var name := str(names.get(str(_party_member_id(controller)), "")).strip_edges()
	return name if not name.is_empty() else "Trainer %s" % ("1" if controller == "p1" else "2")


func _opponent_title() -> String:
	var activity_id := str(CoopService.activity.get("activityId", ""))
	if activity_id.begins_with("wild_"):
		return "Wild Pokémon"
	if activity_id.contains("gary"):
		return "Gary"
	if activity_id.contains("brock"):
		return "Brock"
	return "Trainer"


func _sync_native_trainers() -> void:
	if str(CoopService.activity.get("activityId", "")).begins_with("wild_"):
		if _trainer_identity != "wild":
			_first_trainer.clear()
			_second_trainer.clear()
			_trainer_identity = "wild"
		return
	var appearances: Dictionary = CoopService.party.get("memberAppearances", {})
	var first: Dictionary = appearances.get(str(_party_member_id("p1")), {})
	var second: Dictionary = appearances.get(str(_party_member_id("p3")), {})
	if CoopService.view.get("participant") == "p1" and first.is_empty():
		first = PlayerSave.to_appearance_state()
	elif CoopService.view.get("participant") == "p3" and second.is_empty():
		second = PlayerSave.to_appearance_state()
	var identity := JSON.stringify([first, second])
	if identity == _trainer_identity:
		return
	_trainer_identity = identity
	if not first.is_empty():
		_first_trainer.show_player(first, Vector2.RIGHT)
	if not second.is_empty():
		_second_trainer.show_player(second, Vector2.RIGHT)


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _decision_button(text: String, variant: String, callback: Callable) -> Button:
	var button := _button(_actions, text, callback)
	if not _native_mode:
		return button
	button.custom_minimum_size.y = 50
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if variant == "item" else HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("eff8ff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var base := Color("174f61") if variant == "primary" else Color("142637") if variant == "item" else Color("11202f")
	var border := Color("65d9df") if variant == "primary" else Color("315d77") if variant == "item" else Color("29445b")
	button.add_theme_stylebox_override("normal", _decision_button_style(base, border))
	button.add_theme_stylebox_override("hover", _decision_button_style(base.lightened(0.16), Color("8ce7ee")))
	button.add_theme_stylebox_override("pressed", _decision_button_style(base.darkened(0.15), Color("8ce7ee")))
	button.add_theme_stylebox_override("focus", _decision_button_style(Color.TRANSPARENT, Color("b4f1ff")))
	return button


func _decision_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(12)
	return style
