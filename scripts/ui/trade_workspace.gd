extends Window

class_name TradeWorkspaceNode

const TRADE_ICON: Texture2D = preload("res://assets/ui/player_trade.svg")
const MAX_OFFER_SIZE := 5
const TRADE_BG := Color("#050912fa")
const TRADE_SURFACE := Color("#081522f7")
const TRADE_SURFACE_RAISED := Color("#0b1a2bf7")
const TRADE_SLOT := Color("#050d18f2")
const TRADE_BORDER := Color("#2d4b66b3")
const TRADE_ACCENT := Color("#62d7ff")
const TRADE_ACCENT_SOFT := Color("#62d7ff88")
const TRADE_ACCENT_FAINT := Color("#62d7ff22")
const TRADE_GOLD := Color("#d8b767")
const TRADE_TEXT := Color("#f4f0de")
const TRADE_MUTED := Color("#aeb8c5")
const TRADE_READY := Color("#63df8b")

var trade: Dictionary = {}
var candidates: Array[Dictionary] = []
var selected_ids: Array[int] = []
var selected_item_offers: Array[Dictionary] = []
var selected_money := 0
var money_draft_dirty := false
var money_input_syncing := false
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
var status_panel: PanelContainer
var persistent_offer_error := ""
var local_offer_title_label: Label
var opponent_offer_title_label: Label
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

const DESIRED_WINDOW_SIZE := Vector2i(1120, 680)
const MINIMUM_WINDOW_SIZE := Vector2i(920, 580)
const VIEWPORT_MARGIN := Vector2i(20, 20)


func _ready() -> void:
	hide()
	title = _t("ui.trade.title")
	min_size = MINIMUM_WINDOW_SIZE
	size = trade_window_size_for_viewport(get_tree().root.size)
	unresizable = true
	borderless = true
	_build_ui()
	close_requested.connect(_on_close_requested)
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.active_trade_changed.connect(_on_trade_changed)
		if not realtime.active_trade_snapshot.is_empty():
			_on_trade_changed(realtime.active_trade_snapshot)


func clear_account_state() -> void:
	hide()
	trade.clear()
	candidates.clear()
	selected_ids.clear()
	selected_item_offers.clear()
	selected_money = 0
	money_draft_dirty = false
	inventory_items.clear()
	mutation_in_flight = false
	persistent_offer_error = ""
	notified_completed_trade_ids.clear()
	if item_selector_popup != null:
		item_selector_popup.hide()


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _trade_outer_style())
	add_child(background)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 15)
	background.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "TradeHeader"
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_window_header_gui_input)
	root.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(46, 46)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", _trade_icon_frame_style())
	header.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_theme_constant_override("margin_left", 6)
	icon_margin.add_theme_constant_override("margin_top", 6)
	icon_margin.add_theme_constant_override("margin_right", 6)
	icon_margin.add_theme_constant_override("margin_bottom", 6)
	icon_frame.add_child(icon_margin)

	var trade_icon := TextureRect.new()
	trade_icon.texture = TRADE_ICON
	trade_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trade_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trade_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_child(trade_icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var heading := Label.new()
	_set_localized_property(heading, "text", "ui.trade.title")
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.gui_input.connect(_on_window_header_gui_input)
	heading.add_theme_color_override("font_color", TRADE_TEXT)
	heading.add_theme_font_size_override("font_size", 21)
	title_stack.add_child(heading)

	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.trade.subtitle")
	subtitle.mouse_filter = Control.MOUSE_FILTER_STOP
	subtitle.gui_input.connect(_on_window_header_gui_input)
	subtitle.add_theme_color_override("font_color", TRADE_MUTED)
	subtitle.add_theme_font_size_override("font_size", 11)
	title_stack.add_child(subtitle)

	var phase_chip := PanelContainer.new()
	phase_chip.name = "TradePhaseChip"
	phase_chip.custom_minimum_size = Vector2(118, 32)
	phase_chip.add_theme_stylebox_override("panel", _panel_style(TRADE_ACCENT_FAINT, TRADE_ACCENT_SOFT, 7, 1))
	header.add_child(phase_chip)

	phase_label = Label.new()
	phase_label.text = _t("ui.trade.phase.setup")
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", TRADE_ACCENT)
	phase_label.add_theme_font_size_override("font_size", 10)
	phase_chip.add_child(phase_label)

	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "ui.trade.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.custom_minimum_size = Vector2(38, 34)
	close_button.add_theme_color_override("font_color", TRADE_MUTED)
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color("#07111ed8"), TRADE_BORDER, 7, 1))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color("#2a1015"), Color("#b84c58"), 7, 1))
	close_button.pressed.connect(_on_close_requested)
	header.add_child(close_button)

	status_panel = PanelContainer.new()
	status_panel.name = "TradeStatusBanner"
	status_panel.custom_minimum_size.y = 42
	status_panel.visible = false
	status_panel.add_theme_stylebox_override("panel", _trade_status_style())
	root.add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_top", 8)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_bottom", 8)
	status_panel.add_child(status_margin)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_margin.add_child(status_row)

	var status_dot := Label.new()
	status_dot.text = "●"
	status_dot.add_theme_color_override("font_color", TRADE_ACCENT)
	status_dot.add_theme_font_size_override("font_size", 9)
	status_row.add_child(status_dot)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", TRADE_MUTED)
	status_row.add_child(status_label)

	editable_root = VBoxContainer.new()
	editable_root.add_theme_constant_override("separation", 10)
	editable_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editable_root)

	var columns := HBoxContainer.new()
	columns.name = "OfferColumns"
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editable_root.add_child(columns)
	local_offer_box = _offer_section(columns, "Your Offer", local_offer_slots)
	opponent_offer_box = _offer_section(columns, "Other Player's Offer", opponent_offer_slots)

	var action_panel := PanelContainer.new()
	action_panel.name = "TradeActionBar"
	action_panel.custom_minimum_size = Vector2(0, 46)
	action_panel.add_theme_stylebox_override("panel", _trade_action_bar_style())
	editable_root.add_child(action_panel)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 9)
	action_margin.add_theme_constant_override("margin_top", 6)
	action_margin.add_theme_constant_override("margin_right", 9)
	action_margin.add_theme_constant_override("margin_bottom", 6)
	action_panel.add_child(action_margin)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	action_margin.add_child(actions)

	add_items_button = Button.new()
	_set_localized_property(add_items_button, "text", "ui.trade.add_items")
	add_items_button.focus_mode = Control.FOCUS_NONE
	add_items_button.pressed.connect(_open_item_selector)
	_apply_button_style(add_items_button, "secondary")
	actions.add_child(add_items_button)

	var action_hint := Label.new()
	_set_localized_property(action_hint, "text", "ui.trade.drag_hint")
	action_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_hint.add_theme_color_override("font_color", TRADE_MUTED)
	action_hint.add_theme_font_size_override("font_size", 10)
	actions.add_child(action_hint)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)

	ready_button = Button.new()
	_set_localized_property(ready_button, "text", "ui.trade.ready")
	ready_button.custom_minimum_size = Vector2(128, 34)
	ready_button.focus_mode = Control.FOCUS_NONE
	ready_button.pressed.connect(_set_ready.bind(true))
	_apply_button_style(ready_button, "primary")
	actions.add_child(ready_button)

	edit_button = Button.new()
	_set_localized_property(edit_button, "text", "ui.trade.edit")
	edit_button.custom_minimum_size = Vector2(118, 34)
	edit_button.focus_mode = Control.FOCUS_NONE
	edit_button.pressed.connect(_set_ready.bind(false))
	_apply_button_style(edit_button, "secondary")
	actions.add_child(edit_button)

	review_root = VBoxContainer.new()
	review_root.add_theme_constant_override("separation", 10)
	review_root.visible = false
	review_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(review_root)

	var review_banner := PanelContainer.new()
	review_banner.name = "LockedReviewBanner"
	review_banner.add_theme_stylebox_override("panel", _panel_style(Color("#0b241bf2"), Color("#63df8b99"), 8, 1))
	review_root.add_child(review_banner)

	var review_banner_margin := MarginContainer.new()
	review_banner_margin.add_theme_constant_override("margin_left", 12)
	review_banner_margin.add_theme_constant_override("margin_top", 9)
	review_banner_margin.add_theme_constant_override("margin_right", 12)
	review_banner_margin.add_theme_constant_override("margin_bottom", 9)
	review_banner.add_child(review_banner_margin)

	var review_banner_row := HBoxContainer.new()
	review_banner_row.add_theme_constant_override("separation", 9)
	review_banner_margin.add_child(review_banner_row)

	var locked_mark := Label.new()
	locked_mark.text = "✓"
	locked_mark.add_theme_color_override("font_color", TRADE_READY)
	locked_mark.add_theme_font_size_override("font_size", 16)
	review_banner_row.add_child(locked_mark)

	review_trust_label = Label.new()
	review_trust_label.text = _t("ui.trade.review.locked")
	review_trust_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_trust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	review_trust_label.add_theme_color_override("font_color", TRADE_READY)
	review_banner_row.add_child(review_trust_label)

	var review_columns := HBoxContainer.new()
	review_columns.name = "LockedReviewColumns"
	review_columns.add_theme_constant_override("separation", 14)
	review_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_root.add_child(review_columns)
	review_give_list = _section(review_columns, _t("ui.trade.review.give"))
	review_receive_list = _section(review_columns, _t("ui.trade.review.receive"))

	var confirmation_panel := PanelContainer.new()
	confirmation_panel.name = "ConfirmationBar"
	confirmation_panel.add_theme_stylebox_override("panel", _trade_action_bar_style())
	review_root.add_child(confirmation_panel)

	var confirmation_margin := MarginContainer.new()
	confirmation_margin.add_theme_constant_override("margin_left", 10)
	confirmation_margin.add_theme_constant_override("margin_top", 7)
	confirmation_margin.add_theme_constant_override("margin_right", 9)
	confirmation_margin.add_theme_constant_override("margin_bottom", 7)
	confirmation_panel.add_child(confirmation_margin)

	var confirmation_row := HBoxContainer.new()
	confirmation_row.add_theme_constant_override("separation", 10)
	confirmation_margin.add_child(confirmation_row)

	confirmation_label = Label.new()
	confirmation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirmation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_label.add_theme_color_override("font_color", TRADE_MUTED)
	confirmation_row.add_child(confirmation_label)

	confirm_button = Button.new()
	_set_localized_property(confirm_button, "text", "ui.trade.confirm")
	confirm_button.custom_minimum_size = Vector2(148, 36)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(_confirm_trade)
	_apply_button_style(confirm_button, "primary")
	confirmation_row.add_child(confirm_button)
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


