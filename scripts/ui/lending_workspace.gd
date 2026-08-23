extends Window

class_name LendingWorkspaceNode

const LoanInvitationDialogScript := preload("res://scripts/ui/loan_invitation_dialog.gd")

const WINDOW_SIZE := Vector2i(900, 640)
const BG := Color("#050912fa")
const SURFACE := Color("#081522f7")
const BORDER := Color("#2d4b66b3")
const ACCENT := Color("#62d7ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")
const GOLD := Color("#d8b767")
const INCOMING_POLL_SECONDS := 5.0

var target_username := ""
var capabilities: Dictionary = {}
var loans: Array = []
var party_candidates: Array[Dictionary] = []
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

var target_display_label: Label
var duration_select: OptionButton
var fee_input: SpinBox
var assets_list: VBoxContainer
var loans_list: VBoxContainer
var view_select: OptionButton
var status_label: Label
var subtitle_label: Label
var create_button: Button
var usage_label: Label
var compose_panel: Control
var loans_panel: Control


func _ready() -> void:
	hide()
	title = _t("ui.lending.title")
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	size = WINDOW_SIZE
	unresizable = true
	borderless = true
	_build_ui()
	_setup_incoming_offers()
	close_requested.connect(hide)


func clear_account_state() -> void:
	hide()
	loans.clear()
	party_candidates.clear()
	inventory_candidates.clear()
	selected_pokemon.clear()
	selected_items.clear()
	target_username = ""
	last_incoming_signature = ""
	displayed_notification_ids.clear()
	incoming_account_generation += 1
	if incoming_dialog != null and incoming_dialog.has_method("clear_offers"):
		incoming_dialog.call("clear_offers")


func open_for_trainer(username: String) -> void:
	target_username = username.strip_edges()
	_set_workspace_mode(true)
	if target_display_label != null:
		target_display_label.text = _t("ui.lending.compose_target", {"trainer": target_username})
	popup_centered(WINDOW_SIZE)
	await refresh_all()


