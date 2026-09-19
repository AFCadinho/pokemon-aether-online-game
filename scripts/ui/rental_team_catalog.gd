extends VBoxContainer

class_name RentalTeamCatalog

signal offer_selected(offer: Dictionary)

const TEXT := Color("#eef6ff")
const MUTED := Color("#8ea8bd")
const CYAN := Color("#62d5ff")
const GOLD := Color("#f5df9a")
const PURPLE := Color("#c9beff")
const FILTER_TIER_IDS: Array[String] = ["aether-ou", "aether-uu"]

var offers: Array[Dictionary] = []
var selected_offer_id := ""
var search: LineEdit
var archetype_filter: OptionButton
var tier_filter: OptionButton
var result_status: Label
var results: VBoxContainer
var detail_title: Label
var detail_meta: Label
var detail_hint: Label
var team_grid: GridContainer
var action_bar: HBoxContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var intro := Label.new()
	intro.text = "Browse complete level-100 rental teams. Select a team to inspect every set before renting it."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", MUTED)
	add_child(intro)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	search = LineEdit.new()
	search.name = "TeamCatalogSearch"
	search.placeholder_text = "Search team or Pokémon…"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(280, 34)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String): _refresh_results())
	_style_line_edit(search)
	filters.add_child(search)
	archetype_filter = OptionButton.new()
	archetype_filter.name = "TeamCatalogArchetype"
	archetype_filter.custom_minimum_size = Vector2(175, 34)
	archetype_filter.fit_to_longest_item = false
	archetype_filter.item_selected.connect(func(_index: int): _refresh_results())
	_style_option(archetype_filter)
	filters.add_child(archetype_filter)
	tier_filter = OptionButton.new()
	tier_filter.name = "TeamCatalogTier"
	tier_filter.custom_minimum_size = Vector2(145, 34)
	tier_filter.fit_to_longest_item = false
	tier_filter.item_selected.connect(func(_index: int): _refresh_results())
	_style_option(tier_filter)
	filters.add_child(tier_filter)
	result_status = Label.new()
	result_status.add_theme_font_size_override("font_size", 11)
	result_status.add_theme_color_override("font_color", MUTED)
	add_child(result_status)
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 285
	add_child(split)
	var result_scroll := ScrollContainer.new()
	result_scroll.custom_minimum_size = Vector2(270, 0)
	result_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(result_scroll)
	results = VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 7)
	result_scroll.add_child(results)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(510, 0)
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0d1726eb"), Color("#6f5fbaaa"), 10, 1))
	split.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	_set_margins(detail_margin, 12)
	detail_panel.add_child(detail_margin)
	var detail_layout := VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_layout)
	detail_title = Label.new()
	detail_title.text = "Select a rental team"
	detail_title.add_theme_font_size_override("font_size", 18)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title.add_theme_color_override("font_color", TEXT)
	detail_layout.add_child(detail_title)
	detail_meta = Label.new()
	detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_meta.add_theme_color_override("font_color", MUTED)
	detail_layout.add_child(detail_meta)
	detail_hint = Label.new()
	detail_hint.text = "Choose a team to load all six fixed sets."
	detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_hint.add_theme_color_override("font_color", MUTED)
	detail_layout.add_child(detail_hint)
	var sets_scroll := ScrollContainer.new()
	sets_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_layout.add_child(sets_scroll)
	team_grid = GridContainer.new()
	team_grid.columns = 3
	team_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_grid.add_theme_constant_override("h_separation", 7)
	team_grid.add_theme_constant_override("v_separation", 7)
	sets_scroll.add_child(team_grid)
	action_bar = HBoxContainer.new()
	action_bar.name = "RentalActions"
	action_bar.add_theme_constant_override("separation", 8)
	detail_layout.add_child(action_bar)


func add_rental_control(control: Control) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is OptionButton:
		_style_option(control as OptionButton)
	elif control is Button:
		_style_rent_button(control as Button)
	action_bar.add_child(control)


func set_offers(value: Array) -> void:
	offers.clear()
	for entry: Variant in value:
		if entry is Dictionary:
			offers.append((entry as Dictionary).duplicate(true))
	_rebuild_filters()
	_refresh_results()


