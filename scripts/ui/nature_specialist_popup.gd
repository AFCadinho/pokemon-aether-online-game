class_name NatureSpecialistPopup
extends PanelContainer

signal closed
var pokemon_select: OptionButton
var nature_select: OptionButton
var status_label: Label
var preview_button: Button
var confirm_button: Button
var close_button: Button
var confirmation: AetherConfirmationDialog
var entries: Array = []
var quote: Dictionary = {}
var busy := false
var generation := 0
var cooldown := false

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.nature_specialist." + key, values)

const STATS := ["hp", "atk", "def", "spa", "spd", "spe"]
const TEXT := Color("e6eff6")
const MUTED := Color("8fa6b8")
const ACCENT := Color("8ce2b0")
const CYAN := Color("74d7ef")
const RED := Color("f18a97")
const MINT := preload("res://assets/items/icons/ADAMANTMINT.png")

var title_label: Label
var explanation_label: Label
var section_labels: Dictionary = {}
var pokemon_image: TextureRect
var pokemon_name: Label
var pokemon_info: Label
var nature_info: Label
var iv_values: Dictionary = {}
var stat_values: Dictionary = {}
var price_label: Label
var wallet_label: Label
var quote_hint: Label
var cached_state: Dictionary = {}
var content_scroll: ScrollContainer
var stats_panel: PanelContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", _box(Color("07121ffb"), Color("395b70"), 14, 20))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _box(Color("173829"), Color("39614a"), 12, 8))
	header.add_child(badge)
	var mint := TextureRect.new()
	mint.texture = MINT
	mint.custom_minimum_size = Vector2(36,36)
	mint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.add_child(mint)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	title_label = _label("", TEXT, 23)
	heading.add_child(title_label)
	var subtitle := _section("daycare", ACCENT)
	heading.add_child(subtitle)
	close_button = _button("×", close_specialist)
	close_button.custom_minimum_size = Vector2(40,40)
	header.add_child(close_button)
	explanation_label = _label("", MUTED, 13)
	layout.add_child(explanation_label)
	var scroll := ScrollContainer.new()
	content_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", _box(Color("091825"),Color.TRANSPARENT,4,0))
	for state: String in ["grabber","grabber_highlight","grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state,_box(Color("34586a") if state == "grabber" else Color("548c9a"),Color.TRANSPARENT,4,4))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	content.add_child(_section("pokemon_label"))
	pokemon_select = _select(_selection_changed)
	content.add_child(pokemon_select)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("0c1e2d"), Color("26465b"), 10, 10))
	content.add_child(card)
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 4)
	card.add_child(card_content)
	var pokemon_row := HBoxContainer.new()
	pokemon_row.add_theme_constant_override("separation", 12)
	card_content.add_child(pokemon_row)
	pokemon_image = TextureRect.new()
	pokemon_image.custom_minimum_size = Vector2(64,64)
	pokemon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokemon_row.add_child(pokemon_image)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_row.add_child(identity)
	pokemon_name = _label("", TEXT, 19)
	identity.add_child(pokemon_name)
	pokemon_info = _label("", MUTED, 12)
	identity.add_child(pokemon_info)
	nature_info = _label("", CYAN, 13)
	identity.add_child(nature_info)
	var iv_row := HBoxContainer.new()
	iv_row.add_theme_constant_override("separation", 6)
	card_content.add_child(iv_row)
	var iv_caption := _label("IVs", MUTED, 12)
	iv_caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	iv_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	iv_caption.custom_minimum_size.x = 26
	iv_row.add_child(iv_caption)
	for stat: String in STATS:
		var value := _label("", MUTED, 12)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iv_row.add_child(value)
		iv_values[stat] = value
	content.add_child(_section("target_label"))
	nature_select = _select(_selection_changed)
	content.add_child(nature_select)
	content.add_child(_section("stat_comparison"))
	stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _box(Color("091825"), Color("26465b"), 10, 12))
	content.add_child(stats_panel)
	var stats_stack := VBoxContainer.new()
	stats_stack.add_theme_constant_override("separation", 7)
	stats_panel.add_child(stats_stack)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	stats_stack.add_child(grid)
	for key: String in ["stat", "before", "after", "difference"]:
		var label := _section(key, MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if key == "stat" else HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(label)
	for stat: String in STATS:
		var name_label := _label(stat.to_upper(), TEXT, 13)
		grid.add_child(name_label)
		var cells: Array[Label] = []
		for _column in range(3):
			var value := _label("—", MUTED, 14)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(value)
			cells.append(value)
		stat_values[stat] = cells
	quote_hint = _label("", MUTED, 12)
	stats_stack.add_child(quote_hint)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	var payment := VBoxContainer.new()
	payment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(payment)
	payment.add_child(_section("price_label", MUTED))
	price_label = _label("—", ACCENT, 22)
	payment.add_child(price_label)
	wallet_label = _label("", MUTED, 12)
	payment.add_child(wallet_label)
	status_label = _label("", MUTED, 12)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(status_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)
	preview_button = _button("", _preview)
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(preview_button)
	confirm_button = _button("", _ask_confirm, true)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(confirm_button)
	confirmation = preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)
	get_viewport().size_changed.connect(_fit)
	LocalizationManager.locale_changed.connect(_locale_changed)
	_localize()
	_fit()
	_fit.call_deferred()

