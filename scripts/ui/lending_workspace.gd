extends Window

class_name LendingWorkspaceNode

signal return_requests_changed(requests: Array)

const LoanInvitationDialogScript := preload("res://scripts/ui/loan_invitation_dialog.gd")
const AetherConfirmationDialogScene := preload("res://scenes/interface/aether_confirmation_dialog.tscn")

const WINDOW_SIZE := Vector2i(900, 640)
const BG := Color("#050912fa")
const SURFACE := Color("#081522f7")
const BORDER := Color("#2d4b66b3")
const ACCENT := Color("#62d7ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")
const GOLD := Color("#d8b767")
const INCOMING_POLL_SECONDS := 5.0
const DEADLINE_REFRESH_SECONDS := 30.0
const HISTORY_SEARCH_DELAY_SECONDS := 0.35
const INVALID_DEADLINE_SECONDS := -2147483648

var target_username := ""
var capabilities: Dictionary = {}
var loans: Array = []
var party_candidates: Array[Dictionary] = []
var pokemon_boxes: Array[Dictionary] = []
var box_candidates: Array[Dictionary] = []
var inventory_candidates: Array[Dictionary] = []
var selected_pokemon: Dictionary = {}
var selected_items: Dictionary = {}
var mutation_in_flight := false
var incoming_poll_in_flight := false
var notification_poll_in_flight := false
var incoming_dialog: Window
var last_incoming_signature := ""
var incoming_account_generation := 0
var displayed_notification_ids: Dictionary = {}
var pending_return_requests: Array[Dictionary] = []
var pending_return_request_signature := ""
var focused_return_asset_id := ""
var pokemon_source_mode := 0
var selected_box_index := 0
var pokemon_search_query := ""
var loan_asset_mode := "pokemon"
var loan_overview_asset_type := "pokemon"
var loan_overview_view := "borrowed"
var loan_counts: Dictionary = {}
var loan_timing_rows: Array[Dictionary] = []
var history_search_query := ""
var history_status_filter := ""
var history_period_filter := "30"
var history_date_from := ""
var history_date_to := ""

var target_display_label: Label
var duration_select: OptionButton
var fee_input: SpinBox
var assets_list: VBoxContainer
var loans_list: VBoxContainer
var loans_scroll: ScrollContainer
var view_select: OptionButton
var status_label: Label
var subtitle_label: Label
var create_button: Button
var usage_label: Label
var compose_panel: Control
var loans_panel: Control
var pokemon_results_list: VBoxContainer
var loan_type_tabs: HBoxContainer
var history_tools: HBoxContainer
var history_search_input: LineEdit
var history_filter_button: Button
var history_search_timer: Timer


func _ready() -> void:
	hide()
	add_to_group("aether_clash_exchange_surface")
	title = _t("ui.lending.title")
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	size = WINDOW_SIZE
	unresizable = true
	borderless = true
	_build_ui()
	_setup_incoming_offers()
	_setup_deadline_refresh()
	close_requested.connect(hide)


func clear_account_state() -> void:
	hide()
	loans.clear()
	party_candidates.clear()
	pokemon_boxes.clear()
	box_candidates.clear()
	inventory_candidates.clear()
	selected_pokemon.clear()
	selected_items.clear()
	target_username = ""
	loan_overview_view = "borrowed"
	loan_overview_asset_type = "pokemon"
	loan_counts.clear()
	history_search_query = ""
	history_status_filter = ""
	history_period_filter = "30"
	history_date_from = ""
	history_date_to = ""
	if history_search_input != null:
		history_search_input.text = ""
	_update_history_controls()
	last_incoming_signature = ""
	displayed_notification_ids.clear()
	pending_return_requests.clear()
	pending_return_request_signature = ""
	focused_return_asset_id = ""
	return_requests_changed.emit([])
	incoming_account_generation += 1
	if incoming_dialog != null and incoming_dialog.has_method("clear_offers"):
		incoming_dialog.call("clear_offers")


func open_for_trainer(username: String) -> void:
	if _aether_clash_exchange_blocked():
		return
	target_username = username.strip_edges()
	_set_workspace_mode(true)
	if target_display_label != null:
		target_display_label.text = _t("ui.lending.compose_target", {"trainer": target_username})
	popup_centered(WINDOW_SIZE)
	await refresh_all()


func open_loans() -> void:
	target_username = ""
	_set_workspace_mode(false)
	loan_overview_view = "borrowed"
	if view_select != null:
		view_select.select(0)
	_refresh_loan_usage()
	popup_centered(WINDOW_SIZE)
	await refresh_all()


func open_return_requests() -> void:
	target_username = ""
	_set_workspace_mode(false)
	loan_overview_view = "borrowed"
	_select_overview_view("borrowed")
	if not pending_return_requests.is_empty():
		var request: Dictionary = pending_return_requests[0]
		focused_return_asset_id = str(request.get("assetId", ""))
		loan_overview_asset_type = "items" if str(request.get("assetType", "")) == "item" else "pokemon"
	_render_loan_type_tabs()
	_refresh_loan_usage()
	popup_centered(WINDOW_SIZE)
	await refresh_all()


func current_return_requests() -> Array[Dictionary]:
	return pending_return_requests.duplicate(true)


func _select_overview_view(view: String) -> void:
	if view_select == null:
		return
	for index in range(view_select.item_count):
		if str(view_select.get_item_metadata(index)) == view:
			view_select.select(index)
			return


func refresh_all() -> void:
	status_label.text = _t("ui.lending.status.loading")
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		_show_error(_t("ui.lending.error.unavailable"))
		return
	var capability_result: Dictionary = await service.load_capabilities()
	if not bool(capability_result.get("success", false)):
		_show_error(str(capability_result.get("error", _t("ui.lending.error.unavailable"))))
		return
	capabilities = capability_result.get("capabilities", {}).duplicate(true)
	if not bool(capabilities.get("enabled", false)):
		_show_error(_t("ui.lending.error.disabled"))
		create_button.disabled = true
		return
	if compose_panel.visible:
		_populate_durations()
		await _refresh_assets()
	else:
		await _refresh_loans()
	status_label.text = _t("ui.lending.status.ready")


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _style(BG, ACCENT, 12))
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var heading_label := Label.new()
	heading_label.text = _t("ui.lending.title")
	heading_label.add_theme_font_size_override("font_size", 21)
	heading_label.add_theme_color_override("font_color", TEXT)
	heading.add_child(heading_label)
	subtitle_label = Label.new()
	subtitle_label.text = _t("ui.lending.subtitle")
	subtitle_label.add_theme_color_override("font_color", MUTED)
	heading.add_child(subtitle_label)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(40, 36)
	close.pressed.connect(hide)
	_apply_button_style(close, "danger")
	header.add_child(close)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED)
	root.add_child(status_label)

	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.split_offset = 430
	root.add_child(columns)
	compose_panel = _build_compose_panel()
	columns.add_child(compose_panel)
	loans_panel = _build_loans_panel()
	columns.add_child(loans_panel)


func _build_compose_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(410, 0)
	panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 9))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(_section_label(_t("ui.lending.compose")))
	var target_panel := PanelContainer.new()
	target_panel.add_theme_stylebox_override("panel", _input_style(Color("#07111df5"), ACCENT))
	root.add_child(target_panel)
	target_display_label = Label.new()
	target_display_label.text = _t("ui.lending.compose_target", {"trainer": target_username})
	target_display_label.add_theme_color_override("font_color", TEXT)
	target_display_label.add_theme_font_size_override("font_size", 13)
	target_panel.add_child(target_display_label)
	var terms := HBoxContainer.new()
	terms.add_theme_constant_override("separation", 8)
	root.add_child(terms)
	duration_select = OptionButton.new()
	duration_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_option_style(duration_select)
	terms.add_child(duration_select)
	fee_input = SpinBox.new()
	fee_input.min_value = 0
	fee_input.max_value = 2147483647
	fee_input.prefix = "₽"
	fee_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_spinbox_style(fee_input)
	terms.add_child(fee_input)
	var hint := Label.new()
	hint.text = _t("ui.lending.ownership_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", GOLD)
	root.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	assets_list = VBoxContainer.new()
	assets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assets_list.add_theme_constant_override("separation", 4)
	scroll.add_child(assets_list)
	create_button = Button.new()
	create_button.text = _t("ui.lending.create")
	create_button.custom_minimum_size = Vector2(0, 40)
	create_button.pressed.connect(_create_loan)
	_apply_button_style(create_button, "primary")
	root.add_child(create_button)
	return panel


