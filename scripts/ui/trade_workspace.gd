extends Window

class_name TradeWorkspaceNode

const MAX_OFFER_SIZE := 5
const TRADE_BG := Color("#050912fa")
const TRADE_SURFACE := Color("#0b1422f7")
const TRADE_SLOT := Color("#07101cf8")
const TRADE_BORDER := Color("#345170")
const TRADE_ACCENT := Color("#62d7ff")
const TRADE_GOLD := Color("#d8b767")
const TRADE_TEXT := Color("#f4f0de")
const TRADE_MUTED := Color("#aeb8c5")
const TRADE_READY := Color("#63df8b")

var trade: Dictionary = {}
var candidates: Array[Dictionary] = []
var selected_ids: Array[int] = []
var selected_item_offers: Array[Dictionary] = []
var selected_money := 0
var inventory_items: Array[Dictionary] = []
var local_offer_box: PanelContainer
var opponent_offer_box: PanelContainer
var local_offer_slots: Array[Control] = []
var opponent_offer_slots: Array[Control] = []
var local_item_offer_list: VBoxContainer
var opponent_item_offer_list: VBoxContainer
var item_selector_popup: PopupPanel
var item_selector_list: VBoxContainer
var item_selector_rows: Dictionary = {}
var item_selector_search: LineEdit
var item_selector_empty_label: Label
var add_items_button: Button
var money_amount_spinbox: SpinBox
var money_balance_label: Label
var update_money_button: Button
var local_money_offer_label: Label
var opponent_money_offer_label: Label
var local_ready_indicator: Label
var opponent_ready_indicator: Label
var phase_label: Label
var status_label: Label
var ready_button: Button
var edit_button: Button
var editable_root: VBoxContainer
var review_root: VBoxContainer
var review_give_list: VBoxContainer
var review_receive_list: VBoxContainer
var review_trust_label: Label
var confirm_button: Button
var confirmation_label: Label
var mutation_in_flight := false
var party_drag_preview: TextureRect
var window_dragging := false
var notified_completed_trade_ids: Dictionary = {}


func _ready() -> void:
	hide()
	title = "Player Trade"
	min_size = Vector2i(1060, 610)
	unresizable = true
	borderless = true
	_build_ui()
	close_requested.connect(_on_close_requested)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.active_trade_changed.connect(_on_trade_changed)
		if not realtime.active_trade_snapshot.is_empty():
			_on_trade_changed(realtime.active_trade_snapshot)


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _panel_style(TRADE_BG, TRADE_GOLD, 8, 1))
	add_child(background)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_window_header_gui_input)
	root.add_child(header)
	var heading_stack := VBoxContainer.new()
	heading_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_stack.add_theme_constant_override("separation", 2)
	header.add_child(heading_stack)
	var eyebrow := Label.new()
	eyebrow.text = "PLAYER EXCHANGE"
	eyebrow.add_theme_color_override("font_color", TRADE_GOLD)
	eyebrow.add_theme_font_size_override("font_size", 12)
	heading_stack.add_child(eyebrow)
	var heading := Label.new()
	heading.text = "Player Trade"
	heading.add_theme_color_override("font_color", TRADE_TEXT)
	heading.add_theme_font_size_override("font_size", 26)
	heading_stack.add_child(heading)
	phase_label = Label.new()
	phase_label.text = "OFFER SETUP"
	phase_label.add_theme_color_override("font_color", TRADE_ACCENT)
	phase_label.add_theme_font_size_override("font_size", 13)
	header.add_child(phase_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close trade"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.add_theme_color_override("font_color", TRADE_MUTED)
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color("#00000000"), Color("#00000000"), 4, 0))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color("#2a1015"), Color("#b84c58"), 4, 1))
	close_button.pressed.connect(_on_close_requested)
	header.add_child(close_button)
	var separator := HSeparator.new()
	root.add_child(separator)
	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size.y = 42
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color("#091827e8"), TRADE_BORDER, 5, 1))
	root.add_child(status_panel)
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_top", 9)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_bottom", 9)
	status_panel.add_child(status_margin)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", TRADE_MUTED)
	status_margin.add_child(status_label)
	editable_root = VBoxContainer.new()
	editable_root.add_theme_constant_override("separation", 14)
	editable_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editable_root)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editable_root.add_child(columns)
	local_offer_box = _offer_section(columns, "Your Offer", local_offer_slots)
	opponent_offer_box = _offer_section(columns, "Other Player's Offer", opponent_offer_slots)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	editable_root.add_child(actions)
	var money_label := Label.new()
	money_label.text = "Money"
	money_label.add_theme_color_override("font_color", TRADE_MUTED)
	actions.add_child(money_label)
	money_amount_spinbox = SpinBox.new()
	money_amount_spinbox.min_value = 0
	money_amount_spinbox.max_value = 2147483647
	money_amount_spinbox.step = 1
	money_amount_spinbox.update_on_text_changed = true
	money_amount_spinbox.custom_minimum_size.x = 130
	actions.add_child(money_amount_spinbox)
	update_money_button = Button.new()
	update_money_button.text = "Set Money"
	update_money_button.pressed.connect(_update_money_offer)
	_apply_button_style(update_money_button, "secondary")
	actions.add_child(update_money_button)
	money_balance_label = Label.new()
	money_balance_label.text = "Available: $0"
	money_balance_label.add_theme_color_override("font_color", TRADE_GOLD)
	actions.add_child(money_balance_label)
	add_items_button = Button.new()
	add_items_button.text = "Add Items"
	add_items_button.pressed.connect(_open_item_selector)
	_apply_button_style(add_items_button, "secondary")
	actions.add_child(add_items_button)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	ready_button = Button.new()
	ready_button.text = "Ready"
	ready_button.pressed.connect(_set_ready.bind(true))
	_apply_button_style(ready_button, "primary")
	actions.add_child(ready_button)
	edit_button = Button.new()
	edit_button.text = "Edit Offer"
	edit_button.pressed.connect(_set_ready.bind(false))
	_apply_button_style(edit_button, "secondary")
	actions.add_child(edit_button)
	review_root = VBoxContainer.new()
	review_root.add_theme_constant_override("separation", 12)
	review_root.visible = false
	review_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(review_root)
	review_trust_label = Label.new()
	review_trust_label.add_theme_color_override("font_color", TRADE_GOLD)
	review_root.add_child(review_trust_label)
	var review_columns := HBoxContainer.new()
	review_columns.add_theme_constant_override("separation", 16)
	review_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_root.add_child(review_columns)
	review_give_list = _section(review_columns, "You give")
	review_receive_list = _section(review_columns, "You receive")
	confirmation_label = Label.new()
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_label.add_theme_color_override("font_color", TRADE_MUTED)
	review_root.add_child(confirmation_label)
	confirm_button = Button.new()
	confirm_button.text = "Confirm Trade"
	confirm_button.pressed.connect(_confirm_trade)
	_apply_button_style(confirm_button, "primary")
	review_root.add_child(confirm_button)
	_build_item_selector()


