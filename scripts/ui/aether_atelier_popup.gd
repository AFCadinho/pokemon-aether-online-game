class_name AetherAtelierPopup
extends PanelContainer

signal closed
signal bundle_created(result: Dictionary)
signal chroma_dyed(result: Dictionary)

const AetherAtelierService := preload("res://scripts/services/aether_atelier_service.gd")
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_HOVER := Color("#112a44fa")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_PURPLE := Color("#b28ae8")
const UI_GOLD := Color("#f0cc70")
const UI_GREEN := Color("#70d6a1")
const UI_DANGER := Color("#ef7085")
const PREVIEW_SIZE := Vector2i(160, 176)
const PREVIEW_POSITION := Vector2(80, 108)
const PREVIEW_SCALE := Vector2(2.5, 2.5)
const PREVIEW_DIRECTIONS := ["down", "left", "right", "up"]
const APPEARANCE_WEAR_SLOT_ORDER := [
	"hair",
	"headgear",
	"facial_hair",
	"facegear",
	"top",
	"bottom",
	"shoes",
]

var atelier_service: AetherAtelierServiceNode
var outfits: Array[Dictionary] = []
var chroma_items: Array[Dictionary] = []
var active_mode := "outfits"
var selected_box_item_id := ""
var selected_chroma_item_id := ""
var selected_chroma_color := "#ffffff"
var pending_chroma_colors: Dictionary = {}
var selected_wear_item_ids: Dictionary = {}
var initial_wear_item_ids: Dictionary = {}
var preview_direction := "down"
var money := 0
var create_in_progress := false

var outfits_tab_button: Button
var dye_tab_button: Button
var money_label: Label
var search_input: LineEdit
var catalog_summary_label: Label
var catalog_caption_label: Label
var outfit_list: VBoxContainer
var detail_icon: TextureRect
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var detail_name_label: Label
var detail_gender_label: Label
var detail_description_label: Label
var detail_progress_label: Label
var components_caption_label: Label
var component_scroll: ScrollContainer
var component_list: VBoxContainer
var dye_palette: VBoxContainer
var dye_swatch_grid: GridContainer
var dye_color_picker: ColorPickerButton
var dye_hex_input: LineEdit
var preview_direction_buttons: Dictionary = {}
var fee_label: Label
var status_label: Label
var create_button: Button


func _ready() -> void:
	atelier_service = AetherAtelierService.new()
	add_child(atelier_service)
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#795aa5dd"), 14, 2))
	_build_interface()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open_atelier() -> void:
	visible = true
	status_label.text = _t("ui.atelier.status.loading")
	status_label.add_theme_color_override("font_color", UI_MUTED)
	create_button.disabled = true
	var result: Dictionary = await atelier_service.load_catalog()
	if not bool(result.get("success", false)):
		status_label.text = str(result.get("error", _t("ui.atelier.error.load")))
		status_label.add_theme_color_override("font_color", UI_DANGER)
		return
	_apply_catalog(result)
	status_label.text = _t("ui.atelier.status.choose_outfit")
	status_label.add_theme_color_override("font_color", UI_MUTED)


func close_atelier() -> void:
	if create_in_progress:
		return
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 11)
	margin.add_child(layout)
	layout.add_child(_build_header())
	layout.add_child(_build_service_tabs())

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 9)
	layout.add_child(search_row)
	search_input = LineEdit.new()
	search_input.name = "AtelierSearchInput"
	_set_localized_property(search_input, "placeholder_text", "ui.atelier.search")
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(0, 38)
	search_input.text_changed.connect(_on_search_changed)
	_apply_line_edit_style(search_input)
	search_row.add_child(search_input)

	catalog_summary_label = Label.new()
	catalog_summary_label.custom_minimum_size = Vector2(180, 38)
	catalog_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	catalog_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_summary_label.add_theme_font_size_override("font_size", 11)
	catalog_summary_label.add_theme_color_override("font_color", UI_MUTED)
	search_row.add_child(catalog_summary_label)

	var workspace := HBoxContainer.new()
	workspace.name = "AtelierWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	layout.add_child(workspace)
	workspace.add_child(_build_catalog_panel())
	workspace.add_child(_build_detail_panel())

func _build_service_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	outfits_tab_button = Button.new()
	_set_localized_property(outfits_tab_button, "text", "ui.atelier.tab.outfits")
	outfits_tab_button.custom_minimum_size = Vector2(150, 32)
	outfits_tab_button.focus_mode = Control.FOCUS_NONE
	outfits_tab_button.pressed.connect(_select_mode.bind("outfits"))
	tabs.add_child(outfits_tab_button)
	dye_tab_button = Button.new()
	_set_localized_property(dye_tab_button, "text", "ui.atelier.tab.customize")
	dye_tab_button.custom_minimum_size = Vector2(150, 32)
	dye_tab_button.focus_mode = Control.FOCUS_NONE
	dye_tab_button.pressed.connect(_select_mode.bind("dye"))
	tabs.add_child(dye_tab_button)
	var explanation := Label.new()
	_set_localized_property(explanation, "text", "ui.atelier.tab.explanation")
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explanation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	explanation.add_theme_font_size_override("font_size", 10)
	explanation.add_theme_color_override("font_color", UI_MUTED)
	tabs.add_child(explanation)
	_refresh_mode_tabs()
	return tabs


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 10)

	var accent := Panel.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.add_theme_stylebox_override("panel", _panel_style(UI_PURPLE, UI_PURPLE, 2, 0))
	header.add_child(accent)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)
	var title := Label.new()
	_set_localized_property(title, "text", "ui.atelier.title")
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.atelier.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle)

	var wallet_panel := PanelContainer.new()
	wallet_panel.custom_minimum_size = Vector2(170, 38)
	wallet_panel.add_theme_stylebox_override("panel", _panel_style(UI_INTERACTIVE, Color("#806d34aa"), 9, 1))
	header.add_child(wallet_panel)
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 13)
	money_label.add_theme_color_override("font_color", UI_GOLD)
	wallet_panel.add_child(money_label)

	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_atelier)
	_apply_button_style(close_button, false)
	header.add_child(close_button)
	return header


