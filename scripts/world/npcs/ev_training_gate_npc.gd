@tool
extends DialogueNPC

class_name EvTrainingGateNPC

signal stat_selected(stat: String)

const STATS := [
	{"id": "hp", "label": "HP", "accent": Color("#ff697d")},
	{"id": "atk", "label": "Attack", "accent": Color("#f2a45f")},
	{"id": "def", "label": "Defense", "accent": Color("#dfc65b")},
	{"id": "spa", "label": "Sp. Attack", "accent": Color("#61c9f5")},
	{"id": "spd", "label": "Sp. Defense", "accent": Color("#74d690")},
	{"id": "spe", "label": "Speed", "accent": Color("#d986df")},
]

const UI_SURFACE := Color("#06111ded")
const UI_SURFACE_RAISED := Color("#0a1b2af7")
const UI_SURFACE_INSET := Color("#030914e8")
const UI_BORDER := Color("#31536c")
const UI_BORDER_SOFT := Color("#20384c")
const UI_TEXT := Color("#f3f5f7")
const UI_TEXT_MUTED := Color("#a9b8c5")
const UI_GOLD := Color("#d8b767")
const UI_GOLD_BRIGHT := Color("#f0d58f")
const TRAINER_SCHOOL_QUEST_ID := "learn_at_trainer_school"

@export var inside_marker_path: NodePath
@export var outside_marker_path: NodePath
@export var inside_direction := Vector2.DOWN

var choice_layer: CanvasLayer
var choice_root: Control


func interact_with_player(player: Node2D) -> void:
	if not StoryService.is_requirement_met(TRAINER_SCHOOL_QUEST_ID, "", "completed"):
		await show_dialogue([
			LocalizationManager.text("ui.ev_training.assistant.pre_lesson"),
		], display_name)
		return
	if _is_player_inside(player):
		await _leave_training_area(player)
	else:
		await _enter_training_area(player)


func _enter_training_area(player: Node2D) -> void:
	var status: Dictionary = await EvTrainingService.get_session()
	if not bool(status.get("success", false)):
		await GameErrorDialogService.show_response(status, "ui.ev_training.assistant.error.unavailable")
		return
	var session: Dictionary = status.get("session", {})
	var tutorial: Dictionary = status.get("tutorial", {})
	if bool(session.get("active", false)):
		var stat_label := _stat_label(str(session.get("stat", "")))
		await show_dialogue([
			LocalizationManager.text("ui.ev_training.assistant.session_active", {"stat": stat_label}),
		], display_name)
		_teleport_player(player, inside_marker_path, -inside_direction)
		return
	if not bool(tutorial.get("unlocked", false)):
		if str(tutorial.get("stepId", "")) != "defeat_training_targets":
			await show_dialogue([
				LocalizationManager.text("ui.ev_training.assistant.authorization_required"),
				LocalizationManager.text("ui.ev_training.assistant.authorization_hint"),
			], display_name)
			return
		var tutorial_response: Dictionary = await EvTrainingService.start_tutorial_session()
		if not bool(tutorial_response.get("success", false)):
			await GameErrorDialogService.show_response(
				tutorial_response,
				"ui.ev_training.assistant.error.tutorial_start"
			)
			return
		var active_tutorial: Dictionary = tutorial_response.get("tutorial", {})
		await show_dialogue([
			LocalizationManager.text(
				"ui.ev_training.assistant.tutorial_ready",
				{"target": str(active_tutorial.get("targetSpeciesName", "Pokemon"))}
			),
			LocalizationManager.text(
				"ui.ev_training.assistant.tutorial_participation",
				{"pokemon": str(active_tutorial.get("pokemonName", "Pokemon"))}
			),
		], display_name)
		_teleport_player(player, inside_marker_path, -inside_direction)
		return

	await show_dialogue([
		LocalizationManager.text("ui.ev_training.assistant.introduction"),
		LocalizationManager.text(
			"ui.ev_training.assistant.fee_explanation",
			{"fee": int(session.get("fee", 500))}
		),
		LocalizationManager.text("ui.ev_training.assistant.choose_stat"),
	], display_name)
	var selected_stat := await _show_stat_prompt(int(session.get("fee", 500)))
	if selected_stat.is_empty():
		return
	var response: Dictionary = await EvTrainingService.start_session(selected_stat)
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "ui.ev_training.assistant.error.session_start")
		return
	await show_dialogue([
		LocalizationManager.text(
			"ui.ev_training.assistant.session_started",
			{"stat": _stat_label(selected_stat)}
		),
	], display_name)
	_teleport_player(player, inside_marker_path, -inside_direction)


func _leave_training_area(player: Node2D) -> void:
	var response: Dictionary = await EvTrainingService.end_session()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "ui.ev_training.assistant.error.session_end")
		return
	var tutorial: Dictionary = response.get("tutorial", {})
	if str(tutorial.get("stepId", "")) == "defeat_training_targets":
		await show_dialogue([
			LocalizationManager.text(
				"ui.ev_training.assistant.lesson_paused",
				{
					"defeated": int(tutorial.get("defeated", 0)),
					"required": int(tutorial.get("requiredDefeats", 4)),
					"target": str(tutorial.get("targetSpeciesName", "Pokemon")),
				}
			),
		], display_name)
	else:
		await show_dialogue([
			LocalizationManager.text("ui.ev_training.assistant.session_complete"),
		], display_name)
	_teleport_player(player, outside_marker_path, inside_direction)


func _is_player_inside(player: Node2D) -> bool:
	return (player.global_position - global_position).dot(inside_direction) > 0.0