func _build_loans_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 9))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	root.add_child(tools)
	view_select = OptionButton.new()
	for view: String in ["borrowed", "lent", "history"]:
		view_select.add_item(_t("ui.lending.view.%s" % view))
		view_select.set_item_metadata(view_select.item_count - 1, view)
	view_select.select(0)
	view_select.item_selected.connect(_on_loan_overview_view_selected)
	view_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_option_style(view_select)
	tools.add_child(view_select)
	var refresh := Button.new()
	refresh.text = _t("common.refresh")
	refresh.pressed.connect(refresh_all)
	_apply_button_style(refresh)
	tools.add_child(refresh)
	history_tools = HBoxContainer.new()
	history_tools.add_theme_constant_override("separation", 8)
	root.add_child(history_tools)
	history_search_input = LineEdit.new()
	history_search_input.placeholder_text = _t("ui.lending.history.search_placeholder")
	history_search_input.clear_button_enabled = true
	history_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_search_input.custom_minimum_size.y = 36
	history_search_input.text_changed.connect(_on_history_search_changed)
	history_search_input.text_submitted.connect(_submit_history_search)
	_apply_line_edit_style(history_search_input)
	history_tools.add_child(history_search_input)
	history_filter_button = Button.new()
	history_filter_button.pressed.connect(_open_history_filter)
	_apply_button_style(history_filter_button)
	history_tools.add_child(history_filter_button)
	history_search_timer = Timer.new()
	history_search_timer.one_shot = true
	history_search_timer.wait_time = HISTORY_SEARCH_DELAY_SECONDS
	history_search_timer.timeout.connect(_refresh_history_search)
	add_child(history_search_timer)
	_update_history_controls()
	loan_type_tabs = HBoxContainer.new()
	loan_type_tabs.add_theme_constant_override("separation", 6)
	root.add_child(loan_type_tabs)
	_render_loan_type_tabs()
	usage_label = Label.new()
	usage_label.add_theme_color_override("font_color", MUTED)
	usage_label.add_theme_font_size_override("font_size", 10)
	root.add_child(usage_label)
	loans_scroll = ScrollContainer.new()
	loans_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(loans_scroll)
	loans_list = VBoxContainer.new()
	loans_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loans_list.add_theme_constant_override("separation", 7)
	loans_scroll.add_child(loans_list)
	return panel


func _refresh_assets() -> void:
	selected_pokemon.clear()
	selected_items.clear()
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	var storage_service := get_node_or_null("/root/PokemonStorageService")
	var inventory_service := get_node_or_null("/root/InventoryService")
	var party_result: Dictionary = await party_service.load_party() if party_service != null else {"success": false}
	var boxes_result: Dictionary = await storage_service.load_boxes() if storage_service != null else {"success": false}
	var inventory_result: Dictionary = await inventory_service.load_inventory() if inventory_service != null else {"success": false}
	party_candidates = _party_candidates(party_result.get("party", [])) if bool(party_result.get("success", false)) else []
	pokemon_boxes = _pokemon_boxes(boxes_result.get("boxes", [])) if bool(boxes_result.get("success", false)) else []
	box_candidates = _box_candidates(pokemon_boxes)
	inventory_candidates = _item_candidates(inventory_result.get("items", [])) if bool(inventory_result.get("success", false)) else []
	_render_assets()


func _render_assets() -> void:
	_clear(assets_list)
	var type_tabs := HBoxContainer.new()
	type_tabs.add_theme_constant_override("separation", 6)
	assets_list.add_child(type_tabs)
	for mode in ["pokemon", "items"]:
		var type_button := Button.new()
		type_button.text = _t("ui.lending.offer_type.%s" % mode)
		type_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		type_button.custom_minimum_size.y = 38
		type_button.pressed.connect(_request_asset_mode.bind(mode))
		_apply_button_style(type_button, "primary" if loan_asset_mode == mode else "secondary")
		type_tabs.add_child(type_button)
	if create_button != null:
		create_button.text = _t("ui.lending.create_%s" % loan_asset_mode)
	if loan_asset_mode == "items":
		_render_item_offer_assets()
		return
	assets_list.add_child(_section_label(_t("ui.lending.assets.pokemon")))
	var source_tools := HBoxContainer.new()
	source_tools.add_theme_constant_override("separation", 6)
	assets_list.add_child(source_tools)
	var source_select := OptionButton.new()
	source_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_select.add_item(_t("ui.lending.source.party"))
	source_select.add_item(_t("ui.lending.source.boxes"))
	source_select.select(clampi(pokemon_source_mode, 0, 1))
	source_select.item_selected.connect(func(index: int):
		pokemon_source_mode = index
		_render_assets()
	)
	_apply_option_style(source_select)
	source_tools.add_child(source_select)
	var box_select := OptionButton.new()
	box_select.visible = pokemon_source_mode == 1
	box_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for box_value: Variant in pokemon_boxes:
		if not box_value is Dictionary:
			continue
		var box: Dictionary = box_value
		var box_index := int(box.get("boxIndex", box_select.item_count))
		var box_name := str(box.get("name", "")).strip_edges()
		box_select.add_item(box_name if box_name != "" else _t("ui.lending.source.box", {"number": box_index + 1}))
		box_select.set_item_metadata(box_select.item_count - 1, box_index)
		if box_index == selected_box_index:
			box_select.select(box_select.item_count - 1)
	box_select.item_selected.connect(func(index: int):
		selected_box_index = int(box_select.get_item_metadata(index))
		_render_assets()
	)
	_apply_option_style(box_select)
	source_tools.add_child(box_select)
	var search_input := LineEdit.new()
	search_input.visible = pokemon_source_mode == 1
	search_input.placeholder_text = _t("ui.lending.source.search")
	search_input.text = pokemon_search_query
	search_input.clear_button_enabled = true
	search_input.custom_minimum_size.y = 36
	search_input.text_changed.connect(_on_pokemon_search_changed)
	_apply_line_edit_style(search_input)
	assets_list.add_child(search_input)
	var party_hint := Label.new()
	party_hint.text = _t("ui.lending.party_required_hint")
	party_hint.visible = pokemon_source_mode == 0
	party_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party_hint.add_theme_color_override("font_color", GOLD)
	party_hint.add_theme_font_size_override("font_size", 10)
	assets_list.add_child(party_hint)
	pokemon_results_list = VBoxContainer.new()
	pokemon_results_list.add_theme_constant_override("separation", 6)
	assets_list.add_child(pokemon_results_list)
	_render_pokemon_candidate_results()


func _render_item_offer_assets() -> void:
	assets_list.add_child(_section_label(_t("ui.lending.assets.items")))
	var item_hint := Label.new()
	item_hint.text = _t("ui.lending.items_hint")
	item_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_hint.add_theme_color_override("font_color", GOLD)
	item_hint.add_theme_font_size_override("font_size", 10)
	assets_list.add_child(item_hint)
	for item: Dictionary in inventory_candidates:
		var item_id := str(item.get("itemId", ""))
		assets_list.add_child(_item_candidate_row(item, "bag:%s" % item_id))
	var held_candidates := _held_item_candidates()
	for held: Dictionary in held_candidates:
		var pokemon_id := int(held.get("pokemonId", 0))
		var held_item_id := str(held.get("heldItemId", ""))
		assets_list.add_child(_item_candidate_row({
			"itemId": held_item_id,
			"name": _item_display_name(held_item_id, held_item_id),
			"quantity": 1,
			"holderName": str(held.get("name", "Pokémon")),
		}, "held:%d" % pokemon_id, true))
	if inventory_candidates.is_empty() and held_candidates.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.lending.items_empty")
		empty.add_theme_color_override("font_color", MUTED)
		assets_list.add_child(empty)


func _request_asset_mode(mode: String) -> void:
	if mode == loan_asset_mode:
		return
	var has_selection := not selected_pokemon.is_empty() if loan_asset_mode == "pokemon" else not selected_items.is_empty()
	if not has_selection:
		_set_asset_mode(mode)
		return
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	dialog.configure(
		_t("ui.lending.offer_type.change_title"),
		_t("ui.lending.offer_type.change_text"),
		_t("ui.lending.offer_type.change_confirm"),
		_t("common.cancel")
	)
	dialog.confirmed.connect(_set_asset_mode.bind(mode), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(500, 230))


func _set_asset_mode(mode: String) -> void:
	loan_asset_mode = "items" if mode == "items" else "pokemon"
	selected_pokemon.clear()
	selected_items.clear()
	_render_assets()


func _on_pokemon_search_changed(value: String) -> void:
	pokemon_search_query = value.strip_edges()
	_render_pokemon_candidate_results()


func _render_pokemon_candidate_results() -> void:
	if pokemon_results_list == null:
		return
	_clear(pokemon_results_list)
	var visible_candidates := _visible_pokemon_candidates()
	if visible_candidates.is_empty():
		var empty := Label.new()
		if pokemon_source_mode == 0:
			empty.text = _t("ui.lending.source.empty_party")
		elif pokemon_search_query != "":
			empty.text = _t("ui.lending.source.no_search_results")
		else:
			empty.text = _t("ui.lending.source.empty_box")
		empty.add_theme_color_override("font_color", MUTED)
		pokemon_results_list.add_child(empty)
	for candidate: Dictionary in visible_candidates:
		var pokemon_id := int(candidate.get("pokemonId", 0))
		pokemon_results_list.add_child(_pokemon_candidate_row(candidate, pokemon_id))


func _visible_pokemon_candidates() -> Array[Dictionary]:
	if pokemon_source_mode == 0:
		return party_candidates
	var query := pokemon_search_query.to_lower()
	if query == "":
		return _box_candidates_for_index(selected_box_index)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in box_candidates:
		var searchable := "%s %s" % [str(candidate.get("name", "")), str(candidate.get("speciesId", ""))]
		if query in searchable.to_lower():
			result.append(candidate)
	return result


func _held_item_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for candidate: Dictionary in party_candidates + box_candidates:
		var pokemon_id := int(candidate.get("pokemonId", 0))
		var item_id := str(candidate.get("heldItemId", ""))
		if pokemon_id <= 0 or item_id == "" or seen.has(pokemon_id):
			continue
		seen[pokemon_id] = true
		result.append(candidate)
	return result


