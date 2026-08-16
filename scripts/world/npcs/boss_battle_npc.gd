@tool
extends DialogueNPC

class_name BossBattleNPC

signal difficulty_selected(difficulty: String)

@export var easy_trainer_id := ""
@export var normal_trainer_id := ""
@export var hard_trainer_id := ""
@export var difficulty_prompt := "Choose your challenge."
@export var easy_label := "Easy"
@export var normal_label := "Normal"
@export var hard_label := "Hard"

var difficulty_layer: CanvasLayer
var difficulty_root: Control
var difficulty_panel: PanelContainer


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue()

	var difficulty := await _show_difficulty_prompt()
	if difficulty.is_empty():
		return

	var trainer_id := _get_trainer_id_for_difficulty(difficulty)
	if trainer_id.is_empty():
		push_warning("BossBattleNPC: missing trainer id for difficulty %s." % difficulty)
		await _show_report_to_staff_message()
		return

	var metadata_response: Dictionary = await TrainerMetadataService.get_trainer_metadata(trainer_id)
	if not metadata_response.get("success", false):
		push_warning("BossBattleNPC: trainer metadata failed for %s: %s" % [
			trainer_id,
			str(metadata_response.get("error", "Unknown API error")),
		])
		await _show_report_to_staff_message()
		return

	var trainer_metadata: Dictionary = metadata_response.get("metadata", {})
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("start_trainer_battle"):
		push_warning("BossBattleNPC: World cannot start boss battle.")
		await _show_report_to_staff_message()
		return

	var battle_metadata := build_battle_trainer_metadata(trainer_metadata)
	battle_metadata["battleTransitionStyle"] = WildEncounterTransition.STYLE_SPECIAL_TRAINER
	var battle_result: Dictionary = await world.start_trainer_battle(battle_metadata)
	if not bool(battle_result.get("success", false)):
		await GameErrorDialogService.show_response(
			battle_result,
			"backend.error.trainer_battle_start"
		)


func _show_difficulty_prompt() -> String:
	_ensure_difficulty_panel()
	if difficulty_root != null and is_instance_valid(difficulty_root):
		difficulty_root.show()
	difficulty_panel.show()
	return await difficulty_selected


func _ensure_difficulty_panel() -> void:
	if difficulty_panel != null and is_instance_valid(difficulty_panel):
		return

	difficulty_layer = CanvasLayer.new()
	difficulty_layer.name = "BossDifficultyLayer"
	difficulty_layer.layer = 90
	add_child(difficulty_layer)

	var screen_root := Control.new()
	screen_root.name = "BossDifficultyRoot"
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.visible = false
	difficulty_root = screen_root
	difficulty_layer.add_child(screen_root)

	difficulty_panel = PanelContainer.new()
	difficulty_panel.name = "BossDifficultyPanel"
	difficulty_panel.visible = false
	difficulty_panel.custom_minimum_size = Vector2(320, 0)
	difficulty_panel.anchor_left = 0.5
	difficulty_panel.anchor_top = 0.5
	difficulty_panel.anchor_right = 0.5
	difficulty_panel.anchor_bottom = 0.5
	difficulty_panel.offset_left = -160.0
	difficulty_panel.offset_top = -138.0
	difficulty_panel.offset_right = 160.0
	difficulty_panel.offset_bottom = 138.0
	difficulty_panel.add_theme_stylebox_override("panel", _make_difficulty_panel_style())
	screen_root.add_child(difficulty_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	difficulty_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title_label := Label.new()
	title_label.text = display_name if not display_name.strip_edges().is_empty() else name
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.847, 0.718, 0.404, 1.0))
	title_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(title_label)

	var prompt_label := Label.new()
	prompt_label.text = difficulty_prompt
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_color_override("font_color", Color(0.957, 0.941, 0.871, 1.0))
	prompt_label.add_theme_font_size_override("font_size", 15)
	layout.add_child(prompt_label)

	var choice_list := VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 8)
	layout.add_child(choice_list)

	choice_list.add_child(_make_difficulty_button(hard_label, "hard", Color(0.95, 0.27, 0.25, 1.0)))
	choice_list.add_child(_make_difficulty_button(normal_label, "normal", Color(0.95, 0.72, 0.25, 1.0)))
	choice_list.add_child(_make_difficulty_button(easy_label, "easy", Color(0.34, 0.82, 0.48, 1.0)))

	var cancel_button := _make_cancel_button()
	layout.add_child(cancel_button)


func _make_difficulty_button(label: String, difficulty: String, accent_color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.957, 0.941, 0.871, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88, 1.0))
	button.add_theme_stylebox_override("normal", _make_difficulty_button_style(Color(0.051, 0.086, 0.145, 0.92), accent_color))
	button.add_theme_stylebox_override("hover", _make_difficulty_button_style(Color(0.086, 0.145, 0.235, 0.98), accent_color))
	button.add_theme_stylebox_override("pressed", _make_difficulty_button_style(Color(0.027, 0.043, 0.075, 0.98), accent_color))
	button.pressed.connect(_select_difficulty.bind(difficulty))
	return button


func _make_cancel_button() -> Button:
	var button := Button.new()
	button.text = LocalizationManager.text("common.cancel")
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.957, 0.941, 0.871, 1.0))
	button.add_theme_stylebox_override("normal", _make_difficulty_button_style(Color(0.023, 0.036, 0.061, 0.74), Color(0.192, 0.314, 0.439, 0.78)))
	button.add_theme_stylebox_override("hover", _make_difficulty_button_style(Color(0.051, 0.086, 0.145, 0.92), Color(0.847, 0.718, 0.404, 0.9)))
	button.add_theme_stylebox_override("pressed", _make_difficulty_button_style(Color(0.016, 0.025, 0.043, 0.96), Color(0.847, 0.718, 0.404, 0.9)))
	button.pressed.connect(_select_difficulty.bind(""))
	return button


func _select_difficulty(difficulty: String) -> void:
	if difficulty_root != null and is_instance_valid(difficulty_root):
		difficulty_root.hide()
	if difficulty_panel != null and is_instance_valid(difficulty_panel):
		difficulty_panel.hide()
	difficulty_selected.emit(difficulty)


func _make_difficulty_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.043, 0.075, 0.957)
	style.border_color = Color(0.847, 0.718, 0.404, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_difficulty_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _get_trainer_id_for_difficulty(difficulty: String) -> String:
	if difficulty == "easy":
		return easy_trainer_id.strip_edges()
	if difficulty == "normal":
		return normal_trainer_id.strip_edges()
	if difficulty == "hard":
		return hard_trainer_id.strip_edges()
	return ""


func _show_report_to_staff_message() -> void:
	var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
	if error_dialog_service != null and error_dialog_service.has_method("show_report_to_staff_message"):
		await error_dialog_service.call("show_report_to_staff_message")
		return

	await show_dialogue([LocalizationManager.text("npc.error.boss_battle")])
