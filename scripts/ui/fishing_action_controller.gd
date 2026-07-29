class_name FishingActionController
extends Node

const FISHING_ACTION_ICON := preload("res://assets/ui/fishing_rod.svg")
const ROD_ICONS := {
	"old-rod": preload("res://assets/items/icons/OLDROD.png"),
	"good-rod": preload("res://assets/items/icons/GOODROD.png"),
	"super-rod": preload("res://assets/items/icons/SUPERROD.png"),
}
const ROD_NAMES := {
	"old-rod": "Old Rod",
	"good-rod": "Good Rod",
	"super-rod": "Super Rod",
}
const SURFACE_BASE := Color("#050b14f7")
const SURFACE_INTERACTIVE := Color("#0b1a2bf2")
const SURFACE_HOVER := Color("#112a44fa")
const SURFACE_PRESSED := Color("#060e18fa")
const BORDER_SUBTLE := Color("#2d4b66d9")
const BORDER_SOFT := Color("#3f6685e6")
const ACCENT_GOLD := Color("#d8b767")
const ACCENT_CYAN := Color("#69cbe8")
const ACTIVE_GREEN_BG := Color("#155f2be8")
const ACTIVE_GREEN_HOVER := Color("#1b6f34e8")
const ACTIVE_GREEN_BORDER := Color("#58d96f")
const ACTIVE_GREEN_BORDER_HOVER := Color("#72f28a")
const TEXT_PRIMARY := Color("#f4f0de")
const TEXT_MUTED := Color("#aeb8c5")
const POPUP_Z_INDEX := 1050

var action_slot: PanelContainer
var action_button: TextureButton
var popup: PanelContainer
var status_label: Label
var experience_label: Label
var experience_bar: ProgressBar
var rods_container: VBoxContainer
var selection_pending := false
var action_hovered := false


func _ready() -> void:
	add_to_group("fishing_action_controller")
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	call_deferred("_build_interface")