func _refresh_loans() -> void:
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		return
	var statuses: Array[String] = []
	if loan_overview_view == "history" and history_status_filter != "":
		statuses.append(history_status_filter)
	var result: Dictionary = await service.load_loans(
		loan_overview_view,
		100 if loan_overview_view == "history" else 50,
		0,
		history_search_query if loan_overview_view == "history" else "",
		statuses,
		int(history_period_filter) if loan_overview_view == "history" and history_period_filter != "custom" else 0,
		history_date_from if loan_overview_view == "history" and history_period_filter == "custom" else "",
		history_date_to if loan_overview_view == "history" and history_period_filter == "custom" else ""
	)
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.load"))))
		return
	var body: Dictionary = result.get("body", {})
	loans = []
	for value: Variant in body.get("loans", []):
		if not value is Dictionary:
			continue
		var loan: Dictionary = value
		if loan_overview_view != "history" and str(loan.get("status", "")) in ["returned", "declined", "cancelled", "expired"]:
			continue
		loans.append(loan.duplicate(true))
	loan_counts = body.duplicate(true)
	_refresh_loan_usage()
	_render_loans()


func _render_loans() -> void:
	_clear(loans_list)
	loan_timing_rows.clear()
	var visible_loans := _loans_for_asset_type(loan_overview_asset_type)
	if visible_loans.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.lending.empty.%s.%s" % [loan_overview_view, loan_overview_asset_type])
		empty.add_theme_color_override("font_color", MUTED)
		loans_list.add_child(empty)
		return
	var current_user_id := _current_user_id()
	for value: Variant in visible_loans:
		if not value is Dictionary:
			continue
		var loan: Dictionary = value
		var status := str(loan.get("status", ""))
		var is_borrower := int(loan.get("borrowerUserId", 0)) == current_user_id
		var assets: Array = loan.get("assets", []) if loan.get("assets", []) is Array else []
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("#050d18f2"), _status_color(status, true), 8))
		var margin := MarginContainer.new()
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 11)
		card.add_child(margin)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 7)
		margin.add_child(stack)
		var lender := str(loan.get("lenderUsername", "")).strip_edges()
		if lender == "":
			lender = str(loan.get("lenderGuildName", "Guild"))
		var borrower := str(loan.get("borrowerUsername", "Trainer"))
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		stack.add_child(header)
		var title_label := Label.new()
		title_label.text = _t("ui.lending.card.borrowed_from" if is_borrower else "ui.lending.card.lent_to", {"trainer": lender if is_borrower else borrower})
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.add_theme_color_override("font_color", TEXT)
		title_label.add_theme_font_size_override("font_size", 14)
		header.add_child(title_label)
		header.add_child(_status_badge(status))
		var pokemon_count := 0
		var item_count := 0
		for asset: Variant in assets:
			if asset is Dictionary and str(asset.get("assetType", "")) == "pokemon": pokemon_count += 1
			elif asset is Dictionary: item_count += 1
		var details := Label.new()
		details.text = _loan_terms_text(pokemon_count, item_count, int(loan.get("feeAmount", 0)), int(loan.get("durationSeconds", 0)))
		details.add_theme_font_size_override("font_size", 10)
		details.add_theme_color_override("font_color", MUTED)
		stack.add_child(details)
		var timing := Label.new()
		timing.text = _loan_timing_text(loan)
		timing.add_theme_font_size_override("font_size", 10)
		timing.add_theme_color_override("font_color", _status_color(status))
		stack.add_child(timing)
		loan_timing_rows.append({"label": timing, "loan": loan.duplicate(true)})
		var asset_stack := VBoxContainer.new()
		asset_stack.add_theme_constant_override("separation", 4)
		stack.add_child(asset_stack)
		if not assets.is_empty():
			asset_stack.add_child(_section_label(_loan_contents_title(pokemon_count, item_count)))
		var visible_asset_index := 0
		for asset_value: Variant in assets:
			if asset_value is Dictionary:
				visible_asset_index += 1
				asset_stack.add_child(_loan_asset_row(asset_value, is_borrower, status, str(loan.get("loanId", "")), visible_asset_index, assets.size()))
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 6)
		stack.add_child(actions)
		if status == "pending" and is_borrower:
			_add_action(actions, _t("common.decline"), _loan_action.bind("decline", str(loan.get("loanId", ""))))
			_add_action(actions, _t("common.accept"), _loan_action.bind("accept", str(loan.get("loanId", ""))))
		elif status == "pending":
			_add_action(actions, _t("common.cancel"), _loan_action.bind("cancel", str(loan.get("loanId", ""))))
		loans_list.add_child(card)
	_focus_requested_asset.call_deferred()


func _focus_requested_asset() -> void:
	if focused_return_asset_id == "" or loans_list == null or loans_scroll == null:
		return
	var row := loans_list.find_child("ReturnRequest_%s" % focused_return_asset_id, true, false) as Control
	if row == null:
		return
	loans_scroll.ensure_control_visible(row)
	row.grab_focus()


func _on_loan_overview_view_selected(index: int) -> void:
	loan_overview_view = str(view_select.get_item_metadata(index))
	_update_history_controls()
	await _refresh_loans()


func _on_history_search_changed(value: String) -> void:
	history_search_query = value.strip_edges()
	if loan_overview_view == "history" and history_search_timer != null:
		history_search_timer.start()


func _refresh_history_search() -> void:
	if loan_overview_view == "history":
		await _refresh_loans()


func _submit_history_search(_value: String) -> void:
	if history_search_timer != null:
		history_search_timer.stop()
	if loan_overview_view == "history":
		await _refresh_loans()


func _open_history_filter() -> void:
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	dialog.configure(
		_t("ui.lending.history.filter_title"),
		_t("ui.lending.history.filter_description"),
		_t("ui.lending.history.apply_filter"),
		_t("common.cancel")
	)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.add_child(_section_label(_t("ui.lending.history.outcome")))
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(0, 38)
	for status: String in ["", "returned", "expired", "declined", "cancelled"]:
		selector.add_item(_t("ui.lending.history.filter_all") if status == "" else _t("ui.lending.status.%s" % status))
		selector.set_item_metadata(selector.item_count - 1, status)
		if status == history_status_filter:
			selector.select(selector.item_count - 1)
	_apply_option_style(selector)
	controls.add_child(selector)
	controls.add_child(_section_label(_t("ui.lending.history.period")))
	var period_selector := OptionButton.new()
	period_selector.custom_minimum_size = Vector2(0, 38)
	for period: String in ["1", "7", "14", "30", "custom"]:
		period_selector.add_item(_t("ui.lending.history.period.%s" % period))
		period_selector.set_item_metadata(period_selector.item_count - 1, period)
		if period == history_period_filter:
			period_selector.select(period_selector.item_count - 1)
	_apply_option_style(period_selector)
	controls.add_child(period_selector)
	var custom_dates := HBoxContainer.new()
	custom_dates.add_theme_constant_override("separation", 8)
	var from_input := LineEdit.new()
	from_input.placeholder_text = _t("ui.lending.history.date_from_placeholder")
	from_input.text = history_date_from if history_date_from != "" else _history_date_days_ago(29)
	from_input.max_length = 10
	from_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_line_edit_style(from_input)
	custom_dates.add_child(from_input)
	var to_input := LineEdit.new()
	to_input.placeholder_text = _t("ui.lending.history.date_to_placeholder")
	to_input.text = history_date_to if history_date_to != "" else _history_date_days_ago(0)
	to_input.max_length = 10
	to_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_line_edit_style(to_input)
	custom_dates.add_child(to_input)
	custom_dates.visible = history_period_filter == "custom"
	period_selector.item_selected.connect(func(index: int):
		custom_dates.visible = str(period_selector.get_item_metadata(index)) == "custom"
	)
	controls.add_child(custom_dates)
	dialog.add_custom_control(controls)
	dialog.confirmed.connect(func():
		var selected_period := str(period_selector.get_item_metadata(period_selector.selected))
		var selected_from := from_input.text.strip_edges()
		var selected_to := to_input.text.strip_edges()
		if selected_period == "custom" and (
			not _history_date_is_valid(selected_from)
			or not _history_date_is_valid(selected_to)
			or selected_from > selected_to
		):
			_show_error(_t("ui.lending.history.date_invalid"))
			dialog.queue_free()
			return
		history_status_filter = str(selector.get_item_metadata(selector.selected))
		history_period_filter = selected_period
		if selected_period == "custom":
			history_date_from = selected_from
			history_date_to = selected_to
		_update_history_controls()
		await _refresh_loans()
		dialog.queue_free()
	, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(560, 420))


func _update_history_controls() -> void:
	if history_tools == null:
		return
	history_tools.visible = loan_overview_view == "history"
	if history_filter_button != null:
		var period_text := _history_period_label()
		history_filter_button.text = (
			_t("ui.lending.history.filter_period", {"period": period_text})
			if history_status_filter == ""
			else _t("ui.lending.history.filter_period_status", {
				"period": period_text,
				"status": _t("ui.lending.status.%s" % history_status_filter),
			})
		)


func _history_period_label() -> String:
	if history_period_filter == "custom":
		return _t("ui.lending.history.custom_range", {
			"from": history_date_from,
			"to": history_date_to,
		})
	return _t("ui.lending.history.period.%s" % history_period_filter)


func _history_date_days_ago(days_ago: int) -> String:
	var timestamp := int(Time.get_unix_time_from_system()) - maxi(days_ago, 0) * 86400
	var value := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d" % [int(value.get("year", 0)), int(value.get("month", 0)), int(value.get("day", 0))]


