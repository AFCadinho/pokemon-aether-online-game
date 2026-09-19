extends Window

signal finished

const SERVICE := preload("res://scripts/services/rental_service.gd")
const CONFIRM := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const TEAM_CATALOG := preload("res://scripts/ui/rental_team_catalog.gd")
const ITEM_ICON_RESOLVER := preload("res://scripts/services/item_icon_resolver.gd")
var service: Node
var kind := "team"
var catalog: Dictionary = {}
var offers: Array = []
var selected: Dictionary = {}
var listing: ItemList
var description: RichTextLabel
var duration: OptionButton
var status: Label
var balance: Label
var rent_button: Button
var active_list: VBoxContainer
var search: LineEdit
var team_catalog: RentalTeamCatalog
var busy := false
var detail_generation := 0
var pokemon_source: TabContainer
var pokemon_paste: TextEdit
var pokemon_fields: Dictionary = {}
var pokemon_evs: Dictionary = {}
var pokemon_ivs: Dictionary = {}
var pokemon_gender: OptionButton
var pokemon_happiness: SpinBox
var quote_button: Button
var selected_build: Dictionary = {}
var pokemon_edit_step: VBoxContainer
var pokemon_review_step: VBoxContainer
var pokemon_preview_icon: TextureRect
var pokemon_preview_species: Label
var pokemon_preview_details: RichTextLabel
var pokemon_preview_item_icon: TextureRect
var pokemon_preview_item_name: Label
var pokemon_review_icon: TextureRect
var pokemon_review_species: Label
var pokemon_review_rarity: Label
var pokemon_review_rental_price: Label
var pokemon_review_buyout_price: Label
var pokemon_review_terms: Label
var pokemon_review_item_icon: TextureRect
var pokemon_review_item_name: Label

func _ready() -> void:
	hide()
	title = "Aether Rentals"
	borderless = true
	size = Vector2i(940, 670)
	min_size = Vector2i(800, 600)
	close_requested.connect(_close)
	service = SERVICE.new()
	add_child(service)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081522")
	style.border_color = Color("62d7ff")
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var heading := Label.new()
	heading.text = "AETHER RENTALS  /  " + ("TEAMS" if kind == "team" else "POKÉMON")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("62d7ff"))
	header.add_child(heading)
	balance = Label.new()
	balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance.add_theme_color_override("font_color", Color("#f5df9a"))
	header.add_child(balance)
	var header_close := Button.new()
	header_close.text = "×"
	header_close.tooltip_text = "Close"
	header_close.custom_minimum_size = Vector2(38, 34)
	header_close.add_theme_font_size_override("font_size", 21)
	header_close.pressed.connect(_close)
	_style_button(header_close, false)
	header.add_child(header_close)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(tabs, false)
	root.add_child(tabs)
	var browse := HBoxContainer.new()
	browse.name = "Catalog"
	browse.add_theme_constant_override("separation", 16)
	tabs.add_child(browse)
	if kind == "team":
		team_catalog = TEAM_CATALOG.new()
		team_catalog.offer_selected.connect(_select_team_offer)
		browse.add_child(team_catalog)
		duration = OptionButton.new()
		duration.custom_minimum_size = Vector2(205, 36)
		team_catalog.add_rental_control(duration)
		rent_button = Button.new()
		rent_button.text = "Rent complete team"
		rent_button.custom_minimum_size = Vector2(210, 36)
		rent_button.disabled = true
		rent_button.pressed.connect(_rent)
		team_catalog.add_rental_control(rent_button)
	else:
		_build_individual_catalog(browse)
	var scroll := ScrollContainer.new()
	scroll.name = "My rentals"
	tabs.add_child(scroll)
	active_list = VBoxContainer.new()
	active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_list.add_theme_constant_override("separation", 12)
	scroll.add_child(active_list)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)

