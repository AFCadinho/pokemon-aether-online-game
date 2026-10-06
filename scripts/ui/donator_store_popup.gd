class_name DonatorStorePopup
extends PanelContainer

signal closed
signal purchase_requested(item_id: String, chroma_colors: Dictionary, currency: String)

const PREVIEW_SHINY_ICON: Texture2D = preload("res://assets/ui/global_shiny_boost.svg")
const PREVIEW_PLAY_ICON: Texture2D = preload("res://assets/ui/icons/replay_play.svg")
const PREVIEW_PAUSE_ICON: Texture2D = preload("res://assets/ui/icons/replay_pause.svg")
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")

const Mounts := preload("res://scripts/services/mount_service.gd")

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
const PATREON_BADGE_ICON: Texture2D = preload("res://assets/ui/patreon_emblem.png")
const PATREON_PAGE_URL := "https://www.patreon.com/c/PokeAether"
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
const STORE_WINDOW_SIZE := Vector2(1120, 680)
const STORE_SCREEN_MARGIN := 16.0

const PREVIEW_VIEWPORT_SIZE := Vector2i(258, 174)
const PREVIEW_AVATAR_POSITION := Vector2(129, 91)
const PREVIEW_AVATAR_SCALE := Vector2(2.25, 2.25)
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
	"credits",
]
const FEATURED_FALLBACK_ITEM_ORDER: Array[String] = [
	"mysterious-outfit",
	"aether-blossom-outfit",
	"rayquaza-mount-box",
	"primal-kyogre-mount-box",
	"aether-blessing-voucher-30-days",
	"surf-charm",
]
const CATEGORY_LABELS := {
	"featured": "Popular",
	"membership": "Blessings",
	"cosmetics": "Cosmetics",
	"guilds": "Guilds",
	"mounts": "Mounts",
	"charms": "Charms",
	"services": "Trainer Services",
	"credits": "Credit Vouchers",
}
const CATEGORY_DESCRIPTIONS := {
	"featured": "Popular picks across categories, with featured selections to fill the gaps.",
	"membership": "Tradeable Aether Blessing vouchers and Patreon membership information.",
	"cosmetics": "Outfits and profile details that personalize your trainer without affecting gameplay.",
	"guilds": "Consumable templates that permanently unlock for your Guild without affecting gameplay.",
	"mounts": "Travel through the overworld in your own style.",
	"charms": "Use supported field moves without carrying a Pokémon that knows them. Progression and area rules still apply.",
	"services": "Optional changes to your trainer identity and account.",
	"credits": "Tradeable vouchers bought with Gems. Claim one to add personal card credit.",
}
const CATEGORY_PROMISES := {
	"featured": "FAIR SUPPORT",
	"membership": "5% SHINY · TRAVEL · NPC SHOPS",
	"cosmetics": "COSMETIC",
	"guilds": "GUILD COSMETIC",
	"mounts": "TRAVEL STYLE",
	"charms": "FIELD CONVENIENCE",
	"services": "TRAINER SERVICE",
	"credits": "PERSONAL CREDIT",
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
const STORE_PREVIEW_POLICY := preload("res://scripts/services/store_preview_appearance_policy.gd")
const CATALOG: Array[Dictionary] = [
	{"id": "aether-credit-voucher-100", "name": "Aether Credit Voucher · 100", "description": "Tradeable until claimed. Adds 100 credit to your personal Aether Credit Card.", "price": 100, "categories": ["credits"], "badge": "TRADEABLE", "icon": preload("res://assets/ui/store_voucher.svg")},
	{"id": "aether-credit-voucher-250", "name": "Aether Credit Voucher · 250", "description": "Tradeable until claimed. Adds 250 credit to your personal Aether Credit Card.", "price": 250, "categories": ["credits"], "badge": "TRADEABLE", "icon": preload("res://assets/ui/store_voucher.svg")},
	{"id": "aether-credit-voucher-500", "name": "Aether Credit Voucher · 500", "description": "Tradeable until claimed. Adds 500 credit to your personal Aether Credit Card.", "price": 500, "categories": ["credits"], "badge": "TRADEABLE", "icon": preload("res://assets/ui/store_voucher.svg")},
	{"id": "aether-credit-voucher-1000", "name": "Aether Credit Voucher · 1,000", "description": "Tradeable until claimed. Adds 1,000 credit to your personal Aether Credit Card.", "price": 1000, "categories": ["credits"], "badge": "TRADEABLE", "icon": preload("res://assets/ui/store_voucher.svg")},
	{
		"id": "patreon-supporter-preview",
		"name_key": "ui.store.patreon.name",
		"description_key": "ui.store.patreon.description",
		"icon": PATREON_BADGE_ICON,
		"categories": ["membership"],
		"badge": "PATREON",
		"informational": true,
		"preview_parts": [
			{"slot": "top", "appearance_id": "AetherRoyal_Shirt"},
			{"slot": "bottom", "appearance_id": "AetherRoyal_Trousers"},
			{"slot": "shoes", "appearance_id": "AetherRoyal_Shoes"},
			{"slot": "headgear", "appearance_id": "AetherRoyal_Crown"},
			{"slot": "cape", "appearance_id": "AetherRoyal_Cape"},
		],
	},
	{
		"id": "aether-blessing-voucher-3-days",
		"name": "Aether Blessing Voucher · 3 Days",
		"description": "Tradeable voucher. Use it from your Bag to activate Aether Blessing.",
		"price": 75,
		"icon": AETHER_BLESSING_VOUCHER_3_DAYS_ICON,
		"categories": ["membership"],
		"badge": "3 DAYS",
	},
	{
		"id": "aether-blessing-voucher-7-days",
		"name": "Aether Blessing Voucher · 7 Days",
		"description": "Tradeable voucher. Use it from your Bag to activate Aether Blessing.",
		"price": 150,
		"icon": AETHER_BLESSING_VOUCHER_7_DAYS_ICON,
		"categories": ["membership"],
		"badge": "7 DAYS",
	},
	{
		"id": "aether-blessing-voucher-14-days",
		"name": "Aether Blessing Voucher · 14 Days",
		"description": "Tradeable voucher. Use it from your Bag to activate Aether Blessing.",
		"price": 275,
		"icon": AETHER_BLESSING_VOUCHER_14_DAYS_ICON,
		"categories": ["membership"],
		"badge": "14 DAYS",
	},
	{
		"id": "aether-blessing-voucher-30-days",
		"name": "Aether Blessing Voucher · 30 Days",
		"description": "Tradeable voucher. Use it from your Bag to activate Aether Blessing.",
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
		"id": "aether-voyager-outfit",
		"name": "Aether Voyager Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "AetherVoyager_Shirt"},
			{"slot": "bottom", "appearance_id": "AetherVoyager_Trousers"},
			{"slot": "shoes", "appearance_id": "AetherVoyager_Shoes"},
		],
		"genders": ["male", "female"],
		"badge": "3-ITEM BOX",
	},
	{
		"id": "rotom-engineer-outfit",
		"name": "Rotom Engineer Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes", "facegear"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "RotomEngineer_Shirt"},
			{"slot": "bottom", "appearance_id": "RotomEngineer_Trousers"},
			{"slot": "shoes", "appearance_id": "RotomEngineer_Shoes"},
			{"slot": "facegear", "appearance_id": "RotomEngineer_Goggles"},
		],
		"genders": ["male", "female"],
		"badge": "4-ITEM BOX",
	},
	{
		"id": "celebi-forest-ranger-outfit",
		"name": "Celebi Forest Ranger Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "CelebiForestRanger_Shirt"},
			{"slot": "bottom", "appearance_id": "CelebiForestRanger_Trousers"},
			{"slot": "shoes", "appearance_id": "CelebiForestRanger_Shoes"},
		],
		"genders": ["male", "female"],
		"badge": "3-ITEM BOX",
	},
	{
		"id": "lucario-aura-fighter-outfit",
		"name": "Lucario Aura Fighter Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "LucarioAuraFighter_Shirt"},
			{"slot": "bottom", "appearance_id": "LucarioAuraFighter_Trousers"},
			{"slot": "shoes", "appearance_id": "LucarioAuraFighter_Shoes"},
		],
		"genders": ["male", "female"],
		"badge": "3-ITEM BOX",
	},
	{
		"id": "relic-explorer-outfit",
		"name": "Relic Explorer Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "RelicExplorer_Shirt"},
			{"slot": "bottom", "appearance_id": "RelicExplorer_Trousers"},
			{"slot": "shoes", "appearance_id": "RelicExplorer_Shoes"},
		],
		"genders": ["male", "female"],
		"badge": "3-ITEM BOX",
	},
	{
		"id": "lugia-sky-captain-outfit",
		"name": "Lugia Sky Captain Outfit Box",
		"description": "Fixed-colour outfit for male and female trainers. Open the box in your Bag to receive separate clothing items.",
		"price": 350,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["top", "bottom", "shoes", "facegear"],
		"preview_parts": [
			{"slot": "top", "appearance_id": "LugiaSkyCaptain_Shirt"},
			{"slot": "bottom", "appearance_id": "LugiaSkyCaptain_Trousers"},
			{"slot": "shoes", "appearance_id": "LugiaSkyCaptain_Shoes"},
			{"slot": "facegear", "appearance_id": "LugiaSkyCaptain_Goggles"},
		],
		"genders": ["male", "female"],
		"badge": "4-ITEM BOX",
	},
	{
		"id": "mysterious-outfit",
		"name": "Mysterious Outfit Box",
		"description": "Tradeable unisex outfit box. Open it in your Bag to receive the mask, shirt and gloves, trousers, and shoes as separate tradeable items.",
		"price": 550,
		"icon": STYLE_ICON,
		"categories": ["featured", "cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["facegear", "top", "bottom", "shoes"],
		"preview_parts": [
			{"slot": "facegear", "appearance_id": "Mysterious_Mask"},
			{"slot": "top", "appearance_id": "Mysterious_Shirt"},
			{"slot": "bottom", "appearance_id": "Mysterious_Trousers"},
			{"slot": "shoes", "appearance_id": "Mysterious_Shoes"},
		],
		"genders": ["male", "female"],
		"badge": "4-ITEM BOX",
	},
	{
		"id": "adinho-classic-outfit",
		"name": "Adinho Classic Box",
		"description": "Tradeable outfit box. Open it in your Bag to receive all six cosmetic components as separate tradeable items.",
		"price": 550,
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
		"id": "ironfanton-outfit",
		"name": "IronFanton Outfit Box",
		"description": "Tradeable male-only outfit box. Open it in your Bag to receive Chroma Hair, Chroma Beard and the Shirt as separate tradeable items.",
		"price": 550,
		"icon": STYLE_ICON,
		"categories": ["featured", "cosmetics"],
		"cosmetic_subcategory": "outfits",
		"appearance_slots": ["hair", "facial_hair", "top"],
		"preview_parts": [
			{"slot": "hair", "appearance_id": "IronFanton_Hair", "tint": "hair_color"},
			{"slot": "facial_hair", "appearance_id": "IronFanton_Beard", "tint": "hair_color"},
			{"slot": "top", "appearance_id": "IronFanton_Shirt"},
		],
		"genders": ["male"],
		"badge": "3-ITEM BOX",
	},
	{
		"id": "aether-blossom-outfit",
		"name": "Aether Blossom Box",
		"description": "Tradeable female-only outfit box. Open it in your Bag to receive all four cosmetic components as separate tradeable items.",
		"price": 550,
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
		"id": "aether-male-chroma-hair-1",
		"name": "Aether Chroma Hair I",
		"description": "Tradeable male-only hairstyle supplied in your selected permanent base colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Male_Hair_01", "tint": "hair_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-male-chroma-hair-2",
		"name": "Aether Chroma Hair II",
		"description": "Tradeable male-only hairstyle supplied in your selected permanent base colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Male_Hair_02", "tint": "hair_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-male-chroma-hair-3",
		"name": "Aether Chroma Hair III",
		"description": "Tradeable male-only hairstyle supplied in your selected permanent base colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Male_Hair_03", "tint": "hair_color"},
		"genders": ["male"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-female-chroma-hair-1",
		"name": "Aether Chroma Hair I",
		"description": "Tradeable female-only hairstyle supplied in your selected permanent base colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Female_Hair_01", "tint": "hair_color"},
		"genders": ["female"],
		"badge": "CHROMA",
	},
	{
		"id": "aether-female-chroma-hair-2",
		"name": "Aether Chroma Hair II",
		"description": "Tradeable female-only hairstyle supplied in your selected permanent base colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Aether_Female_Hair_02", "tint": "hair_color"},
		"genders": ["female"],
		"badge": "CHROMA",
	},
	{
		"id": "adinho-chroma-hair",
		"name": "Adinho Chroma Hair",
		"description": "Tradeable hair box using your selected permanent hair colour.",
		"price": 100,
		"icon": STYLE_ICON,
		"categories": ["cosmetics"],
		"cosmetic_subcategory": "hair",
		"appearance_slots": ["hair"],
		"preview_part": {"slot": "hair", "appearance_id": "Adinho_Hair", "tint": "hair_color"},
		"genders": ["male"],
		"badge": "CHROMA",
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
		"genders": ["male", "female"],
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
		"id": "giratina-origin-mount-box",
		"name": "Giratina Origin Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_giratina_origin",
		"price": 1000,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "ho-oh-mount-box",
		"name": "Ho-Oh Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_ho_oh",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "yveltal-mount-box",
		"name": "Yveltal Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_yveltal",
		"price": 1000,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "miraidon-mount-box",
		"name": "Miraidon Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_miraidon",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "reshiram-mount-box",
		"name": "Reshiram Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_reshiram",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},

	{
		"id": "metagross-mount-box",
		"name": "Metagross Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_metagross",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},

	{
		"id": "salamence-mount-box",
		"name": "Salamence Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_salamence",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "zekrom-mount-box",
		"name": "Zekrom Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_zekrom",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "palkia-mount-box",
		"name": "Palkia Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_palkia",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "dialga-mount-box",
		"name": "Dialga Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_dialga",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "arcanine-mount-box",
		"name": "Arcanine Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_arcanine",
		"price": 500,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "aerodactyl-mount-box",
		"name": "Aerodactyl Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_aerodactyl",
		"price": 500,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "toucannon-mount-box",
		"name": "Toucannon Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_toucannon",
		"price": 500,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "latios-mount-box",
		"name": "Latios Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_latios",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "latias-mount-box",
		"name": "Latias Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_latias",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "caterpie-mount-box",
		"name": "Caterpie Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_caterpie",
		"price": 250,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "magikarp-mount-box",
		"name": "Magikarp Surf Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_magikarp",
		"price": 250,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "rayquaza-mount-box",
		"name": "Rayquaza Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description",
		"price": 1000,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "shadow-lugia-mount-box",
		"name": "Shadow Lugia Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_shadow_lugia",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "mega-alakazam-mount-box",
		"name": "Mega Alakazam Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_mega_alakazam",
		"price": 750,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "glaceon-mount-box",
		"name": "Glaceon Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_glaceon",
		"price": 500,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "cobalion-mount-box",
		"name": "Cobalion Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_cobalion",
		"price": 500,
		"icon": MOUNT_ICON,
		"categories": ["featured", "mounts"],
		"badge": "MOUNT BOX",
	},
	{
		"id": "primal-kyogre-mount-box",
		"name": "Primal Kyogre Mount Box",
		"description_key": "ui.shiny_tracker.mounts.store_description_primal_kyogre",
		"price": 1000,
		"icon": MOUNT_ICON,
		"categories": ["mounts"],
		"badge": "MOUNT BOX",
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

var voucher_balance := 0
var voucher_balance_label: Label
var currency_info_button: Button
var currency_info_dialog: AetherConfirmationDialog
var voucher_eligible_items: Dictionary = {}
var payment_select: OptionButton
var voucher_notice_label: Label
var voucher_confirm_dialog: AetherConfirmationDialog
var pending_voucher_purchase: Dictionary = {}
var gem_balance := 0
var authoritative_gem_prices: Dictionary = {}
var authoritative_item_genders: Dictionary = {}
var store_catalog_loaded := false
var featured_item_ids: Array[String] = []
var popular_item_ids: Array[String] = []
var featured_selection_loaded := false
var store_catalog_loading := false
var purchase_in_progress := false
var trainer_gender := "male"
var trainer_appearance: Dictionary = {}
var active_category := "featured"
var active_mount_mode := "land"
var mount_mode_bar: HBoxContainer
var mount_mode_buttons: Dictionary = {}
var active_cosmetic_filter_group := "all"
var active_cosmetic_subcategory := "all"
var active_cosmetic_gender_filter := "mine"
var selected_item_id := ""
var category_buttons: Dictionary = {}
var cosmetic_filter_group_buttons: Dictionary = {}
var cosmetic_item_category_control: HBoxContainer
var cosmetic_item_category_select: OptionButton
var cosmetic_gender_control: OptionButton
var product_buttons: Dictionary = {}
var catalog_search_input: LineEdit
var catalog_search_text := ""
var catalog_filter_select: OptionButton
var catalog_sort_select: OptionButton
var active_catalog_filter := "all"
var active_catalog_sort := "default"
const CATALOG_FILTERS := ["all", "gems_affordable", "voucher_eligible", "voucher_affordable"]
const CATALOG_SORTS := ["default", "name", "price_asc", "price_desc"]
var balance_label: Label
var add_gems_button: Button
var add_gems_feedback_label: Label
var portal_launch_in_progress := false
var patreon_action_in_progress := false
var patreon_status: Dictionary = {"success": false}
var patreon_status_request_id := 0
var patreon_external_dialog: ConfirmationDialog
var hero_title_label: Label
var hero_description_label: Label
var cosmetic_subcategory_bar: PanelContainer
var product_grid: GridContainer
var catalog_results_label: Label
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
var mount_preview_controls: HBoxContainer
var mount_preview_shiny_toggle: Button
var mount_preview_animation_toggle: Button
var mount_preview_shiny := false
var mount_preview_animated := true
var store_dragging := false
var store_drag_pointer_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_BASE, Color("#74549ebf"), 14, 1))
	if trainer_appearance.is_empty():
		trainer_appearance = CharacterAppearanceService.get_default_appearance(trainer_gender)
	_build_interface()
	get_viewport().size_changed.connect(_fit_store_window)
	var host := get_parent() as Control
	if host != null:
		host.resized.connect(_fit_store_window)
	_fit_store_window.call_deferred()
	voucher_confirm_dialog = AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
	voucher_confirm_dialog.name = "VoucherPurchaseConfirmation"
	voucher_confirm_dialog.confirmed.connect(_confirm_voucher_purchase)
	voucher_confirm_dialog.canceled.connect(_cancel_voucher_purchase)
	add_child(voucher_confirm_dialog)
	_sync_character_preview_colors()
	set_gem_balance(gem_balance)
	set_voucher_balance(voucher_balance)
	_select_category("featured")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func _fit_store_window() -> void:
	store_dragging = false
	# Use logical UI coordinates so the overlay's own scaling is respected.
	var host := get_parent() as Control
	var available := host.size if host != null else get_viewport_rect().size
	var usable := (available - Vector2.ONE * STORE_SCREEN_MARGIN * 2.0).max(Vector2.ONE)
	var fit_scale := minf(1.0, minf(usable.x / STORE_WINDOW_SIZE.x, usable.y / STORE_WINDOW_SIZE.y))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = STORE_WINDOW_SIZE
	scale = Vector2.ONE * fit_scale
	position = (available - STORE_WINDOW_SIZE * fit_scale) * 0.5


