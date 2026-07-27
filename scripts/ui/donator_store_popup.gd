class_name DonatorStorePopup
extends PanelContainer

signal closed
signal purchase_requested(item_id: String)

const GEM_ICON: Texture2D = preload("res://assets/ui/donator_gem.svg")
const STYLE_ICON: Texture2D = preload("res://assets/ui/store_style.svg")
const PROFILE_ICON: Texture2D = preload("res://assets/ui/store_profile.svg")
const MOUNT_ICON: Texture2D = preload("res://assets/ui/store_mount.svg")
const STORE_DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/store_dropdown_arrow.svg")
const STORE_RADIO_CHECKED: Texture2D = preload("res://assets/ui/store_radio_checked.svg")
const STORE_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/store_radio_unchecked.svg")
const NAME_CHANGE_TICKET_ICON: Texture2D = preload("res://assets/items/icons/NAMECHANGETICKET.png")
const GENDER_CHANCE_TICKET_ICON: Texture2D = preload("res://assets/items/icons/GENDERCHANCETICKET.png")
const AETHER_BLESSING_VOUCHER_3_DAYS_ICON: Texture2D = preload("res://assets/items/icons/AETHERBLESSINGVOUCHER3DAYS.png")
const AETHER_BLESSING_VOUCHER_7_DAYS_ICON: Texture2D = preload("res://assets/items/icons/AETHERBLESSINGVOUCHER7DAYS.png")
const AETHER_BLESSING_VOUCHER_14_DAYS_ICON: Texture2D = preload("res://assets/items/icons/AETHERBLESSINGVOUCHER14DAYS.png")
const AETHER_BLESSING_VOUCHER_30_DAYS_ICON: Texture2D = preload("res://assets/items/icons/AETHERBLESSINGVOUCHER30DAYS.png")
const SURF_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/SURFCHARM.png")
const CUT_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/CUTCHARM.png")
const STRENGTH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/STRENGTHCHARM.png")
const ROCK_SMASH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/ROCKSMASHCHARM.png")
const FLASH_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/FLASHCHARM.png")
const DIVE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/DIVECHARM.png")
const DEFOG_CHARM_ICON: Texture2D = preload("res://assets/ui/store_defog_charm.svg")
const RAIN_DANCE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/RAINDANCECHARM.png")
const SNOWSCAPE_CHARM_ICON: Texture2D = preload("res://assets/items/icons/field_move_charms/SNOWSCAPECHARM.png")
const SQUIRTLE_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/SQUIRTLEGUILDEMBLEMTEMPLATE.png")
const CHARMANDER_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/CHARMANDERGUILDEMBLEMTEMPLATE.png")
const BULBASAUR_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/BULBASAURGUILDEMBLEMTEMPLATE.png")
const VENUSAUR_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/VENUSAURGUILDEMBLEMTEMPLATE.png")
const CHARIZARD_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/CHARIZARDGUILDEMBLEMTEMPLATE.png")
const BLASTOISE_GUILD_EMBLEM_TEMPLATE_ICON: Texture2D = preload("res://assets/items/icons/BLASTOISEGUILDEMBLEMTEMPLATE.png")
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")

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
const PREVIEW_VIEWPORT_SIZE := Vector2i(236, 260)
const PREVIEW_AVATAR_POSITION := Vector2(118, 158)
const PREVIEW_AVATAR_SCALE := Vector2(3.0, 3.0)
const PREVIEW_DIRECTIONS: Array[Dictionary] = [
	{"id": "down", "label": "Front"},
	{"id": "left", "label": "Left"},
	{"id": "right", "label": "Right"},
	{"id": "up", "label": "Back"},
]

