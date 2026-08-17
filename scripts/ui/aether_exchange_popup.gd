class_name AetherExchangePopup
extends PanelContainer

signal closed
signal wallet_changed

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_CYAN := Color("#71e4f3")
const UI_PURPLE := Color("#c694ff")
const UI_GOLD := Color("#f3cf70")
const UI_GREEN := Color("#70d6a1")
const UI_DANGER := Color("#ef7085")
const MAX_PRICE := 2_147_483_647
const BROWSE_CARD_MIN_WIDTH := 245.0
const BROWSE_GRID_MAX_COLUMNS := 3

var active_tab := "browse"
var asset_filter := ""
var browse_listings: Array = []
var my_listings: Array = []
var sellable_items: Array = []
var sellable_pokemon: Array = []
var selected_entry: Dictionary = {}
var selected_kind := ""
var request_busy := false
var wallet_money := 0
var rendered_list_entry_count := 0
var confirmation_action := Callable()

var title_label: Label
var subtitle_label: Label
var money_label: Label
var tab_buttons: Dictionary = {}
var filter_buttons: Dictionary = {}
var search_input: LineEdit
var search_timer: Timer
var refresh_button: Button
var list_caption: Label
var list_scroll: ScrollContainer
var list_container: GridContainer
var detail_stack: VBoxContainer
var status_label: Label
var confirmation_overlay: ColorRect
var confirmation_card: PanelContainer
var confirmation_title_label: Label
var confirmation_message_label: Label
var confirmation_confirm_button: Button
var confirmation_cancel_button: Button
var quantity_spin: SpinBox
var price_spin: SpinBox
var total_price_label: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#5d9ebddd"), 14, 2))
	_build_interface()
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.3
	search_timer.timeout.connect(_refresh_browse)
	add_child(search_timer)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null and not localization.locale_changed.is_connected(_on_locale_changed):
		localization.locale_changed.connect(_on_locale_changed)
	_translate_static_ui()


func open_exchange() -> void:
	visible = true
	confirmation_action = Callable()
	if confirmation_overlay != null:
		confirmation_overlay.visible = false
	selected_entry.clear()
	selected_kind = ""
	_set_status(_t("ui.exchange.status.loading"), UI_MUTED)
	request_busy = true
	_refresh_controls()
	var portfolio_loaded := await _load_portfolio()
	var browse_loaded := await _load_browse()
	request_busy = false
	_render_current_list()
	_refresh_controls()
	if portfolio_loaded and browse_loaded:
		_set_status(_t("ui.exchange.status.ready"), UI_MUTED)


func close_exchange() -> void:
	if request_busy:
		return
	if confirmation_overlay != null and confirmation_overlay.visible:
		_on_confirmation_cancelled()
		return
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 11)
	margin.add_child(layout)
	layout.add_child(_build_header())
	layout.add_child(_build_tabs())
	layout.add_child(_build_filters())

	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	layout.add_child(workspace)
	workspace.add_child(_build_list_panel())
	workspace.add_child(_build_detail_panel())

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	layout.add_child(status_label)

	_build_confirmation_overlay()