func _on_window_header_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	window_dragging = mouse_event.pressed
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not window_dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			window_dragging = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		position += Vector2i(roundi(motion.relative.x), roundi(motion.relative.y))
		_clamp_window_position()
		get_viewport().set_input_as_handled()


func _clamp_window_position() -> void:
	var available := get_tree().root.size
	position.x = clampi(position.x, 0, maxi(available.x - size.x, 0))
	position.y = clampi(position.y, 0, maxi(available.y - size.y, 0))
func _process(_delta: float) -> void:
	if visible and str(trade.get("status", "")) in ["active", "locked"]:
		_render_connection_status()


func _section(parent: Control, label_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(235, 0)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", TRADE_TEXT)
	section.add_child(label)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE, TRADE_BORDER, 6, 1))
	section.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _offer_section(parent: Control, label_text: String, slots: Array[Control]) -> PanelContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(490, 330)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	section.add_child(header)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", TRADE_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var ready_indicator := Label.new()
	ready_indicator.text = "READY"
	ready_indicator.visible = false
	ready_indicator.add_theme_color_override("font_color", TRADE_READY)
	ready_indicator.add_theme_font_size_override("font_size", 14)
	header.add_child(ready_indicator)
	if label_text == "Your Offer":
		local_ready_indicator = ready_indicator
	else:
		opponent_ready_indicator = ready_indicator
	var money_offer_label := Label.new()
	money_offer_label.visible = false
	money_offer_label.add_theme_color_override("font_color", TRADE_GOLD)
	money_offer_label.add_theme_font_size_override("font_size", 14)
	header.add_child(money_offer_label)
	if label_text == "Your Offer":
		local_money_offer_label = money_offer_label
	else:
		opponent_money_offer_label = money_offer_label
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = TRADE_SURFACE
	panel_style.border_color = TRADE_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.shadow_color = Color("#00000066")
	panel_style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	section.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var grid := GridContainer.new()
	grid.columns = MAX_OFFER_SIZE
	grid.add_theme_constant_override("h_separation", 10)
	content.add_child(grid)
	for index in range(MAX_OFFER_SIZE):
		var slot := _create_offer_slot()
		slots.append(slot)
		grid.add_child(slot)
	var item_separator := HSeparator.new()
	content.add_child(item_separator)
	var item_scroll := ScrollContainer.new()
	item_scroll.custom_minimum_size.y = 96
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(item_scroll)
	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 5)
	item_scroll.add_child(item_list)
	if label_text == "Your Offer":
		local_item_offer_list = item_list
	else:
		opponent_item_offer_list = item_list
	return panel