const CATEGORY_ORDER: Array[String] = [
	"featured",
	"membership",
	"cosmetics",
	"guilds",
	"mounts",
	"charms",
	"services",
]
const CATEGORY_LABELS := {
	"featured": "Featured",
	"membership": "Blessings",
	"cosmetics": "Cosmetics",
	"guilds": "Guilds",
	"mounts": "Mounts",
	"charms": "Charms",
	"services": "Trainer Services",
}
const CATEGORY_DESCRIPTIONS := {
	"featured": "A curated mix of supporter items, style and permanent conveniences.",
	"membership": "Temporary supporter recognition. No battle advantages.",
	"cosmetics": "Outfits and profile details that personalize your trainer without affecting gameplay.",
	"guilds": "Consumable templates that permanently unlock for your Guild without affecting gameplay.",
	"mounts": "Travel through the overworld in your own style.",
	"charms": "Use supported field moves without carrying a Pokémon that knows them. Progression and area rules still apply.",
	"services": "Optional changes to your trainer identity and account.",
}
const CATEGORY_PROMISES := {
	"featured": "FAIR SUPPORT",
	"membership": "NO BATTLE POWER",
	"cosmetics": "COSMETIC",
	"guilds": "GUILD COSMETIC",
	"mounts": "TRAVEL STYLE",
	"charms": "FIELD CONVENIENCE",
	"services": "TRAINER SERVICE",
}
const COSMETIC_FILTER_GROUP_ORDER: Array[String] = [
	"all",
	"outfits",
	"items",
]
const COSMETIC_FILTER_GROUP_LABELS := {
	"all": "All",
	"outfits": "Outfits",
	"items": "Loose Items",
}
const COSMETIC_ITEM_CATEGORY_ORDER: Array[String] = [
	"body",
	"hair",
	"headgear",
	"face",
	"facegear",
	"top",
	"bottom",
	"shoes",
]
const COSMETIC_SUBCATEGORY_LABELS := {
	"all": "All item types",
	"body": "Body",
	"hair": "Hair",
	"headgear": "Headgear",
	"face": "Face",
	"facegear": "Facegear",
	"top": "Tops",
	"bottom": "Bottoms",
	"shoes": "Shoes",
}
const CATALOG: Array[Dictionary] = [
	{
		"id": "aether-blessing-voucher-3-days",
		"name": "Aether Blessing Voucher · 3 Days",
		"description": "Tradeable voucher. Use it from the Bag to add three days of Aether Blessing.",
		"price": 75,
		"icon": AETHER_BLESSING_VOUCHER_3_DAYS_ICON,
		"categories": ["membership"],
		"badge": "3 DAYS",
	},
	{
		"id": "aether-blessing-voucher-7-days",
		"name": "Aether Blessing Voucher · 7 Days",
		"description": "Tradeable voucher. Use it from the Bag to add one week of Aether Blessing.",
		"price": 150,
		"icon": AETHER_BLESSING_VOUCHER_7_DAYS_ICON,
		"categories": ["membership"],
		"badge": "7 DAYS",
	},
	{
		"id": "aether-blessing-voucher-14-days",
		"name": "Aether Blessing Voucher · 14 Days",
		"description": "Tradeable voucher. Use it from the Bag to add two weeks of Aether Blessing.",
		"price": 275,
		"icon": AETHER_BLESSING_VOUCHER_14_DAYS_ICON,
		"categories": ["membership"],
		"badge": "14 DAYS",
	},
	{
		"id": "aether-blessing-voucher-30-days",
		"name": "Aether Blessing Voucher · 30 Days",
		"description": "Tradeable voucher. Use it from the Bag to add thirty days of Aether Blessing.",
		"price": 500,
		"icon": AETHER_BLESSING_VOUCHER_30_DAYS_ICON,
		"categories": ["featured", "membership"],
		"badge": "30 DAYS",
	},
	{
		"id": "squirtle-guild-emblem-template",
		"name": "Squirtle Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": SQUIRTLE_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "charmander-guild-emblem-template",
		"name": "Charmander Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": CHARMANDER_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "bulbasaur-guild-emblem-template",
		"name": "Bulbasaur Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": BULBASAUR_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "venusaur-guild-emblem-template",
		"name": "Venusaur Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": VENUSAUR_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "charizard-guild-emblem-template",
		"name": "Charizard Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": CHARIZARD_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "blastoise-guild-emblem-template",
		"name": "Blastoise Guild Emblem",
		"description": "Consume it from your Bag to permanently unlock this 32×32 template for your current Guild.",
		"price": 150,
		"icon": BLASTOISE_GUILD_EMBLEM_TEMPLATE_ICON,
		"categories": ["featured", "guilds"],
		"badge": "GUILD UNLOCK",
		"guild_emblem_template": true,
	},
	{
		"id": "adinho-classic-outfit",
		"name": "Adinho Classic Box",
		"description": "Tradeable outfit box. Open it in your Bag to receive all six cosmetic components as separate tradeable items.",
		"price": 500,
		"icon": STYLE_ICON,
		"categories": ["featured", "cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["hair", "facial_hair", "facegear", "top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "hair", "appearance_id": "Adinho_Hair", "tint": "hair_color"},
			{"slot": "facial_hair", "appearance_id": "Adinho_Beard", "tint": "hair_color"},
			{"slot": "facegear", "appearance_id": "Adinho_Glasses"},
			{"slot": "top", "appearance_id": "Adinho_Shirt"},
			{"slot": "bottom", "appearance_id": "Adinho_Trousers"},
			{"slot": "shoes", "appearance_id": "Adinho_Shoes"},
		],
		"genders": ["male"],
		"badge": "6-ITEM BOX",
	},
	{
		"id": "aether-blossom-outfit",
		"name": "Aether Blossom Box",
		"description": "Tradeable female-only outfit box. Open it in your Bag to receive all four cosmetic components as separate tradeable items.",
		"price": 400,
		"icon": STYLE_ICON,
		"categories": ["featured", "cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["hair", "facegear", "top", "shoes"],
		"preview_parts": [
			{"slot": "hair", "appearance_id": "Aether_Blossom_Hair"},
			{"slot": "facegear", "appearance_id": "Aether_Blossom_Earrings"},
			{"slot": "top", "appearance_id": "Aether_Blossom_Dress"},
			{"slot": "shoes", "appearance_id": "Aether_Blossom_Shoes"},
		],
		"genders": ["female"],
		"badge": "4-ITEM BOX",
	},
	{
		"id": "aether-blossom-chroma-hair",
		"name": "Aether Blossom Chroma Hair",
		"description": "A tradeable female-only grayscale hairstyle whose colour can be selected in Character Customization.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Blossom_Hair_Chroma", "tint": "hair_color"},
		"genders": ["female"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-blossom-chroma-earrings",
		"name": "Aether Blossom Chroma Earrings",
		"description": "Tradeable female-only grayscale earrings whose colour can be selected in Character Customization.",
		"price": 100,
		"icon": PROFILE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "facegear",
		"appearance_slots": ["facegear"],
		"preview_part": {"slot": "facegear", "appearance_id": "Aether_Blossom_Earrings_Chroma", "tint": "facegear_color"},
		"genders": ["female"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-blossom-chroma-shoes",
		"name": "Aether Blossom Chroma Shoes",
		"description": "Tradeable female-only grayscale shoes whose colour can be selected in Character Customization.",
		"price": 75,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "shoes",
		"appearance_slots": ["shoes"],
		"preview_part": {"slot": "shoes", "appearance_id": "Aether_Blossom_Shoes_Chroma", "tint": "shoes_color"},
		"genders": ["female"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-hair",
		"name": "Adinho Chroma Hair",
		"description": "Tradeable hair box with matching eyebrows, both using your selected hair colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Adinho_Hair", "tint": "hair_color"},
		"genders": ["male"],
		"badge": "HAIR + BROWS",
	},
	{
		"id": "adinho-chroma-beard",
		"name": "Adinho Chroma Beard",
		"description": "Tradeable grayscale beard box using your selected hair colour.",
		"price": 75,
		"icon": PROFILE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "face",
		"appearance_slots": ["facial_hair"],
		"preview_part": {"slot": "facial_hair", "appearance_id": "Adinho_Beard", "tint": "facial_hair_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-glasses",
		"name": "Adinho Chroma Glasses",
		"description": "A tradeable grayscale edition whose colour can be selected in Character Customization.",
		"price": 100,
		"icon": PROFILE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "facegear",
		"appearance_slots": ["facegear"],
		"preview_part": {"slot": "facegear", "appearance_id": "Adinho_Glasses_Chroma", "tint": "facegear_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-shirt",
		"name": "Adinho Chroma Shirt",
		"description": "A tradeable grayscale edition whose colour can be selected in Character Customization.",
		"price": 150,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "top",
		"cosmetic_subcategories": ["body", "top"],
		"appearance_slots": ["top"],
		"preview_part": {"slot": "top", "appearance_id": "Adinho_Shirt_Chroma", "tint": "top_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-trousers",
		"name": "Adinho Chroma Trousers",
		"description": "A tradeable, colour-customizable edition of the Adinho trousers.",
		"price": 125,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "bottom",
		"appearance_slots": ["bottom"],
		"preview_part": {"slot": "bottom", "appearance_id": "Adinho_Trousers_Chroma", "tint": "bottom_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-shoes",
		"name": "Adinho Chroma Shoes",
		"description": "A tradeable, colour-customizable edition of the Adinho shoes.",
		"price": 75,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "shoes",
		"appearance_slots": ["shoes"],
		"preview_part": {"slot": "shoes", "appearance_id": "Adinho_Shoes_Chroma", "tint": "shoes_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "nimbus_mount",
		"name": "Nimbus Mount",
		"description": "A cloud-inspired overworld mount for travelling in style.",
		"price": 600,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT",
	},
	{
		"id": "aether_board_mount",
		"name": "Aether Board Mount",
		"description": "A sleek supporter mount with its own overworld look.",
		"price": 600,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT",
	},
	{
		"id": "surf-charm",
		"name": "Surf Charm",
		"description": "Use Surf without an HM Pokémon. Badge and story requirements still apply.",
		"price": 350,
		"icon": SURF_CHARM_ICON,
		"categories": ["featured", "charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "cut-charm",
		"name": "Cut Charm",
		"description": "Use Cut without an HM Pokémon. Badge and story requirements still apply.",
		"price": 250,
		"icon": CUT_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "strength-charm",
		"name": "Strength Charm",
		"description": "Use Strength without an HM Pokémon. Badge and story requirements still apply.",
		"price": 300,
		"icon": STRENGTH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "rock-smash-charm",
		"name": "Rock Smash Charm",
		"description": "Use Rock Smash without an HM Pokémon. Badge and story requirements still apply.",
		"price": 250,
		"icon": ROCK_SMASH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "flash-charm",
		"name": "Flash Charm",
		"description": "Use Flash without a Pokémon that knows it. Progression requirements still apply.",
		"price": 200,
		"icon": FLASH_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "dive-charm",
		"name": "Dive Charm",
		"description": "Use Dive without a Pokémon that knows it. Badge and story requirements still apply.",
		"price": 350,
		"icon": DIVE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "defog-charm",
		"name": "Defog Charm",
		"description": "Use Defog without a Pokémon that knows it. Progression requirements still apply.",
		"price": 250,
		"icon": DEFOG_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "rain-dance-charm",
		"name": "Rain Dance Charm",
		"description": "Call rain without carrying a Pokémon that knows Rain Dance. Area rules still apply.",
		"price": 250,
		"icon": RAIN_DANCE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "snowscape-charm",
		"name": "Snowscape Charm",
		"description": "Call snow without carrying a Pokémon that knows Snowscape. Area rules still apply.",
		"price": 250,
		"icon": SNOWSCAPE_CHARM_ICON,
		"categories": ["charms"],
		"badge": "CONVENIENCE",
	},
	{
		"id": "name-change-ticket",
		"name": "Name Change Ticket",
		"description": "Change your trainer name once.",
		"price": 250,
		"icon": NAME_CHANGE_TICKET_ICON,
		"categories": ["featured", "services"],
		"badge": "SERVICE",
	},
	{
		"id": "gender-chance-ticket",
		"name": "Gender Chance Ticket",
		"description": "Change your trainer's gender once.",
		"price": 100,
		"icon": GENDER_CHANCE_TICKET_ICON,
		"categories": ["services"],
		"badge": "SERVICE",
	},
]

var gem_balance := 0
var authoritative_gem_prices: Dictionary = {}
var authoritative_item_genders: Dictionary = {}
var store_catalog_loaded := false
var store_catalog_loading := false
var purchase_in_progress := false
var trainer_gender := "male"
var trainer_appearance: Dictionary = {}
var active_category := "featured"
var active_cosmetic_filter_group := "all"
var active_cosmetic_subcategory := "all"
var selected_item_id := ""
var category_buttons: Dictionary = {}
var cosmetic_filter_group_buttons: Dictionary = {}
var cosmetic_item_category_control: HBoxContainer
var cosmetic_item_category_select: OptionButton
var product_buttons: Dictionary = {}
var catalog_search_input: LineEdit
var catalog_search_text := ""
var balance_label: Label
var hero_title_label: Label
var hero_description_label: Label
var hero_promise_label: Label
var cosmetic_subcategory_bar: PanelContainer
var product_grid: GridContainer
var selection_title_label: Label
var selection_description_label: Label
var selection_price_label: Label
var purchase_button: Button
var status_label: Label
var character_preview_viewport: SubViewport
var character_preview_eyebrow_label: Label
var character_preview_direction_row: HBoxContainer
var character_preview_title_label: Label
var character_preview_note_label: Label
var character_preview_palette: Control
var character_preview_color_label: Label
var character_preview_swatch_grid: GridContainer
var character_preview_color_picker: ColorPickerButton
var character_preview_hex_input: LineEdit
var character_preview_palette_tint_key := ""
var character_preview_direction := "down"
var character_preview_direction_buttons: Dictionary = {}
var character_preview_color_buttons: Dictionary = {}
var character_preview_colors: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_BASE, Color("#74549ebf"), 14, 1))
	if trainer_appearance.is_empty():
		trainer_appearance = CharacterAppearanceService.get_default_appearance(trainer_gender)
	_build_interface()
	_sync_character_preview_colors()
	set_gem_balance(gem_balance)
	_select_category("featured")


func set_gem_balance(amount: int) -> void:
	gem_balance = maxi(amount, 0)
	if balance_label != null:
		balance_label.text = "%s Aether Gems" % _format_number(gem_balance)
	_refresh_purchase_state()


func set_store_loading(loading: bool) -> void:
	store_catalog_loading = loading
	if loading and status_label != null:
		status_label.text = "Loading Aether Gem balance and available items..."
	_refresh_purchase_state()


func apply_store_state(wallet: Dictionary, store: Dictionary) -> void:
	set_gem_balance(int(wallet.get("gems", gem_balance)))
	authoritative_gem_prices.clear()
	authoritative_item_genders.clear()
	var items_value: Variant = store.get("items", [])
	if items_value is Array:
		for item_value: Variant in items_value as Array:
			if not item_value is Dictionary:
				continue
			var offer := item_value as Dictionary
			var item_id := str(offer.get("itemId", "")).strip_edges()
			var costs_value: Variant = offer.get("costs", [])
			if item_id == "":
				continue
			var normalized_genders: Array[String] = []
			var genders_value: Variant = offer.get("genders", [])
			if genders_value is Array:
				for gender_value: Variant in genders_value as Array:
					var gender := str(gender_value).strip_edges().to_lower()
					if ["male", "female"].has(gender) and not normalized_genders.has(gender):
						normalized_genders.append(gender)
			authoritative_item_genders[item_id] = normalized_genders
			if not costs_value is Array:
				continue
			for cost_value: Variant in costs_value as Array:
				if not cost_value is Dictionary:
					continue
				var cost := cost_value as Dictionary
				if str(cost.get("currency", "")).strip_edges().to_lower() == "gems":
					authoritative_gem_prices[item_id] = maxi(int(cost.get("amount", 0)), 0)
					break
	store_catalog_loaded = true
	store_catalog_loading = false
	if selected_item_id != "" and not _item_matches_trainer_gender(_catalog_item(selected_item_id)):
		selected_item_id = ""
		_reset_selection_footer()
	_render_products()
	_refresh_purchase_state()


func show_store_error(message: String) -> void:
	store_catalog_loading = false
	purchase_in_progress = false
	if status_label != null:
		status_label.text = message
	_refresh_purchase_state(false)


func set_purchase_in_progress(active: bool) -> void:
	purchase_in_progress = active
	if active and status_label != null:
		status_label.text = "Completing secure Aether Gem purchase..."
	_refresh_purchase_state()


func show_purchase_success(item_name: String) -> void:
	purchase_in_progress = false
	if status_label != null:
		status_label.text = "%s was added to your Bag" % item_name
	_refresh_purchase_state(false)


func set_trainer_gender(value: String) -> void:
	trainer_gender = "female" if value.strip_edges().to_lower() == "female" else "male"
	if selected_item_id != "" and not _item_matches_trainer_gender(_catalog_item(selected_item_id)):
		selected_item_id = ""
		_reset_selection_footer()
	_render_products()
	_refresh_character_preview()


func set_trainer_appearance(value: Dictionary) -> void:
	trainer_appearance = value.duplicate(true)
	trainer_gender = (
		"female"
		if str(trainer_appearance.get("gender", trainer_gender)).strip_edges().to_lower() == "female"
		else "male"
	)
	if selected_item_id != "" and not _item_matches_trainer_gender(_catalog_item(selected_item_id)):
		selected_item_id = ""
		_reset_selection_footer()
	_sync_character_preview_colors()
	_render_products()
	_refresh_character_preview()


func open_store() -> void:
	_sync_character_preview_colors()
	_refresh_character_preview()
	visible = true
	if status_label != null:
		status_label.text = "Loading Aether Gem balance and available items..."


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
	body.add_child(_create_character_preview_panel())

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
	title.text = "Aether Gift Store"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Blessings, style, convenience and trainer services"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	heading.add_child(subtitle)

	row.add_child(_create_balance_pill())

	var add_gems_button := Button.new()
	add_gems_button.name = "AddGemsButton"
	add_gems_button.text = "+ Add Gems"
	add_gems_button.tooltip_text = "Aether Gem top-ups are coming later"
	add_gems_button.custom_minimum_size = Vector2(96, 36)
	add_gems_button.focus_mode = Control.FOCUS_NONE
	add_gems_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_gems_button.pressed.connect(_on_add_gems_pressed)
	_apply_text_button_style(add_gems_button, UI_GOLD)
	row.add_child(add_gems_button)

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


func _on_add_gems_pressed() -> void:
	var message := "Adding Aether Gems is not implemented yet."
	if status_label != null:
		status_label.text = message
	if selection_description_label != null:
		selection_description_label.text = message


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
	note.text = "Server-verified catalog\nUnavailable items are clearly marked"
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
	layout.add_child(_create_cosmetic_subcategory_bar())

	var catalog_header := HBoxContainer.new()
	catalog_header.add_theme_constant_override("separation", 8)
	layout.add_child(catalog_header)

	var products_label := Label.new()
	products_label.text = "STORE CATALOG"
	products_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	products_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	products_label.add_theme_font_size_override("font_size", 10)
	products_label.add_theme_color_override("font_color", UI_CYAN)
	catalog_header.add_child(products_label)

	catalog_search_input = LineEdit.new()
	catalog_search_input.name = "CatalogSearchInput"
	catalog_search_input.placeholder_text = "Search Store..."
	catalog_search_input.clear_button_enabled = true
	catalog_search_input.custom_minimum_size = Vector2(210, 34)
	catalog_search_input.tooltip_text = "Search the active Store category"
	catalog_search_input.text_changed.connect(_on_catalog_search_changed)
	_apply_line_edit_style(catalog_search_input)
	catalog_header.add_child(catalog_search_input)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	product_grid = GridContainer.new()
	product_grid.columns = 2
	product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_grid.add_theme_constant_override("h_separation", 9)
	product_grid.add_theme_constant_override("v_separation", 9)
	scroll.add_child(product_grid)
	return layout


func _create_cosmetic_subcategory_bar() -> PanelContainer:
	cosmetic_subcategory_bar = PanelContainer.new()
	cosmetic_subcategory_bar.name = "CosmeticSubcategoryBar"
	cosmetic_subcategory_bar.visible = false
	cosmetic_subcategory_bar.custom_minimum_size = Vector2(0, 42)
	cosmetic_subcategory_bar.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#0a1422e8"), Color("#493b66a8"), 9, 1)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	cosmetic_subcategory_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "CosmeticFilterControls"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	for group_id: String in COSMETIC_FILTER_GROUP_ORDER:
		var button := Button.new()
		button.name = "CosmeticFilter_%s" % group_id
		button.text = str(COSMETIC_FILTER_GROUP_LABELS.get(group_id, group_id.capitalize()))
		button.custom_minimum_size = Vector2(70, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_cosmetic_filter_group.bind(group_id))
		row.add_child(button)
		cosmetic_filter_group_buttons[group_id] = button

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	cosmetic_item_category_control = HBoxContainer.new()
	cosmetic_item_category_control.name = "CosmeticItemCategoryControl"
	cosmetic_item_category_control.add_theme_constant_override("separation", 6)
	row.add_child(cosmetic_item_category_control)

	var category_label := Label.new()
	category_label.text = "ITEM CATEGORY"
	category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", 9)
	category_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	cosmetic_item_category_control.add_child(category_label)

	cosmetic_item_category_select = OptionButton.new()
	cosmetic_item_category_select.name = "CosmeticItemCategorySelect"
	cosmetic_item_category_select.custom_minimum_size = Vector2(150, 30)
	cosmetic_item_category_select.add_item(str(COSMETIC_SUBCATEGORY_LABELS.get("all", "All item types")))
	cosmetic_item_category_select.set_item_metadata(0, "all")
	for subcategory_id: String in COSMETIC_ITEM_CATEGORY_ORDER:
		cosmetic_item_category_select.add_item(
			str(COSMETIC_SUBCATEGORY_LABELS.get(subcategory_id, subcategory_id.capitalize()))
		)
		cosmetic_item_category_select.set_item_metadata(
			cosmetic_item_category_select.item_count - 1,
			subcategory_id
		)
	cosmetic_item_category_select.item_selected.connect(_on_cosmetic_item_category_selected)
	_apply_cosmetic_item_category_style(cosmetic_item_category_select)
	cosmetic_item_category_control.add_child(cosmetic_item_category_select)

	return cosmetic_subcategory_bar


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


func _create_character_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CharacterPreviewPanel"
	panel.custom_minimum_size = Vector2(260, 0)
	var style := _panel_style(Color("#0b1524f2"), Color("#694f8eb8"), 11, 1)
	style.shadow_color = Color("#00000055")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	character_preview_eyebrow_label = Label.new()
	character_preview_eyebrow_label.text = "ON YOUR TRAINER"
	character_preview_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_eyebrow_label.add_theme_font_size_override("font_size", 10)
	character_preview_eyebrow_label.add_theme_color_override("font_color", UI_CYAN)
	layout.add_child(character_preview_eyebrow_label)

	character_preview_title_label = Label.new()
	character_preview_title_label.text = "Select a cosmetic"
	character_preview_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_preview_title_label.add_theme_font_size_override("font_size", 14)
	character_preview_title_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(character_preview_title_label)

	var viewport_frame := PanelContainer.new()
	viewport_frame.custom_minimum_size = Vector2(PREVIEW_VIEWPORT_SIZE)
	viewport_frame.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#07111de8"), Color("#324d65aa"), 10, 1)
	)
	layout.add_child(viewport_frame)

	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "CharacterPreviewViewportContainer"
	viewport_container.custom_minimum_size = Vector2(PREVIEW_VIEWPORT_SIZE)
	viewport_container.stretch = false
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_frame.add_child(viewport_container)

	character_preview_viewport = SubViewport.new()
	character_preview_viewport.name = "CharacterPreviewViewport"
	character_preview_viewport.transparent_bg = true
	character_preview_viewport.size = PREVIEW_VIEWPORT_SIZE
	character_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(character_preview_viewport)

	character_preview_direction_row = HBoxContainer.new()
	character_preview_direction_row.alignment = BoxContainer.ALIGNMENT_CENTER
	character_preview_direction_row.add_theme_constant_override("separation", 3)
	layout.add_child(character_preview_direction_row)
	for direction: Dictionary in PREVIEW_DIRECTIONS:
		var direction_id := str(direction.get("id", "down"))
		var direction_button := Button.new()
		direction_button.text = str(direction.get("label", direction_id.capitalize()))
		direction_button.custom_minimum_size = Vector2(51, 27)
		direction_button.focus_mode = Control.FOCUS_NONE
		direction_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		direction_button.pressed.connect(_select_character_preview_direction.bind(direction_id))
		character_preview_direction_row.add_child(direction_button)
		character_preview_direction_buttons[direction_id] = direction_button

	character_preview_palette = VBoxContainer.new()
	character_preview_palette.visible = false
	character_preview_palette.add_theme_constant_override("separation", 4)
	layout.add_child(character_preview_palette)

	character_preview_color_label = Label.new()
	character_preview_color_label.text = "PREVIEW COLOR"
	character_preview_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_color_label.add_theme_font_size_override("font_size", 9)
	character_preview_color_label.add_theme_color_override("font_color", UI_PURPLE)
	character_preview_palette.add_child(character_preview_color_label)

	character_preview_swatch_grid = GridContainer.new()
	character_preview_swatch_grid.columns = 8
	character_preview_swatch_grid.add_theme_constant_override("h_separation", 3)
	character_preview_swatch_grid.add_theme_constant_override("v_separation", 3)
	character_preview_palette.add_child(character_preview_swatch_grid)

	var custom_color_row := HBoxContainer.new()
	custom_color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_color_row.add_theme_constant_override("separation", 6)
	character_preview_palette.add_child(custom_color_row)

	var custom_color_label := Label.new()
	custom_color_label.text = "Custom"
	custom_color_label.add_theme_font_size_override("font_size", 10)
	custom_color_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	custom_color_row.add_child(custom_color_label)

	character_preview_color_picker = ColorPickerButton.new()
	character_preview_color_picker.tooltip_text = "Choose a custom color"
	character_preview_color_picker.custom_minimum_size = Vector2(54, 24)
	character_preview_color_picker.focus_mode = Control.FOCUS_NONE
	character_preview_color_picker.color_changed.connect(_select_character_preview_custom_color)
	custom_color_row.add_child(character_preview_color_picker)

	character_preview_hex_input = LineEdit.new()
	character_preview_hex_input.name = "CharacterPreviewHexInput"
	character_preview_hex_input.placeholder_text = "#RRGGBB"
	character_preview_hex_input.max_length = 7
	character_preview_hex_input.custom_minimum_size = Vector2(88, 24)
	character_preview_hex_input.tooltip_text = "Enter a hex colour code, for example #7a46c5"
	character_preview_hex_input.text_changed.connect(_on_character_preview_hex_text_changed)
	character_preview_hex_input.text_submitted.connect(_commit_character_preview_hex_color)
	character_preview_hex_input.focus_exited.connect(_commit_character_preview_hex_color)
	_apply_line_edit_style(character_preview_hex_input)
	custom_color_row.add_child(character_preview_hex_input)

	character_preview_note_label = Label.new()
	character_preview_note_label.text = "Preview only · your equipped outfit is unchanged"
	character_preview_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_preview_note_label.add_theme_font_size_override("font_size", 10)
	character_preview_note_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(character_preview_note_label)

	_refresh_character_preview_direction_buttons()
	_refresh_character_preview()
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
	selection_description_label.text = "Select an available item to purchase it safely with Aether Gems."
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
	purchase_button.tooltip_text = "Select an available Store item"
	purchase_button.custom_minimum_size = Vector2(112, 36)
	purchase_button.focus_mode = Control.FOCUS_NONE
	purchase_button.disabled = true
	purchase_button.pressed.connect(_on_purchase_pressed)
	_apply_text_button_style(purchase_button, UI_PURPLE)
	row.add_child(purchase_button)

	status_label = Label.new()
	status_label.text = "Loading Aether Gem balance and available items..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	status_label.tooltip_text = "Your Aether Gem balance and purchases are kept safe."
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
	_refresh_cosmetic_subcategory_bar()
	_reset_selection_footer()
	_render_products()


func _select_cosmetic_subcategory(subcategory_id: String) -> void:
	if subcategory_id == "all":
		_select_cosmetic_filter_group("all")
		return
	if subcategory_id == "outfits":
		_select_cosmetic_filter_group("outfits")
		return
	if not COSMETIC_ITEM_CATEGORY_ORDER.has(subcategory_id):
		return
	active_cosmetic_filter_group = "items"
	active_cosmetic_subcategory = subcategory_id
	selected_item_id = ""
	_refresh_cosmetic_subcategory_bar()
	_reset_selection_footer()
	_render_products()


func _select_cosmetic_filter_group(group_id: String) -> void:
	if not COSMETIC_FILTER_GROUP_ORDER.has(group_id):
		return
	active_cosmetic_filter_group = group_id
	if group_id == "all":
		active_cosmetic_subcategory = "all"
	elif group_id == "outfits":
		active_cosmetic_subcategory = "outfits"
	elif not COSMETIC_ITEM_CATEGORY_ORDER.has(active_cosmetic_subcategory):
		active_cosmetic_subcategory = "all"
	selected_item_id = ""
	_refresh_cosmetic_subcategory_bar()
	_reset_selection_footer()
	_render_products()


func _on_cosmetic_item_category_selected(index: int) -> void:
	if cosmetic_item_category_select == null or index < 0:
		return
	var subcategory_id := str(cosmetic_item_category_select.get_item_metadata(index))
	if subcategory_id != "all" and not COSMETIC_ITEM_CATEGORY_ORDER.has(subcategory_id):
		return
	active_cosmetic_filter_group = "items"
	active_cosmetic_subcategory = subcategory_id
	selected_item_id = ""
	_refresh_cosmetic_subcategory_bar()
	_reset_selection_footer()
	_render_products()


func _refresh_cosmetic_subcategory_bar() -> void:
	if cosmetic_subcategory_bar == null:
		return
	cosmetic_subcategory_bar.visible = active_category == "cosmetics"
	for group_id: String in COSMETIC_FILTER_GROUP_ORDER:
		var button := cosmetic_filter_group_buttons.get(group_id) as Button
		if button != null:
			_apply_cosmetic_subcategory_style(button, group_id == active_cosmetic_filter_group)
	if cosmetic_item_category_control != null:
		cosmetic_item_category_control.visible = active_cosmetic_filter_group == "items"
	if cosmetic_item_category_select != null and active_cosmetic_filter_group == "items":
		var selected_index := 0
		for index: int in range(cosmetic_item_category_select.item_count):
			if str(cosmetic_item_category_select.get_item_metadata(index)) == active_cosmetic_subcategory:
				selected_index = index
				break
		cosmetic_item_category_select.select(selected_index)


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
		if not _item_matches_trainer_gender(item):
			continue
		if active_category == "cosmetics" and not _matches_cosmetic_subcategory(item):
			continue
		if not _item_matches_catalog_search(item):
			continue
		var card := _create_product_card(item)
		product_grid.add_child(card)
		product_buttons[str(item.get("id", ""))] = card


func _on_catalog_search_changed(search_text: String) -> void:
	catalog_search_text = search_text.strip_edges().to_lower()
	if selected_item_id != "" and not _item_matches_catalog_search(_catalog_item(selected_item_id)):
		selected_item_id = ""
		_reset_selection_footer()
		_refresh_character_preview()
	_render_products()


func _item_matches_catalog_search(item: Dictionary) -> bool:
	if catalog_search_text == "":
		return true
	var searchable_parts := PackedStringArray([
		str(item.get("id", "")),
		str(item.get("name", "")),
		str(item.get("description", "")),
		str(item.get("badge", "")),
		str(item.get("cosmetic_subcategory", "")),
	])
	var searchable_text := " ".join(searchable_parts).to_lower()
	return searchable_text.contains(catalog_search_text)


func _matches_cosmetic_subcategory(item: Dictionary) -> bool:
	if active_cosmetic_filter_group == "all":
		return true
	if active_cosmetic_filter_group == "outfits":
		return _item_has_cosmetic_subcategory(item, "outfits")
	if _item_has_cosmetic_subcategory(item, "outfits"):
		return false
	if active_cosmetic_subcategory == "all":
		return true
	return _item_has_cosmetic_subcategory(item, active_cosmetic_subcategory)


func _item_has_cosmetic_subcategory(item: Dictionary, subcategory_id: String) -> bool:
	var subcategories_value: Variant = item.get("cosmetic_subcategories", [])
	if subcategories_value is Array:
		for subcategory_value: Variant in subcategories_value as Array:
			if str(subcategory_value) == subcategory_id:
				return true
	return str(item.get("cosmetic_subcategory", "")) == subcategory_id


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
	var badge_text := str(item.get("badge", "CONCEPT"))
	var compatibility_badge := _item_gender_badge(item)
	badge.text = (
		"%s · %s" % [compatibility_badge, badge_text]
		if compatibility_badge != ""
		else badge_text
	)
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
	var cosmetic_icon := CharacterAppearanceService.get_cosmetic_item_icon(item_id, trainer_gender)
	icon.texture = cosmetic_icon if cosmetic_icon != null else item.get("icon") as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var authoritative_price := _gem_price(item_id)
	price.text = (
		"COMING LATER"
		if store_catalog_loaded and authoritative_price < 0
		else "◆  %s" % _format_number(authoritative_price if authoritative_price >= 0 else int(item.get("price", 0)))
	)
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
	var description := str(item.get("description", ""))
	var compatibility_note := _item_gender_compatibility_note(item)
	selection_description_label.text = (
		"%s · %s" % [description, compatibility_note]
		if compatibility_note != ""
		else description
	)
	var authoritative_price := _gem_price(item_id)
	selection_price_label.text = (
		"COMING LATER"
		if store_catalog_loaded and authoritative_price < 0
		else "◆ %s" % _format_number(authoritative_price if authoritative_price >= 0 else int(item.get("price", 0)))
	)
	_refresh_purchase_state()
	_refresh_character_preview()


func _reset_selection_footer() -> void:
	if selection_title_label != null:
		selection_title_label.text = "Select an item to preview"
	if selection_description_label != null:
		selection_description_label.text = "Select an available item to purchase it safely with Aether Gems."
	if selection_price_label != null:
		selection_price_label.text = "—"
	if status_label != null:
		status_label.text = "Select an item to preview"
	_refresh_purchase_state()
	_refresh_character_preview()


func _sync_character_preview_colors() -> void:
	character_preview_colors = {
		"hair_color": str(trainer_appearance.get("hair_color", CharacterAppearanceService.get_default_hair_color(trainer_gender))),
		"facial_hair_color": str(trainer_appearance.get("facial_hair_color", "#ffffff")),
		"facegear_color": str(trainer_appearance.get("facegear_color", "#ffffff")),
		"top_color": str(trainer_appearance.get("top_color", "#ffffff")),
		"bottom_color": str(trainer_appearance.get("bottom_color", "#ffffff")),
		"shoes_color": str(trainer_appearance.get("shoes_color", "#ffffff")),
	}


func _current_character_preview_appearance() -> Dictionary:
	var body_id := str(trainer_appearance.get("body", ""))
	if not CharacterAppearanceService.body_supports_layered_parts(body_id, trainer_gender):
		body_id = (
			CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID
			if trainer_gender == "female"
			else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
		)
	body_id = CharacterAppearanceService.resolve_body_model_id(body_id, trainer_gender)
	var appearance := {
		"body": body_id,
		"hair": CharacterAppearanceService.deserialize_part_id(str(trainer_appearance.get("hair", CharacterAppearanceService.get_default_part_id("hair", trainer_gender)))),
		"headgear": "",
		"facial_hair": "",
		"facegear": "",
		"top": CharacterAppearanceService.get_default_part_id("top", trainer_gender),
		"bottom": CharacterAppearanceService.get_default_part_id("bottom", trainer_gender),
		"shoes": CharacterAppearanceService.get_default_part_id("shoes", trainer_gender),
		"hair_color": str(character_preview_colors.get("hair_color", CharacterAppearanceService.get_default_hair_color(trainer_gender))),
		"facial_hair_color": str(character_preview_colors.get("facial_hair_color", "#ffffff")),
		"skin_tone": CharacterAppearanceService.resolve_skin_tone(
			str(trainer_appearance.get("body", body_id)),
			str(trainer_appearance.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE)),
			trainer_gender
		),
		"eye_color": str(trainer_appearance.get("eye_color", CharacterAppearanceService.get_default_eye_color(trainer_gender))),
		"facegear_color": str(character_preview_colors.get("facegear_color", "#ffffff")),
		"top_color": str(character_preview_colors.get("top_color", "#ffffff")),
		"bottom_color": str(character_preview_colors.get("bottom_color", "#ffffff")),
		"shoes_color": str(character_preview_colors.get("shoes_color", "#ffffff")),
	}
	var item := _catalog_item(selected_item_id)
	for preview_part: Dictionary in _preview_parts_for_item(item):
		var slot := CharacterAppearanceService.normalize_part_category(str(preview_part.get("slot", "")))
		var appearance_id := str(preview_part.get("appearance_id", "")).strip_edges()
		if slot != "" and appearance_id != "":
			appearance[slot] = appearance_id
			var tint_key := str(preview_part.get("tint", "")).strip_edges()
			var slot_color_key := "%s_color" % slot
			if tint_key != "" and appearance.has(slot_color_key):
				appearance[slot_color_key] = str(
					character_preview_colors.get(tint_key, appearance.get(slot_color_key, "#ffffff"))
				)
	return appearance


func _refresh_character_preview() -> void:
	if character_preview_viewport == null:
		return
	for child: Node in character_preview_viewport.get_children():
		character_preview_viewport.remove_child(child)
		child.queue_free()

	var item := _catalog_item(selected_item_id)
	if bool(item.get("guild_emblem_template", false)):
		var emblem_sprite := Sprite2D.new()
		emblem_sprite.name = "GuildEmblemStorePreview"
		emblem_sprite.texture = item.get("icon") as Texture2D
		emblem_sprite.position = Vector2(PREVIEW_VIEWPORT_SIZE) * 0.5
		emblem_sprite.scale = Vector2(6.0, 6.0)
		emblem_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		character_preview_viewport.add_child(emblem_sprite)
		character_preview_eyebrow_label.text = "FOR YOUR GUILD"
		character_preview_title_label.text = str(item.get("name", "Guild Emblem"))
		character_preview_note_label.text = "Permanent template · apply it from your Bag"
		character_preview_direction_row.visible = false
		character_preview_palette.visible = false
		return

	character_preview_eyebrow_label.text = "ON YOUR TRAINER"
	character_preview_direction_row.visible = true
	var appearance := _current_character_preview_appearance()
	var preview_visual := _create_character_preview_visual(appearance)
	if preview_visual != null:
		character_preview_viewport.add_child(preview_visual)
		preview_visual.position = PREVIEW_AVATAR_POSITION
		preview_visual.scale = PREVIEW_AVATAR_SCALE
		_disable_character_preview_processing(preview_visual)
		_set_character_preview_direction(preview_visual)

	var preview_parts := _preview_parts_for_item(item)
	var tint_key := ""
	for preview_part: Dictionary in preview_parts:
		tint_key = str(preview_part.get("tint", "")).strip_edges()
		if tint_key != "":
			break
	if character_preview_title_label != null:
		character_preview_title_label.text = (
			str(item.get("name", "Select a cosmetic"))
			if not preview_parts.is_empty()
			else "Select a cosmetic"
		)
	if character_preview_note_label != null:
		character_preview_note_label.text = (
			"Preview only · your equipped outfit is unchanged"
			if not preview_parts.is_empty()
			else "Choose a cosmetic to try it on"
		)
	if character_preview_palette != null:
		character_preview_palette.visible = tint_key != ""
	if character_preview_color_label != null and tint_key != "":
		character_preview_color_label.text = (
			"HAIR & EYEBROW COLOR"
			if tint_key == "hair_color"
			else "PREVIEW COLOR"
		)
	_rebuild_character_preview_color_buttons(tint_key)
	_refresh_character_preview_color_buttons(tint_key)


func _create_character_preview_visual(appearance: Dictionary) -> Node2D:
	var visual_root := Node2D.new()
	for layer: Dictionary in [
		{"name": "BodySprite", "z": 0},
		{"name": "BottomSprite", "z": 1},
		{"name": "ShoesSprite", "z": 2},
		{"name": "TopSprite", "z": 3},
		{"name": "EyebrowsSprite", "z": 4},
		{"name": "EyesSprite", "z": 5},
		{"name": "HairSprite", "z": 6},
		{"name": "FacialHairSprite", "z": 7},
		{"name": "FaceGearSprite", "z": 8},
		{"name": "HeadgearSprite", "z": 9},
	]:
		var sprite := AnimatedSprite2D.new()
		sprite.name = str(layer.get("name", "AppearanceSprite"))
		sprite.z_index = int(layer.get("z", 0))
		visual_root.add_child(sprite)

	_apply_character_preview_appearance(visual_root, appearance)
	return visual_root


func _apply_character_preview_appearance(node: Node, appearance: Dictionary) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames := CharacterAppearanceService.get_skin_tinted_body_frames(
				str(appearance.get("body", "")),
				trainer_gender,
				CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
				str(appearance.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE))
			)
			if body_frames != null:
				sprite.sprite_frames = body_frames
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.modulate = Color.WHITE
		else:
			_apply_character_preview_part(sprite, appearance)

	for child: Node in node.get_children():
		_apply_character_preview_appearance(child, appearance)


func _apply_character_preview_part(sprite: AnimatedSprite2D, appearance: Dictionary) -> void:
	var category := _character_preview_category_for_sprite(sprite.name)
	if category == "":
		return
	if not CharacterAppearanceService.body_supports_layered_parts(
		str(appearance.get("body", "")),
		trainer_gender
	):
		sprite.visible = false
		sprite.sprite_frames = null
		return

	var part_id := _character_preview_part_id(category, appearance)
	if part_id == "":
		sprite.visible = false
		sprite.sprite_frames = null
		return

	var frames := _character_preview_part_frames(category, part_id, appearance)
	if frames == null:
		sprite.visible = false
		sprite.sprite_frames = null
		return
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = null
	sprite.modulate = Color.WHITE
	sprite.visible = true


func _character_preview_category_for_sprite(sprite_name: String) -> String:
	match sprite_name:
		"HairSprite":
			return "hair"
		"HeadgearSprite":
			return "headgear"
		"FacialHairSprite":
			return "facial_hair"
		"FaceGearSprite":
			return "facegear"
		"TopSprite":
			return "top"
		"BottomSprite":
			return "bottom"
		"ShoesSprite":
			return "shoes"
		"EyesSprite":
			return "eyes"
		"EyebrowsSprite":
			return "eyebrows"
		_:
			return ""


func _character_preview_part_id(category: String, appearance: Dictionary) -> String:
	match CharacterAppearanceService.normalize_part_category(category):
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", trainer_gender)
		"eyebrows":
			return CharacterAppearanceService.get_eyebrows_for_hair(
				str(appearance.get("hair", "")),
				trainer_gender
			)
		_:
			return str(appearance.get(category, "")).strip_edges()


func _character_preview_part_frames(
	category: String,
	part_id: String,
	appearance: Dictionary
) -> SpriteFrames:
	var normalized_category := CharacterAppearanceService.normalize_part_category(category)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("eye_color", "#ffffff")), Color.WHITE)
		)
	if normalized_category == "eyebrows" or (
		normalized_category == "hair"
		and CharacterAppearanceService.is_tintable_part(category, part_id)
	):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("hair_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "facial_hair" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(
				str(appearance.get("facial_hair_color", "#ffffff")),
				Color.WHITE
			),
			true
		)
	if normalized_category == "facegear" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("facegear_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "top" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("top_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "bottom" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("bottom_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "shoes" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			trainer_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("shoes_color", "#ffffff")), Color.WHITE),
			true
		)
	return CharacterAppearanceService.get_part_frames(category, part_id, trainer_gender)


func _parse_character_preview_color(color_text: String, fallback: Color) -> Color:
	var normalized := color_text.strip_edges()
	if normalized == "" or not normalized.begins_with("#"):
		return fallback
	return Color(normalized)


func _disable_character_preview_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child: Node in node.get_children():
		_disable_character_preview_processing(child)


func _set_character_preview_direction(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.name == "FaceGearSprite":
			var preview_appearance := _current_character_preview_appearance()
			sprite.z_index = CharacterAppearanceService.get_directional_part_z_index(
				"facegear",
				str(preview_appearance.get("facegear", "")),
				character_preview_direction,
				8
			)
		var animation_name := StringName("idle_%s" % character_preview_direction)
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
			sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()
	for child: Node in node.get_children():
		_set_character_preview_direction(child)


func _select_character_preview_direction(direction: String) -> void:
	if not ["down", "left", "right", "up"].has(direction):
		return
	character_preview_direction = direction
	_refresh_character_preview_direction_buttons()
	if character_preview_viewport != null:
		for child: Node in character_preview_viewport.get_children():
			_set_character_preview_direction(child)


func _refresh_character_preview_direction_buttons() -> void:
	for direction_value: Variant in character_preview_direction_buttons.keys():
		var direction := str(direction_value)
		var button := character_preview_direction_buttons.get(direction) as Button
		if button != null:
			_apply_cosmetic_subcategory_style(button, direction == character_preview_direction)


func _select_character_preview_color(color_id: String) -> void:
	var item := _catalog_item(selected_item_id)
	var tint_key := ""
	for preview_part: Dictionary in _preview_parts_for_item(item):
		tint_key = str(preview_part.get("tint", "")).strip_edges()
		if tint_key != "":
			break
	if tint_key == "":
		return
	character_preview_colors[tint_key] = color_id
	_refresh_character_preview()


func _select_character_preview_custom_color(color: Color) -> void:
	_select_character_preview_color("#%s" % color.to_html(false))


func _on_character_preview_hex_text_changed(color_text: String) -> void:
	var normalized := CharacterAppearanceService.normalize_hex_color_code(color_text)
	if character_preview_hex_input != null:
		character_preview_hex_input.add_theme_color_override(
			"font_color",
			UI_TEXT if normalized != "" or color_text.strip_edges() == "" else UI_DANGER
		)
	if normalized != "":
		_select_character_preview_color(normalized)


func _commit_character_preview_hex_color(_submitted_text: String = "") -> void:
	if character_preview_hex_input == null:
		return
	var normalized := CharacterAppearanceService.normalize_hex_color_code(character_preview_hex_input.text)
	if normalized == "":
		normalized = str(
			character_preview_colors.get(character_preview_palette_tint_key, "#ffffff")
		)
	character_preview_hex_input.set_block_signals(true)
	character_preview_hex_input.text = normalized
	character_preview_hex_input.set_block_signals(false)
	character_preview_hex_input.add_theme_color_override("font_color", UI_TEXT)


func _rebuild_character_preview_color_buttons(tint_key: String) -> void:
	if tint_key == character_preview_palette_tint_key:
		return
	character_preview_palette_tint_key = tint_key
	character_preview_color_buttons.clear()
	if character_preview_swatch_grid == null:
		return
	for child: Node in character_preview_swatch_grid.get_children():
		character_preview_swatch_grid.remove_child(child)
		child.queue_free()
	if tint_key == "":
		return

	var swatches: Array[Dictionary] = (
		CharacterAppearanceService.HAIR_COLOR_SWATCHES
		if tint_key == "hair_color"
		else CharacterAppearanceService.CHROMA_COLOR_SWATCHES
	)
	for swatch: Dictionary in swatches:
		var color_id := str(swatch.get("id", "#ffffff"))
		var swatch_button := Button.new()
		swatch_button.custom_minimum_size = Vector2(24, 24)
		swatch_button.tooltip_text = str(swatch.get("label", color_id))
		swatch_button.focus_mode = Control.FOCUS_NONE
		swatch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swatch_button.pressed.connect(_select_character_preview_color.bind(color_id))
		_apply_preview_swatch_style(swatch_button, swatch.get("color", Color.WHITE) as Color, false)
		character_preview_swatch_grid.add_child(swatch_button)
		character_preview_color_buttons[color_id] = swatch_button


func _refresh_character_preview_color_buttons(tint_key: String) -> void:
	var selected_color := str(character_preview_colors.get(tint_key, "")).to_lower()
	if character_preview_color_picker != null and tint_key != "":
		character_preview_color_picker.set_block_signals(true)
		character_preview_color_picker.color = Color.from_string(selected_color, Color.WHITE)
		character_preview_color_picker.set_block_signals(false)
	if character_preview_hex_input != null and tint_key != "":
		character_preview_hex_input.set_block_signals(true)
		character_preview_hex_input.text = selected_color
		character_preview_hex_input.set_block_signals(false)
		character_preview_hex_input.add_theme_color_override("font_color", UI_TEXT)
	for color_value: Variant in character_preview_color_buttons.keys():
		var color_id := str(color_value)
		var button := character_preview_color_buttons.get(color_id) as Button
		if button == null:
			continue
		_apply_preview_swatch_style(button, Color(color_id), color_id.to_lower() == selected_color)


func _apply_preview_swatch_style(button: Button, color: Color, selected: bool) -> void:
	var border := UI_GOLD if selected else Color("#ffffff55")
	var border_width := 2 if selected else 1
	button.add_theme_stylebox_override("normal", _button_style(color, border, 6, border_width))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.12), UI_TEXT, 6, 2))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.12), UI_GOLD, 6, 2))
	button.add_theme_stylebox_override("focus", _button_style(color, border, 6, border_width))