func _build_confirmation_overlay() -> void:
	confirmation_overlay = ColorRect.new()
	confirmation_overlay.name = "ExchangeConfirmationOverlay"
	confirmation_overlay.visible = false
	confirmation_overlay.color = Color("#01050bc9")
	confirmation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_overlay.z_index = 20
	add_child(confirmation_overlay)
	confirmation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	confirmation_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	confirmation_card = PanelContainer.new()
	confirmation_card.custom_minimum_size = Vector2(540, 210)
	confirmation_card.add_theme_stylebox_override(
		"panel", _panel_style(Color("#071321fc"), Color("#66d7e9e6"), 12, 2)
	)
	center.add_child(confirmation_card)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	confirmation_card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	stack.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = load("res://assets/ui/aether_exchange_icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	confirmation_title_label = Label.new()
	confirmation_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirmation_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirmation_title_label.add_theme_font_size_override("font_size", 19)
	confirmation_title_label.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(confirmation_title_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = _t("common.close")
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_on_confirmation_cancelled)
	_apply_button_style(close_button)
	header.add_child(close_button)

	var accent := PanelContainer.new()
	accent.custom_minimum_size = Vector2(0, 2)
	var accent_style := StyleBoxFlat.new()
	accent_style.bg_color = UI_CYAN
	accent_style.set_corner_radius_all(1)
	accent.add_theme_stylebox_override("panel", accent_style)
	stack.add_child(accent)

	confirmation_message_label = Label.new()
	confirmation_message_label.custom_minimum_size = Vector2(0, 54)
	confirmation_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirmation_message_label.add_theme_font_size_override("font_size", 14)
	confirmation_message_label.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(confirmation_message_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)

	confirmation_cancel_button = Button.new()
	confirmation_cancel_button.custom_minimum_size = Vector2(120, 38)
	confirmation_cancel_button.pressed.connect(_on_confirmation_cancelled)
	_apply_button_style(confirmation_cancel_button)
	actions.add_child(confirmation_cancel_button)

	confirmation_confirm_button = Button.new()
	confirmation_confirm_button.custom_minimum_size = Vector2(140, 38)
	confirmation_confirm_button.pressed.connect(_on_confirmation_confirmed)
	_apply_primary_button_style(confirmation_confirm_button)
	actions.add_child(confirmation_confirm_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 58)
	header.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.texture = load("res://assets/ui/aether_exchange_icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(heading)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle_label)
	var wallet_panel := PanelContainer.new()
	wallet_panel.custom_minimum_size = Vector2(165, 40)
	wallet_panel.add_theme_stylebox_override("panel", _panel_style(UI_INTERACTIVE, Color("#806d34aa"), 9, 1))
	header.add_child(wallet_panel)
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 13)
	money_label.add_theme_color_override("font_color", UI_GOLD)
	wallet_panel.add_child(money_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.pressed.connect(close_exchange)
	_apply_button_style(close_button)
	header.add_child(close_button)
	return header


func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for tab: String in ["browse", "sell", "mine"]:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(_on_tab_pressed.bind(tab))
		row.add_child(button)
		tab_buttons[tab] = button
	return row


func _build_filters() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for filter_id: String in ["", "item", "pokemon"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 34)
		button.pressed.connect(_on_filter_pressed.bind(filter_id))
		row.add_child(button)
		filter_buttons[filter_id] = button
	search_input = LineEdit.new()
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(300, 34)
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(_on_search_changed)
	row.add_child(search_input)
	refresh_button = Button.new()
	refresh_button.custom_minimum_size = Vector2(105, 34)
	refresh_button.pressed.connect(_refresh_current_tab)
	refresh_button.name = "RefreshButton"
	row.add_child(refresh_button)
	return row


func _build_list_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(615, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 11, 1))
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	list_caption = Label.new()
	list_caption.add_theme_font_size_override("font_size", 12)
	list_caption.add_theme_color_override("font_color", UI_CYAN)
	layout.add_child(list_caption)
	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.resized.connect(_update_list_grid_columns)
	layout.add_child(list_scroll)
	list_container = GridContainer.new()
	list_container.columns = 1
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("h_separation", 8)
	list_container.add_theme_constant_override("v_separation", 8)
	list_scroll.add_child(list_container)
	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(365, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 11, 1))
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 15)
	panel.add_child(margin)
	detail_stack = VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 10)
	margin.add_child(detail_stack)
	return panel


func _on_tab_pressed(tab: String) -> void:
	if request_busy or tab == active_tab:
		return
	active_tab = tab
	selected_entry.clear()
	selected_kind = ""
	if active_tab == "browse":
		await _refresh_browse()
	else:
		_render_current_list()
	_refresh_controls()


