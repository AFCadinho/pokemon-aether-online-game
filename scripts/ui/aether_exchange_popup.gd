class_name AetherExchangePopup
extends Panel

signal closed
signal wallet_changed
signal pokemon_summary_requested(pokemon_payload: Dictionary)

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
const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/photo_mode_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_unchecked.svg")
const EXCHANGE_SIZE := Vector2(1040, 660)
const MAX_PRICE := 2_147_483_647
const BROWSE_CARD_MIN_WIDTH := 128.0
const BROWSE_CARD_HEIGHT := 172.0
const BROWSE_GRID_MAX_COLUMNS := 4
const POKEMON_TYPES: Array[String] = [
	"normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison",
	"ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark",
	"steel", "fairy",
]
const POKEMON_NATURES: Array[String] = [
	"hardy", "lonely", "brave", "adamant", "naughty",
	"bold", "docile", "relaxed", "impish", "lax",
	"timid", "hasty", "serious", "jolly", "naive",
	"modest", "mild", "quiet", "bashful", "rash",
	"calm", "gentle", "sassy", "careful", "quirky",
]

var active_tab := "browse"
var asset_filter := "item"
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
var is_dragging_popup := false
var browse_filters: Dictionary = {
	"item": {
		"min_price": 0,
		"max_price": 0,
		"category": "",
		"sort_by": "newest",
		"sort_direction": "desc",
	},
	"pokemon": {
		"min_price": 0,
		"max_price": 0,
		"min_level": 1,
		"max_level": 100,
		"primary_type": "",
		"secondary_type": "",
		"nature": "",
		"ability": "",
		"shiny": -1,
		"hidden_ability": -1,
		"min_iv_hp": 0,
		"min_iv_atk": 0,
		"min_iv_def": 0,
		"min_iv_spa": 0,
		"min_iv_spd": 0,
		"min_iv_spe": 0,
		"sort_by": "newest",
		"sort_direction": "desc",
	},
}

var title_label: Label
var subtitle_label: Label
var money_label: Label
var tab_buttons: Dictionary = {}
var filter_buttons: Dictionary = {}
var search_input: LineEdit
var search_timer: Timer
var refresh_button: Button
var advanced_filter_button: Button
var browse_sort_button: OptionButton
var advanced_filter_overlay: ColorRect
var advanced_filter_panel: PanelContainer
var advanced_filter_title: Label
var advanced_filter_fields: Dictionary = {}
var advanced_filter_controls: Dictionary = {}
var advanced_filter_sections: Dictionary = {}
var advanced_filter_apply_button: Button
var advanced_filter_clear_button: Button
var advanced_filter_cancel_button: Button
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
	custom_minimum_size = EXCHANGE_SIZE
	size = EXCHANGE_SIZE
	clip_contents = true
	var window_style := _panel_style(UI_BG, Color("#5d9ebddd"), 14, 2)
	window_style.set_content_margin(SIDE_LEFT, 0.0)
	window_style.set_content_margin(SIDE_TOP, 0.0)
	window_style.set_content_margin(SIDE_RIGHT, 0.0)
	window_style.set_content_margin(SIDE_BOTTOM, 0.0)
	add_theme_stylebox_override("panel", window_style)
	_build_interface()
	_center_in_parent()
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.3
	search_timer.timeout.connect(_refresh_browse)
	add_child(search_timer)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null and not localization.locale_changed.is_connected(_on_locale_changed):
		localization.locale_changed.connect(_on_locale_changed)
	_translate_static_ui()


func _get_minimum_size() -> Vector2:
	# Container children may have different minimum sizes per tab. Returning the
	# window size here prevents those content changes from resizing the popup.
	return EXCHANGE_SIZE


func _input(event: InputEvent) -> void:
	if not visible or not is_dragging_popup:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		is_dragging_popup = false
		get_viewport().set_input_as_handled()
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null:
		position += mouse_motion.relative
		_clamp_to_parent()
		get_viewport().set_input_as_handled()


func open_exchange() -> void:
	visible = true
	size = EXCHANGE_SIZE
	_clamp_to_parent()
	_normalize_filter_for_tab()
	confirmation_action = Callable()
	if confirmation_overlay != null:
		confirmation_overlay.visible = false
	if advanced_filter_overlay != null:
		advanced_filter_overlay.visible = false
	if advanced_filter_panel != null:
		advanced_filter_panel.visible = false
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
	if advanced_filter_panel != null and advanced_filter_panel.visible:
		_hide_advanced_filter_panel()
		return
	is_dragging_popup = false
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_build_advanced_filter_panel()


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
	header.name = "ExchangeDragHandle"
	header.custom_minimum_size = Vector2(0, 58)
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_drag_handle_gui_input)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load("res://assets/ui/aether_exchange_icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", UI_MUTED)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(subtitle_label)
	var wallet_panel := PanelContainer.new()
	wallet_panel.custom_minimum_size = Vector2(165, 40)
	wallet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_panel.add_theme_stylebox_override("panel", _panel_style(UI_INTERACTIVE, Color("#806d34aa"), 9, 1))
	header.add_child(wallet_panel)
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 13)
	money_label.add_theme_color_override("font_color", UI_GOLD)
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for filter_id: String in ["item", "pokemon"]:
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
	_apply_line_edit_style(search_input)
	row.add_child(search_input)
	advanced_filter_button = Button.new()
	advanced_filter_button.name = "AdvancedFilterButton"
	advanced_filter_button.custom_minimum_size = Vector2(118, 34)
	advanced_filter_button.pressed.connect(_toggle_advanced_filter_panel)
	_apply_button_style(advanced_filter_button)
	row.add_child(advanced_filter_button)
	browse_sort_button = OptionButton.new()
	browse_sort_button.name = "BrowseSortButton"
	browse_sort_button.custom_minimum_size = Vector2(175, 34)
	for sort_mode: String in [
		"newest_desc", "newest_asc", "price_desc", "price_asc", "level_desc", "level_asc",
	]:
		browse_sort_button.add_item("")
		browse_sort_button.set_item_metadata(browse_sort_button.item_count - 1, sort_mode)
	browse_sort_button.item_selected.connect(_on_browse_sort_selected)
	_apply_filter_option_style(browse_sort_button)
	row.add_child(browse_sort_button)
	refresh_button = Button.new()
	refresh_button.custom_minimum_size = Vector2(105, 34)
	refresh_button.pressed.connect(_refresh_current_tab)
	refresh_button.name = "RefreshButton"
	_apply_button_style(refresh_button)
	row.add_child(refresh_button)
	return row