func _preview_parts_for_item(item: Dictionary) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	var preview_parts_value: Variant = item.get("preview_parts", [])
	if preview_parts_value is Array:
		for preview_part_value: Variant in preview_parts_value as Array:
			if preview_part_value is Dictionary:
				normalized.append((preview_part_value as Dictionary).duplicate(true))
	if not normalized.is_empty():
		return normalized
	var preview_part_value: Variant = item.get("preview_part", {})
	if preview_part_value is Dictionary and not (preview_part_value as Dictionary).is_empty():
		normalized.append((preview_part_value as Dictionary).duplicate(true))
	return normalized


func _catalog_item(item_id: String) -> Dictionary:
	for item: Dictionary in CATALOG:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _item_genders(item: Dictionary) -> Array[String]:
	var item_id := str(item.get("id", "")).strip_edges()
	var genders_value: Variant = item.get("genders", [])
	if store_catalog_loaded and authoritative_item_genders.has(item_id):
		var authoritative_value: Variant = authoritative_item_genders.get(item_id, [])
		var authoritative_genders: Array = authoritative_value if authoritative_value is Array else []
		var fallback_genders: Array = genders_value if genders_value is Array else []
		if not authoritative_genders.is_empty() or fallback_genders.is_empty():
			genders_value = authoritative_value
	var genders: Array[String] = []
	if genders_value is Array:
		for gender_value: Variant in genders_value as Array:
			var gender := str(gender_value).strip_edges().to_lower()
			if ["male", "female"].has(gender) and not genders.has(gender):
				genders.append(gender)
	return genders