func _build_item_selector() -> void:
	item_selector_popup = PopupPanel.new()
	item_selector_popup.size = Vector2i(640, 560)
	item_selector_popup.add_theme_stylebox_override("panel", _panel_style(TRADE_BG, TRADE_GOLD, 7, 1))
	add_child(item_selector_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	item_selector_popup.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var heading := Label.new()
	heading.text = "Choose Item Stacks"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", TRADE_TEXT)
	root.add_child(heading)
	var help := Label.new()
	help.text = "Search your inventory, select stacks, and set each offered quantity."
	help.add_theme_color_override("font_color", TRADE_MUTED)
	root.add_child(help)
	item_selector_search = LineEdit.new()
	item_selector_search.placeholder_text = "Search items"
	item_selector_search.clear_button_enabled = true
	item_selector_search.add_theme_color_override("font_color", TRADE_TEXT)
	item_selector_search.add_theme_color_override("font_placeholder_color", TRADE_MUTED)
	item_selector_search.add_theme_stylebox_override("normal", _panel_style(TRADE_SLOT, TRADE_BORDER, 5, 1))
	item_selector_search.add_theme_stylebox_override("focus", _panel_style(TRADE_SLOT, TRADE_ACCENT, 5, 1))
	item_selector_search.text_changed.connect(_filter_item_selector_rows)
	root.add_child(item_selector_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	item_selector_list = VBoxContainer.new()
	item_selector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_selector_list.add_theme_constant_override("separation", 6)
	scroll.add_child(item_selector_list)
	item_selector_empty_label = Label.new()
	item_selector_empty_label.text = "No matching tradable items."
	item_selector_empty_label.add_theme_color_override("font_color", TRADE_MUTED)
	item_selector_empty_label.visible = false
	item_selector_list.add_child(item_selector_empty_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(item_selector_popup.hide)
	_apply_button_style(cancel, "secondary")
	actions.add_child(cancel)
	var apply := Button.new()
	apply.text = "Update Offer"
	apply.pressed.connect(_apply_item_selection)
	_apply_button_style(apply, "primary")
	actions.add_child(apply)


func _create_offer_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(82, 118)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = TRADE_SLOT
	style.border_color = TRADE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 5, 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _apply_button_style(button: Button, kind: String) -> void:
	var primary := kind == "primary"
	var normal_bg := Color("#0d4359") if primary else Color("#111d2c")
	var hover_bg := Color("#12627f") if primary else Color("#192c42")
	var border := TRADE_ACCENT if primary else TRADE_BORDER
	button.add_theme_color_override("font_color", TRADE_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#667382"))
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, TRADE_ACCENT))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#081a27"), TRADE_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(hover_bg, TRADE_GOLD))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#0a1018"), Color("#253344")))


func _on_trade_changed(value: Dictionary) -> void:
	var status := str(value.get("status", ""))
	var refresh_candidates := status == "active" and _trade_snapshot_changed(value)
	if status == "cancelled":
		trade = value.duplicate(true)
		phase_label.text = "CANCELLED"
		editable_root.visible = false
		review_root.visible = false
		if str(trade.get("cancellationReason", "")) == "reconnect_timeout":
			status_label.text = "Trade cancelled because reconnect time expired."
			popup_centered()
		else:
			hide()
		return
	if status == "completed":
		trade = value.duplicate(true)
		_notify_trade_completion(trade)
		hide()
		refresh_after_completion.call_deferred()
		return
	if status not in ["active", "locked"]:
		if visible:
			hide()
		return
	trade = value.duplicate(true)
	_sync_selected_from_offer()
	_render_offers()
	_render_mode()
	popup_centered()
	if refresh_candidates:
		refresh_available_pokemon.call_deferred()
		refresh_available_money.call_deferred()


func refresh_available_pokemon() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		_show_error("Your party is unavailable.")
		return
	var party_result: Dictionary = await party_service.load_party()
	if not bool(party_result.get("success", false)):
		_show_error("Could not refresh your party.")
		return
	candidates = collect_candidates(party_result.get("party", []))
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null:
		_show_error("Your inventory is unavailable.")
		return
	var inventory_result: Dictionary = await inventory_service.load_inventory()
	if not bool(inventory_result.get("success", false)):
		_show_error("Could not refresh your inventory.")
		return
	inventory_items = normalize_inventory_candidates(inventory_result.get("items", []))


static func normalize_inventory_candidates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item_value: Variant in value:
		if not item_value is Dictionary:
			continue
		var item_id := str(item_value.get("itemId", "")).strip_edges().to_lower().replace("_", "-").replace(" ", "-")
		var category := str(item_value.get("category", "")).strip_edges().to_lower()
		var quantity := int(item_value.get("quantity", 0))
		if item_id == "" or quantity <= 0 or category in ["key-items", "key_items", "important"]:
			continue
		result.append({"itemId":item_id, "name":str(item_value.get("name", item_id)), "category":category, "quantity":quantity})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return result


func _trade_snapshot_changed(value: Dictionary) -> bool:
	return str(trade.get("tradeId", "")) != str(value.get("tradeId", "")) \
		or int(trade.get("revision", 0)) != int(value.get("revision", 0)) \
		or int(trade.get("lastEventSeq", 0)) != int(value.get("lastEventSeq", 0))


static func collect_candidates(party_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	if party_value is Array:
		for index in range(party_value.size()):
			_add_candidate(result, seen, party_value[index], {"type":"party", "partySlot":index})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("pokemonId", 0)) < int(b.get("pokemonId", 0)))
	return result


static func _add_candidate(result: Array[Dictionary], seen: Dictionary, value: Variant, location: Dictionary) -> void:
	if not value is Dictionary:
		return
	var payload: Dictionary = value.get("pokemon", value)
	var pokemon_id := int(value.get("id", value.get("pokemonId", payload.get("ownedPokemonId", payload.get("pokemonId", 0)))))
	if pokemon_id <= 0 or seen.has(pokemon_id):
		return
	seen[pokemon_id] = true
	result.append({"pokemonId":pokemon_id, "pokemon":payload.duplicate(true), "location":location.duplicate(true)})


func _replace_offer(pokemon_ids: Array[int], item_offers: Array[Dictionary] = [], money_offer := -1) -> void:
	var resolved_money := selected_money if money_offer < 0 else int(money_offer)
	if mutation_in_flight or (pokemon_ids.is_empty() and item_offers.is_empty() and resolved_money == 0) or _local_participant_ready() or str(trade.get("status", "")) == "locked" or _connection_state_unresolved():
		return
	mutation_in_flight = true
	_render_offers()
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	var trade_id := str(trade.get("tradeId", ""))
	if service == null:
		result = {"success":false, "error":"Trade service unavailable."}
	else:
		result = await service.replace_offer(trade_id, int(trade.get("revision", 0)), pokemon_ids, "", item_offers, resolved_money)
		if _is_stale_revision_error(result):
			result = await _retry_offer_after_stale_revision(service, trade_id, pokemon_ids, item_offers, resolved_money)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		_render_offers()
		return
	trade = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(trade)
	await refresh_available_pokemon()


func _retry_offer_after_stale_revision(service: Node, trade_id: String, pokemon_ids: Array[int], item_offers: Array[Dictionary], money_offer: int) -> Dictionary:
	var refresh: Dictionary = await service.load_trade(trade_id)
	if not bool(refresh.get("success", false)):
		return refresh
	var latest: Dictionary = refresh.get("trade", {}).duplicate(true)
	if str(latest.get("tradeId", "")) != trade_id or str(latest.get("status", "")) != "active":
		return {"success":false, "error":"The trade is no longer editable."}
	trade = latest
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(latest)
	if _local_participant_ready() or _connection_state_unresolved():
		return {"success":false, "error":"The trade changed and is not ready for offer updates."}
	return await service.replace_offer(trade_id, int(latest.get("revision", 0)), pokemon_ids, "", item_offers, money_offer)


static func _is_stale_revision_error(result: Dictionary) -> bool:
	if bool(result.get("success", false)) or int(result.get("status", 0)) != 409:
		return false
	var body: Dictionary = result.get("body", {}) if result.get("body", {}) is Dictionary else {}
	var detail: Variant = body.get("detail", "")
	if detail is Dictionary:
		return str(detail.get("code", "")) == "stale_trade_revision" or str(detail.get("message", "")).to_lower() == "stale trade revision"
	return str(detail).to_lower() == "stale trade revision" or str(result.get("error", "")).to_lower() == "stale trade revision"


func _set_ready(ready: bool) -> void:
	if mutation_in_flight or _connection_state_unresolved():
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false, "error":"Trade service unavailable."}
	else:
		result = await service.set_readiness(str(trade.get("tradeId", "")), int(trade.get("revision", 0)), ready)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		return
	trade = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(trade)
	_render_mode()


func _sync_selected_from_offer() -> void:
	selected_ids.clear()
	selected_item_offers.clear()
	selected_money = 0
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and int(offer_value.get("userId", 0)) == user_id:
			selected_money = maxi(int(offer_value.get("money", 0)), 0)
			for pokemon_value: Variant in offer_value.get("pokemon", []):
				if pokemon_value is Dictionary:
					selected_ids.append(int(pokemon_value.get("pokemonId", 0)))
			for item_value: Variant in offer_value.get("items", []):
				if item_value is Dictionary:
					selected_item_offers.append({"itemId":str(item_value.get("itemId", "")), "quantity":int(item_value.get("quantity", 0))})
	if money_amount_spinbox != null:
		money_amount_spinbox.value = selected_money