func _build_advanced_filter_panel() -> void:
	advanced_filter_overlay = ColorRect.new()
	advanced_filter_overlay.name = "ExchangeAdvancedFilterOverlay"
	advanced_filter_overlay.visible = false
	advanced_filter_overlay.color = Color("#01050bb8")
	advanced_filter_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	advanced_filter_overlay.z_index = 10
	add_child(advanced_filter_overlay)
	advanced_filter_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	advanced_filter_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	advanced_filter_panel = PanelContainer.new()
	advanced_filter_panel.name = "ExchangeAdvancedFilterPanel"
	advanced_filter_panel.visible = false
	advanced_filter_panel.custom_minimum_size = Vector2(790, 460)
	advanced_filter_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#071321fc"), Color("#58cfe2e6"), 11, 2)
	)
	center.add_child(advanced_filter_panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	advanced_filter_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	advanced_filter_title = Label.new()
	advanced_filter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advanced_filter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advanced_filter_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	advanced_filter_title.add_theme_font_size_override("font_size", 17)
	advanced_filter_title.add_theme_color_override("font_color", UI_CYAN)
	header.add_child(advanced_filter_title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(32, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_advanced_filter_panel)
	_apply_button_style(close_button)
	header.add_child(close_button)

	var market_grid := GridContainer.new()
	market_grid.columns = 2
	market_grid.add_theme_constant_override("h_separation", 18)
	market_grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(market_grid)

	_add_advanced_filter_field(market_grid, "min_price", _new_filter_spin(0, MAX_PRICE, 0), false)
	_add_advanced_filter_field(market_grid, "max_price", _new_filter_spin(0, MAX_PRICE, 0), false)
	_add_advanced_filter_field(market_grid, "category", _new_filter_line_edit(), false, true)
	_add_advanced_filter_field(market_grid, "min_level", _new_filter_spin(1, 100, 1), true)
	_add_advanced_filter_field(market_grid, "max_level", _new_filter_spin(1, 100, 100), true)
	_add_advanced_filter_field(market_grid, "primary_type", _new_filter_option(POKEMON_TYPES), true)
	_add_advanced_filter_field(market_grid, "secondary_type", _new_filter_option(POKEMON_TYPES), true)
	_add_advanced_filter_field(market_grid, "nature", _new_filter_option(POKEMON_NATURES), true)
	_add_advanced_filter_field(market_grid, "ability", _new_filter_line_edit(), true)
	_add_advanced_filter_field(market_grid, "shiny", _new_tristate_filter_option(), true)
	_add_advanced_filter_field(market_grid, "hidden_ability", _new_tristate_filter_option(), true)

	var iv_section := VBoxContainer.new()
	iv_section.add_theme_constant_override("separation", 5)
	stack.add_child(iv_section)
	advanced_filter_sections["ivs"] = iv_section
	var iv_title := Label.new()
	iv_title.name = "AdvancedFilterIvTitle"
	iv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv_title.add_theme_font_size_override("font_size", 12)
	iv_title.add_theme_color_override("font_color", UI_CYAN)
	iv_section.add_child(iv_title)
	var iv_grid := GridContainer.new()
	iv_grid.columns = 3
	iv_grid.add_theme_constant_override("h_separation", 14)
	iv_grid.add_theme_constant_override("v_separation", 6)
	iv_section.add_child(iv_grid)
	for stat_id: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		_add_advanced_filter_field(
			iv_grid, "min_iv_%s" % stat_id, _new_filter_spin(0, 31, 0), true, false, true
		)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)
	advanced_filter_clear_button = Button.new()
	advanced_filter_clear_button.custom_minimum_size = Vector2(120, 34)
	advanced_filter_clear_button.pressed.connect(_clear_advanced_filters)
	_apply_button_style(advanced_filter_clear_button)
	actions.add_child(advanced_filter_clear_button)
	advanced_filter_cancel_button = Button.new()
	advanced_filter_cancel_button.custom_minimum_size = Vector2(120, 34)
	advanced_filter_cancel_button.pressed.connect(_hide_advanced_filter_panel)
	_apply_button_style(advanced_filter_cancel_button)
	actions.add_child(advanced_filter_cancel_button)
	advanced_filter_apply_button = Button.new()
	advanced_filter_apply_button.custom_minimum_size = Vector2(140, 34)
	advanced_filter_apply_button.pressed.connect(_apply_advanced_filters)
	_apply_primary_button_style(advanced_filter_apply_button)
	actions.add_child(advanced_filter_apply_button)


func _add_advanced_filter_field(
	parent: Container,
	field_id: String,
	control: Control,
	pokemon_only: bool,
	item_only := false,
	compact := false
) -> void:
	var field := HBoxContainer.new()
	field.custom_minimum_size = Vector2(238 if compact else 368, 34)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.set_meta("pokemon_only", pokemon_only)
	field.set_meta("item_only", item_only)
	field.add_theme_constant_override("separation", 8)
	parent.add_child(field)
	var label := Label.new()
	label.custom_minimum_size = Vector2(54 if compact else 112, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI_MUTED)
	field.add_child(label)
	control.custom_minimum_size = Vector2(0, 32)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(control)
	advanced_filter_fields[field_id] = {"root": field, "label": label}
	advanced_filter_controls[field_id] = control


func _new_filter_spin(minimum: int, maximum: int, initial: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = initial
	spin.allow_greater = false
	spin.allow_lesser = false
	_apply_line_edit_style(spin.get_line_edit())
	return spin


func _new_filter_line_edit() -> LineEdit:
	var input := LineEdit.new()
	input.clear_button_enabled = true
	_apply_line_edit_style(input)
	return input


func _new_filter_option(values: Array[String], include_any := true) -> OptionButton:
	var option := OptionButton.new()
	if include_any:
		option.add_item(_t("ui.exchange.filters.any"))
		option.set_item_metadata(0, "")
	for value: String in values:
		option.add_item(_humanize_identifier(value))
		option.set_item_metadata(option.item_count - 1, value)
	_apply_filter_option_style(option)
	return option


func _new_tristate_filter_option() -> OptionButton:
	var option := OptionButton.new()
	for value: int in [-1, 1, 0]:
		option.add_item("")
		option.set_item_metadata(option.item_count - 1, value)
	_apply_filter_option_style(option)
	return option


func _apply_filter_option_style(option: OptionButton) -> void:
	_apply_button_style(option)
	option.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	option.add_theme_constant_override("arrow_margin", 10)
	var popup := option.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.max_size = Vector2i(420, 340)
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", UI_TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", Color(UI_MUTED, 0.5))
	popup.add_theme_color_override("font_separator_color", UI_CYAN)
	popup.add_theme_color_override("font_outline_color", Color("#02070b"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("icon_max_width", 14)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 5)
	popup.add_theme_stylebox_override("panel", _filter_dropdown_popup_style())
	popup.add_theme_stylebox_override(
		"hover", _filter_dropdown_item_style(Color("#12344cf7"), UI_CYAN)
	)
	popup.add_theme_stylebox_override(
		"separator", _filter_dropdown_item_style(Color.TRANSPARENT, Color("#31566b88"), 0)
	)
	popup.add_theme_icon_override("radio_checked", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", DROPDOWN_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", DROPDOWN_RADIO_UNCHECKED)


func _filter_dropdown_popup_style() -> StyleBoxFlat:
	var style := _filter_dropdown_item_style(Color("#050e18fc"), Color("#4e8caae6"), 9)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _filter_dropdown_item_style(
	background: Color,
	border: Color,
	radius := 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style


func _build_list_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ExchangeListPanel"
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
	panel.name = "ExchangeDetailPanel"
	panel.custom_minimum_size = Vector2(365, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 11, 1))
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 15)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "ExchangeDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	detail_stack = VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", 10)
	scroll.add_child(detail_stack)
	return panel


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	is_dragging_popup = mouse_button.pressed
	if is_dragging_popup:
		move_to_front()
	accept_event()