func open_loans() -> void:
	target_username = ""
	_set_workspace_mode(false)
	popup_centered(WINDOW_SIZE)
	await refresh_all()


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
	root.add_child(tools)
	view_select = OptionButton.new()
	for label in [_t("ui.lending.view.all"), _t("ui.lending.view.borrowed"), _t("ui.lending.view.lent"), _t("ui.lending.view.history")]:
		view_select.add_item(label)
	view_select.item_selected.connect(func(_index: int): await _refresh_loans())
	view_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_option_style(view_select)
	tools.add_child(view_select)
	var refresh := Button.new()
	refresh.text = _t("common.refresh")
	refresh.pressed.connect(refresh_all)
	_apply_button_style(refresh)
	tools.add_child(refresh)
	usage_label = Label.new()
	usage_label.add_theme_color_override("font_color", MUTED)
	usage_label.add_theme_font_size_override("font_size", 10)
	root.add_child(usage_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	loans_list = VBoxContainer.new()
	loans_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loans_list.add_theme_constant_override("separation", 7)
	scroll.add_child(loans_list)
	return panel


func _refresh_assets() -> void:
	selected_pokemon.clear()
	selected_items.clear()
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	var inventory_service := get_node_or_null("/root/InventoryService")
	var party_result: Dictionary = await party_service.load_party() if party_service != null else {"success": false}
	var inventory_result: Dictionary = await inventory_service.load_inventory() if inventory_service != null else {"success": false}
	party_candidates = _party_candidates(party_result.get("party", [])) if bool(party_result.get("success", false)) else []
	inventory_candidates = _item_candidates(inventory_result.get("items", [])) if bool(inventory_result.get("success", false)) else []
	_render_assets()


func _render_assets() -> void:
	_clear(assets_list)
	assets_list.add_child(_section_label(_t("ui.lending.assets.pokemon")))
	var party_hint := Label.new()
	party_hint.text = _t("ui.lending.party_required_hint")
	party_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party_hint.add_theme_color_override("font_color", GOLD)
	party_hint.add_theme_font_size_override("font_size", 10)
	assets_list.add_child(party_hint)
	for candidate: Dictionary in party_candidates:
		var pokemon_id := int(candidate.get("pokemonId", 0))
		assets_list.add_child(_pokemon_candidate_row(candidate, pokemon_id))
		var held_item := str(candidate.get("heldItemId", ""))
		if held_item != "":
			assets_list.add_child(_item_candidate_row({"itemId": held_item, "name": _item_display_name(held_item, held_item), "quantity": 1}, "held:%d" % pokemon_id, true))
	assets_list.add_child(_section_label(_t("ui.lending.assets.items")))
	for item: Dictionary in inventory_candidates:
		var item_id := str(item.get("itemId", ""))
		assets_list.add_child(_item_candidate_row(item, "bag:%s" % item_id))


func _refresh_loans() -> void:
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		return
	var views := ["all", "borrowed", "lent", "history"]
	var result: Dictionary = await service.load_loans(views[clampi(view_select.selected, 0, 3)])
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.load"))))
		return
	var body: Dictionary = result.get("body", {})
	loans = []
	var selected_view := clampi(view_select.selected, 0, 3)
	for value: Variant in body.get("loans", []):
		if not value is Dictionary:
			continue
		var loan: Dictionary = value
		if selected_view < 3 and str(loan.get("status", "")) in ["returned", "declined", "cancelled", "expired"]:
			continue
		loans.append(loan.duplicate(true))
	usage_label.text = _t("ui.lending.usage", {"bp": int(body.get("borrowedPokemon", 0)), "bi": int(body.get("borrowedItems", 0)), "lp": int(body.get("lentPokemon", 0)), "li": int(body.get("lentItems", 0))})
	_render_loans()


func _render_loans() -> void:
	_clear(loans_list)
	if loans.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.lending.empty")
		empty.add_theme_color_override("font_color", MUTED)
		loans_list.add_child(empty)
		return
	var current_user_id := _current_user_id()
	for value: Variant in loans:
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
		var lender := str(loan.get("lenderUsername", "Guild"))
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
		details.text = _t("ui.lending.card.terms", {"pokemon": pokemon_count, "items": item_count, "fee": int(loan.get("feeAmount", 0)), "duration": _duration_label(int(loan.get("durationSeconds", 0)))})
		details.add_theme_font_size_override("font_size", 10)
		details.add_theme_color_override("font_color", MUTED)
		stack.add_child(details)
		var timing := Label.new()
		timing.text = _loan_timing_text(loan)
		timing.add_theme_font_size_override("font_size", 10)
		timing.add_theme_color_override("font_color", _status_color(status))
		stack.add_child(timing)
		var asset_stack := VBoxContainer.new()
		asset_stack.add_theme_constant_override("separation", 4)
		stack.add_child(asset_stack)
		for asset_value: Variant in assets:
			if asset_value is Dictionary:
				asset_stack.add_child(_loan_asset_row(asset_value, is_borrower, status, str(loan.get("loanId", ""))))
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 6)
		stack.add_child(actions)
		if status == "pending" and is_borrower:
			_add_action(actions, _t("common.decline"), _loan_action.bind("decline", str(loan.get("loanId", ""))))
			_add_action(actions, _t("common.accept"), _loan_action.bind("accept", str(loan.get("loanId", ""))))
		elif status == "pending":
			_add_action(actions, _t("common.cancel"), _loan_action.bind("cancel", str(loan.get("loanId", ""))))
		elif status == "active" and not is_borrower:
			_add_action(actions, _t("ui.lending.request_return"), _loan_action.bind("request-return", str(loan.get("loanId", ""))))
		loans_list.add_child(card)