func _history_date_is_valid(value: String) -> bool:
	var parts := value.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1970 or month < 1 or month > 12 or day < 1:
		return false
	var month_days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var is_leap_year := year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)
	if is_leap_year:
		month_days[1] = 29
	return day <= month_days[month - 1]


func _render_loan_type_tabs() -> void:
	if loan_type_tabs == null:
		return
	_clear(loan_type_tabs)
	for asset_type: String in ["pokemon", "items"]:
		var button := Button.new()
		button.text = _t("ui.lending.overview_tab.%s" % asset_type)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 38
		button.pressed.connect(_set_loan_overview_asset_type.bind(asset_type))
		_apply_button_style(button, "primary" if loan_overview_asset_type == asset_type else "secondary")
		loan_type_tabs.add_child(button)


func _set_loan_overview_asset_type(asset_type: String) -> void:
	var normalized := "items" if asset_type == "items" else "pokemon"
	if normalized == loan_overview_asset_type:
		return
	loan_overview_asset_type = normalized
	_render_loan_type_tabs()
	_refresh_loan_usage()
	_render_loans()


func _loans_for_asset_type(asset_type: String) -> Array[Dictionary]:
	var expected_type := "item" if asset_type == "items" else "pokemon"
	var result: Array[Dictionary] = []
	for loan: Dictionary in loans:
		var assets: Array = loan.get("assets", []) if loan.get("assets", []) is Array else []
		if assets.any(func(asset: Variant): return asset is Dictionary and str(asset.get("assetType", "")) == expected_type):
			result.append(loan)
	return result


func _refresh_loan_usage() -> void:
	if usage_label == null:
		return
	var is_items := loan_overview_asset_type == "items"
	var count_key := (
		("borrowedItems" if is_items else "borrowedPokemon")
		if loan_overview_view != "lent"
		else ("lentItems" if is_items else "lentPokemon")
	)
	var count := int(loan_counts.get(count_key, 0))
	if loan_overview_view == "history":
		usage_label.text = "%s · %s" % [
			_t("ui.lending.usage.history.%s" % loan_overview_asset_type),
			_history_period_label(),
		]
	elif loan_overview_view == "borrowed":
		var limits: Dictionary = loan_counts.get("limits", {}) if loan_counts.get("limits", {}) is Dictionary else {}
		usage_label.text = _t("ui.lending.usage.borrowed.%s" % loan_overview_asset_type, {
			"count": count,
			"limit": int(limits.get(count_key, 6)),
		})
	else:
		usage_label.text = _t("ui.lending.usage.lent.%s" % loan_overview_asset_type, {"count": count})


func _loan_asset_row(asset: Dictionary, is_borrower: bool, loan_status: String, loan_id: String, asset_index: int, asset_total: int) -> Control:
	var snapshot: Dictionary = asset.get("snapshot", {}) if asset.get("snapshot", {}) is Dictionary else {}
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#091725e8"), Color("#203b52"), 6))
	var asset_id := str(asset.get("assetId", ""))
	if asset_id != "" and asset_id == focused_return_asset_id:
		panel.name = "ReturnRequest_%s" % asset_id
		panel.focus_mode = Control.FOCUS_ALL
		var focus_style := _style(Color("#18200df2"), GOLD, 7)
		focus_style.border_width_left = 2
		focus_style.border_width_top = 2
		focus_style.border_width_right = 2
		focus_style.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", focus_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var asset_type := str(asset.get("assetType", ""))
	var asset_status := str(asset.get("status", ""))
	var return_requested := _optional_string(asset.get("returnRequestedAt")) != ""
	if asset_type == "pokemon":
		var icon_button := Button.new()
		icon_button.custom_minimum_size = Vector2(42, 42)
		icon_button.icon = PokemonAssets.load_party_icon(str(snapshot.get("speciesId", snapshot.get("species", ""))), bool(snapshot.get("shiny", false)))
		icon_button.expand_icon = true
		icon_button.add_theme_constant_override("icon_max_width", 38)
		icon_button.tooltip_text = _t("ui.lending.invitation.view")
		icon_button.pressed.connect(_open_pokemon_summary.bind(snapshot))
		_apply_icon_button_style(icon_button)
		row.add_child(icon_button)
		var asset_name := _pokemon_display_name(snapshot)
		var identity := _loan_asset_identity(asset_name, _t("ui.lending.card.pokemon_meta", {"level": int(snapshot.get("level", 1)), "state": _asset_state_label(asset_status)}))
		row.add_child(identity)
		_add_asset_return_controls(row, asset, asset_name, is_borrower, loan_status, return_requested, loan_id)
		var view := Button.new()
		view.text = _t("ui.lending.invitation.view")
		view.pressed.connect(_open_pokemon_summary.bind(snapshot))
		_apply_button_style(view)
		row.add_child(view)
	else:
		var item_id := str(asset.get("itemId", snapshot.get("id", "")))
		var held_pokemon_id := _nullable_positive_int(asset.get("heldPokemonId"))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.texture = _load_item_icon(item_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var item_location := _t("ui.lending.card.item_equipped" if held_pokemon_id > 0 else "ui.lending.card.item_in_bag", {"state": _asset_state_label(asset_status)})
		var asset_name := _item_display_name(item_id, str(snapshot.get("name", item_id)))
		var identity := _loan_asset_identity(asset_name, _t("ui.lending.card.item_copy_meta", {
			"index": asset_index,
			"count": asset_total,
			"location": item_location,
		}))
		row.add_child(identity)
		var description := str(snapshot.get("short_desc", snapshot.get("description", ""))).strip_edges()
		if description != "":
			panel.tooltip_text = description
			icon.tooltip_text = description
		if is_borrower and loan_status in ["active", "return_pending"] and asset_status in ["active", "return_pending"]:
			var action := Button.new()
			action.text = _t("ui.lending.detach_item") if held_pokemon_id > 0 else _t("ui.lending.attach_item")
			action.disabled = mutation_in_flight
			if held_pokemon_id > 0:
				action.pressed.connect(_detach_loan_item.bind(str(asset.get("assetId", ""))))
			else:
				action.pressed.connect(_open_attach_menu.bind(str(asset.get("assetId", "")), item_id))
			_apply_button_style(action)
			row.add_child(action)
		_add_asset_return_controls(row, asset, asset_name, is_borrower, loan_status, return_requested, loan_id)
		var view := Button.new()
		view.text = _t("ui.lending.invitation.view")
		view.pressed.connect(_open_item_details.bind(asset))
		_apply_button_style(view)
		row.add_child(view)
	return panel


func _nullable_positive_int(value: Variant) -> int:
	if value == null:
		return 0
	return maxi(int(value), 0)


func _optional_string(value: Variant) -> String:
	return "" if value == null else str(value).strip_edges()


func _open_item_details(asset: Dictionary) -> void:
	var snapshot: Dictionary = asset.get("snapshot", {}) if asset.get("snapshot", {}) is Dictionary else {}
	var item_id := str(asset.get("itemId", snapshot.get("id", "")))
	var item_name := _item_display_name(item_id, str(snapshot.get("name", item_id)))
	var description := str(snapshot.get("description", snapshot.get("short_desc", ""))).strip_edges()
	if description == "":
		description = _t("ui.lending.item_details.no_description")
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	dialog.configure(
		item_name,
		description,
		_t("common.close"),
		""
	)
	dialog.cancel_button.visible = false
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.texture = _load_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_row.add_child(icon)
	var state := Label.new()
	state.text = _asset_state_label(str(asset.get("status", "active")))
	state.add_theme_color_override("font_color", ACCENT)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_row.add_child(state)
	dialog.add_custom_control(detail_row)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(520, 300))


func _loan_terms_text(pokemon_count: int, item_count: int, fee: int, duration_seconds: int) -> String:
	var duration := _duration_label(duration_seconds)
	if item_count > 0 and pokemon_count == 0:
		return _t("ui.lending.card.item_terms", {"count": item_count, "fee": fee, "duration": duration})
	if pokemon_count > 0 and item_count == 0:
		return _t("ui.lending.card.pokemon_terms", {"count": pokemon_count, "fee": fee, "duration": duration})
	return _t("ui.lending.card.terms", {"pokemon": pokemon_count, "items": item_count, "fee": fee, "duration": duration})


func _loan_contents_title(pokemon_count: int, item_count: int) -> String:
	if item_count > 0 and pokemon_count == 0:
		return _t("ui.lending.card.item_contents", {"count": item_count})
	if pokemon_count > 0 and item_count == 0:
		return _t("ui.lending.card.pokemon_contents", {"count": pokemon_count})
	return _t("ui.lending.card.asset_contents", {"count": pokemon_count + item_count})


func _add_asset_return_controls(row: HBoxContainer, asset: Dictionary, asset_name: String, is_borrower: bool, loan_status: String, return_requested: bool, loan_id: String) -> void:
	var asset_status := str(asset.get("status", ""))
	if loan_status not in ["active", "return_pending"] or asset_status not in ["active", "return_pending"]:
		return
	var asset_id := str(asset.get("assetId", ""))
	if is_borrower:
		if return_requested:
			row.add_child(_return_requested_label())
			row.add_child(_asset_return_button(loan_id, asset_id, asset_name, true))
			row.add_child(_asset_decline_return_button(loan_id, asset_id, asset_name))
		else:
			row.add_child(_asset_return_button(loan_id, asset_id, asset_name))
	elif asset_status == "active":
		if return_requested:
			row.add_child(_return_requested_label())
		else:
			row.add_child(_asset_request_return_button(loan_id, asset_id, asset_name))