func _clamp_to_parent() -> void:
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	var available := parent_control.size
	var min_x := minf(0.0, available.x - size.x)
	var max_x := maxf(0.0, available.x - size.x)
	var max_y := maxf(0.0, available.y - size.y)
	# If the viewport is shorter than the popup, pin its header to the top so
	# the drag handle and close action always remain reachable.
	position = Vector2(
		clampf(position.x, min_x, max_x),
		clampf(position.y, 0.0, max_y),
	)


func _on_tab_pressed(tab: String) -> void:
	if request_busy or tab == active_tab:
		return
	active_tab = tab
	_normalize_filter_for_tab()
	if active_tab != "browse":
		_hide_advanced_filter_panel()
	selected_entry.clear()
	selected_kind = ""
	if active_tab == "browse":
		await _refresh_browse()
	else:
		_render_current_list()
	_refresh_controls()


func _on_filter_pressed(filter_id: String) -> void:
	if request_busy or filter_id == asset_filter or (active_tab == "sell" and filter_id.is_empty()):
		return
	asset_filter = filter_id
	if advanced_filter_panel != null and advanced_filter_panel.visible:
		_refresh_advanced_filter_panel()
		_sync_advanced_filter_controls()
	selected_entry.clear()
	selected_kind = ""
	if active_tab == "browse":
		await _refresh_browse()
	else:
		_render_current_list()
	_refresh_controls()


func _on_browse_sort_selected(index: int) -> void:
	if request_busy or active_tab != "browse" or browse_sort_button == null:
		return
	var sort_mode := str(browse_sort_button.get_item_metadata(index))
	if not _apply_browse_sort_mode(sort_mode):
		_refresh_browse_sort_button()
		return
	selected_entry.clear()
	selected_kind = ""
	await _refresh_browse()


func _apply_browse_sort_mode(sort_mode: String) -> bool:
	var sort_by := ""
	var sort_direction := ""
	match sort_mode:
		"newest_desc":
			sort_by = "newest"
			sort_direction = "desc"
		"newest_asc":
			sort_by = "newest"
			sort_direction = "asc"
		"price_desc":
			sort_by = "price"
			sort_direction = "desc"
		"price_asc":
			sort_by = "price"
			sort_direction = "asc"
		"level_desc", "level_asc":
			if asset_filter != "pokemon":
				return false
			sort_by = "level"
			sort_direction = "desc" if sort_mode.ends_with("_desc") else "asc"
		_:
			return false
	var state := _current_browse_filter_state().duplicate(true)
	state["sort_by"] = sort_by
	state["sort_direction"] = sort_direction
	browse_filters[asset_filter] = state
	return true


func _refresh_browse_sort_button() -> void:
	if browse_sort_button == null:
		return
	var state := _current_browse_filter_state()
	var selected_mode := "%s_%s" % [
		str(state.get("sort_by", "newest")),
		str(state.get("sort_direction", "desc")),
	]
	var selected_index := 0
	for index in range(browse_sort_button.item_count):
		var sort_mode := str(browse_sort_button.get_item_metadata(index))
		browse_sort_button.set_item_text(index, _t("ui.exchange.sort.%s" % sort_mode))
		browse_sort_button.set_item_disabled(index, asset_filter == "item" and sort_mode.begins_with("level_"))
		if sort_mode == selected_mode:
			selected_index = index
	browse_sort_button.select(selected_index)