func _render_offers() -> void:
	_clear_offer_slots(local_offer_slots)
	_clear_offer_slots(opponent_offer_slots)
	_clear(local_item_offer_list)
	_clear(opponent_item_offer_list)
	local_money_offer_label.visible = false
	opponent_money_offer_label.visible = false
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if not offer_value is Dictionary:
			continue
		var is_local := int(offer_value.get("userId", 0)) == user_id
		var target := local_offer_slots if is_local else opponent_offer_slots
		var pokemon_values: Array = offer_value.get("pokemon", []) if offer_value.get("pokemon", []) is Array else []
		for index in range(mini(pokemon_values.size(), MAX_OFFER_SIZE)):
			if pokemon_values[index] is Dictionary:
				_render_offer_slot(target[index], pokemon_values[index], is_local, index)
		var item_values: Array = offer_value.get("items", []) if offer_value.get("items", []) is Array else []
		var item_target := local_item_offer_list if is_local else opponent_item_offer_list
		for index in range(item_values.size()):
			if item_values[index] is Dictionary:
				_render_item_offer(item_target, item_values[index], is_local, index)
		var money := maxi(int(offer_value.get("money", 0)), 0)
		if money > 0:
			var money_label := local_money_offer_label if is_local else opponent_money_offer_label
			money_label.text = "MONEY  $%s" % format_money(money)
			money_label.visible = true
			_render_money_offer(item_target, money, is_local)


func _render_money_offer(target: VBoxContainer, amount: int, is_local: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32
	target.add_child(row)
	var label := Label.new()
	label.text = "$%s" % format_money(amount)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TRADE_GOLD)
	row.add_child(label)
	var kind := Label.new()
	kind.text = "Money"
	kind.add_theme_color_override("font_color", TRADE_MUTED)
	row.add_child(kind)
	if is_local and _local_offer_asset_count() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove := Button.new()
		remove.text = "X"
		remove.tooltip_text = "Remove money from offer"
		remove.pressed.connect(_replace_offer.bind(selected_ids.duplicate(), selected_item_offers.duplicate(true), 0))
		row.add_child(remove)


func _render_item_offer(target: VBoxContainer, item: Dictionary, is_local: bool, position: int) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 32
	row.add_theme_constant_override("separation", 8)
	target.add_child(row)
	var name_label := Label.new()
	name_label.text = "%dx %s" % [int(item.get("quantity", 0)), str(item.get("name", item.get("itemId", "Item")))]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", TRADE_TEXT)
	row.add_child(name_label)
	var category_label := Label.new()
	category_label.text = str(item.get("category", "")).replace("-", " ").capitalize()
	category_label.add_theme_color_override("font_color", TRADE_MUTED)
	row.add_child(category_label)
	if is_local and _local_offer_asset_count() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove := Button.new()
		remove.text = "X"
		remove.tooltip_text = "Remove item stack from offer"
		remove.focus_mode = Control.FOCUS_NONE
		remove.pressed.connect(_remove_item_offer_position.bind(position))
		row.add_child(remove)


func _open_item_selector() -> void:
	if mutation_in_flight or _local_participant_ready() or str(trade.get("status", "")) != "active":
		return
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null:
		_show_error("Your inventory is unavailable.")
		return
	var result: Dictionary = await inventory_service.load_inventory()
	if not bool(result.get("success", false)):
		_show_error("Could not refresh your inventory.")
		return
	inventory_items = normalize_inventory_candidates(result.get("items", []))
	item_selector_search.text = ""
	_rebuild_item_selector_rows()
	item_selector_popup.popup_centered(Vector2i(640, 560))
	item_selector_search.grab_focus()


func refresh_available_money() -> void:
	var wallet_service := get_node_or_null("/root/PlayerWalletService")
	if wallet_service == null:
		return
	var result: Dictionary = await wallet_service.load_wallet()
	if not bool(result.get("success", false)):
		return
	var wallet: Dictionary = result.get("wallet", {}) if result.get("wallet", {}) is Dictionary else {}
	var balance := maxi(int(wallet.get("money", 0)), 0)
	wallet_service.apply_wallet_result(result)
	if money_amount_spinbox != null:
		money_amount_spinbox.max_value = maxi(balance, selected_money)
		money_amount_spinbox.value = mini(selected_money, int(money_amount_spinbox.max_value))
	if money_balance_label != null:
		money_balance_label.text = "Available: $%s" % format_money(balance)


func _update_money_offer() -> void:
	if money_amount_spinbox == null:
		return
	var amount := maxi(int(money_amount_spinbox.value), 0)
	if amount == 0 and selected_ids.is_empty() and selected_item_offers.is_empty():
		_show_error("Offer at least one Pokemon, item, or money.")
		return
	_replace_offer(selected_ids.duplicate(), selected_item_offers.duplicate(true), amount)