func _build_individual_catalog(browse: HBoxContainer) -> void:
	var builder := VBoxContainer.new()
	builder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builder.add_theme_constant_override("separation", 8)
	browse.add_child(builder)
	pokemon_edit_step = VBoxContainer.new()
	pokemon_edit_step.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_edit_step.add_theme_constant_override("separation", 8)
	builder.add_child(pokemon_edit_step)
	var intro := Label.new()
	intro.text = "Create your level-100 Pokémon"
	intro.add_theme_font_size_override("font_size", 18)
	intro.add_theme_color_override("font_color", Color("#eef6ff"))
	pokemon_edit_step.add_child(intro)
	var intro_hint := Label.new()
	intro_hint.text = "Paste one competitive set, or switch to Manual to fill in the fields yourself."
	intro_hint.add_theme_color_override("font_color", Color("#8ea8bd"))
	pokemon_edit_step.add_child(intro_hint)
	var edit_split := HBoxContainer.new()
	edit_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_split.add_theme_constant_override("separation", 12)
	pokemon_edit_step.add_child(edit_split)
	var input_column := VBoxContainer.new()
	input_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_column.size_flags_stretch_ratio = 1.7
	input_column.add_theme_constant_override("separation", 8)
	edit_split.add_child(input_column)
	pokemon_source = TabContainer.new()
	pokemon_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_source.tab_changed.connect(func(_tab: int): _invalidate_pokemon_quote())
	_style_tabs(pokemon_source, true)
	input_column.add_child(pokemon_source)
	var paste_panel := VBoxContainer.new()
	paste_panel.name = "Paste a set"
	pokemon_source.add_child(paste_panel)
	var paste_hint := Label.new()
	paste_hint.text = "Paste your Showdown / PokéPaste set below. Its held item is included during the rental."
	paste_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paste_hint.add_theme_color_override("font_color", Color("#8ea8bd"))
	paste_panel.add_child(paste_hint)
	pokemon_paste = TextEdit.new()
	pokemon_paste.placeholder_text = "Paste here…\n\nExample:\nDragonite\nAbility: Multiscale\nEVs: 252 Atk / 4 SpD / 252 Spe\nAdamant Nature\n- Dragon Dance\n- Extreme Speed"
	pokemon_paste.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_paste.text_changed.connect(_invalidate_pokemon_quote)
	_style_text_edit(pokemon_paste)
	paste_panel.add_child(pokemon_paste)
	var manual_scroll := ScrollContainer.new()
	manual_scroll.name = "Build manually"
	pokemon_source.add_child(manual_scroll)
	var manual := VBoxContainer.new()
	manual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manual_scroll.add_child(manual)
	_add_pokemon_text_field(manual, "species", "Pokémon", "e.g. Garchomp", true)
	_add_pokemon_text_field(manual, "nickname", "Nickname", "Optional")
	_add_pokemon_text_field(manual, "ability", "Ability", "e.g. Rough Skin")
	_add_pokemon_text_field(manual, "item", "Held item", "Optional, e.g. Leftovers")
	_add_pokemon_text_field(manual, "nature", "Nature", "e.g. Jolly", false, "Hardy")
	_add_pokemon_text_field(manual, "tera_type", "Tera type", "Optional, e.g. Steel")
	var gender_label := Label.new()
	gender_label.text = "Gender"
	manual.add_child(gender_label)
	pokemon_gender = OptionButton.new()
	for gender_option: String in ["Unspecified", "Male", "Female", "Genderless"]:
		pokemon_gender.add_item(gender_option)
	pokemon_gender.item_selected.connect(func(_index: int): _invalidate_pokemon_quote())
	_style_option(pokemon_gender)
	manual.add_child(pokemon_gender)
	var happiness_label := Label.new()
	happiness_label.text = "Happiness"
	manual.add_child(happiness_label)
	pokemon_happiness = SpinBox.new()
	pokemon_happiness.min_value = 0
	pokemon_happiness.max_value = 255
	pokemon_happiness.value = 255
	pokemon_happiness.value_changed.connect(func(_value: float): _invalidate_pokemon_quote())
	_style_spinbox(pokemon_happiness)
	manual.add_child(pokemon_happiness)
	_add_pokemon_text_field(manual, "moves", "Moves", "Comma-separated, up to four")
	_add_stat_fields(manual, "EVs", pokemon_evs, 0, 252)
	_add_stat_fields(manual, "IVs", pokemon_ivs, 31, 31)
	var quote_actions := HBoxContainer.new()
	quote_actions.alignment = BoxContainer.ALIGNMENT_END
	input_column.add_child(quote_actions)
	quote_button = Button.new()
	quote_button.text = "Review Pokémon & price  →"
	quote_button.custom_minimum_size = Vector2(260, 40)
	quote_button.pressed.connect(_quote_pokemon)
	_style_button(quote_button, true)
	quote_actions.add_child(quote_button)
	edit_split.add_child(_create_pokemon_preview())
	pokemon_review_step = VBoxContainer.new()
	pokemon_review_step.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_review_step.add_theme_constant_override("separation", 10)
	builder.add_child(pokemon_review_step)
	var review_header := HBoxContainer.new()
	review_header.add_theme_constant_override("separation", 8)
	pokemon_review_step.add_child(review_header)
	var review_heading := Label.new()
	review_heading.text = "Review your Pokémon"
	review_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_heading.add_theme_font_size_override("font_size", 18)
	review_heading.add_theme_color_override("font_color", Color("#eef6ff"))
	review_header.add_child(review_heading)
	var edit_button := Button.new()
	edit_button.text = "← Edit set"
	edit_button.pressed.connect(func(): _show_pokemon_review(false))
	_style_button(edit_button, false)
	review_header.add_child(edit_button)
	var review_content := HBoxContainer.new()
	review_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_content.add_theme_constant_override("separation", 12)
	pokemon_review_step.add_child(review_content)
	var identity_card := PanelContainer.new()
	identity_card.custom_minimum_size.x = 230
	identity_card.add_theme_stylebox_override("panel", _control_style(Color("#0a1726"), Color("#41698d")))
	review_content.add_child(identity_card)
	var identity := VBoxContainer.new()
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 8)
	identity_card.add_child(identity)
	var validated := Label.new()
	validated.text = "VALIDATED RENTAL"
	validated.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	validated.add_theme_font_size_override("font_size", 11)
	validated.add_theme_color_override("font_color", Color("#8ea8bd"))
	identity.add_child(validated)
	var review_sprite_center := CenterContainer.new()
	review_sprite_center.custom_minimum_size.y = 140
	identity.add_child(review_sprite_center)
	pokemon_review_icon = TextureRect.new()
	pokemon_review_icon.custom_minimum_size = Vector2(132, 132)
	pokemon_review_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_review_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	review_sprite_center.add_child(pokemon_review_icon)
	pokemon_review_species = Label.new()
	pokemon_review_species.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_review_species.add_theme_font_size_override("font_size", 22)
	pokemon_review_species.add_theme_color_override("font_color", Color("#62d5ff"))
	identity.add_child(pokemon_review_species)
	var rarity_center := CenterContainer.new()
	rarity_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(rarity_center)
	var rarity_badge := PanelContainer.new()
	rarity_badge.name = "RarityBadge"
	var rarity_style := _control_style(Color("#211d12"), Color("#8c793b"))
	rarity_style.content_margin_left = 12
	rarity_style.content_margin_right = 12
	rarity_style.content_margin_top = 3
	rarity_style.content_margin_bottom = 3
	rarity_badge.add_theme_stylebox_override("panel", rarity_style)
	rarity_center.add_child(rarity_badge)
	pokemon_review_rarity = Label.new()
	pokemon_review_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_review_rarity.add_theme_font_size_override("font_size", 11)
	pokemon_review_rarity.add_theme_color_override("font_color", Color("#f5df9a"))
	rarity_badge.add_child(pokemon_review_rarity)
	var fixed_rules := Label.new()
	fixed_rules.text = "LV. 100"
	fixed_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fixed_rules.add_theme_font_size_override("font_size", 11)
	fixed_rules.add_theme_color_override("font_color", Color("#8ea8bd"))
	identity.add_child(fixed_rules)
	var review_item := _create_preview_item_row(identity)
	pokemon_review_item_icon = review_item["icon"]
	pokemon_review_item_name = review_item["label"]
	var details_column := VBoxContainer.new()
	details_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_column.add_theme_constant_override("separation", 10)
	review_content.add_child(details_column)
	description = RichTextLabel.new()
	description.bbcode_enabled = true
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.fit_content = true
	description.scroll_active = false
	description.text = "Your validated set will appear here."
	description.add_theme_color_override("default_color", Color("#eef6ff"))
	description.add_theme_stylebox_override("normal", _control_style(Color("#0a1422"), Color("#315070")))
	details_column.add_child(description)
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 10)
	details_column.add_child(price_row)
	pokemon_review_rental_price = _review_price_card(price_row, "24-HOUR RENTAL", Color("#62d5ff"))
	pokemon_review_buyout_price = _review_price_card(price_row, "KEEP PERMANENTLY LATER", Color("#f5df9a"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	pokemon_review_step.add_child(actions)
	pokemon_review_terms = Label.new()
	pokemon_review_terms.text = "24 hours real time • Rental item is temporary • Timer runs offline"
	pokemon_review_terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_review_terms.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_review_terms.add_theme_color_override("font_color", Color("#8ea8bd"))
	actions.add_child(pokemon_review_terms)
	duration = OptionButton.new()
	duration.disabled = true
	duration.visible = false
	duration.tooltip_text = "3  Choose how long you want to rent this Pokémon"
	_style_option(duration)
	actions.add_child(duration)
	rent_button = Button.new()
	rent_button.text = "Rent quoted Pokémon"
	rent_button.custom_minimum_size.x = 210
	rent_button.disabled = true
	rent_button.pressed.connect(_rent)
	_style_button(rent_button, true)
	actions.add_child(rent_button)
	_show_pokemon_review(false)
	_update_pokemon_preview()
	_refresh_builder_actions()

func _review_price_card(parent: HBoxContainer, heading_text: String, accent: Color) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _control_style(Color("#101829"), accent.darkened(0.35)))
	parent.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", accent)
	content.add_child(heading)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", Color("#eef6ff"))
	content.add_child(value)
	return value

func _create_pokemon_preview() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 310
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.add_theme_stylebox_override("panel", _control_style(Color("#0a1321"), Color("#41698d")))
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var eyebrow := Label.new()
	eyebrow.text = "LIVE BUILD PREVIEW"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", Color("#8ea8bd"))
	layout.add_child(eyebrow)
	var hero := HBoxContainer.new()
	hero.custom_minimum_size.y = 104
	hero.add_theme_constant_override("separation", 10)
	layout.add_child(hero)
	var sprite_center := CenterContainer.new()
	sprite_center.custom_minimum_size.x = 106
	hero.add_child(sprite_center)
	pokemon_preview_icon = TextureRect.new()
	pokemon_preview_icon.custom_minimum_size = Vector2(100, 100)
	pokemon_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_center.add_child(pokemon_preview_icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 5)
	hero.add_child(identity)
	pokemon_preview_species = Label.new()
	pokemon_preview_species.text = "Your Pokémon"
	pokemon_preview_species.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pokemon_preview_species.add_theme_font_size_override("font_size", 19)
	pokemon_preview_species.add_theme_color_override("font_color", Color("#62d5ff"))
	identity.add_child(pokemon_preview_species)
	var fixed_meta := Label.new()
	fixed_meta.text = "LEVEL 100"
	fixed_meta.add_theme_font_size_override("font_size", 10)
	fixed_meta.add_theme_color_override("font_color", Color("#f5df9a"))
	identity.add_child(fixed_meta)
	var preview_item := _create_preview_item_row(identity)
	pokemon_preview_item_icon = preview_item["icon"]
	pokemon_preview_item_name = preview_item["label"]
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 6)
	layout.add_child(divider)
	pokemon_preview_details = RichTextLabel.new()
	pokemon_preview_details.name = "PokemonBuilderPreviewDetails"
	pokemon_preview_details.bbcode_enabled = true
	pokemon_preview_details.fit_content = true
	pokemon_preview_details.scroll_active = false
	pokemon_preview_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_preview_details.add_theme_font_size_override("normal_font_size", 11)
	pokemon_preview_details.add_theme_constant_override("line_separation", 2)
	pokemon_preview_details.add_theme_color_override("default_color", Color("#eef6ff"))
	layout.add_child(pokemon_preview_details)
	return card