func _on_store_header_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	store_dragging = event.pressed
	if store_dragging:
		store_drag_pointer_offset = _store_pointer_in_parent(event.global_position) - position
		move_to_front()
	accept_event()


func _input(event: InputEvent) -> void:
	if not store_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		store_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			store_dragging = false
			return
		position = _store_pointer_in_parent(event.position) - store_drag_pointer_offset
		_clamp_store_to_parent()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		store_dragging = false


func _store_pointer_in_parent(viewport_position: Vector2) -> Vector2:
	var host := get_parent_control()
	return host.get_global_transform_with_canvas().affine_inverse() * viewport_position if host != null else viewport_position


func _clamp_store_to_parent() -> void:
	var host := get_parent_control()
	var available := host.size if host != null else get_viewport_rect().size
	var minimum := Vector2.ONE * STORE_SCREEN_MARGIN
	var maximum := (available - size * scale - minimum).max(minimum)
	position = Vector2(clampf(position.x, minimum.x, maximum.x), clampf(position.y, minimum.y, maximum.y))


func _configure_header_drag_surface(control: Control) -> void:
	if control is BaseButton:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_configure_header_drag_surface(child)


func set_gem_balance(amount: int) -> void:
	gem_balance = maxi(amount, 0)
	if balance_label != null:
		balance_label.text = _t("ui.store.balance", {"amount": _format_number(gem_balance)})
	_refresh_purchase_state()
	if active_catalog_filter == "gems_affordable":
		_render_products()


func set_voucher_balance(amount: int) -> void:
	voucher_balance = maxi(amount, 0)
	if voucher_balance_label != null:
		voucher_balance_label.text = _t("ui.store.voucher.balance", {"amount": _format_number(voucher_balance)})
	_refresh_purchase_state()
	if active_catalog_filter == "voucher_affordable":
		_render_products()


func _payment_currency() -> String:
	return "gift_voucher" if payment_select != null and payment_select.selected == 1 else "gems"


func set_store_loading(loading: bool) -> void:
	store_catalog_loading = loading
	if loading and status_label != null:
		status_label.text = _t("ui.store.status.loading")
	_refresh_purchase_state()


