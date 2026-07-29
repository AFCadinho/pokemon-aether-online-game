extends PanelContainer

class_name DevBadgeProgressPopup

signal closed

const POPUP_SIZE := Vector2(720, 540)
const REGION := "kanto"
const BADGES: Array[Dictionary] = [
	{"id": "boulder", "name": "Boulder", "texture": "res://assets/gym_badges/kanto_badges/Boulder_Badge.png"},
	{"id": "cascade", "name": "Cascade", "texture": "res://assets/gym_badges/kanto_badges/Cascade_Badge.png"},
	{"id": "thunder", "name": "Thunder", "texture": "res://assets/gym_badges/kanto_badges/Thunder_Badge.png"},
	{"id": "rainbow", "name": "Rainbow", "texture": "res://assets/gym_badges/kanto_badges/Rainbow_Badge.png"},
	{"id": "soul", "name": "Soul", "texture": "res://assets/gym_badges/kanto_badges/Soul_Badge.png"},
	{"id": "marsh", "name": "Marsh", "texture": "res://assets/gym_badges/kanto_badges/Marsh_Badge.png"},
	{"id": "volcano", "name": "Volcano", "texture": "res://assets/gym_badges/kanto_badges/Volcano_Badge.png"},
	{"id": "earth", "name": "Earth", "texture": "res://assets/gym_badges/kanto_badges/Earth_Badge.png"},
]

const UI_BG := Color("#050b14fa")
const UI_SURFACE := Color("#0a1726f5")
const UI_SURFACE_HOVER := Color("#102944fa")
const UI_BORDER := Color("#526b8c")
const UI_ACCENT := Color("#e3bd68")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED := Color("#aeb8c5")
const UI_SUCCESS := Color("#79e49b")
const UI_ERROR := Color("#ff8393")

var status_label: Label
var badge_buttons: Dictionary = {}
var badge_icon_rects: Dictionary = {}
var badge_status_labels: Dictionary = {}
var badge_state: Dictionary = {}
var busy := false
var dragging := false


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#8d7440"), 14, 1))
	_build_ui()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open() -> void:
	visible = true
	_center_in_viewport()
	_set_status(_t("ui.staff.badges.loading"), false)
	_set_busy(true)
	var service := get_node_or_null("/root/BadgeProgressionService")
	if service == null or not service.has_method("load_gym_badges"):
		_set_busy(false)
		_set_status(_t("ui.staff.badges.unavailable"), true)
		return
	var result: Dictionary = await service.call("load_gym_badges")
	_set_busy(false)
	if not visible:
		return
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.staff.badges.load_failed"))), true)
		return
	set_badge_state(result)


func close() -> void:
	var was_visible := visible
	dragging = false
	visible = false
	if was_visible:
		closed.emit()