static func trade_window_size_for_viewport(viewport_size: Vector2i) -> Vector2i:
	var available := Vector2i(
		maxi(viewport_size.x - VIEWPORT_MARGIN.x, MINIMUM_WINDOW_SIZE.x),
		maxi(viewport_size.y - VIEWPORT_MARGIN.y, MINIMUM_WINDOW_SIZE.y)
	)
	return Vector2i(
		mini(DESIRED_WINDOW_SIZE.x, available.x),
		mini(DESIRED_WINDOW_SIZE.y, available.y)
	)


func _process(_delta: float) -> void:
	if visible and str(trade.get("status", "")) in ["active", "locked"]:
		_render_connection_status()


func _section(parent: Control, label_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(235, 0)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", TRADE_ACCENT)
	section.add_child(label)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _trade_workspace_panel_style())
	section.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	return list


func _offer_section(parent: Control, label_text: String, slots: Array[Control]) -> PanelContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(0, 300)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	section.add_child(header)

	var identity_stack := VBoxContainer.new()
	identity_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_stack.add_theme_constant_override("separation", 0)
	header.add_child(identity_stack)

	var side_caption := Label.new()
	side_caption.text = _t(
		"ui.trade.offer.yours" if label_text == "Your Offer" else "ui.trade.offer.theirs"
	)
	side_caption.add_theme_font_size_override("font_size", 9)
	side_caption.add_theme_color_override("font_color", TRADE_ACCENT if label_text == "Your Offer" else TRADE_MUTED)
	identity_stack.add_child(side_caption)

	var participant_label := Label.new()
	participant_label.text = _t(
		"ui.trade.participant.you"
		if label_text == "Your Offer"
		else "ui.trade.participant.other_trainer"
	)
	participant_label.add_theme_font_size_override("font_size", 16)
	participant_label.add_theme_color_override("font_color", TRADE_TEXT)
	identity_stack.add_child(participant_label)
	if label_text == "Your Offer":
		local_offer_title_label = participant_label
	else:
		opponent_offer_title_label = participant_label

	var ready_indicator := Label.new()
	_set_localized_property(ready_indicator, "text", "ui.trade.ready_indicator")
	ready_indicator.visible = false
	ready_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ready_indicator.add_theme_color_override("font_color", TRADE_READY)
	ready_indicator.add_theme_font_size_override("font_size", 11)
	header.add_child(ready_indicator)
	if label_text == "Your Offer":
		local_ready_indicator = ready_indicator
	else:
		opponent_ready_indicator = ready_indicator

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _trade_workspace_panel_style())
	section.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var pokemon_caption := Label.new()
	pokemon_caption.text = _t(
		"ui.trade.offer.pokemon_drag"
		if label_text == "Your Offer"
		else "ui.trade.offer.pokemon"
	)
	pokemon_caption.add_theme_font_size_override("font_size", 9)
	pokemon_caption.add_theme_color_override("font_color", TRADE_MUTED)
	content.add_child(pokemon_caption)

	var grid := GridContainer.new()
	grid.columns = MAX_OFFER_SIZE
	grid.add_theme_constant_override("h_separation", 7)
	content.add_child(grid)
	for index in range(MAX_OFFER_SIZE):
		var slot := _create_offer_slot(index, label_text == "Your Offer")
		slots.append(slot)
		grid.add_child(slot)

	var item_heading := HBoxContainer.new()
	item_heading.add_theme_constant_override("separation", 8)
	content.add_child(item_heading)

	var item_caption := Label.new()
	_set_localized_property(item_caption, "text", "ui.trade.offer.items")
	item_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_caption.add_theme_font_size_override("font_size", 9)
	item_caption.add_theme_color_override("font_color", TRADE_MUTED)
	item_heading.add_child(item_caption)

	var item_hint := Label.new()
	item_hint.text = _t(
		"ui.trade.offer.items_yours"
		if label_text == "Your Offer"
		else "ui.trade.offer.items_theirs"
	)
	item_hint.add_theme_font_size_override("font_size", 9)
	item_hint.add_theme_color_override("font_color", Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.62))
	item_heading.add_child(item_hint)

	var item_scroll := ScrollContainer.new()
	item_scroll.custom_minimum_size.y = 62
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(item_scroll)

	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 4)
	item_scroll.add_child(item_list)
	if label_text == "Your Offer":
		local_item_offer_list = item_list
	else:
		opponent_item_offer_list = item_list

	var money_footer := PanelContainer.new()
	money_footer.custom_minimum_size.y = 78 if label_text == "Your Offer" else 64
	money_footer.add_theme_stylebox_override("panel", _trade_money_style())
	content.add_child(money_footer)

	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 10)
	footer_margin.add_theme_constant_override("margin_top", 7)
	footer_margin.add_theme_constant_override("margin_right", 10)
	footer_margin.add_theme_constant_override("margin_bottom", 7)
	money_footer.add_child(footer_margin)

	var money_content := VBoxContainer.new()
	money_content.add_theme_constant_override("separation", 4)
	footer_margin.add_child(money_content)

	var money_header := HBoxContainer.new()
	money_header.add_theme_constant_override("separation", 8)
	money_content.add_child(money_header)

	var money_title := Label.new()
	_set_localized_property(money_title, "text", "ui.trade.offer.money")
	money_title.add_theme_color_override("font_color", TRADE_MUTED)
	money_title.add_theme_font_size_override("font_size", 9)
	money_header.add_child(money_title)

	var money_offer_label := Label.new()
	money_offer_label.text = "$0"
	money_offer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_offer_label.add_theme_color_override("font_color", TRADE_GOLD)
	money_offer_label.add_theme_font_size_override("font_size", 16)
	money_header.add_child(money_offer_label)
	if label_text == "Your Offer":
		local_money_offer_label = money_offer_label
		money_balance_label = Label.new()
		money_balance_label.text = _t("ui.trade.money.available", {"amount": "0"})
		_set_localized_property(
			money_balance_label,
			"tooltip_text",
			"ui.trade.money.balance_tooltip"
		)
		money_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		money_balance_label.add_theme_color_override("font_color", TRADE_MUTED)
		money_balance_label.add_theme_font_size_override("font_size", 9)
		money_header.add_child(money_balance_label)

		var money_controls := HBoxContainer.new()
		money_controls.add_theme_constant_override("separation", 8)
		money_content.add_child(money_controls)

		var currency_prefix := Label.new()
		currency_prefix.text = "$"
		currency_prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		currency_prefix.add_theme_color_override("font_color", TRADE_GOLD)
		currency_prefix.add_theme_font_size_override("font_size", 16)
		money_controls.add_child(currency_prefix)

		money_amount_spinbox = SpinBox.new()
		money_amount_spinbox.min_value = 0
		money_amount_spinbox.max_value = 2147483647
		money_amount_spinbox.step = 1
		money_amount_spinbox.update_on_text_changed = true
		money_amount_spinbox.value_changed.connect(_on_money_amount_changed)
		money_amount_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money_amount_spinbox.custom_minimum_size.x = 140
		money_amount_spinbox.focus_mode = Control.FOCUS_ALL
		money_controls.add_child(money_amount_spinbox)

		update_money_button = Button.new()
		_set_localized_property(update_money_button, "text", "ui.trade.money.update")
		update_money_button.focus_mode = Control.FOCUS_NONE
		_set_localized_property(
			update_money_button,
			"tooltip_text",
			"ui.trade.money.update_tooltip"
		)
		update_money_button.pressed.connect(_update_money_offer)
		_apply_button_style(update_money_button, "secondary")
		money_controls.add_child(update_money_button)
	else:
		opponent_money_offer_label = money_offer_label
		var opponent_hint := Label.new()
		_set_localized_property(opponent_hint, "text", "ui.trade.money.opponent")
		opponent_hint.add_theme_color_override("font_color", TRADE_MUTED)
		opponent_hint.add_theme_font_size_override("font_size", 10)
		money_content.add_child(opponent_hint)
	return panel