func show_loading(offer: Dictionary) -> void:
	selected_offer_id = str(offer.get("offerId", offer.get("teamId", "")))
	detail_title.text = str(offer.get("displayName", selected_offer_id))
	detail_meta.text = _offer_meta(offer)
	detail_hint.text = "Loading all six sets…"
	detail_hint.visible = true
	_clear(team_grid)
	_refresh_results()


func show_detail(detail: Dictionary) -> void:
	detail_title.text = str(detail.get("displayName", selected_offer_id))
	detail_meta.text = _offer_meta(detail)
	_clear(team_grid)
	var pokemon := _array(detail.get("pokemon", []))
	detail_hint.text = "This team has no available set data." if pokemon.is_empty() else ""
	detail_hint.visible = pokemon.is_empty()
	for value: Variant in pokemon:
		if value is Dictionary:
			team_grid.add_child(_set_card(value as Dictionary))


func clear_selection() -> void:
	selected_offer_id = ""
	detail_title.text = "Select a rental team"
	detail_meta.text = ""
	detail_hint.text = "Choose a team to load all six fixed sets."
	detail_hint.visible = true
	_clear(team_grid)
	_refresh_results()


func _rebuild_filters() -> void:
	var archetypes: Array[String] = []
	var tiers: Array[String] = []
	for offer: Dictionary in offers:
		var archetype := str(offer.get("archetype", "balance"))
		if archetype not in archetypes:
			archetypes.append(archetype)
		for tier_value: Variant in _array(offer.get("eligibleTierIds", [])):
			var tier := str(tier_value)
			if tier in FILTER_TIER_IDS and tier not in tiers:
				tiers.append(tier)
	archetypes.sort()
	tiers.sort()
	archetype_filter.clear()
	_add_option(archetype_filter, "All archetypes", "all")
	for archetype: String in archetypes:
		_add_option(archetype_filter, _archetype_label(archetype), archetype)
	tier_filter.clear()
	_add_option(tier_filter, "All tiers", "all")
	for tier: String in tiers:
		_add_option(tier_filter, _tier_label(tier), tier)


func _refresh_results() -> void:
	if results == null:
		return
	_clear(results)
	var query := search.text.strip_edges().to_lower()
	var archetype := str(archetype_filter.get_selected_metadata()) if archetype_filter.item_count > 0 else "all"
	var tier := str(tier_filter.get_selected_metadata()) if tier_filter.item_count > 0 else "all"
	var count := 0
	for offer: Dictionary in offers:
		if archetype != "all" and str(offer.get("archetype", "balance")) != archetype:
			continue
		if tier != "all" and tier not in _array(offer.get("eligibleTierIds", [])):
			continue
		if not query.is_empty() and query not in _search_text(offer):
			continue
		results.add_child(_team_card(offer))
		count += 1
	result_status.text = "%d rental team%s" % [count, "" if count == 1 else "s"]


func _team_card(offer: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var offer_id := str(offer.get("offerId", offer.get("teamId", "")))
	var selected := offer_id == selected_offer_id
	var normal := _panel_style(Color("#101829e8"), Color("#35597a99"), 10, 1)
	var hovered := _panel_style(Color("#172b49f2"), Color("#62d5ffcc"), 10, 2)
	var chosen := _panel_style(Color("#182741f2"), Color("#f5df9acc"), 10, 2)
	var chosen_hovered := _panel_style(Color("#24385ae8"), Color("#ffe699"), 10, 2)
	panel.custom_minimum_size = Vector2(0, 84)
	panel.tooltip_text = str(offer.get("displayName", offer_id))
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("normal", normal)
	panel.set_meta("hover", hovered)
	panel.set_meta("selected", chosen)
	panel.set_meta("selected_hover", chosen_hovered)
	panel.set_meta("is_selected", selected)
	panel.add_theme_stylebox_override("panel", chosen if selected else normal)
	panel.gui_input.connect(_team_input.bind(offer))
	panel.mouse_entered.connect(_team_hover.bind(panel, true))
	panel.mouse_exited.connect(_team_hover.bind(panel, false))
	var margin := MarginContainer.new()
	_set_margins(margin, 8)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	layout.add_child(header)
	var title := Label.new()
	title.text = str(offer.get("displayName", offer_id))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEXT)
	header.add_child(title)
	header.add_child(_badge(_archetype_label(str(offer.get("archetype", "balance"))), false))
	var display_tier := _display_tier(offer)
	if not display_tier.is_empty():
		header.add_child(_badge(_tier_label(display_tier), true))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 5)
	layout.add_child(icons)
	for value: Variant in _array(offer.get("pokemon", [])):
		if value is Dictionary:
			icons.add_child(_pokemon_icon(value as Dictionary))
	_mouse_ignore(margin)
	return panel