func _on_filter_pressed(filter_id: String) -> void:
	if request_busy or filter_id == asset_filter:
		return
	asset_filter = filter_id
	selected_entry.clear()
	selected_kind = ""
	if active_tab == "browse":
		await _refresh_browse()
	else:
		_render_current_list()
	_refresh_controls()


func _on_search_changed(_value: String) -> void:
	if active_tab == "browse":
		search_timer.start()
	else:
		_render_current_list()


func _refresh_current_tab() -> void:
	if request_busy:
		return
	request_busy = true
	_refresh_controls()
	var refreshed: bool
	if active_tab == "browse":
		refreshed = await _load_browse()
	else:
		refreshed = await _load_portfolio()
	request_busy = false
	_render_current_list()
	_refresh_controls()
	if refreshed:
		_set_status(_t("ui.exchange.status.updated"), UI_GREEN)


func _refresh_browse() -> void:
	if request_busy or active_tab != "browse":
		return
	request_busy = true
	_refresh_controls()
	await _load_browse()
	request_busy = false
	_render_current_list()
	_refresh_controls()


func _load_browse() -> bool:
	var service := get_node_or_null("/root/AetherExchangeService")
	var result: Dictionary = (
		await service.call("load_listings", asset_filter, search_input.text if search_input != null else "")
		if service != null
		else {"success": false, "error": _t("ui.exchange.error.load")}
	)
	if not bool(result.get("success", false)):
		browse_listings.clear()
		_set_status(str(result.get("error", _t("ui.exchange.error.load"))), UI_DANGER)
		return false
	browse_listings = _array(result.get("listings", [])).duplicate(true)
	return true


func _load_portfolio() -> bool:
	var service := get_node_or_null("/root/AetherExchangeService")
	var result: Dictionary = (
		await service.call("load_portfolio")
		if service != null
		else {"success": false, "error": _t("ui.exchange.error.load")}
	)
	if not bool(result.get("success", false)):
		my_listings.clear()
		sellable_items.clear()
		sellable_pokemon.clear()
		_set_status(str(result.get("error", _t("ui.exchange.error.load"))), UI_DANGER)
		return false
	my_listings = _array(result.get("listings", [])).duplicate(true)
	sellable_items = _array(result.get("sellableItems", [])).duplicate(true)
	sellable_pokemon = _array(result.get("sellablePokemon", [])).duplicate(true)
	wallet_money = maxi(int(_dictionary(result.get("wallet", {})).get("money", 0)), 0)
	_refresh_money()
	return true


func _render_current_list() -> void:
	_clear_children(list_container)
	var entries: Array = []
	var kind := "listing"
	match active_tab:
		"sell":
			kind = "sell"
			if asset_filter != "pokemon":
				entries.append_array(sellable_items)
			if asset_filter != "item":
				entries.append_array(sellable_pokemon)
		"mine":
			entries = my_listings.filter(func(value: Variant) -> bool:
				return asset_filter.is_empty() or str(_dictionary(value).get("assetType", "")) == asset_filter
			)
		_:
			entries = browse_listings

	var query := search_input.text.strip_edges().to_lower()
	if active_tab != "browse" and not query.is_empty():
		entries = entries.filter(func(value: Variant) -> bool:
			return _entry_name(_dictionary(value), kind).to_lower().contains(query)
		)

	rendered_list_entry_count = entries.size()
	list_caption.text = _list_caption(entries.size())
	if entries.is_empty():
		list_container.columns = 1
		var empty := Label.new()
		empty.text = _t("ui.exchange.empty.%s" % active_tab)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", UI_MUTED)
		empty.custom_minimum_size = Vector2(0, 120)
		list_container.add_child(empty)
	else:
		_update_list_grid_columns()
		for value: Variant in entries:
			var entry := _dictionary(value)
			list_container.add_child(_entry_button(entry, kind))
	if not _selection_still_visible(entries):
		selected_entry.clear()
		selected_kind = ""
	_render_detail()