func _on_search_changed(_value: String) -> void:
	if active_tab == "browse":
		search_timer.start()
	else:
		_render_current_list()


func _toggle_advanced_filter_panel() -> void:
	if request_busy or active_tab != "browse":
		return
	var show_panel := not advanced_filter_panel.visible
	advanced_filter_overlay.visible = show_panel
	advanced_filter_panel.visible = show_panel
	if show_panel:
		_refresh_advanced_filter_panel()
		_sync_advanced_filter_controls()
		advanced_filter_overlay.move_to_front()
	_refresh_controls()


func _hide_advanced_filter_panel() -> void:
	if advanced_filter_overlay != null:
		advanced_filter_overlay.visible = false
	if advanced_filter_panel != null:
		advanced_filter_panel.visible = false
	_refresh_controls()


func _refresh_advanced_filter_panel() -> void:
	if advanced_filter_panel == null:
		return
	var is_pokemon := asset_filter == "pokemon"
	advanced_filter_panel.custom_minimum_size = Vector2(790, 460) if is_pokemon else Vector2(700, 230)
	advanced_filter_title.text = _t(
		"ui.exchange.filters.title_pokemon" if is_pokemon else "ui.exchange.filters.title_item"
	)
	for field_id_value: Variant in advanced_filter_fields:
		var field_id := str(field_id_value)
		var field_data := _dictionary(advanced_filter_fields.get(field_id))
		var root := field_data.get("root") as Control
		if root != null:
			root.visible = (
				(not bool(root.get_meta("pokemon_only", false)) or is_pokemon)
				and (not bool(root.get_meta("item_only", false)) or not is_pokemon)
			)
		var label := field_data.get("label") as Label
		if label != null:
			label.text = _t("ui.exchange.filters.%s" % field_id)
	var category_input := advanced_filter_controls.get("category") as LineEdit
	if category_input != null:
		category_input.placeholder_text = _t("ui.exchange.filters.category_hint")
	var ability_input := advanced_filter_controls.get("ability") as LineEdit
	if ability_input != null:
		ability_input.placeholder_text = _t("ui.exchange.filters.ability_hint")
	var iv_section := advanced_filter_sections.get("ivs") as VBoxContainer
	if iv_section != null:
		iv_section.visible = is_pokemon
		var iv_title := iv_section.get_node_or_null("AdvancedFilterIvTitle") as Label
		if iv_title != null:
			iv_title.text = _t("ui.exchange.filters.iv_section")
	_refresh_filter_option_labels()
	advanced_filter_clear_button.text = _t("ui.exchange.filters.clear")
	advanced_filter_cancel_button.text = _t("ui.exchange.filters.cancel")
	advanced_filter_apply_button.text = _t("ui.exchange.filters.apply")


func _refresh_filter_option_labels() -> void:
	for field_id: String in ["primary_type", "secondary_type", "nature"]:
		var option := advanced_filter_controls.get(field_id) as OptionButton
		if option == null:
			continue
		for index in range(option.item_count):
			var value := str(option.get_item_metadata(index))
			option.set_item_text(
				index,
				_t("ui.exchange.filters.any") if value.is_empty() else _humanize_identifier(value),
			)
	for field_id: String in ["shiny", "hidden_ability"]:
		var option := advanced_filter_controls.get(field_id) as OptionButton
		if option == null:
			continue
		for index in range(option.item_count):
			var value := int(option.get_item_metadata(index))
			var key := "any" if value < 0 else ("yes" if value == 1 else "no")
			option.set_item_text(index, _t("ui.exchange.filters.%s" % key))
func _sync_advanced_filter_controls(state_override: Dictionary = {}) -> void:
	var state := state_override if not state_override.is_empty() else _current_browse_filter_state()
	for field_id: String in [
		"min_price", "max_price", "min_level", "max_level",
		"min_iv_hp", "min_iv_atk", "min_iv_def", "min_iv_spa", "min_iv_spd", "min_iv_spe",
	]:
		var spin := advanced_filter_controls.get(field_id) as SpinBox
		if spin != null:
			spin.value = int(state.get(field_id, 0))
	for field_id: String in ["category", "ability"]:
		var input := advanced_filter_controls.get(field_id) as LineEdit
		if input != null:
			input.text = str(state.get(field_id, ""))
	_select_filter_option("primary_type", str(state.get("primary_type", "")))
	_select_filter_option("secondary_type", str(state.get("secondary_type", "")))
	_select_filter_option("nature", str(state.get("nature", "")))
	_select_filter_option("shiny", int(state.get("shiny", -1)))
	_select_filter_option("hidden_ability", int(state.get("hidden_ability", -1)))


func _select_filter_option(field_id: String, value: Variant) -> void:
	var option := advanced_filter_controls.get(field_id) as OptionButton
	if option == null:
		return
	for index in range(option.item_count):
		if option.get_item_metadata(index) == value:
			option.select(index)
			return
	option.select(0)


func _read_advanced_filter_controls(commit_state := true) -> Dictionary:
	var state := _current_browse_filter_state().duplicate(true)
	for field_id: String in [
		"min_price", "max_price", "min_level", "max_level",
		"min_iv_hp", "min_iv_atk", "min_iv_def", "min_iv_spa", "min_iv_spd", "min_iv_spe",
	]:
		var spin := advanced_filter_controls.get(field_id) as SpinBox
		if spin != null:
			state[field_id] = int(spin.value)
	for field_id: String in ["category", "ability"]:
		var input := advanced_filter_controls.get(field_id) as LineEdit
		if input != null:
			state[field_id] = input.text.strip_edges()
	for field_id: String in ["primary_type", "secondary_type", "nature", "shiny", "hidden_ability"]:
		var option := advanced_filter_controls.get(field_id) as OptionButton
		if option != null:
			state[field_id] = option.get_item_metadata(option.selected)
	if commit_state:
		browse_filters[asset_filter] = state
	return state