func _fit() -> void:
	var available := get_viewport_rect().size
	var target := Vector2(minf(720, available.x-24), minf(820, available.y-24))
	custom_minimum_size = Vector2.ZERO
	size = target
	position = (available-target)/2.0
	if not quote.is_empty():
		_reveal_comparison.call_deferred()

func _reveal_comparison() -> void:
	# Container sizes settle after text wrapping and viewport changes.
	await get_tree().process_frame
	await get_tree().process_frame
	if not quote.is_empty() and visible:
		content_scroll.ensure_control_visible(stats_panel)

func _box(background: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _section(key: String, color: Color = CYAN) -> Label:
	var label := _label(_t(key), color, 12)
	section_labels[key] = label
	return label

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("0b2018") if primary else TEXT)
	button.add_theme_color_override("font_focus_color", Color("0b2018") if primary else Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color("0b2018") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("0b2018") if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("586e7d"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var background := Color("a7eac2") if primary else Color("102638")
		var border := ACCENT if primary else Color("36586e")
		if state in ["hover", "focus"]:
			background = Color("c0f4d4") if primary else Color("183c50")
			border = ACCENT if primary else CYAN
		elif state == "pressed":
			background = Color("74c599") if primary else Color("0a1d2c")
		elif state == "disabled":
			background = Color("101e29")
			border = Color("203542")
		button.add_theme_stylebox_override(state, _box(background,border,8,10))
	button.pressed.connect(action)
	return button

func _select(action: Callable) -> OptionButton:
	var select := OptionButton.new()
	select.fit_to_longest_item = false
	select.clip_text = true
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LanguageSelectorStyle.configure(select)
	select.get_popup().borderless = true
	select.get_popup().max_size = Vector2i(680,360)
	select.item_selected.connect(action)
	return select

func _money(value: Variant) -> String:
	var digits := str(int(value))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length()-3)
	groups.push_front(digits)
	var separator := "." if LocalizationManager.current_locale in ["nl", "pt_BR"] else ","
	return separator.join(groups)

func _nature(value: Variant) -> String:
	var name := str(value)
	return ContentLocalization.nature_name(name.to_lower(), name)

func _localize() -> void:
	title_label.text = _t("title")
	explanation_label.text = _t("explanation")
	for key: String in section_labels:
		section_labels[key].text = _t(key)
	close_button.tooltip_text = LocalizationManager.text("common.close")
	preview_button.text = _t("preview")
	confirm_button.text = _t("confirm")
	quote_hint.text = _t("comparison_hint")

func _locale_changed(_locale: String) -> void:
	_localize()
	if not cached_state.is_empty():
		var previous_quote := quote.duplicate(true)
		var was_busy := busy
		_apply_state(cached_state)
		if not previous_quote.is_empty():
			_show_quote(previous_quote)
		_set_busy(was_busy)

func open_specialist() -> void:
	visible = true
	_localize()
	_fit()
	generation += 1
	quote.clear()
	await _load_state()

func close_specialist() -> void:
	if busy:
		return
	generation += 1
	confirmation.hide_dialog()
	visible = false
	closed.emit()

func _set_busy(value: bool) -> void:
	busy = value
	pokemon_select.disabled = value or not NatureSpecialistService.pending_request.is_empty()
	nature_select.disabled = value or not NatureSpecialistService.pending_request.is_empty()
	close_button.disabled = value
	preview_button.disabled = value or cooldown or entries.is_empty() or not NatureSpecialistService.pending_request.is_empty()
	confirm_button.disabled = value or (quote.is_empty() and NatureSpecialistService.pending_request.is_empty())
	confirm_button.text = _t("retry") if not NatureSpecialistService.pending_request.is_empty() else _t("confirm")

func _load_state() -> void:
	_set_busy(true)
	status_label.text = _t("loading")
	var current := generation
	var response: Dictionary = await NatureSpecialistService.state()
	if current != generation:
		return
	if not bool(response.get("success", false)):
		status_label.text = str(response.get("error", ""))
		_set_busy(false)
		return
	_apply_state(response.get("body", {}))

func _apply_state(data: Dictionary) -> void:
	var selected_id := 0
	if pokemon_select.selected >= 0 and pokemon_select.selected < entries.size():
		selected_id = int(entries[pokemon_select.selected].get("pokemon",{}).get("ownedPokemonId",0))
	var selected_nature := str(nature_select.get_item_metadata(nature_select.selected)) if nature_select.selected >= 0 else ""
	if not NatureSpecialistService.pending_request.is_empty():
		selected_id = int(NatureSpecialistService.pending_display.get("pokemonId",selected_id))
		selected_nature = str(NatureSpecialistService.pending_display.get("newNature",selected_nature))
	cached_state = data.duplicate(true)
	entries = data.get("pokemon", [])
	pokemon_select.clear()
	for entry: Dictionary in entries:
		var p: Dictionary = entry.get("pokemon", {})
		var location: Dictionary = entry.get("location", {})
		var position_text := "PC %s/%s" % [int(location.get("boxIndex",0))+1,int(location.get("slotIndex",0))+1] if str(location.get("type","")) == "box" else "Party %s" % (int(location.get("partySlot",0))+1)
		var display_name := str(p.get("nickname")) if p.get("nickname") is String and not str(p.get("nickname")).is_empty() else str(p.get("species","Pokemon"))
		pokemon_select.add_item("%s #%s · Lv.%s%s · %s · %s ₽" % [display_name,int(p.get("ownedPokemonId",0)),int(p.get("level",1))," ★" if bool(p.get("shiny",false)) else "",position_text,_money(entry.get("price",0))])
		if int(p.get("ownedPokemonId",0)) == selected_id:
			pokemon_select.select(pokemon_select.item_count-1)
	if entries.is_empty():
		pokemon_select.add_item(_t("no_pokemon"))
	nature_select.clear()
	for nature: Dictionary in data.get("natures", []):
		var name := str(nature.get("name", "Hardy"))
		var boosted := str(nature.get("boosted_stat")).to_upper() if nature.get("boosted_stat") != null else "—"
		var lowered := str(nature.get("lowered_stat")).to_upper() if nature.get("lowered_stat") != null else "—"
		var effect := "(+10%% %s / −10%% %s)" % [boosted, lowered] if nature.get("boosted_stat") != null else _t("neutral")
		nature_select.add_item("%s %s" % [ContentLocalization.nature_name(name.to_lower(),name), effect])
		nature_select.set_item_metadata(nature_select.item_count-1, name)
		if name == selected_nature:
			nature_select.select(nature_select.item_count-1)
	var next_at := str(data.get("nextAvailableAt", "")) if data.get("nextAvailableAt") != null else ""
	cooldown = not next_at.is_empty() and next_at > str(data.get("serverTime", ""))
	wallet_label.text = _t("wallet_label") + ": " + _money(data.get("money",0)) + " ₽"
	status_label.text = _t("ready")
	if cooldown:
		status_label.text = _t("cooldown", {"time":next_at.replace("T", " ").replace("+00:00"," UTC")})
	_selection_changed(0)
	if not NatureSpecialistService.pending_request.is_empty():
		_show_quote(NatureSpecialistService.pending_display)
		status_label.text = _t("pending")
	_set_busy(false)
	_fit.call_deferred()

func _selection_changed(_index: int) -> void:
	quote.clear()
	quote_hint.text = _t("comparison_hint")
	if not entries.is_empty():
		var entry: Dictionary = entries[pokemon_select.selected]
		var p: Dictionary = entry.get("pokemon", {})
		pokemon_name.text = str(p.get("nickname")) if p.get("nickname") is String and not str(p.get("nickname")).is_empty() else str(p.get("species", "Pokemon"))
		pokemon_name.text += " ★" if bool(p.get("shiny",false)) else ""
		pokemon_info.text = "Lv.%d · #%d" % [int(p.get("level",1)),int(p.get("ownedPokemonId",0))]
		pokemon_image.texture = PokemonAssets.load_home_sprite(str(p.get("speciesId",p.get("species",""))),bool(p.get("shiny",false)))
		nature_info.text = _t("current", {"original":_nature(p.get("nature","Hardy")),"effective":_nature(p.get("effectiveNature",p.get("nature","Hardy")))})
		price_label.text = _money(entry.get("price",0)) + " ₽"
		for stat: String in STATS:
			var iv := int(p.get("ivs",{}).get(stat,0))
			iv_values[stat].text = "%s  %d" % [stat.to_upper(),iv]
			iv_values[stat].add_theme_color_override("font_color",ACCENT if iv == 31 else MUTED)
		_render_stats(p.get("stats",{}),{})
	else:
		pokemon_name.text = _t("no_pokemon")
		pokemon_info.text = ""
		nature_info.text = ""
		pokemon_image.texture = null
		price_label.text = "—"
		for stat: String in STATS:
			iv_values[stat].text = stat.to_upper() + " —"
		_render_stats({},{})
	_set_busy(busy)

func _preview() -> void:
	if busy or entries.is_empty():
		return
	_set_busy(true)
	var p: Dictionary = entries[pokemon_select.selected].get("pokemon", {})
	var pokemon_id := int(p.get("ownedPokemonId",p.get("pokemonId",0)))
	var response: Dictionary = await NatureSpecialistService.preview(pokemon_id, str(nature_select.get_item_metadata(nature_select.selected)))
	if bool(response.get("success",false)):
		_show_quote(response.get("body", {}))
	else:
		status_label.text = str(response.get("error",""))
	_set_busy(false)

func _render_stats(before: Dictionary, after: Dictionary) -> void:
	for stat: String in STATS:
		var cells: Array = stat_values[stat]
		cells[0].text = str(int(before[stat])) if before.has(stat) else "—"
		cells[1].text = str(int(after[stat])) if after.has(stat) else "—"
		var comparable := before.has(stat) and after.has(stat)
		var difference := int(after.get(stat,0))-int(before.get(stat,0)) if comparable else 0
		var color := ACCENT if difference > 0 else (RED if difference < 0 else MUTED)
		cells[1].add_theme_color_override("font_color", color if after.has(stat) else MUTED)
		cells[2].text = ("+" if difference > 0 else "") + str(difference) if comparable else "—"
		cells[2].add_theme_color_override("font_color",color)

func _show_quote(data: Dictionary) -> void:
	quote = data
	_render_stats(quote.get("oldStats",{}),quote.get("newStats",{}))
	price_label.text = _money(quote.get("price",0)) + " ₽"
	quote_hint.text = _nature(quote.get("oldNature","")) + " → " + _nature(quote.get("newNature",""))
	status_label.text = _t("review")
	_reveal_comparison.call_deferred()

func _ask_confirm() -> void:
	if busy:
		return
	if not NatureSpecialistService.pending_request.is_empty():
		await _confirm()
	elif not quote.is_empty():
		confirmation.configure(_t("title"), _t("confirmation", {"nature":_nature(quote.get("newNature","")), "price":_money(quote.get("price",0))}), _t("confirm"), LocalizationManager.text("common.cancel"))
		confirmation.popup_centered(Vector2i(600,280))

func _confirm() -> void:
	if busy:
		return
	_set_busy(true)
	var response: Dictionary = await NatureSpecialistService.confirm(str(quote.get("previewId","")), quote)
	if bool(response.get("success",false)):
		quote.clear()
		await _load_state()
		status_label.text = _t("success") + "\n" + status_label.text
	else:
		status_label.text = str(response.get("error",""))
	_set_busy(false)