func apply_store_state(wallet: Dictionary, store: Dictionary) -> void:
	set_gem_balance(int(wallet.get("gems", gem_balance)))
	set_voucher_balance(int(wallet.get("gift_voucher_balance", 0)))
	voucher_eligible_items.clear()
	authoritative_gem_prices.clear()
	authoritative_item_genders.clear()
	var items_value: Variant = store.get("items", [])
	if items_value is Array:
		for item_value: Variant in items_value as Array:
			if not item_value is Dictionary:
				continue
			var offer := item_value as Dictionary
			var item_id := str(offer.get("itemId", "")).strip_edges()
			voucher_eligible_items[item_id] = bool(offer.get("voucherEligible", false))
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
	featured_item_ids.clear()
	popular_item_ids.clear()
	var featured_value: Variant = store.get("featured")
	featured_selection_loaded = featured_value is Dictionary
	if featured_selection_loaded:
		var featured := featured_value as Dictionary
		var featured_ids_value: Variant = featured.get("itemIds", [])
		if featured_ids_value is Array:
			for item_id_value: Variant in featured_ids_value:
				var item_id := str(item_id_value)
				if featured_item_ids.size() >= 6:
					break
				if authoritative_gem_prices.has(item_id) and not _catalog_item(item_id).is_empty() and not featured_item_ids.has(item_id):
					featured_item_ids.append(item_id)
		var popular_ids_value: Variant = featured.get("popularItemIds", [])
		if popular_ids_value is Array:
			for item_id_value: Variant in popular_ids_value:
				var item_id := str(item_id_value)
				if featured_item_ids.has(item_id) and not popular_item_ids.has(item_id):
					popular_item_ids.append(item_id)
	store_catalog_loaded = true
	store_catalog_loading = false
	_refresh_category_visibility()
	_render_products()
	if selected_item_id == "":
		_reset_selection_footer()
	else:
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
		status_label.text = _t("ui.store.status.purchasing")
	_refresh_purchase_state()


func show_purchase_success(item_name: String, currency: String = "gems") -> void:
	purchase_in_progress = false
	if status_label != null:
		status_label.text = _t("ui.store.voucher.success" if currency == "gift_voucher" else "ui.store.status.added", {
			"item": item_name, "amount": _format_number(voucher_balance)
		})
	_refresh_purchase_state(false)


func set_trainer_gender(value: String) -> void:
	trainer_gender = "female" if value.strip_edges().to_lower() == "female" else "male"
	_render_products()
	_refresh_character_preview()


func set_trainer_appearance(value: Dictionary) -> void:
	trainer_appearance = value.duplicate(true)
	trainer_gender = (
		"female"
		if str(trainer_appearance.get("gender", trainer_gender)).strip_edges().to_lower() == "female"
		else "male"
	)
	_sync_character_preview_colors()
	_render_products()
	_refresh_character_preview()


func open_store() -> void:
	_fit_store_window()
	_sync_character_preview_colors()
	_refresh_character_preview()
	visible = true
	if status_label != null:
		status_label.text = _t("ui.store.status.loading")
	patreon_status = {"success": false}
	patreon_status_request_id += 1
	_refresh_purchase_state()
	_load_patreon_status(patreon_status_request_id)


func close_store() -> void:
	store_dragging = false
	if currency_info_dialog != null:
		currency_info_dialog.hide_dialog()
	if voucher_confirm_dialog != null:
		voucher_confirm_dialog.hide_dialog()
	if not pending_voucher_purchase.is_empty():
		_cancel_voucher_purchase()
	patreon_status_request_id += 1
	patreon_action_in_progress = false
	if patreon_external_dialog != null:
		patreon_external_dialog.hide()
	visible = false
	closed.emit()


func _build_interface() -> void:
	patreon_external_dialog = ConfirmationDialog.new()
	patreon_external_dialog.title = _t("ui.store.patreon.external_title")
	patreon_external_dialog.dialog_text = _t("ui.store.patreon.external_confirm")
	patreon_external_dialog.confirmed.connect(_open_patreon_page)
	add_child(patreon_external_dialog)
	# A plain Control isolates the window minimum from changing product contents.
	var content_frame := Control.new()
	content_frame.name = "StoreContentFrame"
	add_child(content_frame)
	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_top", 14)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 16)
	content_frame.add_child(outer_margin)
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	outer_margin.add_child(layout)
	layout.add_child(_create_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	body.add_child(_create_category_rail())
	body.add_child(_create_catalog_area())
	body.add_child(_create_character_preview_panel())


func _create_header() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StoreDragHeader"
	panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	panel.gui_input.connect(_on_store_header_gui_input)
	panel.custom_minimum_size = Vector2(0, 58)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 10, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var header_content := VBoxContainer.new()
	header_content.add_theme_constant_override("separation", 4)
	margin.add_child(header_content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header_content.add_child(row)

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
	_set_localized_property(title, "text", "ui.store.title")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)

	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.store.subtitle")
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UI_MUTED_TEXT)
	heading.add_child(subtitle)

	row.add_child(_create_balance_pill())

	add_gems_button = Button.new()
	add_gems_button.name = "AddGemsButton"
	_set_localized_property(add_gems_button, "text", "ui.store.add_gems")
	_set_localized_property(add_gems_button, "tooltip_text", "ui.store.add_gems_tooltip")
	add_gems_button.custom_minimum_size = Vector2(184, 42)
	add_gems_button.focus_mode = Control.FOCUS_ALL
	add_gems_button.icon = GEM_ICON
	add_gems_button.expand_icon = true
	add_gems_button.add_theme_constant_override("icon_max_width", 19)
	add_gems_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_gems_button.pressed.connect(_on_add_gems_pressed)
	_apply_add_gems_button_style(add_gems_button)
	row.add_child(add_gems_button)

	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(close_store)
	_apply_text_button_style(close_button, UI_BORDER)
	row.add_child(close_button)

	add_gems_feedback_label = Label.new()
	add_gems_feedback_label.name = "AddGemsFeedback"
	add_gems_feedback_label.visible = false
	add_gems_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_gems_feedback_label.add_theme_font_size_override("font_size", 11)
	header_content.add_child(add_gems_feedback_label)
	for child in panel.get_children():
		if child is Control:
			_configure_header_drag_surface(child)
	return panel


func _on_add_gems_pressed() -> void:
	if portal_launch_in_progress:
		return
	portal_launch_in_progress = true
	add_gems_button.disabled = true
	_set_add_gems_feedback("ui.store.add_gems_opening")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	var locale := str(localization_manager.get("current_locale")) if localization_manager != null else "en"
	var auth_service := get_node_or_null("/root/AuthService")
	if auth_service == null:
		_finish_add_gems_launch({"success": false})
		return
	var result: Dictionary = await auth_service.call("create_account_portal_launch", locale, "gems")
	if is_inside_tree():
		_finish_add_gems_launch(result)


func _finish_add_gems_launch(result: Dictionary) -> void:
	var key := "ui.store.add_gems_error"
	if bool(result.get("success", false)):
		if OS.shell_open(str(result.get("url", ""))) == OK:
			key = "ui.store.add_gems_opened"
		else:
			key = "ui.store.add_gems_error_open"
	_set_add_gems_feedback(key, key != "ui.store.add_gems_opened")
	portal_launch_in_progress = false
	if add_gems_button != null:
		add_gems_button.disabled = false


func _set_add_gems_feedback(key: String, is_error: bool = false) -> void:
	var message := _t(key)
	if add_gems_feedback_label != null:
		add_gems_feedback_label.text = message
		add_gems_feedback_label.add_theme_color_override("font_color", UI_DANGER if is_error else UI_CYAN)
		add_gems_feedback_label.visible = true
	if status_label != null:
		status_label.text = message


func _load_patreon_status(request_id: int) -> void:
	var auth_service := get_node_or_null("/root/AuthService")
	if auth_service == null:
		return
	var result: Dictionary = await auth_service.call("get_patreon_store_status")
	if not is_inside_tree() or not visible or request_id != patreon_status_request_id:
		return
	apply_patreon_status(result)


func apply_patreon_status(value: Dictionary) -> void:
	patreon_status = value.duplicate(true)
	if selected_item_id == "patreon-supporter-preview":
		_select_product(selected_item_id)


func _patreon_status_key() -> String:
	if not bool(patreon_status.get("success", false)):
		return "ui.store.patreon.status_unknown"
	if bool(patreon_status.get("manualRole", false)) and not bool(patreon_status.get("active", false)):
		return "ui.store.patreon.status_manual_role"
	if bool(patreon_status.get("connected", false)):
		return (
			"ui.store.patreon.status_active"
			if bool(patreon_status.get("active", false))
			else "ui.store.patreon.status_connected"
		)
	if not bool(patreon_status.get("available", false)):
		return "ui.store.patreon.status_unavailable"
	return "ui.store.patreon.status_not_connected"


func _on_patreon_action_pressed() -> void:
	if patreon_action_in_progress or not bool(patreon_status.get("success", false)):
		return
	if bool(patreon_status.get("connected", false)):
		patreon_external_dialog.popup_centered()
		return
	if not bool(patreon_status.get("available", false)):
		return
	patreon_action_in_progress = true
	var request_id := patreon_status_request_id
	_refresh_purchase_state()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	var locale := str(localization_manager.get("current_locale")) if localization_manager != null else "en"
	var auth_service := get_node_or_null("/root/AuthService")
	var result: Dictionary = {"success": false}
	if auth_service != null:
		result = await auth_service.call("create_account_portal_launch", locale, "account")
	if not is_inside_tree():
		return
	patreon_action_in_progress = false
	if not visible or request_id != patreon_status_request_id:
		return
	if not bool(result.get("success", false)) or OS.shell_open(str(result.get("url", ""))) != OK:
		status_label.text = _t("ui.store.patreon.open_failed")
		_refresh_purchase_state(false)
		return
	_refresh_purchase_state()


func _open_patreon_page() -> void:
	if OS.shell_open(PATREON_PAGE_URL) != OK:
		status_label.text = _t("ui.store.patreon.open_failed")


func _create_balance_pill() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 52)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 10, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var balance_row := HBoxContainer.new()
	balance_row.add_theme_constant_override("separation", 10)
	margin.add_child(balance_row)
	var balances := GridContainer.new()
	balances.columns = 2
	balances.add_theme_constant_override("h_separation", 8)
	balances.add_theme_constant_override("v_separation", 4)
	balance_row.add_child(balances)

	for texture: Texture2D in [GEM_ICON, preload("res://assets/ui/store_credit_card.svg")]:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture
		balances.add_child(icon)

		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		balances.add_child(label)
		if texture == GEM_ICON:
			balance_label = label
			label.add_theme_color_override("font_color", UI_TEXT)
		else:
			voucher_balance_label = label
			label.name = "VoucherBalance"
			label.add_theme_color_override("font_color", UI_GOLD)
	currency_info_button = Button.new()
	currency_info_button.name = "CurrencyInfoButton"
	currency_info_button.text = "i"
	currency_info_button.custom_minimum_size = Vector2(26, 26)
	currency_info_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	currency_info_button.focus_mode = Control.FOCUS_ALL
	currency_info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_localized_property(currency_info_button, "tooltip_text", "ui.store.currency_info.tooltip")
	_apply_text_button_style(currency_info_button, UI_BORDER)
	currency_info_button.add_theme_font_size_override("font_size", 15)
	currency_info_button.pressed.connect(_show_currency_info)
	balance_row.add_child(currency_info_button)
	return panel