func _create_preview_item_row(parent: VBoxContainer) -> Dictionary:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var chip := PanelContainer.new()
	chip.name = "HeldItemChip"
	chip.custom_minimum_size = Vector2(190, 36)
	var chip_style := _control_style(Color("#0d1b2a"), Color("#315070"))
	chip_style.content_margin_left = 9
	chip_style.content_margin_right = 9
	chip_style.content_margin_top = 3
	chip_style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", chip_style)
	center.add_child(chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var label := Label.new()
	label.text = "No held item"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#f5df9a"))
	row.add_child(label)
	return {"icon": icon, "label": label}

func _style_option(control: OptionButton) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, Color("#eef6ff"))
	control.add_theme_color_override("font_disabled_color", Color("#596d80"))
	control.add_theme_stylebox_override("normal", _control_style(Color("#101829"), Color("#41698d")))
	control.add_theme_stylebox_override("hover", _control_style(Color("#172b49"), Color("#62d5ff")))
	control.add_theme_stylebox_override("pressed", _control_style(Color("#0a1321"), Color("#62d5ff")))
	control.add_theme_stylebox_override("focus", _control_style(Color("#101829"), Color("#62d5ff")))
	control.add_theme_stylebox_override("disabled", _control_style(Color("#0b111d"), Color("#293b50")))
	var popup := control.get_popup()
	popup.transparent_bg = true
	popup.add_theme_color_override("font_color", Color("#eef6ff"))
	popup.add_theme_color_override("font_hover_color", Color("#eef6ff"))
	popup.add_theme_color_override("font_disabled_color", Color("#596d80"))
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	var popup_panel := _control_style(Color("#0a1422"), Color("#41698d"))
	popup_panel.shadow_color = Color(0, 0, 0, 0.55)
	popup_panel.shadow_size = 14
	popup_panel.shadow_offset = Vector2(0, 5)
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", _control_style(Color("#193753"), Color("#62d5ff")))