func _rebuild_item_selector_rows() -> void:
	_clear(item_selector_list)
	item_selector_rows.clear()
	item_selector_empty_label = Label.new()
	item_selector_empty_label.text = "No matching tradable items."
	item_selector_empty_label.add_theme_color_override("font_color", TRADE_MUTED)
	item_selector_empty_label.visible = false
	item_selector_list.add_child(item_selector_empty_label)
	var selected_by_id: Dictionary = {}
	for selected: Dictionary in selected_item_offers:
		selected_by_id[str(selected.get("itemId", ""))] = int(selected.get("quantity", 1))
	if inventory_items.is_empty():
		var empty := Label.new()
		empty.text = "No tradable inventory items are available."
		empty.add_theme_color_override("font_color", TRADE_MUTED)
		item_selector_list.add_child(empty)
		return
	for item: Dictionary in inventory_items:
		var item_id := str(item.get("itemId", ""))
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE, TRADE_BORDER, 5, 1))
		item_selector_list.add_child(row_panel)
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 10)
		row_margin.add_theme_constant_override("margin_top", 7)
		row_margin.add_theme_constant_override("margin_right", 10)
		row_margin.add_theme_constant_override("margin_bottom", 7)
		row_panel.add_child(row_margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_margin.add_child(row)
		var enabled := CheckBox.new()
		enabled.button_pressed = selected_by_id.has(item_id)
		enabled.focus_mode = Control.FOCUS_NONE
		row.add_child(enabled)
		var label := Label.new()
		label.text = "%s  (owned: %d)" % [str(item.get("name", item_id)), int(item.get("quantity", 0))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", TRADE_TEXT)
		row.add_child(label)
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = mini(int(item.get("quantity", 1)), 999)
		quantity.step = 1
		quantity.value = clampi(int(selected_by_id.get(item_id, 1)), 1, int(quantity.max_value))
		quantity.custom_minimum_size.x = 90
		row.add_child(quantity)
		item_selector_rows[item_id] = {"enabled":enabled, "quantity":quantity, "row":row_panel, "searchText":("%s %s %s" % [item.get("name", ""), item_id, item.get("category", "")]).to_lower()}
	_filter_item_selector_rows(item_selector_search.text)


func _filter_item_selector_rows(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	var visible_count := 0
	for controls_value: Variant in item_selector_rows.values():
		if not controls_value is Dictionary:
			continue
		var controls: Dictionary = controls_value
		var row := controls.get("row") as Control
		if row == null:
			continue
		row.visible = item_matches_search(str(controls.get("searchText", "")), normalized)
		if row.visible:
			visible_count += 1
	if item_selector_empty_label != null:
		item_selector_empty_label.visible = visible_count == 0


static func item_matches_search(search_text: String, query: String) -> bool:
	var normalized := query.strip_edges().to_lower()
	return normalized == "" or search_text.to_lower().contains(normalized)


func _apply_item_selection() -> void:
	var replacement: Array[Dictionary] = []
	for item: Dictionary in inventory_items:
		var item_id := str(item.get("itemId", ""))
		var controls: Dictionary = item_selector_rows.get(item_id, {})
		var enabled := controls.get("enabled") as CheckBox
		var quantity := controls.get("quantity") as SpinBox
		if enabled != null and enabled.button_pressed and quantity != null:
			replacement.append({"itemId":item_id, "quantity":int(quantity.value)})
	if replacement.is_empty() and selected_ids.is_empty():
		_show_error("Offer at least one Pokemon or item.")
		return
	item_selector_popup.hide()
	_replace_offer(selected_ids.duplicate(), replacement)


func _remove_item_offer_position(position: int) -> void:
	if _local_offer_asset_count() <= 1 or position < 0 or position >= selected_item_offers.size():
		return
	var replacement := selected_item_offers.duplicate(true)
	replacement.remove_at(position)
	_replace_offer(selected_ids.duplicate(), replacement)


func _local_offer_asset_count() -> int:
	return selected_ids.size() + selected_item_offers.size() + (1 if selected_money > 0 else 0)


func _clear_offer_slots(slots: Array[Control]) -> void:
	for slot in slots:
		_clear(slot)


func _render_offer_slot(slot: Control, pokemon: Dictionary, is_local: bool, position: int) -> void:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(wrapper)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_top = 5
	content.offset_right = -5
	content.offset_bottom = -5
	wrapper.add_child(content)
	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(70, 64)
	icon_button.icon = PokemonAssets.load_party_icon(_pokemon_species(pokemon), bool(pokemon.get("shiny", false)))
	icon_button.expand_icon = true
	icon_button.add_theme_constant_override("icon_max_width", 58)
	icon_button.flat = true
	icon_button.focus_mode = Control.FOCUS_NONE
	icon_button.add_theme_stylebox_override("normal", _panel_style(Color("#00000000"), Color("#00000000"), 4, 0))
	icon_button.add_theme_stylebox_override("hover", _panel_style(Color("#62d7ff12"), TRADE_ACCENT, 4, 1))
	icon_button.add_theme_stylebox_override("pressed", _panel_style(Color("#62d7ff20"), TRADE_ACCENT, 4, 1))
	icon_button.tooltip_text = "%s\nOpen Pokemon summary" % _pokemon_label(pokemon)
	icon_button.pressed.connect(_open_offer_summary.bind(pokemon, is_local))
	content.add_child(icon_button)
	var name_label := Label.new()
	name_label.text = _pokemon_name(pokemon)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", TRADE_TEXT)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.custom_minimum_size.x = 70
	content.add_child(name_label)
	var level_label := Label.new()
	level_label.text = "Lv. %d" % maxi(int(pokemon.get("level", 1)), 1)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", TRADE_MUTED)
	level_label.add_theme_font_size_override("font_size", 11)
	content.add_child(level_label)
	if is_local and _local_offer_asset_count() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove_button := Button.new()
		remove_button.text = "X"
		remove_button.tooltip_text = "Remove from offer"
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.custom_minimum_size = Vector2(22, 22)
		remove_button.anchor_left = 1.0
		remove_button.anchor_right = 1.0
		remove_button.offset_left = -25
		remove_button.offset_top = 3
		remove_button.offset_right = -3
		remove_button.offset_bottom = 25
		remove_button.add_theme_color_override("font_color", Color("#ffc6ca"))
		remove_button.add_theme_font_size_override("font_size", 11)
		remove_button.add_theme_stylebox_override("normal", _panel_style(Color("#2a1015e8"), Color("#7d3540"), 4, 1))
		remove_button.add_theme_stylebox_override("hover", _panel_style(Color("#6a1f2af2"), Color("#ff6b74"), 4, 1))
		remove_button.pressed.connect(_remove_offer_position.bind(position))
		wrapper.add_child(remove_button)


func _open_offer_summary(pokemon: Dictionary, is_local: bool) -> void:
	var payload := pokemon.duplicate(true)
	if is_local:
		var candidate := _candidate_by_id(int(pokemon.get("pokemonId", 0)))
		if not candidate.is_empty():
			payload = candidate.get("pokemon", {}).duplicate(true)
	payload = normalize_summary_payload(payload)
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("open_trade_pokemon_summary"):
		overlay.call("open_trade_pokemon_summary", payload)


func _remove_offer_position(position: int) -> void:
	if _local_offer_asset_count() <= 1 or position < 0 or position >= selected_ids.size():
		return
	var replacement := selected_ids.duplicate()
	replacement.remove_at(position)
	_replace_offer(replacement, selected_item_offers)


func try_offer_party_drop(global_position: Vector2, party_slot: int) -> bool:
	var workspace_position := _main_to_workspace_position(global_position)
	if not visible or local_offer_box == null or not local_offer_box.get_global_rect().has_point(workspace_position):
		return false
	if party_slot < 0 or party_slot >= 6 or mutation_in_flight or _local_participant_ready() or _connection_state_unresolved() or str(trade.get("status", "")) != "active":
		return true
	var candidate := _candidate_by_party_slot(party_slot)
	if candidate.is_empty():
		_show_error("That party Pokemon is unavailable. Refresh your party.")
		return true
	var pokemon_id := int(candidate.get("pokemonId", 0))
	var target_position := _offer_slot_at_position(workspace_position)
	var replacement := build_drop_replacement(selected_ids, pokemon_id, target_position, _offer_limit())
	if replacement == selected_ids:
		if pokemon_id not in selected_ids and selected_ids.size() >= _offer_limit():
			_show_error("The other player does not have enough free party slots.")
		return true
	_replace_offer(replacement, selected_item_offers)
	return true


func begin_party_offer_drag(pokemon_payload: Dictionary) -> bool:
	if not visible or str(trade.get("status", "")) != "active":
		return false
	end_party_offer_drag()
	party_drag_preview = TextureRect.new()
	party_drag_preview.custom_minimum_size = Vector2(58, 58)
	party_drag_preview.size = Vector2(58, 58)
	party_drag_preview.texture = PokemonAssets.load_party_icon(_pokemon_species(pokemon_payload), bool(pokemon_payload.get("shiny", false)))
	party_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	party_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	party_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	party_drag_preview.z_index = 1000
	add_child(party_drag_preview)
	update_party_offer_drag(DisplayServer.mouse_get_position())
	return true


func update_party_offer_drag(global_position: Vector2) -> void:
	if party_drag_preview == null:
		return
	party_drag_preview.position = _main_to_workspace_position(global_position) - party_drag_preview.size * 0.5


func end_party_offer_drag() -> void:
	if party_drag_preview != null:
		party_drag_preview.queue_free()
	party_drag_preview = null


func _main_to_workspace_position(global_position: Vector2) -> Vector2:
	if get_viewport() == get_tree().root:
		return global_position
	return global_position - Vector2(position)


static func build_drop_replacement(current_ids: Array[int], pokemon_id: int, target_position: int, limit: int) -> Array[int]:
	var result := current_ids.duplicate()
	if pokemon_id <= 0 or pokemon_id in result:
		return result
	if target_position >= 0 and target_position < result.size():
		result[target_position] = pokemon_id
	elif result.size() < clampi(limit, 0, MAX_OFFER_SIZE):
		result.append(pokemon_id)
	return result


func _offer_slot_at_position(global_position: Vector2) -> int:
	for index in range(local_offer_slots.size()):
		if local_offer_slots[index].get_global_rect().has_point(global_position):
			return index
	return -1


func _candidate_by_party_slot(party_slot: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("location", {}).get("partySlot", -1)) == party_slot:
			return candidate
	return {}


func _candidate_by_id(pokemon_id: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("pokemonId", 0)) == pokemon_id:
			return candidate
	return {}


static func normalize_summary_payload(value: Dictionary) -> Dictionary:
	var payload := value.duplicate(true)
	if str(payload.get("species", "")).strip_edges() == "":
		payload["species"] = str(payload.get("speciesId", payload.get("speciesName", "")))
	if not payload.has("ownedPokemonId") and payload.has("pokemonId"):
		payload["ownedPokemonId"] = int(payload.get("pokemonId", 0))
	return payload


func _render_mode() -> void:
	var locked := str(trade.get("status", "")) == "locked"
	phase_label.text = "FINAL REVIEW" if locked else "OFFER SETUP"
	editable_root.visible = not locked
	review_root.visible = locked
	if locked:
		_render_locked_review()
		return
	var local_ready := _local_participant_ready()
	local_ready_indicator.visible = local_ready
	opponent_ready_indicator.visible = _opponent_participant_ready()
	var blocked := _connection_state_unresolved()
	ready_button.visible = not local_ready
	ready_button.disabled = mutation_in_flight or not _local_offer_nonempty() or blocked
	add_items_button.disabled = mutation_in_flight or local_ready or blocked
	update_money_button.disabled = mutation_in_flight or local_ready or blocked
	money_amount_spinbox.editable = not mutation_in_flight and not local_ready and not blocked
	edit_button.visible = local_ready
	edit_button.disabled = mutation_in_flight or blocked
	if local_ready:
		status_label.text = "Your offer is ready and cannot be edited."
	elif _opponent_receive_capacity() <= 0 and selected_item_offers.is_empty() and selected_money == 0:
		status_label.text = "The other player needs a free party slot before you can offer a Pokemon."
	elif not _local_offer_nonempty():
		status_label.text = "Offer at least one Pokemon, item, or money before becoming Ready."
	else:
		status_label.text = ""


func _render_locked_review() -> void:
	_clear(review_give_list)
	_clear(review_receive_list)
	var review: Dictionary = trade.get("lockedReview", {}) if trade.get("lockedReview", {}) is Dictionary else {}
	var snapshot: Dictionary = review.get("snapshot", {}) if review.get("snapshot", {}) is Dictionary else {}
	var user_id := _current_user_id()
	for participant_value: Variant in snapshot.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			_add_review_pokemon(review_give_list, participant_value.get("gives", []))
			_add_review_pokemon(review_receive_list, participant_value.get("receives", []))
			_add_review_items(review_give_list, participant_value.get("givesItems", []))
			_add_review_items(review_receive_list, participant_value.get("receivesItems", []))
			_add_review_money(review_give_list, int(participant_value.get("givesMoney", 0)))
			_add_review_money(review_receive_list, int(participant_value.get("receivesMoney", 0)))
	review_trust_label.text = "Locked revision %d  Review %s" % [int(review.get("lockedRevision", 0)), str(review.get("snapshotHash", "")).left(12)]
	var local_confirmed := _local_participant_confirmed()
	confirm_button.visible = not local_confirmed
	confirm_button.disabled = mutation_in_flight or _connection_state_unresolved()
	confirmation_label.text = "Confirmed. Waiting for the other player." if local_confirmed else "Review the exact exchange before confirming."


func _confirm_trade() -> void:
	if mutation_in_flight or _connection_state_unresolved() or str(trade.get("status", "")) != "locked":
		return
	var review: Dictionary = trade.get("lockedReview", {}) if trade.get("lockedReview", {}) is Dictionary else {}
	mutation_in_flight = true
	confirm_button.disabled = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":"Trade service unavailable."}
	else:
		result = await service.confirm_trade(str(trade.get("tradeId", "")),int(trade.get("revision",0)),int(review.get("lockedRevision",0)),str(review.get("snapshotHash","")))
	mutation_in_flight = false
	if not bool(result.get("success",false)):
		_show_error(_friendly_error(result))
		confirm_button.disabled = false
		return
	var snapshot: Dictionary = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(snapshot)
	else:
		_on_trade_changed(snapshot)


func refresh_after_completion() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service != null:
		var result: Dictionary = await party_service.refresh_party()
		if not bool(result.get("success", false)):
			var overlay := get_tree().get_first_node_in_group("ui_overlay")
			if overlay != null and overlay.has_method("add_system_message"):
				overlay.call("add_system_message", "Trade completed, but your party could not be refreshed. Please reconnect.")
	var result: Dictionary = trade.get("completionResult", {}) if trade.get("completionResult", {}) is Dictionary else {}
	var refresh: Dictionary = result.get("refresh", {}) if result.get("refresh", {}) is Dictionary else {}
	if bool(refresh.get("inventory", false)):
		var inventory_service := get_node_or_null("/root/InventoryService")
		var inventory_result: Dictionary = await inventory_service.load_inventory() if inventory_service != null else {"success":false,"error":"Inventory service unavailable."}
		var overlay := get_tree().get_first_node_in_group("ui_overlay")
		if bool(inventory_result.get("success", false)):
			if overlay != null:
				overlay.set("bag_inventory_items", inventory_result.get("items", []).duplicate(true))
				overlay.set("bag_inventory_loaded", true)
		else:
			if overlay != null and overlay.has_method("add_system_message"):
				overlay.call("add_system_message", "Trade completed, but your inventory could not be refreshed. Please reconnect.")
	if bool(refresh.get("wallet", false)):
		var wallet_service := get_node_or_null("/root/PlayerWalletService")
		var wallet_result: Dictionary = await wallet_service.load_wallet() if wallet_service != null else {"success":false,"error":"Wallet service unavailable."}
		var overlay := get_tree().get_first_node_in_group("ui_overlay")
		if bool(wallet_result.get("success", false)):
			wallet_service.apply_wallet_result(wallet_result)
			get_tree().call_group("ui_overlay", "refresh_money_display")
		elif overlay != null and overlay.has_method("add_system_message"):
			overlay.call("add_system_message", "Trade completed, but your wallet could not be refreshed. Please reconnect.")


func _notify_trade_completion(snapshot: Dictionary) -> void:
	var trade_id := str(snapshot.get("tradeId", "")).strip_edges()
	if trade_id == "" or notified_completed_trade_ids.has(trade_id):
		return
	var messages := completion_transfer_messages(snapshot, _current_user_id())
	if messages.is_empty():
		return
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay == null or not overlay.has_method("add_system_message"):
		return
	notified_completed_trade_ids[trade_id] = true
	overlay.call("add_system_message", str(messages.get("removed", "")))
	overlay.call("add_system_message", str(messages.get("received", "")))


static func completion_transfer_messages(snapshot: Dictionary, user_id: int) -> Dictionary:
	var result: Dictionary = snapshot.get("completionResult", {}) if snapshot.get("completionResult", {}) is Dictionary else {}
	var transfers: Variant = result.get("transfers", [])
	if not transfers is Array:
		return {}
	var removed: Array[String] = []
	var received: Array[String] = []
	var removed_items: Array[String] = []
	var received_items: Array[String] = []
	var removed_money := 0
	var received_money := 0
	for transfer_value: Variant in transfers:
		if not transfer_value is Dictionary:
			continue
		var name := _completion_pokemon_name(transfer_value)
		if int(transfer_value.get("fromUserId", 0)) == user_id:
			removed.append(name)
		if int(transfer_value.get("toUserId", 0)) == user_id:
			received.append(name)
	var item_transfers: Variant = result.get("itemTransfers", [])
	if item_transfers is Array:
		for transfer_value: Variant in item_transfers:
			if not transfer_value is Dictionary:
				continue
			var item_label := "%dx %s" % [int(transfer_value.get("quantity", 0)), str(transfer_value.get("name", transfer_value.get("itemId", "Item")))]
			if int(transfer_value.get("fromUserId", 0)) == user_id:
				removed_items.append(item_label)
			if int(transfer_value.get("toUserId", 0)) == user_id:
				received_items.append(item_label)
	var money_transfers: Variant = result.get("moneyTransfers", [])
	if money_transfers is Array:
		for transfer_value: Variant in money_transfers:
			if not transfer_value is Dictionary:
				continue
			if int(transfer_value.get("fromUserId", 0)) == user_id:
				removed_money += maxi(int(transfer_value.get("amount", 0)), 0)
			if int(transfer_value.get("toUserId", 0)) == user_id:
				received_money += maxi(int(transfer_value.get("amount", 0)), 0)
	if removed.is_empty() and removed_items.is_empty() and removed_money == 0:
		return {}
	var removed_parts: Array[String] = []
	var received_parts: Array[String] = []
	if not removed.is_empty(): removed_parts.append("%s from your party" % ", ".join(removed))
	if not removed_items.is_empty(): removed_parts.append("%s from your inventory" % ", ".join(removed_items))
	if removed_money > 0: removed_parts.append("$%s from your wallet" % format_money(removed_money))
	if not received.is_empty(): received_parts.append("%s in your party" % ", ".join(received))
	if not received_items.is_empty(): received_parts.append("%s in your inventory" % ", ".join(received_items))
	if received_money > 0: received_parts.append("$%s in your wallet" % format_money(received_money))
	return {
		"removed": "Removed %s." % " and ".join(removed_parts),
		"received": "Received %s." % " and ".join(received_parts),
	}


static func _completion_pokemon_name(value: Dictionary) -> String:
	var nickname := str(value.get("nickname", "")).strip_edges()
	var species_name := str(value.get("speciesName", "")).strip_edges()
	var species_id := str(value.get("speciesId", "Pokemon")).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	if species_name != "" and species_name != "<null>":
		return species_name
	return species_id if species_id != "" else "Pokemon"


func _leave_trade() -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":"Trade service unavailable."}
	else:
		result = await service.leave_trade(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		return
	var snapshot: Dictionary = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(snapshot)
	else:
		_on_trade_changed(snapshot)


func _on_close_requested() -> void:
	if str(trade.get("status", "")) in ["active", "locked"]:
		_leave_trade()
		return
	hide()


func _render_connection_status() -> void:
	var disconnected := _disconnected_opponent()
	if disconnected.is_empty():
		return
	var deadline := str(disconnected.get("reconnectDeadlineAt", ""))
	var remaining := reconnect_seconds_remaining(deadline, Time.get_unix_time_from_system())
	status_label.text = "Other player disconnected. Waiting %d seconds for reconnect." % remaining


static func reconnect_seconds_remaining(deadline: String, now_unix: float) -> int:
	if deadline.strip_edges() == "":
		return 0
	return maxi(int(ceil(Time.get_unix_time_from_datetime_string(deadline) - now_unix)), 0)


func _disconnected_opponent() -> Dictionary:
	var user_id := _current_user_id()
	for value: Variant in trade.get("participants", []):
		if value is Dictionary and int(value.get("userId", 0)) != user_id and str(value.get("connectionState", "connected")) == "disconnected":
			return value
	return {}


func _connection_state_unresolved() -> bool:
	if not _disconnected_opponent().is_empty():
		return true
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	return realtime != null and realtime.active_trade_id == str(trade.get("tradeId", "")) and realtime.recovery_in_progress


func _add_review_pokemon(target: VBoxContainer, values: Variant) -> void:
	if not values is Array:
		return
	for value: Variant in values:
		var pokemon: Dictionary = value if value is Dictionary else {}
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 66
		panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SLOT, TRADE_BORDER, 5, 1))
		target.add_child(panel)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 7)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 7)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.texture = PokemonAssets.load_party_icon(_pokemon_species(pokemon), bool(pokemon.get("shiny", false)))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = _pokemon_label(pokemon)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TRADE_TEXT)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)