func _apply_advanced_filters() -> void:
	if request_busy or active_tab != "browse":
		return
	var state := _read_advanced_filter_controls(false)
	var min_price := int(state.get("min_price", 0))
	var max_price := int(state.get("max_price", 0))
	if min_price > 0 and max_price > 0 and min_price > max_price:
		_set_status(_t("ui.exchange.filters.price_range_error"), UI_DANGER)
		return
	if asset_filter == "pokemon" and int(state.get("min_level", 1)) > int(state.get("max_level", 100)):
		_set_status(_t("ui.exchange.filters.level_range_error"), UI_DANGER)
		return
	browse_filters[asset_filter] = state
	_hide_advanced_filter_panel()
	await _refresh_browse()


func _clear_advanced_filters() -> void:
	if request_busy or active_tab != "browse":
		return
	_sync_advanced_filter_controls(_default_browse_filter_state(asset_filter))


func _default_browse_filter_state(filter_id: String) -> Dictionary:
	if filter_id == "pokemon":
		return {
			"min_price": 0, "max_price": 0, "min_level": 1, "max_level": 100,
			"primary_type": "", "secondary_type": "", "nature": "", "ability": "", "shiny": -1,
			"hidden_ability": -1,
			"min_iv_hp": 0, "min_iv_atk": 0, "min_iv_def": 0,
			"min_iv_spa": 0, "min_iv_spd": 0, "min_iv_spe": 0,
			"sort_by": "newest", "sort_direction": "desc",
		}
	return {
		"min_price": 0, "max_price": 0, "category": "",
		"sort_by": "newest", "sort_direction": "desc",
	}


func _current_browse_filter_state() -> Dictionary:
	if not browse_filters.has(asset_filter):
		browse_filters[asset_filter] = _default_browse_filter_state(asset_filter)
	return _dictionary(browse_filters.get(asset_filter))


func _current_browse_filter_params() -> Dictionary:
	var state := _current_browse_filter_state()
	var params: Dictionary = {}
	var min_price := int(state.get("min_price", 0))
	var max_price := int(state.get("max_price", 0))
	if min_price > 0:
		params["minPrice"] = min_price
	if max_price > 0:
		params["maxPrice"] = max_price
	var sort_by := str(state.get("sort_by", "")).strip_edges()
	if not sort_by.is_empty():
		params["sortBy"] = sort_by
		params["sortDirection"] = str(state.get("sort_direction", "asc"))
	if asset_filter == "item":
		var category := str(state.get("category", "")).strip_edges()
		if not category.is_empty():
			params["itemCategory"] = category
		return params
	var min_level := int(state.get("min_level", 1))
	var max_level := int(state.get("max_level", 100))
	if min_level > 1:
		params["minLevel"] = min_level
	if max_level < 100:
		params["maxLevel"] = max_level
	for field_id: String in ["nature", "ability"]:
		var value := str(state.get(field_id, "")).strip_edges()
		if not value.is_empty():
			params[field_id] = value
	var type_param_by_field := {
		"primary_type": "primaryType",
		"secondary_type": "secondaryType",
	}
	for field_id: String in type_param_by_field:
		var type_value := str(state.get(field_id, "")).strip_edges()
		if not type_value.is_empty():
			params[str(type_param_by_field.get(field_id))] = type_value
	var shiny := int(state.get("shiny", -1))
	if shiny >= 0:
		params["shiny"] = shiny == 1
	var hidden_ability := int(state.get("hidden_ability", -1))
	if hidden_ability >= 0:
		params["hiddenAbility"] = hidden_ability == 1
	var iv_param_by_stat := {
		"hp": "minHpIv", "atk": "minAtkIv", "def": "minDefIv",
		"spa": "minSpAtkIv", "spd": "minSpDefIv", "spe": "minSpeedIv",
	}
	for stat_id: String in iv_param_by_stat:
		var minimum_iv := int(state.get("min_iv_%s" % stat_id, 0))
		if minimum_iv > 0:
			params[str(iv_param_by_stat.get(stat_id))] = minimum_iv
	return params


func _active_advanced_filter_count() -> int:
	var params := _current_browse_filter_params()
	var filter_count := params.size()
	if params.has("sortBy"):
		filter_count -= 1
	if params.has("sortDirection"):
		filter_count -= 1
	return maxi(filter_count, 0)


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
		await service.call(
			"load_listings",
			asset_filter,
			search_input.text if search_input != null else "",
			50,
			0,
			_current_browse_filter_params(),
		)
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
		empty.name = "ExchangeEmptyState"
		empty.text = _t("ui.exchange.empty.%s" % active_tab)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		BROWSE_CARD_HEIGHT if browse_card else 70,
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	if browse_card:
		_build_browse_card_content(button, entry, kind)
	else:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_constant_override("icon_max_width", 52)
		button.text = "%s\n%s" % [_entry_name(entry, kind), _entry_subtitle(entry, kind)]
		button.icon = _entry_texture(entry, kind)
	button.tooltip_text = _entry_name(entry, kind)
	button.pressed.connect(_select_entry.bind(entry, kind))
	_apply_button_style(button, _entry_matches_selection(entry, kind))
	return button