func _build_item_selector() -> void:
	item_selector_popup = PopupPanel.new()
	item_selector_popup.size = Vector2i(680, 590)
	item_selector_popup.add_theme_stylebox_override("panel", _trade_outer_style())
	add_child(item_selector_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 15)
	item_selector_popup.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(40, 40)
	icon_frame.add_theme_stylebox_override("panel", _trade_icon_frame_style())
	header.add_child(icon_frame)

	var icon_margin := MarginContainer.new()
	icon_margin.add_theme_constant_override("margin_left", 6)
	icon_margin.add_theme_constant_override("margin_top", 6)
	icon_margin.add_theme_constant_override("margin_right", 6)
	icon_margin.add_theme_constant_override("margin_bottom", 6)
	icon_frame.add_child(icon_margin)

	var icon := TextureRect.new()
	icon.texture = TRADE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_margin.add_child(icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)

	var heading := Label.new()
	_set_localized_property(heading, "text", "ui.trade.items.title")
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", TRADE_TEXT)
	title_stack.add_child(heading)

	var help := Label.new()
	_set_localized_property(help, "text", "ui.trade.items.subtitle")
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", TRADE_MUTED)
	title_stack.add_child(help)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	_set_localized_property(close_button, "tooltip_text", "ui.trade.items.close")
	close_button.pressed.connect(item_selector_popup.hide)
	_apply_button_style(close_button, "secondary")
	header.add_child(close_button)

	item_selector_search = LineEdit.new()
	_set_localized_property(
		item_selector_search,
		"placeholder_text",
		"ui.trade.items.search"
	)
	item_selector_search.custom_minimum_size = Vector2(0, 38)
	item_selector_search.clear_button_enabled = true
	item_selector_search.add_theme_color_override("font_color", TRADE_TEXT)
	item_selector_search.add_theme_color_override("font_placeholder_color", TRADE_MUTED)
	item_selector_search.add_theme_stylebox_override("normal", _trade_input_style(TRADE_BORDER))
	item_selector_search.add_theme_stylebox_override("focus", _trade_input_style(TRADE_ACCENT))
	item_selector_search.text_changed.connect(_filter_item_selector_rows)
	root.add_child(item_selector_search)

	var list_frame := PanelContainer.new()
	list_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_frame.add_theme_stylebox_override("panel", _panel_style(TRADE_SLOT, Color("#28496399"), 8, 1))
	root.add_child(list_frame)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 8)
	list_margin.add_theme_constant_override("margin_top", 8)
	list_margin.add_theme_constant_override("margin_right", 8)
	list_margin.add_theme_constant_override("margin_bottom", 8)
	list_frame.add_child(list_margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(scroll)

	item_selector_list = VBoxContainer.new()
	item_selector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_selector_list.add_theme_constant_override("separation", 6)
	scroll.add_child(item_selector_list)

	item_selector_empty_label = Label.new()
	item_selector_empty_label.text = _t("ui.trade.items.no_matches")
	item_selector_empty_label.custom_minimum_size = Vector2(0, 70)
	item_selector_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_selector_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_selector_empty_label.add_theme_color_override("font_color", TRADE_MUTED)
	item_selector_empty_label.visible = false
	item_selector_list.add_child(item_selector_empty_label)

	var action_panel := PanelContainer.new()
	action_panel.add_theme_stylebox_override("panel", _trade_action_bar_style())
	root.add_child(action_panel)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 9)
	action_margin.add_theme_constant_override("margin_top", 6)
	action_margin.add_theme_constant_override("margin_right", 9)
	action_margin.add_theme_constant_override("margin_bottom", 6)
	action_panel.add_child(action_margin)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	action_margin.add_child(actions)

	var selection_hint := Label.new()
	_set_localized_property(selection_hint, "text", "ui.trade.items.apply_hint")
	selection_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_hint.add_theme_color_override("font_color", TRADE_MUTED)
	selection_hint.add_theme_font_size_override("font_size", 10)
	actions.add_child(selection_hint)

	var cancel := Button.new()
	_set_localized_property(cancel, "text", "common.cancel")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(item_selector_popup.hide)
	_apply_button_style(cancel, "secondary")
	actions.add_child(cancel)

	var apply := Button.new()
	_set_localized_property(apply, "text", "ui.trade.items.update_offer")
	apply.custom_minimum_size = Vector2(130, 34)
	apply.focus_mode = Control.FOCUS_NONE
	apply.pressed.connect(_apply_item_selection)
	_apply_button_style(apply, "primary")
	actions.add_child(apply)