func _build_catalog_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "OutfitCatalogPanel"
	panel.custom_minimum_size = Vector2(390, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#06101bf2"), UI_BORDER, 10, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	catalog_caption_label = Label.new()
	catalog_caption_label.text = _t("ui.atelier.catalog.outfits")
	catalog_caption_label.add_theme_font_size_override("font_size", 10)
	catalog_caption_label.add_theme_color_override("font_color", UI_PURPLE)
	stack.add_child(catalog_caption_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	outfit_list = VBoxContainer.new()
	outfit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outfit_list.add_theme_constant_override("separation", 7)
	scroll.add_child(outfit_list)
	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "OutfitDetailPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 10, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 13)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 13)
	stack.add_child(preview_row)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(PREVIEW_SIZE)
	icon_panel.add_theme_stylebox_override("panel", _panel_style(Color("#030a12ee"), Color("#4b6880aa"), 9, 1))
	preview_row.add_child(icon_panel)
	detail_icon = TextureRect.new()
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_panel.add_child(detail_icon)
	preview_container = SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	preview_container.stretch = false
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.visible = false
	icon_panel.add_child(preview_container)
	preview_viewport = SubViewport.new()
	preview_viewport.transparent_bg = true
	preview_viewport.size = PREVIEW_SIZE
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(preview_viewport)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 5)
	preview_row.add_child(identity)
	detail_name_label = Label.new()
	detail_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_name_label.add_theme_font_size_override("font_size", 20)
	detail_name_label.add_theme_color_override("font_color", UI_TEXT)
	identity.add_child(detail_name_label)
	detail_gender_label = Label.new()
	detail_gender_label.add_theme_font_size_override("font_size", 10)
	detail_gender_label.add_theme_color_override("font_color", UI_PURPLE)
	identity.add_child(detail_gender_label)
	detail_description_label = Label.new()
	detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description_label.add_theme_font_size_override("font_size", 11)
	detail_description_label.add_theme_color_override("font_color", UI_MUTED)
	identity.add_child(detail_description_label)

	detail_progress_label = Label.new()
	detail_progress_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(detail_progress_label)
	components_caption_label = Label.new()
	components_caption_label.text = _t("ui.atelier.components.required")
	components_caption_label.add_theme_font_size_override("font_size", 10)
	components_caption_label.add_theme_color_override("font_color", UI_PURPLE)
	stack.add_child(components_caption_label)
	component_scroll = ScrollContainer.new()
	component_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	component_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(component_scroll)
	component_list = VBoxContainer.new()
	component_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_list.add_theme_constant_override("separation", 5)
	component_scroll.add_child(component_list)
	dye_palette = VBoxContainer.new()
	dye_palette.visible = false
	dye_palette.add_theme_constant_override("separation", 7)
	stack.add_child(dye_palette)
	_build_dye_palette()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	stack.add_child(footer)
	var footer_copy := VBoxContainer.new()
	footer_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_copy)
	fee_label = Label.new()
	fee_label.add_theme_font_size_override("font_size", 13)
	fee_label.add_theme_color_override("font_color", UI_GOLD)
	footer_copy.add_child(fee_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", UI_MUTED)
	footer_copy.add_child(status_label)
	create_button = Button.new()
	_set_localized_property(create_button, "text", "ui.atelier.create")
	create_button.custom_minimum_size = Vector2(160, 42)
	create_button.focus_mode = Control.FOCUS_NONE
	create_button.pressed.connect(_on_create_pressed)
	_apply_button_style(create_button, true)
	footer.add_child(create_button)
	return panel

func _build_dye_palette() -> void:
	var direction_row := HBoxContainer.new()
	direction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	direction_row.add_theme_constant_override("separation", 4)
	dye_palette.add_child(direction_row)
	for direction: String in PREVIEW_DIRECTIONS:
		var button := Button.new()
		button.text = direction.capitalize()
		button.custom_minimum_size = Vector2(58, 26)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_preview_direction.bind(direction))
		_apply_button_style(button, false)
		direction_row.add_child(button)
		preview_direction_buttons[direction] = button

	dye_swatch_grid = GridContainer.new()
	dye_swatch_grid.columns = 10
	dye_swatch_grid.add_theme_constant_override("h_separation", 4)
	dye_swatch_grid.add_theme_constant_override("v_separation", 4)
	dye_palette.add_child(dye_swatch_grid)
	for swatch: Dictionary in CharacterAppearanceService.CHROMA_COLOR_SWATCHES:
		var color_id := str(swatch.get("id", "#ffffff"))
		var button := Button.new()
		button.custom_minimum_size = Vector2(24, 24)
		button.tooltip_text = str(swatch.get("label", color_id))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_dye_color.bind(color_id))
		button.set_meta("color_id", color_id)
		button.set_meta("color", swatch.get("color", Color.WHITE))
		dye_swatch_grid.add_child(button)

	var custom_row := HBoxContainer.new()
	custom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_row.add_theme_constant_override("separation", 7)
	dye_palette.add_child(custom_row)
	var custom_label := Label.new()
	_set_localized_property(custom_label, "text", "ui.atelier.custom")
	custom_label.add_theme_color_override("font_color", UI_MUTED)
	custom_row.add_child(custom_label)
	dye_color_picker = ColorPickerButton.new()
	dye_color_picker.custom_minimum_size = Vector2(54, 26)
	dye_color_picker.focus_mode = Control.FOCUS_NONE
	dye_color_picker.color_changed.connect(_on_dye_picker_changed)
	custom_row.add_child(dye_color_picker)
	dye_hex_input = LineEdit.new()
	dye_hex_input.placeholder_text = "#RRGGBB"
	dye_hex_input.max_length = 7
	dye_hex_input.custom_minimum_size = Vector2(108, 28)
	dye_hex_input.text_changed.connect(_on_dye_hex_changed)
	dye_hex_input.text_submitted.connect(_commit_dye_hex)
	dye_hex_input.focus_exited.connect(_commit_dye_hex)
	_apply_line_edit_style(dye_hex_input)
	custom_row.add_child(dye_hex_input)