func _update_list_grid_columns() -> void:
	if list_container == null:
		return
	if active_tab != "browse":
		list_container.columns = 1
		return
	if rendered_list_entry_count == 0:
		list_container.columns = 1
		return
	var available_width := list_scroll.size.x if list_scroll != null else 0.0
	if available_width <= 0.0:
		available_width = 560.0
	var columns := int(floor((available_width + 8.0) / (BROWSE_CARD_MIN_WIDTH + 8.0)))
	list_container.columns = clampi(columns, 1, BROWSE_GRID_MAX_COLUMNS)


func _entry_button(entry: Dictionary, kind: String) -> Button:
	var button := Button.new()
	var browse_card := active_tab == "browse" and kind == "listing"
	button.custom_minimum_size = Vector2(
		BROWSE_CARD_MIN_WIDTH if browse_card else 0.0,
		82 if browse_card else 70,
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 46 if browse_card else 52)
	if browse_card:
		button.add_theme_font_size_override("font_size", 13)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.text = "%s\n%s" % [_entry_name(entry, kind), _entry_subtitle(entry, kind)]
	button.icon = _entry_texture(entry, kind)
	button.tooltip_text = _entry_name(entry, kind)
	button.pressed.connect(_select_entry.bind(entry, kind))
	_apply_button_style(button, _entry_matches_selection(entry, kind))
	return button


func _select_entry(entry: Dictionary, kind: String) -> void:
	selected_entry = entry.duplicate(true)
	selected_kind = kind
	# Render the detail immediately. Rebuilding the list is deferred so a button
	# press cannot leave the previous "select an asset" prompt on screen.
	_render_detail()
	call_deferred("_render_current_list")


func _render_detail() -> void:
	_clear_children(detail_stack)
	if selected_entry.is_empty():
		var prompt := Label.new()
		prompt.text = _t("ui.exchange.detail.select")
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		prompt.add_theme_color_override("font_color", UI_MUTED)
		detail_stack.add_child(prompt)
		return

	var asset := _entry_asset(selected_entry, selected_kind)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 132)
	icon.texture = _entry_texture(selected_entry, selected_kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_stack.add_child(icon)
	var name := Label.new()
	name.text = _entry_name(selected_entry, selected_kind)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", UI_TEXT)
	detail_stack.add_child(name)
	var description := Label.new()
	description.text = _asset_detail_text(asset, _entry_asset_type(selected_entry, selected_kind))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", UI_MUTED)
	detail_stack.add_child(description)

	if selected_kind == "sell":
		_build_sell_controls(asset)
	else:
		_build_listing_controls()


func _build_sell_controls(asset: Dictionary) -> void:
	var asset_type := _entry_asset_type(selected_entry, selected_kind)
	if asset_type == "item":
		quantity_spin = SpinBox.new()
		quantity_spin.min_value = 1
		quantity_spin.max_value = maxi(int(asset.get("quantity", 1)), 1)
		quantity_spin.value = 1
		quantity_spin.value_changed.connect(_update_sell_total)
		detail_stack.add_child(_labeled_control(_t("ui.exchange.quantity"), quantity_spin))
	else:
		quantity_spin = null
	price_spin = SpinBox.new()
	price_spin.min_value = 1
	price_spin.max_value = MAX_PRICE
	price_spin.value = 100
	price_spin.step = 1
	price_spin.value_changed.connect(_update_sell_total)
	detail_stack.add_child(_labeled_control(_t("ui.exchange.unit_price"), price_spin))
	total_price_label = Label.new()
	total_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_price_label.add_theme_font_size_override("font_size", 16)
	total_price_label.add_theme_color_override("font_color", UI_GOLD)
	detail_stack.add_child(total_price_label)
	var list_button := Button.new()
	list_button.custom_minimum_size = Vector2(0, 42)
	list_button.text = _t("ui.exchange.action.list")
	list_button.pressed.connect(_confirm_list_selected)
	_apply_primary_button_style(list_button)
	detail_stack.add_child(list_button)
	_update_sell_total(0)


func _build_listing_controls() -> void:
	var status := str(selected_entry.get("status", "active"))
	var price := Label.new()
	price.text = _t("ui.exchange.total", {"amount": _format_money(int(selected_entry.get("totalPrice", 0)))})
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 18)
	price.add_theme_color_override("font_color", UI_GOLD)
	detail_stack.add_child(price)
	var state := Label.new()
	state.text = _t("ui.exchange.state.%s" % status)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_color_override("font_color", UI_GREEN if status == "sold" else UI_MUTED)
	detail_stack.add_child(state)
	if status != "active":
		return
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 42)
	if active_tab == "mine" or bool(selected_entry.get("isMine", false)):
		action.text = _t("ui.exchange.action.cancel") if active_tab == "mine" else _t("ui.exchange.action.owned")
		action.disabled = active_tab != "mine"
		if active_tab == "mine":
			action.pressed.connect(_confirm_cancel_selected)
	else:
		action.text = _t("ui.exchange.action.buy")
		action.disabled = wallet_money < int(selected_entry.get("totalPrice", 0))
		action.pressed.connect(_confirm_buy_selected)
	_apply_primary_button_style(action)
	detail_stack.add_child(action)


