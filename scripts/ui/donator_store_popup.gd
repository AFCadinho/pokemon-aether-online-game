class_name DonatorStorePopup
extends PanelContainer

signal closed
signal get_gems_requested
signal purchase_requested(item_id: String)

const GEM_ICON: Texture2D = preload("res://assets/ui/donator_gem.svg")
const MEMBERSHIP_ICON: Texture2D = preload("res://assets/ui/store_membership.svg")
const STYLE_ICON: Texture2D = preload("res://assets/ui/store_style.svg")
const PROFILE_ICON: Texture2D = preload("res://assets/ui/store_profile.svg")
const CHAT_FLAIR_ICON: Texture2D = preload("res://assets/ui/store_chat_flair.svg")
const MOUNT_ICON: Texture2D = preload("res://assets/ui/store_mount.svg")
const SERVICE_ICON: Texture2D = preload("res://assets/ui/store_service_ticket.svg")
const SURF_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/SURFCHARM.png")
const CUT_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/CUTCHARM.png")
const STRENGTH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/STRENGTHCHARM.png")
const ROCK_SMASH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/ROCKSMASHCHARM.png")
const FLASH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/FLASHCHARM.png")
const DIVE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/DIVECHARM.png")
const DEFOG_CHARM_ICON: Texture2D = preload("res://assets/ui/store_defog_charm.svg")
const RAIN_DANCE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/RAINDANCECHARM.png")
const SNOWSCAPE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/SNOWSCAPECHARM.png")