func _style_tabs(control: TabContainer, compact: bool) -> void:
	control.get_tab_bar().mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_constant_override("side_margin", 0)
	control.add_theme_constant_override("tab_separation", 4)
	control.add_theme_color_override("font_selected_color", Color("#eef6ff"))
	control.add_theme_color_override("font_unselected_color", Color("#8ea8bd"))
	control.add_theme_color_override("font_hovered_color", Color("#eef6ff"))
	var selected_style := _control_style(Color("#17324a"), Color("#62d5ff"))
	selected_style.border_width_left = 0
	selected_style.border_width_top = 0
	selected_style.border_width_right = 0
	selected_style.border_width_bottom = 2
	var vertical_padding := 5 if compact else 7
	selected_style.content_margin_top = vertical_padding
	selected_style.content_margin_bottom = vertical_padding
	var normal_style := _control_style(Color("#0b1421"), Color("#263e54"))
	normal_style.content_margin_top = vertical_padding
	normal_style.content_margin_bottom = vertical_padding
	control.add_theme_stylebox_override("tab_selected", selected_style)
	control.add_theme_stylebox_override("tab_unselected", normal_style)
	control.add_theme_stylebox_override("tab_hovered", _control_style(Color("#142b42"), Color("#4e89ad")))
	control.add_theme_stylebox_override("tab_focus", _control_style(Color("#17324a"), Color("#62d5ff")))
	control.add_theme_stylebox_override("panel", _control_style(Color("#081321"), Color("#263e54")))

func _style_line_edit(control: LineEdit) -> void:
	control.add_theme_color_override("font_color", Color("#eef6ff"))
	control.add_theme_color_override("font_placeholder_color", Color("#657d91"))
	control.add_theme_color_override("caret_color", Color("#62d5ff"))
	control.add_theme_stylebox_override("normal", _control_style(Color("#091524"), Color("#315070")))
	control.add_theme_stylebox_override("focus", _control_style(Color("#0c1d2e"), Color("#62d5ff")))
	control.add_theme_stylebox_override("read_only", _control_style(Color("#0b111d"), Color("#293b50")))

func _style_text_edit(control: TextEdit) -> void:
	control.add_theme_color_override("font_color", Color("#eef6ff"))
	control.add_theme_color_override("font_placeholder_color", Color("#657d91"))
	control.add_theme_color_override("caret_color", Color("#62d5ff"))
	control.add_theme_color_override("selection_color", Color("#245776"))
	control.add_theme_stylebox_override("normal", _control_style(Color("#091524"), Color("#315070")))
	control.add_theme_stylebox_override("focus", _control_style(Color("#0c1d2e"), Color("#62d5ff")))

func _style_spinbox(control: SpinBox) -> void:
	_style_line_edit(control.get_line_edit())

func _style_button(control: Button, primary: bool) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, Color("#eef6ff"))
	control.add_theme_color_override("font_disabled_color", Color("#596d80"))
	var normal_bg := Color("#5d4aa4") if primary else Color("#13243a")
	var hover_bg := Color("#725dbe") if primary else Color("#1a3550")
	var border := Color("#d4c9ff") if primary else Color("#41698d")
	control.add_theme_stylebox_override("normal", _control_style(normal_bg, border))
	control.add_theme_stylebox_override("hover", _control_style(hover_bg, Color("#62d5ff")))
	control.add_theme_stylebox_override("pressed", _control_style(normal_bg.darkened(0.18), Color("#62d5ff")))
	control.add_theme_stylebox_override("focus", _control_style(normal_bg, Color("#62d5ff")))
	control.add_theme_stylebox_override("disabled", _control_style(Color("#0b111d"), Color("#293b50")))

func _control_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _add_pokemon_text_field(parent: VBoxContainer, key: String, label_text: String, placeholder: String, required := false, initial := "") -> void:
	var label := Label.new()
	label.text = label_text + (" *" if required else "")
	parent.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = initial
	field.text_changed.connect(func(_value: String): _invalidate_pokemon_quote())
	_style_line_edit(field)
	parent.add_child(field)
	pokemon_fields[key] = field

func _add_stat_fields(parent: VBoxContainer, heading_text: String, target: Dictionary, default_value: int, max_value: int) -> void:
	var heading := Label.new()
	heading.text = heading_text
	parent.add_child(heading)
	var row := HBoxContainer.new()
	parent.add_child(row)
	for stat: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var label := Label.new()
		label.text = stat.to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var value := SpinBox.new()
		value.min_value = 0
		value.max_value = max_value
		value.value = default_value
		value.value_changed.connect(func(_number: float): _invalidate_pokemon_quote())
		_style_spinbox(value)
		column.add_child(value)
		target[stat] = value

func _invalidate_pokemon_quote() -> void:
	if kind != "pokemon":
		return
	selected = {}
	selected_build = {}
	if duration != null:
		duration.clear()
		duration.disabled = true
	if rent_button != null:
		rent_button.disabled = true
		rent_button.text = "Rent quoted Pokémon"
	if status != null:
		status.text = ""
	_show_pokemon_review(false)
	_update_pokemon_preview()
	_refresh_builder_actions()

