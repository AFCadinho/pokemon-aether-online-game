class_name AetheringPopup
extends PanelContainer

signal closed
signal completed(result: Dictionary)

const STATS := ["hp", "atk", "def", "spa", "spd", "spe"]
const WINGS := ["health-wing", "muscle-wing", "resist-wing", "genius-wing", "clever-wing", "swift-wing"]
const CONFIRM_DIALOG := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const CYAN := Color("74d7ef")
const MUTED := Color("91a4b7")
const GREEN := Color("70d6a1")
const RED := Color("ef7085")

var candidates: Array = []
var wing_availability: Dictionary = {}
var recipient: Dictionary = {}
var donor: Dictionary = {}
var plan: Dictionary = {}
var recipient_lock: Variant = null
var donor_lock: Variant = null
var resources_ready := false
var busy := false
var choosing_donor := false
var confirmation_open := false
var last_result: Dictionary = {}
var result_before: Dictionary = {}

var title: Label
var help_label: Label
var cards: HBoxContainer
var recipient_details: VBoxContainer
var donor_details: VBoxContainer
var recipient_select: Button
var donor_select: Button
var recipient_options: OptionButton
var donor_options: OptionButton
var grid: GridContainer
var wing_stock: Label
var status: Label
var preview_button: Button
var confirm_button: Button
var next_donor_button: Button
var scroll: ScrollContainer
var close_button: Button
var refresh_button: Button
var picker: VBoxContainer
var search: LineEdit
var location_filter: OptionButton
var picker_list: ItemList
var picker_rows: Array = []
var results: RichTextLabel

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("050b14fa")
	style.border_color = Color("397b9c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", style)
	_build()
	get_viewport().size_changed.connect(_fit)
	LocalizationManager.locale_changed.connect(_locale_changed)
	_fit()

func _fit() -> void:
	var available := get_viewport_rect().size
	var target := Vector2(minf(920, available.x - 24), minf(690, available.y - 24))
	size = target
	position = (available - target) / 2.0

func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = _label("", CYAN, 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	refresh_button = _button("", refresh)
	header.add_child(refresh_button)
	close_button = _button("×", close_popup)
	header.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	help_label = _label("", MUTED)
	content.add_child(help_label)
	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	content.add_child(cards)
	recipient_details = _card(cards, CYAN)
	recipient_select = _button("", _open_picker.bind(false))
	recipient_details.add_child(recipient_select)
	recipient_options = _locks(recipient_details, false)
	donor_details = _card(cards, RED)
	donor_select = _button("", _open_picker.bind(true))
	donor_details.add_child(donor_select)
	donor_options = _locks(donor_details, true)
	picker = VBoxContainer.new()
	picker.visible = false
	content.add_child(picker)
	var filters := HBoxContainer.new()
	picker.add_child(filters)
	search = LineEdit.new()
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 40
	search.text_changed.connect(func(_value: String): _render_picker())
	filters.add_child(search)
	location_filter = OptionButton.new()
	location_filter.custom_minimum_size.y = 40
	location_filter.item_selected.connect(func(_index: int): _render_picker())
	filters.add_child(location_filter)
	filters.add_child(_button("×", func(): picker.hide()))
	picker_list = ItemList.new()
	picker_list.custom_minimum_size.y = 230
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.fixed_icon_size = Vector2i(40, 40)
	picker_list.item_selected.connect(_pick)
	picker.add_child(picker_list)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 7)
	content.add_child(grid)
	wing_stock = _label("", CYAN)
	content.add_child(wing_stock)
	results = RichTextLabel.new()
	results.bbcode_enabled = true
	results.fit_content = true
	results.scroll_active = false
	results.add_theme_font_size_override("normal_font_size", 15)
	results.visible = false
	content.add_child(results)
	status = _label("", MUTED)
	layout.add_child(status)
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	preview_button = _button("", _preview)
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(preview_button)
	confirm_button = _button("", _ask_confirm)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm_button)
	next_donor_button = _button("", _open_picker.bind(true))
	actions.add_child(next_donor_button)
	_localize()