func _apply_catalog(result: Dictionary) -> void:
	money = maxi(int((result.get("wallet", {}) as Dictionary).get("money", 0)), 0)
	outfits.clear()
	for outfit_value: Variant in result.get("outfits", []):
		if outfit_value is Dictionary:
			outfits.append((outfit_value as Dictionary).duplicate(true))
	chroma_items.clear()
	for item_value: Variant in result.get("chromaItems", []):
		if item_value is Dictionary:
			chroma_items.append((item_value as Dictionary).duplicate(true))
	money_label.text = _t("ui.atelier.money", {"amount": _format_number(money)})
	if selected_box_item_id == "" or _selected_outfit().is_empty():
		selected_box_item_id = str(outfits[0].get("boxItemId", "")) if not outfits.is_empty() else ""
	selected_wear_item_ids.clear()
	initial_wear_item_ids.clear()
	for item: Dictionary in chroma_items:
		if bool(item.get("equipped", false)):
			var slot := str(item.get("slot", ""))
			var item_id := str(item.get("itemId", ""))
			selected_wear_item_ids[slot] = item_id
			initial_wear_item_ids[slot] = item_id
	if selected_chroma_item_id == "" or _selected_chroma_item().is_empty():
		selected_chroma_item_id = str(chroma_items[0].get("itemId", "")) if not chroma_items.is_empty() else ""
	pending_chroma_colors.clear()
	selected_chroma_color = str(_selected_chroma_item().get("color", "#ffffff"))
	_render_outfit_list()
	_refresh_detail()


func _render_outfit_list() -> void:
	for child: Node in outfit_list.get_children():
		child.queue_free()
	catalog_caption_label.text = (
		_t("ui.atelier.catalog.wear")
		if active_mode == "dye"
		else _t("ui.atelier.catalog.outfits")
	)
	var search_text := search_input.text.strip_edges().to_lower()
	var visible_count := 0
	if active_mode == "dye":
		for slot: String in APPEARANCE_WEAR_SLOT_ORDER:
			var slot_items: Array[Dictionary] = []
			for item: Dictionary in chroma_items:
				if (
					str(item.get("slot", "")) == slot
					and _chroma_item_matches_search(item, search_text)
				):
					slot_items.append(item)
			if slot_items.is_empty():
				continue
			outfit_list.add_child(_create_wear_slot_heading(slot))
			for item: Dictionary in slot_items:
				visible_count += 1
				outfit_list.add_child(_create_chroma_item_card(item))
		catalog_summary_label.text = _t("ui.atelier.count.wear", {
			"visible": visible_count,
			"total": chroma_items.size(),
		})
		if visible_count == 0:
			var empty_dye_label := Label.new()
			empty_dye_label.text = (
				_t("ui.atelier.empty.wear")
				if search_text == ""
				else _t("ui.atelier.empty.wear_search")
			)
			empty_dye_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty_dye_label.add_theme_color_override("font_color", UI_MUTED)
			outfit_list.add_child(empty_dye_label)
		return
	for outfit: Dictionary in outfits:
		if not _outfit_matches_search(outfit, search_text):
			continue
		visible_count += 1
		outfit_list.add_child(_create_outfit_card(outfit))
	catalog_summary_label.text = _t("ui.atelier.count.outfits", {
		"visible": visible_count,
		"total": outfits.size(),
	})
	if visible_count == 0:
		var empty_label := Label.new()
		empty_label.text = _t("ui.atelier.empty.search")
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", UI_MUTED)
		outfit_list.add_child(empty_label)


func _create_wear_slot_heading(slot: String) -> Label:
	var heading := Label.new()
	heading.text = _slot_label(slot).to_upper()
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", UI_PURPLE)
	heading.add_theme_constant_override("outline_size", 2)
	heading.add_theme_color_override("font_outline_color", UI_BG)
	heading.custom_minimum_size = Vector2(0, 24)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return heading


