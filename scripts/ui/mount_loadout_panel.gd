extends Control

class_name MountLoadoutPanel

const MountServiceScript := preload("res://scripts/services/mount_service.gd")

const PANEL_BACKGROUND := Color("#050b14ed")
const PANEL_BORDER := Color("#2d4b66b3")
const SLOT_BACKGROUND := Color("#081522eb")
const SLOT_HOVER_BACKGROUND := Color("#112a44f2")
const SLOT_SELECTED_BACKGROUND := Color("#0b2940f2")
const SLOT_SELECTED_BORDER := Color("#58c8ebcc")
const TEXT_COLOR := Color("#f4f0de")
const MUTED_TEXT_COLOR := Color("#aeb8c5")

var slots_panel: PanelContainer
var title_label: Label
var slot_buttons: Dictionary = {}
var selector_panel: PanelContainer
var selector_title_label: Label
var selector_options: VBoxContainer
var selector_empty_label: Label
var selector_close_button: Button
var active_mode := ""
var settings_manager: Node
var localization_manager: Node


func _ready() -> void:
	_build_interface()
	settings_manager = get_node_or_null("/root/SettingsManager")
	localization_manager = get_node_or_null("/root/LocalizationManager")
	var loadout_callable := Callable(self, "_on_mount_loadout_changed")
	if (
		settings_manager != null
		and not settings_manager.is_connected("mount_loadout_changed", loadout_callable)
	):
		settings_manager.connect("mount_loadout_changed", loadout_callable)
	var locale_callable := Callable(self, "_on_locale_changed")
	if (
		localization_manager != null
		and not localization_manager.is_connected("locale_changed", locale_callable)
	):
		localization_manager.connect("locale_changed", locale_callable)
	_refresh_localized_content()
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if selector_panel != null and selector_panel.visible:
			_close_selector()
		else:
			close_manager()
		get_viewport().set_input_as_handled()


func toggle_manager() -> void:
	if visible:
		close_manager()
	else:
		open_manager()


func open_manager() -> void:
	_close_selector()
	_refresh_slots()
	visible = true


func close_manager() -> void:
	_close_selector()
	visible = false


func is_manager_open() -> bool:
	return visible


func _build_interface() -> void:
	slots_panel = PanelContainer.new()
	slots_panel.name = "SlotsPanel"
	slots_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	slots_panel.offset_bottom = 100.0
	slots_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slots_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(PANEL_BACKGROUND, PANEL_BORDER, 10, 1)
	)
	add_child(slots_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	slots_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	title_label.add_theme_font_size_override("font_size", 11)
	content.add_child(title_label)

	var slot_row := HBoxContainer.new()
	slot_row.name = "SlotRow"
	slot_row.add_theme_constant_override("separation", 6)
	content.add_child(slot_row)

	for movement_mode: String in MountServiceScript.AVAILABLE_MOVEMENT_MODES:
		var button := Button.new()
		button.name = "%sMountButton" % movement_mode.capitalize()
		button.custom_minimum_size = Vector2(95, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 42)
		button.expand_icon = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", TEXT_COLOR)
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override(
			"normal",
			_make_panel_style(SLOT_BACKGROUND, PANEL_BORDER, 8, 1)
		)
		button.add_theme_stylebox_override(
			"hover",
			_make_panel_style(SLOT_HOVER_BACKGROUND, SLOT_SELECTED_BORDER, 8, 1)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_panel_style(SLOT_SELECTED_BACKGROUND, SLOT_SELECTED_BORDER, 8, 1)
		)
		button.add_theme_stylebox_override(
			"focus",
			StyleBoxEmpty.new()
		)
		button.pressed.connect(_open_selector.bind(movement_mode))
		slot_row.add_child(button)
		slot_buttons[movement_mode] = button

	selector_panel = PanelContainer.new()
	selector_panel.name = "SelectorPanel"
	selector_panel.visible = false
	selector_panel.position = Vector2(0, 106)
	selector_panel.custom_minimum_size = Vector2(228, 0)
	selector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	selector_panel.z_index = 5
	selector_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(PANEL_BACKGROUND, SLOT_SELECTED_BORDER, 10, 1)
	)
	add_child(selector_panel)

	var selector_margin := MarginContainer.new()
	selector_margin.add_theme_constant_override("margin_left", 10)
	selector_margin.add_theme_constant_override("margin_top", 8)
	selector_margin.add_theme_constant_override("margin_right", 10)
	selector_margin.add_theme_constant_override("margin_bottom", 10)
	selector_panel.add_child(selector_margin)

	var selector_content := VBoxContainer.new()
	selector_content.add_theme_constant_override("separation", 7)
	selector_margin.add_child(selector_content)

	var selector_header := HBoxContainer.new()
	selector_header.add_theme_constant_override("separation", 6)
	selector_content.add_child(selector_header)

	selector_title_label = Label.new()
	selector_title_label.name = "SelectorTitleLabel"
	selector_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_title_label.add_theme_color_override("font_color", TEXT_COLOR)
	selector_title_label.add_theme_font_size_override("font_size", 13)
	selector_header.add_child(selector_title_label)

	selector_close_button = Button.new()
	selector_close_button.name = "CloseButton"
	selector_close_button.custom_minimum_size = Vector2(28, 28)
	selector_close_button.text = "×"
	selector_close_button.focus_mode = Control.FOCUS_NONE
	selector_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selector_close_button.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	selector_close_button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	selector_close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	selector_close_button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(SLOT_HOVER_BACKGROUND, PANEL_BORDER, 6, 1)
	)
	selector_close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	selector_close_button.pressed.connect(_close_selector)
	selector_header.add_child(selector_close_button)

	selector_options = VBoxContainer.new()
	selector_options.name = "Options"
	selector_options.add_theme_constant_override("separation", 5)
	selector_content.add_child(selector_options)

	selector_empty_label = Label.new()
	selector_empty_label.name = "EmptyLabel"
	selector_empty_label.custom_minimum_size = Vector2(0, 44)
	selector_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selector_empty_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	selector_empty_label.add_theme_font_size_override("font_size", 11)
	selector_content.add_child(selector_empty_label)