func _create_offer_slot(slot_index: int = -1, accepts_drop: bool = false) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(82, 86)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_theme_stylebox_override("panel", _trade_offer_slot_style(false))
	if slot_index >= 0:
		_render_empty_offer_slot(slot, slot_index, accepts_drop)
	return slot


func _render_empty_offer_slot(slot: Control, slot_index: int, accepts_drop: bool) -> void:
	slot.add_theme_stylebox_override("panel", _trade_offer_slot_style(false))
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 5
	stack.offset_top = 5
	stack.offset_right = -5
	stack.offset_bottom = -5
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)
	slot.add_child(stack)

	var badge := Label.new()
	badge.text = "%02d" % (slot_index + 1)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.56))
	stack.add_child(badge)

	var plus := Label.new()
	plus.text = "+" if accepts_drop else "·"
	plus.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 19)
	plus.add_theme_color_override("font_color", Color(TRADE_ACCENT.r, TRADE_ACCENT.g, TRADE_ACCENT.b, 0.48) if accepts_drop else Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.34))
	stack.add_child(plus)

	var hint := Label.new()
	hint.text = _t("ui.trade.slot.drop" if accepts_drop else "ui.trade.slot.empty")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.48))
	stack.add_child(hint)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _trade_outer_style() -> StyleBoxFlat:
	var style := _panel_style(TRADE_BG, TRADE_ACCENT_SOFT, 12, 1)
	style.border_width_top = 2
	style.shadow_color = Color("#00000099")
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


func _trade_workspace_panel_style() -> StyleBoxFlat:
	var style := _panel_style(TRADE_SURFACE_RAISED, TRADE_BORDER, 9, 1)
	style.shadow_color = Color("#0000003d")
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


func _trade_icon_frame_style() -> StyleBoxFlat:
	var style := _panel_style(TRADE_ACCENT_FAINT, TRADE_ACCENT_SOFT, 9, 1)
	style.shadow_color = Color("#00000036")
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _trade_status_style() -> StyleBoxFlat:
	var style := _panel_style(Color("#071522ec"), Color("#3d7596aa"), 8, 1)
	style.border_width_left = 3
	return style


func _trade_action_bar_style() -> StyleBoxFlat:
	return _panel_style(Color("#07121fd9"), Color("#28496399"), 8, 1)


func _trade_money_style() -> StyleBoxFlat:
	var style := _panel_style(Color("#171408d9"), Color("#9c7d2f99"), 7, 1)
	style.border_width_left = 3
	style.border_color = Color("#d8b76799")
	return style


func _trade_offer_slot_style(occupied: bool) -> StyleBoxFlat:
	var background := Color("#0a1d2ef2") if occupied else TRADE_SLOT
	var border := TRADE_ACCENT_SOFT if occupied else Color("#28496399")
	var style := _panel_style(background, border, 7, 1)
	if occupied:
		style.border_width_bottom = 2
	return style


