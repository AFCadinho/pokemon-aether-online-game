extends Control
class_name Ai5ResearchMarker

const MAX_NOTE_LENGTH := 2000
const CATEGORIES: Array[String] = [
	"UNNECESSARY_SWITCH",
	"INEFFECTIVE_MOVE",
	"SETUP_IGNORED",
	"HAZARDS_OR_SUSTAIN",
	"THREW_WIN_CONDITION",
	"UNCLEAR_OTHER",
]

var battle_id := ""
var turn_provider := Callable()
var marker_submitter := Callable()
var translator := Callable()
var marked_turn := 0
var submitting := false
var mark_button: Button
var feedback_label: Label
var modal: Control
var turn_label: Label
var category_select: OptionButton
var note_input: TextEdit
var save_button: Button
var modal_status: Label


static func has_research_context(api_response: Dictionary) -> bool:
	var context_value: Variant = api_response.get("ai5Playtest", {})
	if not (context_value is Dictionary):
		return false
	var context: Dictionary = context_value as Dictionary
	return (
		str(api_response.get("battleId", "")).strip_edges() != ""
		and str(context.get("campaignId", "")).strip_edges() != ""
		and str(context.get("policyRevision", "")).strip_edges() != ""
		and str(context.get("phase", "")).strip_edges() in ["pilot", "campaign"]
		and int(context.get("assignmentIndex", -1)) >= 0
	)


func configure(api_response: Dictionary, current_turn_provider: Callable, submitter: Callable, translate: Callable) -> bool:
	if not has_research_context(api_response) or not current_turn_provider.is_valid() or not submitter.is_valid() or not translate.is_valid():
		return false
	battle_id = str(api_response.get("battleId", "")).strip_edges()
	turn_provider = current_turn_provider
	marker_submitter = submitter
	translator = translate
	_build_interface()
	return true


func close_for_battle_end() -> void:
	visible = false
	if modal != null:
		modal.visible = false


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200

	mark_button = Button.new()
	mark_button.text = _t("battle.ai5_research.mark")
	mark_button.tooltip_text = _t("battle.ai5_research.mark_tooltip")
	mark_button.focus_mode = Control.FOCUS_NONE
	mark_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(mark_button, false)
	mark_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_button.offset_left = 10.0
	mark_button.offset_top = 48.0
	mark_button.offset_right = 190.0
	mark_button.offset_bottom = 84.0
	mark_button.pressed.connect(_open_marker)
	add_child(mark_button)

	feedback_label = Label.new()
	feedback_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	feedback_label.offset_left = 12.0
	feedback_label.offset_top = 86.0
	feedback_label.offset_right = 280.0
	feedback_label.offset_bottom = 110.0
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color("#9be7b1"))
	add_child(feedback_label)

	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.visible = false
	add_child(modal)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 350.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#071426")
	panel_style.border_color = Color("#3296e8")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = _t("battle.ai5_research.title")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#6fdcff"))
	layout.add_child(title)
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(turn_label)

	category_select = OptionButton.new()
	category_select.custom_minimum_size = Vector2(0.0, 40.0)
	_apply_input_style(category_select)
	for category: String in CATEGORIES:
		category_select.add_item(_t("ui.pvp.training.ai5_playtest.flag.%s" % category.to_lower()))
		category_select.set_item_metadata(category_select.item_count - 1, category)
	layout.add_child(category_select)

	note_input = TextEdit.new()
	note_input.placeholder_text = _t("battle.ai5_research.note_placeholder")
	note_input.custom_minimum_size = Vector2(0.0, 130.0)
	note_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_apply_input_style(note_input)
	note_input.text_changed.connect(_limit_note_length)
	layout.add_child(note_input)

	modal_status = Label.new()
	modal_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_status.add_theme_color_override("font_color", Color("#ff9b9b"))
	layout.add_child(modal_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	var cancel_button := Button.new()
	cancel_button.text = _t("battle.ai5_research.cancel")
	cancel_button.custom_minimum_size = Vector2(110.0, 38.0)
	_apply_button_style(cancel_button, false)
	cancel_button.pressed.connect(_close_marker)
	actions.add_child(cancel_button)
	save_button = Button.new()
	save_button.text = _t("battle.ai5_research.save")
	save_button.custom_minimum_size = Vector2(150.0, 38.0)
	_apply_button_style(save_button, true)
	save_button.pressed.connect(_save_marker)
	actions.add_child(save_button)


func _open_marker() -> void:
	if submitting or not turn_provider.is_valid():
		return
	marked_turn = maxi(0, int(turn_provider.call()))
	if marked_turn < 1:
		feedback_label.text = _t("battle.ai5_research.turn_unavailable")
		return
	turn_label.text = _t("battle.ai5_research.turn", {"turn": marked_turn})
	modal_status.text = ""
	modal.visible = true
	note_input.grab_focus()


func _close_marker() -> void:
	if not submitting:
		modal.visible = false


func _save_marker() -> void:
	if submitting or marked_turn < 1 or category_select.selected < 0:
		return
	submitting = true
	save_button.disabled = true
	modal_status.text = _t("battle.ai5_research.saving")
	var response: Dictionary = await marker_submitter.call(
		marked_turn, str(category_select.get_selected_metadata()), note_input.text
	)
	submitting = false
	save_button.disabled = false
	if not bool(response.get("success", false)):
		modal_status.text = _t("battle.ai5_research.save_failed")
		return
	modal.visible = false
	note_input.text = ""
	feedback_label.text = _t("battle.ai5_research.saved", {"turn": marked_turn})


func _limit_note_length() -> void:
	if note_input.text.length() <= MAX_NOTE_LENGTH:
		return
	note_input.text = note_input.text.left(MAX_NOTE_LENGTH)
	note_input.set_caret_line(note_input.get_line_count() - 1)
	note_input.set_caret_column(note_input.get_line(note_input.get_line_count() - 1).length())


func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_color := Color("#1979b8") if primary else Color("#081a31")
	var hover_color := Color("#249bdc") if primary else Color("#10345c")
	var pressed_color := Color("#126496") if primary else Color("#061224")
	button.add_theme_stylebox_override("normal", _style_box(normal_color, Color("#42b9ef"), 1))
	button.add_theme_stylebox_override("hover", _style_box(hover_color, Color("#6fdcff"), 2))
	button.add_theme_stylebox_override("pressed", _style_box(pressed_color, Color("#9cecff"), 2))
	button.add_theme_stylebox_override("disabled", _style_box(Color("#101b29"), Color("#30465b"), 1))
	button.add_theme_color_override("font_color", Color("#edfaff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#718091"))


func _apply_input_style(control: Control) -> void:
	control.add_theme_stylebox_override("normal", _style_box(Color("#050d1a"), Color("#285b82"), 1))
	control.add_theme_stylebox_override("focus", _style_box(Color("#071426"), Color("#53c8f3"), 2))
	control.add_theme_stylebox_override("hover", _style_box(Color("#0a1d34"), Color("#3d91c5"), 1))
	control.add_theme_color_override("font_color", Color("#e8f5ff"))
	control.add_theme_color_override("font_placeholder_color", Color("#7f95a8"))


func _style_box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _t(key: String, replacements: Dictionary = {}) -> String:
	return str(translator.call(key, replacements)) if translator.is_valid() else key