func _add_review_items(target: VBoxContainer, values: Variant) -> void:
	if not values is Array:
		return
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 48
		panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SLOT, TRADE_BORDER, 5, 1))
		target.add_child(panel)
		var label := Label.new()
		label.text = "%dx %s" % [int(value.get("quantity", 0)), str(value.get("name", value.get("itemId", "Item")))]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TRADE_TEXT)
		label.add_theme_font_size_override("font_size", 14)
		panel.add_child(label)


func _add_review_money(target: VBoxContainer, amount: int) -> void:
	if amount <= 0:
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 48
	panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SLOT, TRADE_GOLD, 5, 1))
	target.add_child(panel)
	var label := Label.new()
	label.text = "$%s Money" % format_money(amount)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TRADE_GOLD)
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)


static func format_money(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	while digits.length() > 3:
		result = ",%s%s" % [digits.right(3), result]
		digits = digits.left(digits.length() - 3)
	return digits + result


func _local_participant_ready() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return bool(participant_value.get("ready", false))
	return false


func _opponent_participant_ready() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) != user_id:
			return bool(participant_value.get("ready", false))
	return false


func _local_participant_confirmed() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return bool(participant_value.get("confirmed", false))
	return false


func _local_offer_nonempty() -> bool:
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and int(offer_value.get("userId", 0)) == user_id:
			var pokemon: Variant = offer_value.get("pokemon", [])
			var items: Variant = offer_value.get("items", [])
			return (pokemon is Array and not pokemon.is_empty()) or (items is Array and not items.is_empty()) or int(offer_value.get("money", 0)) > 0
	return false