func _trade_input_style(border: Color) -> StyleBoxFlat:
	var style := _panel_style(TRADE_SLOT, border, 7, 1)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 7, 1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _apply_button_style(button: Button, kind: String) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	var primary := kind == "primary"
	var normal_bg := Color("#0d4359") if primary else Color("#111d2c")
	var hover_bg := Color("#12627f") if primary else Color("#192c42")
	var border := TRADE_ACCENT if primary else TRADE_BORDER
	button.add_theme_color_override("font_color", TRADE_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#667382"))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, TRADE_ACCENT))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#081a27"), TRADE_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(hover_bg, TRADE_GOLD))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#0a1018"), Color("#253344")))


func _on_trade_changed(value: Dictionary) -> void:
	var status := str(value.get("status", ""))
	var refresh_candidates := status == "active" and _trade_snapshot_changed(value)
	var center_window := should_center_for_trade(
		visible,
		str(trade.get("tradeId", "")),
		str(value.get("tradeId", ""))
	)
	if center_window:
		persistent_offer_error = ""
	if status == "cancelled":
		persistent_offer_error = ""
		trade = value.duplicate(true)
		phase_label.text = _t("ui.trade.phase.cancelled")
		editable_root.visible = false
		review_root.visible = false
		if str(trade.get("cancellationReason", "")) == "reconnect_timeout":
			_set_status(_t("ui.trade.status.reconnect_expired"), true)
			popup_centered()
		else:
			hide()
		return
	if status == "completed":
		persistent_offer_error = ""
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
	_render_participant_names()
	_sync_selected_from_offer()
	_render_offers()
	_render_mode()
	if center_window:
		popup_centered()
	if refresh_candidates:
		refresh_available_pokemon.call_deferred()
		refresh_available_money.call_deferred()


func refresh_available_pokemon() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		_show_error(_t("ui.trade.error.party_unavailable"))
		return
	var party_result: Dictionary = await party_service.load_party()
	if not bool(party_result.get("success", false)):
		_show_error(_t("ui.trade.error.party_refresh"))
		return
	candidates = collect_candidates(party_result.get("party", []))
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null:
		_show_error(_t("ui.trade.error.inventory_unavailable"))
		return
	var inventory_result: Dictionary = await inventory_service.load_inventory()
	if not bool(inventory_result.get("success", false)):
		_show_error(_t("ui.trade.error.inventory_refresh"))
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


static func should_center_for_trade(is_visible: bool, current_trade_id: String, incoming_trade_id: String) -> bool:
	return not is_visible or current_trade_id != incoming_trade_id


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
	_clear_persistent_offer_error()
	mutation_in_flight = true
	_render_offers()
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	var trade_id := str(trade.get("tradeId", ""))
	if service == null:
		result = {"success":false, "error":_t("ui.trade.error.service_unavailable")}
	else:
		result = await service.replace_offer(trade_id, int(trade.get("revision", 0)), pokemon_ids, "", item_offers, resolved_money)
		if _is_stale_revision_error(result):
			result = await _retry_offer_after_stale_revision(service, trade_id, pokemon_ids, item_offers, resolved_money)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result), true)
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
		return {"success":false, "error":_t("ui.trade.error.not_editable")}
	trade = latest
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(latest)
	if _local_participant_ready() or _connection_state_unresolved():
		return {"success":false, "error":_t("ui.trade.error.not_ready_for_update")}
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
	_clear_persistent_offer_error()
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false, "error":_t("ui.trade.error.service_unavailable")}
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
	var previous_money := selected_money
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
	if money_amount_spinbox != null and (not money_draft_dirty or selected_money != previous_money):
		_set_money_input_value(selected_money)
		money_draft_dirty = false


func _render_offers() -> void:
	_clear_offer_slots(local_offer_slots, true)
	_clear_offer_slots(opponent_offer_slots, false)
	_clear(local_item_offer_list)
	_clear(opponent_item_offer_list)
	local_money_offer_label.text = "$0"
	opponent_money_offer_label.text = "$0"
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
		var money_label := local_money_offer_label if is_local else opponent_money_offer_label
		money_label.text = "$%s" % format_money(money)
	if local_item_offer_list.get_child_count() == 0:
		_render_empty_item_offer(local_item_offer_list, _t("ui.trade.offer.no_items_added"))
	if opponent_item_offer_list.get_child_count() == 0:
		_render_empty_item_offer(opponent_item_offer_list, _t("ui.trade.offer.no_items_offered"))


func _render_item_offer(target: VBoxContainer, item: Dictionary, is_local: bool, position: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 34)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#091827df"), Color("#28496399"), 6, 1))
	target.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var item_mark := Label.new()
	item_mark.text = "◆"
	item_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_mark.add_theme_color_override("font_color", TRADE_GOLD)
	item_mark.add_theme_font_size_override("font_size", 9)
	row.add_child(item_mark)

	var name_label := Label.new()
	name_label.text = _t("ui.trade.item.quantity_name", {
		"quantity": int(item.get("quantity", 0)),
		"name": _item_display_name(item),
	})
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", TRADE_TEXT)
	name_label.add_theme_font_size_override("font_size", 11)
	row.add_child(name_label)

	var category_label := Label.new()
	category_label.text = str(item.get("category", "")).replace("-", " ").capitalize()
	category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category_label.add_theme_color_override("font_color", TRADE_MUTED)
	category_label.add_theme_font_size_override("font_size", 9)
	row.add_child(category_label)
	if is_local and _local_offer_asset_count() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove := Button.new()
		remove.text = "×"
		_set_localized_property(remove, "tooltip_text", "ui.trade.item.remove")
		remove.focus_mode = Control.FOCUS_NONE
		remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		remove.custom_minimum_size = Vector2(24, 24)
		remove.add_theme_color_override("font_color", Color("#ffc6ca"))
		remove.add_theme_stylebox_override("normal", _panel_style(Color("#00000000"), Color("#00000000"), 5, 0))
		remove.add_theme_stylebox_override("hover", _panel_style(Color("#2a1015e8"), Color("#b84c58"), 5, 1))
		remove.pressed.connect(_remove_item_offer_position.bind(position))
		row.add_child(remove)


func _render_empty_item_offer(target: VBoxContainer, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.custom_minimum_size = Vector2(0, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.58))
	label.add_theme_font_size_override("font_size", 10)
	target.add_child(label)


func _open_item_selector() -> void:
	if mutation_in_flight or _local_participant_ready() or str(trade.get("status", "")) != "active":
		return
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service == null:
		_show_error(_t("ui.trade.error.inventory_unavailable"))
		return
	var result: Dictionary = await inventory_service.load_inventory()
	if not bool(result.get("success", false)):
		_show_error(_t("ui.trade.error.inventory_refresh"))
		return
	inventory_items = normalize_inventory_candidates(result.get("items", []))
	item_selector_search.text = ""
	_rebuild_item_selector_rows()
	item_selector_popup.popup_centered(Vector2i(680, 590))
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
		if not money_draft_dirty:
			_set_money_input_value(mini(selected_money, int(money_amount_spinbox.max_value)))
	if money_balance_label != null:
		money_balance_label.text = _t("ui.trade.money.available", {
			"amount": format_money(balance),
		})


func _update_money_offer() -> void:
	if money_amount_spinbox == null:
		return
	var amount := maxi(int(money_amount_spinbox.value), 0)
	if amount == 0 and selected_ids.is_empty() and selected_item_offers.is_empty():
		_show_error(_t("ui.trade.error.offer_assets"))
		return
	_replace_offer(selected_ids.duplicate(), selected_item_offers.duplicate(true), amount)


func _on_money_amount_changed(_value: float) -> void:
	if not money_input_syncing:
		money_draft_dirty = true


func _set_money_input_value(value: int) -> void:
	money_input_syncing = true
	money_amount_spinbox.value = value
	money_input_syncing = false