func _build_interface() -> void:
	var overlay := get_parent()
	var actions_row := overlay.get_node_or_null("Control/ToggleActionsPanel/MarginContainer/HBoxContainer") as HBoxContainer
	var control := overlay.get_node_or_null("Control") as Control
	if actions_row == null or control == null:
		push_warning("FishingActionController: action bar is unavailable.")
		return

	action_slot = PanelContainer.new()
	action_slot.name = "FishingRodSlot"
	action_slot.custom_minimum_size = Vector2(52, 52)
	actions_row.add_child(action_slot)

	action_button = TextureButton.new()
	action_button.name = "FishingRodButton"
	action_button.custom_minimum_size = Vector2(32, 32)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.ignore_texture_size = true
	action_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.pressed.connect(_toggle_popup)
	action_button.mouse_entered.connect(_on_action_hover_changed.bind(true))
	action_button.mouse_exited.connect(_on_action_hover_changed.bind(false))
	action_slot.add_child(action_button)

	popup = PanelContainer.new()
	popup.name = "FishingRodPopup"
	popup.visible = false
	popup.custom_minimum_size = Vector2(372, 0)
	popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	popup.position = Vector2(-388, 76)
	popup.z_index = POPUP_Z_INDEX
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_theme_stylebox_override("panel", _make_popup_style())
	control.add_child(popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	popup.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var header_icon := TextureRect.new()
	header_icon.custom_minimum_size = Vector2(34, 34)
	header_icon.texture = FISHING_ACTION_ICON
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(header_icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	var title := Label.new()
	_set_localized_control_property(title, "text", "ui.fishing.title")
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.add_theme_font_size_override("font_size", 19)
	heading.add_child(title)
	var subtitle := Label.new()
	_set_localized_control_property(subtitle, "text", "ui.fishing.loadout")
	subtitle.add_theme_color_override("font_color", ACCENT_CYAN)
	subtitle.add_theme_font_size_override("font_size", 10)
	heading.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_control_property(close_button, "tooltip_text", "common.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(32, 32)
	_apply_close_button_style(close_button)
	close_button.pressed.connect(_close_popup)
	header.add_child(close_button)

	var header_separator := HSeparator.new()
	header_separator.custom_minimum_size = Vector2(0, 1)
	header_separator.add_theme_stylebox_override(
		"separator",
		_make_style(Color("#315070b3"), Color.TRANSPARENT, 0, 0)
	)
	content.add_child(header_separator)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	status_label.add_theme_font_size_override("font_size", 14)
	content.add_child(status_label)

	var experience_row := HBoxContainer.new()
	experience_row.add_theme_constant_override("separation", 8)
	content.add_child(experience_row)
	experience_label = Label.new()
	experience_label.custom_minimum_size = Vector2(82, 0)
	experience_label.add_theme_color_override("font_color", TEXT_MUTED)
	experience_label.add_theme_font_size_override("font_size", 12)
	experience_row.add_child(experience_label)
	experience_bar = ProgressBar.new()
	experience_bar.custom_minimum_size = Vector2(0, 8)
	experience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	experience_bar.show_percentage = false
	experience_bar.add_theme_stylebox_override(
		"background",
		_make_style(Color("#030812e8"), Color("#24445ecc"), 4, 1)
	)
	experience_bar.add_theme_stylebox_override(
		"fill",
		_make_style(Color("#3ca7c8"), Color("#78dcf5"), 4, 1)
	)
	experience_row.add_child(experience_bar)

	var loadout_label := Label.new()
	_set_localized_control_property(loadout_label, "text", "ui.fishing.available_rods")
	loadout_label.add_theme_color_override("font_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.82))
	loadout_label.add_theme_font_size_override("font_size", 10)
	content.add_child(loadout_label)
	rods_container = VBoxContainer.new()
	rods_container.add_theme_constant_override("separation", 7)
	content.add_child(rods_container)

	LocalizationManager.localize_tree(popup)
	refresh_from_game_state()


func refresh_from_game_state() -> void:
	if action_button == null:
		return
	var selected_id := GameState.selected_fishing_rod_item_id
	action_button.texture_normal = FISHING_ACTION_ICON
	action_button.texture_hover = FISHING_ACTION_ICON
	action_button.texture_pressed = FISHING_ACTION_ICON
	action_button.texture_disabled = FISHING_ACTION_ICON
	action_button.disabled = selection_pending
	_apply_action_slot_style()
	if selected_id == "":
		action_button.tooltip_text = LocalizationManager.text("ui.fishing.tooltip.no_rod")
	else:
		var usability := LocalizationManager.text(
			"ui.fishing.ready"
			if GameState.fishing_unlocked
			else "ui.fishing.locked_region"
		)
		action_button.tooltip_text = LocalizationManager.text(
			"ui.fishing.tooltip.rod",
			{"rod": _localized_rod_name(selected_id), "status": usability}
		)
	if status_label == null:
		return
	status_label.text = LocalizationManager.text("ui.fishing.progress", {
		"level": GameState.fishing_level,
		"region": _localized_fishing_region(),
		"badges": GameState.fishing_region_badge_count,
	})
	if GameState.fishing_experience_for_next_level > 0:
		experience_label.text = LocalizationManager.text("ui.fishing.experience", {
			"current": GameState.fishing_experience_into_level,
			"required": GameState.fishing_experience_for_next_level,
		})
		experience_bar.max_value = maxi(GameState.fishing_experience_for_next_level, 1)
		experience_bar.value = GameState.fishing_experience_into_level
	else:
		experience_label.text = LocalizationManager.text("ui.fishing.max_level")
		experience_bar.max_value = 1
		experience_bar.value = 1
	_rebuild_rod_buttons()


func _rebuild_rod_buttons() -> void:
	for child in rods_container.get_children():
		rods_container.remove_child(child)
		child.queue_free()
	var no_rod_button := Button.new()
	var no_rod_selected := GameState.selected_fishing_rod_item_id == ""
	no_rod_button.icon = FISHING_ACTION_ICON
	no_rod_button.expand_icon = true
	no_rod_button.custom_minimum_size = Vector2(0, 48)
	no_rod_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	no_rod_button.focus_mode = Control.FOCUS_NONE
	no_rod_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	no_rod_button.text = LocalizationManager.text(
		"ui.fishing.no_rod.selected" if no_rod_selected else "ui.fishing.no_rod.stow"
	)
	no_rod_button.disabled = selection_pending
	no_rod_button.tooltip_text = LocalizationManager.text("ui.fishing.no_rod.tooltip")
	_apply_no_rod_button_style(no_rod_button, no_rod_selected)
	no_rod_button.pressed.connect(_select_rod.bind(""))
	rods_container.add_child(no_rod_button)
	for rod_value: Variant in GameState.fishing_rods:
		if not (rod_value is Dictionary):
			continue
		var rod: Dictionary = rod_value
		var item_id := str(rod.get("itemId", "")).strip_edges().to_lower()
		var button := Button.new()
		button.icon = ROD_ICONS.get(item_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = _rod_button_text(rod)
		button.disabled = selection_pending or not bool(rod.get("owned", false)) or not bool(rod.get("usable", false))
		button.tooltip_text = _rod_tooltip(rod)
		_apply_rod_button_style(button, rod, item_id == GameState.selected_fishing_rod_item_id)
		button.pressed.connect(_select_rod.bind(item_id))
		rods_container.add_child(button)


func _rod_button_text(rod: Dictionary) -> String:
	var item_id := str(rod.get("itemId", "")).strip_edges().to_lower()
	var prefix := "✓ " if item_id == GameState.selected_fishing_rod_item_id else ""
	var name := _localized_rod_name(item_id, str(rod.get("name", "")))
	if not bool(rod.get("owned", false)):
		return prefix + LocalizationManager.text("ui.fishing.rod.not_owned", {"rod": name})
	if not bool(rod.get("levelRequirementMet", false)):
		return prefix + LocalizationManager.text("ui.fishing.rod.level_required", {
			"rod": name,
			"level": int(rod.get("requiredLevel", 1)),
		})
	if not bool(rod.get("badgeRequirementMet", false)):
		return prefix + LocalizationManager.text("ui.fishing.rod.badges_required", {
			"rod": name,
			"badges": int(rod.get("requiredBadges", 0)),
			"region": _localized_fishing_region(),
		})
	return prefix + LocalizationManager.text("ui.fishing.rod.ready", {"rod": name})


func _rod_tooltip(rod: Dictionary) -> String:
	return LocalizationManager.text("ui.fishing.rod.requirements", {
		"level": int(rod.get("requiredLevel", 1)),
		"badges": int(rod.get("requiredBadges", 0)),
	})


func _toggle_popup() -> void:
	if popup == null:
		return
	popup.visible = not popup.visible
	if popup.visible:
		popup.move_to_front()
		_apply_action_slot_style()
		await _refresh_progression()
	else:
		_apply_action_slot_style()


func _close_popup() -> void:
	if popup != null:
		popup.visible = false
		_apply_action_slot_style()


func _refresh_progression() -> void:
	var result: Dictionary = await InventoryService.load_fishing_progression(_current_area_id())
	if not bool(result.get("success", false)):
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.fishing.error.refresh")
		)


func _select_rod(item_id: String) -> void:
	if selection_pending:
		return
	selection_pending = true
	refresh_from_game_state()
	var result: Dictionary = await InventoryService.select_fishing_rod(item_id, _current_area_id())
	selection_pending = false
	refresh_from_game_state()
	if not bool(result.get("success", false)):
		push_warning("FishingActionController: rod selection failed: %s" % str(result.get("error", "Unknown error")))
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.fishing.error.select")
		)


func _localized_rod_name(item_id: String, fallback_name: String = "") -> String:
	var fallback := fallback_name.strip_edges()
	if fallback == "":
		fallback = str(ROD_NAMES.get(item_id, item_id))
	return ItemLocalization.display_name(item_id, fallback)


func _localized_fishing_region() -> String:
	var region_id := str(GameState.fishing_region).strip_edges().to_lower()
	var key := "ui.fishing.region.%s" % region_id
	if region_id != "" and LocalizationManager.has_key(key):
		return LocalizationManager.text(key)
	return region_id.capitalize()


func _set_localized_control_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, LocalizationManager.text(key))


func _on_locale_changed(_locale: String) -> void:
	if popup != null:
		LocalizationManager.localize_tree(popup)
	refresh_from_game_state()


func _current_area_id() -> String:
	var current_map: Node = GameState.current_map
	if current_map != null and is_instance_valid(current_map) and current_map.has_method("get_wild_encounter_area_id"):
		return str(current_map.call("get_wild_encounter_area_id")).strip_edges()
	return ""


func _on_action_hover_changed(hovered: bool) -> void:
	action_hovered = hovered
	_apply_action_slot_style()


func _apply_action_slot_style() -> void:
	if action_slot == null or action_button == null:
		return
	var selected := popup != null and popup.visible
	var rod_active := (
		not GameState.selected_fishing_rod_item_id.is_empty()
		and GameState.fishing_unlocked
		and GameState.fishing_tier > 0
	)
	var background := SURFACE_INTERACTIVE
	var border := BORDER_SOFT
	if rod_active:
		background = ACTIVE_GREEN_HOVER if action_hovered else ACTIVE_GREEN_BG
		border = ACTIVE_GREEN_BORDER_HOVER if action_hovered else ACTIVE_GREEN_BORDER
	elif action_hovered:
		background = SURFACE_HOVER
		border = ACCENT_CYAN
	if selected:
		background = ACTIVE_GREEN_HOVER if rod_active else SURFACE_HOVER
		border = ACCENT_GOLD
	var width := 2 if selected else 1
	var style := _make_style(background, border, 9, width)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	action_slot.add_theme_stylebox_override("panel", style)
	action_button.modulate = Color.WHITE if rod_active else Color(0.66, 0.72, 0.8, 0.9)


func _apply_no_rod_button_style(button: Button, selected: bool) -> void:
	var background := Color("#252114f2") if selected else SURFACE_INTERACTIVE
	var border := ACCENT_GOLD if selected else BORDER_SUBTLE
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_stylebox_override("normal", _make_button_style(background, border))
	button.add_theme_stylebox_override("hover", _make_button_style(SURFACE_HOVER, ACCENT_CYAN))
	button.add_theme_stylebox_override("pressed", _make_button_style(SURFACE_PRESSED, ACCENT_CYAN))
	button.add_theme_stylebox_override("focus", _make_button_style(SURFACE_HOVER, ACCENT_CYAN))
	button.add_theme_stylebox_override("disabled", _make_button_style(background, border))
	button.modulate = Color.WHITE if selected else Color(0.78, 0.82, 0.88, 0.92)


func _apply_rod_button_style(button: Button, rod: Dictionary, selected: bool) -> void:
	var owned := bool(rod.get("owned", false))
	var usable := bool(rod.get("usable", false))
	var normal_background := SURFACE_INTERACTIVE
	var normal_border := BORDER_SUBTLE
	var font_color := TEXT_PRIMARY
	if selected:
		normal_background = Color("#252114f2")
		normal_border = ACCENT_GOLD
	elif usable:
		normal_border = Color("#397893d9")
	elif not owned:
		normal_background = Color("#060d17db")
		normal_border = Color("#24384a99")
		font_color = Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.48)
	else:
		normal_background = Color("#09121ee8")
		font_color = Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.62)

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", font_color)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 34)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_background, normal_border))
	button.add_theme_stylebox_override("hover", _make_button_style(SURFACE_HOVER, ACCENT_CYAN))
	button.add_theme_stylebox_override("pressed", _make_button_style(SURFACE_PRESSED, ACCENT_CYAN))
	button.add_theme_stylebox_override("focus", _make_button_style(SURFACE_HOVER, ACCENT_CYAN))
	button.add_theme_stylebox_override("disabled", _make_button_style(normal_background, normal_border))
	button.modulate = Color.WHITE if owned else Color(0.72, 0.76, 0.82, 0.78)


func _apply_close_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", TEXT_MUTED)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _make_button_style(Color.TRANSPARENT, Color.TRANSPARENT, 7, 0))
	button.add_theme_stylebox_override("hover", _make_button_style(SURFACE_HOVER, BORDER_SOFT, 7, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(SURFACE_PRESSED, BORDER_SOFT, 7, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(SURFACE_HOVER, BORDER_SOFT, 7, 1))


func _make_popup_style() -> StyleBoxFlat:
	var style := _make_style(SURFACE_BASE, Color("#456b87f2"), 12, 1)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _make_button_style(
	background: Color,
	border: Color,
	radius := 9,
	border_width := 1
) -> StyleBoxFlat:
	var style := _make_style(background, border, radius, border_width)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style


func _make_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
