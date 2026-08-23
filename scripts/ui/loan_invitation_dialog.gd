extends Window

class_name LoanInvitationDialog

signal offers_changed

const DIALOG_SIZE := Vector2i(560, 440)
const BG := Color("#050912fa")
const SURFACE := Color("#0b1a2bf7")
const BORDER := Color("#2d4b66b3")
const ACCENT := Color("#62d7ff")
const GOLD := Color("#d8b767")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")

var offers: Array[Dictionary] = []
var offer: Dictionary = {}
var action_in_flight := false
var heading_label: Label
var terms_label: Label
var count_label: Label
var assets_list: VBoxContainer
var accept_button: Button
var decline_button: Button


func setup() -> void:
	hide()
	title = _t("ui.lending.invitation.window_title")
	min_size = DIALOG_SIZE
	max_size = DIALOG_SIZE
	size = DIALOG_SIZE
	unresizable = true
	borderless = true
	_build_ui()
	close_requested.connect(hide)


func clear_offers() -> void:
	offers.clear()
	offer.clear()
	hide()


func show_offers(values: Array[Dictionary], popup_when_new := true) -> void:
	offers = values.duplicate(true)
	if offers.is_empty():
		clear_offers()
		return
	var active_id := str(offer.get("loanId", ""))
	var selected := offers[0]
	for candidate: Dictionary in offers:
		if str(candidate.get("loanId", "")) == active_id:
			selected = candidate
			break
	offer = selected.duplicate(true)
	_render_offer()
	if popup_when_new and not visible:
		popup_centered(DIALOG_SIZE)


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _outer_style())
	add_child(background)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 15)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)
	var title_label := Label.new()
	title_label.text = _t("ui.lending.invitation.title")
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", TEXT)
	title_stack.add_child(title_label)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", ACCENT)
	title_stack.add_child(count_label)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(38, 34)
	close.pressed.connect(hide)
	_style_button(close, "danger")
	header.add_child(close)

	heading_label = Label.new()
	heading_label.add_theme_font_size_override("font_size", 17)
	heading_label.add_theme_color_override("font_color", TEXT)
	root.add_child(heading_label)
	terms_label = Label.new()
	terms_label.add_theme_color_override("font_color", GOLD)
	terms_label.add_theme_font_size_override("font_size", 11)
	root.add_child(terms_label)

	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", _panel_style(SURFACE, BORDER, 9, 1))
	root.add_child(content)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 10)
	content_margin.add_theme_constant_override("margin_top", 9)
	content_margin.add_theme_constant_override("margin_right", 10)
	content_margin.add_theme_constant_override("margin_bottom", 9)
	content.add_child(content_margin)
	var scroll := ScrollContainer.new()
	content_margin.add_child(scroll)
	assets_list = VBoxContainer.new()
	assets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assets_list.add_theme_constant_override("separation", 6)
	scroll.add_child(assets_list)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 9)
	root.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	decline_button = Button.new()
	decline_button.text = _t("common.decline")
	decline_button.custom_minimum_size = Vector2(112, 38)
	decline_button.pressed.connect(_decline)
	_style_button(decline_button)
	actions.add_child(decline_button)
	accept_button = Button.new()
	accept_button.text = _t("common.accept")
	accept_button.custom_minimum_size = Vector2(132, 38)
	accept_button.pressed.connect(_accept)
	_style_button(accept_button, "primary")
	actions.add_child(accept_button)


func _render_offer() -> void:
	if offer.is_empty():
		return
	heading_label.text = _t("ui.lending.invitation.from", {"trainer": str(offer.get("lenderUsername", "Trainer"))})
	terms_label.text = _t("ui.lending.invitation.terms", {
		"duration": _duration_label(int(offer.get("durationSeconds", 0))),
		"fee": int(offer.get("feeAmount", 0)),
	})
	terms_label.add_theme_color_override("font_color", GOLD)
	count_label.text = _t("ui.lending.invitation.pending_count", {"count": offers.size()})
	_clear(assets_list)
	var values: Array = offer.get("assets", []) if offer.get("assets", []) is Array else []
	for value: Variant in values:
		if value is Dictionary:
			assets_list.add_child(_asset_row(value))
	accept_button.disabled = action_in_flight
	decline_button.disabled = action_in_flight


func _asset_row(asset: Dictionary) -> Control:
	var snapshot: Dictionary = asset.get("snapshot", {}).duplicate(true)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 58
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07111df0"), BORDER, 7, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	var name_label := Label.new()
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 13)
	identity.add_child(name_label)
	var detail := Label.new()
	detail.add_theme_color_override("font_color", MUTED)
	detail.add_theme_font_size_override("font_size", 10)
	identity.add_child(detail)
	if str(asset.get("assetType", "")) == "pokemon":
		var species := str(snapshot.get("speciesId", snapshot.get("species", snapshot.get("speciesName", ""))))
		icon.texture = PokemonAssets.load_party_icon(species, bool(snapshot.get("shiny", false)))
		name_label.text = _pokemon_name(snapshot)
		detail.text = "Lv. %d" % maxi(int(snapshot.get("level", 1)), 1)
		var view := Button.new()
		view.text = _t("ui.lending.invitation.view")
		view.pressed.connect(_open_summary.bind(snapshot))
		_style_button(view)
		row.add_child(view)
	else:
		var item_id := str(asset.get("itemId", snapshot.get("itemId", "")))
		icon.texture = _item_icon(item_id)
		name_label.text = _item_name(item_id, str(snapshot.get("name", item_id)))
		detail.text = _t("ui.lending.invitation.item")
	return panel