func _show_currency_info() -> void:
	if currency_info_dialog == null:
		currency_info_dialog = AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
		currency_info_dialog.name = "StoreCurrencyInfo"
		add_child(currency_info_dialog)
		currency_info_dialog.confirmed.connect(_hide_currency_info)
		currency_info_dialog.canceled.connect(_hide_currency_info)
	_refresh_currency_info()
	currency_info_dialog.cancel_button.hide()
	currency_info_dialog.accent_icon.texture = GEM_ICON
	currency_info_dialog.popup_centered(Vector2i(640, 440))
	currency_info_dialog.confirm_button.grab_focus()


func _refresh_currency_info() -> void:
	if currency_info_dialog != null:
		currency_info_dialog.configure(_t("ui.store.currency_info.title"), _t("ui.store.currency_info.body", {"get_gems": _t("ui.store.add_gems")}), _t("common.close"), _t("common.close"))


func _hide_currency_info() -> void:
	currency_info_dialog.hide_dialog()
	currency_info_button.grab_focus()


func _create_category_rail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(154, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 11, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var browse_label := Label.new()
	_set_localized_property(browse_label, "text", "ui.store.browse")
	browse_label.add_theme_font_size_override("font_size", 10)
	browse_label.add_theme_color_override("font_color", UI_PURPLE)
	layout.add_child(browse_label)

	for category_id: String in CATEGORY_ORDER:
		var button := Button.new()
		button.text = _category_text(category_id, "label")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_category.bind(category_id))
		layout.add_child(button)
		category_buttons[category_id] = button

	return panel


func _create_catalog_area() -> Control:
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	layout.add_child(_create_hero_panel())
	layout.add_child(_create_cosmetic_subcategory_bar())
	layout.add_child(_create_mount_mode_bar())

	var catalog_header := HBoxContainer.new()
	catalog_header.add_theme_constant_override("separation", 8)
	layout.add_child(catalog_header)

	catalog_results_label = Label.new()
	_set_localized_property(catalog_results_label, "text", "ui.store.catalog")
	catalog_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catalog_results_label.add_theme_font_size_override("font_size", 11)
	catalog_results_label.add_theme_color_override("font_color", UI_CYAN)
	catalog_header.add_child(catalog_results_label)

	catalog_search_input = LineEdit.new()
	catalog_search_input.name = "CatalogSearchInput"
	_set_localized_property(catalog_search_input, "placeholder_text", "ui.store.search")
	catalog_search_input.clear_button_enabled = true
	catalog_search_input.custom_minimum_size = Vector2(190, 32)
	_set_localized_property(catalog_search_input, "tooltip_text", "ui.store.search_tooltip")
	catalog_search_input.text_changed.connect(_on_catalog_search_changed)
	_apply_line_edit_style(catalog_search_input)
	catalog_header.add_child(catalog_search_input)

	var tools_row := HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 8)
	layout.add_child(tools_row)
	catalog_filter_select = _create_catalog_option("CatalogFilter", CATALOG_FILTERS, "filter")
	catalog_filter_select.item_selected.connect(_on_catalog_filter_selected)
	tools_row.add_child(catalog_filter_select)
	catalog_sort_select = _create_catalog_option("CatalogSort", CATALOG_SORTS, "sort")
	catalog_sort_select.item_selected.connect(_on_catalog_sort_selected)
	tools_row.add_child(catalog_sort_select)

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


func _create_catalog_option(control_name: String, options: Array, kind: String) -> OptionButton:
	var select := OptionButton.new()
	select.name = control_name
	select.custom_minimum_size = Vector2(0, 30)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.fit_to_longest_item = false
	for option: String in options:
		select.add_item(_t("ui.store." + kind + "." + option))
		select.set_item_metadata(select.item_count - 1, option)
	_apply_cosmetic_item_category_style(select)
	return select


func _on_catalog_filter_selected(index: int) -> void:
	active_catalog_filter = str(catalog_filter_select.get_item_metadata(index))
	_render_products()


func _on_catalog_sort_selected(index: int) -> void:
	active_catalog_sort = str(catalog_sort_select.get_item_metadata(index))
	_render_products()


func _matches_catalog_filter(item: Dictionary) -> bool:
	if active_catalog_filter == "all":
		return true
	var item_id := str(item.get("id", ""))
	var price := _gem_price(item_id)
	if not store_catalog_loaded or price < 0 or bool(item.get("informational", false)):
		return false
	match active_catalog_filter:
		"gems_affordable":
			return price <= gem_balance
		"voucher_eligible":
			return bool(voucher_eligible_items.get(item_id, false))
		"voucher_affordable":
			return bool(voucher_eligible_items.get(item_id, false)) and price <= voucher_balance
	return true


func _catalog_sort_price(item: Dictionary) -> int:
	if bool(item.get("informational", false)):
		return -1
	return _gem_price(str(item.get("id", ""))) if store_catalog_loaded else int(item.get("price", 0))


func _catalog_item_before(left: Dictionary, right: Dictionary) -> bool:
	if active_catalog_sort in ["price_asc", "price_desc"]:
		var left_price := _catalog_sort_price(left)
		var right_price := _catalog_sort_price(right)
		if (left_price < 0) != (right_price < 0):
			return right_price < 0
		if left_price != right_price:
			return left_price < right_price if active_catalog_sort == "price_asc" else left_price > right_price
	var comparison := _item_name(left).naturalnocasecmp_to(_item_name(right))
	return comparison < 0 if comparison != 0 else str(left.get("id", "")) < str(right.get("id", ""))


func _create_mount_mode_bar() -> HBoxContainer:
	mount_mode_bar = HBoxContainer.new()
	mount_mode_bar.name = "MountModeTabs"
	mount_mode_bar.visible = false
	mount_mode_bar.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for mode: String in ["land", "surf"]:
		var button := Button.new()
		button.name = "MountMode_" + mode
		button.custom_minimum_size = Vector2(110, 34)
		button.toggle_mode = true
		button.button_group = group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_mount_mode.bind(mode))
		mount_mode_bar.add_child(button)
		mount_mode_buttons[mode] = button
	return mount_mode_bar


func _refresh_mount_mode_bar() -> void:
	if mount_mode_bar == null:
		return
	mount_mode_bar.visible = active_category == "mounts"
	for mode: String in mount_mode_buttons:
		var button: Button = mount_mode_buttons[mode]
		button.text = _t("ui.store.mounts.mode." + mode)
		button.set_pressed_no_signal(mode == active_mount_mode)
		_apply_cosmetic_subcategory_style(button, mode == active_mount_mode)


func _select_mount_mode(mode: String) -> void:
	if mode not in ["land", "surf"]:
		return
	active_mount_mode = mode
	selected_item_id = ""
	catalog_search_text = ""
	catalog_search_input.set_block_signals(true)
	catalog_search_input.text = ""
	catalog_search_input.set_block_signals(false)
	_refresh_mount_mode_bar()
	_reset_selection_footer()
	_render_products()


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

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	margin.add_child(controls)

	var row := HBoxContainer.new()
	row.name = "CosmeticFilterControls"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	controls.add_child(row)

	for group_id: String in COSMETIC_FILTER_GROUP_ORDER:
		var button := Button.new()
		button.name = "CosmeticFilter_%s" % group_id
		button.text = _t("ui.store.cosmetic.group.%s" % group_id)
		button.custom_minimum_size = Vector2(70, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_cosmetic_filter_group.bind(group_id))
		row.add_child(button)
		cosmetic_filter_group_buttons[group_id] = button

	cosmetic_gender_control = OptionButton.new()
	cosmetic_gender_control.name = "CosmeticGenderFilter"
	cosmetic_gender_control.custom_minimum_size = Vector2(190, 30)
	for filter_id: String in ["mine", "other", "all"]:
		cosmetic_gender_control.add_item(_t("ui.store.cosmetic.gender.%s" % filter_id))
		cosmetic_gender_control.set_item_metadata(cosmetic_gender_control.item_count - 1, filter_id)
	cosmetic_gender_control.item_selected.connect(_on_cosmetic_gender_filter_selected)
	_apply_cosmetic_item_category_style(cosmetic_gender_control)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(cosmetic_gender_control)

	cosmetic_item_category_control = HBoxContainer.new()
	cosmetic_item_category_control.name = "CosmeticItemCategoryControl"
	cosmetic_item_category_control.add_theme_constant_override("separation", 6)
	controls.add_child(cosmetic_item_category_control)

	var category_label := Label.new()
	_set_localized_property(category_label, "text", "ui.store.cosmetic.item_category")
	category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", 9)
	category_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	cosmetic_item_category_control.add_child(category_label)

	cosmetic_item_category_select = OptionButton.new()
	cosmetic_item_category_select.name = "CosmeticItemCategorySelect"
	cosmetic_item_category_select.custom_minimum_size = Vector2(150, 30)
	cosmetic_item_category_select.add_item(_subcategory_text("all"))
	cosmetic_item_category_select.set_item_metadata(0, "all")
	for subcategory_id: String in COSMETIC_ITEM_CATEGORY_ORDER:
		cosmetic_item_category_select.add_item(_subcategory_text(subcategory_id))
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
	panel.custom_minimum_size = Vector2(0, 66)
	var style := _panel_style(UI_SURFACE_RAISED, UI_BORDER_SOFT, 10, 1)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 2)
	margin.add_child(heading)

	hero_title_label = Label.new()
	hero_title_label.add_theme_font_size_override("font_size", 17)
	hero_title_label.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(hero_title_label)

	hero_description_label = Label.new()
	hero_description_label.custom_minimum_size = Vector2(0, 16)
	hero_description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hero_description_label.clip_text = true
	hero_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_description_label.add_theme_font_size_override("font_size", 11)
	hero_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	heading.add_child(hero_description_label)
	return panel