func _create_outfit_card(outfit: Dictionary) -> Button:
	var box_item_id := str(outfit.get("boxItemId", ""))
	var selected := box_item_id == selected_box_item_id
	var ready := bool(outfit.get("canCreate", false))
	var button := Button.new()
	button.name = "Outfit_%s" % box_item_id
	button.text = ""
	button.custom_minimum_size = Vector2(0, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_select_outfit.bind(box_item_id))
	_apply_outfit_card_style(button, selected, ready)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = CharacterAppearanceService.get_cosmetic_item_icon(
		box_item_id,
		_outfit_icon_gender(outfit)
	)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name_label := Label.new()
	name_label.text = _item_name(box_item_id, str(outfit.get("name", box_item_id)))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name_label)
	var owned_count := int(outfit.get("ownedComponentCount", 0))
	var total_count := int(outfit.get("totalComponentCount", 1))
	var meta_label := Label.new()
	meta_label.text = _t("ui.atelier.outfit.meta", {
		"owned": owned_count,
		"total": total_count,
		"gender": _outfit_gender_label(outfit),
	})
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.add_theme_color_override("font_color", UI_GREEN if ready else UI_MUTED)
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(meta_label)
	return button


func _select_outfit(box_item_id: String) -> void:
	selected_box_item_id = box_item_id
	_render_outfit_list()
	_refresh_detail()

func _create_chroma_item_card(item: Dictionary) -> Button:
	var item_id := str(item.get("itemId", ""))
	var selected := str(selected_wear_item_ids.get(str(item.get("slot", "")), "")) == item_id
	var button := Button.new()
	button.name = "Chroma_%s" % item_id
	button.text = "%s\n%s%s" % [
		_item_name(item_id, str(item.get("name", item_id))),
		_slot_label(str(item.get("slot", ""))),
		(" · %s" % str(pending_chroma_colors.get(item_id, item.get("color", "#ffffff"))).to_upper())
		if bool(item.get("tintable", false)) else "",
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 62)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_select_chroma_item.bind(item_id))
	_apply_outfit_card_style(button, selected, false)
	return button


func _select_chroma_item(item_id: String) -> void:
	selected_chroma_item_id = item_id
	var item := _selected_chroma_item()
	selected_wear_item_ids[str(item.get("slot", ""))] = item_id
	selected_chroma_color = str(pending_chroma_colors.get(item_id, item.get("color", "#ffffff")))
	_render_outfit_list()
	_refresh_detail()


func _select_mode(mode: String) -> void:
	if mode not in ["outfits", "dye"] or active_mode == mode:
		return
	active_mode = mode
	search_input.text = ""
	search_input.placeholder_text = (
		_t("ui.atelier.search_wear")
		if active_mode == "dye"
		else _t("ui.atelier.search")
	)
	_refresh_mode_tabs()
	_render_outfit_list()
	_refresh_detail()


func _refresh_mode_tabs() -> void:
	if outfits_tab_button != null:
		_apply_button_style(outfits_tab_button, active_mode == "outfits")
	if dye_tab_button != null:
		_apply_button_style(dye_tab_button, active_mode == "dye")


func _refresh_detail() -> void:
	if active_mode == "dye":
		_refresh_dye_detail()
		return
	var outfit := _selected_outfit()
	var has_outfit := not outfit.is_empty()
	detail_icon.visible = has_outfit
	preview_container.visible = false
	dye_palette.visible = false
	component_scroll.visible = true
	components_caption_label.visible = true
	detail_name_label.text = (
		_item_name(str(outfit.get("boxItemId", "")), str(outfit.get("name", "")))
		if has_outfit
		else _t("ui.atelier.detail.select")
	)
	detail_gender_label.text = _outfit_gender_label(outfit).to_upper() if has_outfit else ""
	detail_description_label.text = (
		_item_description(
			str(outfit.get("boxItemId", "")),
			str(outfit.get("shortDesc", ""))
		)
		if has_outfit
		else _t("ui.atelier.detail.search_hint")
	)
	for child: Node in component_list.get_children():
		child.queue_free()
	if not has_outfit:
		detail_progress_label.text = ""
		fee_label.text = ""
		create_button.disabled = true
		return
	var box_item_id := str(outfit.get("boxItemId", ""))
	detail_icon.texture = CharacterAppearanceService.get_cosmetic_item_icon(
		box_item_id,
		_outfit_icon_gender(outfit)
	)
	var owned_count := int(outfit.get("ownedComponentCount", 0))
	var total_count := int(outfit.get("totalComponentCount", 1))
	var complete := owned_count >= total_count
	detail_progress_label.text = (
		_t("ui.atelier.detail.complete")
		if complete
		else _t("ui.atelier.detail.progress", {"owned": owned_count, "total": total_count})
	)
	detail_progress_label.add_theme_color_override("font_color", UI_GREEN if complete else UI_GOLD)
	for component_value: Variant in outfit.get("components", []):
		if component_value is Dictionary:
			component_list.add_child(_create_component_row(component_value as Dictionary))
	var fee := int(outfit.get("fee", 0))
	fee_label.text = _t("ui.atelier.fee", {"amount": _format_number(fee)})
	create_button.text = (
		_t("ui.atelier.status.creating")
		if create_in_progress
		else _t("ui.atelier.create_price", {"amount": _format_number(fee)})
	)
	create_button.disabled = create_in_progress or not bool(outfit.get("canCreate", false))
	if create_in_progress:
		status_label.text = _t("ui.atelier.status.packing")
		status_label.add_theme_color_override("font_color", UI_MUTED)
	elif not complete:
		status_label.text = _t("ui.atelier.error.components")
		status_label.add_theme_color_override("font_color", UI_MUTED)
	elif money < fee:
		status_label.text = _t("ui.atelier.error.money", {
			"amount": _format_number(fee - money),
		})
		status_label.add_theme_color_override("font_color", UI_DANGER)
	else:
		status_label.text = _t("ui.atelier.status.ready_box")
		status_label.add_theme_color_override("font_color", UI_GREEN)