func _card(parent: Node, color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081522")
	style.border_color = color.darkened(0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(72, 72)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(sprite)
	stack.add_child(_label("", color, 16))
	stack.add_child(_label("", MUTED, 12))
	return stack

func _locks(parent: Node, is_donor: bool) -> OptionButton:
	var options := OptionButton.new()
	options.custom_minimum_size.y = 42
	options.item_selected.connect(_lock_changed.bind(is_donor))
	parent.add_child(options)
	return options

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 44)
	button.pressed.connect(action)
	button.add_theme_color_override("font_color", Color("eef5fb"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("112a44") if state in ["hover", "focus"] else Color("0b1d30")
		style.border_color = CYAN if state in ["hover", "focus"] else Color("355672")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	return button

func _label(text: String, color: Color, font_size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.aethering." + key, values)

func _stat(stat: String) -> String:
	return _t("stat." + stat)

func _localize() -> void:
	title.text = _t("title")
	help_label.text = _t("help")
	refresh_button.text = _t("refresh")
	preview_button.text = _t("preview")
	confirm_button.text = _t("retry") if not AetheringService.pending.is_empty() else _t("confirm")
	recipient_select.text = _t("choose_recipient")
	donor_select.text = _t("choose_donor")
	next_donor_button.text = _t("next_donor")
	search.placeholder_text = _t("search")
	var selected := location_filter.selected
	location_filter.clear()
	for key in ["all", "party", "pc"]:
		location_filter.add_item(_t(key))
	location_filter.select(maxi(selected, 0))

func _locale_changed(_locale: String) -> void:
	_localize()
	_render()
	_render_picker()
	_render_result()

func open_aethering() -> void:
	visible = true
	var pending := AetheringService.restore_pending()
	if not pending.is_empty():
		plan = pending["plan"]
		recipient = pending["context"].get("recipient", {})
		donor = pending["context"].get("donor", {})
		recipient_lock = null
		donor_lock = null
		for stat: String in STATS:
			var mode: String = str(plan.get("stats", {}).get(stat, {}).get("mode", ""))
			if mode == "recipient_lock":
				recipient_lock = stat
			elif mode == "donor_lock":
				donor_lock = stat
		status.text = _t("unresolved")
	await refresh()

func close_popup() -> void:
	if busy or confirmation_open:
		return
	visible = false
	closed.emit()

func refresh() -> void:
	if busy or confirmation_open:
		return
	busy = true
	_update_buttons()
	if AetheringService.pending.is_empty():
		plan.clear()
	var response := await AetheringService.load_candidates()
	if bool(response.get("success", false)):
		candidates = response["data"].get("candidates", [])
		wing_availability.clear()
		for wing: Dictionary in response["data"].get("wingInventory", []):
			wing_availability[str(wing["itemId"])] = int(wing["availableQuantity"])
		if AetheringService.pending.is_empty():
			recipient = _find(int(recipient.get("pokemonId", 0)))
			donor = _find(int(donor.get("pokemonId", 0)))
	else:
		status.text = _error(response)
	var inventory := await InventoryService.load_inventory()
	var wallet := await PlayerWalletService.load_wallet()
	PlayerWalletService.apply_wallet_result(wallet)
	resources_ready = bool(inventory.get("success", false)) and bool(wallet.get("success", false)) and bool(response.get("success", false))
	if not resources_ready:
		status.text = _t("refresh_failed")
	busy = false
	_render()
	_render_picker()
	completed.emit({"refreshOnly": true})

func _find(id: int) -> Dictionary:
	for entry: Dictionary in candidates:
		if int(entry.get("pokemonId", 0)) == id:
			return entry
	return {}

static func compatible(left: Dictionary, right: Dictionary) -> bool:
	var a: Array = left.get("eggGroups", [])
	var b: Array = right.get("eggGroups", [])
	if a.has("ditto") or b.has("ditto"):
		return a == ["ditto"] and b == ["ditto"]
	for group: String in a:
		if b.has(group):
			return true
	return false

func _reason(entry: Dictionary, is_donor: bool) -> String:
	if is_donor and int(entry.get("pokemonId", 0)) == int(recipient.get("pokemonId", -1)):
		return _t("same_pokemon")
	var code: String = str(entry.get("donorBlockedReason" if is_donor else "recipientBlockedReason", ""))
	if code != "" and code != "<null>":
		return _t("reason." + code)
	if not bool(entry.get("donorAllowed" if is_donor else "recipientAllowed", false)):
		return _t("unavailable")
	if is_donor and not compatible(recipient, entry):
		return _t("incompatible")
	return ""

func _open_picker(is_donor: bool) -> void:
	if busy or confirmation_open or not AetheringService.pending.is_empty():
		return
	choosing_donor = is_donor
	picker.show()
	search.text = ""
	_render_picker()
	scroll.ensure_control_visible.call_deferred(picker)

func _name(entry: Dictionary) -> String:
	var pokemon: Dictionary = entry.get("pokemon", {})
	var species_id := str(pokemon.get("speciesId", pokemon.get("species", "")))
	var species_name := ContentLocalization.display_name("species", species_id, species_id.capitalize())
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	var display_name := species_name if nickname.is_empty() else nickname + " (" + species_name + ")"
	return display_name + (" ★" if bool(entry.get("shiny", false)) else "")

func _groups(entry: Dictionary) -> String:
	var names: Array[String] = []
	for group: String in entry.get("eggGroups", []):
		names.append(_t("group." + group))
	return ", ".join(names)

func _location(entry: Dictionary) -> String:
	var location: Dictionary = entry.get("location", {})
	return _t("party") if location.get("type") == "party" else _t("box", {"number": int(location.get("boxIndex", 0)) + 1})

static func donor_score(entry: Dictionary, target: Dictionary) -> int:
	var values: Dictionary = entry.get("pokemon", {}).get("ivs", {})
	var original: Dictionary = target.get("pokemon", {}).get("ivs", {})
	var score := 0
	for stat: String in STATS:
		if values.get(stat, -1) == original.get(stat, -2):
			score += 100 if int(values.get(stat, -1)) in [0, 31] else 10
		if int(values.get(stat, -1)) == 31:
			score += 1
	return score

func _render_picker() -> void:
	if picker_list == null:
		return
	picker_list.clear()
	picker_rows.clear()
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var allowed_a := _reason(a, choosing_donor).is_empty()
		var allowed_b := _reason(b, choosing_donor).is_empty()
		if allowed_a != allowed_b:
			return allowed_a
		if choosing_donor and donor_score(a, recipient) != donor_score(b, recipient):
			return donor_score(a, recipient) > donor_score(b, recipient)
		return _name(a).naturalnocasecmp_to(_name(b)) < 0)
	for entry: Dictionary in sorted:
		var location: String = str(entry.get("location", {}).get("type", ""))
		if location_filter.selected == 1 and location != "party" or location_filter.selected == 2 and location != "box":
			continue
		var description := "%s · %s · %s" % [_name(entry), _location(entry), _groups(entry)]
		if not search.text.is_empty() and not (description + str(entry.get("pokemon", {}).get("species", ""))).to_lower().contains(search.text.to_lower()):
			continue
		var reason := _reason(entry, choosing_donor)
		if not reason.is_empty():
			description += " — " + reason
		var pokemon: Dictionary = entry.get("pokemon", {})
		var sprite := PokemonAssets.load_home_sprite(str(pokemon.get("speciesId", pokemon.get("species", ""))), bool(entry.get("shiny", false)))
		var index := picker_list.add_item(description, sprite)
		picker_list.set_item_disabled(index, not reason.is_empty())
		picker_list.set_item_tooltip(index, description + "\n" + str(pokemon.get("ivs", {})))
		picker_rows.append(entry)

func _pick(index: int) -> void:
	if busy or confirmation_open or not AetheringService.pending.is_empty() or index < 0 or index >= picker_rows.size():
		return
	var entry: Dictionary = picker_rows[index]
	if not _reason(entry, choosing_donor).is_empty():
		return
	plan.clear()
	if choosing_donor:
		donor = entry
	else:
		recipient = entry
		donor = {}
		last_result.clear()
		results.hide()
	picker.hide()
	status.text = _t("ready")
	_render()
	scroll.ensure_control_visible.call_deferred(cards)

func _lock_changed(index: int, is_donor: bool) -> void:
	if busy or confirmation_open or not AetheringService.pending.is_empty():
		return
	var stat: Variant = null if index == 0 else STATS[index - 1]
	var other: Variant = recipient_lock if is_donor else donor_lock
	if stat != null and stat == other:
		status.text = _t("reason.aethering_locks_invalid")
		_render()
		return
	if is_donor:
		donor_lock = stat
	else:
		recipient_lock = stat
	plan.clear()
	_render()

func _populate_locks(options: OptionButton, selected: Variant, other: Variant) -> void:
	options.clear()
	options.add_item(_t("no_lock"))
	for stat: String in STATS:
		options.add_item(_stat(stat))
		options.set_item_disabled(options.item_count - 1, other == stat)
	options.select(0 if selected == null else STATS.find(selected) + 1)

func _render_card(stack: VBoxContainer, entry: Dictionary, label: String) -> void:
	var pokemon: Dictionary = entry.get("pokemon", {})
	(stack.get_child(0) as TextureRect).texture = PokemonAssets.load_home_sprite(str(pokemon.get("speciesId", pokemon.get("species", ""))), bool(entry.get("shiny", false))) if not entry.is_empty() else null
	(stack.get_child(1) as Label).text = label + (" · " + _name(entry) if not entry.is_empty() else "")
	(stack.get_child(2) as Label).text = _location(entry) + " · " + _groups(entry) if not entry.is_empty() else _t("none_selected")

func _render() -> void:
	_render_card(recipient_details, recipient, _t("recipient"))
	_render_card(donor_details, donor, _t("donor"))
	_populate_locks(recipient_options, recipient_lock, donor_lock)
	_populate_locks(donor_options, donor_lock, recipient_lock)
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for caption in [_t("stat"), _t("recipient"), _t("donor"), _t("outcome")]:
		grid.add_child(_label(caption, MUTED))
	for stat: String in STATS:
		var left: Variant = recipient.get("pokemon", {}).get("ivs", {}).get(stat)
		var right: Variant = donor.get("pokemon", {}).get("ivs", {}).get(stat)
		grid.add_child(_label(_stat(stat), CYAN))
		grid.add_child(_label(str(int(left)) if left != null else "—", GREEN if left == right and left != null else Color.WHITE))
		grid.add_child(_label(str(int(right)) if right != null else "—", GREEN if left == right and left != null else Color.WHITE))
		var entry: Dictionary = plan.get("stats", {}).get(stat, {})
		var mode: String = str(entry.get("mode", ""))
		var outcome := _t("needs_preview") if entry.is_empty() else _t("mode." + mode, {"value": int(entry.get("guaranteedIV", 0)) if entry.get("guaranteedIV") != null else ""})
		grid.add_child(_label(outcome, MUTED if entry.is_empty() else RED if mode == "reroll" else GREEN))
	var stock: Array[String] = []
	for index in range(STATS.size()):
		var count := _wing_count(WINGS[index])
		var needed: bool = recipient_lock == STATS[index] or donor_lock == STATS[index]
		stock.append("%s: %d%s" % [ItemLocalization.display_name(WINGS[index]), count, " (-1)" if needed else ""])
	wing_stock.text = _t("cost", {"money": PlayerSave.money}) + "\n" + " · ".join(stock)
	if not plan.is_empty():
		wing_stock.text += "\n" + _t("preview_ready", {"expires": str(plan.get("expiresAt", "")).substr(11, 5) + " UTC"})
	_update_buttons()

func _wing_count(item_id: String) -> int:
	if wing_availability.has(item_id):
		return int(wing_availability[item_id])
	for item: Dictionary in InventoryService.cached_inventory_items:
		if str(item.get("itemId", item.get("id", ""))) == item_id:
			return int(item.get("quantity", 0))
	return 0

func _update_buttons() -> void:
	var unresolved := not AetheringService.pending.is_empty()
	var frozen := busy or unresolved or confirmation_open
	recipient_select.disabled = frozen
	donor_select.disabled = frozen or recipient.is_empty()
	recipient_options.disabled = frozen or recipient.is_empty()
	donor_options.disabled = frozen or donor.is_empty()
	refresh_button.disabled = busy or confirmation_open
	close_button.disabled = busy or confirmation_open
	preview_button.disabled = frozen or not resources_ready or recipient.is_empty() or donor.is_empty()
	confirm_button.disabled = busy or confirmation_open or plan.is_empty()
	confirm_button.text = _t("retry") if unresolved else _t("confirm")
	next_donor_button.visible = not last_result.is_empty()
	next_donor_button.disabled = frozen or recipient.is_empty()

func _preview() -> void:
	if preview_button.disabled:
		return
	busy = true
	_update_buttons()
	plan.clear()
	var response := await AetheringService.preview({"recipientId": recipient["pokemonId"], "donorId": donor["pokemonId"], "recipientLock": recipient_lock, "donorLock": donor_lock})
	if bool(response.get("success", false)):
		plan = response["data"]
		status.text = _t("warning")
	else:
		status.text = _error(response)
	busy = false
	_render()

func _ask_confirm() -> void:
	if busy or confirmation_open or plan.is_empty():
		return
	if not AetheringService.pending.is_empty():
		await _execute()
		return
	confirmation_open = true
	_update_buttons()
	var dialog := CONFIRM_DIALOG.instantiate() as AetherConfirmationDialog
	add_child(dialog)
	var message := _t("confirm_message", {"donor": _name(donor), "recipient": _name(recipient), "wings": plan.get("requiredWings", []).size()})
	var shiny := bool(plan.get("shinyDonor", false))
	if shiny:
		message = _t("shiny_warning", {"donor": _name(donor)}) + "\n\n" + message
	dialog.configure(_t("confirm_title"), message, _t("consume"), LocalizationManager.text("common.cancel"))
	if shiny:
		dialog.configure_option(_t("shiny_acknowledge"))
		dialog.confirm_button.disabled = true
		dialog.option_checkbox.toggled.connect(func(checked: bool): dialog.confirm_button.disabled = not checked)
	dialog.canceled.connect(func():
		confirmation_open = false
		dialog.queue_free()
		_update_buttons(), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(func():
		confirmation_open = false
		dialog.queue_free()
		if not AetheringService.begin_confirmation(plan, {"recipient": recipient, "donor": donor}):
			status.text = _t("persist_failed")
			_update_buttons()
			return
		await _execute(), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(560, 370))

func _execute() -> void:
	busy = true
	_update_buttons()
	result_before = AetheringService.pending.get("context", {}).get("recipient", {}).get("pokemon", {}).get("ivs", {}).duplicate(true)
	var response := await AetheringService.confirm_pending()
	if bool(response.get("success", false)):
		last_result = response["data"]
		# Quantity-only receipts are not full Bag metadata. Refresh normal readers.
		PlayerSave.replace_party_from_state(last_result.get("party", []))
		PlayerSave.money = int(last_result.get("money", PlayerSave.money))
		donor.clear()
		plan.clear()
		donor_lock = null
		var removed_id := int(last_result.get("donorId", 0))
		candidates = candidates.filter(func(entry: Dictionary): return int(entry.get("pokemonId", 0)) != removed_id)
		if not recipient.is_empty():
			recipient["pokemon"] = last_result.get("recipient", {})
		_render_result()
		completed.emit(last_result)
		await PlayerPartyStateService.refresh_party()
		busy = false
		await refresh()
		status.text = _t("success") if resources_ready else _t("success") + "\n" + _t("refresh_failed")
		scroll.ensure_control_visible.call_deferred(results)
	else:
		status.text = _error(response) if AetheringService.pending.is_empty() else _t("unresolved")
		if AetheringService.pending.is_empty():
			plan.clear()
		busy = false
	_render()

func _render_result() -> void:
	if last_result.is_empty():
		return
	var lines: Array[String] = [_t("result")]
	for stat: String in STATS:
		var before := int(result_before.get(stat, 0))
		var after := int(last_result.get("ivs", {}).get(stat, 0))
		var delta := after - before
		var color := RED if delta < 0 else GREEN if delta > 0 else MUTED
		lines.append("[color=#%s]%s: %d → %d  (%+d)[/color]" % [color.to_html(false), _stat(stat), before, after, delta])
	results.text = "\n".join(lines)
	results.show()

func _error(response: Dictionary) -> String:
	var detail: Variant = response.get("body", {}).get("detail", {})
	if detail is String and detail == "not enough items":
		return _t("missing_wings")
	if detail is Dictionary:
		var code := str(detail.get("code", ""))
		var key := "reason." + code
		var localized := _t(key)
		if localized != "ui.aethering." + key:
			return localized
	return str(response.get("error", _t("unavailable")))