const UI_SURFACE_BASE := Color("#050b14f7")
const UI_SURFACE_RAISED := Color("#081522f0")
const UI_SURFACE_INTERACTIVE := Color("#0b1d30f2")
const UI_SURFACE_HOVER := Color("#112a44fa")
const UI_BORDER := Color("#355672c0")
const UI_BORDER_SOFT := Color("#2a465db0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED_TEXT := Color("#91a4b7")
const UI_PURPLE := Color("#b28ae8")
const UI_PURPLE_DARK := Color("#6840b1")
const UI_GOLD := Color("#f0cc70")
const UI_CYAN := Color("#60d3ff")
const UI_DANGER := Color("#ef7085")

const CATEGORY_ORDER: Array[String] = [
	"featured",
	"membership",
	"cosmetics",
	"mounts",
	"charms",
	"services",
]
const CATEGORY_LABELS := {
	"featured": "Featured",
	"membership": "Membership",
	"cosmetics": "Cosmetics",
	"mounts": "Mounts",
	"charms": "Charms",
	"services": "Trainer Services",
}
const CATEGORY_DESCRIPTIONS := {
	"featured": "A curated mix of supporter items, style and permanent conveniences.",
	"membership": "Support PokéAether with cosmetic and account-comfort perks. No battle advantages.",
	"cosmetics": "Outfits and profile details that personalize your trainer without affecting gameplay.",
	"mounts": "Travel through the overworld in your own style.",
	"charms": "Use supported field moves without carrying a Pokémon that knows them. Progression and area rules still apply.",
	"services": "Optional changes to your trainer identity and account.",
}
const CATEGORY_PROMISES := {
	"featured": "FAIR SUPPORT",
	"membership": "NO BATTLE POWER",
	"cosmetics": "COSMETIC",
	"mounts": "TRAVEL STYLE",
	"charms": "FIELD CONVENIENCE",
	"services": "TRAINER SERVICE",
}
const CATALOG: Array[Dictionary] = [
	{
		"id": "aether_membership_3",
		"name": "Aether Membership · 3 Days",
		"description": "A short supporter pass with account comforts and no battle advantages.",
		"price": 60,
		"icon": MEMBERSHIP_ICON,
		"categories": ["membership"],
		"badge": "3 DAYS",
	},
	{
		"id": "aether_membership_7",
		"name": "Aether Membership · 7 Days",
		"description": "One week of fair supporter benefits without battle advantages.",
		"price": 130,
		"icon": MEMBERSHIP_ICON,
		"categories": ["membership"],
		"badge": "7 DAYS",
	},
	{
		"id": "aether_membership_14",
		"name": "Aether Membership · 14 Days",
		"description": "Two weeks of fair supporter benefits without battle advantages.",
		"price": 250,
		"icon": MEMBERSHIP_ICON,
		"categories": ["membership"],
		"badge": "14 DAYS",
	},
	{
		"id": "aether_membership_30",
		"name": "Aether Membership · 30 Days",
		"description": "A full month of supporter cosmetics and account comforts without battle advantages.",
		"price": 500,
		"icon": MEMBERSHIP_ICON,
		"categories": ["featured", "membership"],
		"badge": "30 DAYS",
	},
	{
		"id": "aurora_outfit",
		"name": "Aurora Outfit",
		"description": "A complete premium outfit concept for your wardrobe.",
		"price": 300,
		"icon": STYLE_ICON,
		"categories": ["featured", "cosmetics"],
		"badge": "COSMETIC",
	},
	{
		"id": "profile_accent_pack",
		"name": "Profile Accent Pack",
		"description": "Give your Trainer Passport a new visual accent.",
		"price": 80,
		"icon": PROFILE_ICON,
		"categories": ["cosmetics"],
		"badge": "COSMETIC",
	},
	{
		"id": "chat_flair_pack",
		"name": "Chat Flair Pack",
		"description": "Add a cosmetic supporter flair beside your chat name.",
		"price": 100,
		"icon": CHAT_FLAIR_ICON,
		"categories": ["cosmetics"],
		"badge": "COSMETIC",
	},
	{
		"id": "wardrobe_preset_slot",
		"name": "Wardrobe Preset Slot",
		"description": "Save another complete trainer appearance preset.",
		"price": 90,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "nimbus_mount",
		"name": "Nimbus Mount",
		"description": "A cloud-inspired overworld mount for travelling in style.",
		"price": 450,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT",
	},
	{
		"id": "aether_board_mount",
		"name": "Aether Board Mount",
		"description": "A sleek supporter mount with its own overworld look.",
		"price": 450,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT",
	},
	{
		"id": "surf_charm",
		"name": "Surf Charm",
		"description": "Use Surf without an HM Pokémon. Badge and story requirements still apply.",
		"price": 350,
		"icon": SURF_CHARM_ICON,
		"categories": ["featured", "charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "cut_charm",
		"name": "Cut Charm",
		"description": "Use Cut without an HM Pokémon. Badge and story requirements still apply.",
		"price": 250,
		"icon": CUT_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "strength_charm",
		"name": "Strength Charm",
		"description": "Use Strength without an HM Pokémon. Badge and story requirements still apply.",
		"price": 300,
		"icon": STRENGTH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "rock_smash_charm",
		"name": "Rock Smash Charm",
		"description": "Use Rock Smash without an HM Pokémon. Badge and story requirements still apply.",
		"price": 250,
		"icon": ROCK_SMASH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "flash_charm",
		"name": "Flash Charm",
		"description": "Use Flash without a Pokémon that knows it. Progression requirements still apply.",
		"price": 200,
		"icon": FLASH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "dive_charm",
		"name": "Dive Charm",
		"description": "Use Dive without a Pokémon that knows it. Badge and story requirements still apply.",
		"price": 350,
		"icon": DIVE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "defog_charm",
		"name": "Defog Charm",
		"description": "Use Defog without a Pokémon that knows it. Progression requirements still apply.",
		"price": 250,
		"icon": DEFOG_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "rain_dance_charm",
		"name": "Rain Dance Charm",
		"description": "Call rain without carrying a Pokémon that knows Rain Dance. Area rules still apply.",
		"price": 250,
		"icon": RAIN_DANCE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "snowscape_charm",
		"name": "Snowscape Charm",
		"description": "Call snow without carrying a Pokémon that knows Snowscape. Area rules still apply.",
		"price": 250,
		"icon": SNOWSCAPE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "trainer_name_ticket",
		"name": "Trainer Name Change",
		"description": "Change your trainer name once.",
		"price": 150,
		"icon": SERVICE_ICON,
		"categories": ["featured", "services"],
		"badge": "SERVICE",
	},
	{
		"id": "gender_change_ticket",
		"name": "Gender Change",
		"description": "Revisit your trainer's gender selection.",
		"price": 80,
		"icon": SERVICE_ICON,
		"categories": ["services"],
		"badge": "SERVICE",
	},
	{
		"id": "appearance_reset_ticket",
		"name": "Appearance Reset",
		"description": "Revisit your trainer's base appearance choices.",
		"price": 60,
		"icon": SERVICE_ICON,
		"categories": ["services"],
		"badge": "SERVICE",
	},
]

var gem_balance := 0
var active_category := "featured"
var selected_item_id := ""
var category_buttons: Dictionary = {}
var product_buttons: Dictionary = {}
var balance_label: Label
var hero_title_label: Label
var hero_description_label: Label
var hero_promise_label: Label
var product_grid: GridContainer
var selection_title_label: Label
var selection_description_label: Label
var selection_price_label: Label
var purchase_button: Button
var status_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_BASE, Color("#74549ebf"), 14, 1))
	_build_interface()
	set_gem_balance(0)
	_select_category("featured")