func _friendly_error(result: Dictionary) -> String:
	var body: Dictionary = result.get("body", {}) if result.get("body", {}) is Dictionary else {}
	var detail: Variant = body.get("detail", {})
	var code := str(detail.get("code", "")) if detail is Dictionary else ""
	match code:
		"pokemon_reserved_for_trade": return "That Pokemon is already reserved for a trade."
		"pokemon_holding_item": return "Remove the held item before offering that Pokemon."
		"pokemon_not_tradable": return "That Pokemon cannot be traded."
		"pokemon_not_owned_or_held": return "That Pokemon is no longer held by your account."
		"pokemon_location_stale": return "That Pokemon moved. Refresh your party."
		"item_not_tradable": return "That item cannot be traded."
		"item_reserved_for_trade": return "That item stack is already reserved for a trade."
		"trade_item_quantity_unavailable", "trade_item_quantity_changed": return "That item quantity is no longer available. Refresh your inventory."
		"trade_item_snapshot_changed": return "That item changed. Refresh your inventory before trying again."
		"trade_money_unavailable", "trade_money_balance_changed": return "That money is no longer available. Refresh your wallet."
		"money_reserved_for_trade": return "That money is already reserved for an active trade."
		"trade_offer_party_only": return "Only Pokemon currently in your party can be offered."
		"trade_party_capacity_exceeded": return "The other player does not have enough free party slots."
		"trade_party_space_required": return "A free party slot is required to receive a Pokemon."
		"trade_offer_required": return "Offer at least one Pokemon or item before becoming Ready."
		"trade_review_mismatch": return "The locked review changed. Refresh before confirming."
		"trade_review_not_locked": return "This trade is no longer locked for review."
		"trade_settlement_invalidated": return "The trade changed and could not be completed. Refresh the authoritative trade state."
		"trade_settlement_retryable": return "The trade was not committed. Refresh and try again."
	if _is_stale_revision_error(result):
		return "The trade changed again. Please retry your offer."
	return str(result.get("error", "The offer could not be updated. Refresh and try again."))