func _loan_asset_row(asset: Dictionary, is_borrower: bool, loan_status: String, loan_id: String) -> Control:
	var snapshot: Dictionary = asset.get("snapshot", {}) if asset.get("snapshot", {}) is Dictionary else {}
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#091725e8"), Color("#203b52"), 6))
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
		var identity := _loan_asset_identity(_pokemon_display_name(snapshot), _t("ui.lending.card.pokemon_meta", {"level": int(snapshot.get("level", 1)), "state": _asset_state_label(str(asset.get("status", "")))}))
		row.add_child(identity)
		if is_borrower and loan_status in ["active", "return_pending"] and str(asset.get("status", "")) in ["active", "return_pending"]:
			row.add_child(_asset_return_button(loan_id, str(asset.get("assetId", "")), _pokemon_display_name(snapshot)))
		var view := Button.new()
		view.text = _t("ui.lending.invitation.view")
		view.pressed.connect(_open_pokemon_summary.bind(snapshot))
		_apply_button_style(view)
		row.add_child(view)
	else:
		var item_id := str(asset.get("itemId", snapshot.get("id", "")))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.texture = _load_item_icon(item_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var item_meta_key := "ui.lending.card.item_equipped" if int(asset.get("heldPokemonId", 0)) > 0 else "ui.lending.card.item_in_bag"
		var identity := _loan_asset_identity(_item_display_name(item_id, str(snapshot.get("name", item_id))), _t(item_meta_key, {"state": _asset_state_label(str(asset.get("status", "")))}))
		row.add_child(identity)
		if is_borrower and loan_status in ["active", "return_pending"] and str(asset.get("status", "")) in ["active", "return_pending"]:
			var action := Button.new()
			action.text = _t("ui.lending.detach_item") if int(asset.get("heldPokemonId", 0)) > 0 else _t("ui.lending.attach_item")
			action.disabled = mutation_in_flight
			if int(asset.get("heldPokemonId", 0)) > 0:
				action.pressed.connect(_detach_loan_item.bind(str(asset.get("assetId", ""))))
			else:
				action.pressed.connect(_open_attach_menu.bind(str(asset.get("assetId", "")), item_id))
			_apply_button_style(action)
			row.add_child(action)
			row.add_child(_asset_return_button(loan_id, str(asset.get("assetId", "")), _item_display_name(item_id, str(snapshot.get("name", item_id)))))
	return panel


func _asset_return_button(loan_id: String, asset_id: String, asset_name: String) -> Button:
	var button := Button.new()
	button.text = _t("ui.lending.return_asset")
	button.disabled = mutation_in_flight
	button.pressed.connect(_confirm_asset_return.bind(loan_id, asset_id, asset_name))
	_apply_button_style(button)
	return button


func _confirm_asset_return(loan_id: String, asset_id: String, asset_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("ui.lending.return_confirm_title")
	dialog.dialog_text = _t("ui.lending.return_confirm_text", {"asset": asset_name})
	dialog.ok_button_text = _t("ui.lending.return_asset")
	dialog.confirmed.connect(_return_loan_asset.bind(loan_id, asset_id, asset_name))
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(430, 180))


func _return_loan_asset(loan_id: String, asset_id: String, asset_name: String) -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/LendingService")
	var result: Dictionary = await service.return_assets(loan_id, [asset_id])
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(str(result.get("error", _t("ui.lending.error.action"))))
		return
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("add_system_message"):
		overlay.call("add_system_message", _t("ui.lending.notification.you_returned", {"asset": asset_name}))
	await _refresh_after_asset_return()
	await _refresh_assets()
	await _refresh_loans()


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
			return _t("ui.lending.card.offer_expires", {"date": _format_loan_time(str(loan.get("offerExpiresAt", "")))})
		"active":
			return _t("ui.lending.card.due", {"date": _format_loan_time(str(loan.get("dueAt", "")))})
		"return_pending":
			return _t("ui.lending.card.return_requested", {"date": _format_loan_time(str(loan.get("returnRequestedAt", "")))})
		"returned":
			return _t("ui.lending.card.returned", {"date": _format_loan_time(str(loan.get("returnedAt", "")))})
		"expired":
			return _t("ui.lending.card.expired", {"date": _format_loan_time(str(loan.get("offerExpiresAt", "")))})
	return _t("ui.lending.card.created", {"date": _format_loan_time(str(loan.get("createdAt", "")))})


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
	for key: Variant in selected_pokemon.keys():
		pokemon_ids.append(int(key))
	var items: Array[Dictionary] = []
	for key_value: Variant in selected_items.keys():
		var key := str(key_value)
		if key.begins_with("held:"):
			var pokemon_id := int(key.trim_prefix("held:"))
			var candidate := _candidate_by_id(pokemon_id)
			items.append({"itemId": str(candidate.get("heldItemId", "")), "sourcePokemonId": pokemon_id})
		else:
			items.append({"itemId": key.trim_prefix("bag:")})
	if pokemon_ids.size() > 6 or items.size() > 6:
		_show_error(_t("ui.lending.error.selection_limit"))
		return
	if not pokemon_ids.is_empty() and pokemon_ids.size() >= party_candidates.size():
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
		"request-return": result = await service.request_return(loan_id)
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
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("ui.lending.attach_title", {"item": item_id})
	dialog.dialog_text = _t("ui.lending.attach_description")
	dialog.ok_button_text = _t("ui.lending.attach_item")
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(310, 36)
	for candidate: Dictionary in eligible:
		selector.add_item("%s · Lv. %d" % [str(candidate.get("name", "Pokémon")), int(candidate.get("level", 1))])
		selector.set_item_metadata(selector.item_count - 1, int(candidate.get("pokemonId", 0)))
	dialog.add_child(selector)
	dialog.confirmed.connect(func():
		var pokemon_id := int(selector.get_item_metadata(selector.selected))
		_attach_item_to_pokemon(asset_id, pokemon_id)
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(390, 190))


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
	var current := int(duration_select.get_item_metadata(duration_select.selected)) if duration_select.item_count > 0 else 86400
	duration_select.clear()
	var durations: Array = capabilities.get("durationsSeconds", [3600, 86400, 259200, 604800])
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
			result.append({"pokemonId": pokemon_id, "name": _pokemon_display_name(payload), "speciesId": species_id, "level": int(payload.get("level", 1)), "heldItemId": str(payload.get("heldItemId", payload.get("item", ""))), "pokemon": payload})
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


func _poll_incoming_offers() -> void:
	if incoming_poll_in_flight:
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
	var body: Dictionary = result.get("body", {})
	for value: Variant in body.get("loans", []):
		if value is Dictionary and str(value.get("status", "")) == "pending":
			pending.append(value.duplicate(true))
	var signature_parts: Array[String] = []
	for offer: Dictionary in pending:
		signature_parts.append(str(offer.get("loanId", "")))
	var signature := "|".join(signature_parts)
	if signature != last_incoming_signature and incoming_dialog != null and incoming_dialog.has_method("show_offers"):
		incoming_dialog.call("show_offers", pending, true)
	last_incoming_signature = signature


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
			if item_id == "" or int(entry.get("quantity", 0)) <= 0 or category in ["key-items", "key_items", "important"]: continue
			result.append({"itemId": item_id, "name": _item_display_name(item_id, str(entry.get("name", item_id))), "quantity": int(entry.get("quantity", 0))})
	return result


func _candidate_by_id(pokemon_id: int) -> Dictionary:
	for candidate: Dictionary in party_candidates:
		if int(candidate.get("pokemonId", 0)) == pokemon_id: return candidate
	return {}


func _set_selected(target: Dictionary, key: Variant, enabled: bool) -> void:
	if enabled: target[key] = true
	else: target.erase(key)


func _toggle_pokemon_selection(enabled: bool, pokemon_id: int, checkbox: CheckBox) -> void:
	if not enabled:
		selected_pokemon.erase(pokemon_id)
		return
	var maximum_selection := maxi(party_candidates.size() - 1, 0)
	if selected_pokemon.size() >= maximum_selection:
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
	panel.add_theme_stylebox_override("panel", _style(Color("#07111df0"), BORDER, 7))
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
	level_label.add_theme_color_override("font_color", MUTED)
	level_label.add_theme_font_size_override("font_size", 10)
	identity.add_child(level_label)
	var view := Button.new()
	view.text = _t("ui.lending.invitation.view")
	view.pressed.connect(_open_pokemon_summary.bind(payload))
	_apply_button_style(view)
	row.add_child(view)
	return panel


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
	box.toggled.connect(func(enabled: bool): _set_selected(selected_items, selection_key, enabled))
	row.add_child(box)
	var item_id := str(item.get("itemId", ""))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.texture = _load_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = "%s%s" % ["↳ " if held else "", str(item.get("name", item_id))]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT)
	row.add_child(label)
	var quantity := Label.new()
	quantity.text = "×%d" % int(item.get("quantity", 1))
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.add_theme_color_override("font_color", MUTED)
	row.add_child(quantity)
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
	select.add_theme_color_override("font_color", TEXT)
	select.add_theme_stylebox_override("normal", _input_style(Color("#07111df5"), BORDER))
	select.add_theme_stylebox_override("hover", _input_style(Color("#102238f5"), ACCENT))
	select.add_theme_stylebox_override("pressed", _input_style(Color("#071526f5"), ACCENT))
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


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
		3600: return _t("ui.lending.duration.hour")
		86400: return _t("ui.lending.duration.day")
		259200: return _t("ui.lending.duration.three_days")
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
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.call("text", key, values)) if localization != null else key