func set_gem_balance(amount: int) -> void:
	gem_balance = maxi(amount, 0)
	if balance_label != null:
		balance_label.text = "%s Gems" % _format_number(gem_balance)


func open_store() -> void:
	visible = true
	if status_label != null:
		status_label.text = "Store preview · purchases are not connected yet"


func close_store() -> void:
	visible = false
	closed.emit()


func _build_interface() -> void:
	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_top", 14)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(outer_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	outer_margin.add_child(layout)
	layout.add_child(_create_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)
	body.add_child(_create_category_rail())
	body.add_child(_create_catalog_area())

	layout.add_child(_create_selection_footer())


func _create_header() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, Color("#8065b0aa"), 11, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(46, 46)
	icon_frame.add_theme_stylebox_override("panel", _panel_style(Color("#24163bd9"), Color("#9d71d8cc"), 10, 1))
	row.add_child(icon_frame)

	var icon_center := CenterContainer.new()
	icon_frame.add_child(icon_center)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = GEM_ICON
	icon_center.add_child(icon)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 1)
	row.add_child(heading)

	var title := Label.new()
	title.text = "Aether Store"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Membership, style, convenience and trainer services"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	heading.add_child(subtitle)

	row.add_child(_create_balance_pill())

	var get_gems_button := Button.new()
	get_gems_button.text = "Get Gems"
	get_gems_button.custom_minimum_size = Vector2(96, 36)
	get_gems_button.focus_mode = Control.FOCUS_NONE
	get_gems_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	get_gems_button.pressed.connect(_on_get_gems_pressed)
	_apply_text_button_style(get_gems_button, UI_PURPLE)
	row.add_child(get_gems_button)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(close_store)
	_apply_text_button_style(close_button, UI_BORDER)
	row.add_child(close_button)
	return panel


func _create_balance_pill() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 38)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#180f29e8"), Color("#8f68c5b8"), 10, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(23, 23)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = GEM_ICON
	row.add_child(icon)

	balance_label = Label.new()
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_label.add_theme_font_size_override("font_size", 13)
	balance_label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(balance_label)
	return panel


func _create_category_rail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(176, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 11, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	var browse_label := Label.new()
	browse_label.text = "BROWSE"
	browse_label.add_theme_font_size_override("font_size", 10)
	browse_label.add_theme_color_override("font_color", UI_PURPLE)
	layout.add_child(browse_label)

	for category_id: String in CATEGORY_ORDER:
		var button := Button.new()
		button.text = str(CATEGORY_LABELS.get(category_id, category_id.capitalize()))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_category.bind(category_id))
		layout.add_child(button)
		category_buttons[category_id] = button

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var note := Label.new()
	note.text = "Preview catalog\nNames and prices may change"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(note)
	return panel