func _item_matches_trainer_gender(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var genders := _item_genders(item)
	return genders.is_empty() or genders.has(trainer_gender)


func _item_gender_badge(item: Dictionary) -> String:
	var genders := _item_genders(item)
	if genders == ["male"]:
		return "MALE ONLY"
	if genders == ["female"]:
		return "FEMALE ONLY"
	return ""


func _item_gender_compatibility_note(item: Dictionary) -> String:
	var badge := _item_gender_badge(item)
	if badge == "MALE ONLY":
		return "Male character models only."
	if badge == "FEMALE ONLY":
		return "Female character models only."
	return ""


func _gem_price(item_id: String) -> int:
	if not authoritative_gem_prices.has(item_id):
		return -1
	return maxi(int(authoritative_gem_prices.get(item_id, -1)), 0)


func _refresh_purchase_state(update_status: bool = true) -> void:
	if purchase_button == null:
		return
	if purchase_in_progress:
		purchase_button.disabled = true
		purchase_button.text = "Purchasing..."
		purchase_button.tooltip_text = "Completing your purchase..."
		return
	purchase_button.text = "Purchase"
	if selected_item_id == "":
		purchase_button.disabled = true
		purchase_button.tooltip_text = "Select an available Store item"
		return
	if not _item_matches_trainer_gender(_catalog_item(selected_item_id)):
		purchase_button.disabled = true
		purchase_button.tooltip_text = "This item does not fit your character"
		if update_status:
			status_label.text = "This cosmetic is not compatible with your character model"
		return
	if store_catalog_loading or not store_catalog_loaded:
		purchase_button.disabled = true
		purchase_button.tooltip_text = "Loading Store items..."
		if update_status:
			status_label.text = "Loading Aether Gem balance and available items..."
		return
	var price := _gem_price(selected_item_id)
	if price < 0:
		purchase_button.disabled = true
		purchase_button.tooltip_text = "This preview item is not available yet"
		if update_status:
			status_label.text = "Preview only · this item is coming later"
		return
	if gem_balance < price:
		purchase_button.disabled = true
		purchase_button.tooltip_text = "You need %s more Aether Gems" % _format_number(price - gem_balance)
		if update_status:
			status_label.text = "Not enough Aether Gems · need %s more" % _format_number(price - gem_balance)
		return
	purchase_button.disabled = false
	purchase_button.tooltip_text = "Purchase for %s Aether Gems and add it to your Bag" % _format_number(price)
	if update_status:
		status_label.text = "Ready to purchase · item goes to your Bag"


func _on_purchase_pressed() -> void:
	if selected_item_id == "" or purchase_button.disabled:
		return
	set_purchase_in_progress(true)
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


func _apply_cosmetic_subcategory_style(button: Button, active: bool) -> void:
	var accent := UI_PURPLE if active else Color("#3b536999")
	var background := Color("#24183be8") if active else Color("#091725d9")
	var normal := _cosmetic_subcategory_button_style(background, accent)
	if active:
		normal.border_width_bottom = 2
	button.add_theme_color_override("font_color", UI_TEXT if active else UI_MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _cosmetic_subcategory_button_style(UI_SURFACE_HOVER, UI_PURPLE))
	button.add_theme_stylebox_override("pressed", _cosmetic_subcategory_button_style(UI_SURFACE_BASE, UI_PURPLE))
	button.add_theme_stylebox_override("focus", normal)


func _cosmetic_subcategory_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(background, border, 7, 1)
	style.content_margin_left = 7
	style.content_margin_top = 5
	style.content_margin_right = 7
	style.content_margin_bottom = 5
	return style


func _apply_cosmetic_item_category_style(select: OptionButton) -> void:
	select.focus_mode = Control.FOCUS_NONE
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select.add_theme_color_override("font_color", UI_TEXT)
	select.add_theme_color_override("font_hover_color", UI_TEXT)
	select.add_theme_color_override("font_pressed_color", UI_TEXT)
	select.add_theme_font_size_override("font_size", 10)
	select.add_theme_icon_override("arrow", STORE_DROPDOWN_ARROW)
	select.add_theme_stylebox_override(
		"normal",
		_cosmetic_subcategory_button_style(Color("#091725d9"), Color("#3b536999"))
	)
	select.add_theme_stylebox_override(
		"hover",
		_cosmetic_subcategory_button_style(UI_SURFACE_HOVER, UI_PURPLE)
	)
	select.add_theme_stylebox_override(
		"pressed",
		_cosmetic_subcategory_button_style(UI_SURFACE_BASE, UI_PURPLE)
	)
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var popup := select.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.add_theme_stylebox_override("panel", _cosmetic_item_category_popup_style())
	popup.add_theme_stylebox_override(
		"hover",
		_cosmetic_subcategory_button_style(Color("#24183bf2"), UI_PURPLE)
	)
	popup.add_theme_stylebox_override(
		"separator",
		_panel_style(Color("#00000000"), Color("#493b6688"), 0, 0)
	)
	popup.add_theme_color_override("font_color", UI_MUTED_TEXT)
	popup.add_theme_color_override("font_hover_color", UI_TEXT)
	popup.add_theme_color_override("font_disabled_color", Color("#657487"))
	popup.add_theme_color_override("font_separator_color", UI_PURPLE)
	popup.add_theme_color_override("font_outline_color", Color("#03070d"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 9)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 5)
	popup.add_theme_font_size_override("font_size", 11)
	popup.add_theme_icon_override("radio_checked", STORE_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", STORE_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", STORE_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", STORE_RADIO_UNCHECKED)


func _cosmetic_item_category_popup_style() -> StyleBoxFlat:
	var style := _panel_style(Color("#07111dfb"), Color("#6f5596d9"), 8, 1)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


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


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", UI_MUTED_TEXT)
	input.add_theme_color_override("caret_color", UI_CYAN)
	input.add_theme_stylebox_override("normal", _button_style(UI_SURFACE_INTERACTIVE, UI_BORDER_SOFT, 8, 1))
	input.add_theme_stylebox_override("focus", _button_style(UI_SURFACE_HOVER, UI_PURPLE, 8, 1))


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