func _create_character_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "CharacterPreviewPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	var style := _panel_style(Color("#0b1524f2"), UI_BORDER_SOFT, 10, 1)
	panel.add_theme_stylebox_override("panel", style)

	var panel_layout := VBoxContainer.new()
	panel_layout.add_theme_constant_override("separation", 0)
	panel.add_child(panel_layout)
	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.name = "ProductDetailsScroll"
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_layout.add_child(details_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	details_scroll.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	character_preview_eyebrow_label = Label.new()
	character_preview_eyebrow_label.text = _t("ui.store.preview.on_trainer")
	character_preview_eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_eyebrow_label.add_theme_font_size_override("font_size", 10)
	character_preview_eyebrow_label.add_theme_color_override("font_color", UI_CYAN)
	layout.add_child(character_preview_eyebrow_label)

	character_preview_title_label = Label.new()
	character_preview_title_label.text = _t("ui.store.preview.select_cosmetic")
	character_preview_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_preview_title_label.add_theme_font_size_override("font_size", 14)
	character_preview_title_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(character_preview_title_label)
	selection_title_label = character_preview_title_label

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
		direction_button.text = _t("ui.store.preview.direction.%s" % direction_id)
		direction_button.custom_minimum_size = Vector2(51, 27)
		direction_button.focus_mode = Control.FOCUS_NONE
		direction_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		direction_button.pressed.connect(_select_character_preview_direction.bind(direction_id))
		character_preview_direction_row.add_child(direction_button)
		character_preview_direction_buttons[direction_id] = direction_button

	mount_preview_controls = HBoxContainer.new()
	mount_preview_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	mount_preview_controls.add_theme_constant_override("separation", 8)
	mount_preview_controls.visible = false
	layout.add_child(mount_preview_controls)
	mount_preview_shiny_toggle = Button.new()
	mount_preview_shiny_toggle.toggle_mode = true
	mount_preview_shiny_toggle.icon = PREVIEW_SHINY_ICON
	mount_preview_shiny_toggle.toggled.connect(_on_mount_preview_shiny_toggled)
	mount_preview_controls.add_child(mount_preview_shiny_toggle)
	mount_preview_animation_toggle = Button.new()
	mount_preview_animation_toggle.toggle_mode = true
	mount_preview_animation_toggle.button_pressed = mount_preview_animated
	mount_preview_animation_toggle.toggled.connect(_on_mount_preview_animation_toggled)
	mount_preview_controls.add_child(mount_preview_animation_toggle)
	_refresh_mount_preview_controls()

	character_preview_palette = VBoxContainer.new()
	character_preview_palette.visible = false
	character_preview_palette.add_theme_constant_override("separation", 4)
	layout.add_child(character_preview_palette)

	character_preview_color_label = Label.new()
	_set_localized_property(character_preview_color_label, "text", "ui.store.preview.color")
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
	_set_localized_property(custom_color_label, "text", "ui.store.preview.custom")
	custom_color_label.add_theme_font_size_override("font_size", 10)
	custom_color_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	custom_color_row.add_child(custom_color_label)

	character_preview_color_picker = ColorPickerButton.new()
	_set_localized_property(
		character_preview_color_picker,
		"tooltip_text",
		"ui.store.preview.choose_color"
	)
	character_preview_color_picker.custom_minimum_size = Vector2(54, 24)
	character_preview_color_picker.focus_mode = Control.FOCUS_NONE
	character_preview_color_picker.color_changed.connect(_select_character_preview_custom_color)
	custom_color_row.add_child(character_preview_color_picker)

	character_preview_hex_input = LineEdit.new()
	character_preview_hex_input.name = "CharacterPreviewHexInput"
	character_preview_hex_input.placeholder_text = "#RRGGBB"
	character_preview_hex_input.max_length = 7
	character_preview_hex_input.custom_minimum_size = Vector2(88, 24)
	_set_localized_property(
		character_preview_hex_input,
		"tooltip_text",
		"ui.store.preview.hex_tooltip"
	)
	character_preview_hex_input.text_changed.connect(_on_character_preview_hex_text_changed)
	character_preview_hex_input.text_submitted.connect(_commit_character_preview_hex_color)
	character_preview_hex_input.focus_exited.connect(_commit_character_preview_hex_color)
	_apply_line_edit_style(character_preview_hex_input)
	custom_color_row.add_child(character_preview_hex_input)

	character_preview_note_label = Label.new()
	_set_localized_property(
		character_preview_note_label,
		"text",
		"ui.store.preview.chroma_included"
	)
	character_preview_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_preview_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_preview_note_label.add_theme_font_size_override("font_size", 10)
	character_preview_note_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(character_preview_note_label)

	selection_description_label = Label.new()
	selection_description_label.text = _t("ui.store.selection.description")
	selection_description_label.custom_minimum_size = Vector2(0, 46)
	selection_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_description_label.add_theme_font_size_override("font_size", 11)
	selection_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(selection_description_label)

	payment_select = OptionButton.new()
	payment_select.name = "StorePaymentMethod"
	payment_select.custom_minimum_size = Vector2(0, 32)
	_apply_cosmetic_item_category_style(payment_select)
	payment_select.add_theme_constant_override("icon_max_width", 16)
	payment_select.add_item(_t("ui.store.voucher.pay_gems"))
	payment_select.add_item(_t("ui.store.voucher.pay_voucher"))
	payment_select.set_item_icon(0, GEM_ICON)
	payment_select.set_item_icon(1, preload("res://assets/ui/store_credit_card.svg"))
	var payment_popup := payment_select.get_popup()
	payment_popup.add_theme_constant_override("icon_max_width", 16)
	payment_popup.add_theme_constant_override("h_separation", 8)
	payment_popup.add_theme_constant_override("v_separation", 8)
	payment_popup.add_theme_font_size_override("font_size", 10)
	payment_popup.add_theme_color_override("font_color", UI_TEXT)
	payment_select.item_selected.connect(func(_index: int) -> void: _refresh_purchase_state())
	layout.add_child(payment_select)
	voucher_notice_label = Label.new()
	voucher_notice_label.name = "VoucherBindingNotice"
	voucher_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voucher_notice_label.add_theme_font_size_override("font_size", 10)
	voucher_notice_label.add_theme_color_override("font_color", UI_GOLD)
	layout.add_child(voucher_notice_label)

	var checkout_margin := MarginContainer.new()
	checkout_margin.add_theme_constant_override("margin_left", 11)
	checkout_margin.add_theme_constant_override("margin_right", 11)
	checkout_margin.add_theme_constant_override("margin_top", 6)
	checkout_margin.add_theme_constant_override("margin_bottom", 11)
	panel_layout.add_child(checkout_margin)
	var checkout_row := HBoxContainer.new()
	checkout_row.add_theme_constant_override("separation", 8)
	checkout_margin.add_child(checkout_row)

	selection_price_label = Label.new()
	selection_price_label.text = "—"
	selection_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_price_label.add_theme_font_size_override("font_size", 15)
	selection_price_label.add_theme_color_override("font_color", UI_GOLD)
	checkout_row.add_child(selection_price_label)

	purchase_button = Button.new()
	_set_localized_property(purchase_button, "text", "ui.store.purchase")
	_set_localized_property(purchase_button, "tooltip_text", "ui.store.purchase_select")
	purchase_button.custom_minimum_size = Vector2(132, 36)
	purchase_button.focus_mode = Control.FOCUS_NONE
	purchase_button.disabled = true
	purchase_button.pressed.connect(_on_purchase_pressed)
	_apply_text_button_style(purchase_button, UI_PURPLE)
	checkout_row.add_child(purchase_button)

	status_label = Label.new()
	status_label.text = _t("ui.store.status.loading")
	status_label.custom_minimum_size = Vector2(0, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	_set_localized_property(status_label, "tooltip_text", "ui.store.safety")
	layout.add_child(status_label)

	_refresh_character_preview_direction_buttons()
	_refresh_character_preview()
	return panel


func _select_category(category_id: String) -> void:
	if not CATEGORY_ORDER.has(category_id):
		return
	var category_changed := active_category != category_id
	active_category = category_id
	if category_changed and category_id == "cosmetics":
		active_cosmetic_filter_group = "outfits"
		active_cosmetic_subcategory = "outfits"
		active_cosmetic_gender_filter = "mine"
	selected_item_id = ""
	if category_changed and catalog_search_text != "":
		catalog_search_text = ""
		if catalog_search_input != null:
			catalog_search_input.set_block_signals(true)
			catalog_search_input.text = ""
			catalog_search_input.set_block_signals(false)
	for category_key: String in CATEGORY_ORDER:
		var button := category_buttons.get(category_key) as Button
		if button != null:
			_apply_category_button_style(button, category_key == active_category)
	if hero_title_label != null:
		hero_title_label.text = _category_text(active_category, "label")
	if hero_description_label != null:
		hero_description_label.text = _category_text(active_category, "description")
		hero_description_label.tooltip_text = _t("ui.store.featured.explanation") if active_category == "featured" else ""
	_refresh_cosmetic_subcategory_bar()
	_refresh_mount_mode_bar()
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


func _on_cosmetic_gender_filter_selected(index: int) -> void:
	if cosmetic_gender_control == null or index < 0:
		return
	var filter_id := str(cosmetic_gender_control.get_item_metadata(index))
	if not ["mine", "other", "all"].has(filter_id):
		return
	active_cosmetic_gender_filter = filter_id
	selected_item_id = ""
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
	if cosmetic_gender_control != null:
		for index: int in range(cosmetic_gender_control.item_count):
			var filter_id := str(cosmetic_gender_control.get_item_metadata(index))
			cosmetic_gender_control.set_item_text(index, _t("ui.store.cosmetic.gender.%s" % filter_id))
			if filter_id == active_cosmetic_gender_filter:
				cosmetic_gender_control.select(index)
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

	var catalog_items: Array[Dictionary] = []
	if active_category == "featured":
		for item_id: String in _featured_items():
			var featured_item := _catalog_item(item_id)
			if not featured_item.is_empty():
				catalog_items.append(featured_item)
	else:
		catalog_items.assign(CATALOG)

	if active_catalog_sort != "default":
		catalog_items.sort_custom(_catalog_item_before)
	for item: Dictionary in catalog_items:
		var categories: Array = item.get("categories", [])
		if active_category != "featured" and not categories.has(active_category):
			continue
		if active_category == "cosmetics" and not _matches_cosmetic_subcategory(item):
			continue
		if active_category == "mounts" and Mounts.get_mount_movement_mode(_mount_box_mount_id(str(item.get("id", "")))) != active_mount_mode:
			continue
		if not _item_matches_catalog_search(item):
			continue
		if not _matches_catalog_filter(item):
			continue
		var card := _create_product_card(item)
		product_grid.add_child(card)
		product_buttons[str(item.get("id", ""))] = card
		_apply_product_card_style(card, str(item.get("id", "")) == selected_item_id)
	if selected_item_id != "" and not product_buttons.has(selected_item_id):
		selected_item_id = ""
		_reset_selection_footer()
		_refresh_character_preview()
	if catalog_results_label != null:
		catalog_results_label.text = (
			_t("ui.store.no_results")
			if product_buttons.is_empty()
			else _t("ui.store.results", {"count": product_buttons.size()})
		)


func _refresh_category_visibility() -> void:
	if not store_catalog_loaded:
		return
	for category_id: String in CATEGORY_ORDER:
		var button := category_buttons.get(category_id) as Button
		if button != null:
			button.visible = _category_has_available_items(category_id)
	var active_button := category_buttons.get(active_category) as Button
	if active_button != null and not active_button.visible:
		_select_category("featured")


func _category_has_available_items(category_id: String) -> bool:
	var item_ids: Array[String] = []
	if category_id == "featured":
		item_ids.assign(_featured_items())
	else:
		for item: Dictionary in CATALOG:
			var categories: Array = item.get("categories", [])
			if categories.has(category_id):
				if bool(item.get("informational", false)):
					return true
				item_ids.append(str(item.get("id", "")))
	for item_id: String in item_ids:
		if _gem_price(item_id) >= 0:
			return true
	return false


func _featured_items() -> Array[String]:
	if featured_selection_loaded:
		return featured_item_ids
	var fallback: Array[String] = []
	for item_id: String in FEATURED_FALLBACK_ITEM_ORDER:
		if not store_catalog_loaded or _gem_price(item_id) >= 0:
			fallback.append(item_id)
	return fallback


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
		_item_name(item),
		_item_description(item),
		str(item.get("badge", "")),
		str(item.get("cosmetic_subcategory", "")),
	])
	var searchable_text := " ".join(searchable_parts).to_lower()
	return searchable_text.contains(catalog_search_text)