func _teleport_player(player: Node2D, marker_path: NodePath, facing: Vector2) -> void:
	var marker := get_node_or_null(marker_path) as Marker2D
	if marker == null:
		push_error("%s is missing teleport marker %s." % [name, marker_path])
		return
	if player.has_method("teleport_within_current_map"):
		player.call("teleport_within_current_map", marker.global_position, facing)
	else:
		player.global_position = marker.global_position


func _show_stat_prompt(fee: int) -> String:
	_ensure_choice_panel(fee)
	choice_root.show()
	return await stat_selected


func _ensure_choice_panel(fee: int) -> void:
	if choice_root != null and is_instance_valid(choice_root):
		return
	choice_layer = CanvasLayer.new()
	choice_layer.name = "EvTrainingChoiceLayer"
	choice_layer.layer = 90
	add_child(choice_layer)
	choice_root = Control.new()
	choice_root.name = "EvTrainingChoiceRoot"
	choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_root.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_root.hide()
	choice_layer.add_child(choice_root)

	var backdrop := ColorRect.new()
	backdrop.name = "EvTrainingChoiceBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#01050a8c")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "EvTrainingChoicePanel"
	panel.custom_minimum_size = Vector2(410, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -205.0
	panel.offset_top = -157.0
	panel.offset_right = 205.0
	panel.offset_bottom = 157.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	choice_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	var title := Label.new()
	title.text = LocalizationManager.text("ui.ev_training.assistant.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", UI_GOLD_BRIGHT)
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color("#02070db8"))
	layout.add_child(title)
	var accent_line := ColorRect.new()
	accent_line.name = "EvTrainingAccentLine"
	accent_line.custom_minimum_size = Vector2(0, 2)
	accent_line.color = UI_GOLD
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(accent_line)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 10)
	layout.add_child(prompt_row)
	var prompt := Label.new()
	prompt.text = LocalizationManager.text("ui.ev_training.assistant.stat_prompt")
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", UI_TEXT)
	prompt_row.add_child(prompt)
	var fee_badge := PanelContainer.new()
	fee_badge.name = "EvTrainingFeeBadge"
	fee_badge.add_theme_stylebox_override("panel", _fee_badge_style())
	prompt_row.add_child(fee_badge)
	var fee_label := Label.new()
	fee_label.text = LocalizationManager.text("ui.ev_training.assistant.session_fee", {"fee": fee})
	fee_label.add_theme_font_size_override("font_size", 10)
	fee_label.add_theme_color_override("font_color", UI_GOLD_BRIGHT)
	fee_badge.add_child(fee_label)
	var grid_panel := PanelContainer.new()
	grid_panel.name = "EvTrainingStatGridPanel"
	grid_panel.add_theme_stylebox_override(
		"panel",
		_surface_style(UI_SURFACE_INSET, UI_BORDER_SOFT, 10, 1)
	)
	layout.add_child(grid_panel)
	var grid_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		grid_margin.add_theme_constant_override("margin_%s" % side, 7)
	grid_panel.add_child(grid_margin)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid_margin.add_child(grid)
	for stat: Dictionary in STATS:
		grid.add_child(_choice_button(str(stat.label), str(stat.id)))
	var cancel := _choice_button(LocalizationManager.text("common.cancel"), "")
	cancel.name = "EvTrainingCancelButton"
	layout.add_child(cancel)


func _choice_button(label: String, stat: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(174, 40)
	button.add_theme_font_size_override("font_size", 13)
	if stat.is_empty():
		_apply_cancel_button_style(button)
	else:
		_apply_stat_button_style(button, _stat_accent(stat))
	button.pressed.connect(_select_stat.bind(stat))
	return button


func _select_stat(stat: String) -> void:
	choice_root.hide()
	stat_selected.emit(stat)


func _stat_label(stat: String) -> String:
	for definition: Dictionary in STATS:
		if str(definition.id) == stat:
			return str(definition.label)
	return stat.to_upper()


func _stat_accent(stat: String) -> Color:
	for definition: Dictionary in STATS:
		if str(definition.id) == stat:
			return definition.get("accent", UI_GOLD) as Color
	return UI_GOLD


func _apply_stat_button_style(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override(
		"normal",
		_surface_style(UI_SURFACE_RAISED, _with_alpha(accent, 0.48), 8, 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_surface_style(_with_alpha(accent, 0.16), accent, 8, 1)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_surface_style(_with_alpha(accent, 0.26), UI_GOLD_BRIGHT, 8, 1)
	)
	button.add_theme_stylebox_override(
		"focus",
		_surface_style(_with_alpha(accent, 0.12), accent, 8, 1)
	)


func _apply_cancel_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", UI_TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_stylebox_override(
		"normal",
		_surface_style(Color("#07101ae0"), Color("#2a4052"), 8, 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_surface_style(Color("#101d2aec"), Color("#60788b"), 8, 1)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_surface_style(Color("#040a11f2"), UI_BORDER, 8, 1)
	)
	button.add_theme_stylebox_override(
		"focus",
		_surface_style(Color("#101d2aec"), UI_BORDER, 8, 1)
	)


func _panel_style() -> StyleBoxFlat:
	var style := _surface_style(UI_SURFACE, UI_BORDER, 14, 1)
	style.shadow_color = Color("#000000a8")
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 7)
	return style


func _fee_badge_style() -> StyleBoxFlat:
	var style := _surface_style(Color("#312814a8"), Color("#9d8145"), 7, 1)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _surface_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