func _update_pokemon_preview() -> void:
	if pokemon_preview_species == null or pokemon_preview_details == null:
		return
	var preview := _paste_preview_data() if pokemon_source != null and pokemon_source.current_tab == 0 else _manual_preview_data()
	var species := str(preview.get("species", "")).strip_edges()
	if species.is_empty():
		pokemon_preview_species.text = "Your Pokémon"
		pokemon_preview_icon.texture = PokemonAssets.load_unknown_icon() if pokemon_preview_icon != null else null
		_set_preview_item(pokemon_preview_item_icon, pokemon_preview_item_name, "")
		pokemon_preview_details.text = "[color=#8ea8bd]Your PokéPaste-formatted set will appear here while you build.[/color]"
		return
	pokemon_preview_species.text = species
	if pokemon_preview_icon != null:
		pokemon_preview_icon.texture = PokemonAssets.load_party_icon(species)
	_set_preview_item(pokemon_preview_item_icon, pokemon_preview_item_name, str(preview.get("item", "")))
	pokemon_preview_details.text = _pokepaste_text(preview, false)

func _item_display_name(item_id: String) -> String:
	var value := item_id.strip_edges()
	if value.is_empty():
		return "No held item"
	var fallback := value if value != value.to_lower() else value.replace("-", " ").capitalize()
	var localizer := get_node_or_null("/root/ItemLocalization")
	return str(localizer.call("display_name", value, fallback)) if localizer != null else fallback

func _set_preview_item(icon: TextureRect, label: Label, item_id: String) -> void:
	var value := item_id.strip_edges()
	icon.texture = ITEM_ICON_RESOLVER.load_icon(value) if not value.is_empty() else null
	icon.visible = not value.is_empty()
	label.text = _item_display_name(value)

func _pokepaste_text(data: Dictionary, include_species: bool) -> String:
	var lines: Array[String] = []
	var species := str(data.get("species", "Pokémon")).strip_edges()
	var item := str(data.get("item", "")).strip_edges()
	if include_species:
		lines.append("[color=#62d5ff]%s[/color]%s" % [species, " @ " + _item_display_name(item) if not item.is_empty() else ""])
	var ability := str(data.get("ability", "")).strip_edges()
	if not ability.is_empty(): lines.append("[color=#8ea8bd]Ability:[/color] %s" % ability)
	var tera := str(data.get("tera", data.get("teraType", ""))).strip_edges()
	if not tera.is_empty(): lines.append("[color=#8ea8bd]Tera Type:[/color] %s" % tera)
	var evs := str(data.get("evs", "")).strip_edges()
	if not evs.is_empty() and evs != "No EV investment": lines.append("[color=#8ea8bd]EVs:[/color] %s" % evs)
	var ivs := str(data.get("ivs", "")).strip_edges()
	if not ivs.is_empty() and ivs not in ["All 31", "All stats 31"]: lines.append("[color=#8ea8bd]IVs:[/color] %s" % ivs)
	var nature := str(data.get("nature", "")).strip_edges()
	if not nature.is_empty(): lines.append("%s Nature" % nature)
	var moves: Array = data.get("moves", []) if data.get("moves", []) is Array else []
	for move: Variant in moves:
		lines.append("[color=#c9beff]-[/color] %s" % str(move))
	return "\n".join(lines)

func _paste_preview_data() -> Dictionary:
	var result := {"species": "", "item": "", "ability": "", "tera": "", "evs": "", "ivs": "", "nature": "", "moves": []}
	if pokemon_paste == null:
		return result
	for raw_line: String in pokemon_paste.text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		if str(result["species"]).is_empty() and not line.begins_with("-") and ":" not in line and not line.ends_with(" Nature"):
			var heading_parts := line.split("@", false, 1)
			var heading := heading_parts[0].strip_edges()
			if heading_parts.size() > 1:
				result["item"] = heading_parts[1].strip_edges()
			if heading.ends_with(" (M)") or heading.ends_with(" (F)"):
				heading = heading.substr(0, heading.length() - 4).strip_edges()
			var open := heading.rfind("(")
			if open >= 0 and heading.ends_with(")"):
				heading = heading.substr(open + 1, heading.length() - open - 2).strip_edges()
			result["species"] = heading
		elif line.begins_with("Ability:"):
			result["ability"] = line.trim_prefix("Ability:").strip_edges()
		elif line.begins_with("Tera Type:"):
			result["tera"] = line.trim_prefix("Tera Type:").strip_edges()
		elif line.begins_with("EVs:"):
			result["evs"] = line.trim_prefix("EVs:").strip_edges()
		elif line.begins_with("IVs:"):
			result["ivs"] = line.trim_prefix("IVs:").strip_edges()
		elif line.ends_with(" Nature"):
			result["nature"] = line.trim_suffix(" Nature").strip_edges()
		elif line.begins_with("-"):
			(result["moves"] as Array).append(line.trim_prefix("-").strip_edges())
	return result

func _manual_preview_data() -> Dictionary:
	var result := {"species": "", "item": "", "ability": "", "tera": "", "evs": "", "ivs": "", "nature": "", "moves": []}
	if pokemon_fields.is_empty():
		return result
	result["species"] = (pokemon_fields["species"] as LineEdit).text.strip_edges()
	result["ability"] = (pokemon_fields["ability"] as LineEdit).text.strip_edges()
	result["item"] = (pokemon_fields["item"] as LineEdit).text.strip_edges()
	result["tera"] = (pokemon_fields["tera_type"] as LineEdit).text.strip_edges()
	result["nature"] = (pokemon_fields["nature"] as LineEdit).text.strip_edges()
	result["evs"] = _preview_stat_spread(pokemon_evs, 0, false)
	result["ivs"] = _preview_stat_spread(pokemon_ivs, 31, true)
	for raw_move: String in (pokemon_fields["moves"] as LineEdit).text.split(","):
		var move := raw_move.strip_edges()
		if not move.is_empty():
			(result["moves"] as Array).append(move)
	return result