func _build_browse_card_content(button: Button, entry: Dictionary, kind: String) -> void:
	button.text = ""
	button.icon = null
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var icon := TextureRect.new()
	icon.name = "BrowseCardIcon"
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = _entry_texture(entry, kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(icon)

	var name := Label.new()
	name.name = "BrowseCardName"
	name.text = _entry_name(entry, kind)
	name.tooltip_text = name.text
	name.custom_minimum_size = Vector2(0, 34)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible = 2
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(name)

	var asset := _entry_asset(entry, kind)
	var metadata_label := Label.new()
	metadata_label.name = "BrowseCardTrait"
	metadata_label.text = (
		_t("ui.exchange.summary.level", {"value": int(asset.get("level", 1))})
		if _entry_asset_type(entry, kind) == "pokemon"
		else "×%d" % maxi(int(entry.get("quantity", 1)), 1)
	)
	metadata_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metadata_label.add_theme_font_size_override("font_size", 10)
	metadata_label.add_theme_color_override("font_color", UI_CYAN)
	stack.add_child(metadata_label)

	var price := Label.new()
	price.name = "BrowseCardPrice"
	price.text = _t(
		"ui.exchange.total",
		{"amount": _format_money(int(entry.get("totalPrice", 0)))},
	)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 13)
	price.add_theme_color_override("font_color", UI_GOLD)
	stack.add_child(price)


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
	var asset_type := _entry_asset_type(selected_entry, selected_kind)
	if asset_type == "pokemon":
		detail_stack.add_child(_build_pokemon_detail_header(asset))
		detail_stack.add_child(_build_pokemon_quick_summary(asset))
	else:
		detail_stack.add_child(_build_item_detail_header(asset))

	if selected_kind == "sell":
		_build_sell_controls(asset)
	else:
		_build_listing_controls()


func _build_item_detail_header(asset: Dictionary) -> Control:
	var hero := PanelContainer.new()
	hero.name = "ItemDetailHeader"
	hero.add_theme_stylebox_override(
		"panel", _compact_panel_style(Color("#081725ee"), UI_BORDER, 10, 1, 10, 9)
	)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 12)
	hero.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(72, 72)
	icon_frame.add_theme_stylebox_override(
		"panel", _compact_panel_style(Color("#050d17e8"), Color(UI_GOLD, 0.55), 9, 1, 5, 5)
	)
	row.add_child(icon_frame)
	var icon_center := CenterContainer.new()
	icon_frame.add_child(icon_center)
	var icon := TextureRect.new()
	icon.name = "ItemDetailIcon"
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = _entry_texture(selected_entry, selected_kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_center.add_child(icon)

	var information := VBoxContainer.new()
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.alignment = BoxContainer.ALIGNMENT_CENTER
	information.add_theme_constant_override("separation", 5)
	row.add_child(information)
	var name := Label.new()
	name.text = _entry_name(selected_entry, selected_kind)
	name.tooltip_text = name.text
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 19)
	name.add_theme_color_override("font_color", UI_TEXT)
	information.add_child(name)
	var description := Label.new()
	description.text = _asset_detail_text(asset, "item")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", UI_MUTED)
	information.add_child(description)
	return hero


func _build_pokemon_detail_header(asset: Dictionary) -> Control:
	var primary_type := _optional_text(_array(asset.get("types", [])).front() if not _array(asset.get("types", [])).is_empty() else "")
	var type_surface := TypeColors.get_slot_background(primary_type, UI_INTERACTIVE)
	var type_border := TypeColors.get_slot_border(primary_type, UI_BORDER)
	var hero := PanelContainer.new()
	hero.name = "PokemonPurchaseHeader"
	hero.add_theme_stylebox_override("panel", _compact_panel_style(type_surface.darkened(0.58), type_border, 10, 1, 8, 5))
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 86)
	header.add_theme_constant_override("separation", 10)
	hero.add_child(header)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(86, 86)
	icon_frame.add_theme_stylebox_override("panel", _compact_panel_style(Color(type_surface, 0.34), Color(type_border, 0.7), 9, 1, 4, 4))
	header.add_child(icon_frame)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.texture = _entry_texture(selected_entry, selected_kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(icon)

	var information := VBoxContainer.new()
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information.add_theme_constant_override("separation", 2)
	header.add_child(information)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	information.add_child(name_row)
	var name := Label.new()
	name.text = _entry_name(selected_entry, selected_kind)
	name.tooltip_text = name.text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 19)
	name.add_theme_color_override("font_color", UI_TEXT)
	name_row.add_child(name)
	if bool(asset.get("shiny", false)):
		name_row.add_child(_build_micro_badge("★", UI_GOLD, Color("#493a13e8"), _t("ui.exchange.summary.shiny")))
	if bool(asset.get("hiddenAbility", asset.get("hidden_ability", false))):
		name_row.add_child(_build_micro_badge("HA", UI_PURPLE, Color("#35204be8"), _t("ui.exchange.summary.hidden_ability")))
	var open_button := Button.new()
	open_button.name = "PokemonSummaryButton"
	open_button.text = _t("ui.mail.summary")
	open_button.tooltip_text = _t("ui.exchange.action.open_summary_tooltip")
	open_button.custom_minimum_size = Vector2(72, 26)
	open_button.pressed.connect(_on_pokemon_summary_pressed.bind(asset.duplicate(true)))
	_apply_button_style(open_button)
	name_row.add_child(open_button)

	var traits: Array[String] = [
		_t("ui.exchange.summary.level", {"value": int(asset.get("level", 1))}),
		_content_name("natures", _optional_text(asset.get("nature")), _optional_text(asset.get("nature"), "—")),
	]
	var gender := _optional_text(asset.get("gender"))
	if not gender.is_empty():
		traits.append(gender)
	var trait_label := Label.new()
	trait_label.text = " • ".join(traits)
	trait_label.clip_text = true
	trait_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trait_label.add_theme_font_size_override("font_size", 11)
	trait_label.add_theme_color_override("font_color", UI_CYAN)
	information.add_child(trait_label)

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 4)
	information.add_child(type_row)
	for value: Variant in _array(asset.get("types", [])):
		var type_id := _optional_text(value)
		if not type_id.is_empty():
			type_row.add_child(_build_type_chip(type_id))
	var ability_id := _optional_text(asset.get("ability"))
	var ability_label := Label.new()
	ability_label.text = "%s  %s" % [
		_t("ui.exchange.summary.ability"),
		_content_name("abilities", ability_id, _humanize_identifier(ability_id, "—")),
	]
	ability_label.clip_text = true
	ability_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ability_label.add_theme_font_size_override("font_size", 10)
	ability_label.add_theme_color_override("font_color", UI_MUTED)
	information.add_child(ability_label)

	return hero