func _create_catalog_area() -> Control:
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	layout.add_child(_create_hero_panel())

	var products_label := Label.new()
	products_label.text = "STORE CATALOG"
	products_label.add_theme_font_size_override("font_size", 10)
	products_label.add_theme_color_override("font_color", UI_CYAN)
	layout.add_child(products_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	product_grid = GridContainer.new()
	product_grid.columns = 3
	product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_grid.add_theme_constant_override("h_separation", 9)
	product_grid.add_theme_constant_override("v_separation", 9)
	scroll.add_child(product_grid)
	return layout


func _create_hero_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 94)
	var style := _panel_style(Color("#17102be8"), Color("#8964bfb0"), 12, 1)
	style.shadow_color = Color("#8a5fc344")
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 3)
	row.add_child(heading)

	hero_title_label = Label.new()
	hero_title_label.add_theme_font_size_override("font_size", 19)
	hero_title_label.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(hero_title_label)

	hero_description_label = Label.new()
	hero_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_description_label.add_theme_font_size_override("font_size", 12)
	hero_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	heading.add_child(hero_description_label)

	hero_promise_label = Label.new()
	hero_promise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_promise_label.add_theme_font_size_override("font_size", 10)
	hero_promise_label.add_theme_color_override("font_color", UI_GOLD)
	row.add_child(hero_promise_label)
	return panel


func _create_selection_footer() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 62)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 10, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var selection := VBoxContainer.new()
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection.alignment = BoxContainer.ALIGNMENT_CENTER
	selection.add_theme_constant_override("separation", 1)
	row.add_child(selection)

	selection_title_label = Label.new()
	selection_title_label.text = "Select an item to preview"
	selection_title_label.add_theme_font_size_override("font_size", 13)
	selection_title_label.add_theme_color_override("font_color", UI_TEXT)
	selection.add_child(selection_title_label)

	selection_description_label = Label.new()
	selection_description_label.text = "Checkout will be connected to an authoritative Store service later."
	selection_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selection_description_label.add_theme_font_size_override("font_size", 10)
	selection_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	selection.add_child(selection_description_label)

	selection_price_label = Label.new()
	selection_price_label.text = "—"
	selection_price_label.custom_minimum_size = Vector2(80, 0)
	selection_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selection_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_price_label.add_theme_font_size_override("font_size", 14)
	selection_price_label.add_theme_color_override("font_color", UI_GOLD)
	row.add_child(selection_price_label)

	purchase_button = Button.new()
	purchase_button.text = "Purchase"
	purchase_button.tooltip_text = "Purchases are not connected yet"
	purchase_button.custom_minimum_size = Vector2(112, 36)
	purchase_button.focus_mode = Control.FOCUS_NONE
	purchase_button.disabled = true
	purchase_button.pressed.connect(_on_purchase_pressed)
	_apply_text_button_style(purchase_button, UI_PURPLE)
	row.add_child(purchase_button)

	status_label = Label.new()
	status_label.text = "Store preview · purchases are not connected yet"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_label.tooltip_text = "The catalog, gem balance and checkout still require backend integration."
	row.add_child(status_label)
	return panel


func _select_category(category_id: String) -> void:
	if not CATEGORY_ORDER.has(category_id):
		return
	active_category = category_id
	selected_item_id = ""
	for category_key: String in CATEGORY_ORDER:
		var button := category_buttons.get(category_key) as Button
		if button != null:
			_apply_category_button_style(button, category_key == active_category)
	if hero_title_label != null:
		hero_title_label.text = str(CATEGORY_LABELS.get(active_category, "Store"))
	if hero_description_label != null:
		hero_description_label.text = str(CATEGORY_DESCRIPTIONS.get(active_category, ""))
	if hero_promise_label != null:
		hero_promise_label.text = str(CATEGORY_PROMISES.get(active_category, "FAIR SUPPORT"))
	_reset_selection_footer()
	_render_products()


func _render_products() -> void:
	if product_grid == null:
		return
	for child: Node in product_grid.get_children():
		product_grid.remove_child(child)
		child.queue_free()
	product_buttons.clear()

	for item: Dictionary in CATALOG:
		var categories: Array = item.get("categories", [])
		if not categories.has(active_category):
			continue
		var card := _create_product_card(item)
		product_grid.add_child(card)
		product_buttons[str(item.get("id", ""))] = card