func _preview_stat_spread(inputs: Dictionary, default_value: int, show_default_summary: bool) -> String:
	var parts: Array[String] = []
	for pair: Array in [["hp", "HP"], ["atk", "Atk"], ["def", "Def"], ["spa", "SpA"], ["spd", "SpD"], ["spe", "Spe"]]:
		var stat := str(pair[0])
		if not inputs.has(stat):
			continue
		var value := int((inputs[stat] as SpinBox).value)
		if value != default_value:
			parts.append("%d %s" % [value, str(pair[1])])
	if parts.is_empty() and show_default_summary:
		return "All 31"
	return " / ".join(parts)

func _format_quote_stat_spread(values: Dictionary, default_value: int, all_default_label: String) -> String:
	var parts: Array[String] = []
	for pair: Array in [["hp", "HP"], ["atk", "Atk"], ["def", "Def"], ["spa", "SpA"], ["spd", "SpD"], ["spe", "Spe"]]:
		var value := int(values.get(str(pair[0]), default_value))
		if value != default_value:
			parts.append("%d %s" % [value, str(pair[1])])
	return all_default_label if parts.is_empty() else " / ".join(parts)

func _show_pokemon_review(show_review: bool) -> void:
	if pokemon_edit_step != null:
		pokemon_edit_step.visible = not show_review
	if pokemon_review_step != null:
		pokemon_review_step.visible = show_review

func _pokemon_input_ready() -> bool:
	if pokemon_source == null:
		return false
	if pokemon_source.current_tab == 0:
		return pokemon_paste != null and not pokemon_paste.text.strip_edges().is_empty()
	return pokemon_fields.has("species") and not (pokemon_fields["species"] as LineEdit).text.strip_edges().is_empty()

func _refresh_builder_actions() -> void:
	if quote_button != null:
		quote_button.disabled = busy or not _pokemon_input_ready()

func _pokemon_build() -> Dictionary:
	if pokemon_source.current_tab == 0:
		return {"source": "paste", "pasteText": pokemon_paste.text.strip_edges()}
	var moves: Array[String] = []
	for raw_move: String in str((pokemon_fields["moves"] as LineEdit).text).split(","):
		var move := raw_move.strip_edges()
		if not move.is_empty():
			moves.append(move)
	var evs := {}
	var ivs := {}
	for stat: String in pokemon_evs:
		evs[stat] = int((pokemon_evs[stat] as SpinBox).value)
		ivs[stat] = int((pokemon_ivs[stat] as SpinBox).value)
	var gender_values: Array[String] = ["", "M", "F", "N"]
	return {"source": "manual", "pokemon": {
		"species": (pokemon_fields["species"] as LineEdit).text.strip_edges(),
		"nickname": (pokemon_fields["nickname"] as LineEdit).text.strip_edges(),
		"ability": (pokemon_fields["ability"] as LineEdit).text.strip_edges(),
		"item": (pokemon_fields["item"] as LineEdit).text.strip_edges(),
		"nature": (pokemon_fields["nature"] as LineEdit).text.strip_edges(),
		"happiness": int(pokemon_happiness.value), "gender": gender_values[pokemon_gender.selected],
		"teraType": (pokemon_fields["tera_type"] as LineEdit).text.strip_edges(), "moves": moves, "evs": evs, "ivs": ivs,
	}}

func _quote_pokemon() -> void:
	if busy:
		return
	if not _pokemon_input_ready():
		status.text = "Paste a Pokémon set or enter a Pokémon species first."
		return
	var build := _pokemon_build()
	busy = true
	quote_button.disabled = true
	status.text = "Validating set and calculating its rarity…"
	var result: Dictionary = await service.request("/pokemon/quote", {"pokemonBuild": build}, false, true)
	busy = false
	_refresh_builder_actions()
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", "This set is not valid."))
		return
	selected = result["body"]
	selected_build = build
	duration.clear()
	for price: Dictionary in selected.get("prices", []):
		duration.add_item("%s — %d Aetherite" % [_duration_label(int(price["durationSeconds"])), int(price["amount"])])
		duration.set_item_metadata(duration.item_count - 1, price)
	duration.disabled = false
	var pokemon: Dictionary = selected.get("pokemon", [{}])[0]
	var moves: Array[String] = []
	for move: Variant in pokemon.get("moves", []):
		moves.append(str(move.get("name", move.get("id", ""))) if move is Dictionary else str(move))
	var species := str(pokemon.get("species", pokemon.get("speciesId", "Pokémon")))
	var rarity := str(selected.get("rarity", "common")).replace("_", " ").capitalize()
	pokemon_review_icon.texture = PokemonAssets.load_party_icon(species)
	pokemon_review_species.text = species
	pokemon_review_rarity.text = rarity.to_upper()
	var item := str(pokemon.get("item", pokemon.get("heldItemId", "")))
	_set_preview_item(pokemon_review_item_icon, pokemon_review_item_name, item)
	var ev_text := _format_quote_stat_spread(pokemon.get("evs", {}), 0, "No EV investment")
	var iv_text := _format_quote_stat_spread(pokemon.get("ivs", {}), 31, "All stats 31")
	description.text = _pokepaste_text({
		"species": species, "item": item, "ability": pokemon.get("ability", ""),
		"teraType": pokemon.get("teraType", ""), "evs": ev_text, "ivs": iv_text,
		"nature": pokemon.get("nature", "Hardy"), "moves": moves,
	}, true)
	var rental_price := int((selected.get("prices", [{}])[0] as Dictionary).get("amount", 0))
	var buyout_total := int(selected.get("buyoutTotal", 0))
	pokemon_review_rental_price.text = "%d Aetherite" % rental_price
	pokemon_review_buyout_price.text = "%d Aetherite after rental\n%d total" % [maxi(0, buyout_total - rental_price), buyout_total]
	rent_button.text = "Rent for 24 hours — %d Aetherite" % rental_price
	var limit_reached := _rental_limit_reached()
	rent_button.disabled = limit_reached
	if limit_reached:
		rent_button.text = "Pokémon rental limit reached"
	_show_pokemon_review(true)
	status.text = "Quote ready. Changing the set will require a new quote."