func _confirm_list_selected() -> void:
	var quantity := int(quantity_spin.value) if quantity_spin != null else 1
	var unit_price := int(price_spin.value) if price_spin != null else 0
	var total := quantity * unit_price
	var request_id := _new_request_id("list")
	_show_confirmation(
		_t("ui.exchange.confirm.list_title"),
		_t("ui.exchange.confirm.list", {
			"name": _entry_name(selected_entry, selected_kind),
			"quantity": quantity,
			"amount": _format_money(total),
		}),
		Callable(self, "_list_selected").bind(quantity, unit_price, request_id)
	)


func _confirm_buy_selected() -> void:
	_show_confirmation(
		_t("ui.exchange.confirm.buy_title"),
		_t("ui.exchange.confirm.buy", {
			"name": _entry_name(selected_entry, selected_kind),
			"amount": _format_money(int(selected_entry.get("totalPrice", 0))),
		}),
		Callable(self, "_buy_selected").bind(str(selected_entry.get("id", "")), _new_request_id("buy"))
	)


func _confirm_cancel_selected() -> void:
	_show_confirmation(
		_t("ui.exchange.confirm.cancel_title"),
		_t("ui.exchange.confirm.cancel", {"name": _entry_name(selected_entry, selected_kind)}),
		Callable(self, "_cancel_selected").bind(str(selected_entry.get("id", "")), _new_request_id("cancel")),
		true
	)


func _show_confirmation(title: String, message: String, action: Callable, danger := false) -> void:
	confirmation_action = action
	confirmation_title_label.text = title
	confirmation_message_label.text = message
	confirmation_cancel_button.text = _t("common.cancel")
	confirmation_confirm_button.text = _t("common.confirm")
	if danger:
		_apply_danger_button_style(confirmation_confirm_button)
	else:
		_apply_primary_button_style(confirmation_confirm_button)
	confirmation_overlay.visible = true
	confirmation_confirm_button.grab_focus()


func _on_confirmation_cancelled() -> void:
	confirmation_action = Callable()
	confirmation_overlay.visible = false


func _on_confirmation_confirmed() -> void:
	var action := confirmation_action
	confirmation_action = Callable()
	confirmation_overlay.visible = false
	if action.is_valid():
		action.call()


func _unhandled_key_input(event: InputEvent) -> void:
	if confirmation_overlay == null or not confirmation_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_confirmation_cancelled()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_confirmation_confirmed()
			get_viewport().set_input_as_handled()


