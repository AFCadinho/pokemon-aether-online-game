extends "res://scripts/ui/mentor_topic_menu.gd"

const Mounts := preload("res://scripts/services/mount_service.gd")
const OFFERS_PER_PAGE := 12
const CARD_HEIGHT := 146

var view_state: Dictionary = {}
var all_offers: Array = []
var filtered_offers: Array = []
var shiny_totals: Dictionary = {}
var grid: GridContainer
var scroll: ScrollContainer
var summary: Label
var empty_label: Label
var counter: Label
var previous: Button
var next: Button
var search: LineEdit
var tabs: TabBar
var duplicates: CheckButton
var binding: OptionButton
var preview_cache: Dictionary = {}
var panel: PanelContainer
var navigation: HBoxContainer


func choose_mount(offers: Array, page: int, credit: int, state: Dictionary = {}) -> String:
	layer = 105
	_build_grid(offers, page, credit, state)
	return await topic_selected


func _build_grid(offers: Array, page: int, credit: int, state: Dictionary = {}) -> void:
	all_offers = offers
	view_state = state
	if not view_state.has("page"):
		view_state["page"] = page
	for offer: Dictionary in all_offers:
		var mount_id := str(offer.get("shinyMountId", ""))
		shiny_totals[mount_id] = int(shiny_totals.get(mount_id, 0)) + int(offer.get("quantity", 0))
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(800, viewport_size.x - 32)
	var columns := maxi(1, mini(4, int((panel_width - 32) / 175)))
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
	panel = PanelContainer.new()
	panel.name = "MountPanel"
	panel.custom_minimum_size.x = panel_width
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var title := _label(_t("title"), 22, Color("#f4f0de"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)
	var prompt := _label(_t("choose", {"credit": credit}), 13, Color("#afbdca"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(prompt)
	search = LineEdit.new()
	search.name = "MountSearch"
	search.placeholder_text = _t("search")
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 34
	search.text = str(view_state.get("search", ""))
	search.add_theme_font_size_override("font_size", 13)
	search.add_theme_stylebox_override("normal", _button_style(Color("#0b1a2b"), Color("#315070"), true))
	search.add_theme_stylebox_override("focus", _button_style(Color.TRANSPARENT, Color("#e3bd68"), true))
	layout.add_child(search)
	search.text_changed.connect(func(value: String) -> void: _change_filter("search", value))
	tabs = TabBar.new()
	tabs.name = "MovementTabs"
	for mode: String in ["all", "land", "surf"]:
		var count := 0
		for mount_id: String in shiny_totals:
			if mode == "all" or Mounts.get_mount_movement_mode(mount_id) == mode:
				count += 1
		tabs.add_tab("%s (%s)" % [_t("tab_" + mode), count])
	tabs.current_tab = ["all", "land", "surf"].find(str(view_state.get("mode", "all")))
	tabs.add_theme_font_size_override("font_size", 13)
	tabs.add_theme_stylebox_override("tab_selected", _button_style(Color("#14314c"), Color("#e3bd68"), true))
	tabs.add_theme_stylebox_override("tab_unselected", _button_style(Color("#0b1a2b"), Color("#315070"), true))
	tabs.add_theme_stylebox_override("tab_hovered", _button_style(Color("#14314c"), Color("#60d3ff"), true))
	layout.add_child(tabs)
	tabs.tab_changed.connect(func(index: int) -> void: _change_filter("mode", ["all", "land", "surf"][index]))
	var filters: BoxContainer = HBoxContainer.new() if panel_width >= 400 else VBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	layout.add_child(filters)
	duplicates = CheckButton.new()
	duplicates.name = "DuplicatesOnly"
	duplicates.text = _t("duplicates_only")
	duplicates.tooltip_text = _t("duplicates_hint")
	duplicates.button_pressed = bool(view_state.get("duplicates", false))
	duplicates.add_theme_font_size_override("font_size", 13)
	duplicates.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filters.add_child(duplicates)
	if filters is HBoxContainer:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filters.add_child(spacer)
	duplicates.toggled.connect(func(value: bool) -> void: _change_filter("duplicates", value))
	binding = OptionButton.new()
	binding.name = "BindingFilter"
	binding.add_theme_font_size_override("font_size", 13)
	binding.add_theme_stylebox_override("normal", _button_style(Color("#0b1a2b"), Color("#315070"), true))
	binding.add_theme_stylebox_override("hover", _button_style(Color("#14314c"), Color("#60d3ff"), true))
	binding.add_item(_t("binding_all"))
	binding.add_item(_t("tradeable"))
	binding.add_item(_t("bound"))
	binding.selected = int(view_state.get("binding", 0))
	binding.custom_minimum_size.y = 32
	filters.add_child(binding)
	binding.item_selected.connect(func(index: int) -> void: _change_filter("binding", index))
	summary = _label("", 12, Color("#afbdca"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(summary)
	scroll = ScrollContainer.new()
	scroll.name = "MountScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = minf(450, maxf(48, viewport_size.y - 390))
	layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	grid = GridContainer.new()
	grid.name = "MountCards"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	empty_label = _label(_t("no_results"), 14, Color("#afbdca"))
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(empty_label)
	navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	layout.add_child(navigation)
	previous = _action_button(_t("previous"), "")
	previous.pressed.disconnect(_finish.bind(""))
	previous.pressed.connect(_change_page.bind(-1))
	navigation.add_child(previous)
	counter = _label("", 13, Color("#afbdca"))
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(counter)
	next = _action_button(_t("next"), "")
	next.pressed.disconnect(_finish.bind(""))
	next.pressed.connect(_change_page.bind(1))
	navigation.add_child(next)
	layout.add_child(_action_button(LocalizationManager.text("common.close"), ""))
	_refresh_cards()
	panel.resized.connect(_fit_scroll_height)
	_fit_scroll_height.call_deferred()
	search.grab_focus.call_deferred()


func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.mount_collector." + key, values)


func _change_filter(key: String, value: Variant) -> void:
	view_state[key] = value
	view_state["page"] = 0
	_refresh_cards()


func _change_page(delta: int) -> void:
	view_state["page"] = int(view_state.get("page", 0)) + delta
	_refresh_cards()
	_focus_first_card.call_deferred()


func _focus_first_card() -> void:
	if is_inside_tree() and grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()


func _fit_scroll_height() -> void:
	if not is_inside_tree():
		return
	var other_height := panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var rows := ceili(float(grid.get_child_count()) / grid.columns)
	var content_height := rows * CARD_HEIGHT + maxi(0, rows - 1) * 8
	if rows == 0:
		content_height = maxi(48, int(empty_label.get_combined_minimum_size().y))
	var height := minf(content_height, clampf(get_viewport().get_visible_rect().size.y - other_height - 32, 48, 454))
	if absf(scroll.custom_minimum_size.y - height) >= 1:
		scroll.custom_minimum_size.y = height


func _matching_offers() -> Array:
	var matches: Array = []
	var query := str(view_state.get("search", "")).strip_edges().to_lower()
	var mode := str(view_state.get("mode", "all"))
	var binding_filter := int(view_state.get("binding", 0))
	for offer: Dictionary in all_offers:
		var mount_id := str(offer.get("shinyMountId", ""))
		if mode != "all" and Mounts.get_mount_movement_mode(mount_id) != mode:
			continue
		if bool(view_state.get("duplicates", false)) and int(shiny_totals.get(mount_id, 0)) <= 1:
			continue
		if binding_filter == 1 and bool(offer.get("accountBound", false)):
			continue
		if binding_filter == 2 and not bool(offer.get("accountBound", false)):
			continue
		var name := Mounts.get_mount_display_name(mount_id).to_lower()
		if not query.is_empty() and not query in name and not query in str(offer.get("name", "")).to_lower():
			continue
		matches.append(offer)
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_name := Mounts.get_mount_display_name(str(a.get("shinyMountId", "")))
		var b_name := Mounts.get_mount_display_name(str(b.get("shinyMountId", "")))
		return str(a.get("itemId", "")) < str(b.get("itemId", "")) if a_name == b_name else a_name.naturalnocasecmp_to(b_name) < 0)
	return matches


func _refresh_cards() -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	filtered_offers = _matching_offers()
	var pages := maxi(1, ceili(float(filtered_offers.size()) / OFFERS_PER_PAGE))
	var page := clampi(int(view_state.get("page", 0)), 0, pages - 1)
	navigation.visible = pages > 1
	view_state["page"] = page
	for index: int in range(page * OFFERS_PER_PAGE, mini((page + 1) * OFFERS_PER_PAGE, filtered_offers.size())):
		grid.add_child(_mount_card(filtered_offers[index]))
	empty_label.visible = filtered_offers.is_empty()
	previous.disabled = page == 0
	next.disabled = page + 1 == pages
	counter.text = "%s / %s" % [page + 1, pages]
	summary.text = _t("results", {"count": filtered_offers.size(), "total": all_offers.size()})
	if bool(view_state.get("duplicates", false)):
		summary.text += " · " + _t("keep_one")
	scroll.scroll_vertical = 0
	_fit_scroll_height.call_deferred()


func _mount_card(offer: Dictionary) -> Button:
	var mount_id := str(offer.get("shinyMountId", ""))
	var mount_name := Mounts.get_mount_display_name(mount_id)
	var bound := bool(offer.get("accountBound", false))
	var binding_text := _t("bound" if bound else "tradeable")
	var card := _action_button("", str(offer.get("itemId", "")))
	card.name = "MountCard"
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.set_meta("item_id", str(offer.get("itemId", "")))
	var total := int(shiny_totals.get(mount_id, int(offer.get("quantity", 0))))
	card.tooltip_text = "%s ×%s · %s\n%s" % [mount_name, int(offer.get("quantity", 0)), binding_text, _t("copies", {"count": total, "spare": maxi(0, total - 1)})]
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_right = -8
	content.offset_top = 6
	content.offset_bottom = -6
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	card.add_child(content)
	var count := _label("×%s" % int(offer.get("quantity", 0)), 11, Color("#e3bd68"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(count)
	var image := TextureRect.new()
	image.name = "MountImage"
	image.custom_minimum_size = Vector2(0, 48)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _preview_texture(mount_id)
	content.add_child(image)
	var title := _label(mount_name, 13, Color("#e8eef4"))
	title.custom_minimum_size.y = 32
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(title)
	var badge := _label(binding_text, 10, Color("#e3bd68") if bound else Color("#83d8b0"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(badge)
	var spare := _label(_t("spares", {"count": maxi(0, total - 1)}), 10, Color("#83d8b0") if total > 1 else Color("#afbdca"))
	spare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(spare)
	return card


func _preview_texture(mount_id: String) -> Texture2D:
	if preview_cache.has(mount_id):
		return preview_cache[mount_id] as Texture2D
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
	preview_cache[mount_id] = preview
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