func open_vendor() -> void:
	popup_centered(size)
	await refresh()

func refresh() -> void:
	busy = true
	status.text = "Loading rentals…"
	var result: Dictionary = await service.request("/catalog/" + kind)
	busy = false
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", "Unavailable"))
		return
	catalog = result["body"]
	balance.text = "%d Aetherite" % int(catalog.get("aetherite", 0))
	duration.clear()
	for price: Dictionary in catalog.get("prices", []):
		duration.add_item("%s — %d Aetherite" % [_duration_label(int(price["durationSeconds"])), int(price["amount"])])
		duration.set_item_metadata(duration.item_count - 1, price)
	if kind == "team":
		team_catalog.set_offers(catalog.get("offers", []))
	else:
		_invalidate_pokemon_quote()
	_render_active()
	status.text = ""

func _filter() -> void:
	if listing == null:
		return
	listing.clear()
	offers.clear()
	selected = {}
	detail_generation += 1
	rent_button.disabled = true
	for offer: Dictionary in catalog.get("offers", []):
		if not search.text.is_empty() and search.text.to_lower() not in JSON.stringify(offer).to_lower():
			continue
		offers.append(offer)
		listing.add_item(str(offer.get("displayName", "")) + (" · " + str(offer.get("homeTierId", "Open")) if kind == "team" else ""))

func _select(index: int) -> void:
	if busy:
		return
	detail_generation += 1
	var generation := detail_generation
	selected = {}
	rent_button.disabled = true
	description.text = "Loading set…"
	var offer: Dictionary = offers[index]
	var result: Dictionary = await service.request("/catalog/%s/%s" % [kind, str(offer["offerId"]).uri_encode()])
	if generation != detail_generation:
		return
	if not bool(result.get("success", false)):
		description.text = str(result.get("error", "Unavailable"))
		return
	selected = result["body"]
	var text := str(selected.get("displayName", "")) + "\n\n"
	for pokemon: Dictionary in selected.get("pokemon", []):
		var held_item := str(pokemon.get("item", ""))
		text += "%s • Lv.100\n%s / %s / %s\n" % [str(pokemon.get("species", pokemon.get("speciesId", ""))), str(pokemon.get("nature", "")), str(pokemon.get("ability", "")), "No item" if held_item.is_empty() else held_item]
		text += "Moves: %s\nEVs: %s\nIVs: %s\n\n" % [", ".join(pokemon.get("moves", [])), JSON.stringify(pokemon.get("evs", {})), JSON.stringify(pokemon.get("ivs", {}))]
	text += "Full rental team: fixed sets and items; no permanent purchase. Use all six together in Aether Clash." if kind == "team" else "Permanent purchase: %d Aetherite total, minus the initial rental fee. Extensions do not reduce this price. NPC OT stays; no caught credit." % int(selected.get("buyoutTotal", 0))
	description.text = text
	rent_button.disabled = false

func _select_team_offer(offer: Dictionary) -> void:
	if busy:
		return
	detail_generation += 1
	var generation := detail_generation
	selected = {}
	rent_button.disabled = true
	team_catalog.show_loading(offer)
	var result: Dictionary = await service.request("/catalog/team/%s" % str(offer["offerId"]).uri_encode())
	if generation != detail_generation:
		return
	if not bool(result.get("success", false)):
		team_catalog.clear_selection()
		status.text = str(result.get("error", "Unavailable"))
		return
	selected = result["body"]
	team_catalog.show_detail(selected)
	var limit_reached := _rental_limit_reached()
	rent_button.disabled = limit_reached
	rent_button.text = "Team rental limit reached" if limit_reached else "Rent complete team"

func _rent() -> void:
	if busy or selected.is_empty():
		return
	var price: Dictionary = duration.get_selected_metadata()
	var payload := _build_rent_payload(price)
	await _mutate("", payload, "Rent %s for %d Aetherite?\nThe timer includes offline time. No refund for early return." % [selected["displayName"], int(price["amount"])])

func _build_rent_payload(price: Dictionary) -> Dictionary:
	# Godot decodes JSON numbers as floats. The rentals API deliberately uses a
	# strict integer contract for durations, so normalize catalog metadata before
	# serializing it back into a mutation request.
	var payload := {
		"kind": kind,
		"offerId": str(selected.get("offerId", "")),
		"durationSeconds": int(price.get("durationSeconds", 0)),
	}
	if kind == "pokemon":
		payload["pokemonBuild"] = selected_build
	return payload

func _rental_limit_reached() -> bool:
	var context := "npc_" + kind
	var count := 0
	for loan: Dictionary in catalog.get("rentals", []):
		if str(loan.get("context", "")) == context and str(loan.get("status", "")) in ["active", "return_pending"]:
			count += 1
	return count >= int(catalog.get("maxTeams", 1) if kind == "team" else catalog.get("maxPokemon", 6))

func _duration_label(seconds: int) -> String:
	if seconds % 86400 == 0:
		var days := seconds / 86400
		return "%d day%s" % [days, "" if days == 1 else "s"]
	var hours := seconds / 3600
	return "%d hour%s" % [hours, "" if hours == 1 else "s"]