func _set_card(set_data: Dictionary) -> Control:
	var species := str(set_data.get("species", set_data.get("speciesId", "")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color("#0a1321e8"), Color("#315070cc"), 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 8)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 5)
	layout.add_child(heading)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = PokemonAssets.load_party_icon(species, bool(set_data.get("shiny", false)))
	heading.add_child(icon)
	var title := Label.new()
	var gender := str(set_data.get("gender", "")).strip_edges()
	title.text = "%s%s" % [_content_name("species", species), " (%s)" % gender if gender in ["M", "F"] else ""]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", CYAN)
	heading.add_child(title)
	var lines: Array[String] = []
	var item := str(set_data.get("item", "")).strip_edges()
	if not item.is_empty():
		lines.append("[color=#f5df9a]@ %s[/color]" % item)
	var ability := str(set_data.get("ability", "")).strip_edges()
	if not ability.is_empty():
		lines.append("Ability: %s" % _content_name("abilities", ability))
	var tera := str(set_data.get("teraType", "")).strip_edges()
	if not tera.is_empty():
		lines.append("Tera Type: %s" % tera)
	var evs := _stat_spread(set_data.get("evs", {}), 0)
	if not evs.is_empty():
		lines.append("EVs: %s" % evs)
	var nature := str(set_data.get("nature", "")).strip_edges()
	if not nature.is_empty():
		lines.append("%s Nature" % _content_name("natures", nature))
	var ivs := _stat_spread(set_data.get("ivs", {}), 31)
	if not ivs.is_empty():
		lines.append("IVs: %s" % ivs)
	for move: Variant in _array(set_data.get("moves", [])):
		lines.append("[color=#c9beff]– %s[/color]" % _content_name("moves", str(move)))
	var details := RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_font_size_override("normal_font_size", 10)
	details.text = "\n".join(lines)
	layout.add_child(details)
	return card