func _refresh_localized_content() -> void:
	if title_label == null:
		return
	title_label.text = _text("ui.mounts.title").to_upper()
	selector_empty_label.text = _text("ui.mounts.none_available")
	selector_close_button.tooltip_text = _text("common.close")
	_refresh_slots()
	if selector_panel.visible and active_mode != "":
		_populate_selector(active_mode)


func _refresh_slots() -> void:
	for movement_mode: String in MountServiceScript.AVAILABLE_MOVEMENT_MODES:
		var button := slot_buttons.get(movement_mode) as Button
		if button == null:
			continue
		var mount_id := _get_selected_mount_id(movement_mode)
		var mount_name := MountServiceScript.get_mount_display_name(mount_id) \
			if mount_id != "" else _text("ui.mounts.none_selected")
		button.text = "%s\n%s" % [_mode_label(movement_mode), mount_name]
		button.icon = MountServiceScript.get_mount_icon_texture(mount_id)
		button.tooltip_text = _text(
			"ui.mounts.%s_tooltip" % movement_mode
		)


func _open_selector(movement_mode: String) -> void:
	active_mode = movement_mode
	_populate_selector(active_mode)
	selector_panel.visible = true


func _populate_selector(movement_mode: String) -> void:
	selector_title_label.text = _text(
		"ui.mounts.choose",
		{"type": _mode_label(movement_mode)}
	)
	for child: Node in selector_options.get_children():
		selector_options.remove_child(child)
		child.queue_free()

	var mount_ids := MountServiceScript.get_mount_ids_for_mode(movement_mode)
	selector_empty_label.visible = mount_ids.is_empty()
	var selected_mount_id := _get_selected_mount_id(movement_mode)
	for mount_id: String in mount_ids:
		var option := Button.new()
		option.name = "%sOption" % mount_id.to_pascal_case()
		option.custom_minimum_size = Vector2(0, 50)
		option.focus_mode = Control.FOCUS_NONE
		option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.add_theme_constant_override("icon_max_width", 42)
		option.expand_icon = true
		option.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		option.icon = MountServiceScript.get_mount_icon_texture(mount_id)
		option.text = "%s  %s" % [
			"✓" if mount_id == selected_mount_id else "",
			MountServiceScript.get_mount_display_name(mount_id),
		]
		option.add_theme_color_override("font_color", TEXT_COLOR)
		option.add_theme_color_override("font_hover_color", TEXT_COLOR)
		option.add_theme_stylebox_override(
			"normal",
			_make_panel_style(
				SLOT_SELECTED_BACKGROUND if mount_id == selected_mount_id else SLOT_BACKGROUND,
				SLOT_SELECTED_BORDER if mount_id == selected_mount_id else PANEL_BORDER,
				8,
				1
			)
		)
		option.add_theme_stylebox_override(
			"hover",
			_make_panel_style(SLOT_HOVER_BACKGROUND, SLOT_SELECTED_BORDER, 8, 1)
		)
		option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		option.pressed.connect(_select_mount.bind(movement_mode, mount_id))
		selector_options.add_child(option)


func _select_mount(movement_mode: String, mount_id: String) -> void:
	if settings_manager != null and bool(
		settings_manager.call("set_selected_mount_id", movement_mode, mount_id)
	):
		_close_selector()


func _close_selector() -> void:
	active_mode = ""
	selector_panel.visible = false


func _on_mount_loadout_changed(_movement_mode: String, _mount_id: String) -> void:
	_refresh_slots()


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_content()


func _mode_label(movement_mode: String) -> String:
	return _text("ui.mounts.%s" % movement_mode)


func _get_selected_mount_id(movement_mode: String) -> String:
	if settings_manager == null:
		return MountServiceScript.get_default_mount_id(movement_mode)
	return str(settings_manager.call("get_selected_mount_id", movement_mode))


func _text(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager == null:
		return key
	return str(localization_manager.call("text", key, replacements))


func _make_panel_style(
	background_color: Color,
	border_color: Color,
	corner_radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