func _render_active() -> void:
	for child: Node in active_list.get_children():
		child.queue_free()
	var count := 0
	for loan: Dictionary in catalog.get("rentals", []):
		if str(loan.get("context", "")) != "npc_" + kind or str(loan.get("status", "")) not in ["active", "return_pending"]:
			continue
		count += 1
		if kind == "team":
			_render_active_team(loan)
			continue
		var data: Dictionary = loan.get("rental", {})
		var label := Label.new()
		label.text = "%s\nExpires: %s UTC • %s" % [data.get("displayName", "Rental"), str(loan.get("dueAt", "")).replace("T", " ").left(19), loan.get("status", "")]
		active_list.add_child(label)
		var actions := HBoxContainer.new()
		active_list.add_child(actions)
		if loan.get("status") == "active":
			var extend_button := Button.new()
			extend_button.text = "Extend 24 hours — 100 Aetherite"
			extend_button.pressed.connect(func(): await _mutate("/%s/extend" % loan["loanId"], {}, "Extend this rental by 24 hours for 100 Aetherite?\nThe extra time starts at the current expiry time."))
			actions.add_child(extend_button)
		var return_button := Button.new()
		return_button.text = "Return rental"
		return_button.pressed.connect(func(): await _mutate("/%s/return" % loan["loanId"], {}, "Return this rental now? No Aetherite will be refunded."))
		actions.add_child(return_button)
		if kind == "pokemon" and loan.get("status") == "active":
			var buy := Button.new()
			buy.text = "Keep permanently — %d Aetherite" % int(data.get("buyoutPrice", 0))
			buy.pressed.connect(func(): await _mutate("/%s/buyout" % loan["loanId"], {}, "Pay %d Aetherite to keep this Pokémon?\nOT stays Aether Rental Service. This does not count as caught." % int(data.get("buyoutPrice", 0))))
			actions.add_child(buy)
	if count == 0:
		var empty := Label.new()
		empty.text = "No active rentals from this vendor."
		active_list.add_child(empty)

func _render_active_team(loan: Dictionary) -> void:
	var data: Dictionary = loan.get("rental", {})
	var panel := PanelContainer.new()
	panel.name = "ActiveTeamRentalCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := _control_style(Color("#0b1726"), Color("#41698d"))
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	active_list.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 3)
	header.add_child(identity)
	var title := Label.new()
	title.text = str(data.get("displayName", "Rental team"))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#62d5ff"))
	identity.add_child(title)
	var meta := Label.new()
	meta.text = "FULL LEVEL-100 TEAM  •  6 POKÉMON  •  TIMER RUNS OFFLINE"
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color("#8ea8bd"))
	identity.add_child(meta)
	var timing := VBoxContainer.new()
	timing.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(timing)
	var state := Label.new()
	state.text = str(loan.get("status", "active")).replace("_", " ").to_upper()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color", Color("#a9f0cb"))
	state.add_theme_stylebox_override("normal", _control_style(Color("#102c26"), Color("#3c8b70")))
	timing.add_child(state)
	var expiry := Label.new()
	expiry.text = "Expires %s UTC" % str(loan.get("dueAt", "")).replace("T", " ").left(19)
	expiry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	expiry.add_theme_font_size_override("font_size", 11)
	expiry.add_theme_color_override("font_color", Color("#eef6ff"))
	timing.add_child(expiry)
	var grid := GridContainer.new()
	grid.name = "ActiveTeamSets"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)
	for asset_value: Variant in loan.get("assets", []):
		if not asset_value is Dictionary:
			continue
		var asset := asset_value as Dictionary
		if str(asset.get("assetType", "")) != "pokemon":
			continue
		var snapshot: Variant = asset.get("snapshot", {})
		if snapshot is Dictionary:
			grid.add_child(team_catalog.create_set_card(snapshot as Dictionary, true))
	if grid.get_child_count() == 0:
		var unavailable := Label.new()
		unavailable.text = "Team set details are unavailable. Refresh the rental screen."
		unavailable.add_theme_color_override("font_color", Color("#8ea8bd"))
		grid.add_child(unavailable)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	var terms := Label.new()
	terms.text = "Extensions add 24 hours from the current expiry time."
	terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terms.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terms.add_theme_font_size_override("font_size", 11)
	terms.add_theme_color_override("font_color", Color("#8ea8bd"))
	footer.add_child(terms)
	if loan.get("status") == "active":
		var extend_button := Button.new()
		extend_button.text = "Extend 24 hours — 100 Aetherite"
		extend_button.custom_minimum_size = Vector2(245, 38)
		extend_button.pressed.connect(func(): await _mutate("/%s/extend" % loan["loanId"], {}, "Extend this rental by 24 hours for 100 Aetherite?\nThe extra time starts at the current expiry time."))
		_style_button(extend_button, true)
		footer.add_child(extend_button)
	var return_button := Button.new()
	return_button.text = "Return team"
	return_button.custom_minimum_size = Vector2(135, 38)
	return_button.pressed.connect(func(): await _mutate("/%s/return" % loan["loanId"], {}, "Return this rental now? No Aetherite will be refunded."))
	_style_button(return_button, false)
	footer.add_child(return_button)

func _mutate(path: String, payload: Dictionary, message: String) -> void:
	if busy:
		return
	busy = true
	var confirm := CONFIRM.instantiate() as AetherConfirmationDialog
	add_child(confirm)
	confirm.configure("Aether Rentals", message, "Confirm", "Cancel")
	var choice := {"yes": false, "done": false}
	confirm.confirmed.connect(func(): choice["yes"] = true; choice["done"] = true)
	confirm.canceled.connect(func(): choice["done"] = true)
	confirm.popup_centered(Vector2i(620, 340))
	while not bool(choice["done"]):
		await get_tree().process_frame
	confirm.queue_free()
	if not bool(choice["yes"]):
		busy = false
		return
	status.text = "Processing…"
	var result: Dictionary = await service.request(path, payload, true)
	busy = false
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", "Request failed."))
		return
	for entry: Array in [["PlayerPartyStateService", "refresh_party"], ["InventoryService", "load_inventory"], ["PlayerWalletService", "load_wallet"]]:
		var target := get_node_or_null("/root/" + str(entry[0]))
		if target != null and target.has_method(str(entry[1])):
			var updated: Dictionary = await target.call(str(entry[1]))
			if str(entry[0]) == "PlayerWalletService" and target.has_method("apply_wallet_result"):
				target.call("apply_wallet_result", updated)
	await refresh()
	status.text = "Done. Your Pokémon, wallet and rentals are up to date."

func _close() -> void:
	if busy:
		return
	hide()
	finished.emit()
