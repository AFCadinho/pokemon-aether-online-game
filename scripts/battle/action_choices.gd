extends PanelContainer

signal action_selected(action: String)

const ACTION_ACTIVE_BG := Color("#101b2cf2")
const ACTION_ACTIVE_BG_HOVER := Color("#142238f6")
const ACTION_ACTIVE_BORDER := Color("#b99a52")
const ACTION_ACTIVE_BORDER_SOFT := Color("#5b83a8")
const ACTION_ACTIVE_TEXT := Color("#ead9a8")
const ACTION_DISABLED_MODULATE := Color(0.52, 0.52, 0.52, 0.72)

@onready var buttons: Array[Button] = [
	$GridContainer/FightButton,
	$GridContainer/PartyButton,
	$GridContainer/RunButton,
	$GridContainer/BagButton
]

var disabled_actions := {}
var all_actions_disabled := false
var selected_action := ""
var base_button_styles: Dictionary = {}

func _ready() -> void:
	_capture_base_button_styles()
	_apply_disabled_actions()

func _select_button(active_button: Button) -> void:
	selected_action = _get_action_for_button(active_button)
	_apply_disabled_actions()

func set_selected_action(action: String) -> void:
	if action == "fight":
		_select_button($GridContainer/FightButton)
	elif action == "bag":
		_select_button($GridContainer/BagButton)
	elif action == "party":
		_select_button($GridContainer/PartyButton)
	elif action == "run":
		_select_button($GridContainer/RunButton)

func set_action_disabled(action: String, is_disabled: bool) -> void:
	disabled_actions[action] = is_disabled
	_apply_disabled_actions()

func set_all_actions_disabled(is_disabled: bool) -> void:
	all_actions_disabled = is_disabled
	_apply_disabled_actions()

func _apply_disabled_actions() -> void:
	if base_button_styles.is_empty():
		_capture_base_button_styles()

	for button in buttons:
		button.disabled = false
		_apply_button_default_state(button)

	if all_actions_disabled:
		for button in buttons:
			button.disabled = true
			_apply_button_disabled_state(button)

		return

	var selected_button := _get_action_button(selected_action)
	if selected_button != null:
		_apply_button_selected_state(selected_button)

	for action in disabled_actions:
		if not bool(disabled_actions[action]):
			continue

		var button := _get_action_button(str(action))
		if button == null:
			continue

		button.disabled = true
		_apply_button_disabled_state(button)

func _capture_base_button_styles() -> void:
	base_button_styles.clear()
	for button: Button in buttons:
		var action: String = _get_action_for_button(button)
		base_button_styles[action] = {
			"normal": button.get_theme_stylebox("normal").duplicate(),
			"hover": button.get_theme_stylebox("hover").duplicate(),
			"pressed": button.get_theme_stylebox("pressed").duplicate(),
			"disabled": button.get_theme_stylebox("disabled").duplicate(),
			"focus": button.get_theme_stylebox("focus").duplicate(),
		}

func _apply_button_default_state(button: Button) -> void:
	var action: String = _get_action_for_button(button)
	var styles: Dictionary = base_button_styles.get(action, {})
	button.modulate = Color.WHITE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		if styles.has(style_name):
			var style_box: StyleBox = styles.get(style_name) as StyleBox
			if style_box != null:
				button.add_theme_stylebox_override(style_name, style_box)
	button.remove_theme_color_override("font_color")
	button.remove_theme_color_override("font_hover_color")
	button.remove_theme_color_override("font_pressed_color")

func _apply_button_selected_state(button: Button) -> void:
	button.modulate = Color.WHITE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_selected_button_style(ACTION_ACTIVE_BG, ACTION_ACTIVE_BORDER))
	button.add_theme_stylebox_override("hover", _make_selected_button_style(ACTION_ACTIVE_BG_HOVER, ACTION_ACTIVE_BORDER))
	button.add_theme_stylebox_override("pressed", _make_selected_button_style(ACTION_ACTIVE_BG_HOVER, ACTION_ACTIVE_BORDER_SOFT))
	button.add_theme_stylebox_override("focus", _make_selected_button_style(ACTION_ACTIVE_BG, ACTION_ACTIVE_BORDER_SOFT))
	button.add_theme_color_override("font_color", ACTION_ACTIVE_TEXT)
	button.add_theme_color_override("font_hover_color", ACTION_ACTIVE_TEXT)
	button.add_theme_color_override("font_pressed_color", ACTION_ACTIVE_TEXT)

func _apply_button_disabled_state(button: Button) -> void:
	var action: String = _get_action_for_button(button)
	var styles: Dictionary = base_button_styles.get(action, {})
	button.modulate = ACTION_DISABLED_MODULATE
	button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	if styles.has("disabled"):
		var disabled_style: StyleBox = styles.get("disabled") as StyleBox
		if disabled_style != null:
			button.add_theme_stylebox_override("disabled", disabled_style)

func _make_selected_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.10)
	style.shadow_size = 3
	style.shadow_offset = Vector2.ZERO
	return style

func _get_action_button(action: String) -> Button:
	if action == "fight":
		return $GridContainer/FightButton
	if action == "bag":
		return $GridContainer/BagButton
	if action == "party":
		return $GridContainer/PartyButton
	if action == "run":
		return $GridContainer/RunButton

	return null

func _get_action_for_button(button: Button) -> String:
	if button == $GridContainer/FightButton:
		return "fight"
	if button == $GridContainer/BagButton:
		return "bag"
	if button == $GridContainer/PartyButton:
		return "party"
	if button == $GridContainer/RunButton:
		return "run"

	return ""

func _on_fight_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("fight", false)):
		return

	set_selected_action("fight")
	action_selected.emit("fight")


func _on_bag_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("bag", false)):
		return

	set_selected_action("bag")
	action_selected.emit("bag")

func _on_party_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("party", false)):
		return

	set_selected_action("party")
	action_selected.emit("party")

func _on_run_button_pressed() -> void:
	if all_actions_disabled:
		return
	if bool(disabled_actions.get("run", false)):
		return

	set_selected_action("run")
	action_selected.emit("run")