func _rebuild_item_selector_rows() -> void:
	_clear(item_selector_list)
	item_selector_rows.clear()
	item_selector_empty_label = Label.new()
	item_selector_empty_label.text = _t("ui.trade.items.no_matches")
	item_selector_empty_label.custom_minimum_size = Vector2(0, 70)
	item_selector_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_selector_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_selector_empty_label.add_theme_color_override("font_color", TRADE_MUTED)
	item_selector_empty_label.visible = false
	item_selector_list.add_child(item_selector_empty_label)
	var selected_by_id: Dictionary = {}
	for selected: Dictionary in selected_item_offers:
		selected_by_id[str(selected.get("itemId", ""))] = int(selected.get("quantity", 1))
	if inventory_items.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.trade.items.none_available")
		empty.custom_minimum_size = Vector2(0, 70)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", TRADE_MUTED)
		item_selector_list.add_child(empty)
		return
	for item: Dictionary in inventory_items:
		var item_id := str(item.get("itemId", ""))
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 54)
		row_panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE_RAISED, TRADE_BORDER, 7, 1))
		item_selector_list.add_child(row_panel)
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 11)
		row_margin.add_theme_constant_override("margin_top", 6)
		row_margin.add_theme_constant_override("margin_right", 9)
		row_margin.add_theme_constant_override("margin_bottom", 6)
		row_panel.add_child(row_margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_margin.add_child(row)
		var enabled := CheckBox.new()
		enabled.button_pressed = selected_by_id.has(item_id)
		enabled.focus_mode = Control.FOCUS_NONE
		enabled.custom_minimum_size = Vector2(24, 24)
		_apply_trade_checkbox_style(enabled)
		row.add_child(enabled)

		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.alignment = BoxContainer.ALIGNMENT_CENTER
		identity.add_theme_constant_override("separation", 0)
		row.add_child(identity)

		var label := Label.new()
		label.text = _item_display_name(item)
		label.add_theme_color_override("font_color", TRADE_TEXT)
		label.add_theme_font_size_override("font_size", 12)
		identity.add_child(label)

		var item_meta := Label.new()
		item_meta.text = _t("ui.trade.items.owned", {
			"category": str(item.get("category", "item")).replace("-", " ").capitalize(),
			"count": int(item.get("quantity", 0)),
		})
		item_meta.add_theme_color_override("font_color", TRADE_MUTED)
		item_meta.add_theme_font_size_override("font_size", 9)
		identity.add_child(item_meta)

		var quantity_caption := Label.new()
		_set_localized_property(quantity_caption, "text", "ui.trade.items.quantity")
		quantity_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity_caption.add_theme_color_override("font_color", TRADE_MUTED)
		quantity_caption.add_theme_font_size_override("font_size", 9)
		row.add_child(quantity_caption)

		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = mini(int(item.get("quantity", 1)), 999)
		quantity.step = 1
		quantity.value = clampi(int(selected_by_id.get(item_id, 1)), 1, int(quantity.max_value))
		quantity.update_on_text_changed = true
		quantity.custom_minimum_size.x = 90
		row.add_child(quantity)
		item_selector_rows[item_id] = {
			"enabled": enabled,
			"quantity": quantity,
			"row": row_panel,
			"searchText": ("%s %s %s" % [
				_item_display_name(item),
				item_id,
				item.get("category", ""),
			]).to_lower(),
		}
	_filter_item_selector_rows(item_selector_search.text)


func _apply_trade_checkbox_style(checkbox: CheckBox) -> void:
	checkbox.add_theme_icon_override("unchecked", _trade_checkbox_icon(false, false))
	checkbox.add_theme_icon_override("unchecked_hover", _trade_checkbox_icon(false, true))
	checkbox.add_theme_icon_override("unchecked_pressed", _trade_checkbox_icon(false, true))
	checkbox.add_theme_icon_override("checked", _trade_checkbox_icon(true, false))
	checkbox.add_theme_icon_override("checked_hover", _trade_checkbox_icon(true, true))
	checkbox.add_theme_icon_override("checked_pressed", _trade_checkbox_icon(true, true))


static func _trade_checkbox_icon(checked: bool, hovered: bool) -> ImageTexture:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	var border := Color("#62d7ff") if hovered or checked else Color("#42627d")
	var fill := Color("#1685a7") if checked else Color("#071321")
	for y in range(18):
		for x in range(18):
			var is_border := x < 2 or x > 15 or y < 2 or y > 15
			image.set_pixel(x, y, border if is_border else fill)
	if checked:
		var check_pixels := [Vector2i(4, 9), Vector2i(5, 10), Vector2i(6, 11), Vector2i(7, 12), Vector2i(8, 11), Vector2i(9, 10), Vector2i(10, 9), Vector2i(11, 8), Vector2i(12, 7), Vector2i(13, 6)]
		for point: Vector2i in check_pixels:
			image.set_pixelv(point, Color.WHITE)
			if point.y + 1 < 16:
				image.set_pixel(point.x, point.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(image)


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
		_show_error(_t("ui.trade.error.offer_required"))
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


func _clear_offer_slots(slots: Array[Control], accepts_drop: bool) -> void:
	for index in range(slots.size()):
		var slot := slots[index]
		_clear(slot)
		_render_empty_offer_slot(slot, index, accepts_drop)


func _render_offer_slot(slot: Control, pokemon: Dictionary, is_local: bool, position: int) -> void:
	_clear(slot)
	slot.add_theme_stylebox_override("panel", _trade_offer_slot_style(true))
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

	var slot_badge := Label.new()
	slot_badge.text = "%02d" % (position + 1)
	slot_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_badge.anchor_left = 0.0
	slot_badge.anchor_top = 0.0
	slot_badge.anchor_right = 0.0
	slot_badge.anchor_bottom = 0.0
	slot_badge.offset_left = 5
	slot_badge.offset_top = 4
	slot_badge.offset_right = 25
	slot_badge.offset_bottom = 18
	slot_badge.add_theme_font_size_override("font_size", 8)
	slot_badge.add_theme_color_override("font_color", TRADE_ACCENT)
	wrapper.add_child(slot_badge)

	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(66, 52)
	icon_button.icon = PokemonAssets.load_party_icon(_pokemon_species(pokemon), bool(pokemon.get("shiny", false)))
	icon_button.expand_icon = true
	icon_button.add_theme_constant_override("icon_max_width", 48)
	icon_button.flat = true
	icon_button.focus_mode = Control.FOCUS_NONE
	icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_button.add_theme_stylebox_override("normal", _panel_style(Color("#00000000"), Color("#00000000"), 4, 0))
	icon_button.add_theme_stylebox_override("hover", _panel_style(Color("#62d7ff12"), TRADE_ACCENT, 4, 1))
	icon_button.add_theme_stylebox_override("pressed", _panel_style(Color("#62d7ff20"), TRADE_ACCENT, 4, 1))
	icon_button.tooltip_text = _t("ui.trade.pokemon.open_summary", {
		"pokemon": _pokemon_label(pokemon),
	})
	icon_button.pressed.connect(_open_offer_summary.bind(pokemon, is_local))
	content.add_child(icon_button)
	var level_label := Label.new()
	level_label.text = _t("ui.trade.pokemon.level", {
		"level": maxi(int(pokemon.get("level", 1)), 1),
	})
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", TRADE_MUTED)
	level_label.add_theme_font_size_override("font_size", 11)
	content.add_child(level_label)
	if is_local and _local_offer_asset_count() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove_button := Button.new()
		remove_button.text = "×"
		_set_localized_property(remove_button, "tooltip_text", "ui.trade.pokemon.remove")
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	if candidates.size() <= 1:
		_show_error(_t("ui.trade.error.party_last"))
		return true
	var candidate := _candidate_by_party_slot(party_slot)
	if candidate.is_empty():
		_show_error(_t("ui.trade.error.pokemon_unavailable"))
		return true
	var pokemon_id := int(candidate.get("pokemonId", 0))
	var target_position := _offer_slot_at_position(workspace_position)
	var replacement := build_drop_replacement(selected_ids, pokemon_id, target_position, _offer_limit())
	if replacement == selected_ids:
		if pokemon_id not in selected_ids and selected_ids.size() >= _offer_limit():
			_show_error(_t("ui.trade.error.opponent_party_full"))
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
	phase_label.text = _t("ui.trade.phase.review" if locked else "ui.trade.phase.setup")
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
		_set_status(_t("ui.trade.status.ready_locked"))
	elif _opponent_receive_capacity() <= 0 and selected_item_offers.is_empty() and selected_money == 0:
		_set_status(_t("ui.trade.status.opponent_slot"))
	elif not _local_offer_nonempty():
		_set_status(_t("ui.trade.status.offer_required"))
	else:
		_set_status("")


func _render_participant_names() -> void:
	var user_id := _current_user_id()
	var local_name := _t("ui.trade.participant.you")
	var opponent_name := _t("ui.trade.participant.other_player")
	for participant_value: Variant in trade.get("participants", []):
		if not participant_value is Dictionary:
			continue
		var participant := participant_value as Dictionary
		var fallback := (
			_t("ui.trade.participant.you")
			if int(participant.get("userId", 0)) == user_id
			else _t("ui.trade.participant.other_player")
		)
		var display_name := participant_display_name(participant, fallback)
		if int(participant.get("userId", 0)) == user_id:
			local_name = display_name
		else:
			opponent_name = display_name
	local_offer_title_label.text = local_name
	opponent_offer_title_label.text = opponent_name


static func participant_display_name(participant: Dictionary, fallback: String) -> String:
	var display_name := str(participant.get("displayName", "")).strip_edges()
	if display_name != "":
		return display_name
	var username := str(participant.get("username", "")).strip_edges()
	return username if username != "" else fallback


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
	if review_give_list.get_child_count() == 0:
		_render_review_empty_state(review_give_list, _t("ui.trade.review.give_empty"))
	if review_receive_list.get_child_count() == 0:
		_render_review_empty_state(review_receive_list, _t("ui.trade.review.receive_empty"))
	review_trust_label.text = _t("ui.trade.review.changed")
	review_trust_label.tooltip_text = _t("ui.trade.review.tooltip")
	var local_confirmed := _local_participant_confirmed()
	confirm_button.visible = not local_confirmed
	confirm_button.disabled = mutation_in_flight or _connection_state_unresolved()
	confirmation_label.text = (
		_t("ui.trade.review.confirmed_waiting")
		if local_confirmed
		else _t("ui.trade.review.confirm_hint")
	)


func _confirm_trade() -> void:
	if mutation_in_flight or _connection_state_unresolved() or str(trade.get("status", "")) != "locked":
		return
	var review: Dictionary = trade.get("lockedReview", {}) if trade.get("lockedReview", {}) is Dictionary else {}
	mutation_in_flight = true
	confirm_button.disabled = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":_t("ui.trade.error.service_unavailable")}
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
				overlay.call("add_system_message", _t("ui.trade.completion.party_refresh_failed"))
	var result: Dictionary = trade.get("completionResult", {}) if trade.get("completionResult", {}) is Dictionary else {}
	var refresh: Dictionary = result.get("refresh", {}) if result.get("refresh", {}) is Dictionary else {}
	if bool(refresh.get("inventory", false)):
		var inventory_service := get_node_or_null("/root/InventoryService")
		var inventory_result: Dictionary = await inventory_service.load_inventory() if inventory_service != null else {"success":false,"error":_t("ui.trade.error.inventory_unavailable")}
		var overlay := get_tree().get_first_node_in_group("ui_overlay")
		if bool(inventory_result.get("success", false)):
			if overlay != null:
				overlay.set("bag_inventory_items", inventory_result.get("items", []).duplicate(true))
				overlay.set("bag_inventory_loaded", true)
		else:
			if overlay != null and overlay.has_method("add_system_message"):
				overlay.call("add_system_message", _t("ui.trade.completion.inventory_refresh_failed"))
	if bool(refresh.get("wallet", false)):
		var wallet_service := get_node_or_null("/root/PlayerWalletService")
		var wallet_result: Dictionary = await wallet_service.load_wallet() if wallet_service != null else {"success":false,"error":_t("ui.trade.error.wallet_unavailable")}
		var overlay := get_tree().get_first_node_in_group("ui_overlay")
		if bool(wallet_result.get("success", false)):
			wallet_service.apply_wallet_result(wallet_result)
			get_tree().call_group("ui_overlay", "refresh_money_display")
		elif overlay != null and overlay.has_method("add_system_message"):
			overlay.call("add_system_message", _t("ui.trade.completion.wallet_refresh_failed"))


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
			var item_label := _static_t("ui.trade.item.quantity_name", {
				"quantity": int(transfer_value.get("quantity", 0)),
				"name": _static_item_display_name(transfer_value),
			})
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
	if not removed.is_empty():
		removed_parts.append(_static_t("ui.trade.completion.from_party", {
			"assets": ", ".join(removed),
		}))
	if not removed_items.is_empty():
		removed_parts.append(_static_t("ui.trade.completion.from_inventory", {
			"assets": ", ".join(removed_items),
		}))
	if removed_money > 0:
		removed_parts.append(_static_t("ui.trade.completion.from_wallet", {
			"amount": format_money(removed_money),
		}))
	if not received.is_empty():
		received_parts.append(_static_t("ui.trade.completion.in_party", {
			"assets": ", ".join(received),
		}))
	if not received_items.is_empty():
		received_parts.append(_static_t("ui.trade.completion.in_inventory", {
			"assets": ", ".join(received_items),
		}))
	if received_money > 0:
		received_parts.append(_static_t("ui.trade.completion.in_wallet", {
			"amount": format_money(received_money),
		}))
	return {
		"removed": _static_t("ui.trade.completion.removed", {
			"assets": _static_join_parts(removed_parts),
		}),
		"received": _static_t("ui.trade.completion.received", {
			"assets": _static_join_parts(received_parts),
		}),
	}


static func _static_t(key: String, values: Dictionary = {}) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var localization_manager := tree.root.get_node_or_null("LocalizationManager") if tree != null else null
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


static func _static_item_display_name(item: Dictionary) -> String:
	var item_id := str(item.get("itemId", item.get("id", "")))
	var fallback := str(item.get("name", item_id))
	var tree := Engine.get_main_loop() as SceneTree
	var item_localization := tree.root.get_node_or_null("ItemLocalization") if tree != null else null
	if item_localization == null:
		return fallback
	return str(item_localization.call("display_name", item_id, fallback))


static func _static_species_display_name(species_id: String, fallback: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var content_localization := tree.root.get_node_or_null("ContentLocalization") if tree != null else null
	if content_localization == null:
		return fallback
	return str(content_localization.call("display_name", "species", species_id, fallback))


static func _static_join_parts(parts: Array[String]) -> String:
	if parts.size() < 2:
		return parts[0] if not parts.is_empty() else ""
	var final_part := parts[-1]
	var leading := parts.slice(0, parts.size() - 1)
	return _static_t("ui.trade.completion.join", {
		"leading": ", ".join(leading),
		"final": final_part,
	})


static func _completion_pokemon_name(value: Dictionary) -> String:
	var nickname := str(value.get("nickname", "")).strip_edges()
	var species_name := str(value.get("speciesName", "")).strip_edges()
	var species_id := str(value.get("speciesId", "Pokemon")).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	if species_name != "" and species_name != "<null>":
		return _static_species_display_name(species_id, species_name)
	var fallback := species_id if species_id != "" else "Pokemon"
	return _static_species_display_name(species_id, fallback)


func _leave_trade() -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":_t("ui.trade.error.service_unavailable")}
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
	_set_status(_t("ui.trade.status.disconnected", {"seconds": remaining}), true)


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
		panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE_RAISED, TRADE_BORDER, 7, 1))
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

		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.alignment = BoxContainer.ALIGNMENT_CENTER
		identity.add_theme_constant_override("separation", 1)
		row.add_child(identity)

		var label := Label.new()
		label.text = _pokemon_name(pokemon)
		label.add_theme_color_override("font_color", TRADE_TEXT)
		label.add_theme_font_size_override("font_size", 13)
		identity.add_child(label)

		var level_label := Label.new()
		level_label.text = _t("ui.trade.pokemon.level", {
			"level": maxi(int(pokemon.get("level", 1)), 1),
		})
		level_label.add_theme_color_override("font_color", TRADE_MUTED)
		level_label.add_theme_font_size_override("font_size", 10)
		identity.add_child(level_label)


func _add_review_items(target: VBoxContainer, values: Variant) -> void:
	if not values is Array:
		return
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 48
		panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SURFACE_RAISED, TRADE_BORDER, 7, 1))
		target.add_child(panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 11)
		margin.add_theme_constant_override("margin_top", 7)
		margin.add_theme_constant_override("margin_right", 11)
		margin.add_theme_constant_override("margin_bottom", 7)
		panel.add_child(margin)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)

		var mark := Label.new()
		mark.text = "◆"
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_color_override("font_color", TRADE_GOLD)
		mark.add_theme_font_size_override("font_size", 9)
		row.add_child(mark)

		var label := Label.new()
		label.text = _t("ui.trade.item.quantity_name", {
			"quantity": int(value.get("quantity", 0)),
			"name": _item_display_name(value),
		})
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TRADE_TEXT)
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)