func _pokemon_icon(entry: Dictionary) -> Control:
	var species := str(entry.get("species", entry.get("speciesId", "")))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(34, 30)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = _content_name("species", species)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#081321ee"), Color("#41698d"), 7, 1))
	var center := CenterContainer.new()
	panel.add_child(center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = PokemonAssets.load_party_icon(species, bool(entry.get("shiny", false)))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	return panel


func _team_input(event: InputEvent, offer: Dictionary) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
		offer_selected.emit(offer)


func _team_hover(panel: PanelContainer, hovered: bool) -> void:
	var selected := bool(panel.get_meta("is_selected", false))
	var key := "selected_hover" if selected and hovered else "selected" if selected else "hover" if hovered else "normal"
	panel.add_theme_stylebox_override("panel", panel.get_meta(key) as StyleBox)


func _offer_meta(offer: Dictionary) -> String:
	var parts: Array[String] = [_archetype_label(str(offer.get("archetype", "balance")))]
	for value: Variant in _array(offer.get("eligibleTierIds", [])):
		parts.append(_tier_label(str(value)))
	return " · ".join(parts)


func _search_text(offer: Dictionary) -> String:
	var parts: Array[String] = [str(offer.get("offerId", "")), str(offer.get("displayName", "")), str(offer.get("archetype", ""))]
	for value: Variant in _array(offer.get("pokemon", [])):
		if value is Dictionary:
			var species := str((value as Dictionary).get("species", (value as Dictionary).get("speciesId", "")))
			parts.append(species)
			parts.append(_content_name("species", species))
	return " ".join(parts).to_lower()


func _stat_spread(value: Variant, omitted_default: int) -> String:
	if not value is Dictionary:
		return ""
	var spread := value as Dictionary
	var parts: Array[String] = []
	for labels: Array in [["hp", "HP"], ["atk", "Atk"], ["def", "Def"], ["spa", "SpA"], ["spd", "SpD"], ["spe", "Spe"]]:
		var key := str(labels[0])
		var upper := str(labels[1])
		var raw: Variant = spread.get(key, spread.get(upper, omitted_default))
		if int(raw) != omitted_default:
			parts.append("%d %s" % [int(raw), upper])
	return " / ".join(parts)


func _content_name(kind: String, identifier: String) -> String:
	var fallback := identifier.replace("-", " ").capitalize()
	var service := get_node_or_null("/root/ContentLocalizationService")
	return str(service.call("display_name", kind, identifier, fallback)) if service != null and service.has_method("display_name") else fallback


func _archetype_label(value: String) -> String:
	var key := "ui.pvp.training.ai.archetype.%s" % value
	var localization := get_node_or_null("/root/LocalizationManager")
	var translated := str(localization.call("text", key)) if localization != null and localization.has_method("text") else key
	return value.replace("_", " ").capitalize() if translated == key else translated


func _tier_label(value: String) -> String:
	if value == "none":
		return "Open"
	return value.replace("-", " ").to_upper()


func _display_tier(offer: Dictionary) -> String:
	var home := str(offer.get("homeTierId", ""))
	if not home.is_empty():
		return home
	for value: Variant in _array(offer.get("eligibleTierIds", [])):
		if str(value) != "none":
			return str(value)
	return ""


func _badge(label: String, gold: bool) -> Label:
	var badge := Label.new()
	badge.text = label
	badge.custom_minimum_size = Vector2(72, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", GOLD if gold else Color("#b8dbf4"))
	badge.add_theme_stylebox_override("normal", _panel_style(Color("#332d1b") if gold else Color("#172c45"), Color("#9f8750") if gold else Color("#4c789f"), 6, 1))
	return badge


func _style_line_edit(control: LineEdit) -> void:
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_placeholder_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.68))
	control.add_theme_stylebox_override("normal", _input_style(Color("#091524"), Color("#315070")))
	control.add_theme_stylebox_override("focus", _input_style(Color("#091524"), CYAN))


func _style_option(control: OptionButton) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_hover_color", TEXT)
	control.add_theme_color_override("font_pressed_color", TEXT)
	control.add_theme_color_override("font_focus_color", TEXT)
	control.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.48))
	control.add_theme_stylebox_override("normal", _input_style(Color("#101829"), Color("#41698d")))
	control.add_theme_stylebox_override("hover", _input_style(Color("#172b49"), CYAN))
	control.add_theme_stylebox_override("pressed", _input_style(Color("#0a1321"), CYAN))
	control.add_theme_stylebox_override("focus", _input_style(Color("#101829"), CYAN))
	control.add_theme_stylebox_override("disabled", _input_style(Color("#0b111d"), Color("#293b50")))
	var popup := control.get_popup()
	popup.transparent_bg = true
	popup.add_theme_color_override("font_color", TEXT)
	popup.add_theme_color_override("font_hover_color", TEXT)
	popup.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.48))
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	var popup_panel := _input_style(Color("#0a1422"), Color("#41698d"))
	popup_panel.shadow_color = Color(0, 0, 0, 0.55)
	popup_panel.shadow_size = 14
	popup_panel.shadow_offset = Vector2(0, 5)
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", _input_style(Color("#193753"), CYAN))


func _style_rent_button(control: Button) -> void:
	control.add_theme_color_override("font_color", Color.WHITE)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.45))
	control.add_theme_stylebox_override("normal", _input_style(Color("#5d4aa4"), Color("#d4c9ff")))
	control.add_theme_stylebox_override("hover", _input_style(Color("#725dbe"), Color("#f0ebff")))
	control.add_theme_stylebox_override("pressed", _input_style(Color("#493984"), PURPLE))
	control.add_theme_stylebox_override("disabled", _input_style(Color("#151827"), Color("#30384c")))


func _input_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 8, 1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _set_margins(control: MarginContainer, value: int) -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		control.add_theme_constant_override(side, value)


func _add_option(control: OptionButton, label: String, metadata: String) -> void:
	control.add_item(label)
	control.set_item_metadata(control.item_count - 1, metadata)


func _array(value: Variant) -> Array:
	return value if value is Array else []


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_mouse_ignore(child)