func _create_product_card(item: Dictionary) -> Button:
	var item_id := str(item.get("id", ""))
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 188)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_select_product.bind(item_id))
	_apply_product_card_style(button, false)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = str(item.get("badge", "CONCEPT"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", UI_PURPLE)
	layout.add_child(badge)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.custom_minimum_size = Vector2(0, 58)
	layout.add_child(icon_center)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(58, 58)
	icon_frame.add_theme_stylebox_override("panel", _panel_style(Color("#1d1332d9"), Color("#7655a6aa"), 12, 1))
	icon_center.add_child(icon_frame)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(center)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = item.get("icon") as Texture2D
	center.add_child(icon)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(item.get("name", "Store Item"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(title)

	var description := Label.new()
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.text = str(item.get("description", ""))
	description.custom_minimum_size = Vector2(0, 34)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(description)

	var price := Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.text = "◆  %s" % _format_number(int(item.get("price", 0)))
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", UI_GOLD)
	layout.add_child(price)
	return button


func _select_product(item_id: String) -> void:
	var item := _catalog_item(item_id)
	if item.is_empty():
		return
	selected_item_id = item_id
	for product_id_value: Variant in product_buttons.keys():
		var product_id := str(product_id_value)
		var button := product_buttons.get(product_id) as Button
		if button != null:
			_apply_product_card_style(button, product_id == selected_item_id)

	selection_title_label.text = str(item.get("name", "Store Item"))
	selection_description_label.text = str(item.get("description", ""))
	selection_price_label.text = "◆ %s" % _format_number(int(item.get("price", 0)))
	status_label.text = "Selected for preview · checkout is unavailable"


func _reset_selection_footer() -> void:
	if selection_title_label != null:
		selection_title_label.text = "Select an item to preview"
	if selection_description_label != null:
		selection_description_label.text = "Checkout will be connected to an authoritative Store service later."
	if selection_price_label != null:
		selection_price_label.text = "—"
	if status_label != null:
		status_label.text = "Store preview · purchases are not connected yet"


func _catalog_item(item_id: String) -> Dictionary:
	for item: Dictionary in CATALOG:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _on_get_gems_pressed() -> void:
	status_label.text = "Gem purchases are not connected yet"
	get_gems_requested.emit()


func _on_purchase_pressed() -> void:
	if selected_item_id == "":
		return
	status_label.text = "Checkout is not connected yet"
	purchase_requested.emit(selected_item_id)


func _apply_category_button_style(button: Button, active: bool) -> void:
	var accent := UI_PURPLE if active else UI_BORDER_SOFT
	var background := Color("#24183bd9") if active else UI_SURFACE_INTERACTIVE
	button.add_theme_color_override("font_color", UI_TEXT if active else UI_MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style(background, accent, 8, 1))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, UI_PURPLE, 8, 1))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_BASE, UI_PURPLE, 8, 1))
	button.add_theme_stylebox_override("focus", _button_style(background, accent, 8, 1))


func _apply_product_card_style(button: Button, selected: bool) -> void:
	var accent := UI_PURPLE if selected else UI_BORDER_SOFT
	var background := Color("#17102be8") if selected else UI_SURFACE_RAISED
	button.add_theme_stylebox_override("normal", _button_style(background, accent, 11, 1))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, UI_PURPLE, 11, 1))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_BASE, UI_PURPLE, 11, 1))
	button.add_theme_stylebox_override("focus", _button_style(background, accent, 11, 1))


func _apply_text_button_style(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#657487"))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style(UI_SURFACE_INTERACTIVE, Color(accent.r, accent.g, accent.b, 0.7), 8, 1))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, accent, 8, 1))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_BASE, accent, 8, 1))
	button.add_theme_stylebox_override("focus", _button_style(UI_SURFACE_INTERACTIVE, accent, 8, 1))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#080f19d9"), Color("#26394a99"), 8, 1))


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.anti_aliasing = true
	return style


func _button_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, border_width)
	style.content_margin_left = 10
	style.content_margin_top = 7
	style.content_margin_right = 10
	style.content_margin_bottom = 7
	return style


func _format_number(value: int) -> String:
	var raw := str(maxi(value, 0))
	var grouped := ""
	while raw.length() > 3:
		grouped = ",%s%s" % [raw.right(3), grouped]
		raw = raw.left(raw.length() - 3)
	return "%s%s" % [raw, grouped]