func set_badge_state(state: Dictionary) -> void:
	badge_state.clear()
	var values: Variant = state.get("badges", [])
	if values is Array:
		for value: Variant in values:
			if not (value is Dictionary):
				continue
			var badge: Dictionary = value as Dictionary
			if str(badge.get("region", "")).to_lower() != REGION:
				continue
			badge_state[str(badge.get("badgeId", badge.get("id", ""))).to_lower()] = bool(badge.get("earned", false))
	_render_badges()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 15, 18, 17)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	layout.add_child(header)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	heading.add_child(_localized_label("ui.staff.dev.trainer_progress", 20, UI_TEXT))
	heading.add_child(_localized_label("ui.staff.badges.subtitle", 11, UI_MUTED))

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	_apply_button_style(close_button, false)
	header.add_child(close_button)

	var notice := PanelContainer.new()
	notice.add_theme_stylebox_override("panel", _panel_style(Color("#112033e8"), Color("#486888aa"), 9, 1))
	layout.add_child(notice)
	var notice_margin := MarginContainer.new()
	_set_margins(notice_margin, 12, 9, 12, 9)
	notice.add_child(notice_margin)
	var notice_label := _localized_label(
		"ui.staff.badges.notice",
		11,
		UI_MUTED
	)
	notice_margin.add_child(notice_label)

	var grid := GridContainer.new()
	grid.name = "BadgeGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	layout.add_child(grid)

	for definition: Dictionary in BADGES:
		var button := Button.new()
		var badge_id := str(definition.get("id", ""))
		button.name = "%sBadgeButton" % badge_id.capitalize().replace(" ", "")
		button.custom_minimum_size = Vector2(158, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var tile_margin := MarginContainer.new()
		tile_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_margins(tile_margin, 8, 7, 8, 7)
		button.add_child(tile_margin)
		var tile_layout := VBoxContainer.new()
		tile_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_layout.add_theme_constant_override("separation", 2)
		tile_margin.add_child(tile_layout)
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile_layout.add_child(icon_center)
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(54, 54)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_path := str(definition.get("texture", ""))
		if ResourceLoader.exists(texture_path):
			icon_rect.texture = load(texture_path) as Texture2D
		icon_center.add_child(icon_rect)
		var name_label := _label(str(definition.get("name", "Badge")), 12, UI_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(name_label)
		var state_label := _localized_label("ui.staff.badges.locked", 9, UI_MUTED)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(state_label)
		button.pressed.connect(_toggle_badge.bind(badge_id))
		_apply_button_style(button, false)
		grid.add_child(button)
		badge_buttons[badge_id] = button
		badge_icon_rects[badge_id] = icon_rect
		badge_status_labels[badge_id] = state_label

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	layout.add_child(footer)

	var first_three_button := Button.new()
	first_three_button.name = "GrantFirstThreeButton"
	_set_localized_property(first_three_button, "text", "ui.staff.badges.grant_first_three")
	first_three_button.pressed.connect(_set_first_three)
	_apply_button_style(first_three_button, true)
	footer.add_child(first_three_button)

	var all_button := Button.new()
	all_button.name = "GrantAllButton"
	_set_localized_property(all_button, "text", "ui.staff.badges.grant_all")
	all_button.pressed.connect(_set_all.bind(true))
	_apply_button_style(all_button, true)
	footer.add_child(all_button)

	var clear_button := Button.new()
	clear_button.name = "ClearAllButton"
	_set_localized_property(clear_button, "text", "ui.staff.badges.clear_all")
	clear_button.pressed.connect(_set_all.bind(false))
	_apply_button_style(clear_button, false)
	footer.add_child(clear_button)

	status_label = _label("", 11, UI_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(status_label)
	_render_badges()


func _toggle_badge(badge_id: String) -> void:
	if busy:
		return
	await _submit_badges([badge_id], not bool(badge_state.get(badge_id, false)))


func _set_first_three() -> void:
	if busy:
		return
	var badge_ids: Array[String] = ["boulder", "cascade", "thunder"]
	await _submit_badges(badge_ids, true)


func _set_all(earned: bool) -> void:
	if busy:
		return
	var badge_ids: Array[String] = []
	for definition: Dictionary in BADGES:
		badge_ids.append(str(definition.get("id", "")))
	await _submit_badges(badge_ids, earned)


func _submit_badges(badge_ids: Array[String], earned: bool) -> void:
	_set_busy(true)
	_set_status(_t("ui.staff.badges.saving"), false)
	var service := get_node_or_null("/root/BadgeProgressionService")
	if service == null or not service.has_method("dev_set_gym_badges"):
		_set_busy(false)
		_set_status(_t("ui.staff.badges.unavailable"), true)
		return
	var result: Dictionary = await service.call("dev_set_gym_badges", REGION, badge_ids, earned)
	_set_busy(false)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.staff.badges.update_failed"))), true)
		return
	set_badge_state(result)


func _render_badges() -> void:
	var earned_count := 0
	for definition: Dictionary in BADGES:
		var badge_id := str(definition.get("id", ""))
		var earned := bool(badge_state.get(badge_id, false))
		if earned:
			earned_count += 1
		var button := badge_buttons.get(badge_id) as Button
		if button == null:
			continue
		button.tooltip_text = "%s · %s" % [
			str(definition.get("name", "Badge")),
			(
				_t("ui.staff.badges.earned")
				if earned
				else _t("ui.staff.badges.locked")
			).capitalize(),
		]
		var icon_rect := badge_icon_rects.get(badge_id) as TextureRect
		if icon_rect != null:
			icon_rect.modulate = Color.WHITE if earned else Color("#6370809a")
		var state_label := badge_status_labels.get(badge_id) as Label
		if state_label != null:
			state_label.text = (
				_t("ui.staff.badges.earned")
				if earned
				else _t("ui.staff.badges.locked")
			)
			state_label.add_theme_color_override("font_color", UI_SUCCESS if earned else UI_MUTED)
		var style := _panel_style(
			Color("#112b27f2") if earned else UI_SURFACE,
			UI_SUCCESS if earned else UI_BORDER,
			9,
			1
		)
		button.add_theme_stylebox_override("normal", style)
	if not busy:
		_set_status(_t("ui.staff.badges.progress", {
			"earned": earned_count,
			"total": BADGES.size(),
		}), false)


func _set_busy(value: bool) -> void:
	busy = value
	for value_button: Variant in badge_buttons.values():
		var button := value_button as Button
		if button != null:
			button.disabled = value
	var named_buttons := find_children("*Button", "Button", true, false)
	for button_node: Node in named_buttons:
		var button := button_node as Button
		if button != null and button.name != "CloseButton":
			button.disabled = value


func _set_status(message: String, is_error: bool) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_MUTED)


func _t(key: String, replacements: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key
	return str(localization_manager.call("text", key, replacements))


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _localized_label(key: String, font_size: int, color: Color) -> Label:
	var label := _label("", font_size, color)
	_set_localized_property(label, "text", key)
	return label


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_render_badges()


func _on_header_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		dragging = mouse_button.pressed
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and dragging:
		position += mouse_motion.relative
		_clamp_to_viewport()


func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = (viewport_size - POPUP_SIZE) * 0.5
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 8.0, maxf(viewport_size.x - size.x - 8.0, 8.0))
	position.y = clampf(position.y, 8.0, maxf(viewport_size.y - size.y - 8.0, 8.0))


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_button_style(button: Button, primary: bool) -> void:
	var background := Color("#253e29") if primary else UI_SURFACE
	var border := UI_ACCENT if primary else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_SURFACE_HOVER, UI_ACCENT, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#172d41"), UI_ACCENT, 8, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#09111c"), Color("#303b4b"), 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#687382"))


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)