func _refresh_dye_detail() -> void:
	var item := _selected_chroma_item()
	var has_item := not item.is_empty()
	detail_icon.visible = false
	preview_container.visible = has_item
	dye_palette.visible = has_item
	component_scroll.visible = false
	components_caption_label.visible = false
	detail_name_label.text = (
		_t("ui.atelier.wear.title")
		if has_item
		else _t("ui.atelier.wear.empty")
	)
	detail_gender_label.text = (
		"%s · %s" % [
			_slot_label(str(item.get("slot", ""))),
			_outfit_gender_label(item),
		]
	).to_upper() if has_item else ""
	detail_description_label.text = (
		_t("ui.atelier.wear.description")
		if has_item
		else _t("ui.atelier.wear.move_hint")
	)
	detail_progress_label.text = (
		_t("ui.atelier.wear.editing", {
			"item": _item_name(
				str(item.get("itemId", "")),
				str(item.get("name", ""))
			),
			"color": str(item.get("color", "#ffffff")).to_upper(),
		})
		if bool(item.get("tintable", false))
		else _t("ui.atelier.wear.editing_plain", {
			"item": _item_name(
				str(item.get("itemId", "")),
				str(item.get("name", ""))
			),
		})
		if has_item
		else ""
	)
	detail_progress_label.add_theme_color_override("font_color", UI_PURPLE)
	if not has_item:
		fee_label.text = ""
		create_button.text = _t("ui.atelier.wear.select_chroma")
		create_button.disabled = true
		status_label.text = _t("ui.atelier.wear.empty_status")
		status_label.add_theme_color_override("font_color", UI_MUTED)
		_clear_preview()
		return
	if selected_chroma_color == "":
		selected_chroma_color = str(item.get("color", "#ffffff"))
	var changed_count := _pending_color_change_count()
	var fee := _pending_chroma_fee()
	var outfit_changed := _has_wear_selection_changes()
	fee_label.text = _t("ui.atelier.wear.changed", {
		"count": changed_count,
		"amount": _format_number(fee),
	})
	create_button.text = (
		_t("ui.atelier.status.applying")
		if create_in_progress
		else _t("ui.atelier.wear.apply", {"amount": _format_number(fee)})
	)
	create_button.disabled = create_in_progress or (changed_count == 0 and not outfit_changed) or money < fee
	if create_in_progress:
		status_label.text = _t("ui.atelier.status.applying_color")
		status_label.add_theme_color_override("font_color", UI_MUTED)
	elif changed_count == 0 and not outfit_changed:
		status_label.text = _t("ui.atelier.wear.choose_change")
		status_label.add_theme_color_override("font_color", UI_MUTED)
	elif money < fee:
		status_label.text = _t("ui.atelier.error.money", {"amount": _format_number(fee - money)})
		status_label.add_theme_color_override("font_color", UI_DANGER)
	else:
		status_label.text = _t("ui.atelier.wear.preview_ready")
		status_label.add_theme_color_override("font_color", UI_GREEN)
	_sync_dye_controls()
	dye_swatch_grid.visible = bool(item.get("tintable", false))
	dye_hex_input.get_parent().visible = bool(item.get("tintable", false))
	_refresh_preview()


func _sync_dye_controls() -> void:
	if dye_color_picker != null:
		dye_color_picker.set_block_signals(true)
		dye_color_picker.color = Color.from_string(selected_chroma_color, Color.WHITE)
		dye_color_picker.set_block_signals(false)
	if dye_hex_input != null:
		dye_hex_input.set_block_signals(true)
		dye_hex_input.text = selected_chroma_color.to_upper()
		dye_hex_input.set_block_signals(false)
		dye_hex_input.add_theme_color_override("font_color", UI_TEXT)
	for child: Node in dye_swatch_grid.get_children():
		if not child is Button:
			continue
		var button := child as Button
		var color: Color = button.get_meta("color", Color.WHITE) as Color
		var selected := str(button.get_meta("color_id", "")).to_lower() == selected_chroma_color.to_lower()
		_apply_preview_swatch_style(button, color, selected)
	for direction_value: Variant in preview_direction_buttons.keys():
		var direction := str(direction_value)
		var button := preview_direction_buttons.get(direction) as Button
		if button != null:
			_apply_button_style(button, direction == preview_direction)


func _select_dye_color(color: String) -> void:
	var normalized := CharacterAppearanceService.normalize_hex_color_code(color)
	if normalized == "":
		return
	selected_chroma_color = normalized
	var item := _selected_chroma_item()
	if not bool(item.get("tintable", false)):
		return
	if normalized.to_lower() == str(item.get("color", "#ffffff")).to_lower():
		pending_chroma_colors.erase(selected_chroma_item_id)
	else:
		pending_chroma_colors[selected_chroma_item_id] = normalized
	_render_outfit_list()
	_refresh_dye_detail()


func _on_dye_picker_changed(color: Color) -> void:
	_select_dye_color("#%s" % color.to_html(false))