func _add_review_money(target: VBoxContainer, amount: int) -> void:
	if amount <= 0:
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 48
	panel.add_theme_stylebox_override("panel", _trade_money_style())
	target.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var label := Label.new()
	label.text = _t("ui.trade.money.pokedollars", {"amount": format_money(amount)})
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TRADE_GOLD)
	label.add_theme_font_size_override("font_size", 12)
	margin.add_child(label)


func _render_review_empty_state(target: VBoxContainer, message: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 86)
	panel.add_theme_stylebox_override("panel", _panel_style(TRADE_SLOT, Color("#28496377"), 7, 1))
	target.add_child(panel)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(TRADE_MUTED.r, TRADE_MUTED.g, TRADE_MUTED.b, 0.68))
	label.add_theme_font_size_override("font_size", 11)
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
	if _is_stale_revision_error(result):
		return _t("ui.trade.error.stale")
	if is_inside_tree():
		var error_localization := get_node_or_null("/root/BackendErrorLocalization")
		if error_localization != null:
			return str(error_localization.call(
				"message",
				result,
				"ui.trade.error.update_offer"
			))
	return _t("ui.trade.error.update_offer")


func _show_error(message: String, persist_for_offer: bool = false) -> void:
	if persist_for_offer:
		persistent_offer_error = message
	_set_status(message)


