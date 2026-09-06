extends VBoxContainer

var category: OptionButton
var preview: CheckButton
var preview_level: SpinBox
var summary: Label
var rows: VBoxContainer
var scroll: ScrollContainer
var retry: Button
var player_level := 1
var catalog: Dictionary = {}
var request_revision := 0

const CONTROL_BACKGROUND := Color("#071522")
const CONTROL_HOVER := Color("#102a40")
const CONTROL_PRESSED := Color("#0d3048")
const CONTROL_BORDER := Color("#31546e")
const CONTROL_ACCENT := Color("#58c8eb")
const CONTROL_TEXT := Color("#e8edf2")


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	category = OptionButton.new()
	category.name = "RewardCategory"
	for key in ["items", "fossils", "money_xp"]:
		category.add_item(_text(key))
	_style_option(category)
	category.item_selected.connect(func(_index: int): _render())
	add_child(category)
	var controls := HBoxContainer.new()
	add_child(controls)
	preview = CheckButton.new()
	preview.text = _text("preview")
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_color_override("font_color", CONTROL_TEXT)
	preview.add_theme_color_override("font_hover_color", CONTROL_TEXT)
	preview.add_theme_font_size_override("font_size", 12)
	controls.add_child(preview)
	preview_level = SpinBox.new()
	preview_level.min_value = 1
	preview_level.max_value = 100
	preview_level.step = 1
	preview_level.visible = false
	_style_spinbox(preview_level)
	controls.add_child(preview_level)
	preview.toggled.connect(func(enabled: bool):
		preview_level.visible = enabled
		_refresh()
	)
	preview_level.value_changed.connect(func(_value: float):
		if preview.button_pressed:
			_refresh()
	)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color("#aeb8c5"))
	summary.add_theme_font_size_override("font_size", 12)
	add_child(summary)
	retry = Button.new()
	retry.text = _text("retry")
	retry.visible = false
	retry.pressed.connect(_refresh)
	add_child(retry)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)


func _style_option(button: OptionButton) -> void:
	button.custom_minimum_size.y = 34.0
	button.add_theme_color_override("font_color", CONTROL_TEXT)
	button.add_theme_color_override("font_hover_color", CONTROL_TEXT)
	button.add_theme_color_override("font_pressed_color", CONTROL_TEXT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _control_style(CONTROL_BACKGROUND, CONTROL_BORDER))
	button.add_theme_stylebox_override("hover", _control_style(CONTROL_HOVER, CONTROL_ACCENT))
	button.add_theme_stylebox_override("pressed", _control_style(CONTROL_PRESSED, CONTROL_ACCENT))
	button.add_theme_stylebox_override("focus", _control_style(CONTROL_PRESSED, CONTROL_ACCENT))
	var popup := button.get_popup()
	popup.add_theme_color_override("font_color", CONTROL_TEXT)
	popup.add_theme_color_override("font_hover_color", CONTROL_TEXT)
	popup.add_theme_font_size_override("font_size", 12)
	popup.add_theme_stylebox_override("panel", _control_style(CONTROL_BACKGROUND, CONTROL_BORDER))
	popup.add_theme_stylebox_override("hover", _control_style(CONTROL_HOVER, CONTROL_ACCENT))


func _style_spinbox(spinbox: SpinBox) -> void:
	spinbox.custom_minimum_size = Vector2(92, 34)
	var line_edit := spinbox.get_line_edit()
	line_edit.add_theme_color_override("font_color", CONTROL_TEXT)
	line_edit.add_theme_color_override("caret_color", CONTROL_ACCENT)
	line_edit.add_theme_font_size_override("font_size", 12)
	line_edit.add_theme_stylebox_override("normal", _control_style(CONTROL_BACKGROUND, CONTROL_BORDER))
	line_edit.add_theme_stylebox_override("focus", _control_style(CONTROL_PRESSED, CONTROL_ACCENT))


func _control_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func show_for_level(level: int) -> void:
	for index in range(category.item_count):
		category.set_item_text(index, _text(["items", "fossils", "money_xp"][index]))
	preview.text = _text("preview")
	retry.text = _text("retry")
	player_level = level
	if not preview.button_pressed:
		preview_level.set_value_no_signal(level)
	_refresh()


func _refresh() -> void:
	request_revision += 1
	var revision := request_revision
	catalog = {}
	_render()
	summary.text = _text("loading")
	retry.hide()
	var level := int(preview_level.value) if preview.button_pressed else player_level
	var response: Dictionary = await SkillsService.load_rock_smash_rewards(level)
	if revision != request_revision or not is_inside_tree():
		return
	if not bool(response.get("success", false)):
		summary.text = _text("error")
		retry.show()
		return
	catalog = response.get("body", {})
	_render()


func _render() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	if catalog.is_empty():
		return
	var level := int(catalog.get("level", player_level))
	var context := _text("level", {"level": level})
	if level > player_level:
		context += " · " + _text("locked")
	if category.selected == 2:
		summary.text = context + "\n" + _text("guaranteed")
		for rock: Dictionary in catalog.get("rocks", []):
			var required := int(rock.get("requiredLevel", 1))
			var title := _text("rock_level", {"level": required})
			if required > player_level:
				title += " · " + _text("locked")
			_row(title, _text("payout", {
				"money": int(rock.get("money", 0)),
				"xp": int(rock.get("experience", 0)),
			}))
		_row(_text("boost"), "×%d" % int(catalog.get("experienceMultiplier", 1)))
		_row(_text("guild"), _text("guild_detail"))
		return
	var fossils := category.selected == 1
	var chance := float(catalog.get("fossilChancePercent" if fossils else "itemChancePercent", 0))
	summary.text = context + "\n" + _text("chance", {"chance": _percent(chance)}) + " · " + _text("bonus" if fossils else "one_item")
	var entries: Array = catalog.get("fossils" if fossils else "items", [])
	if entries.is_empty():
		_row(_text("fossils_locked"), "")
	for entry: Dictionary in entries:
		var item_id := str(entry.get("itemId", ""))
		var title := ItemLocalization.display_name(item_id, item_id.replace("-", " ").capitalize())
		_row("%s ×%d" % [title, int(entry.get("quantity", 1))], _percent(float(entry.get("chancePercent", 0))), item_id)


func _row(title: String, value: String, item_id := "") -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#07111c")
	style.border_color = Color("#263b50")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	rows.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	if not item_id.is_empty():
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for path: String in ["res://assets/items/icons/%s.png" % item_id.to_upper().replace("-", ""), "res://assets/items/icons/000.png"]:
			if ResourceLoader.exists(path):
				icon.texture = load(path)
				break
		line.add_child(icon)
	var name_label := Label.new()
	name_label.text = title
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	line.add_child(name_label)
	var amount := Label.new()
	amount.text = value
	amount.add_theme_font_size_override("font_size", 12)
	amount.add_theme_color_override("font_color", Color("#70d8f6"))
	line.add_child(amount)


func _percent(value: float) -> String:
	return ("%.4f" % value).rstrip("0").rstrip(".") + "%"


func _text(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.skills.rock_smash.rewards." + key, values)