func _on_dye_hex_changed(color_text: String) -> void:
	var normalized := CharacterAppearanceService.normalize_hex_color_code(color_text)
	dye_hex_input.add_theme_color_override(
		"font_color",
		UI_TEXT if normalized != "" or color_text.strip_edges() == "" else UI_DANGER
	)
	if normalized != "":
		selected_chroma_color = normalized
		var item := _selected_chroma_item()
		if normalized.to_lower() == str(item.get("color", "#ffffff")).to_lower():
			pending_chroma_colors.erase(selected_chroma_item_id)
		else:
			pending_chroma_colors[selected_chroma_item_id] = normalized
		_render_outfit_list()
		_refresh_preview()
		_refresh_dye_action_state()


func _commit_dye_hex(_submitted_text: String = "") -> void:
	var normalized := CharacterAppearanceService.normalize_hex_color_code(dye_hex_input.text)
	if normalized != "":
		_select_dye_color(normalized)
	else:
		_refresh_dye_detail()


func _refresh_dye_action_state() -> void:
	var item := _selected_chroma_item()
	if item.is_empty():
		return
	var changed_count := _pending_color_change_count()
	var fee := _pending_chroma_fee()
	var outfit_changed := _has_wear_selection_changes()
	fee_label.text = _t("ui.atelier.wear.changed", {
		"count": changed_count,
		"amount": _format_number(fee),
	})
	create_button.text = (
		_t("ui.atelier.status.applying")
		if create_in_progress
		else _t("ui.atelier.wear.apply", {"amount": _format_number(fee)})
	)
	create_button.disabled = create_in_progress or (changed_count == 0 and not outfit_changed) or money < fee
	if changed_count == 0 and not outfit_changed:
		status_label.text = _t("ui.atelier.wear.choose_change")
		status_label.add_theme_color_override("font_color", UI_MUTED)
	elif money < fee:
		status_label.text = _t("ui.atelier.error.money", {"amount": _format_number(fee - money)})
		status_label.add_theme_color_override("font_color", UI_DANGER)
	else:
		status_label.text = _t("ui.atelier.wear.preview_ready")
		status_label.add_theme_color_override("font_color", UI_GREEN)


func _select_preview_direction(direction: String) -> void:
	if direction not in PREVIEW_DIRECTIONS:
		return
	preview_direction = direction
	_refresh_dye_detail()


func _clear_preview() -> void:
	if preview_viewport == null:
		return
	for child: Node in preview_viewport.get_children():
		child.queue_free()


func _refresh_preview() -> void:
	_clear_preview()
	var item := _selected_chroma_item()
	if item.is_empty():
		return
	var player_save := get_node_or_null("/root/PlayerSave")
	var appearance := (
		player_save.call("to_appearance_state")
		if player_save != null and player_save.has_method("to_appearance_state")
		else CharacterAppearanceService.get_default_appearance(_trainer_gender())
	) as Dictionary
	for worn_item: Dictionary in _selected_wear_items():
		var slot := str(worn_item.get("slot", ""))
		var item_id := str(worn_item.get("itemId", ""))
		appearance[slot] = str(worn_item.get("appearanceId", ""))
		appearance[_color_field_for_slot(slot)] = str(
			pending_chroma_colors.get(item_id, worn_item.get("color", "#ffffff"))
		)
	var visual := _create_preview_visual(appearance)
	preview_viewport.add_child(visual)
	visual.position = PREVIEW_POSITION
	visual.scale = PREVIEW_SCALE


func _create_preview_visual(appearance: Dictionary) -> Node2D:
	var root := Node2D.new()
	for layer: Dictionary in [
		{"category": "body", "z": 0},
		{"category": "bottom", "z": 1},
		{"category": "shoes", "z": 2},
		{"category": "top", "z": 3},
		{"category": "eyebrows", "z": 4},
		{"category": "eyes", "z": 5},
		{"category": "hair", "z": 6},
		{"category": "facial_hair", "z": 7},
		{"category": "facegear", "z": 8 if preview_direction != "up" else 5},
		{"category": "headgear", "z": 9},
	]:
		var category := str(layer.get("category", ""))
		var sprite := AnimatedSprite2D.new()
		sprite.z_index = int(layer.get("z", 0))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(sprite)
		var frames := _preview_frames(category, appearance)
		if frames == null:
			sprite.visible = false
			continue
		sprite.sprite_frames = frames
		var animation := StringName("idle_%s" % preview_direction)
		if frames.has_animation(animation):
			sprite.animation = animation
			sprite.frame = 0
	return root


func _preview_frames(category: String, appearance: Dictionary) -> SpriteFrames:
	var trainer_gender := _trainer_gender()
	if category == "body":
		return CharacterAppearanceService.get_skin_tinted_body_frames(
			str(appearance.get("body", "")),
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			str(appearance.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE))
		)
	var part_id := ""
	if category == "eyes":
		part_id = CharacterAppearanceService.get_default_part_id("eyes", trainer_gender)
	elif category == "eyebrows":
		part_id = CharacterAppearanceService.get_eyebrows_for_hair(
			str(appearance.get("hair", "")),
			trainer_gender
		)
	elif category == "hair":
		part_id = CharacterAppearanceService.deserialize_part_id(
			str(appearance.get("hair", ""))
		)
	else:
		part_id = CharacterAppearanceService.deserialize_part_id(
			str(appearance.get(category, ""))
		)
	if part_id == "":
		return null
	if category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			Color.from_string(str(appearance.get("eye_color", "#ffffff")), Color.WHITE)
		)
	if category == "eyebrows" or (
		category == "hair"
		and CharacterAppearanceService.is_tintable_part(category, part_id)
	):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			Color.from_string(str(appearance.get("hair_color", "#ffffff")), Color.WHITE),
			true
		)
	if CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			Color.from_string(
				str(appearance.get(_color_field_for_slot(category), "#ffffff")),
				Color.WHITE
			),
			true
		)
	return CharacterAppearanceService.get_part_frames(category, part_id, trainer_gender)