func _build_micro_badge(text: String, color: Color, background: Color, tooltip: String) -> Control:
	var badge := PanelContainer.new()
	badge.tooltip_text = tooltip
	badge.add_theme_stylebox_override("panel", _compact_panel_style(background, Color(color, 0.7), 6, 1, 4, 1))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	badge.add_child(label)
	return badge


func _build_type_chip(type_id: String) -> Control:
	var chip := PanelContainer.new()
	chip.set_meta("exchange_type_chip", true)
	var background := TypeColors.get_slot_background(type_id, UI_INTERACTIVE)
	var border := TypeColors.get_slot_border(type_id, UI_BORDER)
	chip.add_theme_stylebox_override("panel", _compact_panel_style(background.darkened(0.18), border, 6, 1, 6, 2))
	var label := Label.new()
	label.text = _content_name("types", type_id, _humanize_identifier(type_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", TypeColors.get_slot_accent(type_id, UI_TEXT))
	chip.add_child(label)
	return chip


func _build_pokemon_quick_summary(asset: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "PokemonQuickSummary"
	panel.add_theme_stylebox_override("panel", _compact_panel_style(Color("#07111dcc"), UI_BORDER, 8, 1, 8, 5))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var ivs := _dictionary(asset.get("ivs", {}))
	content.add_child(_quick_stat_summary(
		_t("ui.exchange.summary.ivs", {"total": _stat_total(ivs), "maximum": 186}),
		ivs,
		"iv"
	))
	var evs := _dictionary(asset.get("evs", {}))
	content.add_child(_quick_stat_summary(
		_t("ui.exchange.summary.evs", {"total": _stat_total(evs), "maximum": 510}),
		evs,
		"ev"
	))
	content.add_child(_quick_moves_summary(_array(asset.get("moves", []))))
	return panel


func _quick_stat_summary(title_text: String, stats: Dictionary, stat_kind: String) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 1)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UI_MUTED)
	section.add_child(title)
	var values := GridContainer.new()
	values.columns = 6
	values.add_theme_constant_override("h_separation", 4)
	section.add_child(values)
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		var stat_amount := int(stats.get(key, 0))
		var highlight := (stat_kind == "iv" and stat_amount == 31) or (stat_kind == "ev" and stat_amount > 0)
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", _compact_panel_style(
			Color("#0d2335dc") if highlight else Color("#091622c4"),
			Color(UI_CYAN, 0.55) if stat_kind == "iv" and highlight else (Color(UI_GOLD, 0.55) if highlight else Color(UI_BORDER, 0.42)),
			5,
			1,
			3,
			2
		))
		var cell_content := VBoxContainer.new()
		cell_content.add_theme_constant_override("separation", 0)
		cell.add_child(cell_content)
		var stat_name := Label.new()
		stat_name.text = str({
			"hp": "HP", "atk": "Atk", "def": "Def",
			"spa": "SpA", "spd": "SpD", "spe": "Spe",
		}.get(key, key))
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_name.add_theme_font_size_override("font_size", 9)
		stat_name.add_theme_color_override("font_color", UI_MUTED)
		cell_content.add_child(stat_name)
		var stat_value := Label.new()
		stat_value.text = str(stat_amount)
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_value.add_theme_font_size_override("font_size", 12)
		stat_value.add_theme_color_override("font_color", UI_CYAN if stat_kind == "iv" and highlight else (UI_GOLD if highlight else UI_TEXT))
		cell_content.add_child(stat_value)
		values.add_child(cell)
	return section


func _quick_moves_summary(moves: Array) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = _t("ui.exchange.summary.moves")
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UI_MUTED)
	section.add_child(title)
	if moves.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.exchange.summary.no_moves")
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", UI_MUTED)
		section.add_child(empty)
		return section
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	section.add_child(grid)
	for value: Variant in moves.slice(0, 4):
		var move := _dictionary(value)
		var move_id := _optional_text(move.get("id"), _optional_text(move.get("move")))
		var fallback := _optional_text(move.get("name"), _humanize_identifier(move_id, "—"))
		var move_type := _optional_text(move.get("type"))
		var chip := PanelContainer.new()
		chip.set_meta("exchange_move_chip", true)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var background := TypeColors.get_slot_background(move_type, UI_INTERACTIVE)
		var border := TypeColors.get_slot_border(move_type, UI_BORDER)
		chip.add_theme_stylebox_override("panel", _compact_panel_style(background.darkened(0.45), Color(border, 0.72), 6, 1, 6, 3))
		var label := Label.new()
		label.text = _content_name("moves", move_id, fallback)
		label.tooltip_text = label.text
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", UI_TEXT)
		chip.add_child(label)
		grid.add_child(chip)
	return section


func _on_pokemon_summary_pressed(asset: Dictionary) -> void:
	pokemon_summary_requested.emit(_pokemon_summary_payload(asset))