func _accept() -> void:
	await _act("accept")


func _decline() -> void:
	await _act("decline")


func _act(action: String) -> void:
	if action_in_flight or offer.is_empty():
		return
	action_in_flight = true
	_render_offer()
	var service := get_node_or_null("/root/LendingService")
	var loan_id := str(offer.get("loanId", ""))
	var result: Dictionary = await service.accept_loan(loan_id) if action == "accept" else await service.decline_loan(loan_id)
	action_in_flight = false
	if not bool(result.get("success", false)):
		terms_label.text = _friendly_error(result)
		terms_label.add_theme_color_override("font_color", Color("#ff7b82"))
		accept_button.disabled = false
		decline_button.disabled = false
		return
	var resolved_offer := offer.duplicate(true)
	hide()
	offer.clear()
	_notify_resolution(action)
	if action == "accept":
		await _refresh_after_acceptance(resolved_offer)
	offers_changed.emit()


func _refresh_after_acceptance(resolved_offer: Dictionary) -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service != null and party_service.has_method("refresh_party"):
		await party_service.call("refresh_party")
	var assets: Array = resolved_offer.get("assets", []) if resolved_offer.get("assets", []) is Array else []
	var has_items := false
	for value: Variant in assets:
		if value is Dictionary and str(value.get("assetType", "")) == "item":
			has_items = true
			break
	if has_items:
		var inventory_service := get_node_or_null("/root/InventoryService")
		if inventory_service != null and inventory_service.has_method("load_inventory"):
			await inventory_service.call("load_inventory")
	if int(resolved_offer.get("feeAmount", 0)) > 0:
		var wallet_service := get_node_or_null("/root/PlayerWalletService")
		if wallet_service != null and wallet_service.has_method("load_wallet"):
			var wallet_result: Dictionary = await wallet_service.call("load_wallet")
			if bool(wallet_result.get("success", false)) and wallet_service.has_method("apply_wallet_result"):
				wallet_service.call("apply_wallet_result", wallet_result)
				get_tree().call_group("ui_overlay", "refresh_money_display")
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("_refresh_pc_state"):
		await overlay.call("_refresh_pc_state", true)


func _notify_resolution(action: String) -> void:
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay == null or not overlay.has_method("add_system_message"):
		return
	var key := "ui.lending.invitation.accepted" if action == "accept" else "ui.lending.invitation.declined"
	overlay.call("add_system_message", _t(key))


func _friendly_error(result: Dictionary) -> String:
	var code := str(result.get("code", ""))
	if code in ["loan_same_map_required", "loan_presence_unavailable"]:
		var localizer := get_node_or_null("/root/BackendErrorLocalization")
		if localizer != null:
			return str(localizer.call("message", result, "ui.lending.error.action"))
	return str(result.get("error", _t("ui.lending.error.action")))


func _open_summary(snapshot: Dictionary) -> void:
	var payload := snapshot.duplicate(true)
	if str(payload.get("species", "")).strip_edges() == "":
		payload["species"] = str(payload.get("speciesId", payload.get("speciesName", "")))
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("open_trade_pokemon_summary"):
		overlay.call("open_trade_pokemon_summary", payload)


func _pokemon_name(snapshot: Dictionary) -> String:
	var nickname := str(snapshot.get("nickname", "")).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	var species_id := str(snapshot.get("speciesId", snapshot.get("species", "")))
	var fallback := str(snapshot.get("speciesName", species_id))
	var localizer := get_node_or_null("/root/ContentLocalization")
	return str(localizer.call("display_name", "species", species_id, fallback)) if localizer != null else fallback


func _item_name(item_id: String, fallback: String) -> String:
	var localizer := get_node_or_null("/root/ItemLocalization")
	return str(localizer.call("display_name", item_id, fallback)) if localizer != null else fallback


func _item_icon(item_id: String) -> Texture2D:
	var normalized := item_id.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	for path: String in ["res://assets/items/icons/%s.png" % normalized, "res://assets/items/icons/%s.png" % item_id.strip_edges(), "res://assets/items/icons/000.png"]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _duration_label(seconds: int) -> String:
	match seconds:
		3600: return _t("ui.lending.duration.hour")
		86400: return _t("ui.lending.duration.day")
		259200: return _t("ui.lending.duration.three_days")
		604800: return _t("ui.lending.duration.week")
	return "%d h" % maxi(seconds / 3600, 1)


func _style_button(button: Button, kind := "secondary") -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var primary := kind == "primary"
	var danger := kind == "danger"
	var normal := Color("#0d4359") if primary else (Color("#2a1015") if danger else Color("#111d2c"))
	var hover := Color("#12627f") if primary else (Color("#6a1f2a") if danger else Color("#192c42"))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#667382"))
	button.add_theme_stylebox_override("normal", _button_style(normal, ACCENT if primary else BORDER))
	button.add_theme_stylebox_override("hover", _button_style(hover, ACCENT))
	button.add_theme_stylebox_override("pressed", _button_style(BG, ACCENT))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _button_style(Color("#0a1018"), Color("#253344")))


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 7, 1)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _outer_style() -> StyleBoxFlat:
	var style := _panel_style(BG, Color("#62d7ff99"), 12, 1)
	style.border_width_top = 2
	style.shadow_color = Color("#00000099")
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 7)
	return style


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _t(key: String, values := {}) -> String:
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.call("text", key, values)) if localization != null else key.format(values)