func _trainer_gender() -> String:
	var player_save := get_node_or_null("/root/PlayerSave")
	return CharacterAppearanceService.normalize_gender(
		str(player_save.get("gender")) if player_save != null else "male"
	)


func _color_field_for_slot(slot: String) -> String:
	return "facial_hair_color" if slot == "facial_hair" else "%s_color" % slot


func _apply_preview_swatch_style(button: Button, color: Color, selected: bool) -> void:
	var border := UI_GOLD if selected else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(color, border, 5, 3 if selected else 1))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), UI_PURPLE, 5, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), UI_GOLD, 5, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _create_component_row(component: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var has_enough := bool(component.get("hasEnough", false))
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color("#0a2019d9") if has_enough else Color("#1e1117d9"),
			Color("#4a9b72aa") if has_enough else Color("#8b485aaa"),
			7,
			1
		)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var state := Label.new()
	state.text = "✓" if has_enough else "○"
	state.custom_minimum_size = Vector2(24, 0)
	state.add_theme_color_override("font_color", UI_GREEN if has_enough else UI_DANGER)
	row.add_child(state)
	var name_label := Label.new()
	name_label.text = _item_name(
		str(component.get("itemId", "")),
		str(component.get("name", component.get("itemId", _t("ui.atelier.component"))))
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(name_label)
	var quantity_label := Label.new()
	quantity_label.text = "%d / %d" % [
		int(component.get("ownedQuantity", 0)),
		int(component.get("requiredQuantity", 1)),
	]
	quantity_label.add_theme_color_override("font_color", UI_GREEN if has_enough else UI_MUTED)
	row.add_child(quantity_label)
	return panel


func _on_create_pressed() -> void:
	if active_mode == "dye":
		await _dye_customized_outfit()
		return
	var outfit := _selected_outfit()
	if outfit.is_empty() or create_in_progress or not bool(outfit.get("canCreate", false)):
		return
	create_in_progress = true
	_refresh_detail()
	var result: Dictionary = await atelier_service.create_bundle(selected_box_item_id)
	create_in_progress = false
	if not bool(result.get("success", false)):
		status_label.text = str(result.get("error", _t("ui.atelier.error.create")))
		status_label.add_theme_color_override("font_color", UI_DANGER)
		_refresh_detail()
		return
	_apply_catalog(result)
	var created_item_id := str(result.get("createdBoxItemId", "outfit-box"))
	status_label.text = _t("ui.atelier.status.created", {
		"item": _item_name(created_item_id, _format_item_name(created_item_id)),
	})
	status_label.add_theme_color_override("font_color", UI_GREEN)
	bundle_created.emit(result)

func _dye_customized_outfit() -> void:
	var changes := _pending_chroma_changes()
	if changes.is_empty() or create_in_progress:
		return
	var fee := _pending_chroma_fee()
	if money < fee:
		return
	create_in_progress = true
	_refresh_dye_detail()
	var result: Dictionary = await atelier_service.dye_chroma_outfit(changes)
	create_in_progress = false
	if not bool(result.get("success", false)):
		status_label.text = str(result.get("error", _t("ui.atelier.error.dye")))
		status_label.add_theme_color_override("font_color", UI_DANGER)
		_refresh_dye_action_state()
		return
	money = maxi(int((result.get("wallet", {}) as Dictionary).get("money", money)), 0)
	money_label.text = _t("ui.atelier.money", {"amount": _format_number(money)})
	var dyed_items: Array = result.get("items", [])
	for dyed_value: Variant in dyed_items:
		var dyed_item := dyed_value as Dictionary
		for index: int in chroma_items.size():
			if str(chroma_items[index].get("itemId", "")) == str(dyed_item.get("itemId", "")):
				chroma_items[index] = dyed_item.duplicate(true)
				break
	for index: int in chroma_items.size():
		var local_item := chroma_items[index]
		local_item["equipped"] = (
			str(selected_wear_item_ids.get(str(local_item.get("slot", "")), ""))
			== str(local_item.get("itemId", ""))
		)
		chroma_items[index] = local_item
	initial_wear_item_ids = selected_wear_item_ids.duplicate(true)
	pending_chroma_colors.clear()
	selected_chroma_color = str(_selected_chroma_item().get("color", selected_chroma_color))
	_render_outfit_list()
	_refresh_dye_detail()
	status_label.text = _t("ui.atelier.status.wear_updated", {
		"amount": _format_number(int(result.get("fee", fee))),
	})
	status_label.add_theme_color_override("font_color", UI_GREEN)
	chroma_dyed.emit(result)


func _on_search_changed(_text: String) -> void:
	_render_outfit_list()


func _selected_outfit() -> Dictionary:
	for outfit: Dictionary in outfits:
		if str(outfit.get("boxItemId", "")) == selected_box_item_id:
			return outfit
	return {}


func _selected_chroma_item() -> Dictionary:
	for item: Dictionary in chroma_items:
		if str(item.get("itemId", "")) == selected_chroma_item_id:
			return item
	return {}


func _selected_wear_items() -> Array[Dictionary]:
	var selected_items: Array[Dictionary] = []
	for item: Dictionary in chroma_items:
		var slot := str(item.get("slot", ""))
		if str(selected_wear_item_ids.get(slot, "")) == str(item.get("itemId", "")):
			selected_items.append(item)
	return selected_items


func _pending_chroma_changes() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for item: Dictionary in _selected_wear_items():
		var item_id := str(item.get("itemId", ""))
		changes.append({
			"itemId": item_id,
			"color": str(pending_chroma_colors.get(item_id, item.get("color", "#ffffff"))),
		})
	return changes


func _pending_color_change_count() -> int:
	var count := 0
	for item: Dictionary in _selected_wear_items():
		var item_id := str(item.get("itemId", ""))
		if (
			bool(item.get("tintable", false))
			and pending_chroma_colors.has(item_id)
			and str(pending_chroma_colors[item_id]).to_lower()
				!= str(item.get("color", "#ffffff")).to_lower()
		):
			count += 1
	return count


func _has_wear_selection_changes() -> bool:
	return selected_wear_item_ids != initial_wear_item_ids


func _pending_chroma_fee() -> int:
	var total := 0
	for change: Dictionary in _pending_chroma_changes():
		var item_id := str(change.get("itemId", ""))
		for item: Dictionary in chroma_items:
			if (
				str(item.get("itemId", "")) == item_id
				and bool(item.get("tintable", false))
				and str(change.get("color", "")).to_lower()
					!= str(item.get("color", "#ffffff")).to_lower()
			):
				total += int(item.get("fee", 0))
				break
	return total


func _outfit_matches_search(outfit: Dictionary, search_text: String) -> bool:
	if search_text == "":
		return true
	var searchable := "%s %s %s" % [
		str(outfit.get("boxItemId", "")),
		_item_name(str(outfit.get("boxItemId", "")), str(outfit.get("name", ""))),
		_outfit_gender_label(outfit),
	]
	for component_value: Variant in outfit.get("components", []):
		if component_value is Dictionary:
			searchable += " %s %s" % [
				str((component_value as Dictionary).get("itemId", "")),
				_item_name(
					str((component_value as Dictionary).get("itemId", "")),
					str((component_value as Dictionary).get("name", ""))
				),
			]
	return searchable.to_lower().contains(search_text)


func _chroma_item_matches_search(item: Dictionary, search_text: String) -> bool:
	if search_text == "":
		return true
	return ("%s %s %s %s" % [
		str(item.get("itemId", "")),
		_item_name(str(item.get("itemId", "")), str(item.get("name", ""))),
		_slot_label(str(item.get("slot", ""))),
		_outfit_gender_label(item),
	]).to_lower().contains(search_text)


func _outfit_icon_gender(outfit: Dictionary) -> String:
	return CharacterAppearanceService.resolve_cosmetic_icon_gender(
		"male",
		outfit.get("genders", [])
	)


func _outfit_gender_label(outfit: Dictionary) -> String:
	var genders: Array = outfit.get("genders", [])
	if genders.size() == 1:
		return _t("ui.atelier.gender.only", {
			"gender": _t("ui.atelier.gender.%s" % str(genders[0]).to_lower()),
		})
	return _t("ui.atelier.gender.all")


func _apply_outfit_card_style(button: Button, selected: bool, ready: bool) -> void:
	var border := UI_GREEN if ready else UI_BORDER
	if selected:
		border = UI_PURPLE
	var background := Color("#17102be8") if selected else UI_INTERACTIVE
	button.add_theme_stylebox_override("normal", _panel_style(background, border, 9, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_PURPLE, 9, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(UI_BG, UI_PURPLE, 9, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_button_style(button: Button, primary: bool) -> void:
	var border := UI_PURPLE if primary else UI_BORDER
	var background := Color("#2a1b45e8") if primary else UI_INTERACTIVE
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#657487"))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _panel_style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_PURPLE, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(UI_BG, UI_PURPLE, 8, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#080f19d9"), Color("#26394a99"), 8, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, 0.75))
	input.add_theme_color_override("caret_color", UI_PURPLE)
	input.add_theme_stylebox_override("normal", _panel_style(UI_INTERACTIVE, UI_BORDER, 8, 1))
	input.add_theme_stylebox_override("focus", _panel_style(Color("#10172af5"), UI_PURPLE, 8, 1))


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits.substr(index, 1)
	return result


func _item_name(item_id: String, fallback: String) -> String:
	var item_localization := get_node_or_null("/root/ItemLocalization")
	if item_localization == null:
		return fallback
	return str(item_localization.call("display_name", item_id, fallback))


func _item_description(item_id: String, fallback: String) -> String:
	var item_localization := get_node_or_null("/root/ItemLocalization")
	if item_localization == null:
		return fallback
	return str(item_localization.call("short_description", item_id, fallback))


func _slot_label(slot: String) -> String:
	var key := "ui.atelier.slot.%s" % slot.strip_edges().to_lower()
	var translated := _t(key)
	return translated if translated != key else slot.replace("_", " ").capitalize()


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	search_input.placeholder_text = _t(
		"ui.atelier.search_wear" if active_mode == "dye" else "ui.atelier.search"
	)
	money_label.text = _t("ui.atelier.money", {"amount": _format_number(money)})
	_render_outfit_list()
	_refresh_detail()


func _format_item_name(item_id: String) -> String:
	var words := item_id.replace("_", "-").split("-")
	for index: int in words.size():
		words[index] = words[index].capitalize()
	return " ".join(words)