func _list_selected(quantity: int, unit_price: int, request_id: String) -> void:
	if request_busy:
		return
	request_busy = true
	_refresh_controls()
	_set_status(_t("ui.exchange.status.listing"), UI_MUTED)
	var asset_type := _entry_asset_type(selected_entry, selected_kind)
	var result: Dictionary
	var service := get_node_or_null("/root/AetherExchangeService")
	if service == null:
		await _finish_mutation({"success": false, "error": _t("ui.exchange.error.action")}, "ui.exchange.status.listed")
		return
	if asset_type == "item":
		result = await service.call("create_item_listing",
			str(selected_entry.get("itemId", "")), quantity, unit_price, request_id
		)
	else:
		result = await service.call("create_pokemon_listing",
			int(selected_entry.get("pokemonId", 0)), unit_price, request_id
		)
	await _finish_mutation(result, "ui.exchange.status.listed")


func _buy_selected(listing_id: String, request_id: String) -> void:
	if request_busy:
		return
	request_busy = true
	_refresh_controls()
	_set_status(_t("ui.exchange.status.buying"), UI_MUTED)
	var service := get_node_or_null("/root/AetherExchangeService")
	await _finish_mutation(
		await service.call("buy_listing", listing_id, request_id) if service != null else {"success": false, "error": _t("ui.exchange.error.action")},
		"ui.exchange.status.bought"
	)


func _cancel_selected(listing_id: String, request_id: String) -> void:
	if request_busy:
		return
	request_busy = true
	_refresh_controls()
	_set_status(_t("ui.exchange.status.cancelling"), UI_MUTED)
	var service := get_node_or_null("/root/AetherExchangeService")
	await _finish_mutation(
		await service.call("cancel_listing", listing_id, request_id) if service != null else {"success": false, "error": _t("ui.exchange.error.action")},
		"ui.exchange.status.cancelled"
	)


func _finish_mutation(result: Dictionary, success_key: String) -> void:
	if not bool(result.get("success", false)):
		request_busy = false
		_refresh_controls()
		_set_status(str(result.get("error", _t("ui.exchange.error.action"))), UI_DANGER)
		return
	var wallet := _dictionary(result.get("wallet", {}))
	wallet_money = maxi(int(wallet.get("money", wallet_money)), 0)
	var wallet_service := get_node_or_null("/root/PlayerWalletService")
	if wallet_service != null:
		wallet_service.call("apply_wallet_result", {"success": true, "wallet": wallet})
	wallet_changed.emit()
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service != null:
		await inventory_service.call("load_inventory")
	var party_loaded := true
	var listing := _dictionary(result.get("listing", {}))
	if _mutation_requires_party_refresh(listing, success_key):
		var party_service := get_node_or_null("/root/PlayerPartyStateService")
		var party_result: Dictionary = (
			await party_service.call("refresh_party")
			if party_service != null
			else {"success": false}
		)
		party_loaded = bool(party_result.get("success", false))
	var portfolio_loaded := await _load_portfolio()
	var browse_loaded := await _load_browse()
	request_busy = false
	selected_entry.clear()
	selected_kind = ""
	_render_current_list()
	_refresh_controls()
	if portfolio_loaded and browse_loaded and party_loaded:
		_set_status(_t(success_key), UI_GREEN)
	elif portfolio_loaded and browse_loaded and not party_loaded:
		_set_status(_t("ui.exchange.error.party_refresh"), UI_DANGER)


func _mutation_requires_party_refresh(listing: Dictionary, success_key: String) -> bool:
	return (
		str(listing.get("assetType", "")) == "pokemon"
		and success_key in ["ui.exchange.status.listed", "ui.exchange.status.cancelled"]
	)


