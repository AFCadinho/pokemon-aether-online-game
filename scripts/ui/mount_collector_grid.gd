extends "res://scripts/ui/mentor_topic_menu.gd"

const Mounts := preload("res://scripts/services/mount_service.gd")
const OFFERS_PER_PAGE := 6
const CARD_HEIGHT := 196


func choose_mount(offers: Array, page: int, credit: int) -> String:
	layer = 105
	_build_grid(offers, page, credit)
	return await topic_selected


func _build_grid(offers: Array, page: int, credit: int) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(660, viewport_size.x - 32)
	var visible_count := mini(OFFERS_PER_PAGE, offers.size() - page * OFFERS_PER_PAGE)
	if visible_count <= 2:
		panel_width = minf(panel_width, 540 if visible_count == 2 else 360)
	var columns := 3 if panel_width >= 600 else 2 if panel_width >= 400 else 1
	var root := Control.new()
	root.name = "MountCollectorGrid"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#02060bd1")
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MountPanel"
	panel.custom_minimum_size.x = panel_width
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	layout.add_child(_label(LocalizationManager.text("ui.mount_collector.title"), 22, Color("#f4f0de")))
	var prompt := _label(LocalizationManager.text("ui.mount_collector.choose", {"credit": credit}), 13, Color("#afbdca"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(prompt)
	var scroll := ScrollContainer.new()
	scroll.name = "MountScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var start := page * OFFERS_PER_PAGE
	var end := mini(start + OFFERS_PER_PAGE, offers.size())
	var rows := ceili(float(end - start) / columns)
	scroll.custom_minimum_size.y = minf(rows * (CARD_HEIGHT + 10), maxf(64, viewport_size.y - 260))
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "MountCards"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var first_card: Button
	for index: int in range(start, end):
		var card := _mount_card(offers[index])
		grid.add_child(card)
		if first_card == null:
			first_card = card
	var pages := ceili(float(offers.size()) / OFFERS_PER_PAGE)
	if pages > 1:
		var navigation := HBoxContainer.new()
		navigation.add_theme_constant_override("separation", 12)
		layout.add_child(navigation)
		var previous := _action_button(LocalizationManager.text("ui.mount_collector.previous"), "previous")
		previous.disabled = page == 0
		navigation.add_child(previous)
		var counter := _label("%s / %s" % [page + 1, pages], 13, Color("#afbdca"))
		counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		navigation.add_child(counter)
		var next := _action_button(LocalizationManager.text("ui.mount_collector.next"), "next")
		next.disabled = page + 1 == pages
		navigation.add_child(next)
	layout.add_child(_action_button(LocalizationManager.text("common.close"), ""))
	if first_card != null:
		first_card.grab_focus.call_deferred()


func _mount_card(offer: Dictionary) -> Button:
	var mount_id := str(offer.get("shinyMountId", ""))
	var mount_name := Mounts.get_mount_display_name(mount_id)
	var bound := bool(offer.get("accountBound", false))
	var binding: String = LocalizationManager.text("ui.mount_collector.bound" if bound else "ui.mount_collector.tradeable")
	var card := _action_button("", str(offer.get("itemId", "")))
	card.name = "MountCard"
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.set_meta("item_id", str(offer.get("itemId", "")))
	card.tooltip_text = "%s ×%s · %s" % [mount_name, int(offer.get("quantity", 0)), binding]
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_right = -10
	content.offset_top = 8
	content.offset_bottom = -8
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var count := _label("×%s" % int(offer.get("quantity", 0)), 12, Color("#e3bd68"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(count)
	var image := TextureRect.new()
	image.name = "MountImage"
	image.custom_minimum_size = Vector2(0, 80)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _preview_texture(mount_id)
	content.add_child(image)
	var title := _label(mount_name, 14, Color("#e8eef4"))
	title.custom_minimum_size.y = 40
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(title)
	var badge := _label(binding, 11, Color("#e3bd68") if bound else Color("#83d8b0"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(badge)
	return card


func _preview_texture(mount_id: String) -> Texture2D:
	var texture := Mounts.get_mount_icon_texture(mount_id)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	var used := image.get_used_rect()
	if not used.has_area():
		return texture
	var preview := AtlasTexture.new()
	preview.atlas = texture
	preview.region = used
	return preview


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _action_button(text: String, choice: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("#e8eef4"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#0b1a2b"), Color("#315070"), true))
	button.add_theme_stylebox_override("hover", _button_style(Color("#14314c"), Color("#60d3ff"), true))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#091521"), Color("#e3bd68"), true))
	var focus := _button_style(Color.TRANSPARENT, Color("#e3bd68"), true)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(_finish.bind(choice))
	return button