func _matches_cosmetic_subcategory(item: Dictionary) -> bool:
	if not _matches_cosmetic_gender_filter(item):
		return false
	if active_cosmetic_filter_group == "all":
		return true
	if active_cosmetic_filter_group == "outfits":
		return _item_has_cosmetic_subcategory(item, "outfits")
	if _item_has_cosmetic_subcategory(item, "outfits"):
		return false
	if active_cosmetic_subcategory == "all":
		return true
	return _item_has_cosmetic_subcategory(item, active_cosmetic_subcategory)


func _matches_cosmetic_gender_filter(item: Dictionary) -> bool:
	var genders := _item_genders(item)
	match active_cosmetic_gender_filter:
		"mine":
			return genders.is_empty() or genders.has(trainer_gender)
		"other":
			var other_gender := "female" if trainer_gender == "male" else "male"
			return genders.has(other_gender) and not genders.has(trainer_gender)
		_:
			return true


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
	button.custom_minimum_size = Vector2(0, 140)
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
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 3)
	margin.add_child(layout)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_text := _badge_text(str(item.get("badge", "CONCEPT")))
	var compatibility_badge := _item_gender_badge(item)
	badge.text = (
		"%s · %s" % [compatibility_badge, badge_text]
		if compatibility_badge != ""
		else badge_text
	)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", UI_PURPLE)
	layout.add_child(badge)
	if active_category == "featured":
		var selection_badge := Label.new()
		selection_badge.name = "FeaturedSelectionBadge"
		selection_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_badge.text = _t("ui.store.featured.popular" if popular_item_ids.has(item_id) else "ui.store.featured.curated")
		selection_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_badge.add_theme_font_size_override("font_size", 10)
		selection_badge.add_theme_color_override("font_color", UI_CYAN)
		layout.add_child(selection_badge)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.custom_minimum_size = Vector2(0, 50)
	layout.add_child(icon_center)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(50, 50)
	icon_frame.add_theme_stylebox_override("panel", _panel_style(Color("#171126cc"), Color("#503b7080"), 10, 1))
	icon_center.add_child(icon_frame)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(center)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cosmetic_icon := CharacterAppearanceService.get_store_cosmetic_item_icon(
		item_id,
		_preview_gender_for_item(item)
	)
	icon.texture = Mounts.get_mount_icon_texture(_mount_box_mount_id(item_id)) if not _mount_box_mount_id(item_id).is_empty() else cosmetic_icon if cosmetic_icon != null else item.get("icon") as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	center.add_child(icon)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = _t("ui.credit_card.voucher_short", {"amount": _format_number(int(item.get("price", 0)))}) if item_id.begins_with("aether-credit-voucher-") else _item_name(item)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(title)

	var price := Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var authoritative_price := _gem_price(item_id)
	price.text = (
		_t("ui.store.patreon.external_membership")
		if bool(item.get("informational", false))
		else _t("ui.store.coming_later")
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

	selection_title_label.text = _item_name(item)
	var description := _item_description(item)
	var compatibility_note := _item_gender_compatibility_note(item)
	selection_description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT
		if bool(item.get("informational", false)) or item_id.begins_with("aether-blessing-voucher-")
		else HORIZONTAL_ALIGNMENT_CENTER
	)
	selection_description_label.text = (
		"%s · %s" % [description, compatibility_note]
		if compatibility_note != ""
		else description
	)
	var authoritative_price := _gem_price(item_id)
	selection_price_label.text = (
		_t(_patreon_status_key())
		if bool(item.get("informational", false))
		else _t("ui.store.coming_later")
		if store_catalog_loaded and authoritative_price < 0
		else _mount_box_price_text(authoritative_price if authoritative_price >= 0 else int(item.get("price", 0)))
		if not _mount_box_mount_id(item_id).is_empty()
		else "◆ %s" % _format_number(authoritative_price if authoritative_price >= 0 else int(item.get("price", 0)))
	)
	_refresh_purchase_state()
	_refresh_character_preview()


func _reset_selection_footer() -> void:
	if selection_title_label != null:
		selection_title_label.text = _t("ui.store.selection.title")
	if selection_description_label != null:
		selection_description_label.text = _t("ui.store.selection.description")
	if selection_price_label != null:
		selection_price_label.text = "—"
	if status_label != null:
		status_label.text = _t("ui.store.selection.title")
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
	var item := _catalog_item(selected_item_id)
	var preview_gender := _preview_gender_for_item(item)
	var is_outfit := _item_has_cosmetic_subcategory(item, "outfits")
	var body_id := str(trainer_appearance.get("body", ""))
	if preview_gender != trainer_gender or not CharacterAppearanceService.body_supports_layered_parts(body_id, preview_gender):
		body_id = (
			CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID
			if preview_gender == "female"
			else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
		)
	body_id = CharacterAppearanceService.resolve_body_model_id(body_id, preview_gender)
	var preview_hair := (
		CharacterAppearanceService.deserialize_part_id(str(trainer_appearance.get("hair", "")))
		if preview_gender == trainer_gender and trainer_appearance.has("hair")
		else CharacterAppearanceService.get_default_part_id("hair", preview_gender)
	)
	var appearance := {
		"body": body_id,
		"gender": preview_gender,
		"hair": preview_hair,
		"headgear": "",
		"facial_hair": "",
		"facegear": "",
		"top": "" if is_outfit else CharacterAppearanceService.get_default_part_id("top", preview_gender),
		"bottom": "" if is_outfit else CharacterAppearanceService.get_default_part_id("bottom", preview_gender),
		"shoes": "" if is_outfit else CharacterAppearanceService.get_default_part_id("shoes", preview_gender),
		"hair_color": str(character_preview_colors.get("hair_color", CharacterAppearanceService.get_default_hair_color(preview_gender))),
		"facial_hair_color": str(character_preview_colors.get("facial_hair_color", "#ffffff")),
		"skin_tone": CharacterAppearanceService.resolve_skin_tone(
			str(trainer_appearance.get("body", body_id)),
			str(trainer_appearance.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE)),
			preview_gender
		),
		"eye_color": str(trainer_appearance.get("eye_color", CharacterAppearanceService.get_default_eye_color(preview_gender))),
		"facegear_color": str(character_preview_colors.get("facegear_color", "#ffffff")),
		"top_color": str(character_preview_colors.get("top_color", "#ffffff")),
		"bottom_color": str(character_preview_colors.get("bottom_color", "#ffffff")),
		"shoes_color": str(character_preview_colors.get("shoes_color", "#ffffff")),
	}
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
	var includes_hair := _preview_includes_hair(item)
	if not includes_hair and preview_gender == trainer_gender and trainer_appearance.has("hair"):
		appearance["hair_color"] = CharacterAppearanceService.resolve_hair_color(
			str(trainer_appearance.get("hair_color", "")), preview_gender
		)
	appearance.merge(STORE_PREVIEW_POLICY.resolve_hair(
		str(item.get("id", "")), "detail", preview_gender,
		str(appearance.get("headgear", "")), includes_hair,
		str(appearance["hair"]), str(appearance["hair_color"]),
		preview_gender == trainer_gender and trainer_appearance.has("hair")
	), true)
	return appearance


func _preview_includes_hair(item: Dictionary) -> bool:
	for part: Dictionary in _preview_parts_for_item(item):
		if CharacterAppearanceService.normalize_part_category(str(part.get("slot", ""))) == "hair" \
			and not str(part.get("appearance_id", "")).is_empty():
			return true
	return false


func _refresh_character_preview() -> void:
	if character_preview_viewport == null:
		return
	for child: Node in character_preview_viewport.get_children():
		character_preview_viewport.remove_child(child)
		child.queue_free()

	mount_preview_controls.visible = false
	var item := _catalog_item(selected_item_id)
	if not _mount_box_mount_id(selected_item_id).is_empty():
		_refresh_mount_rider_preview(item)
		return
	if item.is_empty():
		var base_preview := _create_character_preview_visual(_current_character_preview_appearance())
		if base_preview != null:
			character_preview_viewport.add_child(base_preview)
			base_preview.position = PREVIEW_AVATAR_POSITION
			base_preview.scale = PREVIEW_AVATAR_SCALE
			_disable_character_preview_processing(base_preview)
			_set_character_preview_direction(base_preview)
		character_preview_eyebrow_label.text = _t("ui.store.preview.details")
		character_preview_title_label.text = _t("ui.store.selection.title")
		character_preview_note_label.text = _t("ui.store.preview.choose_item")
		character_preview_direction_row.visible = false
		character_preview_palette.visible = false
		return
	if bool(item.get("guild_emblem_template", false)):
		var emblem_sprite := Sprite2D.new()
		emblem_sprite.name = "GuildEmblemStorePreview"
		emblem_sprite.texture = item.get("icon") as Texture2D
		emblem_sprite.position = Vector2(PREVIEW_VIEWPORT_SIZE) * 0.5
		emblem_sprite.scale = Vector2(4.0, 4.0)
		emblem_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		character_preview_viewport.add_child(emblem_sprite)
		character_preview_eyebrow_label.text = _t("ui.store.preview.for_guild")
		character_preview_title_label.text = _item_name(item)
		character_preview_note_label.text = _t("ui.store.preview.guild_template")
		character_preview_direction_row.visible = false
		character_preview_palette.visible = false
		return

	var preview_parts := _preview_parts_for_item(item)
	if preview_parts.is_empty():
		var item_sprite := Sprite2D.new()
		item_sprite.name = "StoreItemDetailPreview"
		item_sprite.texture = Mounts.get_mount_icon_texture(_mount_box_mount_id(str(item.get("id", "")))) if not _mount_box_mount_id(str(item.get("id", ""))).is_empty() else item.get("icon") as Texture2D
		item_sprite.position = Vector2(PREVIEW_VIEWPORT_SIZE) * 0.5
		var item_scale := 1.0
		if item_sprite.texture != null:
			var texture_size := item_sprite.texture.get_size()
			var largest_dimension := maxf(texture_size.x, texture_size.y)
			if largest_dimension > 0.0:
				item_scale = minf(3.0, 112.0 / largest_dimension)
		item_sprite.scale = Vector2.ONE * item_scale
		item_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		character_preview_viewport.add_child(item_sprite)
		character_preview_eyebrow_label.text = _t("ui.store.preview.details")
		character_preview_title_label.text = _item_name(item)
		character_preview_note_label.text = _badge_text(str(item.get("badge", "")))
		character_preview_direction_row.visible = false
		character_preview_palette.visible = false
		return

	character_preview_eyebrow_label.text = (
		_item_gender_badge(item)
		if not _item_matches_trainer_gender(item)
		else _t("ui.store.preview.on_trainer")
	)
	character_preview_direction_row.visible = true
	var appearance := _current_character_preview_appearance()
	var preview_visual := _create_character_preview_visual(appearance)
	if preview_visual != null:
		character_preview_viewport.add_child(preview_visual)
		preview_visual.position = PREVIEW_AVATAR_POSITION
		preview_visual.scale = PREVIEW_AVATAR_SCALE
		_disable_character_preview_processing(preview_visual)
		_set_character_preview_direction(preview_visual)

	var tint_key := ""
	for preview_part: Dictionary in preview_parts:
		tint_key = str(preview_part.get("tint", "")).strip_edges()
		if tint_key != "":
			break
	if character_preview_title_label != null:
		character_preview_title_label.text = (
			_item_name(item)
			if not preview_parts.is_empty()
			else _t("ui.store.preview.select_cosmetic")
		)
	if character_preview_note_label != null:
		character_preview_note_label.text = (
			_t("ui.store.preview.chroma_included")
			if tint_key != ""
			else _t("ui.store.preview.fixed_colours")
		)
		if _item_has_cosmetic_subcategory(item, "outfits") and not _preview_includes_hair(item):
			character_preview_note_label.text += "\n" + _t("ui.store.preview.hair_not_included")
	if character_preview_palette != null:
		character_preview_palette.visible = tint_key != ""
	if character_preview_color_label != null and tint_key != "":
		character_preview_color_label.text = (
			_t("ui.store.preview.hair_color")
			if tint_key == "hair_color"
			else _t("ui.store.preview.color")
		)
	_rebuild_character_preview_color_buttons(tint_key)
	_refresh_character_preview_color_buttons(tint_key)