func _refresh_controls() -> void:
	for key: Variant in tab_buttons:
		var button := tab_buttons[key] as Button
		button.text = _t("ui.exchange.tab.%s" % str(key))
		button.disabled = request_busy
		_apply_button_style(button, str(key) == active_tab)
	for key: Variant in filter_buttons:
		var button := filter_buttons[key] as Button
		var label_key := "all" if str(key).is_empty() else str(key)
		button.text = _t("ui.exchange.filter.%s" % label_key)
		button.disabled = request_busy
		_apply_button_style(button, str(key) == asset_filter)
	search_input.editable = not request_busy
	if refresh_button != null:
		refresh_button.text = _t("ui.exchange.refresh")
		refresh_button.disabled = request_busy
	_refresh_money()


func _translate_static_ui() -> void:
	title_label.text = _t("ui.exchange.title")
	subtitle_label.text = _t("ui.exchange.subtitle")
	search_input.placeholder_text = _t("ui.exchange.search")
	if confirmation_cancel_button != null:
		confirmation_cancel_button.text = _t("common.cancel")
	if confirmation_confirm_button != null:
		confirmation_confirm_button.text = _t("common.confirm")
	_refresh_controls()
	if list_container != null:
		_render_current_list()


func _on_locale_changed(_locale: String) -> void:
	_translate_static_ui()


func _refresh_money() -> void:
	if money_label != null:
		money_label.text = _t("ui.exchange.wallet", {"amount": _format_money(wallet_money)})


func _update_sell_total(_value: float) -> void:
	if total_price_label == null:
		return
	var quantity := int(quantity_spin.value) if quantity_spin != null else 1
	var unit_price := int(price_spin.value) if price_spin != null else 0
	total_price_label.text = _t("ui.exchange.total", {"amount": _format_money(quantity * unit_price)})


func _entry_name(entry: Dictionary, kind: String) -> String:
	var asset := _entry_asset(entry, kind)
	var asset_type := _entry_asset_type(entry, kind)
	if asset_type == "pokemon":
		var nickname := _optional_text(asset.get("nickname"))
		var species := _optional_text(asset.get("speciesName"))
		if species.is_empty():
			species = _optional_text(asset.get("speciesId"), _t("ui.exchange.pokemon"))
		return "%s (%s)" % [nickname, species] if not nickname.is_empty() else species
	return _optional_text(asset.get("name"), _optional_text(asset.get("itemId"), _t("ui.exchange.item")))


func _entry_subtitle(entry: Dictionary, kind: String) -> String:
	var asset := _entry_asset(entry, kind)
	if kind == "sell":
		if _entry_asset_type(entry, kind) == "pokemon":
			return _t("ui.exchange.pokemon_summary", {
				"level": int(asset.get("level", 1)),
				"nature": str(asset.get("nature", "—")),
			})
		return _t("ui.exchange.owned", {"quantity": int(asset.get("quantity", 1))})
	var status := str(entry.get("status", "active"))
	return "%s  •  %s" % [
		_t("ui.exchange.total", {"amount": _format_money(int(entry.get("totalPrice", 0)))}),
		_t("ui.exchange.state.%s" % status),
	]


func _entry_asset(entry: Dictionary, kind: String) -> Dictionary:
	return entry if kind == "sell" else _dictionary(entry.get("asset", {}))


func _entry_asset_type(entry: Dictionary, kind: String) -> String:
	if kind != "sell":
		return str(entry.get("assetType", "item"))
	return "pokemon" if entry.has("pokemonId") or entry.has("speciesId") or entry.has("speciesName") else "item"


func _asset_detail_text(asset: Dictionary, asset_type: String) -> String:
	if asset_type == "item":
		var description := str(asset.get("shortDesc", "")).strip_edges()
		return description if not description.is_empty() else _t("ui.exchange.item_description")
	var parts: Array[String] = [
		_t("ui.exchange.detail.level", {"value": int(asset.get("level", 1))}),
		_t("ui.exchange.detail.nature", {"value": str(asset.get("nature", "—"))}),
		_t("ui.exchange.detail.ability", {"value": str(asset.get("ability", "—"))}),
	]
	var ivs := _dictionary(asset.get("ivs", {}))
	if not ivs.is_empty():
		parts.append(_t("ui.exchange.detail.ivs", {"value": _iv_summary(ivs)}))
	if bool(asset.get("shiny", false)):
		parts.append(_t("ui.exchange.detail.shiny"))
	return "\n".join(parts)