func _clear_persistent_offer_error() -> void:
	persistent_offer_error = ""


func _set_status(message: String, override_persistent_error: bool = false) -> void:
	var visible_message := (
		persistent_offer_error
		if not override_persistent_error and not persistent_offer_error.is_empty()
		else message
	)
	status_label.text = visible_message
	status_panel.visible = visible_message.strip_edges() != ""


func _item_display_name(item: Dictionary) -> String:
	var item_id := str(item.get("itemId", item.get("id", "")))
	var fallback := str(item.get("name", item_id))
	if not is_inside_tree():
		return fallback
	var item_localization := get_node_or_null("/root/ItemLocalization")
	if item_localization == null:
		return fallback
	return str(item_localization.call("display_name", item_id, fallback))


func _species_display_name(species_id: String, fallback: String) -> String:
	if not is_inside_tree():
		return fallback
	var content_localization := get_node_or_null("/root/ContentLocalization")
	if content_localization == null:
		return fallback
	return str(content_localization.call("display_name", "species", species_id, fallback))


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	if not is_inside_tree():
		return key.format(values)
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _on_locale_changed(_locale: String) -> void:
	title = _t("ui.trade.title")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	if item_selector_list != null and is_instance_valid(item_selector_list):
		_rebuild_item_selector_rows()
	if not trade.is_empty():
		_render_participant_names()
		_sync_selected_from_offer()
		_render_offers()
		_render_mode()


func _pokemon_label(value: Variant) -> String:
	var pokemon: Dictionary = value if value is Dictionary else {}
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	var species_name := str(pokemon.get("speciesName", "")).strip_edges()
	var species_id := str(pokemon.get("speciesId", "")).strip_edges()
	var name := nickname if nickname != "" and nickname != "<null>" else species_name
	if name == "" or name == "<null>":
		name = species_id if species_id != "" else "Pokemon"
	elif nickname == "" or nickname == "<null>":
		name = _species_display_name(species_id, name)
	return "%s  Lv. %d" % [name, maxi(int(pokemon.get("level", 1)), 1)]


func _pokemon_name(value: Dictionary) -> String:
	var nickname := str(value.get("nickname", "")).strip_edges()
	var species_name := str(value.get("speciesName", "")).strip_edges()
	var species_id := str(value.get("speciesId", value.get("species", "Pokemon"))).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	if species_name != "" and species_name != "<null>":
		return _species_display_name(species_id, species_name)
	var fallback := species_id if species_id != "" else "Pokemon"
	return _species_display_name(species_id, fallback)


func _pokemon_species(value: Dictionary) -> String:
	return str(value.get("speciesId", value.get("species", value.get("speciesName", ""))))


func _current_user_id() -> int:
	if not is_inside_tree():
		return 0
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
