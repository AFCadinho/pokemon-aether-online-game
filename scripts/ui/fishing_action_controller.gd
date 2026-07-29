class_name FishingActionController
extends Node

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

var action_button: TextureButton
var popup: PanelContainer
var status_label: Label
var experience_label: Label
var rods_container: VBoxContainer
var selection_pending := false


func _ready() -> void:
	add_to_group("fishing_action_controller")
	call_deferred("_build_interface")


func _build_interface() -> void:
	var overlay := get_parent()
	var actions_row := overlay.get_node_or_null("Control/ToggleActionsPanel/MarginContainer/HBoxContainer") as HBoxContainer
	var control := overlay.get_node_or_null("Control") as Control
	if actions_row == null or control == null:
		push_warning("FishingActionController: action bar is unavailable.")
		return

	var slot := PanelContainer.new()
	slot.name = "FishingRodSlot"
	slot.custom_minimum_size = Vector2(52, 52)
	actions_row.add_child(slot)

	action_button = TextureButton.new()
	action_button.name = "FishingRodButton"
	action_button.custom_minimum_size = Vector2(32, 32)
	action_button.ignore_texture_size = true
	action_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.pressed.connect(_toggle_popup)
	slot.add_child(action_button)

	popup = PanelContainer.new()
	popup.name = "FishingRodPopup"
	popup.visible = false
	popup.custom_minimum_size = Vector2(320, 0)
	popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	popup.position = Vector2(-336, 76)
	control.add_child(popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	popup.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "Fishing"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(_close_popup)
	header.add_child(close_button)

	status_label = Label.new()
	content.add_child(status_label)
	experience_label = Label.new()
	content.add_child(experience_label)
	var separator := HSeparator.new()
	content.add_child(separator)
	rods_container = VBoxContainer.new()
	rods_container.add_theme_constant_override("separation", 5)
	content.add_child(rods_container)

	refresh_from_game_state()


func refresh_from_game_state() -> void:
	if action_button == null:
		return
	var selected_id := GameState.selected_fishing_rod_item_id
	var icon: Texture2D = ROD_ICONS.get(selected_id, ROD_ICONS["old-rod"])
	action_button.texture_normal = icon
	action_button.texture_hover = icon
	action_button.texture_pressed = icon
	action_button.texture_disabled = icon
	var has_rods := not GameState.fishing_owned_rod_item_ids.is_empty()
	action_button.disabled = selection_pending
	if selected_id == "":
		action_button.tooltip_text = "Fishing rods (no rod selected)"
	else:
		var usability := "ready" if GameState.fishing_unlocked else "locked in this region"
		action_button.tooltip_text = "%s — %s" % [ROD_NAMES.get(selected_id, selected_id), usability]
	if status_label == null:
		return
	status_label.text = "Level %d  •  %s badges: %d" % [
		GameState.fishing_level,
		GameState.fishing_region.capitalize(),
		GameState.fishing_region_badge_count,
	]
	if GameState.fishing_experience_for_next_level > 0:
		experience_label.text = "XP: %d / %d" % [
			GameState.fishing_experience_into_level,
			GameState.fishing_experience_for_next_level,
		]
	else:
		experience_label.text = "Maximum Fishing Level"
	_rebuild_rod_buttons()


func _rebuild_rod_buttons() -> void:
	for child in rods_container.get_children():
		child.queue_free()
	for rod_value: Variant in GameState.fishing_rods:
		if not (rod_value is Dictionary):
			continue
		var rod: Dictionary = rod_value
		var item_id := str(rod.get("itemId", "")).strip_edges().to_lower()
		var button := Button.new()
		button.icon = ROD_ICONS.get(item_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = _rod_button_text(rod)
		button.disabled = selection_pending or not bool(rod.get("owned", false)) or not bool(rod.get("usable", false))
		button.tooltip_text = _rod_tooltip(rod)
		button.pressed.connect(_select_rod.bind(item_id))
		rods_container.add_child(button)


func _rod_button_text(rod: Dictionary) -> String:
	var item_id := str(rod.get("itemId", "")).strip_edges().to_lower()
	var prefix := "✓ " if item_id == GameState.selected_fishing_rod_item_id else ""
	var name := str(rod.get("name", ROD_NAMES.get(item_id, item_id)))
	if not bool(rod.get("owned", false)):
		return "%s%s — Not owned" % [prefix, name]
	if not bool(rod.get("levelRequirementMet", false)):
		return "%s%s — Level %d required" % [prefix, name, int(rod.get("requiredLevel", 1))]
	if not bool(rod.get("badgeRequirementMet", false)):
		return "%s%s — %d %s badges required" % [
			prefix,
			name,
			int(rod.get("requiredBadges", 0)),
			GameState.fishing_region.capitalize(),
		]
	return "%s%s — Ready" % [prefix, name]


func _rod_tooltip(rod: Dictionary) -> String:
	return "Fishing Level %d • %d regional badges" % [
		int(rod.get("requiredLevel", 1)),
		int(rod.get("requiredBadges", 0)),
	]


func _toggle_popup() -> void:
	if popup == null:
		return
	popup.visible = not popup.visible
	if popup.visible:
		await _refresh_progression()


func _close_popup() -> void:
	if popup != null:
		popup.visible = false


func _refresh_progression() -> void:
	var result: Dictionary = await InventoryService.load_fishing_progression(_current_area_id())
	if not bool(result.get("success", false)):
		get_tree().call_group("ui_overlay", "add_system_message", "Fishing progress could not be refreshed.")


func _select_rod(item_id: String) -> void:
	if selection_pending:
		return
	selection_pending = true
	refresh_from_game_state()
	var result: Dictionary = await InventoryService.select_fishing_rod(item_id, _current_area_id())
	selection_pending = false
	refresh_from_game_state()
	if not bool(result.get("success", false)):
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			str(result.get("error", "That fishing rod could not be selected."))
		)


func _current_area_id() -> String:
	var current_map: Node = GameState.current_map
	if current_map != null and is_instance_valid(current_map) and current_map.has_method("get_wild_encounter_area_id"):
		return str(current_map.call("get_wild_encounter_area_id")).strip_edges()
	return ""