func _create_character_preview_visual(appearance: Dictionary) -> Node2D:
	var visual_root := Node2D.new()
	for layer: Dictionary in [
		{"name": "CapeSprite", "z": 0},
		{"name": "BodySprite", "z": 0},
		{"name": "BottomSprite", "z": 1},
		{"name": "ShoesSprite", "z": 2},
		{"name": "TopSprite", "z": 3},
		{"name": "CapeOverlaySprite", "z": 3},
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
	var preview_gender := str(appearance.get("gender", trainer_gender))
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames := CharacterAppearanceService.get_skin_tinted_body_frames(
				str(appearance.get("body", "")),
				preview_gender,
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
	var preview_gender := str(appearance.get("gender", trainer_gender))
	var category := _character_preview_category_for_sprite(sprite.name)
	if category == "":
		return
	if not CharacterAppearanceService.body_supports_layered_parts(
		str(appearance.get("body", "")),
		preview_gender
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
		"CapeSprite":
			return "cape"
		"CapeOverlaySprite":
			return "cape_overlay"
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
	var preview_gender := str(appearance.get("gender", trainer_gender))
	match CharacterAppearanceService.normalize_part_category(category):
		"cape_overlay":
			return str(appearance.get("cape", "")).strip_edges()
		"hair":
			return CharacterAppearanceService.deserialize_part_id(
				str(appearance.get("hair", ""))
			)
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", preview_gender)
		"eyebrows":
			return CharacterAppearanceService.get_eyebrows_for_hair(
				str(appearance.get("hair", "")),
				preview_gender
			)
		_:
			return str(appearance.get(category, "")).strip_edges()


func _character_preview_part_frames(
	category: String,
	part_id: String,
	appearance: Dictionary
) -> SpriteFrames:
	var preview_gender := str(appearance.get("gender", trainer_gender))
	var normalized_category := CharacterAppearanceService.normalize_part_category(category)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			preview_gender,
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
			preview_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("hair_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "facial_hair" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			preview_gender,
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
			preview_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("facegear_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "top" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			preview_gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_character_preview_color(str(appearance.get("top_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "bottom" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			preview_gender,
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
	return CharacterAppearanceService.get_part_frames(category, part_id, preview_gender)


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
	if not _mount_box_mount_id(selected_item_id).is_empty():
		_update_mount_rider_preview()
		return
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


func _preview_gender_for_item(item: Dictionary) -> String:
	return CharacterAppearanceService.resolve_cosmetic_icon_gender(
		trainer_gender,
		_item_genders(item)
	)


func _item_gender_badge(item: Dictionary) -> String:
	var genders := _item_genders(item)
	if genders == ["male"]:
		return _t("ui.store.gender.male_only")
	if genders == ["female"]:
		return _t("ui.store.gender.female_only")
	return ""


func _item_gender_compatibility_note(item: Dictionary) -> String:
	var badge := _item_gender_badge(item)
	if badge == _t("ui.store.gender.male_only"):
		return _t("ui.store.gender.male_note")
	if badge == _t("ui.store.gender.female_only"):
		return _t("ui.store.gender.female_note")
	return ""


func _gem_price(item_id: String) -> int:
	if not authoritative_gem_prices.has(item_id):
		return -1
	return maxi(int(authoritative_gem_prices.get(item_id, -1)), 0)


func _refresh_purchase_state(update_status: bool = true) -> void:
	if purchase_button == null:
		return
	var eligible := bool(voucher_eligible_items.get(selected_item_id, false))
	if payment_select != null:
		payment_select.disabled = purchase_in_progress or store_catalog_loading or not store_catalog_loaded
		payment_select.set_item_disabled(1, not eligible)
		if not eligible:
			payment_select.select(0)
		payment_select.visible = not selected_item_id.is_empty() and selected_item_id != "patreon-supporter-preview"
	if voucher_notice_label != null:
		voucher_notice_label.visible = payment_select.visible
		voucher_notice_label.text = _t(
			"ui.store.voucher.binding" if _payment_currency() == "gift_voucher"
			else "ui.store.voucher.available" if eligible else "ui.store.voucher.unavailable"
		)
	if purchase_in_progress:
		purchase_button.disabled = true
		purchase_button.text = _t("ui.store.status.purchasing_short")
		purchase_button.tooltip_text = _t("ui.store.status.purchasing_tooltip")
		return
	purchase_button.text = _t("ui.store.purchase")
	if selected_item_id == "":
		purchase_button.disabled = true
		purchase_button.tooltip_text = _t("ui.store.purchase_select")
		return
	var selected_item := _catalog_item(selected_item_id)
	if bool(selected_item.get("informational", false)):
		var connected := bool(patreon_status.get("connected", false))
		purchase_button.disabled = patreon_action_in_progress or not bool(patreon_status.get("success", false)) or (
			not connected and not bool(patreon_status.get("available", false))
		)
		purchase_button.text = _t(
			"ui.store.patreon.opening" if patreon_action_in_progress
			else "ui.store.patreon.manage" if connected and bool(patreon_status.get("active", false))
			else "ui.store.patreon.view" if connected
			else "ui.store.patreon.connect" if bool(patreon_status.get("success", false))
			else "ui.store.patreon.status_unknown"
		)
		purchase_button.tooltip_text = _t(
			"ui.store.patreon.external_tooltip" if connected else "ui.store.patreon.portal_tooltip"
		)
		if update_status:
			status_label.text = _t(
				"ui.store.patreon.status_error_hint"
				if not bool(patreon_status.get("success", false))
				else "ui.store.patreon.benefits_pending_short"
				if not bool(patreon_status.get("benefitsEnabled", false))
				else _patreon_status_key()
			)
		return
	if store_catalog_loading or not store_catalog_loaded:
		purchase_button.disabled = true
		purchase_button.tooltip_text = _t("ui.store.status.loading_short")
		if update_status:
			status_label.text = _t("ui.store.status.loading")
		return
	var price := _gem_price(selected_item_id)
	if price >= 0:
		selection_price_label.text = (
			_t("ui.store.voucher.price", {"amount": _format_number(price)})
			if _payment_currency() == "gift_voucher"
			else _mount_box_price_text(price) if not _mount_box_mount_id(selected_item_id).is_empty()
			else "◆ %s" % _format_number(price)
		)
		purchase_button.icon = preload("res://assets/ui/store_credit_card.svg") if _payment_currency() == "gift_voucher" else null
		purchase_button.expand_icon = true
		purchase_button.add_theme_constant_override("icon_max_width", 16)
		purchase_button.text = _t("ui.store.voucher.buy" if _payment_currency() == "gift_voucher" else "ui.store.purchase_with_price", {
			"amount": _format_number(price),
		})
	if price < 0:
		purchase_button.disabled = true
		purchase_button.tooltip_text = _t("ui.store.error.preview_unavailable")
		if update_status:
			status_label.text = _t("ui.store.status.preview_only")
		return
	if _payment_currency() == "gift_voucher":
		purchase_button.disabled = voucher_balance < price
		purchase_button.tooltip_text = _t("ui.store.voucher.binding")
		if update_status:
			status_label.text = _t(
				"ui.store.voucher.insufficient" if voucher_balance < price else "ui.store.voucher.remaining",
				{"amount": _format_number(absi(voucher_balance - price))}
			)
		return
	if gem_balance < price:
		purchase_button.disabled = true
		purchase_button.tooltip_text = _t("ui.store.error.gems_needed", {
			"amount": _format_number(price - gem_balance),
		})
		if update_status:
			status_label.text = _t("ui.store.error.not_enough_gems", {
				"amount": _format_number(price - gem_balance),
			})
		return
	purchase_button.disabled = false
	purchase_button.tooltip_text = _t("ui.store.purchase_tooltip", {
		"amount": _format_number(price),
	})
	if update_status:
		status_label.text = _t("ui.store.status.ready_balance", {
			"amount": _format_number(gem_balance - price),
		})


func _on_purchase_pressed() -> void:
	if selected_item_id == "" or purchase_button.disabled:
		return
	if selected_item_id == "patreon-supporter-preview":
		_on_patreon_action_pressed()
		return
	if _payment_currency() == "gift_voucher":
		pending_voucher_purchase = {"itemId": selected_item_id, "colors": _selected_purchase_chroma_colors()}
		voucher_confirm_dialog.configure(
			_t("ui.store.voucher.confirm_title"),
			_t("ui.store.voucher.confirm", {
				"item": _item_name(_catalog_item(selected_item_id)),
				"price": _format_number(_gem_price(selected_item_id)),
				"balance": _format_number(voucher_balance - _gem_price(selected_item_id)),
			}),
			_t("common.confirm"),
			_t("common.cancel")
		)
		set_purchase_in_progress(true)
		voucher_confirm_dialog.popup_centered(Vector2i(540, 270))
		return
	set_purchase_in_progress(true)
	purchase_requested.emit(selected_item_id, _selected_purchase_chroma_colors(), "gems")


func _confirm_voucher_purchase() -> void:
	if pending_voucher_purchase.is_empty():
		return
	var pending := pending_voucher_purchase.duplicate(true)
	pending_voucher_purchase.clear()
	purchase_requested.emit(str(pending.itemId), pending.colors as Dictionary, "gift_voucher")


func _cancel_voucher_purchase() -> void:
	pending_voucher_purchase.clear()
	set_purchase_in_progress(false)


func _selected_purchase_chroma_colors() -> Dictionary:
	var colors := {}
	var item := _catalog_item(selected_item_id)
	for preview_part: Dictionary in _preview_parts_for_item(item):
		var slot := CharacterAppearanceService.normalize_part_category(
			str(preview_part.get("slot", ""))
		)
		var tint_key := str(preview_part.get("tint", "")).strip_edges()
		if slot == "" or tint_key == "":
			continue
		var normalized := CharacterAppearanceService.normalize_hex_color_code(
			str(character_preview_colors.get(tint_key, ""))
		)
		if normalized != "":
			colors[slot] = normalized
	return colors


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
	var accent := UI_PURPLE if selected else Color("#2b455a70")
	var background := Color("#17102be8") if selected else Color("#081522dc")
	button.add_theme_stylebox_override("normal", _button_style(background, accent, 11, 1))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, Color("#8e6cc1"), 11, 1))
	button.add_theme_stylebox_override("pressed", _button_style(UI_SURFACE_BASE, UI_PURPLE, 11, 1))
	button.add_theme_stylebox_override("focus", _button_style(background, accent, 11, 1))


func _apply_add_gems_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#24152e"))
	button.add_theme_color_override("font_hover_color", Color("#24152e"))
	button.add_theme_color_override("font_pressed_color", Color("#24152e"))
	button.add_theme_color_override("font_disabled_color", UI_MUTED_TEXT)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _button_style(Color("#f0cc70"), Color("#ffe4a5"), 9, 1))
	button.add_theme_stylebox_override("hover", _button_style(Color("#ffe1a0"), Color("#fff1c8"), 9, 1))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#d9af52"), UI_GOLD, 9, 1))
	button.add_theme_stylebox_override("focus", _button_style(Color("#f0cc70"), UI_PURPLE, 9, 2))
	button.add_theme_stylebox_override("disabled", _button_style(UI_SURFACE_INTERACTIVE, UI_BORDER_SOFT, 9, 1))


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


func _item_name(item: Dictionary) -> String:
	var name_key := str(item.get("name_key", ""))
	if name_key != "":
		return _t(name_key)
	var item_id := str(item.get("id", item.get("itemId", "")))
	var fallback := str(item.get("name", _t("ui.store.item")))
	var item_localization := get_node_or_null("/root/ItemLocalization")
	if item_localization == null:
		return fallback
	return str(item_localization.call("display_name", item_id, fallback))


func _item_description(item: Dictionary) -> String:
	var description_key := str(item.get("description_key", ""))
	if description_key != "":
		var description := _t(description_key)
		if bool(item.get("informational", false)):
			description += "\n" + _t("ui.store.patreon.extras")
			if bool(patreon_status.get("manualRole", false)):
				description += "\n" + _t("ui.store.patreon.manual_grant_note")
			if not bool(patreon_status.get("benefitsEnabled", false)):
				description += "\n" + _t("ui.store.patreon.benefits_pending")
		return description
	var item_id := str(item.get("id", item.get("itemId", "")))
	if item_id.begins_with("aether-blessing-voucher-"):
		return _t("ui.store.blessing.voucher_intro") + "\n" + _blessing_benefits_description()
	var fallback := str(item.get("description", ""))
	var item_localization := get_node_or_null("/root/ItemLocalization")
	if item_localization == null:
		return fallback
	return str(item_localization.call("short_description", item_id, fallback))


func _blessing_benefits_description() -> String:
	var benefits: Array[String] = []
	for benefit in ["shiny", "travel", "anchor", "shops", "badge"]:
		benefits.append("• " + _t("ui.store.blessing.benefit.%s" % benefit))
	return "\n".join(benefits)


func _category_text(category_id: String, field: String) -> String:
	var key := "ui.store.category.%s.%s" % [category_id, field]
	var translated := _t(key)
	if translated != key:
		return translated
	match field:
		"label": return str(CATEGORY_LABELS.get(category_id, category_id.capitalize()))
		"description": return str(CATEGORY_DESCRIPTIONS.get(category_id, ""))
		"promise": return str(CATEGORY_PROMISES.get(category_id, ""))
	return ""


func _subcategory_text(subcategory_id: String) -> String:
	var key := "ui.store.cosmetic.subcategory.%s" % subcategory_id
	var translated := _t(key)
	return (
		translated
		if translated != key
		else str(COSMETIC_SUBCATEGORY_LABELS.get(subcategory_id, subcategory_id.capitalize()))
	)


func _badge_text(value: String) -> String:
	var key := "ui.store.badge.%s" % value.to_lower().replace("-", "_").replace(" ", "_")
	var translated := _t(key)
	return translated if translated != key else value


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _on_locale_changed(_locale: String) -> void:
	_refresh_currency_info()
	for select: OptionButton in [catalog_filter_select, catalog_sort_select]:
		if select == null:
			continue
		var kind := "filter" if select == catalog_filter_select else "sort"
		for index: int in range(select.item_count):
			select.set_item_text(index, _t("ui.store." + kind + "." + str(select.get_item_metadata(index))))
	if payment_select != null:
		payment_select.set_item_text(0, _t("ui.store.voucher.pay_gems"))
		payment_select.set_item_text(1, _t("ui.store.voucher.pay_voucher"))
	set_voucher_balance(voucher_balance)
	if patreon_external_dialog != null:
		patreon_external_dialog.title = _t("ui.store.patreon.external_title")
		patreon_external_dialog.dialog_text = _t("ui.store.patreon.external_confirm")
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	for category_id: String in CATEGORY_ORDER:
		var button := category_buttons.get(category_id) as Button
		if button != null:
			button.text = _category_text(category_id, "label")
	for group_id: String in COSMETIC_FILTER_GROUP_ORDER:
		var group_button := cosmetic_filter_group_buttons.get(group_id) as Button
		if group_button != null:
			group_button.text = _t("ui.store.cosmetic.group.%s" % group_id)
	if cosmetic_item_category_select != null:
		for index: int in range(cosmetic_item_category_select.item_count):
			cosmetic_item_category_select.set_item_text(
				index,
				_subcategory_text(str(cosmetic_item_category_select.get_item_metadata(index)))
			)
	set_gem_balance(gem_balance)
	var previous_selection := selected_item_id
	_select_category(active_category)
	if product_buttons.has(previous_selection):
		_select_product(previous_selection)
	else:
		_reset_selection_footer()


func _mount_box_mount_id(item_id: String) -> String:
	if not item_id.ends_with("-mount-box"):
		return ""
	return Mounts.get_mount_id_for_unlock_item(item_id.trim_suffix("-box"))


func _mount_box_price_text(gems: int) -> String:
	return _t("ui.shiny_tracker.mounts.store_price", {"gems": _format_number(gems)})


func _mount_preview_id() -> String:
	var unlock_item_id := selected_item_id.trim_suffix("-box")
	if mount_preview_shiny:
		unlock_item_id = "shiny-" + unlock_item_id
	return Mounts.get_mount_id_for_unlock_item(unlock_item_id)


func _mount_preview_appearance() -> Dictionary:
	var appearance := CharacterAppearanceService.get_default_appearance(trainer_gender)
	appearance.merge(trainer_appearance, true)
	appearance["gender"] = trainer_gender
	return appearance


func _refresh_mount_rider_preview(item: Dictionary) -> void:
	var preview := load("res://scripts/ui/mount_rider_preview.gd").new() as Node2D
	preview.name = "MountRiderPreview"
	character_preview_viewport.add_child(preview)
	_update_mount_rider_preview()
	character_preview_eyebrow_label.text = _t("ui.store.preview.on_trainer")
	character_preview_title_label.text = _item_name(item)
	character_preview_note_label.text = _badge_text(str(item.get("badge", "")))
	character_preview_direction_row.visible = true
	_refresh_character_preview_direction_buttons()
	mount_preview_controls.visible = true
	_refresh_mount_preview_controls()
	character_preview_palette.visible = false


func _update_mount_rider_preview() -> void:
	var preview := character_preview_viewport.get_node_or_null("MountRiderPreview")
	if preview != null:
		preview.configure(_mount_preview_id(), _mount_preview_appearance(), character_preview_direction, mount_preview_animated, character_preview_viewport.size)


func _on_mount_preview_shiny_toggled(enabled: bool) -> void:
	mount_preview_shiny = enabled
	_refresh_mount_preview_controls()
	_update_mount_rider_preview()


func _on_mount_preview_animation_toggled(enabled: bool) -> void:
	mount_preview_animated = enabled
	_refresh_mount_preview_controls()
	_update_mount_rider_preview()


func _refresh_mount_preview_controls() -> void:
	_style_mount_preview_toggle(mount_preview_shiny_toggle, "ui.store.preview.shiny", UI_PURPLE)
	mount_preview_animation_toggle.icon = PREVIEW_PAUSE_ICON if mount_preview_animated else PREVIEW_PLAY_ICON
	_style_mount_preview_toggle(mount_preview_animation_toggle, "ui.store.preview.animation", UI_CYAN)


func _style_mount_preview_toggle(button: Button, label_key: String, accent: Color) -> void:
	var active := button.button_pressed
	var background := UI_SURFACE_INTERACTIVE.lerp(accent, 0.14) if active else UI_SURFACE_RAISED
	var border := accent if active else UI_BORDER_SOFT
	button.text = "%s · %s" % [_t(label_key), _t("ui.store.preview.state.on" if active else "ui.store.preview.state.off")]
	button.custom_minimum_size = Vector2(118, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_constant_override("icon_max_width", 14)
	button.add_theme_constant_override("h_separation", 5)
	button.expand_icon = true
	button.add_theme_color_override("font_color", accent if active else UI_MUTED_TEXT)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_hover_pressed_color", accent.lightened(0.15))
	button.add_theme_color_override("icon_normal_color", Color(0.65, 0.65, 0.65, 0.8))
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(background, border, 8, 1))
	button.add_theme_stylebox_override("pressed", _button_style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _button_style(UI_SURFACE_HOVER, accent, 8, 1))
	button.add_theme_stylebox_override("hover_pressed", _button_style(background.lightened(0.06), accent, 8, 1))
	button.add_theme_stylebox_override("focus", _button_style(Color.TRANSPARENT, accent, 8, 2))