func _pokemon_summary_payload(asset: Dictionary) -> Dictionary:
	var payload := asset.duplicate(true)
	if _optional_text(payload.get("species")).is_empty():
		payload["species"] = _optional_text(
			payload.get("formId"),
			_optional_text(payload.get("speciesId"), _optional_text(payload.get("speciesName")))
		)
	var origin := _dictionary(payload.get("origin", {})).duplicate(true)
	for key: String in [
		"currentTrainerName", "current_trainer_name", "ownerName", "owner_name",
		"currentTrainerUserId", "current_trainer_user_id", "ownerUserId", "owner_user_id",
		"originalTrainerName", "original_trainer_name", "otName", "ot_name",
		"originalTrainerUserId", "original_trainer_user_id", "originalOwnerUserId", "original_owner_user_id",
	]:
		origin.erase(key)
	origin["currentTrainerName"] = _t("ui.exchange.summary.exchange_trainer")
	payload["origin"] = origin
	return payload


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
	var footer := PanelContainer.new()
	footer.name = "ExchangePurchaseFooter"
	footer.add_theme_stylebox_override("panel", _compact_panel_style(Color("#07111dcc"), Color("#806d34aa"), 8, 1, 8, 5))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	footer.add_child(content)
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 8)
	content.add_child(price_row)
	var price := Label.new()
	price.text = _t("ui.exchange.total", {"amount": _format_money(int(selected_entry.get("totalPrice", 0)))})
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.add_theme_font_size_override("font_size", 19)
	price.add_theme_color_override("font_color", UI_GOLD)
	price_row.add_child(price)
	var state := Label.new()
	state.text = "●  %s" % _t("ui.exchange.state.%s" % status)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.add_theme_color_override("font_color", UI_GREEN if status in ["active", "sold"] else UI_MUTED)
	price_row.add_child(state)
	if status == "active":
		var action := Button.new()
		action.name = "ExchangeListingActionButton"
		action.custom_minimum_size = Vector2(0, 40)
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
		content.add_child(action)
	detail_stack.add_child(footer)


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
	_normalize_filter_for_tab()
	for key: Variant in tab_buttons:
		var button := tab_buttons[key] as Button
		button.text = _t("ui.exchange.tab.%s" % str(key))
		button.disabled = request_busy
		_apply_button_style(button, str(key) == active_tab)
	for key: Variant in filter_buttons:
		var button := filter_buttons[key] as Button
		button.visible = not (active_tab == "sell" and str(key).is_empty())
		var label_key := "all" if str(key).is_empty() else str(key)
		button.text = _t("ui.exchange.filter.%s" % label_key)
		button.disabled = request_busy
		_apply_button_style(button, str(key) == asset_filter)
	search_input.editable = not request_busy
	if advanced_filter_button != null:
		var filter_count := _active_advanced_filter_count()
		advanced_filter_button.text = _t(
			"ui.exchange.filters.button_active" if filter_count > 0 else "ui.exchange.filters.button",
			{"count": filter_count},
		)
		advanced_filter_button.visible = active_tab == "browse"
		advanced_filter_button.disabled = request_busy
		_apply_button_style(
			advanced_filter_button,
			filter_count > 0 or (advanced_filter_panel != null and advanced_filter_panel.visible),
		)
	if browse_sort_button != null:
		browse_sort_button.visible = active_tab == "browse"
		browse_sort_button.disabled = request_busy
		_refresh_browse_sort_button()
	if advanced_filter_apply_button != null:
		advanced_filter_apply_button.disabled = request_busy
	if advanced_filter_clear_button != null:
		advanced_filter_clear_button.disabled = request_busy
	if refresh_button != null:
		refresh_button.text = _t("ui.exchange.refresh")
		refresh_button.disabled = request_busy
	_refresh_money()


func _normalize_filter_for_tab() -> void:
	if asset_filter not in ["item", "pokemon"]:
		asset_filter = "item"


func _center_in_parent() -> void:
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	size = EXCHANGE_SIZE
	position = (parent_control.size - size) * 0.5
	_clamp_to_parent()


func _translate_static_ui() -> void:
	title_label.text = _t("ui.exchange.title")
	subtitle_label.text = _t("ui.exchange.subtitle")
	search_input.placeholder_text = _t("ui.exchange.search")
	_refresh_advanced_filter_panel()
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
		var species_id := _optional_text(
			asset.get("formId"),
			_optional_text(asset.get("speciesId"), _optional_text(asset.get("species")))
		)
		var species_fallback := _optional_text(asset.get("speciesName"), _humanize_identifier(species_id, _t("ui.exchange.pokemon")))
		var species := _content_name("species", species_id, species_fallback)
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


func _humanize_identifier(value: String, fallback := "") -> String:
	var normalized := value.strip_edges().replace("_", " ").replace("-", " ")
	return normalized.capitalize() if not normalized.is_empty() else fallback


func _content_name(kind: String, content_id: String, fallback: String) -> String:
	if content_id.is_empty():
		return fallback
	var content_localization := get_node_or_null("/root/ContentLocalization")
	if content_localization == null:
		return fallback
	return str(content_localization.call("display_name", kind, content_id, fallback))


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


func _stat_total(stats: Dictionary) -> int:
	var total := 0
	for key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		total += maxi(int(stats.get(key, 0)), 0)
	return total


func _new_request_id(prefix: String) -> String:
	return "%s-%d-%d" % [prefix, Time.get_unix_time_from_system(), randi()]


func _apply_button_style(button: Button, selected := false) -> void:
	var bg := Color("#12324af5") if selected else UI_INTERACTIVE
	var border := UI_CYAN if selected else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(bg, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#12324af5"), UI_CYAN, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#173e5af5"), UI_CYAN, 8, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#07111dcc"), Color("#263b4d99"), 8, 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color("#12324af5"), UI_CYAN, 8, 2))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED, 0.55))


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", _input_style(Color("#030812e8"), UI_BORDER))
	input.add_theme_stylebox_override("focus", _input_style(Color("#071524f5"), UI_CYAN, 2))
	input.add_theme_stylebox_override("read_only", _input_style(Color("#07111dcc"), Color("#263b4d99")))
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_uneditable_color", Color(UI_MUTED, 0.7))
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED, 0.75))
	input.add_theme_color_override("caret_color", UI_CYAN)
	input.add_theme_color_override("selection_color", Color(UI_CYAN, 0.28))
	input.add_theme_color_override("clear_button_color", UI_MUTED)
	input.add_theme_color_override("clear_button_color_pressed", UI_TEXT)


func _input_style(background: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style := _panel_style(background, border, 8, border_width)
	style.content_margin_left = 11
	style.content_margin_top = 6
	style.content_margin_right = 9
	style.content_margin_bottom = 6
	return style


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


func _compact_panel_style(
	background: Color,
	border: Color,
	radius: int,
	width: int,
	horizontal_margin: int,
	vertical_margin: int
) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, width)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
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
