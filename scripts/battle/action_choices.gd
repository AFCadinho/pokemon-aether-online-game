extends PanelContainer

signal action_selected(action: String)

const ACTION_ACTIVE_BG := Color("#082955f2")
const ACTION_ACTIVE_BG_HOVER := Color("#0b3970f6")
const ACTION_ACTIVE_BORDER := Color("#62d7ff")
const ACTION_ACTIVE_BORDER_SOFT := Color("#2d7dcc")
const ACTION_ACTIVE_TEXT := Color("#e4f7ff")
const ACTION_DISABLED_MODULATE := Color(0.52, 0.52, 0.52, 0.72)
const UTILITY_BAG_ACCENT := Color("#62d7ff")
const UTILITY_EXIT_ACCENT := Color("#ff8068")
const UTILITY_EXIT_ACTIVE_BG := Color("#32100df2")
const UTILITY_EXIT_ACTIVE_BG_HOVER := Color("#48130ff6")

@onready var fight_button: Button = %FightButton
@onready var bag_button: Button = %BagButton
@onready var party_button: Button = %PartyButton
@onready var run_button: Button = %RunButton
@onready var utility_action_divider: ColorRect = %UtilityActionDivider
@onready var buttons: Array[Button] = [fight_button, party_button, run_button, bag_button]

var disabled_actions := {}
var all_actions_disabled := false
var selected_action := ""
var base_button_styles: Dictionary = {}

func _ready() -> void:
	_connect_action_buttons()
	_capture_base_button_styles()
	_apply_disabled_actions()

func _connect_action_buttons() -> void:
	var button_handlers: Dictionary = {
		fight_button: Callable(self, "_on_fight_button_pressed"),
		bag_button: Callable(self, "_on_bag_button_pressed"),
		party_button: Callable(self, "_on_party_button_pressed"),
		run_button: Callable(self, "_on_run_button_pressed"),
	}
	for button_value: Variant in button_handlers:
		var button := button_value as Button
		var handler: Callable = button_handlers.get(button_value)
		if button != null and not button.pressed.is_connected(handler):
			button.pressed.connect(handler)

func _select_button(active_button: Button) -> void:
	selected_action = _get_action_for_button(active_button)
	_apply_disabled_actions()

func set_selected_action(action: String) -> void:
	if action == "fight":
		_select_button(fight_button)
	elif action == "bag":
		_select_button(bag_button)
	elif action == "party":
		_select_button(party_button)
	elif action == "run":
		_select_button(run_button)

func set_action_label(action: String, label: String) -> void:
	var button := _get_action_button(action)
	if button != null:
		button.text = label
		button.tooltip_text = label

func set_action_visible(action: String, is_visible: bool) -> void:
	var button := _get_action_button(action)
	if button != null:
		button.visible = is_visible
	if action == "bag" and utility_action_divider != null:
		utility_action_divider.visible = is_visible

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
	button.remove_theme_color_override("font_focus_color")
	if button == bag_button:
		button.add_theme_color_override("font_hover_color", UTILITY_BAG_ACCENT)
		button.add_theme_color_override("font_pressed_color", UTILITY_BAG_ACCENT)
		button.add_theme_color_override("font_focus_color", UTILITY_BAG_ACCENT)
	elif button == run_button:
		button.add_theme_color_override("font_hover_color", UTILITY_EXIT_ACCENT)
		button.add_theme_color_override("font_pressed_color", UTILITY_EXIT_ACCENT)
		button.add_theme_color_override("font_focus_color", UTILITY_EXIT_ACCENT)

func _apply_button_selected_state(button: Button) -> void:
	button.modulate = Color.WHITE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var active_background := UTILITY_EXIT_ACTIVE_BG if button == run_button else ACTION_ACTIVE_BG
	var active_hover_background := UTILITY_EXIT_ACTIVE_BG_HOVER if button == run_button else ACTION_ACTIVE_BG_HOVER
	var active_border := UTILITY_EXIT_ACCENT if button == run_button else ACTION_ACTIVE_BORDER
	var active_border_soft := UTILITY_EXIT_ACCENT if button == run_button else ACTION_ACTIVE_BORDER_SOFT
	var active_text := UTILITY_EXIT_ACCENT if button == run_button else ACTION_ACTIVE_TEXT
	if button == bag_button or button == run_button:
		button.add_theme_stylebox_override("normal", _make_utility_selected_button_style(active_background))
		button.add_theme_stylebox_override("hover", _make_utility_selected_button_style(active_hover_background))
		button.add_theme_stylebox_override("pressed", _make_utility_selected_button_style(active_hover_background))
		button.add_theme_stylebox_override("focus", _make_utility_selected_button_style(active_background))
		button.add_theme_color_override("font_color", active_text)
		button.add_theme_color_override("font_hover_color", active_text)
		button.add_theme_color_override("font_pressed_color", active_text)
		button.add_theme_color_override("font_focus_color", active_text)
		return
	button.add_theme_stylebox_override("normal", _make_selected_button_style(active_background, active_border))
	button.add_theme_stylebox_override("hover", _make_selected_button_style(active_hover_background, active_border))
	button.add_theme_stylebox_override("pressed", _make_selected_button_style(active_hover_background, active_border_soft))
	button.add_theme_stylebox_override("focus", _make_selected_button_style(active_background, active_border_soft))
	button.add_theme_color_override("font_color", active_text)
	button.add_theme_color_override("font_hover_color", active_text)
	button.add_theme_color_override("font_pressed_color", active_text)
	button.add_theme_color_override("font_focus_color", active_text)

func _make_utility_selected_button_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	return style

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
		return fight_button
	if action == "bag":
		return bag_button
	if action == "party":
		return party_button
	if action == "run":
		return run_button

	return null

func _get_action_for_button(button: Button) -> String:
	if button == fight_button:
		return "fight"
	if button == bag_button:
		return "bag"
	if button == party_button:
		return "party"
	if button == run_button:
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