func _show_error(message: String) -> void:
	status_label.text = message


func _pokemon_label(value: Variant) -> String:
	var pokemon: Dictionary = value if value is Dictionary else {}
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	var species_name := str(pokemon.get("speciesName", "")).strip_edges()
	var species_id := str(pokemon.get("speciesId", "")).strip_edges()
	var name := nickname if nickname != "" and nickname != "<null>" else species_name
	if name == "" or name == "<null>":
		name = species_id if species_id != "" else "Pokemon"
	return "%s  Lv. %d" % [name, maxi(int(pokemon.get("level", 1)), 1)]


func _pokemon_name(value: Dictionary) -> String:
	var nickname := str(value.get("nickname", "")).strip_edges()
	var species_name := str(value.get("speciesName", "")).strip_edges()
	var species_id := str(value.get("speciesId", value.get("species", "Pokemon"))).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	if species_name != "" and species_name != "<null>":
		return species_name
	return species_id if species_id != "" else "Pokemon"


func _pokemon_species(value: Dictionary) -> String:
	return str(value.get("speciesId", value.get("species", value.get("speciesName", ""))))


func _current_user_id() -> int:
	var auth := get_node_or_null("/root/AuthService")
	return int(auth.current_user.get("id", 0)) if auth != null else 0


func _opponent_receive_capacity() -> int:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) != user_id:
			return clampi(6 - int(participant_value.get("partyCount", 0)), 0, MAX_OFFER_SIZE)
	return MAX_OFFER_SIZE


func _offer_limit() -> int:
	return mini(MAX_OFFER_SIZE, _opponent_receive_capacity())


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