func _return_requested_label() -> Label:
	var label := Label.new()
	label.text = _t("ui.lending.card.asset_return_requested")
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_font_size_override("font_size", 9)
	return label


func _asset_request_return_button(loan_id: String, asset_id: String, asset_name: String) -> Button:
	var button := Button.new()
	button.text = _t("ui.lending.request_return_asset")
	button.disabled = mutation_in_flight
	button.pressed.connect(_request_loan_asset_return.bind(loan_id, asset_id, asset_name))
	_apply_button_style(button)
	return button


func _asset_return_button(loan_id: String, asset_id: String, asset_name: String, requested := false) -> Button:
	var button := Button.new()
	button.text = _t("ui.lending.accept_return_request") if requested else _t("ui.lending.return_asset")
	button.disabled = mutation_in_flight
	button.pressed.connect(_confirm_asset_return.bind(loan_id, asset_id, asset_name))
	_apply_button_style(button)
	return button


func _asset_decline_return_button(loan_id: String, asset_id: String, asset_name: String) -> Button:
	var button := Button.new()
	button.text = _t("ui.lending.decline_return_request")
	button.disabled = mutation_in_flight
	button.pressed.connect(_decline_loan_asset_return.bind(loan_id, asset_id, asset_name))
	_apply_button_style(button)
	return button