func _entry_texture(entry: Dictionary, kind: String) -> Texture2D:
	var asset := _entry_asset(entry, kind)
	if _entry_asset_type(entry, kind) == "pokemon":
		var species := _optional_text(asset.get("formId"))
		if species.is_empty():
			species = _optional_text(asset.get("speciesName"), _optional_text(asset.get("speciesId")))
		return PokemonAssets.load_party_icon(species, bool(asset.get("shiny", false)))
	return _load_item_icon(str(asset.get("itemId", "")))


func _load_item_icon(item_id: String) -> Texture2D:
	var normalized := item_id.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	for path: String in [
		"res://assets/items/icons/%s.png" % normalized,
		"res://assets/items/icons/%s.png" % item_id.strip_edges(),
		"res://assets/items/icons/000.png",
	]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _list_caption(count: int) -> String:
	return _t("ui.exchange.catalog.%s" % active_tab, {"count": count})


func _selection_still_visible(entries: Array) -> bool:
	if selected_entry.is_empty():
		return false
	for value: Variant in entries:
		var entry := _dictionary(value)
		if _entry_selection_key(entry, selected_kind) == _entry_selection_key(selected_entry, selected_kind):
			return true
	return false


func _entry_matches_selection(entry: Dictionary, kind: String) -> bool:
	if selected_kind != kind:
		return false
	return _entry_selection_key(entry, kind) == _entry_selection_key(selected_entry, kind)


func _entry_selection_key(entry: Dictionary, kind: String) -> String:
	if kind != "sell":
		return "listing:%s" % _optional_text(entry.get("id"))
	if _entry_asset_type(entry, kind) == "pokemon":
		return "pokemon:%s" % _optional_text(entry.get("pokemonId"))
	return "item:%s" % _optional_text(entry.get("itemId"))


func _optional_text(value: Variant, fallback := "") -> String:
	if value == null:
		return fallback
	var text := str(value).strip_edges()
	return fallback if text.is_empty() or text == "<null>" else text


func _labeled_control(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)
	control.custom_minimum_size = Vector2(145, 36)
	row.add_child(control)
	return row


func _set_status(message: String, color: Color) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)


func _format_money(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result


func _iv_summary(ivs: Dictionary) -> String:
	return "%d / %d / %d / %d / %d / %d" % [
		int(ivs.get("hp", 0)), int(ivs.get("atk", 0)), int(ivs.get("def", 0)),
		int(ivs.get("spa", 0)), int(ivs.get("spd", 0)), int(ivs.get("spe", 0)),
	]


func _new_request_id(prefix: String) -> String:
	return "%s-%d-%d" % [prefix, Time.get_unix_time_from_system(), randi()]


func _apply_button_style(button: Button, selected := false) -> void:
	var bg := Color("#12324af5") if selected else UI_INTERACTIVE
	var border := UI_CYAN if selected else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#12324af5"), UI_CYAN, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#173e5af5"), UI_CYAN, 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED, 0.55))


func _apply_primary_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color("#15566df5"), UI_CYAN, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#1c6d87f5"), Color("#b8f6ff"), 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0f465bf5"), UI_CYAN, 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)


func _apply_danger_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color("#5a1e2bf5"), UI_DANGER, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#78283af5"), Color("#ff9aaa"), 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#451720f5"), UI_DANGER, 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()


func _t(key: String, values := {}) -> String:
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.call("text", key, values)) if localization != null else key


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value as Array if value is Array else []
