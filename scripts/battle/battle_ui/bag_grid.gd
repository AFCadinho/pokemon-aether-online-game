extends MarginContainer

class_name BattleBagGrid

signal item_selected(item_data: Dictionary)

const ITEM_ICON_PATH := "res://assets/items/icons/%s.png"
const CAPTURE_ITEM_IDS: Array[String] = [
	"poke-ball",
	"great-ball",
	"ultra-ball",
	"master-ball",
	"premier-ball",
	"cherish-ball",
	"luxury-ball",
	"nest-ball",
	"net-ball",
	"dive-ball",
	"repeat-ball",
	"timer-ball",
	"safari-ball",
	"quick-ball",
	"dusk-ball",
	"heal-ball",
	"beast-ball",
	"fast-ball",
	"lure-ball",
	"level-ball",
	"heavy-ball",
	"love-ball",
	"friend-ball",
	"moon-ball",
	"sport-ball",
	"dream-ball",
]

var input_disabled := false
var item_buttons: Array[Button] = []
var content: VBoxContainer
var message_label: Label
var current_items: Array = []
var current_message_key := "battle.ui.bag"
var localization_manager: Node


func _ready() -> void:
	_build_layout()
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	show_localized_message("battle.ui.bag")


func set_items(items: Array) -> void:
	current_items = items.duplicate(true)
	current_message_key = ""
	_clear_content()
	var capture_items := _get_capture_items(items)
	if capture_items.is_empty():
		show_localized_message("battle.bag.no_poke_balls")
		return

	message_label.visible = false
	for item_value: Variant in capture_items:
		if item_value is Dictionary:
			content.add_child(_create_item_button(item_value as Dictionary))


func set_loading() -> void:
	current_items = []
	_clear_content()
	show_localized_message("common.loading")


func show_message(message: String) -> void:
	current_message_key = ""
	_clear_content()
	message_label.text = message
	message_label.visible = true


func show_localized_message(key: String) -> void:
	current_message_key = key
	_clear_content()
	message_label.text = _t(key)
	message_label.visible = true


func set_input_disabled(is_disabled: bool) -> void:
	input_disabled = is_disabled
	for button: Button in item_buttons:
		button.disabled = input_disabled
		button.modulate = Color("#8196ab") if input_disabled else Color.WHITE


func _build_layout() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 8)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_label.add_theme_color_override("font_color", Color("#9fb8cb"))
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)


func _clear_content() -> void:
	if content == null:
		return

	for child: Node in content.get_children():
		child.queue_free()
	item_buttons.clear()
	if message_label != null:
		message_label.visible = false


func _create_item_button(item_data: Dictionary) -> Button:
	var item_id := str(item_data.get("itemId", "")).strip_edges()
	var localized_item := ItemLocalization.localize_item(item_data)
	var item_name := str(localized_item.get("name", item_id)).strip_edges()
	var quantity: int = max(int(item_data.get("quantity", 0)), 0)
	if item_name.is_empty():
		item_name = item_id

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.tooltip_text = _t("battle.bag.item_quantity", {
		"item": item_name,
		"quantity": quantity,
	})
	_style_item_button(button)
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge: String in ["left", "right"]:
		padding.add_theme_constant_override("margin_" + edge, 10)
	for edge: String in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_" + edge, 7)
	button.add_child(padding)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	padding.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _load_item_icon(item_id)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color("#e5f3ff"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _row_style(Color("#102e43"), Color("#28516c")))
	row.add_child(badge)
	var count_label := Label.new()
	count_label.text = "×%d" % quantity
	count_label.custom_minimum_size.x = 34
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color("#78dfff"))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count_label)
	button.disabled = input_disabled or quantity <= 0
	button.modulate = Color("#8196ab") if button.disabled else Color.WHITE
	button.pressed.connect(_on_item_button_pressed.bind(item_data.duplicate(true)))
	item_buttons.append(button)
	return button


func _style_item_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _row_style(Color("#0c1c2d"), Color("#244b68")))
	button.add_theme_stylebox_override("hover", _row_style(Color("#12334a"), Color("#62d7ff")))
	button.add_theme_stylebox_override("pressed", _row_style(Color("#174760"), Color("#a3edff")))
	button.add_theme_stylebox_override("disabled", _row_style(Color("#0b1521"), Color("#253545")))
	var focus := _row_style(Color.TRANSPARENT, Color("#a3edff"))
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)


func _row_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _get_capture_items(items: Array) -> Array:
	var capture_items: Array = []
	for item_value: Variant in items:
		if not (item_value is Dictionary):
			continue

		var item: Dictionary = item_value
		var item_id := str(item.get("itemId", "")).strip_edges()
		if _is_capture_item(item_id) and int(item.get("quantity", 0)) > 0:
			capture_items.append(item.duplicate(true))

	return capture_items


func _is_capture_item(item_id: String) -> bool:
	return CAPTURE_ITEM_IDS.has(_normalize_item_id(item_id))


func _load_item_icon(item_id: String) -> Texture2D:
	var icon_key := _normalize_item_id(item_id).replace("-", "").to_upper()
	var icon := load(ITEM_ICON_PATH % icon_key) as Texture2D
	return icon


func _normalize_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


func _on_item_button_pressed(item_data: Dictionary) -> void:
	if input_disabled:
		return

	item_selected.emit(item_data)


func _on_locale_changed(_locale: String) -> void:
	if not current_items.is_empty():
		set_items(current_items)
	elif current_message_key != "":
		show_localized_message(current_message_key)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