func _request_loan_asset_return(loan_id: String, asset_id: String, asset_name: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.request_return(loan_id, asset_id)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("add_system_message"):
		overlay.call("add_system_message", _t("ui.lending.notification.you_requested_asset", {"asset": asset_name}))
	await _refresh_loans()


func _confirm_asset_return(loan_id: String, asset_id: String, asset_name: String) -> void:
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	dialog.configure(
		_t("ui.lending.return_confirm_title"),
		_t("ui.lending.return_confirm_text", {"asset": asset_name}),
		_t("ui.lending.return_asset"),
		_t("common.cancel")
	)
	dialog.confirmed.connect(_return_loan_asset.bind(loan_id, asset_id, asset_name), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(500, 230))


func _return_loan_asset(loan_id: String, asset_id: String, _asset_name: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.return_assets(loan_id, [asset_id])
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	_remove_pending_return_request(asset_id)
	await _refresh_after_asset_return()
	await _refresh_assets()
	await _refresh_loans()
	await _poll_loan_notifications()
	await _poll_incoming_offers()


func _decline_loan_asset_return(loan_id: String, asset_id: String, _asset_name: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.decline_return(loan_id, asset_id)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	_remove_pending_return_request(asset_id)
	await _refresh_loans()
	await _poll_incoming_offers()


func _remove_pending_return_request(asset_id: String) -> void:
	var remaining: Array[Dictionary] = []
	for request: Dictionary in pending_return_requests:
		if str(request.get("assetId", "")) != asset_id:
			remaining.append(request)
	pending_return_requests = remaining
	pending_return_request_signature = ""
	if focused_return_asset_id == asset_id:
		focused_return_asset_id = ""
	return_requests_changed.emit(pending_return_requests.duplicate(true))


func _refresh_after_asset_return() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service != null and party_service.has_method("refresh_party"):
		await party_service.call("refresh_party")
	var inventory_service := get_node_or_null("/root/InventoryService")
	if inventory_service != null and inventory_service.has_method("load_inventory"):
		await inventory_service.call("load_inventory")
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("_refresh_pc_state"):
		await overlay.call("_refresh_pc_state", true)


func _loan_asset_identity(display_name: String, metadata: String) -> VBoxContainer:
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 12)
	identity.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = metadata
	meta_label.add_theme_color_override("font_color", MUTED)
	meta_label.add_theme_font_size_override("font_size", 9)
	identity.add_child(meta_label)
	return identity


func _status_badge(status: String) -> Label:
	var badge := Label.new()
	badge.text = _t("ui.lending.status.%s" % status)
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", _status_color(status))
	var badge_style := _style(Color("#07111df5"), _status_color(status, true), 6)
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("normal", badge_style)
	return badge


func _status_color(status: String, subdued := false) -> Color:
	var color := Color("#83e2a9")
	match status:
		"pending": color = GOLD
		"return_pending": color = Color("#ffae6d")
		"returned": color = ACCENT
		"declined", "cancelled", "expired": color = Color("#8794a3")
	return Color(color, 0.55) if subdued else color


func _loan_timing_text(loan: Dictionary) -> String:
	var status := str(loan.get("status", ""))
	match status:
		"pending":
			return _t("ui.lending.card.offer_expires", {"date": _format_loan_time(_optional_string(loan.get("offerExpiresAt")))})
		"active":
			return _loan_deadline_text(_optional_string(loan.get("dueAt")))
		"return_pending":
			return _t("ui.lending.card.return_requested", {"date": _format_loan_time(_optional_string(loan.get("returnRequestedAt")))})
		"returned":
			return _t("ui.lending.card.returned", {"date": _format_loan_time(_optional_string(loan.get("returnedAt")))})
		"expired":
			return _t("ui.lending.card.expired", {"date": _format_loan_time(_optional_string(loan.get("offerExpiresAt")))})
	return _t("ui.lending.card.created", {"date": _format_loan_time(_optional_string(loan.get("createdAt")))})


func _loan_deadline_text(deadline: String, now_unix := -1) -> String:
	var date_text := _format_loan_time(deadline)
	var remaining := _loan_remaining_text(deadline, now_unix)
	if remaining == "":
		return _t("ui.lending.card.due", {"date": date_text})
	return _t("ui.lending.card.due_with_remaining", {"date": date_text, "remaining": remaining})


func _loan_remaining_text(deadline: String, now_unix := -1) -> String:
	var seconds := _seconds_until_loan_deadline(deadline, now_unix)
	if seconds == INVALID_DEADLINE_SECONDS or seconds >= 3600:
		return ""
	if seconds < 0:
		var overdue_seconds := absi(seconds)
		if overdue_seconds < 60:
			return _t("ui.lending.remaining.overdue_less_than_minute")
		var overdue_minutes := maxi(int(ceil(float(overdue_seconds) / 60.0)), 1)
		return _t("ui.lending.remaining.overdue_minute" if overdue_minutes == 1 else "ui.lending.remaining.overdue_minutes", {"count": overdue_minutes})
	if seconds == 0:
		return _t("ui.lending.remaining.due_now")
	if seconds < 60:
		return _t("ui.lending.remaining.less_than_minute")
	var minutes := maxi(int(floor(float(seconds) / 60.0)), 1)
	return _t("ui.lending.remaining.minute" if minutes == 1 else "ui.lending.remaining.minutes", {"count": minutes})


func _seconds_until_loan_deadline(deadline: String, now_unix := -1) -> int:
	var cleaned := deadline.strip_edges()
	if cleaned.length() < 19:
		return INVALID_DEADLINE_SECONDS
	var deadline_unix := int(Time.get_unix_time_from_datetime_string(cleaned.left(19)))
	if deadline_unix <= 0:
		return INVALID_DEADLINE_SECONDS
	var current_unix := int(Time.get_unix_time_from_system()) if now_unix < 0 else now_unix
	return deadline_unix - current_unix


func _format_loan_time(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned == "":
		return "—"
	if cleaned.length() >= 16:
		return "%s UTC" % cleaned.left(16).replace("T", " ")
	return cleaned


func _asset_state_label(status: String) -> String:
	return _t("ui.lending.asset_status.%s" % status)


func _create_loan() -> void:
	if mutation_in_flight:
		return
	var pokemon_ids: Array[int] = []
	if loan_asset_mode == "pokemon":
		for key: Variant in selected_pokemon.keys():
			pokemon_ids.append(int(key))
	var items: Array[Dictionary] = []
	if loan_asset_mode == "items":
		for key_value: Variant in selected_items.keys():
			var key := str(key_value)
			if key.begins_with("held:"):
				var pokemon_id := int(key.trim_prefix("held:"))
				var candidate := _candidate_by_id(pokemon_id)
				items.append({"itemId": str(candidate.get("heldItemId", "")), "sourcePokemonId": pokemon_id, "quantity": 1})
			else:
				items.append({"itemId": key.trim_prefix("bag:"), "quantity": int(selected_items.get(key_value, 1))})
	if pokemon_ids.is_empty() and items.is_empty():
		_show_error(_t("ui.lending.error.assets_required_%s" % loan_asset_mode))
		return
	if pokemon_ids.size() > 6 or _selected_item_copy_count() > 6:
		_show_error(_t("ui.lending.error.selection_limit"))
		return
	var selected_party_count := _selected_party_pokemon_count()
	if selected_party_count > 0 and selected_party_count >= party_candidates.size():
		_show_error(_t("ui.lending.error.party_required"))
		return
	mutation_in_flight = true
	create_button.disabled = true
	var service := get_node_or_null("/root/LendingService")
	var duration := int(duration_select.get_item_metadata(duration_select.selected))
	var result: Dictionary = await service.create_loan(target_username, pokemon_ids, items, duration, int(fee_input.value))
	mutation_in_flight = false
	create_button.disabled = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result, "ui.lending.error.create"))
		return
	status_label.text = _t("ui.lending.status.sent", {"trainer": target_username})
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("add_system_message"):
		overlay.call("add_system_message", status_label.text)
	hide()


func _set_workspace_mode(is_composing: bool) -> void:
	if compose_panel != null:
		compose_panel.visible = is_composing
	if loans_panel != null:
		loans_panel.visible = not is_composing
	if subtitle_label != null:
		subtitle_label.text = _t("ui.lending.subtitle" if is_composing else "ui.lending.overview_subtitle")


func _friendly_error(result: Dictionary, fallback_key: String) -> String:
	var code := str(result.get("code", ""))
	if code in ["loan_same_map_required", "loan_presence_unavailable", "loan_lender_party_required"]:
		var localizer := get_node_or_null("/root/BackendErrorLocalization")
		if localizer != null:
			return str(localizer.call("message", result, fallback_key))
	return str(result.get("error", _t(fallback_key)))


func _loan_action(action: String, loan_id: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary
	match action:
		"accept": result = await service.accept_loan(loan_id)
		"decline": result = await service.decline_loan(loan_id)
		"cancel": result = await service.cancel_loan(loan_id)
		_: result = {"success": false, "error": "Unsupported loan action."}
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	await _refresh_assets()
	await _refresh_loans()


func _open_attach_menu(asset_id: String, item_id: String) -> void:
	var eligible: Array[Dictionary] = []
	for candidate: Dictionary in party_candidates:
		if str(candidate.get("heldItemId", "")) == "":
			eligible.append(candidate)
	if eligible.is_empty():
		_show_error(_t("ui.lending.error.no_attach_target"))
		return
	var dialog := AetherConfirmationDialogScene.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	dialog.configure(
		_t("ui.lending.attach_title", {"item": item_id}),
		_t("ui.lending.attach_description"),
		_t("ui.lending.attach_item"),
		_t("common.cancel")
	)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(310, 36)
	for candidate: Dictionary in eligible:
		selector.add_item("%s · Lv. %d" % [str(candidate.get("name", "Pokémon")), int(candidate.get("level", 1))])
		selector.set_item_metadata(selector.item_count - 1, int(candidate.get("pokemonId", 0)))
	_apply_option_style(selector)
	dialog.add_custom_control(selector)
	dialog.confirmed.connect(func():
		var pokemon_id := int(selector.get_item_metadata(selector.selected))
		_attach_item_to_pokemon(asset_id, pokemon_id)
	, CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(520, 280))


func _attach_item_to_pokemon(asset_id: String, pokemon_id: int) -> void:
	if mutation_in_flight or pokemon_id <= 0:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.attach_item(asset_id, pokemon_id)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	await _refresh_assets()
	await _refresh_loans()


func _detach_loan_item(asset_id: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.detach_item(asset_id)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	await _refresh_assets()
	await _refresh_loans()


func _populate_durations() -> void:
	var current := int(duration_select.get_item_metadata(duration_select.selected)) if duration_select.item_count > 0 else 10800
	duration_select.clear()
	var durations: Array = capabilities.get("durationsSeconds", [3600, 10800, 21600, 43200, 86400, 172800, 259200])
	for value: Variant in durations:
		var duration := int(value)
		duration_select.add_item(_duration_label(duration))
		duration_select.set_item_metadata(duration_select.item_count - 1, duration)
		if duration == current: duration_select.select(duration_select.item_count - 1)


func _party_candidates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if not entry is Dictionary: continue
			var payload: Dictionary = entry.get("pokemon", entry).duplicate(true)
			var pokemon_id := int(entry.get("id", entry.get("pokemonId", payload.get("ownedPokemonId", 0))))
			if pokemon_id <= 0: continue
			payload["ownedPokemonId"] = pokemon_id
			var species_id := str(payload.get("speciesId", payload.get("species_id", payload.get("species", ""))))
			if not payload.has("speciesId"):
				payload["speciesId"] = species_id
			result.append({"pokemonId": pokemon_id, "name": _pokemon_display_name(payload), "speciesId": species_id, "level": int(payload.get("level", 1)), "heldItemId": str(payload.get("heldItemId", payload.get("item", ""))), "pokemon": payload, "sourceType": "party"})
	return result


func _box_candidates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for box_value: Variant in value:
		if not box_value is Dictionary:
			continue
		var box: Dictionary = box_value
		var box_index := int(box.get("boxIndex", 0))
		for slot_value: Variant in box.get("slots", []):
			if not slot_value is Dictionary:
				continue
			var slot: Dictionary = slot_value
			var normalized := _party_candidates([slot.get("pokemon", {})])
			if normalized.is_empty():
				continue
			var candidate: Dictionary = normalized[0]
			candidate["sourceType"] = "box"
			candidate["boxIndex"] = box_index
			candidate["slotIndex"] = int(slot.get("slotIndex", 0))
			result.append(candidate)
	return result


func _pokemon_boxes(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for box_value: Variant in value:
		if box_value is Dictionary:
			result.append((box_value as Dictionary).duplicate(true))
	return result


func _box_candidates_for_index(box_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in box_candidates:
		if int(candidate.get("boxIndex", -1)) == box_index:
			result.append(candidate)
	return result


func _setup_incoming_offers() -> void:
	incoming_dialog = LoanInvitationDialogScript.new()
	add_child(incoming_dialog)
	incoming_dialog.call("setup")
	if incoming_dialog.has_signal("offers_changed"):
		incoming_dialog.connect("offers_changed", _on_incoming_offers_changed)
	var timer := Timer.new()
	timer.wait_time = INCOMING_POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll_incoming_offers)
	timer.timeout.connect(_poll_loan_notifications)
	add_child(timer)
	_poll_incoming_offers.call_deferred()
	_poll_loan_notifications.call_deferred()


func _setup_deadline_refresh() -> void:
	var timer := Timer.new()
	timer.wait_time = DEADLINE_REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh_loan_deadline_labels)
	add_child(timer)


func _refresh_loan_deadline_labels() -> void:
	if not visible or loans_panel == null or not loans_panel.visible:
		return
	for entry: Dictionary in loan_timing_rows:
		var label := entry.get("label") as Label
		var loan: Dictionary = entry.get("loan", {}) if entry.get("loan", {}) is Dictionary else {}
		if is_instance_valid(label):
			label.text = _loan_timing_text(loan)


func _poll_incoming_offers() -> void:
	if incoming_poll_in_flight:
		return
	if _aether_clash_exchange_blocked():
		if incoming_dialog != null and incoming_dialog.has_method("clear_offers"):
			incoming_dialog.call("clear_offers")
		last_incoming_signature = ""
		return
	var auth := get_node_or_null("/root/AuthService")
	if auth == null or not auth.has_method("is_authenticated") or not bool(auth.is_authenticated()):
		return
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		return
	var account_generation := incoming_account_generation
	incoming_poll_in_flight = true
	var result: Dictionary = await service.load_loans("borrowed")
	incoming_poll_in_flight = false
	if account_generation != incoming_account_generation:
		return
	if not bool(result.get("success", false)):
		return
	var pending: Array[Dictionary] = []
	var return_requests: Array[Dictionary] = []
	var body: Dictionary = result.get("body", {})
	for value: Variant in body.get("loans", []):
		if not value is Dictionary:
			continue
		var loan: Dictionary = value
		if str(loan.get("status", "")) == "pending":
			pending.append(loan.duplicate(true))
		if str(loan.get("status", "")) not in ["active", "return_pending"]:
			continue
		for asset_value: Variant in loan.get("assets", []):
			if not asset_value is Dictionary:
				continue
			var asset: Dictionary = asset_value
			if _optional_string(asset.get("returnRequestedAt")) == "":
				continue
			if str(asset.get("status", "")) not in ["active", "return_pending"]:
				continue
			return_requests.append({
				"loanId": str(loan.get("loanId", "")),
				"assetId": str(asset.get("assetId", "")),
				"assetType": str(asset.get("assetType", "")),
				"requestedAt": _optional_string(asset.get("returnRequestedAt")),
			})
	_update_return_request_attention(return_requests)
	var signature_parts: Array[String] = []
	for offer: Dictionary in pending:
		signature_parts.append(str(offer.get("loanId", "")))
	var signature := "|".join(signature_parts)
	if signature != last_incoming_signature and incoming_dialog != null and incoming_dialog.has_method("show_offers"):
		incoming_dialog.call("show_offers", pending, true)
	last_incoming_signature = signature


func suppress_for_aether_clash() -> void:
	hide()
	if incoming_dialog != null and incoming_dialog.has_method("clear_offers"):
		incoming_dialog.call("clear_offers")
	last_incoming_signature = ""


func _aether_clash_exchange_blocked() -> bool:
	return not get_tree().get_nodes_in_group("aether_clash_duel_controller").is_empty()


func _update_return_request_attention(requests: Array[Dictionary]) -> void:
	requests.sort_custom(func(left: Dictionary, right: Dictionary):
		return "%s:%s" % [left.get("loanId", ""), left.get("assetId", "")] < "%s:%s" % [right.get("loanId", ""), right.get("assetId", "")]
	)
	var signature_parts: Array[String] = []
	for request: Dictionary in requests:
		signature_parts.append("%s:%s:%s" % [request.get("loanId", ""), request.get("assetId", ""), request.get("requestedAt", "")])
	var signature := "|".join(signature_parts)
	if signature == pending_return_request_signature:
		return
	pending_return_request_signature = signature
	pending_return_requests = requests.duplicate(true)
	if pending_return_requests.is_empty():
		focused_return_asset_id = ""
	return_requests_changed.emit(pending_return_requests.duplicate(true))


func _poll_loan_notifications() -> void:
	if notification_poll_in_flight:
		return
	var auth := get_node_or_null("/root/AuthService")
	if auth == null or not auth.has_method("is_authenticated") or not bool(auth.is_authenticated()):
		return
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay == null or not overlay.has_method("add_system_message"):
		return
	var service := get_node_or_null("/root/LendingService")
	if service == null or not service.has_method("load_notifications"):
		return
	var account_generation := incoming_account_generation
	notification_poll_in_flight = true
	var result: Dictionary = await service.load_notifications()
	notification_poll_in_flight = false
	if account_generation != incoming_account_generation or not bool(result.get("success", false)):
		return
	var body: Dictionary = result.get("body", {})
	var custody_changed := false
	for value: Variant in body.get("notifications", []):
		if not value is Dictionary:
			continue
		var notification: Dictionary = value
		var notification_id := str(notification.get("notificationId", ""))
		if notification_id == "":
			continue
		if not displayed_notification_ids.has(notification_id):
			displayed_notification_ids[notification_id] = true
			var message_key := str(notification.get("messageKey", ""))
			if message_key in [
				"ui.lending.notification.accepted",
				"ui.lending.notification.asset_returned",
				"ui.lending.notification.asset_auto_returned",
				"ui.lending.notification.you_returned",
				"ui.lending.notification.asset_auto_returned_from_you",
			]:
				custody_changed = true
			var message_args: Dictionary = _notification_message_args(notification.get("messageArgs", {}))
			overlay.call("add_system_message", _t(message_key, message_args))
		var ack: Dictionary = await service.acknowledge_notification(notification_id)
		if account_generation != incoming_account_generation:
			return
		if bool(ack.get("success", false)):
			displayed_notification_ids.erase(notification_id)
	if custody_changed:
		await _refresh_after_asset_return()


func _notification_message_args(value: Variant) -> Dictionary:
	var args: Dictionary = value.duplicate(true) if value is Dictionary else {}
	var asset_type := str(args.get("assetType", ""))
	var asset_id := str(args.get("assetId", ""))
	var fallback := str(args.get("asset", asset_id))
	if asset_type == "pokemon":
		var content_localizer := get_node_or_null("/root/ContentLocalization")
		if content_localizer != null:
			args["asset"] = str(content_localizer.call("display_name", "species", asset_id, fallback))
	elif asset_type == "item":
		args["asset"] = _item_display_name(asset_id, fallback)
	return args


func _on_incoming_offers_changed() -> void:
	last_incoming_signature = ""
	await _poll_incoming_offers()
	if visible:
		await _refresh_loans()


func _pokemon_display_name(pokemon: Dictionary) -> String:
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	var species_id := str(pokemon.get("speciesId", pokemon.get("species_id", pokemon.get("species", "")))).strip_edges()
	var fallback := str(pokemon.get("speciesName", species_id)).strip_edges()
	if fallback == "":
		fallback = "Pokémon"
	if not is_inside_tree():
		return fallback
	var localizer := get_node_or_null("/root/ContentLocalization")
	return str(localizer.call("display_name", "species", species_id, fallback)) if localizer != null else fallback


func _item_candidates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if not entry is Dictionary: continue
			var category := str(entry.get("category", "")).to_lower()
			var item_id := str(entry.get("itemId", "")).strip_edges().to_lower()
			if (
				item_id == ""
				or int(entry.get("quantity", 0)) <= 0
				or not bool(entry.get("isHoldable", false))
				or not bool(entry.get("tradable", false))
				or category == "berries"
			):
				continue
			result.append({
				"itemId": item_id,
				"name": _item_display_name(item_id, str(entry.get("name", item_id))),
				"quantity": int(entry.get("quantity", 0)),
				"category": category,
				"shortDesc": str(entry.get("shortDesc", "")),
			})
	return result


func _candidate_by_id(pokemon_id: int) -> Dictionary:
	for candidate: Dictionary in party_candidates:
		if int(candidate.get("pokemonId", 0)) == pokemon_id: return candidate
	for candidate: Dictionary in box_candidates:
		if int(candidate.get("pokemonId", 0)) == pokemon_id: return candidate
	return {}


func _selected_party_pokemon_count(except_id := 0) -> int:
	var total := 0
	for key_value: Variant in selected_pokemon.keys():
		var pokemon_id := int(key_value)
		if pokemon_id == int(except_id):
			continue
		if str(_candidate_by_id(pokemon_id).get("sourceType", "party")) == "party":
			total += 1
	return total


func _selected_item_copy_count(except_key := "") -> int:
	var total := 0
	for key_value: Variant in selected_items.keys():
		if str(key_value) == str(except_key):
			continue
		total += maxi(int(selected_items.get(key_value, 1)), 1)
	return total


func _toggle_item_selection(enabled: bool, selection_key: String, quantity: SpinBox, checkbox: CheckBox) -> void:
	if not enabled:
		selected_items.erase(selection_key)
		if quantity != null:
			quantity.editable = false
		return
	var remaining := 6 - _selected_item_copy_count(selection_key)
	if remaining <= 0:
		checkbox.set_pressed_no_signal(false)
		_show_error(_t("ui.lending.error.selection_limit"))
		return
	if quantity == null:
		selected_items[selection_key] = 1
		return
	quantity.editable = true
	var accepted := mini(int(quantity.value), remaining)
	quantity.set_value_no_signal(accepted)
	selected_items[selection_key] = accepted


func _update_item_quantity(value: float, selection_key: String, quantity: SpinBox) -> void:
	if not selected_items.has(selection_key):
		return
	var maximum := maxi(6 - _selected_item_copy_count(selection_key), 1)
	var accepted := mini(int(value), maximum)
	if accepted != int(value):
		quantity.set_value_no_signal(accepted)
		_show_error(_t("ui.lending.error.selection_limit"))
	selected_items[selection_key] = accepted


func _toggle_pokemon_selection(enabled: bool, pokemon_id: int, checkbox: CheckBox) -> void:
	if not enabled:
		selected_pokemon.erase(pokemon_id)
		return
	if selected_pokemon.size() >= 6:
		checkbox.set_pressed_no_signal(false)
		_show_error(_t("ui.lending.error.selection_limit"))
		return
	var candidate := _candidate_by_id(pokemon_id)
	if not _pokemon_candidate_is_lendable(candidate):
		checkbox.set_pressed_no_signal(false)
		selected_pokemon.erase(pokemon_id)
		_show_error(_t("ui.lending.error.pokemon_not_lendable"))
		return
	if str(candidate.get("heldItemId", "")) != "":
		checkbox.set_pressed_no_signal(false)
		_show_error(_t("ui.lending.error.remove_held_item"))
		return
	if str(candidate.get("sourceType", "party")) == "party" and _selected_party_pokemon_count(pokemon_id) >= maxi(party_candidates.size() - 1, 0):
		checkbox.set_pressed_no_signal(false)
		_show_error(_t("ui.lending.error.party_required"))
		return
	selected_pokemon[pokemon_id] = true


func _add_action(parent: HBoxContainer, label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.disabled = mutation_in_flight
	button.pressed.connect(callback)
	_apply_button_style(button)
	parent.add_child(button)


func _pokemon_candidate_row(candidate: Dictionary, pokemon_id: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 60
	var is_lendable := _pokemon_candidate_is_lendable(candidate)
	panel.add_theme_stylebox_override("panel", _style(Color("#07111df0"), BORDER if is_lendable else Color("#7f3f49"), 7))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	_apply_checkbox_style(box)
	var held_item_id := str(candidate.get("heldItemId", ""))
	box.disabled = not is_lendable or held_item_id != ""
	if not is_lendable:
		box.tooltip_text = _t("ui.lending.error.pokemon_not_lendable")
	elif held_item_id != "":
		box.tooltip_text = _t("ui.lending.error.remove_held_item")
	box.set_pressed_no_signal(selected_pokemon.has(pokemon_id))
	box.toggled.connect(_toggle_pokemon_selection.bind(pokemon_id, box))
	row.add_child(box)
	var payload: Dictionary = candidate.get("pokemon", {})
	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(46, 46)
	icon_button.icon = PokemonAssets.load_party_icon(str(candidate.get("speciesId", "")), bool(payload.get("shiny", false)))
	icon_button.expand_icon = true
	icon_button.add_theme_constant_override("icon_max_width", 42)
	icon_button.pressed.connect(_open_pokemon_summary.bind(payload))
	_apply_icon_button_style(icon_button)
	row.add_child(icon_button)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	var name_label := Label.new()
	name_label.text = str(candidate.get("name", "Pokémon"))
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 13)
	identity.add_child(name_label)
	var level_label := Label.new()
	level_label.text = "Lv. %d" % int(candidate.get("level", 1))
	if str(candidate.get("sourceType", "party")) == "box":
		level_label.text += " · %s · %s" % [
			_t("ui.lending.source.box", {"number": int(candidate.get("boxIndex", 0)) + 1}),
			_t("ui.lending.source.slot", {"number": int(candidate.get("slotIndex", 0)) + 1}),
		]
	if held_item_id != "":
		level_label.text += " · %s" % _t("ui.lending.pokemon_holding_item", {"item": _item_display_name(held_item_id, held_item_id)})
	if not is_lendable:
		level_label.text += " · %s" % _t("ui.lending.pokemon_not_lendable")
	level_label.add_theme_color_override("font_color", MUTED if is_lendable else Color("#ff8a93"))
	level_label.add_theme_font_size_override("font_size", 10)
	identity.add_child(level_label)
	var view := Button.new()
	view.text = _t("ui.lending.invitation.view")
	view.pressed.connect(_open_pokemon_summary.bind(payload))
	_apply_button_style(view)
	row.add_child(view)
	return panel


func _pokemon_candidate_is_lendable(candidate: Dictionary) -> bool:
	var payload_value: Variant = candidate.get("pokemon", {})
	var payload: Dictionary = payload_value if payload_value is Dictionary else {}
	for key: String in ["tradable", "tradeable", "isTradable", "is_tradable"]:
		if candidate.has(key):
			return bool(candidate.get(key))
		if payload.has(key):
			return bool(payload.get(key))
	return true


func _item_candidate_row(item: Dictionary, selection_key: String, held := false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 46
	panel.add_theme_stylebox_override("panel", _style(Color("#07111df0"), BORDER, 7))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	_apply_checkbox_style(box)
	box.set_pressed_no_signal(selected_items.has(selection_key))
	row.add_child(box)
	var item_id := str(item.get("itemId", ""))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = _load_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	var label := Label.new()
	label.text = str(item.get("name", item_id))
	label.add_theme_color_override("font_color", TEXT)
	identity.add_child(label)
	var detail := Label.new()
	detail.text = _t("ui.lending.item_held_by", {"pokemon": str(item.get("holderName", "Pokémon"))}) if held else _t("ui.lending.item_available", {"count": int(item.get("quantity", 1))})
	detail.add_theme_color_override("font_color", MUTED)
	detail.add_theme_font_size_override("font_size", 9)
	identity.add_child(detail)
	var quantity: SpinBox = null
	if held:
		var single := Label.new()
		single.text = "×1"
		single.add_theme_color_override("font_color", MUTED)
		row.add_child(single)
	else:
		quantity = SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = mini(int(item.get("quantity", 1)), 6)
		quantity.value = int(selected_items.get(selection_key, 1))
		quantity.editable = selected_items.has(selection_key)
		quantity.prefix = "×"
		quantity.custom_minimum_size.x = 72
		_apply_spinbox_style(quantity)
		quantity.value_changed.connect(_update_item_quantity.bind(selection_key, quantity))
		row.add_child(quantity)
	box.toggled.connect(_toggle_item_selection.bind(selection_key, quantity, box))
	return panel


func _open_pokemon_summary(payload: Dictionary) -> void:
	var preview := payload.duplicate(true)
	if str(preview.get("species", "")).strip_edges() == "":
		preview["species"] = str(preview.get("speciesId", preview.get("speciesName", "")))
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("open_trade_pokemon_summary"):
		overlay.call("open_trade_pokemon_summary", preview)


func _item_display_name(item_id: String, fallback: String) -> String:
	if not is_inside_tree():
		return fallback
	var localizer := get_node_or_null("/root/ItemLocalization")
	return str(localizer.call("display_name", item_id, fallback)) if localizer != null else fallback


func _load_item_icon(item_id: String) -> Texture2D:
	var normalized := item_id.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	for path: String in ["res://assets/items/icons/%s.png" % normalized, "res://assets/items/icons/%s.png" % item_id.strip_edges(), "res://assets/items/icons/000.png"]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _apply_button_style(button: Button, kind := "secondary") -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var primary := kind == "primary"
	var danger := kind == "danger"
	var normal := Color("#0d4359") if primary else (Color("#2a1015") if danger else Color("#111d2c"))
	var hover := Color("#12627f") if primary else (Color("#6a1f2a") if danger else Color("#192c42"))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#667382"))
	button.add_theme_stylebox_override("normal", _input_style(normal, ACCENT if primary else BORDER))
	button.add_theme_stylebox_override("hover", _input_style(hover, ACCENT))
	button.add_theme_stylebox_override("pressed", _input_style(BG, ACCENT))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _input_style(Color("#0a1018"), Color("#253344")))


func _apply_icon_button_style(button: Button) -> void:
	_apply_button_style(button)
	button.add_theme_stylebox_override("normal", _style(Color("#00000000"), Color("#00000000"), 5))


func _apply_checkbox_style(checkbox: CheckBox) -> void:
	checkbox.add_theme_icon_override("unchecked", _checkbox_icon(false, false))
	checkbox.add_theme_icon_override("unchecked_hover", _checkbox_icon(false, true))
	checkbox.add_theme_icon_override("unchecked_pressed", _checkbox_icon(false, true))
	checkbox.add_theme_icon_override("checked", _checkbox_icon(true, false))
	checkbox.add_theme_icon_override("checked_hover", _checkbox_icon(true, true))
	checkbox.add_theme_icon_override("checked_pressed", _checkbox_icon(true, true))
	checkbox.add_theme_icon_override("unchecked_disabled", _checkbox_icon(false, false))
	checkbox.add_theme_icon_override("checked_disabled", _checkbox_icon(true, false))


static func _checkbox_icon(checked: bool, hovered: bool) -> ImageTexture:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	var border := ACCENT if hovered or checked else Color("#527793")
	var fill := Color("#1685a7") if checked else Color("#071321")
	for y in range(18):
		for x in range(18):
			var is_border := x < 2 or x > 15 or y < 2 or y > 15
			image.set_pixel(x, y, border if is_border else fill)
	if checked:
		for point: Vector2i in [Vector2i(4, 9), Vector2i(5, 10), Vector2i(6, 11), Vector2i(7, 12), Vector2i(8, 11), Vector2i(9, 10), Vector2i(10, 9), Vector2i(11, 8), Vector2i(12, 7), Vector2i(13, 6)]:
			image.set_pixelv(point, Color.WHITE)
			if point.y + 1 < 16:
				image.set_pixel(point.x, point.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_stylebox_override("normal", _input_style(Color("#07111df5"), BORDER))
	input.add_theme_stylebox_override("focus", _input_style(Color("#071526f5"), ACCENT))


func _apply_option_style(select: OptionButton) -> void:
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.add_theme_color_override("font_color", TEXT)
	select.add_theme_color_override("font_hover_color", Color.WHITE)
	select.add_theme_color_override("font_pressed_color", Color.WHITE)
	select.add_theme_color_override("font_focus_color", Color.WHITE)
	select.add_theme_color_override("font_disabled_color", Color(MUTED, 0.5))
	select.add_theme_icon_override("arrow", _dropdown_arrow_icon())
	select.add_theme_constant_override("arrow_margin", 11)
	select.add_theme_stylebox_override("normal", _input_style(Color("#07111df5"), BORDER))
	select.add_theme_stylebox_override("hover", _input_style(Color("#102238f5"), ACCENT))
	select.add_theme_stylebox_override("pressed", _input_style(Color("#071526f5"), ACCENT))
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var popup := select.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.max_size = Vector2i(430, 340)
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(MUTED, 0.5))
	popup.add_theme_color_override("font_outline_color", Color("#02070b"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", _dropdown_popup_style())
	popup.add_theme_stylebox_override("hover", _dropdown_item_style(Color("#17344cf7"), ACCENT))
	popup.add_theme_icon_override("radio_checked", _dropdown_radio_icon(true))
	popup.add_theme_icon_override("radio_unchecked", _dropdown_radio_icon(false))
	popup.add_theme_icon_override("radio_checked_disabled", _dropdown_radio_icon(true))
	popup.add_theme_icon_override("radio_unchecked_disabled", _dropdown_radio_icon(false))


static func _dropdown_arrow_icon() -> ImageTexture:
	var image := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	for row: int in range(4):
		for x: int in range(2 + row, 10 - row):
			image.set_pixel(x, row + 2, ACCENT)
	return ImageTexture.create_from_image(image)


static func _dropdown_radio_icon(checked: bool) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var center := Vector2(7.5, 7.5)
	for y: int in range(16):
		for x: int in range(16):
			var distance := Vector2(x, y).distance_to(center)
			if distance <= 7.0 and distance >= 5.1:
				image.set_pixel(x, y, ACCENT if checked else Color("#527793"))
			elif checked and distance <= 3.4:
				image.set_pixel(x, y, ACCENT)
	return ImageTexture.create_from_image(image)


func _dropdown_popup_style() -> StyleBoxFlat:
	var style := _dropdown_item_style(Color("#050e18fc"), Color("#4e8caae6"), 9)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _dropdown_item_style(background: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var style := _style(background, border, radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _apply_spinbox_style(spinbox: SpinBox) -> void:
	_apply_line_edit_style(spinbox.get_line_edit())


func _input_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _style(background, border, 7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _section_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", ACCENT)
	return label


func _duration_label(seconds: int) -> String:
	match seconds:
		300: return _t("ui.lending.duration.five_minutes_development")
		3600: return _t("ui.lending.duration.hour")
		10800: return _t("ui.lending.duration.three_hours")
		21600: return _t("ui.lending.duration.six_hours")
		43200: return _t("ui.lending.duration.twelve_hours")
		86400: return _t("ui.lending.duration.day")
		172800: return _t("ui.lending.duration.forty_eight_hours")
		259200: return _t("ui.lending.duration.seventy_two_hours")
		604800: return _t("ui.lending.duration.week")
	return "%d h" % maxi(seconds / 3600, 1)


func _current_user_id() -> int:
	var auth := get_node_or_null("/root/AuthService")
	return int(auth.get("current_user").get("id", 0)) if auth != null and auth.get("current_user") is Dictionary else 0


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#ff7b82"))


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children(): child.queue_free()


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _t(key: String, values := {}) -> String:
	if not is_inside_tree():
		return key
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.call("text", key, values)) if localization != null else key
