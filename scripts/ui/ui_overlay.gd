extends CanvasLayer

const MAX_PARTY_SIZE := 6
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const COLLAPSE_BUTTON_SIZE := Vector2(28, 28)
const COLLAPSE_BUTTON_MARGIN := 10.0
const ACTION_BAR_SLOT_SIZE := 52.0
const ACTION_BAR_MARGIN_X := 8.0
const ACTION_BAR_SLOT_GAP := 8.0
const UI_BASE_Z_INDEX := 100
const UI_ACTIVE_Z_INDEX := 1000
const UI_DRAG_Z_INDEX := 1100
const UI_MODAL_Z_INDEX := 2000
const UI_OVERLAY_BASE_LAYER := 1
const UI_OVERLAY_FOCUSED_LAYER := 20
const CHAT_MIN_SIZE := Vector2(360, 190)
const CHAT_MAX_SIZE := Vector2(760, 520)
const CHAT_RESIZE_BUTTON_GAP := 10.0
const CHAT_TABS_GAP := 8.0
const CHAT_BADGE_TEXT_COLOR: Color = Color("#07101d")
const CHAT_DEFAULT_NAME_COLOR := "#aeb8c5"
const CHAT_SEPARATOR_COLOR := "#778194"
const CHAT_MESSAGE_COLOR := "#d7dce8"
const CHAT_SYSTEM_LABEL_COLOR := "#d8b767"
const CHAT_SYSTEM_MESSAGE_COLOR := "#f0d992"
const CHAT_TAB_GENERAL := "general"
const CHAT_TAB_TRADE := "trade"
const CHAT_TAB_SYSTEM := "system"
const CHAT_CATEGORY_USER := "user"
const CHAT_CATEGORY_SYSTEM := "system"
const CHAT_CHANNEL_GLOBAL := "global"
const CHAT_CHANNEL_TRADE := "trade"
const STAFF_TOOLS_ROLE_IDS := ["staff", "admin", "owner", "developer", "moderator", "gamemaster"]
const IMPERSONATE_PERMISSION := "accounts:impersonate"
const DEV_TOOLS_PERMISSION := "generating"
const CONTENT_CREATOR_TOOLS_PERMISSION := "content:creator:tools"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE_SPRITE_LOADER := preload("res://scripts/battle/battle_ui/sprite_box.gd")
const BATTLE_SUMMARY_SLOT_BG_TEXTURE: Texture2D = preload("res://assets/background/battle/pokemon_x_and_y_battle_background_11_by_phoenixoflight92_d843okx-414w-2x.jpg")
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")
const APPEARANCE_CATEGORIES := [
	{"id": "body", "label": "Body"},
	{"id": "hair", "label": "Hair"},
	{"id": "headgear", "label": "Headgear"},
	{"id": "facegear", "label": "Facegear"},
	{"id": "top", "label": "Top"},
	{"id": "bottom", "label": "Bottom"},
	{"id": "shoes", "label": "Shoes"},
]
const HAIR_COLOR_SWATCHES := [
	{"id": "#ffffff", "label": "White", "color": Color("#ffffff")},
	{"id": "#2a2421", "label": "Black", "color": Color("#2a2421")},
	{"id": "#5a3728", "label": "Brown", "color": Color("#5a3728")},
	{"id": "#f4d77a", "label": "Blond", "color": Color("#f4d77a")},
	{"id": "#8a3030", "label": "Red", "color": Color("#8a3030")},
	{"id": "#5d49a8", "label": "Violet", "color": Color("#5d49a8")},
	{"id": "#2f6f7a", "label": "Teal", "color": Color("#2f6f7a")},
]
const EYE_COLOR_SWATCHES := [
	{"id": "#0fff00", "label": "Green", "color": Color("#0fff00")},
	{"id": "#3da5ff", "label": "Blue", "color": Color("#3da5ff")},
	{"id": "#7a4b2a", "label": "Brown", "color": Color("#7a4b2a")},
	{"id": "#6f50c9", "label": "Violet", "color": Color("#6f50c9")},
	{"id": "#f2d24b", "label": "Gold", "color": Color("#f2d24b")},
	{"id": "#e83b3b", "label": "Red", "color": Color("#e83b3b")},
]
const KANTO_BADGES := [
	{"id": "boulder", "name": "Boulder Badge", "texture": "res://assets/gym_badges/kanto_badges/Boulder_Badge.png", "unlocked": false},
	{"id": "cascade", "name": "Cascade Badge", "texture": "res://assets/gym_badges/kanto_badges/Cascade_Badge.png", "unlocked": false},
	{"id": "thunder", "name": "Thunder Badge", "texture": "res://assets/gym_badges/kanto_badges/Thunder_Badge.png", "unlocked": false},
	{"id": "rainbow", "name": "Rainbow Badge", "texture": "res://assets/gym_badges/kanto_badges/Rainbow_Badge.png", "unlocked": false},
	{"id": "soul", "name": "Soul Badge", "texture": "res://assets/gym_badges/kanto_badges/Soul_Badge.png", "unlocked": false},
	{"id": "marsh", "name": "Marsh Badge", "texture": "res://assets/gym_badges/kanto_badges/Marsh_Badge.png", "unlocked": false},
	{"id": "volcano", "name": "Volcano Badge", "texture": "res://assets/gym_badges/kanto_badges/Volcano_Badge.png", "unlocked": false},
	{"id": "earth", "name": "Earth Badge", "texture": "res://assets/gym_badges/kanto_badges/Earth_Badge.png", "unlocked": false},
]
const PLAYER_STATUS_AVATAR_VIEWPORT_SIZE := Vector2i(76, 76)
const PLAYER_STATUS_AVATAR_POSITION := Vector2(38, 52)
const PLAYER_STATUS_AVATAR_SCALE := Vector2(1.5, 1.5)
const TRAINER_CARD_SIZE := Vector2(700, 430)
const TRAINER_CARD_AVATAR_VIEWPORT_SIZE := Vector2i(160, 160)
const TRAINER_CARD_AVATAR_POSITION := Vector2(80, 112)
const TRAINER_CARD_AVATAR_SCALE := Vector2(2.7, 2.7)
const TRAINER_CARD_APPEARANCE_AVATAR_POSITION := Vector2(80, 100)
const TRAINER_CARD_APPEARANCE_AVATAR_SCALE := Vector2(1.6, 1.6)
const BAG_SIZE := Vector2(920, 620)
const MAIL_POPUP_SIZE := Vector2(760, 500)
const ITEM_DEX_SIZE := Vector2(920, 620)
const POKEDEX_SIZE := Vector2(1180, 720)
const POKEDEX_BASE_STAT_BAR_MAX := 200
const POKEMON_SUMMARY_SIZE := Vector2(620, 380)
const POKEMON_SUMMARY_BODY_HEIGHT := 333.0
const POKEMON_SUMMARY_LEFT_PANEL_WIDTH := 275.0
const POKEMON_SUMMARY_RIGHT_AREA_WIDTH := 320.0
const POKEMON_SUMMARY_CONTENT_PANEL_WIDTH := 320.0
const POKEMON_SUMMARY_CONTENT_PANEL_HEIGHT := 295.0
const POKEMON_SUMMARY_CONTENT_STACK_HEIGHT := 281.0
const POKEMON_SUMMARY_TAB_COLUMN_WIDTH := 64.0
const POKEMON_SUMMARY_ACCENT := Color("#62d7ff")
const POKEMON_SUMMARY_ACCENT_SOFT := Color("#62d7ffaa")
const POKEMON_SUMMARY_ACCENT_FAINT := Color("#62d7ff66")
const POKEMON_SUMMARY_ACCENT_DARK := Color("#063447")
const POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE := Vector2i(263, 180)
const POKEMON_SUMMARY_SPRITE_MAX_SIZE := Vector2(235, 155)
const POKEMON_SUMMARY_SPRITE_MIN_SCALE := 0.72
const POKEMON_SUMMARY_SPRITE_MAX_SCALE := 2.2
const POKEMON_SUMMARY_NATURE_BOOST_COLOR := Color("#7df27f")
const POKEMON_SUMMARY_NATURE_DROP_COLOR := Color("#ff8f4f")
const EVOLUTION_OVERLAY_STAGE_SIZE := Vector2(520, 360)
const EVOLUTION_OVERLAY_SPRITE_SIZE := Vector2(240, 220)
const EVOLUTION_OVERLAY_SPARKLE_COUNT := 18
const POKEMON_SUMMARY_NATURE_CHANGES := {
	"lonely": {"boosted": "atk", "lowered": "def"},
	"brave": {"boosted": "atk", "lowered": "spe"},
	"adamant": {"boosted": "atk", "lowered": "spa"},
	"naughty": {"boosted": "atk", "lowered": "spd"},
	"bold": {"boosted": "def", "lowered": "atk"},
	"relaxed": {"boosted": "def", "lowered": "spe"},
	"impish": {"boosted": "def", "lowered": "spa"},
	"lax": {"boosted": "def", "lowered": "spd"},
	"modest": {"boosted": "spa", "lowered": "atk"},
	"mild": {"boosted": "spa", "lowered": "def"},
	"quiet": {"boosted": "spa", "lowered": "spe"},
	"rash": {"boosted": "spa", "lowered": "spd"},
	"calm": {"boosted": "spd", "lowered": "atk"},
	"gentle": {"boosted": "spd", "lowered": "def"},
	"sassy": {"boosted": "spd", "lowered": "spe"},
	"careful": {"boosted": "spd", "lowered": "spa"},
	"timid": {"boosted": "spe", "lowered": "atk"},
	"hasty": {"boosted": "spe", "lowered": "def"},
	"jolly": {"boosted": "spe", "lowered": "spa"},
	"naive": {"boosted": "spe", "lowered": "spd"},
}
const POKEMON_TYPE_ICON_ROOT := "res://assets/sprites/types/small/"
const MOVE_LEARN_TYPE_LABEL_ROOT := "res://assets/sprites/types/"
const MOVE_CATEGORY_LABEL_PATHS := {
	"physical": "res://assets/battles/physical_move_label.png",
	"special": "res://assets/battles/special_move_label.png",
	"status": "res://assets/battles/status_move_label.png",
}
const ITEM_DEX_CAPTURE_BALL_MULTIPLIERS := {
	"poke-ball": 1.0,
	"pokeball": 1.0,
	"great-ball": 1.5,
	"ultra-ball": 2.0,
	"premier-ball": 1.0,
	"cherish-ball": 1.0,
	"luxury-ball": 1.0,
	"nest-ball": 1.0,
	"net-ball": 1.0,
	"dive-ball": 1.0,
	"repeat-ball": 1.0,
	"timer-ball": 1.0,
	"safari-ball": 1.5,
	"quick-ball": 1.0,
	"dusk-ball": 1.0,
	"heal-ball": 1.0,
	"beast-ball": 0.1,
	"gs-ball": 1.0,
	"fast-ball": 1.0,
	"lure-ball": 1.0,
	"level-ball": 1.0,
	"heavy-ball": 1.0,
	"love-ball": 1.0,
	"friend-ball": 1.0,
	"moon-ball": 1.0,
	"park-ball": 1.0,
	"sport-ball": 1.5,
	"dream-ball": 1.0,
}
const EXP_ITEM_IDS := {
	"rare-candy": true,
	"exp-candy-xs": true,
	"exp-candy-s": true,
	"exp-candy-m": true,
	"exp-candy-l": true,
	"exp-candy-xl": true,
}
const POKEMON_MAX_LEVEL := 100
const EXP_CANDY_EXPERIENCE := {
	"exp-candy-xs": 100,
	"exp-candy-s": 800,
	"exp-candy-m": 3000,
	"exp-candy-l": 10000,
	"exp-candy-xl": 30000,
}
const POKEMON_EV_TOTAL_LIMIT := 510
const POKEMON_EV_STAT_LIMIT := 252
const EV_ITEM_EFFECTS := {
	"hp-up": {"stat": "hp", "potency": 10},
	"protein": {"stat": "atk", "potency": 10},
	"iron": {"stat": "def", "potency": 10},
	"calcium": {"stat": "spa", "potency": 10},
	"zinc": {"stat": "spd", "potency": 10},
	"carbos": {"stat": "spe", "potency": 10},
	"health-wing": {"stat": "hp", "potency": 1},
	"muscle-wing": {"stat": "atk", "potency": 1},
	"resist-wing": {"stat": "def", "potency": 1},
	"genius-wing": {"stat": "spa", "potency": 1},
	"clever-wing": {"stat": "spd", "potency": 1},
	"swift-wing": {"stat": "spe", "potency": 1},
}
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
const MOVE_SUMMARY_INDEX_PATH := "res://data/move_summary_index.json"
const ABILITY_SUMMARY_INDEX_PATH := "res://data/ability_summary_index.json"
const SPECIAL_HOLDABLE_ITEM_IDS := {
	"blue-orb": true,
	"red-orb": true,
}
const BAG_ICON_ROOT := "res://assets/items/icons/"
const ITEM_DEX_ICON := preload("res://assets/ui/item_dex.png")
const BAG_CATEGORIES := [
	{"id": "general", "label": "General"},
	{"id": "pokeball", "label": "Pokeball"},
	{"id": "medicine", "label": "Medicine"},
	{"id": "machines", "label": "Machines"},
	{"id": "held_items", "label": "Held Items"},
	{"id": "power_stones", "label": "Mega & Z"},
	{"id": "cosmetics", "label": "Skin & Mounts"},
	{"id": "currency", "label": "Currency"},
]
const TRAINER_CARD_CYAN := Color("#00f5ff")
const TRAINER_CARD_GREEN := Color("#4cff76")
const UTC_TIME_REFRESH_INTERVAL_SECONDS := 1.0
const UI_BG := Color("#070b14e6")
const UI_BG_STRONG := Color("#05070bf2")
const UI_SLOT_BG := Color("#0d1625e6")
const UI_INPUT_BG := Color("#050912e8")
const UI_BORDER := Color("#d8b767")
const UI_BORDER_SOFT := Color("#315070")
const UI_BORDER_FOCUS := Color("#7aa7f4")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED_TEXT := Color("#aeb8c5")
const UI_MONEY := Color("#ffd45a")
const UI_PURPLE_HOVER := Color("#b980ff")
const UI_DANGER := Color("#ff6b74")
const UI_DANGER_BG := Color("#2a1015e8")
const UI_REPEL_BG := Color("#155f2be8")
const PLAYER_STATUS_CARD_BACKGROUND := UI_BG
const PLAYER_STATUS_CARD_BORDER := UI_BORDER_SOFT

enum DevPokemonPopupMode {
	POKEMON,
	TEAM,
	SPAWN,
}

@onready var root_control: Control = $Control
@onready var party_panel: PanelContainer = $Control/PartyPanel
@onready var party_container: VBoxContainer = $Control/PartyPanel/MarginContainer/VBoxContainer
@onready var party_slot_template: PanelContainer = $Control/PartyPanel/MarginContainer/VBoxContainer/PartySlot
@onready var chat_panel: PanelContainer = $Control/ChatPanel
@onready var location_panel: PanelContainer = $Control/LocationPanel
@onready var region_label: Label = $Control/LocationPanel/MarginContainer/HBoxContainer/VBoxContainer/MetaRow/RegionLabel
@onready var location_label: Label = $Control/LocationPanel/MarginContainer/HBoxContainer/VBoxContainer/LocationLabel
@onready var time_label: Label = $Control/LocationPanel/MarginContainer/HBoxContainer/VBoxContainer/MetaRow/TimeLabel
@onready var options_panel: PanelContainer = $Control/OptionsPanel
@onready var actions_panel: PanelContainer = $Control/ToggleActionsPanel
@onready var toggle_actions_collapse_button: Button = $Control/ToggleActionsCollapseButton
@onready var dex_actions_panel: PanelContainer = $Control/DexActionsPanel
@onready var dex_actions_row: HBoxContainer = $Control/DexActionsPanel/MarginContainer/HBoxContainer
@onready var dex_actions_collapse_button: Button = $Control/DexActionsCollapseButton
@onready var staff_actions_panel: PanelContainer = $Control/StaffActionsPanel
@onready var staff_actions_row: HBoxContainer = $Control/StaffActionsPanel/MarginContainer/HBoxContainer
@onready var staff_actions_collapse_button: Button = $Control/StaffActionsCollapseButton
@onready var message_scroll: ScrollContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll
@onready var message_list: VBoxContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList
@onready var message_entry_template: RichTextLabel = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList/MessageEntry
@onready var chat_tabs_panel: Control = $Control/ChatTabsPanel
@onready var general_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/GeneralButton
@onready var trade_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/TradeButton
@onready var system_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/SystemButton
@onready var chat_input_row: HBoxContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow
@onready var chat_input: LineEdit = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/ChatInput
@onready var dev_pokemon_button: Button = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/DevPokemonButton
@onready var send_button: Button = $Control/ChatPanel/MarginContainer/VBoxContainer/InputRow/SendButton
@onready var parse_pokemon_request: HTTPRequest = $ParsePokemonRequest
@onready var dev_pokemon_popup: PanelContainer = $Control/DevPokemonPopup
@onready var dev_pokemon_title: Label = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/Title
@onready var dev_pokemon_text: TextEdit = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/PokemonText
@onready var dev_pokemon_add_button: Button = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/ButtonRow/AddButton
@onready var dev_pokemon_close_button: Button = $Control/DevPokemonPopup/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var bag_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/BagSlot
@onready var bag_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/BagSlot/BagButton
@onready var socials_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/SocialsSlot
@onready var socials_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/SocialsSlot/SocialsButton
@onready var socials_attention_badge: Panel = $Control/OptionsPanel/MarginContainer/HBoxContainer/SocialsSlot/SocialsAttentionBadge
@onready var guild_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/GuildSlot
@onready var guild_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/GuildSlot/GuildButton
@onready var pvp_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/PvpSlot
@onready var pvp_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/PvpSlot/PvpButton
@onready var settings_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/SettingsSlot
@onready var settings_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/SettingsSlot/SettingsButton
@onready var settings_menu: PanelContainer = $Control/SettingsMenu
@onready var socials_menu: PanelContainer = $Control/SocialsMenu
@onready var socials_friend_list_button: Button = $Control/SocialsMenu/MarginContainer/VBoxContainer/FriendListButton
@onready var socials_mail_button: Button = $Control/SocialsMenu/MarginContainer/VBoxContainer/MailButton
@onready var socials_close_button: Button = $Control/SocialsMenu/MarginContainer/VBoxContainer/CloseButton
@onready var mail_popup: PanelContainer = $Control/MailPopup
@onready var mail_compose_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/HeaderRow/ComposeButton
@onready var mail_close_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var mail_inbox_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/MailTabRow/InboxButton
@onready var mail_sent_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/MailTabRow/SentButton
@onready var mail_list: VBoxContainer = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailListPanel/MarginContainer/MailListScroll/MailList
@onready var mail_empty_inbox_label: Label = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailListPanel/MarginContainer/MailListScroll/MailList/EmptyInboxLabel
@onready var mail_subject_label: Label = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/SubjectLabel
@onready var mail_sender_label: Label = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/SenderLabel
@onready var mail_body_label: Label = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/BodyScroll/BodyLabel
@onready var mail_attachment_list: VBoxContainer = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/AttachmentScroll/AttachmentList
@onready var mail_claim_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/ClaimButton
@onready var mail_reply_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/ReplyButton
@onready var mail_delete_button: Button = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel/MarginContainer/DetailStack/DeleteButton
@onready var mail_compose_popup: PanelContainer = $Control/MailComposePopup
@onready var mail_compose_recipient_input: LineEdit = $Control/MailComposePopup/MarginContainer/VBoxContainer/RecipientInput
@onready var mail_compose_subject_input: LineEdit = $Control/MailComposePopup/MarginContainer/VBoxContainer/SubjectInput
@onready var mail_compose_body_input: TextEdit = $Control/MailComposePopup/MarginContainer/VBoxContainer/BodyInput
@onready var mail_item_search_input: LineEdit = $Control/MailComposePopup/MarginContainer/VBoxContainer/ItemAttachmentRow/ItemSearchInput
@onready var mail_item_quantity: SpinBox = $Control/MailComposePopup/MarginContainer/VBoxContainer/ItemAttachmentRow/ItemQuantity
@onready var mail_add_item_button: Button = $Control/MailComposePopup/MarginContainer/VBoxContainer/ItemAttachmentRow/AddItemButton
@onready var mail_item_suggestions: VBoxContainer = $Control/MailComposePopup/MarginContainer/VBoxContainer/ItemSuggestions
@onready var mail_pokemon_option: OptionButton = $Control/MailComposePopup/MarginContainer/VBoxContainer/PokemonAttachmentRow/PokemonOption
@onready var mail_add_pokemon_button: Button = $Control/MailComposePopup/MarginContainer/VBoxContainer/PokemonAttachmentRow/AddPokemonButton
@onready var mail_selected_attachments_list: VBoxContainer = $Control/MailComposePopup/MarginContainer/VBoxContainer/SelectedAttachmentsScroll/SelectedAttachmentsList
@onready var mail_compose_send_button: Button = $Control/MailComposePopup/MarginContainer/VBoxContainer/ButtonRow/SendButton
@onready var mail_compose_close_button: Button = $Control/MailComposePopup/MarginContainer/VBoxContainer/ButtonRow/CloseButton
@onready var map_slot: PanelContainer = $Control/DexActionsPanel/MarginContainer/HBoxContainer/MapSlot
@onready var map_button: TextureButton = $Control/DexActionsPanel/MarginContainer/HBoxContainer/MapSlot/MapButton
@onready var running_shoes_slot: PanelContainer = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/RunningShoesSlot
@onready var running_shoes_button: TextureButton = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/RunningShoesSlot/RunningShoesButton
@onready var repel_slot: PanelContainer = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/RepelSlot
@onready var repel_toggle_button: TextureButton = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/RepelSlot/RepelToggle
@onready var follower_slot: PanelContainer = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/FollowerSlot
@onready var follower_toggle_button: TextureButton = $Control/ToggleActionsPanel/MarginContainer/HBoxContainer/FollowerSlot/FollowerToggle
@onready var item_dex_slot: PanelContainer = $Control/DexActionsPanel/MarginContainer/HBoxContainer/ItemDexSlot
@onready var item_dex_button: TextureButton = $Control/DexActionsPanel/MarginContainer/HBoxContainer/ItemDexSlot/ItemDexButton
@onready var pokedex_slot: PanelContainer = $Control/DexActionsPanel/MarginContainer/HBoxContainer/PokedexSlot
@onready var pokedex_button: TextureButton = $Control/DexActionsPanel/MarginContainer/HBoxContainer/PokedexSlot/PokedexButton
@onready var staff_tools_slot: PanelContainer = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/StaffToolsSlot
@onready var staff_tools_button: TextureButton = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/StaffToolsSlot/StaffToolsButton
@onready var content_creator_tools_slot: PanelContainer = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/ContentCreatorToolsSlot
@onready var content_creator_tools_button: TextureButton = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/ContentCreatorToolsSlot/ContentCreatorToolsButton
@onready var dev_actions_slot: PanelContainer = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot
@onready var dev_actions_button: TextureButton = $Control/StaffActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot/DevActionsButton
@onready var mail_notification_sound: AudioStreamPlayer = $Control/MailNotificationSound
@onready var hotkey_sidebar_panel: PanelContainer = $Control/HotkeySidebar
@onready var player_status_panel: PanelContainer = $Control/PlayerStatusPanel
@onready var player_status_name_label: Label = $Control/PlayerStatusPanel/MarginContainer/Row/InfoLayout/NameLabel
@onready var player_status_money_label: Label = $Control/PlayerStatusPanel/MarginContainer/Row/InfoLayout/MoneyRow/MoneyLabel
@onready var player_status_avatar_viewport: SubViewport = $Control/PlayerStatusPanel/MarginContainer/Row/AvatarFrame/ViewportContainer/AvatarViewport
@onready var dev_actions_popup: PanelContainer = $Control/DevActionsPopup
@onready var dev_add_pokemon_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/AddPokemonButton
@onready var dev_add_team_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/AddTeamButton
@onready var dev_spawn_pokemon_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/SpawnPokemonButton
@onready var dev_clear_party_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/ClearPartyButton
@onready var dev_actions_close_button: Button = $Control/DevActionsPopup/MarginContainer/VBoxContainer/CloseButton

var party_slots: Array = []
var dev_pokemon_popup_mode: int = DevPokemonPopupMode.POKEMON
var collapsible_panels: Dictionary = {}
var chat_resize_button: Button
var chat_resize_dragging := false
var chat_resize_drag_start_mouse := Vector2.ZERO
var chat_resize_drag_start_rect := Rect2()
var party_drag_start_index := -1
var party_dragging := false
var party_drag_visual: Control
var party_drag_source_slot: Control
var party_drag_pointer_offset := Vector2.ZERO
var party_drag_start_mouse_position := Vector2.ZERO
var ui_confirm_popup: PanelContainer
var ui_confirm_title_label: Label
var ui_confirm_message_label: Label
var ui_confirm_cancel_button: Button
var ui_confirm_confirm_button: Button
var ui_confirm_callback := Callable()
var ui_confirm_cancel_callback := Callable()
var move_learn_popup: PanelContainer
var move_learn_title_label: Label
var move_learn_message_label: Label
var move_learn_moves_container: VBoxContainer
var move_learn_status_label: Label
var move_learn_confirm_button: Button
var move_learn_skip_button: Button
var move_learn_move_buttons: Array[Button] = []
var move_learn_selected_replace_slot := -2
var move_learn_hover_panel: PanelContainer
var move_learn_queue: Array[Dictionary] = []
var move_learn_active_prompt: Dictionary = {}
var move_learn_pending_review_total := 0
var move_learn_pending_review_index := 0
var move_learn_processing := false
var evolution_prompt_popup: PanelContainer
var evolution_prompt_title_label: Label
var evolution_prompt_progress_label: Label
var evolution_prompt_message_label: Label
var evolution_prompt_level_label: Label
var evolution_prompt_status_label: Label
var evolution_prompt_old_sprite: TextureRect
var evolution_prompt_new_sprite: TextureRect
var evolution_prompt_confirm_button: Button
var evolution_prompt_skip_button: Button
var evolution_prompt_queue: Array[Dictionary] = []
var evolution_active_prompt: Dictionary = {}
var evolution_prompt_processing := false
var evolution_prompt_review_total := 0
var evolution_prompt_review_index := 0
var dev_clear_menu_popup: PanelContainer
var pvp_room_popup: PanelContainer
var pvp_history_status_label: Label
var pvp_history_list: VBoxContainer
var pvp_history_refresh_button: Button
var pvp_room_code_label: Label
var pvp_room_status_label: Label
var pvp_room_code_input: LineEdit
var pvp_create_room_button: Button
var pvp_join_room_button: Button
var pvp_copy_code_button: Button
var pvp_queue_status_label: Label
var pvp_queue_select: OptionButton
var pvp_join_queue_button: Button
var pvp_leave_queue_button: Button
var pvp_reconnect_battle_button: Button
var pvp_poll_timer: Timer
var pvp_poll_request: HTTPRequest
var pvp_active_room_code := ""
var pvp_active_queue_id := "casual_queue_v1"
var pvp_available_queues: Array[Dictionary] = []
var pvp_active_queue_entry_id := ""
var pvp_active_queue_match_id := ""
var pvp_queue_list_in_flight := false
var pvp_queue_polling_active := false
var pvp_queue_poll_in_flight := false
var pvp_queue_auto_open_in_flight := false
var pvp_history_in_flight := false
var pvp_poll_in_flight := false
var pvp_polling_active := false
var pvp_poll_elapsed := 0.0
var pvp_battle_starting := false
var staff_tools_popup: PanelContainer
var staff_impersonate_button: Button
var staff_impersonate_popup: PanelContainer
var staff_impersonate_token_input: LineEdit
var staff_impersonate_confirm_button: Button
var chat_submit_in_progress: bool = false
var active_chat_tab: String = CHAT_TAB_GENERAL
var pending_chat_pokemon_attachments: Array[Dictionary] = []
var chat_pokemon_attachment_buttons: Array[Button] = []
var hotkey_sidebar_dragging := false
var hotkey_sidebar_drag_offset := Vector2.ZERO
var trainer_card_popup: PanelContainer
var trainer_card_avatar_viewports: Array[SubViewport] = []
var trainer_card_money_label: Label
var trainer_card_playtime_label: Label
var trainer_card_name_label: Label
var trainer_card_body_buttons: Dictionary = {}
var trainer_card_part_buttons: Dictionary = {}
var trainer_card_color_buttons: Dictionary = {}
var trainer_card_appearance_save_button: Button
var trainer_card_appearance_status_label: Label
var trainer_card_has_unsaved_appearance_changes := false
var trainer_card_is_saving_appearance := false
var trainer_card_dragging: bool = false
var trainer_card_drag_offset := Vector2.ZERO
var bag_popup: PanelContainer
var bag_item_grid: GridContainer
var bag_search_input: LineEdit
var bag_category_buttons: Dictionary = {}
var active_bag_category := "general"
var bag_dragging := false
var bag_drag_offset := Vector2.ZERO
var bag_inventory_items: Array[Dictionary] = []
var bag_inventory_loaded := false
var bag_inventory_loading := false
var bag_item_use_popup: PanelContainer
var bag_item_use_title_label: Label
var bag_item_use_item_label: Label
var bag_item_use_quantity_spinbox: SpinBox
var bag_item_use_party_list: VBoxContainer
var bag_item_use_status_label: Label
var bag_item_use_confirm_button: Button
var bag_item_use_pending_item: Dictionary = {}
var bag_item_use_selected_slot := -1
var bag_item_use_in_progress := false
var mailbox_messages: Array[Dictionary] = []
var selected_mail_id := -1
var active_mail_box := "inbox"
var mail_dragging := false
var mail_drag_offset := Vector2.ZERO
var mail_compose_inventory_items: Array[Dictionary] = []
var mail_compose_party_pokemon: Array[Pokemon] = []
var mail_selected_item_attachments: Array[Dictionary] = []
var mail_selected_pokemon_ids: Array[int] = []
var mail_selected_item_for_attachment: Dictionary = {}
var socials_attention_sources: Dictionary = {}
var socials_friend_list_attention_badge: Panel
var socials_mail_attention_badge: Panel
var known_mail_ids: Dictionary = {}
var mail_ids_initialized: bool = false
var play_existing_mail_notification_on_next_inbox_load: bool = true
var mail_compose_help_button: Button
var mail_compose_help_popup: PanelContainer
var pokemon_summary_popup: PanelContainer
var pokemon_summary_left_panel: PanelContainer
var pokemon_summary_right_area: VBoxContainer
var pokemon_summary_content_panel: PanelContainer
var pokemon_summary_tab_column: HBoxContainer
var pokemon_summary_sprite: TextureRect
var pokemon_summary_sprite_viewport: SubViewport
var pokemon_summary_animated_sprite: AnimatedSprite2D
var pokemon_summary_sprite_loader: Node = BATTLE_SPRITE_LOADER.new()
var pokemon_summary_level_badge_panel: PanelContainer
var pokemon_summary_level_badge_label: Label
var pokemon_summary_ball_button: Button
var pokemon_summary_ball_icon: TextureRect
var pokemon_summary_ball_picker: PanelContainer
var pokemon_summary_ball_search_input: LineEdit
var pokemon_summary_ball_list: VBoxContainer
var pokemon_summary_pending_ball_item_id := ""
var pokemon_summary_pending_ball_card_key := ""
var pokemon_summary_type_icon_row: HBoxContainer
var pokemon_summary_title_label: Label
var pokemon_summary_id_label: Label
var pokemon_summary_meta_label: Label
var pokemon_summary_held_item_slot: PanelContainer
var pokemon_summary_held_item_slot_button: Button
var pokemon_summary_held_item_slot_icon: TextureRect
var pokemon_summary_held_item_slot_name_label: Label
var pokemon_summary_item_search_input: LineEdit
var pokemon_summary_hp_bar: ProgressBar
var pokemon_summary_hp_label: Label
var pokemon_summary_content_stack: VBoxContainer
var pokemon_summary_tab_buttons: Dictionary = {}
var pokemon_summary_shiny_badge: PanelContainer
var pokemon_summary_shiny_badge_label: Label
var pokemon_summary_active_tab := "general"
var pokemon_summary_sprite_side := "front"
var pokemon_summary_trainer_label: Label
var pokemon_summary_stats_list: VBoxContainer
var pokemon_summary_moves_list: VBoxContainer
var pokemon_summary_item_picker: PanelContainer
var pokemon_summary_item_list: VBoxContainer
var pokemon_summary_ev_allocate_popup: PanelContainer
var pokemon_summary_ev_allocate_stat_label: Label
var pokemon_summary_ev_allocate_current_label: Label
var pokemon_summary_ev_allocate_input: SpinBox
var pokemon_summary_ev_allocate_status_label: Label
var pokemon_summary_ev_allocate_confirm_button: Button
var pokemon_summary_ev_allocate_stat_id := ""
var pokemon_summary_preview_pokemon: Pokemon
var pokemon_summary_mode := "interactive"
var pokemon_summary_selected_slot := -1
var pokemon_summary_dragging := false
var pokemon_summary_drag_offset := Vector2.ZERO
var pokemon_summary_open_cards: Dictionary = {}
var pokemon_summary_active_card_key := ""
var pokemon_summary_dragging_card_key := ""
var pokemon_summary_next_card_offset_index := 0
var pokemon_summary_move_type_index: Dictionary = {}
var pokemon_summary_move_type_index_loaded := false
var pokemon_summary_move_summary_index: Dictionary = {}
var pokemon_summary_move_summary_index_loaded := false
var pokemon_summary_ability_summary_index: Dictionary = {}
var pokemon_summary_ability_summary_index_loaded := false
var evolution_overlay: Control
var evolution_stage: Control
var evolution_sprite_stage: Control
var evolution_title_label: Label
var evolution_message_label: Label
var evolution_continue_button: Button
var evolution_old_sprite: TextureRect
var evolution_new_sprite: TextureRect
var evolution_silhouette_sprite: TextureRect
var evolution_flash_rect: ColorRect
var evolution_ring_nodes: Array[Control] = []
var evolution_sparkle_nodes: Array[Control] = []
var evolution_tween: Tween
var evolution_silhouette_material: ShaderMaterial
var evolution_is_playing := false
var dev_add_button: Button
var dev_preview_evolution_button: Button
var dev_add_menu_popup: PanelContainer
var dev_add_item_button: Button
var dev_add_item_popup: PanelContainer
var dev_item_search_input: LineEdit
var dev_item_results_list: VBoxContainer
var dev_item_quantity_spinbox: SpinBox
var dev_item_confirm_button: Button
var dev_add_money_button: Button
var dev_add_money_popup: PanelContainer
var dev_money_amount_spinbox: SpinBox
var dev_money_confirm_button: Button
var dev_heal_party_button: Button
var dev_item_catalog: Array[Dictionary] = []
var dev_selected_item: Dictionary = {}
var dev_item_search_request_id := 0
var item_dex_popup: PanelContainer
var item_dex_search_input: LineEdit
var item_dex_results_list: VBoxContainer
var item_dex_icon: TextureRect
var item_dex_name_label: Label
var item_dex_meta_label: Label
var item_dex_description_label: Label
var item_dex_effect_section_label: Control
var item_dex_effect_label: Label
var item_dex_capture_section_label: Control
var item_dex_capture_label: Label
var item_dex_sources_label: Label
var item_dex_search_request_id := 0
var item_dex_dragging := false
var item_dex_drag_offset := Vector2.ZERO
var pokedex_popup: PanelContainer
var pokedex_search_input: LineEdit
var pokedex_results_list: VBoxContainer
var pokedex_name_label: Label
var pokedex_meta_label: Label
var pokedex_type_row: HBoxContainer
var pokedex_sprite: TextureRect
var pokedex_sprite_panel: PanelContainer
var pokedex_sprite_viewport: SubViewport
var pokedex_animated_sprite: AnimatedSprite2D
var pokedex_sprite_loader: Node = BATTLE_SPRITE_LOADER.new()
var pokedex_sprite_side := "front"
var pokedex_header_stats_stack: VBoxContainer
var pokedex_detail_stack: VBoxContainer
var pokedex_tab_buttons: Dictionary = {}
var pokedex_selected_species: Dictionary = {}
var pokedex_selected_species_id := ""
var pokedex_active_tab := "general"
var pokedex_search_request_id := 0
var pokedex_search_debounce_timer: Timer
var pokedex_species_list_icon_cache: Dictionary = {}
var pokedex_dragging := false
var pokedex_drag_offset := Vector2.ZERO
var displayed_money: int = -1
var displayed_location_map: Node
var utc_time_refresh_elapsed := UTC_TIME_REFRESH_INTERVAL_SECONDS
var staff_tools_visibility_key := ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("ui_overlay")
	layer = UI_OVERLAY_BASE_LAYER
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_player_status_card()
	_setup_trainer_card_popup()
	_setup_bag_popup()
	_setup_bag_item_use_popup()
	_setup_pokemon_summary_ev_allocate_popup()
	_build_party_slots()
	_setup_collapsible_panels()
	_setup_chat_resize_button()
	_setup_normal_ui_focus_groups()
	_setup_chat_pokemon_attachment_preview()
	_setup_ui_confirm_popup()
	_setup_move_learn_popup()
	_setup_evolution_prompt_popup()
	_setup_evolution_overlay()
	_setup_dev_clear_menu_popup()
	_setup_pvp_room_popup()
	_setup_dev_add_item_tools()
	_setup_staff_impersonation_tools()
	_setup_item_dex_button()
	_setup_item_dex_popup()
	_setup_pokedex_button()
	_setup_pokedex_popup()
	_apply_ui_z_index_policy()
	_apply_premium_overlay_styles()
	_apply_mail_ui_styles()
	_setup_socials_attention_badge()
	if mail_notification_sound != null and AudioServer.get_bus_index(SettingsManager.NOTIFICATION_BUS) >= 0:
		mail_notification_sound.bus = SettingsManager.NOTIFICATION_BUS
	_set_socials_attention("mail", false)
	_refresh_location_label()
	_refresh_utc_time_label(UTC_TIME_REFRESH_INTERVAL_SECONDS, true)
	_refresh_party()
	_load_mailbox.call_deferred()

	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)
	if not ChatRealtimeService.message_received.is_connected(_on_chat_realtime_message_received):
		ChatRealtimeService.message_received.connect(_on_chat_realtime_message_received)
	if not ChatRealtimeService.mail_received.is_connected(_on_realtime_mail_received):
		ChatRealtimeService.mail_received.connect(_on_realtime_mail_received)
	if not ChatRealtimeService.session_invalid.is_connected(_on_chat_session_invalid):
		ChatRealtimeService.session_invalid.connect(_on_chat_session_invalid)
	ChatRealtimeService.connect_chat.call_deferred()

	send_button.pressed.connect(_on_send_button_pressed)
	send_button.focus_mode = Control.FOCUS_NONE
	chat_input.keep_editing_on_text_submit = true
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	general_chat_tab_button.pressed.connect(_on_chat_tab_pressed.bind(CHAT_TAB_GENERAL))
	trade_chat_tab_button.pressed.connect(_on_chat_tab_pressed.bind(CHAT_TAB_TRADE))
	system_chat_tab_button.pressed.connect(_on_chat_tab_pressed.bind(CHAT_TAB_SYSTEM))
	general_chat_tab_button.focus_mode = Control.FOCUS_NONE
	trade_chat_tab_button.focus_mode = Control.FOCUS_NONE
	system_chat_tab_button.focus_mode = Control.FOCUS_NONE
	_apply_chat_tab_state()
	dev_pokemon_button.visible = false
	dev_pokemon_button.disabled = true
	dev_pokemon_add_button.pressed.connect(_on_dev_pokemon_add_button_pressed)
	dev_pokemon_close_button.pressed.connect(_on_dev_pokemon_close_button_pressed)
	_setup_icon_slot_hover(map_slot, map_button)
	_setup_icon_slot_hover(running_shoes_slot, running_shoes_button)
	_setup_icon_slot_hover(bag_slot, bag_button)
	_setup_icon_slot_hover(socials_slot, socials_button)
	_setup_icon_slot_hover(guild_slot, guild_button)
	_setup_icon_slot_hover(pvp_slot, pvp_button)
	_setup_icon_slot_hover(settings_slot, settings_button)
	_setup_icon_slot_hover(repel_slot, repel_toggle_button)
	_setup_icon_slot_hover(follower_slot, follower_toggle_button)
	_setup_icon_slot_hover(item_dex_slot, item_dex_button)
	_setup_icon_slot_hover(pokedex_slot, pokedex_button)
	_setup_icon_slot_hover(dev_actions_slot, dev_actions_button)
	_setup_icon_slot_hover(staff_tools_slot, staff_tools_button)
	_setup_icon_slot_hover(content_creator_tools_slot, content_creator_tools_button)
	_disable_icon_button_focus()
	map_button.pressed.connect(_on_map_button_pressed)
	bag_button.pressed.connect(_on_bag_button_pressed)
	socials_button.pressed.connect(_on_socials_button_pressed)
	socials_friend_list_button.pressed.connect(_on_socials_friend_list_button_pressed)
	socials_mail_button.pressed.connect(_on_socials_mail_button_pressed)
	socials_close_button.pressed.connect(_on_socials_close_button_pressed)
	mail_inbox_button.pressed.connect(_on_mail_box_selected.bind("inbox"))
	mail_sent_button.pressed.connect(_on_mail_box_selected.bind("sent"))
	mail_compose_button.pressed.connect(_on_mail_compose_button_pressed)
	mail_close_button.pressed.connect(_on_mail_close_button_pressed)
	mail_claim_button.pressed.connect(_on_mail_claim_button_pressed)
	mail_reply_button.pressed.connect(_on_mail_reply_button_pressed)
	mail_delete_button.pressed.connect(_on_mail_delete_button_pressed)
	mail_item_search_input.text_changed.connect(_on_mail_item_search_changed)
	mail_add_item_button.pressed.connect(_on_mail_add_item_attachment_pressed)
	mail_add_pokemon_button.pressed.connect(_on_mail_add_pokemon_attachment_pressed)
	mail_compose_send_button.pressed.connect(_on_mail_compose_send_button_pressed)
	mail_compose_close_button.pressed.connect(_on_mail_compose_close_button_pressed)
	guild_button.pressed.connect(_on_guild_button_pressed)
	pvp_button.pressed.connect(_on_pvp_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	running_shoes_button.set_pressed_no_signal(GameState.running_shoes_enabled)
	_set_icon_slot_active(running_shoes_slot, GameState.running_shoes_enabled)
	running_shoes_button.toggled.connect(_on_running_shoes_toggled)
	repel_toggle_button.set_pressed_no_signal(GameState.repel_enabled)
	repel_toggle_button.toggled.connect(_on_repel_toggle_toggled)
	follower_toggle_button.set_pressed_no_signal(GameState.show_follower)
	follower_toggle_button.toggled.connect(_on_follower_toggle_toggled)
	_load_toggle_preferences.call_deferred()
	dev_actions_button.pressed.connect(_on_dev_actions_button_pressed)
	staff_tools_button.pressed.connect(_on_staff_tools_button_pressed)
	item_dex_button.pressed.connect(_on_item_dex_button_pressed)
	pokedex_button.pressed.connect(_on_pokedex_button_pressed)
	content_creator_tools_button.pressed.connect(_on_content_creator_tools_button_pressed)
	hotkey_sidebar_panel.gui_input.connect(_on_hotkey_sidebar_gui_input)
	dev_add_pokemon_button.pressed.connect(_on_dev_add_pokemon_button_pressed)
	dev_add_team_button.visible = false
	dev_add_team_button.disabled = true
	dev_spawn_pokemon_button.pressed.connect(_on_dev_spawn_pokemon_button_pressed)
	dev_add_button.pressed.connect(_on_dev_add_button_pressed)
	dev_preview_evolution_button.pressed.connect(_on_dev_preview_evolution_button_pressed)
	dev_heal_party_button.pressed.connect(_on_dev_heal_party_button_pressed)
	dev_add_item_button.pressed.connect(_on_dev_add_item_button_pressed)
	dev_add_money_button.pressed.connect(_on_dev_add_money_button_pressed)
	dev_clear_party_button.pressed.connect(_on_dev_clear_party_button_pressed)
	dev_actions_close_button.pressed.connect(_on_dev_actions_close_button_pressed)
	dev_actions_popup.visible = false
	_refresh_dev_tools_visibility()
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)
	settings_menu.gui_input.connect(_on_focusable_overlay_panel_gui_input.bind(settings_menu))

func _play_mail_notification_sound() -> void:
	if mail_notification_sound == null:
		return
	if mail_notification_sound.playing:
		mail_notification_sound.stop()
	mail_notification_sound.play()

func _can_use_dev_tools() -> bool:
	return _has_user_permission(DEV_TOOLS_PERMISSION)

func _can_use_content_creator_tools() -> bool:
	return _has_user_permission(CONTENT_CREATOR_TOOLS_PERMISSION)

func _can_use_staff_tools() -> bool:
	var roles_value: Variant = AuthService.current_user.get("roles", [])
	if roles_value is Array:
		for role_value: Variant in roles_value:
			var role_id := ""
			if role_value is Dictionary:
				role_id = str((role_value as Dictionary).get("id", "")).strip_edges().to_lower()
			else:
				role_id = str(role_value).strip_edges().to_lower()
			if STAFF_TOOLS_ROLE_IDS.has(role_id):
				return true
	return _can_use_dev_tools() or _can_impersonate_accounts()

func _can_impersonate_accounts() -> bool:
	return _has_user_permission(IMPERSONATE_PERMISSION)

func _has_user_permission(permission: String) -> bool:
	var permissions_value: Variant = AuthService.current_user.get("permissions", [])
	if permissions_value is Array:
		var user_permissions: Array = permissions_value as Array
		for permission_value: Variant in user_permissions:
			if str(permission_value).strip_edges().to_lower() == permission:
				return true

	return false

func _refresh_dev_tools_visibility() -> void:
	var can_use_staff_tools: bool = _can_use_staff_tools()
	var can_use_dev_tools: bool = _can_use_dev_tools()
	var can_impersonate: bool = _can_impersonate_accounts()
	var can_use_content_creator_tools: bool = _can_use_content_creator_tools()
	var has_visible_staff_action: bool = can_impersonate or can_use_dev_tools or can_use_content_creator_tools
	PlayerSave.is_staff = can_use_staff_tools
	if content_creator_tools_slot != null:
		content_creator_tools_slot.visible = can_use_staff_tools and can_use_content_creator_tools
	if content_creator_tools_button != null:
		content_creator_tools_button.visible = can_use_staff_tools and can_use_content_creator_tools
		content_creator_tools_button.disabled = not can_use_content_creator_tools
	dev_actions_slot.visible = can_use_staff_tools and can_use_dev_tools
	dev_actions_button.visible = can_use_staff_tools and can_use_dev_tools
	dev_actions_button.disabled = not can_use_dev_tools
	if staff_tools_slot != null:
		staff_tools_slot.visible = can_use_staff_tools and can_impersonate
	if staff_tools_button != null:
		staff_tools_button.visible = can_use_staff_tools and can_impersonate
		staff_tools_button.disabled = not can_impersonate
	dev_add_pokemon_button.visible = can_use_dev_tools
	dev_add_pokemon_button.disabled = not can_use_dev_tools
	dev_add_team_button.disabled = true
	dev_spawn_pokemon_button.visible = can_use_dev_tools
	dev_spawn_pokemon_button.disabled = not can_use_dev_tools
	if dev_add_button != null:
		dev_add_button.visible = can_use_dev_tools
		dev_add_button.disabled = not can_use_dev_tools
	if dev_preview_evolution_button != null:
		dev_preview_evolution_button.visible = can_use_dev_tools
		dev_preview_evolution_button.disabled = not can_use_dev_tools
	if dev_heal_party_button != null:
		dev_heal_party_button.visible = can_use_dev_tools
		dev_heal_party_button.disabled = not can_use_dev_tools
	dev_clear_party_button.visible = can_use_dev_tools
	dev_clear_party_button.disabled = not can_use_dev_tools
	dev_pokemon_add_button.disabled = not can_use_dev_tools
	if dev_add_item_button != null:
		dev_add_item_button.visible = can_use_dev_tools
		dev_add_item_button.disabled = not can_use_dev_tools
	if dev_add_money_button != null:
		dev_add_money_button.visible = can_use_dev_tools
		dev_add_money_button.disabled = not can_use_dev_tools
	if staff_impersonate_button != null:
		staff_impersonate_button.visible = can_impersonate
		staff_impersonate_button.disabled = not can_impersonate
	if not can_impersonate:
		if staff_tools_popup != null:
			staff_tools_popup.visible = false
		if staff_impersonate_popup != null:
			staff_impersonate_popup.visible = false
	if not can_use_dev_tools:
		dev_actions_popup.visible = false
		dev_pokemon_popup.visible = false
		if dev_add_menu_popup != null:
			dev_add_menu_popup.visible = false
		if dev_add_item_popup != null:
			dev_add_item_popup.visible = false
		if dev_add_money_popup != null:
			dev_add_money_popup.visible = false
		if dev_clear_menu_popup != null:
			dev_clear_menu_popup.visible = false
	if not can_impersonate and staff_impersonate_popup != null:
		staff_impersonate_popup.visible = false
	_refresh_action_bar_layouts()
	_set_collapsible_panel_available("dex_actions", true)
	_set_collapsible_panel_available("staff_actions", can_use_staff_tools and has_visible_staff_action)

func _apply_mail_ui_styles() -> void:
	mail_popup.add_theme_stylebox_override("panel", _make_mail_outer_style())
	mail_compose_popup.add_theme_stylebox_override("panel", _make_mail_outer_style())
	_setup_mail_compose_help_button()
	_set_mail_popup_size()
	var mail_header_row: Control = $Control/MailPopup/MarginContainer/VBoxContainer/HeaderRow
	mail_header_row.mouse_filter = Control.MOUSE_FILTER_STOP
	if not mail_header_row.gui_input.is_connected(_on_mail_header_gui_input):
		mail_header_row.gui_input.connect(_on_mail_header_gui_input)
	var mail_list_panel: PanelContainer = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailListPanel
	var mail_detail_panel: PanelContainer = $Control/MailPopup/MarginContainer/VBoxContainer/BodyRow/MailDetailPanel
	mail_list_panel.add_theme_stylebox_override("panel", _make_mail_inner_style())
	mail_detail_panel.add_theme_stylebox_override("panel", _make_mail_inner_style())
	mail_subject_label.add_theme_color_override("font_color", UI_TEXT)
	mail_subject_label.add_theme_color_override("font_shadow_color", Color("#000000aa"))
	mail_subject_label.add_theme_constant_override("shadow_offset_x", 1)
	mail_subject_label.add_theme_constant_override("shadow_offset_y", 1)
	mail_sender_label.add_theme_color_override("font_color", Color("#f2cf78"))
	mail_body_label.add_theme_color_override("font_color", UI_TEXT)
	_apply_button_style(mail_compose_button, "primary")
	_apply_button_style(mail_close_button)
	_apply_button_style(mail_inbox_button, "primary")
	_apply_button_style(mail_sent_button)
	_apply_button_style(mail_claim_button, "primary")
	_apply_button_style(mail_reply_button)
	_apply_button_style(mail_delete_button, "danger")
	_apply_button_style(mail_add_item_button, "primary")
	_apply_button_style(mail_add_pokemon_button, "primary")
	_apply_button_style(mail_compose_send_button, "primary")
	_apply_button_style(mail_compose_close_button)
	_apply_line_edit_style(mail_compose_recipient_input)
	_apply_line_edit_style(mail_compose_subject_input)
	_apply_line_edit_style(mail_item_search_input)
	_apply_text_edit_style(mail_compose_body_input)

func _setup_mail_compose_help_button() -> void:
	if mail_compose_help_button != null:
		return

	var layout: VBoxContainer = $Control/MailComposePopup/MarginContainer/VBoxContainer
	var title_label: Label = $Control/MailComposePopup/MarginContainer/VBoxContainer/Title
	var title_index: int = title_label.get_index()
	layout.remove_child(title_label)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	layout.move_child(header, title_index)

	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	mail_compose_help_button = Button.new()
	mail_compose_help_button.text = "?"
	mail_compose_help_button.custom_minimum_size = Vector2(32, 30)
	mail_compose_help_button.focus_mode = Control.FOCUS_NONE
	mail_compose_help_button.tooltip_text = "Mail rules\nFee without attachments: 50\nFee with attachments: 400\nCooldown: 2 minutes\nMax item stacks: 5\nMax Pokemon: 5\nPokemon attachments cannot hold items."
	mail_compose_help_button.pressed.connect(_toggle_mail_compose_help_popup)
	header.add_child(mail_compose_help_button)
	_apply_button_style(mail_compose_help_button, "primary")
	_setup_mail_compose_help_popup()

func _setup_mail_compose_help_popup() -> void:
	if mail_compose_help_popup != null:
		return

	mail_compose_help_popup = PanelContainer.new()
	mail_compose_help_popup.name = "MailComposeHelpPopup"
	mail_compose_help_popup.visible = false
	mail_compose_help_popup.custom_minimum_size = Vector2(320, 220)
	mail_compose_help_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	mail_compose_help_popup.z_index = UI_BASE_Z_INDEX + 2
	mail_compose_help_popup.add_theme_stylebox_override("panel", _make_mail_outer_style())
	root_control.add_child(mail_compose_help_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	mail_compose_help_popup.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Mail Rules"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f5df9a"))
	layout.add_child(title)

	for line in [
		"Base fee: 50",
		"With attachments: 400",
		"Cooldown: 2 minutes",
		"Max item stacks: 5",
		"Max Pokemon: 5",
		"Pokemon cannot hold items.",
	]:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", UI_TEXT)
		layout.add_child(label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 32)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_mail_compose_help_popup)
	layout.add_child(close_button)
	_apply_button_style(close_button)

func _toggle_mail_compose_help_popup() -> void:
	if mail_compose_help_popup == null:
		return
	mail_compose_help_popup.visible = not mail_compose_help_popup.visible
	if mail_compose_help_popup.visible:
		_position_mail_compose_help_popup()
		_activate_ui_panel(mail_compose_help_popup)
	else:
		_deactivate_ui_panel(mail_compose_help_popup)

func _hide_mail_compose_help_popup() -> void:
	if mail_compose_help_popup != null:
		mail_compose_help_popup.visible = false
		_deactivate_ui_panel(mail_compose_help_popup)

func _position_mail_compose_help_popup() -> void:
	var parent_control: Control = mail_compose_help_popup.get_parent_control()
	if parent_control == null:
		return
	var target_position: Vector2 = mail_compose_popup.global_position + Vector2(mail_compose_popup.size.x - mail_compose_help_popup.custom_minimum_size.x, 42)
	var parent_size: Vector2 = parent_control.size
	var popup_size: Vector2 = mail_compose_help_popup.custom_minimum_size
	target_position.x = clamp(target_position.x, 0.0, max(parent_size.x - popup_size.x, 0.0))
	target_position.y = clamp(target_position.y, 0.0, max(parent_size.y - popup_size.y, 0.0))
	mail_compose_help_popup.global_position = target_position
	mail_compose_help_popup.size = popup_size

func _refresh_action_bar_layouts() -> void:
	_refresh_action_bar_layout(actions_panel)
	_refresh_action_bar_layout(dex_actions_panel)
	_refresh_action_bar_layout(staff_actions_panel)
	_position_collapsible_button("actions")
	_position_collapsible_button("dex_actions")
	_position_collapsible_button("staff_actions")

func _refresh_action_bar_layout(panel: PanelContainer) -> void:
	if panel == null:
		return
	var row := _get_scene_action_bar_row(panel)
	if row == null:
		return

	var visible_slots := 0
	for child: Node in row.get_children():
		var control := child as Control
		if control != null and control.visible:
			visible_slots += 1

	var slot_gap: float = float(max(visible_slots - 1, 0)) * ACTION_BAR_SLOT_GAP
	var width: float = (ACTION_BAR_MARGIN_X * 2.0) + (float(visible_slots) * ACTION_BAR_SLOT_SIZE) + slot_gap
	panel.custom_minimum_size.x = width
	panel.offset_left = -width

func _get_scene_action_bar_row(panel: PanelContainer) -> HBoxContainer:
	if panel == null or panel.get_child_count() <= 0:
		return null
	var margin_container := panel.get_child(0) as MarginContainer
	if margin_container == null or margin_container.get_child_count() <= 0:
		return null
	return margin_container.get_child(0) as HBoxContainer

func _apply_ui_z_index_policy() -> void:
	var panels: Array[Control] = [
		chat_panel,
		location_panel,
		options_panel,
		actions_panel,
		dex_actions_panel,
		staff_actions_panel,
		party_panel,
		player_status_panel,
		hotkey_sidebar_panel,
		bag_popup,
		pokemon_summary_popup,
		trainer_card_popup,
		dev_actions_popup,
		dev_pokemon_popup,
		dev_clear_menu_popup,
		pvp_room_popup,
		dev_add_item_popup,
		dev_add_money_popup,
		dev_add_menu_popup,
		staff_tools_popup,
		staff_impersonate_popup,
		item_dex_popup,
		pokedex_popup,
		settings_menu,
	]
	for context_value: Variant in pokemon_summary_open_cards.values():
		var context: Dictionary = context_value as Dictionary
		var summary_panel: Control = context.get("popup") as Control
		if summary_panel != null:
			panels.append(summary_panel)
	for panel: Control in panels:
		_set_ui_panel_base_z(panel)
	if chat_resize_button != null:
		chat_resize_button.z_index = UI_BASE_Z_INDEX
	for state_value: Variant in collapsible_panels.values():
		var state: Dictionary = state_value as Dictionary
		var button: Button = state.get("button") as Button
		if button != null:
			button.z_index = UI_BASE_Z_INDEX

func _set_ui_panel_base_z(panel: Control) -> void:
	if panel != null:
		panel.z_index = UI_BASE_Z_INDEX

func _focus_overlay_ui_layer() -> void:
	layer = UI_OVERLAY_FOCUSED_LAYER

func _focus_normal_ui_group(panel: Control) -> void:
	if panel == null:
		return
	_focus_overlay_ui_layer()
	panel.z_index = UI_ACTIVE_Z_INDEX
	panel.move_to_front()

func focus_battle_ui_layer() -> void:
	layer = UI_OVERLAY_BASE_LAYER

func _has_visible_priority_overlay_panel() -> bool:
	var panels: Array[Control] = [
		bag_popup,
		trainer_card_popup,
		dev_actions_popup,
		dev_pokemon_popup,
		dev_clear_menu_popup,
		pvp_room_popup,
		dev_add_item_popup,
		dev_add_money_popup,
		dev_add_menu_popup,
		staff_tools_popup,
		staff_impersonate_popup,
		item_dex_popup,
		pokedex_popup,
		settings_menu,
		socials_menu,
		mail_popup,
		mail_compose_popup,
	]
	for panel: Control in panels:
		if panel != null and panel.visible:
			return true
	for context_value: Variant in pokemon_summary_open_cards.values():
		var context: Dictionary = context_value as Dictionary
		var summary_panel: Control = context.get("popup") as Control
		if summary_panel != null and summary_panel.visible:
			return true
	return false

func _activate_ui_panel(panel: Control) -> void:
	if panel == null:
		return
	_focus_overlay_ui_layer()
	panel.z_index = UI_ACTIVE_Z_INDEX
	panel.move_to_front()

func _deactivate_ui_panel(panel: Control) -> void:
	_set_ui_panel_base_z(panel)
	if not _has_visible_priority_overlay_panel():
		layer = UI_OVERLAY_BASE_LAYER

func _on_focusable_overlay_panel_gui_input(event: InputEvent, panel: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_activate_ui_panel(panel)

func _on_normal_ui_group_gui_input(event: InputEvent, panel: Control) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_focus_normal_ui_group(panel)

func _connect_normal_ui_group_focus(control: Control, panel: Control, use_pass_filter := true) -> void:
	if control == null or panel == null:
		return

	if use_pass_filter:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	var focus_callable: Callable = Callable(self, "_on_normal_ui_group_gui_input").bind(panel)
	if not control.gui_input.is_connected(focus_callable):
		control.gui_input.connect(focus_callable)

func _connect_normal_ui_group_focus_tree(control: Control, panel: Control) -> void:
	if control == null or panel == null:
		return

	_connect_normal_ui_group_focus(control, panel, false)
	for child: Node in control.get_children():
		if child is Control:
			_connect_normal_ui_group_focus_tree(child as Control, panel)

func _setup_normal_ui_focus_groups() -> void:
	var panel_paths_by_group: Dictionary = {
		chat_panel: [
			^"ChatPanel",
			^"ChatPanel/MarginContainer",
			^"ChatPanel/MarginContainer/VBoxContainer",
			^"ChatPanel/MarginContainer/VBoxContainer/ChatScroll",
			^"ChatPanel/MarginContainer/VBoxContainer/InputRow",
			^"ChatTabsPanel",
			^"ChatTabsPanel/TabRow",
		],
		party_panel: [
			^"PartyPanel",
			^"PartyPanel/MarginContainer",
			^"PartyPanel/MarginContainer/VBoxContainer",
		],
		actions_panel: [
			^"ToggleActionsPanel",
			^"ToggleActionsPanel/MarginContainer",
			^"ToggleActionsPanel/MarginContainer/HBoxContainer",
		],
		dex_actions_panel: [
			^"DexActionsPanel",
			^"DexActionsPanel/MarginContainer",
			^"DexActionsPanel/MarginContainer/HBoxContainer",
		],
		staff_actions_panel: [
			^"StaffActionsPanel",
			^"StaffActionsPanel/MarginContainer",
			^"StaffActionsPanel/MarginContainer/HBoxContainer",
		],
		options_panel: [
			^"OptionsPanel",
			^"OptionsPanel/MarginContainer",
			^"OptionsPanel/MarginContainer/HBoxContainer",
		],
		hotkey_sidebar_panel: [
			^"HotkeySidebarPanel",
		],
		player_status_panel: [
			^"PlayerStatusPanel",
		],
	}

	for panel_value: Variant in panel_paths_by_group.keys():
		var panel: Control = panel_value as Control
		var paths: Array = panel_paths_by_group.get(panel, [])
		for path_value: Variant in paths:
			_connect_normal_ui_group_focus(root_control.get_node_or_null(path_value as NodePath) as Control, panel)

	var focus_tree_panels: Dictionary = {
		chat_panel: [chat_panel, chat_tabs_panel],
		party_panel: [party_panel],
		actions_panel: [actions_panel],
		dex_actions_panel: [dex_actions_panel],
		staff_actions_panel: [staff_actions_panel],
		options_panel: [options_panel],
		hotkey_sidebar_panel: [hotkey_sidebar_panel],
		player_status_panel: [player_status_panel],
	}
	for panel_value: Variant in focus_tree_panels.keys():
		var panel: Control = panel_value as Control
		var controls: Array = focus_tree_panels.get(panel, [])
		for control_value: Variant in controls:
			_connect_normal_ui_group_focus_tree(control_value as Control, panel)

func _setup_ui_confirm_popup() -> void:
	ui_confirm_popup = PanelContainer.new()
	ui_confirm_popup.name = "UiConfirmPopup"
	ui_confirm_popup.visible = false
	ui_confirm_popup.top_level = false
	ui_confirm_popup.z_index = UI_MODAL_Z_INDEX
	ui_confirm_popup.z_as_relative = false
	ui_confirm_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_confirm_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui_confirm_popup.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ui_confirm_popup.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ui_confirm_popup.custom_minimum_size = Vector2.ZERO
	ui_confirm_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912fa"), POKEMON_SUMMARY_ACCENT_SOFT, 8, 1))
	root_control.add_child(ui_confirm_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	ui_confirm_popup.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)

	ui_confirm_title_label = Label.new()
	ui_confirm_title_label.text = "Confirm"
	ui_confirm_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_confirm_title_label.add_theme_font_size_override("font_size", 17)
	ui_confirm_title_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	header.add_child(ui_confirm_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 28)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_on_ui_confirm_cancel_pressed)
	_apply_button_style(close_button)
	header.add_child(close_button)

	ui_confirm_message_label = Label.new()
	ui_confirm_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_confirm_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_confirm_message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ui_confirm_message_label.add_theme_font_size_override("font_size", 14)
	ui_confirm_message_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(ui_confirm_message_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	stack.add_child(button_row)

	ui_confirm_cancel_button = Button.new()
	ui_confirm_cancel_button.text = "Cancel"
	ui_confirm_cancel_button.custom_minimum_size = Vector2(112, 32)
	ui_confirm_cancel_button.focus_mode = Control.FOCUS_NONE
	ui_confirm_cancel_button.pressed.connect(_on_ui_confirm_cancel_pressed)
	_apply_button_style(ui_confirm_cancel_button)
	button_row.add_child(ui_confirm_cancel_button)

	ui_confirm_confirm_button = Button.new()
	ui_confirm_confirm_button.text = "Confirm"
	ui_confirm_confirm_button.custom_minimum_size = Vector2(128, 32)
	ui_confirm_confirm_button.focus_mode = Control.FOCUS_NONE
	ui_confirm_confirm_button.pressed.connect(_on_ui_confirm_confirm_pressed)
	_apply_button_style(ui_confirm_confirm_button, "primary")
	button_row.add_child(ui_confirm_confirm_button)

func _show_ui_confirm_popup(
	title: String,
	message: String,
	confirm_text: String,
	callback: Callable,
	size: Vector2i = Vector2i(460, 190),
	danger_confirm: bool = false,
	cancel_text: String = "Cancel",
	cancel_callback: Callable = Callable()
) -> void:
	if ui_confirm_popup == null:
		if callback.is_valid():
			callback.call()
		return
	ui_confirm_callback = callback
	ui_confirm_cancel_callback = cancel_callback
	ui_confirm_title_label.text = title
	ui_confirm_message_label.text = message
	ui_confirm_confirm_button.text = confirm_text
	_apply_button_style(ui_confirm_confirm_button, "danger" if danger_confirm else "primary")
	ui_confirm_cancel_button.text = cancel_text

	var popup_size := Vector2(size)
	if popup_size.y <= 0.0:
		var line_count: int = max(message.split("\n").size(), 1)
		popup_size.y = 126.0 + float(line_count - 1) * 20.0
	popup_size.y = clamp(popup_size.y, 146.0, 220.0)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_position := (viewport_size - popup_size) * 0.5
	ui_confirm_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ui_confirm_popup.visible = true
	ui_confirm_popup.z_index = UI_MODAL_Z_INDEX
	ui_confirm_popup.z_as_relative = false
	ui_confirm_popup.position = popup_position
	ui_confirm_popup.size = popup_size
	ui_confirm_popup.custom_minimum_size = popup_size
	ui_confirm_popup.offset_left = popup_position.x
	ui_confirm_popup.offset_top = popup_position.y
	ui_confirm_popup.offset_right = popup_position.x + popup_size.x
	ui_confirm_popup.offset_bottom = popup_position.y + popup_size.y
	ui_confirm_popup.move_to_front()
	ui_confirm_popup.z_index = UI_MODAL_Z_INDEX

func _hide_ui_confirm_popup() -> void:
	if ui_confirm_popup != null:
		ui_confirm_popup.visible = false
	ui_confirm_callback = Callable()
	ui_confirm_cancel_callback = Callable()

func _on_ui_confirm_cancel_pressed() -> void:
	var callback := ui_confirm_cancel_callback
	_hide_ui_confirm_popup()
	if callback.is_valid():
		await callback.call()

func _on_ui_confirm_confirm_pressed() -> void:
	var callback := ui_confirm_callback
	_hide_ui_confirm_popup()
	if callback.is_valid():
		await callback.call()

func _setup_move_learn_popup() -> void:
	move_learn_popup = PanelContainer.new()
	move_learn_popup.name = "MoveLearnPopup"
	move_learn_popup.visible = false
	move_learn_popup.z_index = UI_MODAL_Z_INDEX
	move_learn_popup.z_as_relative = false
	move_learn_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	move_learn_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	move_learn_popup.custom_minimum_size = Vector2(440, 300)
	move_learn_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912fa"), POKEMON_SUMMARY_ACCENT_SOFT, 8, 1))
	root_control.add_child(move_learn_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	move_learn_popup.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	move_learn_title_label = Label.new()
	move_learn_title_label.text = "Learn Move"
	move_learn_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_learn_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_learn_title_label.add_theme_font_size_override("font_size", 17)
	move_learn_title_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	stack.add_child(move_learn_title_label)

	move_learn_moves_container = VBoxContainer.new()
	move_learn_moves_container.add_theme_constant_override("separation", 8)
	move_learn_moves_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(move_learn_moves_container)

	move_learn_message_label = Label.new()
	move_learn_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move_learn_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_learn_message_label.add_theme_font_size_override("font_size", 15)
	move_learn_message_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(move_learn_message_label)

	move_learn_status_label = Label.new()
	move_learn_status_label.text = ""
	move_learn_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move_learn_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_learn_status_label.add_theme_font_size_override("font_size", 12)
	move_learn_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	stack.add_child(move_learn_status_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	stack.add_child(button_row)

	move_learn_confirm_button = Button.new()
	move_learn_confirm_button.text = "Learn"
	move_learn_confirm_button.custom_minimum_size = Vector2(132, 42)
	move_learn_confirm_button.focus_mode = Control.FOCUS_NONE
	move_learn_confirm_button.disabled = true
	move_learn_confirm_button.pressed.connect(_on_move_learn_confirm_pressed)
	_apply_move_learn_action_button_style(move_learn_confirm_button, Color("#0b4f19"), Color("#2ea043"), Color("#092f11"))
	button_row.add_child(move_learn_confirm_button)

	move_learn_skip_button = Button.new()
	move_learn_skip_button.text = "Cancel"
	move_learn_skip_button.custom_minimum_size = Vector2(132, 42)
	move_learn_skip_button.focus_mode = Control.FOCUS_NONE
	move_learn_skip_button.pressed.connect(_on_move_learn_skip_pressed)
	_apply_move_learn_action_button_style(move_learn_skip_button, Color("#581313"), Color("#b42323"), Color("#330909"))
	button_row.add_child(move_learn_skip_button)

	move_learn_hover_panel = PanelContainer.new()
	move_learn_hover_panel.name = "MoveLearnHoverPanel"
	move_learn_hover_panel.visible = false
	move_learn_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_learn_hover_panel.z_index = UI_MODAL_Z_INDEX + 1
	move_learn_hover_panel.z_as_relative = false
	move_learn_hover_panel.custom_minimum_size = Vector2(260, 142)
	move_learn_hover_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#080604f4"), Color("#2c241a"), 3, 1))
	root_control.add_child(move_learn_hover_panel)

func _setup_evolution_prompt_popup() -> void:
	evolution_prompt_popup = PanelContainer.new()
	evolution_prompt_popup.name = "EvolutionPromptPopup"
	evolution_prompt_popup.visible = false
	evolution_prompt_popup.z_index = UI_MODAL_Z_INDEX
	evolution_prompt_popup.z_as_relative = false
	evolution_prompt_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	evolution_prompt_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912fb"), POKEMON_SUMMARY_ACCENT_SOFT, 8, 1))
	root_control.add_child(evolution_prompt_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evolution_prompt_popup.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	stack.add_child(header)

	evolution_prompt_title_label = Label.new()
	evolution_prompt_title_label.text = "Evolution"
	evolution_prompt_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evolution_prompt_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	evolution_prompt_title_label.add_theme_font_size_override("font_size", 19)
	evolution_prompt_title_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	header.add_child(evolution_prompt_title_label)

	evolution_prompt_progress_label = Label.new()
	evolution_prompt_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	evolution_prompt_progress_label.add_theme_font_size_override("font_size", 12)
	evolution_prompt_progress_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	header.add_child(evolution_prompt_progress_label)

	evolution_prompt_message_label = Label.new()
	evolution_prompt_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evolution_prompt_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_prompt_message_label.add_theme_font_size_override("font_size", 15)
	evolution_prompt_message_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(evolution_prompt_message_label)

	var sprite_row := HBoxContainer.new()
	sprite_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sprite_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_row.add_theme_constant_override("separation", 14)
	stack.add_child(sprite_row)

	evolution_prompt_old_sprite = _create_evolution_prompt_sprite("OldSpecies")
	sprite_row.add_child(evolution_prompt_old_sprite)

	var arrow_label := Label.new()
	arrow_label.text = ">"
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.custom_minimum_size = Vector2(28, 92)
	arrow_label.add_theme_font_size_override("font_size", 22)
	arrow_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	sprite_row.add_child(arrow_label)

	evolution_prompt_new_sprite = _create_evolution_prompt_sprite("NewSpecies")
	sprite_row.add_child(evolution_prompt_new_sprite)

	evolution_prompt_level_label = Label.new()
	evolution_prompt_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_prompt_level_label.add_theme_font_size_override("font_size", 12)
	evolution_prompt_level_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	stack.add_child(evolution_prompt_level_label)

	evolution_prompt_status_label = Label.new()
	evolution_prompt_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_prompt_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_prompt_status_label.add_theme_font_size_override("font_size", 12)
	evolution_prompt_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	stack.add_child(evolution_prompt_status_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_theme_constant_override("separation", 10)
	stack.add_child(button_row)

	evolution_prompt_skip_button = Button.new()
	evolution_prompt_skip_button.text = "Do not evolve"
	evolution_prompt_skip_button.custom_minimum_size = Vector2(132, 36)
	evolution_prompt_skip_button.focus_mode = Control.FOCUS_NONE
	evolution_prompt_skip_button.pressed.connect(_on_evolution_skipped)
	_apply_button_style(evolution_prompt_skip_button)
	button_row.add_child(evolution_prompt_skip_button)

	evolution_prompt_confirm_button = Button.new()
	evolution_prompt_confirm_button.text = "Evolve"
	evolution_prompt_confirm_button.custom_minimum_size = Vector2(132, 36)
	evolution_prompt_confirm_button.focus_mode = Control.FOCUS_NONE
	evolution_prompt_confirm_button.pressed.connect(_on_evolution_confirmed)
	_apply_button_style(evolution_prompt_confirm_button, "primary")
	button_row.add_child(evolution_prompt_confirm_button)

func _create_evolution_prompt_sprite(sprite_name: String) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.name = sprite_name
	sprite.custom_minimum_size = Vector2(112, 94)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite

func _apply_move_learn_action_button_style(button: Button, background_color: Color, border_color: Color, pressed_color: Color) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.46))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _make_button_style(background_color, border_color, 4, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(background_color.r * 1.18, background_color.g * 1.18, background_color.b * 1.18, background_color.a), border_color, 4, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_color, border_color, 4, 1))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color("#111111aa"), Color("#55555577"), 4, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(background_color, UI_BORDER_FOCUS, 4, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _setup_evolution_overlay() -> void:
	evolution_overlay = Control.new()
	evolution_overlay.name = "EvolutionOverlay"
	evolution_overlay.visible = false
	evolution_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	evolution_overlay.z_index = UI_MODAL_Z_INDEX + 30
	evolution_overlay.z_as_relative = false
	evolution_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(evolution_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color("#030811e8")
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	evolution_overlay.add_child(dim)

	evolution_stage = Control.new()
	evolution_stage.name = "Stage"
	evolution_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evolution_stage.custom_minimum_size = EVOLUTION_OVERLAY_STAGE_SIZE
	evolution_overlay.add_child(evolution_stage)

	evolution_title_label = Label.new()
	evolution_title_label.name = "Title"
	evolution_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_title_label.add_theme_font_size_override("font_size", 26)
	evolution_title_label.add_theme_color_override("font_color", Color("#f8f5df"))
	evolution_title_label.add_theme_color_override("font_shadow_color", Color("#08101f"))
	evolution_title_label.add_theme_constant_override("shadow_offset_x", 2)
	evolution_title_label.add_theme_constant_override("shadow_offset_y", 2)
	evolution_stage.add_child(evolution_title_label)

	evolution_sprite_stage = Control.new()
	evolution_sprite_stage.name = "SpriteStage"
	evolution_sprite_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evolution_stage.add_child(evolution_sprite_stage)

	evolution_silhouette_material = _make_evolution_silhouette_material()

	for index in range(3):
		var ring := Panel.new()
		ring.name = "LightRing%s" % index
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", _make_evolution_ring_style(index))
		evolution_sprite_stage.add_child(ring)
		evolution_ring_nodes.append(ring)

	for index in range(EVOLUTION_OVERLAY_SPARKLE_COUNT):
		var sparkle := Panel.new()
		sparkle.name = "Sparkle%s" % index
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.add_theme_stylebox_override("panel", _make_evolution_sparkle_style(index))
		evolution_sprite_stage.add_child(sparkle)
		evolution_sparkle_nodes.append(sparkle)

	evolution_old_sprite = _create_evolution_sprite("OldSprite")
	evolution_sprite_stage.add_child(evolution_old_sprite)

	evolution_silhouette_sprite = _create_evolution_sprite("SilhouetteSprite")
	evolution_silhouette_sprite.material = evolution_silhouette_material
	evolution_sprite_stage.add_child(evolution_silhouette_sprite)

	evolution_new_sprite = _create_evolution_sprite("NewSprite")
	evolution_sprite_stage.add_child(evolution_new_sprite)

	evolution_message_label = Label.new()
	evolution_message_label.name = "Message"
	evolution_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_message_label.add_theme_font_size_override("font_size", 19)
	evolution_message_label.add_theme_color_override("font_color", Color("#f1e4a8"))
	evolution_message_label.add_theme_color_override("font_shadow_color", Color("#08101f"))
	evolution_message_label.add_theme_constant_override("shadow_offset_x", 2)
	evolution_message_label.add_theme_constant_override("shadow_offset_y", 2)
	evolution_stage.add_child(evolution_message_label)

	evolution_continue_button = Button.new()
	evolution_continue_button.name = "ContinueButton"
	evolution_continue_button.text = "Continue"
	evolution_continue_button.custom_minimum_size = Vector2(140, 40)
	evolution_continue_button.focus_mode = Control.FOCUS_NONE
	evolution_continue_button.pressed.connect(_hide_evolution_overlay)
	_apply_move_learn_action_button_style(evolution_continue_button, Color("#0b2035"), POKEMON_SUMMARY_ACCENT_SOFT, Color("#071421"))
	evolution_stage.add_child(evolution_continue_button)

	evolution_flash_rect = ColorRect.new()
	evolution_flash_rect.name = "Flash"
	evolution_flash_rect.color = Color(1.0, 0.96, 0.78, 0.0)
	evolution_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evolution_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	evolution_overlay.add_child(evolution_flash_rect)

	_layout_evolution_overlay()
	_reset_evolution_visuals()

func _make_evolution_silhouette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "
shader_type canvas_item;
uniform vec4 silhouette_color : source_color = vec4(1.0, 0.98, 0.72, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(silhouette_color.rgb, tex.a * COLOR.a * silhouette_color.a);
}
"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("silhouette_color", Color("#fff7bb"))
	return material

func _create_evolution_sprite(sprite_name: String) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.name = sprite_name
	sprite.custom_minimum_size = EVOLUTION_OVERLAY_SPRITE_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite

func _make_evolution_ring_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	var alpha := 0.75 - float(index) * 0.16
	style.border_color = Color(0.95, 0.88, 0.54, alpha)
	style.set_border_width_all(2)
	style.set_corner_radius_all(999)
	return style

func _make_evolution_sparkle_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff3a8") if index % 3 != 0 else Color("#d9f7ff")
	style.set_corner_radius_all(999)
	return style

func _layout_evolution_overlay() -> void:
	if evolution_overlay == null or evolution_stage == null:
		return

	var viewport_size := root_control.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport().get_visible_rect().size

	var stage_size := Vector2(
		min(EVOLUTION_OVERLAY_STAGE_SIZE.x, max(viewport_size.x - 32.0, 320.0)),
		min(EVOLUTION_OVERLAY_STAGE_SIZE.y, max(viewport_size.y - 32.0, 320.0))
	)
	evolution_stage.position = (viewport_size - stage_size) * 0.5
	evolution_stage.size = stage_size

	evolution_title_label.position = Vector2(0, 0)
	evolution_title_label.size = Vector2(stage_size.x, 42)

	var sprite_stage_size := Vector2(min(360.0, stage_size.x), 236.0)
	evolution_sprite_stage.position = Vector2((stage_size.x - sprite_stage_size.x) * 0.5, 58)
	evolution_sprite_stage.size = sprite_stage_size

	var sprite_position := (sprite_stage_size - EVOLUTION_OVERLAY_SPRITE_SIZE) * 0.5
	for sprite in [evolution_old_sprite, evolution_silhouette_sprite, evolution_new_sprite]:
		if sprite == null:
			continue
		sprite.position = sprite_position
		sprite.size = EVOLUTION_OVERLAY_SPRITE_SIZE
		sprite.pivot_offset = EVOLUTION_OVERLAY_SPRITE_SIZE * 0.5

	var ring_size := Vector2(250, 250)
	for ring: Control in evolution_ring_nodes:
		ring.position = (sprite_stage_size - ring_size) * 0.5
		ring.size = ring_size
		ring.pivot_offset = ring_size * 0.5

	_position_evolution_sparkles()

	evolution_message_label.position = Vector2(0, stage_size.y - 94)
	evolution_message_label.size = Vector2(stage_size.x, 48)
	evolution_continue_button.position = Vector2((stage_size.x - evolution_continue_button.custom_minimum_size.x) * 0.5, stage_size.y - 38)
	evolution_continue_button.size = evolution_continue_button.custom_minimum_size

func _position_evolution_sparkles() -> void:
	if evolution_sprite_stage == null:
		return

	var center := evolution_sprite_stage.size * 0.5
	for index in range(evolution_sparkle_nodes.size()):
		var sparkle := evolution_sparkle_nodes[index]
		var sparkle_size := 5.0 + float(index % 4)
		var angle := TAU * float(index) / float(max(evolution_sparkle_nodes.size(), 1))
		var radius := 76.0 + float((index * 17) % 54)
		sparkle.size = Vector2(sparkle_size, sparkle_size)
		sparkle.position = center + Vector2(cos(angle), sin(angle)) * radius - sparkle.size * 0.5
		sparkle.pivot_offset = sparkle.size * 0.5

func _reset_evolution_visuals() -> void:
	if evolution_old_sprite != null:
		evolution_old_sprite.visible = true
		evolution_old_sprite.modulate = Color.WHITE
		evolution_old_sprite.scale = Vector2.ONE
	if evolution_silhouette_sprite != null:
		evolution_silhouette_sprite.visible = false
		evolution_silhouette_sprite.modulate = Color(1, 1, 1, 0)
		evolution_silhouette_sprite.scale = Vector2.ONE
	if evolution_new_sprite != null:
		evolution_new_sprite.visible = false
		evolution_new_sprite.modulate = Color(1, 1, 1, 0)
		evolution_new_sprite.scale = Vector2.ONE
	if evolution_flash_rect != null:
		evolution_flash_rect.color = Color(1.0, 0.96, 0.78, 0.0)
	for ring: Control in evolution_ring_nodes:
		ring.visible = false
		ring.modulate = Color(1, 1, 1, 0)
		ring.scale = Vector2(0.25, 0.25)
	for sparkle: Control in evolution_sparkle_nodes:
		sparkle.visible = false
		sparkle.modulate = Color(1, 1, 1, 0)
		sparkle.scale = Vector2(0.2, 0.2)
	if evolution_continue_button != null:
		evolution_continue_button.visible = false

func play_evolution_preview(old_species: String, new_species: String, shiny: bool = false) -> void:
	var payload := {
		"oldSpecies": old_species,
		"newSpecies": new_species,
		"shiny": shiny,
	}
	await play_evolution_overlay(payload)

func play_evolution_overlay(evolution: Dictionary) -> void:
	if evolution_overlay == null:
		return

	var old_species := str(evolution.get("oldSpecies", evolution.get("fromSpecies", ""))).strip_edges()
	var new_species := str(evolution.get("newSpecies", evolution.get("toSpecies", ""))).strip_edges()
	if old_species == "" or new_species == "":
		return

	if evolution_tween != null and evolution_tween.is_valid():
		evolution_tween.kill()

	var shiny := bool(evolution.get("shiny", false))
	var old_texture := PokemonAssets.load_home_sprite(old_species, shiny)
	var new_texture := PokemonAssets.load_home_sprite(new_species, shiny)
	if old_texture == null or new_texture == null:
		add_system_message("%s evolved into %s!" % [old_species, new_species])
		return

	evolution_is_playing = true
	evolution_old_sprite.texture = old_texture
	evolution_silhouette_sprite.texture = old_texture
	evolution_new_sprite.texture = new_texture
	evolution_title_label.text = "What? %s is evolving!" % old_species
	evolution_message_label.text = ""
	evolution_overlay.visible = true
	evolution_overlay.move_to_front()
	_layout_evolution_overlay()
	_reset_evolution_visuals()

	evolution_tween = create_tween()
	evolution_tween.tween_property(evolution_old_sprite, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	evolution_tween.tween_property(evolution_old_sprite, "scale", Vector2(0.96, 0.96), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	evolution_tween.tween_property(evolution_old_sprite, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	evolution_tween.tween_callback(_show_evolution_silhouette)
	evolution_tween.tween_interval(0.12)
	evolution_tween.tween_callback(_start_evolution_light_effects)
	evolution_tween.tween_property(evolution_silhouette_sprite, "scale", Vector2(1.22, 1.22), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	evolution_tween.tween_property(evolution_silhouette_sprite, "modulate:a", 0.72, 0.18)
	evolution_tween.tween_property(evolution_silhouette_sprite, "modulate:a", 1.0, 0.18)
	evolution_tween.tween_callback(_flash_evolution_overlay)
	evolution_tween.tween_interval(0.16)
	evolution_tween.tween_callback(_reveal_evolution_new_species)
	evolution_tween.tween_property(evolution_new_sprite, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	evolution_tween.parallel().tween_property(evolution_new_sprite, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	evolution_tween.tween_interval(0.22)
	await evolution_tween.finished

	evolution_message_label.text = "Congratulations! %s evolved into %s!" % [old_species, new_species]
	evolution_continue_button.visible = true
	evolution_is_playing = false
	await evolution_continue_button.pressed

func _show_evolution_silhouette() -> void:
	evolution_old_sprite.visible = false
	evolution_silhouette_sprite.visible = true
	evolution_silhouette_sprite.modulate = Color(1, 1, 1, 1)
	evolution_silhouette_sprite.scale = Vector2.ONE

func _start_evolution_light_effects() -> void:
	for index in range(evolution_ring_nodes.size()):
		_animate_evolution_ring(evolution_ring_nodes[index], float(index) * 0.18)
	for index in range(evolution_sparkle_nodes.size()):
		_animate_evolution_sparkle(evolution_sparkle_nodes[index], float(index % 6) * 0.08)

func _animate_evolution_ring(ring: Control, delay: float) -> void:
	ring.visible = true
	ring.scale = Vector2(0.18, 0.18)
	ring.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(ring, "modulate:a", 0.84, 0.12).set_delay(delay)
	tween.parallel().tween_property(ring, "scale", Vector2(1.22, 1.22), 0.72).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.28)

func _animate_evolution_sparkle(sparkle: Control, delay: float) -> void:
	sparkle.visible = true
	sparkle.scale = Vector2(0.2, 0.2)
	sparkle.modulate = Color(1, 1, 1, 0)
	var origin := sparkle.position
	var center := evolution_sprite_stage.size * 0.5
	var direction := (origin + sparkle.size * 0.5 - center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var tween := create_tween()
	tween.tween_property(sparkle, "modulate:a", 1.0, 0.12).set_delay(delay)
	tween.parallel().tween_property(sparkle, "scale", Vector2(1.0, 1.0), 0.18).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sparkle, "position", origin + direction * 34.0, 0.54).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sparkle, "modulate:a", 0.0, 0.22)

func _flash_evolution_overlay() -> void:
	evolution_flash_rect.color = Color(1.0, 0.96, 0.72, 0.0)
	var tween := create_tween()
	tween.tween_property(evolution_flash_rect, "color:a", 0.92, 0.08)
	tween.tween_property(evolution_flash_rect, "color:a", 0.0, 0.28)

func _reveal_evolution_new_species() -> void:
	evolution_silhouette_sprite.visible = false
	evolution_new_sprite.visible = true
	evolution_new_sprite.modulate = Color(1, 1, 1, 0)
	evolution_new_sprite.scale = Vector2(0.72, 0.72)
	_start_evolution_light_effects()

func _hide_evolution_overlay() -> void:
	if evolution_tween != null and evolution_tween.is_valid():
		evolution_tween.kill()
	evolution_tween = null
	evolution_is_playing = false
	if evolution_overlay != null:
		evolution_overlay.visible = false
	_reset_evolution_visuals()

func queue_reward_move_learn_candidates(reward_value: Variant) -> void:
	if not (reward_value is Dictionary):
		return

	var reward: Dictionary = reward_value as Dictionary
	var evolution_queued_count := _queue_reward_evolution_prompts_from_reward(reward)
	var prompts_value: Variant = reward.get("moveLearnPrompts", [])
	if prompts_value is Array:
		var prompts: Array = prompts_value as Array
		if not prompts.is_empty():
			var queued_before := _move_learn_pending_prompt_count()
			var queued_count := 0
			for prompt_value: Variant in prompts:
				if prompt_value is Dictionary:
					if _queue_move_learn_prompt(prompt_value as Dictionary):
						queued_count += 1
			_extend_move_learn_review_count(queued_count, queued_before)
			if queued_count > 0:
				_show_next_move_learn_prompt()
			elif evolution_queued_count > 0:
				_show_next_evolution_prompt()
			return

	var level_ups_value: Variant = reward.get("levelUps", [])
	if not (level_ups_value is Array):
		if evolution_queued_count > 0:
			_show_next_evolution_prompt()
		return

	var queued_before := _move_learn_pending_prompt_count()
	var queued_count := 0
	for level_up_value: Variant in level_ups_value:
		if not (level_up_value is Dictionary):
			continue

		var level_up: Dictionary = level_up_value as Dictionary
		var pokemon_id := int(level_up.get("pokemonId", 0))
		var species := str(level_up.get("species", "Pokemon")).strip_edges()
		var candidates_value: Variant = level_up.get("moveLearnCandidates", [])
		if pokemon_id <= 0 or not (candidates_value is Array):
			continue

		for candidate_value: Variant in candidates_value:
			if not (candidate_value is Dictionary):
				continue

			var prompt := (candidate_value as Dictionary).duplicate(true)
			var move_id := _move_learn_prompt_move_id(prompt)
			if move_id == "":
				continue

			prompt["pokemonId"] = pokemon_id
			prompt["species"] = species if species != "" else "Pokemon"
			if _queue_move_learn_prompt(prompt):
				queued_count += 1

	_extend_move_learn_review_count(queued_count, queued_before)
	if queued_count > 0:
		_show_next_move_learn_prompt()
	elif evolution_queued_count > 0:
		_show_next_evolution_prompt()

func _queue_reward_evolution_prompts_from_reward(reward: Dictionary) -> int:
	var queued_count := 0
	var prompts_value: Variant = reward.get("evolutionPrompts", [])
	if prompts_value is Array:
		for prompt_value: Variant in prompts_value as Array:
			if prompt_value is Dictionary and _queue_evolution_prompt(prompt_value as Dictionary):
				queued_count += 1

	if queued_count > 0:
		_extend_evolution_review_count(queued_count)
		return queued_count

	var level_ups_value: Variant = reward.get("levelUps", [])
	if not (level_ups_value is Array):
		return 0

	for level_up_value: Variant in level_ups_value as Array:
		if not (level_up_value is Dictionary):
			continue
		var level_up: Dictionary = level_up_value as Dictionary
		var pokemon_id := int(level_up.get("pokemonId", 0))
		var species := str(level_up.get("species", "Pokemon")).strip_edges()
		var candidates_value: Variant = level_up.get("evolutionCandidates", [])
		if pokemon_id <= 0 or not (candidates_value is Array):
			continue
		for candidate_value: Variant in candidates_value as Array:
			if not (candidate_value is Dictionary):
				continue
			var prompt := (candidate_value as Dictionary).duplicate(true)
			prompt["pokemonId"] = pokemon_id
			if not prompt.has("fromSpecies"):
				prompt["fromSpecies"] = species
			if _queue_evolution_prompt(prompt):
				queued_count += 1

	_extend_evolution_review_count(queued_count)
	return queued_count

func _queue_evolution_prompt(prompt_value: Dictionary) -> bool:
	var prompt := prompt_value.duplicate(true)
	var pokemon_id := int(prompt.get("pokemonId", 0))
	var target_species_id := _evolution_prompt_target_species_id(prompt)
	if pokemon_id <= 0 or target_species_id == "":
		return false

	var from_species := _evolution_prompt_from_species(prompt)
	var to_species := _evolution_prompt_to_species(prompt)
	prompt["pokemonId"] = pokemon_id
	prompt["toSpeciesId"] = target_species_id
	prompt["fromSpecies"] = from_species
	prompt["toSpecies"] = to_species
	evolution_prompt_queue.append(prompt)
	return true

func _extend_evolution_review_count(queued_count: int) -> void:
	if queued_count <= 0:
		return
	if evolution_prompt_review_total <= 0 and evolution_active_prompt.is_empty():
		evolution_prompt_review_total = queued_count
		evolution_prompt_review_index = 0
		return
	evolution_prompt_review_total += queued_count

func _evolution_queue_progress_label() -> String:
	if evolution_prompt_review_total <= 1:
		return ""
	var current_index: int = clampi(evolution_prompt_review_index, 1, evolution_prompt_review_total)
	return "%s / %s" % [current_index, evolution_prompt_review_total]

func _finish_evolution_review_queue() -> void:
	evolution_prompt_review_total = 0
	evolution_prompt_review_index = 0

func _show_next_evolution_prompt() -> void:
	if evolution_prompt_processing or evolution_is_playing:
		return
	if evolution_prompt_popup != null and evolution_prompt_popup.visible:
		return
	if move_learn_popup != null and move_learn_popup.visible:
		return
	if not move_learn_queue.is_empty() or not move_learn_active_prompt.is_empty():
		return

	while not evolution_prompt_queue.is_empty():
		var prompt: Dictionary = evolution_prompt_queue.pop_front()
		var pokemon := _find_party_pokemon_by_owned_id(int(prompt.get("pokemonId", 0)))
		if pokemon == null:
			add_system_message("Could not open evolution prompt for %s." % _evolution_prompt_from_species(prompt))
			continue

		evolution_prompt_review_index += 1
		evolution_active_prompt = prompt
		_render_evolution_prompt(prompt)
		return

	_finish_evolution_review_queue()

func _render_evolution_prompt(prompt: Dictionary) -> void:
	if evolution_prompt_popup == null:
		return

	var from_species := _evolution_prompt_from_species(prompt)
	var to_species := _evolution_prompt_to_species(prompt)
	var progress_label := _evolution_queue_progress_label()
	var level := int(prompt.get("level", 0))
	evolution_prompt_title_label.text = "Evolution"
	evolution_prompt_progress_label.text = progress_label
	evolution_prompt_message_label.text = "%s can evolve into %s." % [from_species, to_species]
	evolution_prompt_level_label.text = "Available at Lv. %s" % level if level > 0 else ""
	evolution_prompt_status_label.text = ""
	evolution_prompt_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	_set_evolution_prompt_controls_disabled(false)

	var shiny := bool(prompt.get("shiny", false))
	evolution_prompt_old_sprite.texture = PokemonAssets.load_home_sprite(from_species, shiny)
	evolution_prompt_new_sprite.texture = PokemonAssets.load_home_sprite(to_species, shiny)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_size := Vector2(min(440.0, viewport_size.x - 32.0), min(336.0, viewport_size.y - 32.0))
	var popup_position := Vector2(
		max((viewport_size.x - popup_size.x) * 0.5, 16.0),
		max((viewport_size.y - popup_size.y) * 0.5, 16.0)
	)
	evolution_prompt_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	evolution_prompt_popup.position = popup_position
	evolution_prompt_popup.size = popup_size
	evolution_prompt_popup.custom_minimum_size = popup_size
	evolution_prompt_popup.offset_left = popup_position.x
	evolution_prompt_popup.offset_top = popup_position.y
	evolution_prompt_popup.offset_right = popup_position.x + popup_size.x
	evolution_prompt_popup.offset_bottom = popup_position.y + popup_size.y
	evolution_prompt_popup.visible = true
	evolution_prompt_popup.move_to_front()

func _on_evolution_confirmed() -> void:
	await _submit_evolution_choice(true)

func _on_evolution_skipped() -> void:
	await _submit_evolution_choice(false)

func _submit_evolution_choice(confirm: bool) -> void:
	if evolution_prompt_processing or evolution_active_prompt.is_empty():
		return

	evolution_prompt_processing = true
	_set_evolution_prompt_controls_disabled(true)
	var prompt := evolution_active_prompt.duplicate(true)
	var pokemon_id := int(prompt.get("pokemonId", 0))
	var target_species_id := _evolution_prompt_target_species_id(prompt)
	var from_species := _evolution_prompt_from_species(prompt)
	evolution_prompt_status_label.text = "Saving..."
	evolution_prompt_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	var result: Dictionary = await PlayerPartyStateService.evolve_pokemon(pokemon_id, target_species_id, confirm)
	evolution_prompt_processing = false

	if not bool(result.get("success", false)):
		evolution_prompt_status_label.text = str(result.get("error", "Could not save evolution choice."))
		evolution_prompt_status_label.add_theme_color_override("font_color", UI_DANGER)
		_set_evolution_prompt_controls_disabled(false)
		return

	var evolution: Dictionary = {}
	var evolution_value: Variant = result.get("evolution", {})
	if evolution_value is Dictionary:
		evolution = (evolution_value as Dictionary).duplicate(true)

	if confirm and not bool(result.get("skipped", false)):
		if evolution.is_empty():
			evolution = prompt
		if evolution_prompt_popup != null:
			evolution_prompt_popup.visible = false
		await play_evolution_overlay(evolution)
		add_system_message("%s evolved into %s!" % [from_species, _evolution_prompt_to_species(evolution)])
	else:
		if evolution_prompt_popup != null:
			evolution_prompt_popup.visible = false
		add_system_message("%s did not evolve." % from_species)

	evolution_active_prompt.clear()
	_refresh_party()
	_refresh_open_pokemon_summary_cards()
	_show_next_evolution_prompt()

func _set_evolution_prompt_controls_disabled(disabled: bool) -> void:
	if evolution_prompt_confirm_button != null:
		evolution_prompt_confirm_button.disabled = disabled
	if evolution_prompt_skip_button != null:
		evolution_prompt_skip_button.disabled = disabled

func _evolution_prompt_target_species_id(prompt: Dictionary) -> String:
	for key in ["toSpeciesId", "to_species_id", "species_id", "targetSpeciesId"]:
		var value := str(prompt.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _evolution_prompt_from_species(prompt: Dictionary) -> String:
	var species := str(prompt.get("fromSpecies", prompt.get("species", "Pokemon"))).strip_edges()
	return species if species != "" else "Pokemon"

func _evolution_prompt_to_species(prompt: Dictionary) -> String:
	var species := str(prompt.get("toSpecies", "")).strip_edges()
	if species != "":
		return species
	var species_id := _evolution_prompt_target_species_id(prompt)
	return _format_identifier_display_name(species_id) if species_id != "" else "Pokemon"

func _queue_move_learn_prompt(prompt_value: Dictionary) -> bool:
	var prompt := prompt_value.duplicate(true)
	var move_id := _move_learn_prompt_move_id(prompt)
	if move_id == "":
		return false
	if int(prompt.get("pokemonId", 0)) <= 0:
		return false

	var species := str(prompt.get("species", "Pokemon")).strip_edges()
	prompt["species"] = species if species != "" else "Pokemon"
	move_learn_queue.append(prompt)
	return true

func _move_learn_pending_prompt_count() -> int:
	var count := move_learn_queue.size()
	if not move_learn_active_prompt.is_empty():
		count += 1
	return count

func _extend_move_learn_review_count(queued_count: int, queued_before: int) -> void:
	if queued_count <= 0:
		return
	if queued_before <= 0:
		move_learn_pending_review_total = queued_count
		move_learn_pending_review_index = 0
		return
	if move_learn_pending_review_total <= 0:
		move_learn_pending_review_total = move_learn_pending_review_index + queued_before + queued_count
		return
	move_learn_pending_review_total += queued_count

func _move_learn_queue_progress_label() -> String:
	if move_learn_pending_review_total <= 1:
		return ""
	var current_index: int = clampi(move_learn_pending_review_index, 1, move_learn_pending_review_total)
	return "%s / %s" % [current_index, move_learn_pending_review_total]

func _discard_move_learn_review_prompt() -> void:
	if move_learn_pending_review_total <= 0:
		return
	move_learn_pending_review_total = max(move_learn_pending_review_index, move_learn_pending_review_total - 1)

func _finish_move_learn_review_queue() -> void:
	if move_learn_pending_review_total > 1 and move_learn_pending_review_index >= move_learn_pending_review_total:
		add_system_message("Move learning review complete.")
	move_learn_pending_review_total = 0
	move_learn_pending_review_index = 0

func _show_next_move_learn_prompt() -> void:
	if move_learn_processing or move_learn_popup == null or move_learn_popup.visible:
		return

	if move_learn_pending_review_total <= 0 and not move_learn_queue.is_empty():
		move_learn_pending_review_total = move_learn_queue.size()
		move_learn_pending_review_index = 0

	while not move_learn_queue.is_empty():
		var prompt: Dictionary = move_learn_queue.pop_front()
		var pokemon := _find_party_pokemon_by_owned_id(int(prompt.get("pokemonId", 0)))
		if pokemon == null:
			add_system_message("Could not open move learning prompt for %s." % str(prompt.get("species", "Pokemon")))
			_discard_move_learn_review_prompt()
			continue

		move_learn_pending_review_index += 1
		move_learn_active_prompt = prompt
		_render_move_learn_prompt(pokemon, prompt)
		return

	_finish_move_learn_review_queue()
	_show_next_evolution_prompt()

func _render_move_learn_prompt(pokemon: Pokemon, prompt: Dictionary) -> void:
	var move_name := _move_learn_prompt_move_name(prompt)
	var species := str(prompt.get("species", pokemon.species)).strip_edges()
	if species == "":
		species = pokemon.species
	var new_move_value: Variant = _move_learn_prompt_move_value(prompt)
	var progress_label := _move_learn_queue_progress_label()
	move_learn_title_label.text = "Learn %s%s" % [move_name, " (%s)" % progress_label if progress_label != "" else ""]
	move_learn_message_label.text = "%s wants to learn %s. Select a move to replace or choose not to learn." % [species, move_name]
	move_learn_status_label.text = ""
	move_learn_selected_replace_slot = -2
	_hide_move_learn_hover_panel()

	for child: Node in move_learn_moves_container.get_children():
		child.queue_free()
	move_learn_move_buttons.clear()

	move_learn_moves_container.add_child(_create_move_learn_new_move_tile(move_name, new_move_value))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_learn_moves_container.add_child(grid)

	for move_index in range(4):
		var button: Button
		if move_index < pokemon.moves.size():
			var existing_move: Variant = pokemon.moves[move_index]
			var existing_name := _get_summary_move_name(existing_move)
			button = _create_move_learn_replace_button(move_index, existing_move, existing_name)
		else:
			button = _create_move_learn_empty_slot_button(move_index)
		grid.add_child(button)
		move_learn_move_buttons.append(button)
	_refresh_move_learn_selection_buttons()
	_set_move_learn_controls_disabled(false)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_size := Vector2(min(500.0, viewport_size.x - 32.0), min(440.0, viewport_size.y - 32.0))
	var popup_position := Vector2(
		max((viewport_size.x - popup_size.x) * 0.5, 16.0),
		max((viewport_size.y - popup_size.y) * 0.5, 16.0)
	)
	move_learn_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	move_learn_popup.position = popup_position
	move_learn_popup.size = popup_size
	move_learn_popup.custom_minimum_size = popup_size
	move_learn_popup.offset_left = popup_position.x
	move_learn_popup.offset_top = popup_position.y
	move_learn_popup.offset_right = popup_position.x + popup_size.x
	move_learn_popup.offset_bottom = popup_position.y + popup_size.y
	move_learn_popup.visible = true
	move_learn_popup.move_to_front()

func _create_move_learn_new_move_tile(move_name: String, move_value: Variant) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_entered.connect(_show_move_learn_hover_panel.bind(button, move_value))
	button.mouse_exited.connect(_hide_move_learn_hover_panel)
	_apply_move_learn_new_move_tile_style(button)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.anchor_right = 1.0
	stack.anchor_bottom = 1.0
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	button.add_child(stack)

	var eyebrow := Label.new()
	eyebrow.text = "New move"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(eyebrow)

	var name_label := Label.new()
	name_label.text = move_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#ffd95d"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var pp_label := _create_move_learn_meta_label("PP", _get_summary_move_pp_text(move_value), Color("#ffd95d"), 64.0)
	stack.add_child(pp_label)
	return button

func _create_move_learn_replace_button(move_index: int, move_value: Variant, existing_name: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(202, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_move_learn_slot_pressed.bind(move_index))
	button.mouse_entered.connect(_show_move_learn_hover_panel.bind(button, move_value))
	button.mouse_exited.connect(_hide_move_learn_hover_panel)
	_apply_move_learn_move_tile_style(button, false)
	_fill_move_learn_choice_button(button, existing_name, move_value, "")
	return button

func _create_move_learn_empty_slot_button(move_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(202, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_move_learn_slot_pressed.bind(move_index))
	_apply_move_learn_move_tile_style(button, false)
	_fill_move_learn_choice_button(button, "Empty slot", {}, "Learn here")
	return button

func _apply_move_learn_new_move_tile_style(button: Button) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_move_learn_tile_style(Color("#0a1824f4"), POKEMON_SUMMARY_ACCENT_SOFT, true))
	button.add_theme_stylebox_override("hover", _make_move_learn_tile_style(Color("#0e2638f8"), POKEMON_SUMMARY_ACCENT, true))
	button.add_theme_stylebox_override("pressed", _make_move_learn_tile_style(Color("#07131df8"), POKEMON_SUMMARY_ACCENT, true))
	button.add_theme_stylebox_override("focus", _make_move_learn_tile_style(Color("#0e2638f8"), UI_BORDER_FOCUS, true))

func _apply_move_learn_move_tile_style(button: Button, selected: bool) -> void:
	var normal_bg := Color("#111111f0") if selected else Color("#101010ec")
	var hover_bg := Color("#1a1a1af2")
	var pressed_bg := Color("#090909f4")
	var border := Color("#d6d6d699") if selected else Color("#77777788")
	var hover_border := Color("#f2f2f2bb")
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _make_move_learn_tile_style(normal_bg, border, selected))
	button.add_theme_stylebox_override("hover", _make_move_learn_tile_style(hover_bg, hover_border, selected))
	button.add_theme_stylebox_override("pressed", _make_move_learn_tile_style(pressed_bg, hover_border, selected))
	button.add_theme_stylebox_override("focus", _make_move_learn_tile_style(hover_bg, UI_BORDER_FOCUS, selected))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_move_learn_tile_style(background_color: Color, border_color: Color, selected: bool) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 3, 1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	if selected:
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.34)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	return style

func _fill_move_learn_choice_button(button: Button, move_name: String, move_value: Variant, fallback_meta_text: String) -> void:
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.anchor_right = 1.0
	stack.anchor_bottom = 1.0
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	button.add_child(stack)

	var name_label := Label.new()
	name_label.text = move_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 17 if fallback_meta_text == "" else 15)
	name_label.add_theme_color_override("font_color", Color("#ffd95d") if fallback_meta_text == "" else UI_MUTED_TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 8)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(meta_row)

	if fallback_meta_text != "":
		meta_row.add_child(_create_move_learn_plain_meta_label(fallback_meta_text))
		return

	meta_row.add_child(_create_move_learn_meta_label("PP", _get_summary_move_pp_text(move_value), Color("#ffd95d"), 64.0))

func _create_move_learn_meta_label(label_text: String, value_text: String, color: Color, min_width: float = 70.0) -> Control:
	var label := Label.new()
	label.text = "%s %s" % [label_text, value_text]
	label.custom_minimum_size = Vector2(min_width, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_move_learn_plain_meta_label(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _on_move_learn_slot_pressed(move_index: int) -> void:
	if move_learn_processing:
		return
	move_learn_selected_replace_slot = move_index
	move_learn_status_label.text = ""
	_refresh_move_learn_selection_buttons()

func _refresh_move_learn_selection_buttons() -> void:
	for move_index in range(move_learn_move_buttons.size()):
		var button := move_learn_move_buttons[move_index]
		_apply_move_learn_move_tile_style(button, move_index == move_learn_selected_replace_slot)
	if move_learn_confirm_button != null:
		move_learn_confirm_button.disabled = move_learn_selected_replace_slot < 0

func _on_move_learn_confirm_pressed() -> void:
	if move_learn_selected_replace_slot < 0:
		move_learn_status_label.text = "Select a move to replace first."
		move_learn_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		return
	var replace_slot := move_learn_selected_replace_slot
	var pokemon := _find_party_pokemon_by_owned_id(int(move_learn_active_prompt.get("pokemonId", 0)))
	if pokemon != null and replace_slot >= pokemon.moves.size():
		replace_slot = -1
	await _submit_move_learn_choice(replace_slot, false)

func _show_move_learn_hover_panel(anchor: Control, move_value: Variant) -> void:
	if move_learn_hover_panel == null:
		return
	for child: Node in move_learn_hover_panel.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	move_learn_hover_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var name_label := Label.new()
	name_label.text = _get_summary_move_name(move_value)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(name_label)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 7)
	stack.add_child(chip_row)
	var move_type := _get_summary_move_type(move_value)
	if move_type != "":
		chip_row.add_child(_create_move_learn_type_label(move_type))
	var category := _get_summary_move_category_text(move_value)
	if category != "":
		chip_row.add_child(_create_move_learn_category_label(category))

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 6)
	stack.add_child(meta_row)
	meta_row.add_child(_create_move_learn_hover_stat("Power", _get_summary_move_power_text(move_value), Color("#f2cf78")))
	meta_row.add_child(_create_move_learn_hover_stat("Acc", _get_summary_move_accuracy_text(move_value), Color("#d9ecff")))
	meta_row.add_child(_create_move_learn_hover_stat("PP", _get_summary_move_pp_text(move_value).split("/", false, 1)[0], Color("#7df2e8")))

	var description := _get_summary_move_description_text(move_value)
	if description != "":
		var description_label := Label.new()
		description_label.text = description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.max_lines_visible = 2
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description_label.add_theme_font_size_override("font_size", 13)
		description_label.add_theme_color_override("font_color", UI_TEXT)
		stack.add_child(description_label)

	var panel_size := Vector2(280, 154)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var anchor_rect := anchor.get_global_rect()
	var position := Vector2(anchor_rect.position.x + anchor_rect.size.x - 4.0, anchor_rect.position.y - 8.0)
	if position.x + panel_size.x > viewport_size.x - 12.0:
		position.x = anchor_rect.position.x - panel_size.x + 4.0
	if position.y + panel_size.y > viewport_size.y - 12.0:
		position.y = viewport_size.y - panel_size.y - 12.0
	position.x = max(position.x, 12.0)
	position.y = max(position.y, 12.0)
	move_learn_hover_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	move_learn_hover_panel.position = position
	move_learn_hover_panel.size = panel_size
	move_learn_hover_panel.custom_minimum_size = panel_size
	move_learn_hover_panel.offset_left = position.x
	move_learn_hover_panel.offset_top = position.y
	move_learn_hover_panel.offset_right = position.x + panel_size.x
	move_learn_hover_panel.offset_bottom = position.y + panel_size.y
	move_learn_hover_panel.visible = true
	move_learn_hover_panel.move_to_front()

func _hide_move_learn_hover_panel() -> void:
	if move_learn_hover_panel != null:
		move_learn_hover_panel.visible = false

func _create_move_learn_hover_stat(label_text: String, value_text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(82, 20)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#141923d8"), Color(color.r, color.g, color.b, 0.48), 2, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "%s %s" % [label_text, value_text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	return panel

func _create_move_learn_detail_chip(text: String, background_color: Color, text_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(background_color, Color("#4c463d"), 2, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", text_color)
	margin.add_child(label)
	return panel

func _create_move_learn_type_label(type_name: String) -> Control:
	var normalized_type := type_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	var texture_path := "%s%s.png" % [MOVE_LEARN_TYPE_LABEL_ROOT, normalized_type]
	if normalized_type == "" or not ResourceLoader.exists(texture_path):
		return _create_move_learn_detail_chip(type_name, Color("#34312a"), Color("#f4f0de"))

	var texture := load(texture_path) as Texture2D
	if texture == null:
		return _create_move_learn_detail_chip(type_name, Color("#34312a"), Color("#f4f0de"))

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(94, 19)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = type_name.capitalize()
	return icon

func _create_move_learn_category_label(category: String) -> Control:
	var key := category.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	var texture_path := str(MOVE_CATEGORY_LABEL_PATHS.get(key, ""))
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return _create_move_learn_detail_chip(category, Color("#34312a"), Color("#f4f0de"))

	var texture := load(texture_path) as Texture2D
	if texture == null:
		return _create_move_learn_detail_chip(category, Color("#34312a"), Color("#f4f0de"))

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(94, 27)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = category
	return icon

func _get_summary_move_category_text(move_value: Variant) -> String:
	var category_value: Variant = _get_summary_move_data_value(move_value, ["category", "damageClass", "damage_class"], "")
	var category := str(category_value).strip_edges()
	return _format_identifier_display_name(category) if category != "" else ""

func _on_move_learn_skip_pressed() -> void:
	await _submit_move_learn_choice(-1, true)

func _submit_move_learn_choice(replace_slot: int, skip: bool) -> void:
	if move_learn_processing or move_learn_active_prompt.is_empty():
		return

	_hide_move_learn_hover_panel()
	move_learn_processing = true
	_set_move_learn_controls_disabled(true)
	var move_id := _move_learn_prompt_move_id(move_learn_active_prompt)
	var move_name := _move_learn_prompt_move_name(move_learn_active_prompt)
	var pokemon_id := int(move_learn_active_prompt.get("pokemonId", 0))
	move_learn_status_label.text = "Saving..."
	var result: Dictionary = await PlayerPartyStateService.learn_pokemon_move(pokemon_id, move_id, replace_slot, skip)
	move_learn_processing = false

	if not bool(result.get("success", false)):
		move_learn_status_label.text = str(result.get("error", "Could not save move choice."))
		_set_move_learn_controls_disabled(false)
		return

	_emit_move_learn_result_message(result, str(move_learn_active_prompt.get("species", "Pokemon")), move_name, skip)

	move_learn_popup.visible = false
	_hide_move_learn_hover_panel()
	move_learn_active_prompt.clear()
	_refresh_party()
	_refresh_open_pokemon_summary_cards()
	_show_next_move_learn_prompt()

func _emit_move_learn_result_message(result: Dictionary, fallback_species: String, fallback_move_name: String, fallback_skipped: bool) -> void:
	var species := fallback_species.strip_edges()
	if species == "":
		species = "Pokemon"

	var learned_move: Dictionary = {}
	var learned_move_value: Variant = result.get("learnedMove", {})
	if learned_move_value is Dictionary:
		learned_move = learned_move_value as Dictionary
	var learned_name := _move_learn_result_move_name(learned_move, fallback_move_name)
	var skipped := bool(result.get("skipped", fallback_skipped))
	if skipped:
		add_system_message("%s did not learn %s." % [species, learned_name])
		return

	var replaced_move: Dictionary = {}
	var replaced_move_value: Variant = result.get("replacedMove", {})
	if replaced_move_value is Dictionary:
		replaced_move = replaced_move_value as Dictionary
	var replaced_name := _move_learn_result_move_name(replaced_move, "")
	if replaced_name != "":
		add_system_message("%s forgot %s and learned %s!" % [species, replaced_name, learned_name])
	else:
		add_system_message("%s learned %s!" % [species, learned_name])

func _move_learn_result_move_name(move_value: Variant, fallback_name: String) -> String:
	if move_value is Dictionary:
		var move_data: Dictionary = move_value as Dictionary
		if not move_data.is_empty():
			var move_name := _get_summary_move_name(move_data).strip_edges()
			if move_name != "":
				return move_name
			var move_id := str(move_data.get("moveId", move_data.get("move_id", ""))).strip_edges()
			if move_id != "":
				return _format_move_name(move_id)
	return fallback_name

func _set_move_learn_controls_disabled(disabled: bool) -> void:
	for button: Button in move_learn_move_buttons:
		button.disabled = disabled
	if move_learn_confirm_button != null:
		move_learn_confirm_button.disabled = disabled or move_learn_selected_replace_slot < 0
	if move_learn_skip_button != null:
		move_learn_skip_button.disabled = disabled

func _find_party_pokemon_by_owned_id(pokemon_id: int) -> Pokemon:
	if pokemon_id <= 0:
		return null
	for pokemon: Pokemon in PlayerSave.party:
		if pokemon.owned_pokemon_id == pokemon_id:
			return pokemon
	return null

func _move_learn_prompt_move_id(prompt: Dictionary) -> String:
	var move_id := str(prompt.get("moveId", prompt.get("move_id", ""))).strip_edges()
	if move_id != "":
		return move_id

	var move_value: Variant = prompt.get("move", {})
	if move_value is Dictionary:
		var move_payload: Dictionary = move_value as Dictionary
		return str(move_payload.get("id", move_payload.get("move", ""))).strip_edges()
	return ""

func _move_learn_prompt_move_name(prompt: Dictionary) -> String:
	var move_name := str(prompt.get("name", "")).strip_edges()
	if move_name != "":
		return move_name
	var move_value: Variant = prompt.get("move", {})
	if move_value is Dictionary:
		return _get_summary_move_name(move_value)
	return _format_move_name(_move_learn_prompt_move_id(prompt))

func _move_learn_prompt_move_value(prompt: Dictionary) -> Variant:
	var move_value: Variant = prompt.get("move", {})
	if move_value is Dictionary:
		var move_payload: Dictionary = (move_value as Dictionary).duplicate(true)
		var move_id := _move_learn_prompt_move_id(prompt)
		if move_id != "" and str(move_payload.get("id", move_payload.get("move", ""))).strip_edges() == "":
			move_payload["id"] = move_id
		if str(move_payload.get("name", "")).strip_edges() == "":
			move_payload["name"] = _move_learn_prompt_move_name(prompt)
		return _merge_summary_move_metadata(move_payload)

	var move_data := prompt.duplicate(true)
	var move_id := _move_learn_prompt_move_id(prompt)
	if move_id != "":
		move_data["id"] = move_id
	if str(move_data.get("name", "")).strip_edges() == "":
		move_data["name"] = _format_move_name(move_id)
	return _merge_summary_move_metadata(move_data)

func _setup_dev_clear_menu_popup() -> void:
	dev_clear_menu_popup = PanelContainer.new()
	dev_clear_menu_popup.name = "DevClearMenuPopup"
	dev_clear_menu_popup.visible = false
	dev_clear_menu_popup.custom_minimum_size = Vector2(220, 164)
	dev_clear_menu_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_clear_menu_popup.z_index = UI_BASE_Z_INDEX
	dev_clear_menu_popup.anchor_left = 0.0
	dev_clear_menu_popup.anchor_top = 0.0
	dev_clear_menu_popup.anchor_right = 0.0
	dev_clear_menu_popup.anchor_bottom = 0.0
	dev_clear_menu_popup.offset_left = 0.0
	dev_clear_menu_popup.offset_top = 0.0
	dev_clear_menu_popup.offset_right = 220.0
	dev_clear_menu_popup.offset_bottom = 164.0
	dev_clear_menu_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(dev_clear_menu_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	dev_clear_menu_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(header)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 28)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_dev_clear_menu_popup)
	header.add_child(close_button)

	var party_button := Button.new()
	party_button.text = "Party"
	party_button.focus_mode = Control.FOCUS_NONE
	party_button.pressed.connect(_on_dev_clear_party_option_pressed)
	layout.add_child(party_button)

	var inventory_button := Button.new()
	inventory_button.text = "Inventory"
	inventory_button.focus_mode = Control.FOCUS_NONE
	inventory_button.pressed.connect(_on_dev_clear_inventory_option_pressed)
	layout.add_child(inventory_button)

	_apply_button_style(close_button)
	_apply_button_style(party_button, "danger")
	_apply_button_style(inventory_button, "danger")

func _setup_pvp_room_popup() -> void:
	pvp_room_popup = PanelContainer.new()
	pvp_room_popup.name = "PvpRoomPopup"
	pvp_room_popup.visible = false
	pvp_room_popup.custom_minimum_size = Vector2(980, 620)
	pvp_room_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	pvp_room_popup.z_index = UI_BASE_Z_INDEX
	pvp_room_popup.anchor_left = 0.5
	pvp_room_popup.anchor_top = 0.5
	pvp_room_popup.anchor_right = 0.5
	pvp_room_popup.anchor_bottom = 0.5
	pvp_room_popup.offset_left = -490
	pvp_room_popup.offset_top = -310
	pvp_room_popup.offset_right = 490
	pvp_room_popup.offset_bottom = 310
	pvp_room_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(pvp_room_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 14)
	pvp_room_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin_container.add_child(layout)

	var title := Label.new()
	title.text = "Ladder"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f5df9a"))
	layout.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 14)
	layout.add_child(tabs)

	var search_tab := HBoxContainer.new()
	search_tab.name = "Play"
	search_tab.add_theme_constant_override("separation", 14)
	tabs.add_child(search_tab)

	var ladder_sidebar := PanelContainer.new()
	ladder_sidebar.custom_minimum_size = Vector2(270, 0)
	ladder_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ladder_sidebar.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ee8"), Color("#315070"), 6, 1))
	search_tab.add_child(ladder_sidebar)

	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 12)
	sidebar_margin.add_theme_constant_override("margin_top", 10)
	sidebar_margin.add_theme_constant_override("margin_right", 12)
	sidebar_margin.add_theme_constant_override("margin_bottom", 10)
	ladder_sidebar.add_child(sidebar_margin)

	var battle_tab := VBoxContainer.new()
	battle_tab.add_theme_constant_override("separation", 9)
	sidebar_margin.add_child(battle_tab)

	var ladder_main := VBoxContainer.new()
	ladder_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ladder_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ladder_main.add_theme_constant_override("separation", 10)
	search_tab.add_child(ladder_main)

	ladder_main.add_child(_create_pvp_ruleset_panel())

	pvp_room_code_label = Label.new()
	pvp_room_code_label.text = "Room Code"
	pvp_room_code_label.add_theme_font_size_override("font_size", 16)
	pvp_room_code_label.add_theme_color_override("font_color", Color("#f5df9a"))
	battle_tab.add_child(pvp_room_code_label)

	pvp_room_status_label = Label.new()
	pvp_room_status_label.text = "Ready."
	pvp_room_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_room_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	battle_tab.add_child(pvp_room_status_label)

	pvp_room_code_input = LineEdit.new()
	pvp_room_code_input.placeholder_text = "Room code"
	pvp_room_code_input.max_length = 12
	pvp_room_code_input.custom_minimum_size = Vector2(0, 34)
	battle_tab.add_child(pvp_room_code_input)
	_apply_line_edit_style(pvp_room_code_input)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	battle_tab.add_child(actions)

	pvp_create_room_button = Button.new()
	pvp_create_room_button.text = "Create Room"
	pvp_create_room_button.custom_minimum_size = Vector2(112, 34)
	pvp_create_room_button.focus_mode = Control.FOCUS_NONE
	pvp_create_room_button.pressed.connect(_on_pvp_create_room_pressed)
	actions.add_child(pvp_create_room_button)

	pvp_join_room_button = Button.new()
	pvp_join_room_button.text = "Join Room"
	pvp_join_room_button.custom_minimum_size = Vector2(100, 34)
	pvp_join_room_button.focus_mode = Control.FOCUS_NONE
	pvp_join_room_button.pressed.connect(_on_pvp_join_room_pressed)
	actions.add_child(pvp_join_room_button)

	pvp_copy_code_button = Button.new()
	pvp_copy_code_button.text = "Copy"
	pvp_copy_code_button.custom_minimum_size = Vector2(72, 34)
	pvp_copy_code_button.focus_mode = Control.FOCUS_NONE
	pvp_copy_code_button.disabled = true
	pvp_copy_code_button.pressed.connect(_on_pvp_copy_code_pressed)
	actions.add_child(pvp_copy_code_button)

	var queue_separator := HSeparator.new()
	battle_tab.add_child(queue_separator)

	var queue_title := Label.new()
	queue_title.text = "Matchmaking"
	queue_title.add_theme_font_size_override("font_size", 16)
	queue_title.add_theme_color_override("font_color", Color("#f5df9a"))
	battle_tab.add_child(queue_title)

	var queue_select_row := HBoxContainer.new()
	queue_select_row.add_theme_constant_override("separation", 8)
	battle_tab.add_child(queue_select_row)

	var queue_select_label := Label.new()
	queue_select_label.text = "Tier"
	queue_select_label.custom_minimum_size = Vector2(56, 0)
	queue_select_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_select_label.add_theme_color_override("font_color", UI_TEXT)
	queue_select_row.add_child(queue_select_label)

	pvp_queue_select = OptionButton.new()
	pvp_queue_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp_queue_select.focus_mode = Control.FOCUS_NONE
	pvp_queue_select.item_selected.connect(_on_pvp_queue_selected)
	queue_select_row.add_child(pvp_queue_select)
	_populate_pvp_queue_select([
		{"id": "casual_queue_v1", "name": "Casual Queue", "mode": "casual"},
	])

	pvp_queue_status_label = Label.new()
	pvp_queue_status_label.text = "Queue Status: idle"
	pvp_queue_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_queue_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	battle_tab.add_child(pvp_queue_status_label)

	var queue_actions := HBoxContainer.new()
	queue_actions.add_theme_constant_override("separation", 8)
	battle_tab.add_child(queue_actions)

	pvp_join_queue_button = Button.new()
	pvp_join_queue_button.text = "Join Queue"
	pvp_join_queue_button.custom_minimum_size = Vector2(106, 34)
	pvp_join_queue_button.focus_mode = Control.FOCUS_NONE
	pvp_join_queue_button.pressed.connect(_on_pvp_join_queue_pressed)
	queue_actions.add_child(pvp_join_queue_button)

	pvp_leave_queue_button = Button.new()
	pvp_leave_queue_button.text = "Leave Queue"
	pvp_leave_queue_button.custom_minimum_size = Vector2(110, 34)
	pvp_leave_queue_button.focus_mode = Control.FOCUS_NONE
	pvp_leave_queue_button.disabled = true
	pvp_leave_queue_button.pressed.connect(_on_pvp_leave_queue_pressed)
	queue_actions.add_child(pvp_leave_queue_button)

	pvp_reconnect_battle_button = Button.new()
	pvp_reconnect_battle_button.text = "Reconnect"
	pvp_reconnect_battle_button.custom_minimum_size = Vector2(110, 34)
	pvp_reconnect_battle_button.focus_mode = Control.FOCUS_NONE
	pvp_reconnect_battle_button.pressed.connect(_on_pvp_reconnect_battle_pressed)
	queue_actions.add_child(pvp_reconnect_battle_button)

	var history_tab := VBoxContainer.new()
	history_tab.name = "Battle History"
	history_tab.add_theme_constant_override("separation", 10)
	tabs.add_child(history_tab)

	var history_header := HBoxContainer.new()
	history_header.add_theme_constant_override("separation", 8)
	history_tab.add_child(history_header)

	pvp_history_status_label = Label.new()
	pvp_history_status_label.text = "Recent matches"
	pvp_history_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp_history_status_label.add_theme_color_override("font_color", UI_TEXT)
	history_header.add_child(pvp_history_status_label)

	pvp_history_refresh_button = Button.new()
	pvp_history_refresh_button.text = "Refresh"
	pvp_history_refresh_button.custom_minimum_size = Vector2(92, 32)
	pvp_history_refresh_button.focus_mode = Control.FOCUS_NONE
	pvp_history_refresh_button.pressed.connect(_on_pvp_history_refresh_pressed)
	history_header.add_child(pvp_history_refresh_button)

	var history_scroll := ScrollContainer.new()
	history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_tab.add_child(history_scroll)

	pvp_history_list = VBoxContainer.new()
	pvp_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp_history_list.add_theme_constant_override("separation", 8)
	history_scroll.add_child(pvp_history_list)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 32)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_pvp_room_popup)
	layout.add_child(close_button)

	_apply_button_style(pvp_create_room_button, "primary")
	_apply_button_style(pvp_join_room_button)
	_apply_button_style(pvp_copy_code_button)
	_apply_button_style(pvp_join_queue_button, "primary")
	_apply_button_style(pvp_leave_queue_button)
	_apply_button_style(pvp_reconnect_battle_button)
	_apply_button_style(pvp_history_refresh_button)
	_apply_button_style(close_button)

	pvp_poll_timer = Timer.new()
	pvp_poll_timer.wait_time = 2.0
	pvp_poll_timer.one_shot = false
	pvp_poll_timer.timeout.connect(_on_pvp_poll_timeout)
	add_child(pvp_poll_timer)

	pvp_poll_request = HTTPRequest.new()
	pvp_poll_request.request_completed.connect(_on_pvp_room_poll_completed)
	add_child(pvp_poll_request)

func _create_pvp_ruleset_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ee8"), Color("#8aa0b8aa"), 6, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Ruleset"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#f5df9a"))
	layout.add_child(title)

	var rules: Array[Dictionary] = [
		{"title": "Format", "body": "Gen 9 National Dex. Queue selection decides casual or ranked processing."},
		{"title": "Species", "body": "Prevents having 2 or more of the same Pokemon on a team."},
		{"title": "OHKO", "body": "Prevents one-hit KO moves from being used."},
		{"title": "Evasion", "body": "Prevents moves that boost evasion from being used."},
		{"title": "Timers", "body": "Server-authoritative timers are enforced by the PvP foundation."},
		{"title": "Disconnects", "body": "Reconnect grace is tracked server-side; expired grace can end the match."},
	]
	for rule: Dictionary in rules:
		layout.add_child(_create_pvp_ruleset_row(str(rule["title"]), str(rule["body"])))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	return panel

func _create_pvp_ruleset_row(title_text: String, body_text: String) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _make_panel_style(Color("#111926bb"), Color("#c7ced9aa"), 4, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	margin.add_child(layout)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#cfe8ff"))
	layout.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(body)

	return row

func _setup_dev_add_item_tools() -> void:
	var dev_actions_container := dev_clear_party_button.get_parent()

	dev_add_button = Button.new()
	dev_add_button.text = "Add"
	dev_add_button.custom_minimum_size = Vector2(190, 34)
	dev_add_button.focus_mode = Control.FOCUS_NONE
	if dev_actions_container != null:
		dev_actions_container.add_child(dev_add_button)
		dev_actions_container.move_child(dev_add_button, dev_clear_party_button.get_index())

	dev_heal_party_button = Button.new()
	dev_heal_party_button.text = "Heal"
	dev_heal_party_button.custom_minimum_size = Vector2(190, 34)
	dev_heal_party_button.focus_mode = Control.FOCUS_NONE
	if dev_actions_container != null:
		dev_actions_container.add_child(dev_heal_party_button)
		dev_actions_container.move_child(dev_heal_party_button, dev_clear_party_button.get_index())

	dev_preview_evolution_button = Button.new()
	dev_preview_evolution_button.text = "Preview Evolution"
	dev_preview_evolution_button.custom_minimum_size = Vector2(190, 34)
	dev_preview_evolution_button.focus_mode = Control.FOCUS_NONE
	if dev_actions_container != null:
		dev_actions_container.add_child(dev_preview_evolution_button)
		dev_actions_container.move_child(dev_preview_evolution_button, dev_clear_party_button.get_index())

	dev_add_menu_popup = PanelContainer.new()
	dev_add_menu_popup.name = "DevAddMenuPopup"
	dev_add_menu_popup.visible = false
	dev_add_menu_popup.custom_minimum_size = Vector2(220, 168)
	dev_add_menu_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_add_menu_popup.z_index = UI_BASE_Z_INDEX
	dev_add_menu_popup.anchor_left = 0.0
	dev_add_menu_popup.anchor_top = 0.0
	dev_add_menu_popup.anchor_right = 0.0
	dev_add_menu_popup.anchor_bottom = 0.0
	dev_add_menu_popup.offset_left = 0.0
	dev_add_menu_popup.offset_top = 0.0
	dev_add_menu_popup.offset_right = 220.0
	dev_add_menu_popup.offset_bottom = 168.0
	dev_add_menu_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(dev_add_menu_popup)

	var add_margin_container := MarginContainer.new()
	add_margin_container.add_theme_constant_override("margin_left", 12)
	add_margin_container.add_theme_constant_override("margin_top", 12)
	add_margin_container.add_theme_constant_override("margin_right", 12)
	add_margin_container.add_theme_constant_override("margin_bottom", 12)
	dev_add_menu_popup.add_child(add_margin_container)

	var add_layout := VBoxContainer.new()
	add_layout.add_theme_constant_override("separation", 8)
	add_margin_container.add_child(add_layout)

	dev_add_item_button = Button.new()
	dev_add_item_button.text = "Add Item"
	dev_add_item_button.custom_minimum_size = Vector2(190, 34)
	dev_add_item_button.focus_mode = Control.FOCUS_NONE
	add_layout.add_child(dev_add_item_button)

	dev_add_money_button = Button.new()
	dev_add_money_button.text = "Add Money"
	dev_add_money_button.custom_minimum_size = Vector2(190, 34)
	dev_add_money_button.focus_mode = Control.FOCUS_NONE
	add_layout.add_child(dev_add_money_button)

	var add_close_button := Button.new()
	add_close_button.text = "Close"
	add_close_button.custom_minimum_size = Vector2(190, 34)
	add_close_button.focus_mode = Control.FOCUS_NONE
	add_close_button.pressed.connect(_hide_dev_add_menu_popup)
	add_layout.add_child(add_close_button)

	_apply_button_style(dev_add_button, "primary")
	_apply_button_style(dev_heal_party_button, "primary")
	_apply_button_style(dev_preview_evolution_button, "primary")
	_apply_button_style(dev_add_item_button, "primary")
	_apply_button_style(dev_add_money_button, "primary")
	_apply_button_style(add_close_button)

	dev_add_item_popup = PanelContainer.new()
	dev_add_item_popup.name = "DevAddItemPopup"
	dev_add_item_popup.visible = false
	dev_add_item_popup.custom_minimum_size = Vector2(460, 430)
	dev_add_item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_add_item_popup.z_index = UI_BASE_Z_INDEX
	dev_add_item_popup.anchor_left = 0.5
	dev_add_item_popup.anchor_top = 0.5
	dev_add_item_popup.anchor_right = 0.5
	dev_add_item_popup.anchor_bottom = 0.5
	dev_add_item_popup.offset_left = -230
	dev_add_item_popup.offset_top = -215
	dev_add_item_popup.offset_right = 230
	dev_add_item_popup.offset_bottom = 215
	dev_add_item_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(dev_add_item_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	dev_add_item_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title_label := Label.new()
	title_label.text = "Add Item"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_dev_add_item_popup)
	header.add_child(close_button)

	dev_item_search_input = LineEdit.new()
	dev_item_search_input.placeholder_text = "Search item..."
	dev_item_search_input.text_changed.connect(_on_dev_item_search_changed)
	layout.add_child(dev_item_search_input)

	var results_scroll := ScrollContainer.new()
	results_scroll.custom_minimum_size = Vector2(0, 220)
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(results_scroll)

	dev_item_results_list = VBoxContainer.new()
	dev_item_results_list.add_theme_constant_override("separation", 6)
	dev_item_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(dev_item_results_list)

	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 8)
	layout.add_child(quantity_row)

	var quantity_label := Label.new()
	quantity_label.text = "Amount"
	quantity_label.custom_minimum_size = Vector2(96, 0)
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", UI_TEXT)
	quantity_row.add_child(quantity_label)

	dev_item_quantity_spinbox = SpinBox.new()
	dev_item_quantity_spinbox.min_value = 1
	dev_item_quantity_spinbox.max_value = 999999
	dev_item_quantity_spinbox.value = 1
	dev_item_quantity_spinbox.step = 1
	dev_item_quantity_spinbox.custom_minimum_size = Vector2(130, 0)
	dev_item_quantity_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_child(dev_item_quantity_spinbox)

	dev_item_confirm_button = Button.new()
	dev_item_confirm_button.text = "Confirm"
	dev_item_confirm_button.custom_minimum_size = Vector2(0, 36)
	dev_item_confirm_button.disabled = true
	dev_item_confirm_button.focus_mode = Control.FOCUS_NONE
	dev_item_confirm_button.pressed.connect(_on_dev_item_confirm_pressed)
	layout.add_child(dev_item_confirm_button)

	_apply_button_style(close_button)
	_apply_line_edit_style(dev_item_search_input)
	_apply_button_style(dev_item_confirm_button, "primary")

	dev_add_money_popup = PanelContainer.new()
	dev_add_money_popup.name = "DevAddMoneyPopup"
	dev_add_money_popup.visible = false
	dev_add_money_popup.custom_minimum_size = Vector2(360, 190)
	dev_add_money_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_add_money_popup.z_index = UI_BASE_Z_INDEX
	dev_add_money_popup.anchor_left = 0.5
	dev_add_money_popup.anchor_top = 0.5
	dev_add_money_popup.anchor_right = 0.5
	dev_add_money_popup.anchor_bottom = 0.5
	dev_add_money_popup.offset_left = -180
	dev_add_money_popup.offset_top = -95
	dev_add_money_popup.offset_right = 180
	dev_add_money_popup.offset_bottom = 95
	dev_add_money_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(dev_add_money_popup)

	var money_margin := MarginContainer.new()
	money_margin.add_theme_constant_override("margin_left", 16)
	money_margin.add_theme_constant_override("margin_top", 14)
	money_margin.add_theme_constant_override("margin_right", 16)
	money_margin.add_theme_constant_override("margin_bottom", 16)
	dev_add_money_popup.add_child(money_margin)

	var money_layout := VBoxContainer.new()
	money_layout.add_theme_constant_override("separation", 10)
	money_margin.add_child(money_layout)

	var money_header := HBoxContainer.new()
	money_header.add_theme_constant_override("separation", 8)
	money_layout.add_child(money_header)

	var money_title := Label.new()
	money_title.text = "Add Money"
	money_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_title.add_theme_font_size_override("font_size", 18)
	money_title.add_theme_color_override("font_color", UI_TEXT)
	money_header.add_child(money_title)

	var money_close_button := Button.new()
	money_close_button.text = "X"
	money_close_button.custom_minimum_size = Vector2(34, 30)
	money_close_button.focus_mode = Control.FOCUS_NONE
	money_close_button.pressed.connect(_hide_dev_add_money_popup)
	money_header.add_child(money_close_button)

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 8)
	money_layout.add_child(money_row)

	var money_label := Label.new()
	money_label.text = "Amount"
	money_label.custom_minimum_size = Vector2(96, 0)
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_color_override("font_color", UI_TEXT)
	money_row.add_child(money_label)

	dev_money_amount_spinbox = SpinBox.new()
	dev_money_amount_spinbox.min_value = 1
	dev_money_amount_spinbox.max_value = 999999999
	dev_money_amount_spinbox.value = 1000
	dev_money_amount_spinbox.step = 1
	dev_money_amount_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_row.add_child(dev_money_amount_spinbox)

	dev_money_confirm_button = Button.new()
	dev_money_confirm_button.text = "Confirm"
	dev_money_confirm_button.custom_minimum_size = Vector2(0, 36)
	dev_money_confirm_button.focus_mode = Control.FOCUS_NONE
	dev_money_confirm_button.pressed.connect(_on_dev_money_confirm_pressed)
	money_layout.add_child(dev_money_confirm_button)

	_apply_button_style(money_close_button)
	_apply_button_style(dev_money_confirm_button, "primary")

func _setup_staff_impersonation_tools() -> void:
	if staff_tools_popup != null:
		return

	staff_tools_popup = PanelContainer.new()
	staff_tools_popup.name = "StaffToolsPopup"
	staff_tools_popup.visible = false
	staff_tools_popup.custom_minimum_size = Vector2(230, 128)
	staff_tools_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	staff_tools_popup.z_index = UI_BASE_Z_INDEX
	staff_tools_popup.anchor_left = 0.5
	staff_tools_popup.anchor_top = 0.5
	staff_tools_popup.anchor_right = 0.5
	staff_tools_popup.anchor_bottom = 0.5
	staff_tools_popup.offset_left = -115
	staff_tools_popup.offset_top = -64
	staff_tools_popup.offset_right = 115
	staff_tools_popup.offset_bottom = 64
	staff_tools_popup.add_theme_stylebox_override("panel", _make_glass_panel_style(10, 1))
	root_control.add_child(staff_tools_popup)

	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_left", 12)
	tools_margin.add_theme_constant_override("margin_top", 12)
	tools_margin.add_theme_constant_override("margin_right", 12)
	tools_margin.add_theme_constant_override("margin_bottom", 12)
	staff_tools_popup.add_child(tools_margin)

	var tools_layout := VBoxContainer.new()
	tools_layout.add_theme_constant_override("separation", 7)
	tools_margin.add_child(tools_layout)

	var staff_tools_title: Label = Label.new()
	staff_tools_title.text = "Staff Tools"
	staff_tools_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	staff_tools_title.add_theme_font_size_override("font_size", 16)
	staff_tools_title.add_theme_color_override("font_color", UI_BORDER)
	tools_layout.add_child(staff_tools_title)

	staff_impersonate_button = Button.new()
	staff_impersonate_button.text = "Impersonate"
	staff_impersonate_button.custom_minimum_size = Vector2(190, 32)
	staff_impersonate_button.focus_mode = Control.FOCUS_NONE
	staff_impersonate_button.pressed.connect(_on_staff_impersonate_button_pressed)
	tools_layout.add_child(staff_impersonate_button)

	var staff_tools_close_button := Button.new()
	staff_tools_close_button.text = "Close"
	staff_tools_close_button.custom_minimum_size = Vector2(190, 32)
	staff_tools_close_button.focus_mode = Control.FOCUS_NONE
	staff_tools_close_button.pressed.connect(_hide_staff_tools_popup)
	tools_layout.add_child(staff_tools_close_button)

	staff_impersonate_popup = PanelContainer.new()
	staff_impersonate_popup.name = "StaffImpersonatePopup"
	staff_impersonate_popup.visible = false
	staff_impersonate_popup.custom_minimum_size = Vector2(500, 210)
	staff_impersonate_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	staff_impersonate_popup.z_index = UI_BASE_Z_INDEX
	staff_impersonate_popup.anchor_left = 0.5
	staff_impersonate_popup.anchor_top = 0.5
	staff_impersonate_popup.anchor_right = 0.5
	staff_impersonate_popup.anchor_bottom = 0.5
	staff_impersonate_popup.offset_left = -250
	staff_impersonate_popup.offset_top = -105
	staff_impersonate_popup.offset_right = 250
	staff_impersonate_popup.offset_bottom = 105
	staff_impersonate_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(staff_impersonate_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	staff_impersonate_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title_label := Label.new()
	title_label.text = "Staff Impersonation"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_staff_impersonate_popup)
	header.add_child(close_button)

	var description_label := Label.new()
	description_label.text = "Paste the impersonation token generated in the admin portal."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(description_label)

	staff_impersonate_token_input = LineEdit.new()
	staff_impersonate_token_input.placeholder_text = "Impersonation token"
	staff_impersonate_token_input.custom_minimum_size = Vector2(0, 38)
	layout.add_child(staff_impersonate_token_input)

	staff_impersonate_confirm_button = Button.new()
	staff_impersonate_confirm_button.text = "Start impersonation"
	staff_impersonate_confirm_button.custom_minimum_size = Vector2(0, 36)
	staff_impersonate_confirm_button.focus_mode = Control.FOCUS_NONE
	staff_impersonate_confirm_button.pressed.connect(_on_staff_impersonate_confirm_pressed)
	layout.add_child(staff_impersonate_confirm_button)

	_apply_button_style(staff_impersonate_button, "primary")
	_apply_button_style(staff_tools_close_button)
	_apply_button_style(close_button)
	_apply_line_edit_style(staff_impersonate_token_input)
	_apply_button_style(staff_impersonate_confirm_button, "primary")

func _setup_item_dex_button() -> void:
	if item_dex_button != null:
		item_dex_button.focus_mode = Control.FOCUS_NONE

func _setup_pokedex_button() -> void:
	if pokedex_button != null:
		pokedex_button.focus_mode = Control.FOCUS_NONE

func _setup_item_dex_popup() -> void:
	item_dex_popup = PanelContainer.new()
	item_dex_popup.name = "ItemDexPopup"
	item_dex_popup.visible = false
	item_dex_popup.custom_minimum_size = ITEM_DEX_SIZE
	item_dex_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_dex_popup.z_index = UI_BASE_Z_INDEX
	item_dex_popup.anchor_left = 0.5
	item_dex_popup.anchor_top = 0.5
	item_dex_popup.anchor_right = 0.5
	item_dex_popup.anchor_bottom = 0.5
	item_dex_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#020711fa"), Color("#d6c78faa"), 4, 1))
	root_control.add_child(item_dex_popup)
	_position_item_dex_popup()

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 18)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 18)
	margin_container.add_theme_constant_override("margin_bottom", 18)
	item_dex_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin_container.add_child(layout)

	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 44)
	header_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_panel.gui_input.connect(_on_item_dex_header_gui_input)
	header_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#c7bea0dd"), Color("#f2ead2aa"), 2, 1))
	layout.add_child(header_panel)

	var header_margin := MarginContainer.new()
	header_margin.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_margin.gui_input.connect(_on_item_dex_header_gui_input)
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_right", 8)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_panel.add_child(header_margin)

	var header := HBoxContainer.new()
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_item_dex_header_gui_input)
	header.add_theme_constant_override("separation", 8)
	header_margin.add_child(header)

	var title_label := Label.new()
	title_label.text = "Item Dex"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.gui_input.connect(_on_item_dex_header_gui_input)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("#ffffff"))
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_item_dex_popup)
	header.add_child(close_button)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 12)
	layout.add_child(content_row)

	var browser_panel := PanelContainer.new()
	browser_panel.custom_minimum_size = Vector2(320, 0)
	browser_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#061120f0"), Color("#d6c78f66"), 4, 1))
	content_row.add_child(browser_panel)

	var browser_margin := MarginContainer.new()
	browser_margin.add_theme_constant_override("margin_left", 10)
	browser_margin.add_theme_constant_override("margin_top", 10)
	browser_margin.add_theme_constant_override("margin_right", 10)
	browser_margin.add_theme_constant_override("margin_bottom", 10)
	browser_panel.add_child(browser_margin)

	var browser_stack := VBoxContainer.new()
	browser_stack.add_theme_constant_override("separation", 8)
	browser_margin.add_child(browser_stack)

	var browser_label := Label.new()
	browser_label.text = "ITEMS"
	browser_label.add_theme_font_size_override("font_size", 10)
	browser_label.add_theme_color_override("font_color", Color("#d6c78f"))
	browser_stack.add_child(browser_label)

	item_dex_search_input = LineEdit.new()
	item_dex_search_input.placeholder_text = "Search item..."
	item_dex_search_input.text_changed.connect(_on_item_dex_search_changed)
	browser_stack.add_child(item_dex_search_input)

	var results_scroll := ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browser_stack.add_child(results_scroll)

	item_dex_results_list = VBoxContainer.new()
	item_dex_results_list.add_theme_constant_override("separation", 6)
	item_dex_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(item_dex_results_list)

	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(560, 0)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ef2"), Color("#d6c78f66"), 4, 1))
	content_row.add_child(summary_panel)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 16)
	summary_margin.add_theme_constant_override("margin_top", 14)
	summary_margin.add_theme_constant_override("margin_right", 16)
	summary_margin.add_theme_constant_override("margin_bottom", 16)
	summary_panel.add_child(summary_margin)

	var summary_layout := VBoxContainer.new()
	summary_layout.add_theme_constant_override("separation", 12)
	summary_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_margin.add_child(summary_layout)

	var hero_row := HBoxContainer.new()
	hero_row.custom_minimum_size = Vector2(0, 150)
	hero_row.add_theme_constant_override("separation", 16)
	summary_layout.add_child(hero_row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(150, 132)
	icon_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#071b2ce8"), Color("#d6c78f66"), 3, 1))
	hero_row.add_child(icon_panel)

	var icon_center := CenterContainer.new()
	icon_panel.add_child(icon_center)

	item_dex_icon = TextureRect.new()
	item_dex_icon.custom_minimum_size = Vector2(96, 96)
	item_dex_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_dex_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(item_dex_icon)

	var hero_stack := VBoxContainer.new()
	hero_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_stack.add_theme_constant_override("separation", 8)
	hero_row.add_child(hero_stack)

	item_dex_name_label = Label.new()
	item_dex_name_label.text = "Select an item"
	item_dex_name_label.add_theme_font_size_override("font_size", 24)
	item_dex_name_label.add_theme_color_override("font_color", UI_TEXT)
	hero_stack.add_child(item_dex_name_label)

	item_dex_meta_label = Label.new()
	item_dex_meta_label.text = "Category: -    Base price: Unknown"
	item_dex_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_meta_label.add_theme_font_size_override("font_size", 12)
	item_dex_meta_label.add_theme_color_override("font_color", Color("#d6c78f"))
	hero_stack.add_child(item_dex_meta_label)

	summary_layout.add_child(_create_pokedex_section_title("Description"))

	item_dex_description_label = Label.new()
	item_dex_description_label.text = "Search and select an item to view its summary."
	item_dex_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_description_label.add_theme_font_size_override("font_size", 13)
	item_dex_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	summary_layout.add_child(item_dex_description_label)

	item_dex_effect_section_label = _create_pokedex_section_title("Effect")
	item_dex_effect_section_label.visible = false
	summary_layout.add_child(item_dex_effect_section_label)

	item_dex_effect_label = Label.new()
	item_dex_effect_label.visible = false
	item_dex_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_effect_label.add_theme_font_size_override("font_size", 13)
	item_dex_effect_label.add_theme_color_override("font_color", Color("#f2cf78"))
	summary_layout.add_child(item_dex_effect_label)

	item_dex_capture_section_label = _create_pokedex_section_title("Capture")
	item_dex_capture_section_label.visible = false
	summary_layout.add_child(item_dex_capture_section_label)

	item_dex_capture_label = Label.new()
	item_dex_capture_label.visible = false
	item_dex_capture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_capture_label.add_theme_font_size_override("font_size", 13)
	item_dex_capture_label.add_theme_color_override("font_color", Color("#f2cf78"))
	summary_layout.add_child(item_dex_capture_label)

	summary_layout.add_child(_create_pokedex_section_title("Where to get"))

	var sources_scroll := ScrollContainer.new()
	sources_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sources_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_layout.add_child(sources_scroll)

	item_dex_sources_label = Label.new()
	item_dex_sources_label.text = "Where to get\nNo item selected."
	item_dex_sources_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_sources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_dex_sources_label.add_theme_font_size_override("font_size", 12)
	item_dex_sources_label.add_theme_color_override("font_color", UI_TEXT)
	sources_scroll.add_child(item_dex_sources_label)

	_apply_button_style(close_button)
	_apply_line_edit_style(item_dex_search_input)

func _position_item_dex_popup() -> void:
	if item_dex_popup == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_size := Vector2(
		min(ITEM_DEX_SIZE.x, max(viewport_size.x - 32.0, 360.0)),
		min(ITEM_DEX_SIZE.y, max(viewport_size.y - 32.0, 360.0))
	)
	item_dex_popup.custom_minimum_size = popup_size
	item_dex_popup.offset_left = -popup_size.x * 0.5
	item_dex_popup.offset_top = -popup_size.y * 0.5
	item_dex_popup.offset_right = popup_size.x * 0.5
	item_dex_popup.offset_bottom = popup_size.y * 0.5

func _setup_pokedex_popup() -> void:
	pokedex_popup = PanelContainer.new()
	pokedex_popup.name = "PokedexPopup"
	pokedex_popup.visible = false
	pokedex_popup.custom_minimum_size = POKEDEX_SIZE
	pokedex_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	pokedex_popup.z_index = UI_BASE_Z_INDEX
	pokedex_popup.anchor_left = 0.5
	pokedex_popup.anchor_top = 0.5
	pokedex_popup.anchor_right = 0.5
	pokedex_popup.anchor_bottom = 0.5
	pokedex_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#020711fa"), Color("#d6c78faa"), 4, 1))
	root_control.add_child(pokedex_popup)
	_position_pokedex_popup()

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 18)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 18)
	margin_container.add_theme_constant_override("margin_bottom", 18)
	pokedex_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin_container.add_child(layout)

	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 44)
	header_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_panel.gui_input.connect(_on_pokedex_header_gui_input)
	header_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#c7bea0dd"), Color("#f2ead2aa"), 2, 1))
	layout.add_child(header_panel)

	var header_margin := MarginContainer.new()
	header_margin.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_margin.gui_input.connect(_on_pokedex_header_gui_input)
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_right", 8)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_panel.add_child(header_margin)

	var header := HBoxContainer.new()
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_pokedex_header_gui_input)
	header.add_theme_constant_override("separation", 8)
	header_margin.add_child(header)

	var title_label := Label.new()
	title_label.text = "Pokédex"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.gui_input.connect(_on_pokedex_header_gui_input)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("#ffffff"))
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(40, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_pokedex_popup)
	header.add_child(close_button)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 12)
	layout.add_child(content_row)

	var browser_panel := PanelContainer.new()
	browser_panel.custom_minimum_size = Vector2(320, 0)
	browser_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#061120f0"), Color("#d6c78f66"), 4, 1))
	content_row.add_child(browser_panel)

	var browser_margin := MarginContainer.new()
	browser_margin.add_theme_constant_override("margin_left", 10)
	browser_margin.add_theme_constant_override("margin_top", 10)
	browser_margin.add_theme_constant_override("margin_right", 10)
	browser_margin.add_theme_constant_override("margin_bottom", 10)
	browser_panel.add_child(browser_margin)

	var browser_stack := VBoxContainer.new()
	browser_stack.add_theme_constant_override("separation", 8)
	browser_margin.add_child(browser_stack)

	var browser_label := Label.new()
	browser_label.text = "SPECIES"
	browser_label.add_theme_font_size_override("font_size", 10)
	browser_label.add_theme_color_override("font_color", Color("#d6c78f"))
	browser_stack.add_child(browser_label)

	pokedex_search_input = LineEdit.new()
	pokedex_search_input.placeholder_text = "Search species..."
	pokedex_search_input.text_changed.connect(_on_pokedex_search_changed)
	browser_stack.add_child(pokedex_search_input)

	pokedex_search_debounce_timer = Timer.new()
	pokedex_search_debounce_timer.one_shot = true
	pokedex_search_debounce_timer.wait_time = 0.16
	pokedex_search_debounce_timer.timeout.connect(_refresh_pokedex_results)
	pokedex_popup.add_child(pokedex_search_debounce_timer)

	var results_scroll := ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browser_stack.add_child(results_scroll)

	pokedex_results_list = VBoxContainer.new()
	pokedex_results_list.add_theme_constant_override("separation", 6)
	pokedex_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(pokedex_results_list)

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(660, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ef2"), Color("#d6c78f66"), 4, 1))
	content_row.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(detail_margin)

	var detail_layout := VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 9)
	detail_margin.add_child(detail_layout)

	var detail_header := HBoxContainer.new()
	detail_header.custom_minimum_size = Vector2(0, 140)
	detail_header.add_theme_constant_override("separation", 8)
	detail_layout.add_child(detail_header)

	var title_stack := VBoxContainer.new()
	title_stack.custom_minimum_size = Vector2(230, 0)
	title_stack.add_theme_constant_override("separation", 6)
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_header.add_child(title_stack)

	pokedex_name_label = Label.new()
	pokedex_name_label.text = "Select a species"
	pokedex_name_label.add_theme_font_size_override("font_size", 24)
	pokedex_name_label.add_theme_color_override("font_color", UI_TEXT)
	title_stack.add_child(pokedex_name_label)

	pokedex_meta_label = Label.new()
	pokedex_meta_label.text = "No species selected."
	pokedex_meta_label.add_theme_font_size_override("font_size", 11)
	pokedex_meta_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	title_stack.add_child(pokedex_meta_label)

	var sprite_stack := VBoxContainer.new()
	sprite_stack.custom_minimum_size = Vector2(190, 0)
	sprite_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	sprite_stack.add_theme_constant_override("separation", 8)
	detail_header.add_child(sprite_stack)

	pokedex_sprite_panel = PanelContainer.new()
	pokedex_sprite_panel.custom_minimum_size = Vector2(176, 132)
	pokedex_sprite_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pokedex_sprite_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pokedex_sprite_panel.tooltip_text = "Show back sprite"
	pokedex_sprite_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#071b2ce8"), Color("#d6c78f66"), 3, 1))
	pokedex_sprite_panel.gui_input.connect(_on_pokedex_sprite_panel_gui_input)
	sprite_stack.add_child(pokedex_sprite_panel)

	var sprite_viewport_container := SubViewportContainer.new()
	sprite_viewport_container.stretch = true
	sprite_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokedex_sprite_panel.add_child(sprite_viewport_container)
	sprite_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	pokedex_sprite_viewport = SubViewport.new()
	pokedex_sprite_viewport.size = Vector2i(176, 132)
	pokedex_sprite_viewport.transparent_bg = true
	pokedex_sprite_viewport.disable_3d = true
	pokedex_sprite_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sprite_viewport_container.add_child(pokedex_sprite_viewport)

	pokedex_animated_sprite = AnimatedSprite2D.new()
	pokedex_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pokedex_animated_sprite.position = Vector2(88, 70)
	pokedex_animated_sprite.visible = false
	pokedex_sprite_viewport.add_child(pokedex_animated_sprite)

	pokedex_sprite = TextureRect.new()
	pokedex_sprite.custom_minimum_size = Vector2(132, 112)
	pokedex_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokedex_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokedex_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokedex_sprite_panel.add_child(pokedex_sprite)
	pokedex_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	pokedex_type_row = HBoxContainer.new()
	pokedex_type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pokedex_type_row.add_theme_constant_override("separation", 5)
	sprite_stack.add_child(pokedex_type_row)

	pokedex_header_stats_stack = VBoxContainer.new()
	pokedex_header_stats_stack.custom_minimum_size = Vector2(208, 0)
	pokedex_header_stats_stack.add_theme_constant_override("separation", 4)
	detail_header.add_child(pokedex_header_stats_stack)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	detail_layout.add_child(tab_row)

	var general_tab := _create_pokedex_tab_button("general", "General")
	tab_row.add_child(general_tab)
	var moves_tab := _create_pokedex_tab_button("moves", "Moves")
	tab_row.add_child(moves_tab)
	var locations_tab := _create_pokedex_tab_button("locations", "Locations")
	tab_row.add_child(locations_tab)
	var evolutions_tab := _create_pokedex_tab_button("evolutions", "Evolutions")
	tab_row.add_child(evolutions_tab)
	var drops_tab := _create_pokedex_tab_button("drops", "Drops")
	tab_row.add_child(drops_tab)
	_refresh_pokedex_tab_buttons()

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_layout.add_child(detail_scroll)

	pokedex_detail_stack = VBoxContainer.new()
	pokedex_detail_stack.add_theme_constant_override("separation", 8)
	pokedex_detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(pokedex_detail_stack)

	_apply_button_style(close_button)
	_apply_line_edit_style(pokedex_search_input)
	_refresh_pokedex_header_stats({})
	_refresh_pokedex_detail()

func _position_pokedex_popup() -> void:
	if pokedex_popup == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_size := Vector2(
		min(POKEDEX_SIZE.x, max(viewport_size.x - 32.0, 360.0)),
		min(POKEDEX_SIZE.y, max(viewport_size.y - 32.0, 360.0))
	)
	pokedex_popup.custom_minimum_size = popup_size
	pokedex_popup.offset_left = -popup_size.x * 0.5
	pokedex_popup.offset_top = -popup_size.y * 0.5
	pokedex_popup.offset_right = popup_size.x * 0.5
	pokedex_popup.offset_bottom = popup_size.y * 0.5

func _process(delta: float) -> void:
	_position_collapsible_buttons()
	_refresh_player_status_card_if_needed()
	_refresh_trainer_card_playtime_if_needed()
	_refresh_location_label_if_needed()
	_refresh_utc_time_label(delta)
	_refresh_staff_tools_visibility_if_needed()
	_refresh_pvp_room_polling(delta)

func _refresh_pvp_room_polling(delta: float) -> void:
	if not pvp_polling_active or pvp_active_room_code == "" or pvp_battle_starting:
		return

	pvp_poll_elapsed -= delta
	if pvp_poll_elapsed > 0.0:
		return

	pvp_poll_elapsed = 1.0
	_request_pvp_room_poll()

func _refresh_staff_tools_visibility_if_needed() -> void:
	var next_key := _get_staff_tools_visibility_key()
	if next_key == staff_tools_visibility_key:
		return
	staff_tools_visibility_key = next_key
	_refresh_dev_tools_visibility()

func _get_staff_tools_visibility_key() -> String:
	return "%s|%s|%s" % [
		str(AuthService.session_token),
		str(AuthService.current_user.get("roles", [])),
		str(AuthService.current_user.get("permissions", [])),
	]

func _refresh_location_label_if_needed() -> void:
	var current_map: Node = GameState.current_map as Node
	if displayed_location_map == current_map:
		return
	_refresh_location_label()

func _refresh_location_label() -> void:
	displayed_location_map = GameState.current_map as Node
	if region_label != null:
		region_label.text = _get_current_map_region_name().to_upper()
	if location_label != null:
		location_label.text = _get_current_map_display_name()

func _get_current_map_region_name() -> String:
	var current_map: Node = GameState.current_map as Node
	if current_map == null:
		return "Unknown"
	if current_map.has_method("get_map_region_name"):
		var region_name: String = str(current_map.call("get_map_region_name")).strip_edges()
		if region_name != "":
			return region_name
	return "Unknown"

func _get_current_map_display_name() -> String:
	var current_map: Node = GameState.current_map as Node
	if current_map == null:
		return "Unknown Location"
	if current_map.has_method("get_map_display_name"):
		var display_name: String = str(current_map.call("get_map_display_name")).strip_edges()
		if display_name != "":
			return display_name
	return _format_map_name(str(current_map.name))

func _format_map_name(raw_name: String) -> String:
	var readable: String = raw_name.replace("_", " ").strip_edges()
	if readable == "":
		return "Unknown Location"
	return readable

func _refresh_utc_time_label(delta: float, force := false) -> void:
	utc_time_refresh_elapsed += delta
	if not force and utc_time_refresh_elapsed < UTC_TIME_REFRESH_INTERVAL_SECONDS:
		return
	utc_time_refresh_elapsed = 0.0
	if time_label == null:
		return

	var date_time: Dictionary = Time.get_datetime_dict_from_system(true)
	var hour: int = int(date_time.get("hour", 0))
	var minute: int = int(date_time.get("minute", 0))
	var period: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "%02d:%02d %s" % [display_hour, minute, period]

func _input(event: InputEvent) -> void:
	if party_dragging:
		_handle_party_drag_input(event)
		return

	if chat_resize_dragging:
		_handle_chat_resize_drag(event)
		return

	if trainer_card_dragging:
		_handle_trainer_card_drag_input(event)
		return

	if bag_dragging:
		_handle_bag_drag_input(event)
		return

	if pokemon_summary_dragging_card_key != "":
		_handle_pokemon_summary_drag_input(event)
		return

	if mail_dragging:
		_handle_mail_drag_input(event)
		return

	if item_dex_dragging:
		_handle_item_dex_drag_input(event)
		return

	if pokedex_dragging:
		_handle_pokedex_drag_input(event)
		return

	if hotkey_sidebar_dragging:
		_handle_hotkey_sidebar_drag_input(event)
		return

	if _is_settings_toggle_event(event):
		if _close_active_overlay_for_escape():
			get_viewport().set_input_as_handled()
			return

		if chat_input.has_focus():
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
			return

		_toggle_settings_menu()
		get_viewport().set_input_as_handled()
		return

	if not chat_input.has_focus():
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_point_inside_control(chat_input, mouse_event.position):
		return
	if _is_point_inside_control(send_button, mouse_event.position):
		return

	chat_input.release_focus()

func _handle_chat_resize_drag(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_position := root_control.get_local_mouse_position()
		var delta := mouse_position - chat_resize_drag_start_mouse
		var new_size := Vector2(
			clampf(chat_resize_drag_start_rect.size.x + delta.x, CHAT_MIN_SIZE.x, CHAT_MAX_SIZE.x),
			clampf(chat_resize_drag_start_rect.size.y - delta.y, CHAT_MIN_SIZE.y, CHAT_MAX_SIZE.y)
		)
		_set_chat_panel_size(new_size)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			chat_resize_dragging = false
			get_viewport().set_input_as_handled()

func _is_point_inside_control(control: Control, point: Vector2) -> bool:
	return control.get_global_rect().has_point(point)

func is_point_over_visible_ui(global_position: Vector2) -> bool:
	var panels: Array[Control] = [
		chat_panel,
		chat_tabs_panel,
		location_panel,
		options_panel,
		actions_panel,
		dex_actions_panel,
		staff_actions_panel,
		party_panel,
		player_status_panel,
		hotkey_sidebar_panel,
		bag_popup,
		trainer_card_popup,
		dev_actions_popup,
		dev_pokemon_popup,
		dev_clear_menu_popup,
		pvp_room_popup,
		dev_add_item_popup,
		dev_add_money_popup,
		dev_add_menu_popup,
		staff_tools_popup,
		staff_impersonate_popup,
		item_dex_popup,
		pokedex_popup,
		settings_menu,
		socials_menu,
		mail_popup,
		mail_compose_popup,
	]
	if chat_resize_button != null:
		panels.append(chat_resize_button)
	for state_value: Variant in collapsible_panels.values():
		var state: Dictionary = state_value as Dictionary
		var button: Control = state.get("button") as Control
		if button != null:
			panels.append(button)
	for context_value: Variant in pokemon_summary_open_cards.values():
		var context: Dictionary = context_value as Dictionary
		var summary_panel: Control = context.get("popup") as Control
		if summary_panel != null:
			panels.append(summary_panel)

	for panel: Control in panels:
		if panel != null and panel.visible and panel.get_global_rect().has_point(global_position):
			return true

	return false

func _on_hotkey_sidebar_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		hotkey_sidebar_dragging = true
		hotkey_sidebar_drag_offset = root_control.get_local_mouse_position() - hotkey_sidebar_panel.position
		get_viewport().set_input_as_handled()

func _handle_hotkey_sidebar_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var target_position := root_control.get_local_mouse_position() - hotkey_sidebar_drag_offset
		_set_hotkey_sidebar_position(target_position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			hotkey_sidebar_dragging = false
			_position_collapsible_button("hotkey_sidebar")
			get_viewport().set_input_as_handled()

func _set_hotkey_sidebar_position(position: Vector2) -> void:
	if hotkey_sidebar_panel == null:
		return

	var root_size := root_control.size
	var panel_size := hotkey_sidebar_panel.size
	var clamped_position := Vector2(
		clampf(position.x, 8.0, maxf(8.0, root_size.x - panel_size.x - 8.0)),
		clampf(position.y, 8.0, maxf(8.0, root_size.y - panel_size.y - 8.0))
	)
	hotkey_sidebar_panel.position = clamped_position
	_position_collapsible_button("hotkey_sidebar")

func _setup_player_status_card() -> void:
	player_status_panel.gui_input.connect(_on_player_status_panel_gui_input)
	player_status_panel.mouse_entered.connect(_on_player_status_panel_mouse_entered)
	player_status_panel.mouse_exited.connect(_on_player_status_panel_mouse_exited)
	_populate_avatar_preview(player_status_avatar_viewport, PLAYER_STATUS_AVATAR_POSITION, PLAYER_STATUS_AVATAR_SCALE)
	_refresh_player_status_card()

func _create_player_status_avatar_visual() -> Node2D:
	var source_player: Node2D = PLAYER_PREVIEW_SCENE.instantiate() as Node2D
	if source_player == null:
		return null

	var visual_root := Node2D.new()
	var source_look: Node2D = source_player.get_node_or_null("Look") as Node2D
	if source_look != null:
		var visual_look: Node2D = source_look.duplicate() as Node2D
		if visual_look != null:
			visual_look.position = Vector2.ZERO
			visual_root.add_child(visual_look)

	source_player.free()
	if visual_root.get_child_count() == 0:
		visual_root.free()
		return null

	_apply_avatar_preview_appearance(visual_root)
	return visual_root

func _populate_avatar_preview(viewport: SubViewport, preview_position: Vector2, preview_scale: Vector2) -> void:
	if viewport == null:
		return

	for child_node: Node in viewport.get_children():
		child_node.queue_free()

	var avatar_visual := _create_player_status_avatar_visual()
	if avatar_visual == null:
		return

	viewport.add_child(avatar_visual)
	avatar_visual.position = preview_position
	avatar_visual.scale = preview_scale
	_disable_avatar_preview_processing(avatar_visual)
	_set_avatar_preview_idle_frame(avatar_visual)

func _refresh_avatar_previews() -> void:
	_populate_avatar_preview(player_status_avatar_viewport, PLAYER_STATUS_AVATAR_POSITION, PLAYER_STATUS_AVATAR_SCALE)
	for viewport: SubViewport in trainer_card_avatar_viewports:
		var preview_position: Vector2 = viewport.get_meta("preview_position", TRAINER_CARD_AVATAR_POSITION) as Vector2
		var preview_scale: Vector2 = viewport.get_meta("preview_scale", TRAINER_CARD_AVATAR_SCALE) as Vector2
		_populate_avatar_preview(viewport, preview_position, preview_scale)

func _apply_avatar_preview_appearance(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(PlayerSave.appearance_body_id, PlayerSave.gender)
			if body_frames != null:
				sprite.sprite_frames = body_frames
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.modulate = _get_avatar_preview_body_modulate()
		else:
			_apply_avatar_preview_part(sprite)

	for child_node: Node in node.get_children():
		_apply_avatar_preview_appearance(child_node)

func _apply_avatar_preview_part(sprite: AnimatedSprite2D) -> void:
	var category_id: String = _get_appearance_category_for_sprite(sprite.name)
	if category_id == "":
		return
	if not CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	var part_id: String = _get_preview_part_id(category_id)
	if part_id == "":
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	var part_frames: SpriteFrames = _get_avatar_preview_part_frames(category_id, part_id)
	if part_frames == null:
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.material = null
		return

	sprite.sprite_frames = part_frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_avatar_preview_part_visuals(sprite, category_id)
	sprite.visible = true

func _get_appearance_category_for_sprite(sprite_name: String) -> String:
	match sprite_name:
		"HairSprite":
			return "hair"
		"HeadgearSprite":
			return "headgear"
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

func _get_preview_part_id(category_id: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category_id):
		"hair":
			return PlayerSave.appearance_hair_id
		"headgear":
			return PlayerSave.appearance_headgear_id
		"facegear":
			return PlayerSave.appearance_facegear_id
		"top":
			return PlayerSave.appearance_top_id
		"bottom":
			return PlayerSave.appearance_bottom_id
		"shoes":
			return PlayerSave.appearance_shoes_id
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", PlayerSave.gender)
		"eyebrows":
			return CharacterAppearanceService.get_default_part_id("eyebrows", PlayerSave.gender)
		_:
			return ""

func _get_avatar_preview_body_modulate() -> Color:
	if CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		return _parse_appearance_color(PlayerSave.appearance_skin_tone, Color.WHITE)
	return Color.WHITE

func _get_preview_part_modulate(category_id: String) -> Color:
	return Color.WHITE

func _apply_avatar_preview_part_visuals(sprite: AnimatedSprite2D, category_id: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	sprite.material = null
	sprite.modulate = _get_preview_part_modulate(normalized_category)

func _get_avatar_preview_part_frames(category_id: String, part_id: String) -> SpriteFrames:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_appearance_color(PlayerSave.appearance_eye_color, Color.WHITE)
		)
	if normalized_category == "hair" or normalized_category == "eyebrows":
		return CharacterAppearanceService.get_tinted_part_frames(
			category_id,
			part_id,
			PlayerSave.gender,
			CharacterAppearanceService.BODY_MOVEMENT_DEFAULT,
			_parse_appearance_color(PlayerSave.appearance_hair_color, Color.WHITE),
			true
		)
	return CharacterAppearanceService.get_part_frames(category_id, part_id, PlayerSave.gender)

func _parse_appearance_color(color_text: String, fallback: Color) -> Color:
	var normalized_color: String = color_text.strip_edges()
	if normalized_color == "" or not normalized_color.begins_with("#"):
		return fallback
	return Color(normalized_color)

func _disable_avatar_preview_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)

	for child_node: Node in node.get_children():
		_disable_avatar_preview_processing(child_node)

func _set_avatar_preview_idle_frame(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle_down"):
			sprite.animation = &"idle_down"
		sprite.frame = 0
		sprite.stop()

	for child_node: Node in node.get_children():
		_set_avatar_preview_idle_frame(child_node)

func _refresh_player_status_card_if_needed() -> void:
	if player_status_money_label == null:
		return

	var current_money: int = _get_player_money_value()
	if displayed_money != current_money:
		_refresh_player_status_card()

func _refresh_trainer_card_playtime_if_needed() -> void:
	if trainer_card_popup == null or not trainer_card_popup.visible or trainer_card_playtime_label == null:
		return
	trainer_card_playtime_label.text = _format_playtime(PlayerSave.playtime_seconds)

func _refresh_player_status_card() -> void:
	displayed_money = _get_player_money_value()
	if player_status_name_label != null:
		player_status_name_label.text = PlayerSave.player_name
	if trainer_card_name_label != null:
		trainer_card_name_label.text = PlayerSave.player_name
	if player_status_money_label != null:
		player_status_money_label.text = _format_money(displayed_money)
	if trainer_card_money_label != null:
		trainer_card_money_label.text = _format_money(displayed_money)
	if trainer_card_playtime_label != null:
		trainer_card_playtime_label.text = _format_playtime(PlayerSave.playtime_seconds)

func _setup_trainer_card_popup() -> void:
	trainer_card_popup = PanelContainer.new()
	trainer_card_popup.name = "TrainerCardPopup"
	trainer_card_popup.visible = false
	trainer_card_popup.custom_minimum_size = TRAINER_CARD_SIZE
	trainer_card_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	trainer_card_popup.z_index = UI_BASE_Z_INDEX
	trainer_card_popup.anchor_left = 0.5
	trainer_card_popup.anchor_top = 0.5
	trainer_card_popup.anchor_right = 0.5
	trainer_card_popup.anchor_bottom = 0.5
	trainer_card_popup.offset_left = -TRAINER_CARD_SIZE.x * 0.5
	trainer_card_popup.offset_top = -TRAINER_CARD_SIZE.y * 0.5
	trainer_card_popup.offset_right = TRAINER_CARD_SIZE.x * 0.5
	trainer_card_popup.offset_bottom = TRAINER_CARD_SIZE.y * 0.5
	trainer_card_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(trainer_card_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 14)
	trainer_card_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_trainer_card_header_gui_input)
	layout.add_child(header)

	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(90, 0)
	header.add_child(header_spacer)

	var title := Label.new()
	title.text = "Trainer Card"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UI_MONEY)
	title.add_theme_color_override("font_shadow_color", Color("#000000"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_trainer_card)
	_apply_button_style(close_button, "danger")
	header.add_child(close_button)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 14)
	tabs.add_child(_create_trainer_card_stats_tab())
	tabs.add_child(_create_trainer_card_appearance_tab())
	tabs.add_child(_create_trainer_card_badges_tab())
	layout.add_child(tabs)

func _create_trainer_card_avatar_panel(
	preview_position: Vector2 = TRAINER_CARD_AVATAR_POSITION,
	preview_scale: Vector2 = TRAINER_CARD_AVATAR_SCALE
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 198)
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_BG_STRONG, UI_BORDER_SOFT, 8, 1))

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 6)
	margin_container.add_child(layout)

	var viewport_frame := PanelContainer.new()
	viewport_frame.custom_minimum_size = Vector2(160, 160)
	viewport_frame.add_theme_stylebox_override("panel", _make_panel_style(Color("#03060cf2"), Color("#2ea7ff"), 80, 4))
	layout.add_child(viewport_frame)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(160, 160)
	viewport_container.stretch = false
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_frame.add_child(viewport_container)

	var trainer_card_avatar_viewport := SubViewport.new()
	trainer_card_avatar_viewport.transparent_bg = true
	trainer_card_avatar_viewport.size = TRAINER_CARD_AVATAR_VIEWPORT_SIZE
	trainer_card_avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	trainer_card_avatar_viewport.set_meta("preview_position", preview_position)
	trainer_card_avatar_viewport.set_meta("preview_scale", preview_scale)
	viewport_container.add_child(trainer_card_avatar_viewport)
	trainer_card_avatar_viewports.append(trainer_card_avatar_viewport)
	_populate_avatar_preview(trainer_card_avatar_viewport, preview_position, preview_scale)

	var name_label := Label.new()
	name_label.text = PlayerSave.player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	trainer_card_name_label = name_label
	layout.add_child(name_label)

	return panel

func _create_trainer_card_stats_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "Trainer"
	tab.add_theme_constant_override("margin_left", 8)
	tab.add_theme_constant_override("margin_top", 8)
	tab.add_theme_constant_override("margin_right", 8)
	tab.add_theme_constant_override("margin_bottom", 8)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	tab.add_child(layout)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	layout.add_child(top_row)

	top_row.add_child(_create_trainer_card_avatar_panel())
	top_row.add_child(_create_trainer_card_identity_panel())

	var stats_row := HBoxContainer.new()
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_row.add_theme_constant_override("separation", 12)
	layout.add_child(stats_row)

	var adventure_rows: Array[Dictionary] = [
		{"label": "Join Date", "value": _get_formatted_trainer_stat_text("join_date", "-")},
		{"label": "Playtime", "value": _format_playtime(PlayerSave.playtime_seconds)},
		{"label": "Pokemon Caught", "value": _get_trainer_stat_text("pokemon_caught", "0")},
		{"label": "Pokemon Seen", "value": _get_trainer_stat_text("pokemon_seen", "0")},
	]
	var battle_rows: Array[Dictionary] = [
		{"label": "Victories", "value": _get_trainer_stat_text("victories", "0")},
		{"label": "Defeats", "value": _get_trainer_stat_text("defeats", "0")},
		{"label": "Disconnects", "value": _get_trainer_stat_text("disconnects", "0")},
		{"label": "Money", "value": _format_money(_get_player_money_value()), "money": true},
	]
	stats_row.add_child(_create_trainer_card_stat_panel("Adventure Stats", adventure_rows))
	stats_row.add_child(_create_trainer_card_stat_panel("Battle Stats", battle_rows))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	return tab

func _create_trainer_card_identity_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 116)
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, Color("#4b5872"), 8, 2))

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin_container)

	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 4)
	margin_container.add_child(rows)

	rows.add_child(_create_trainer_card_stat_row("Name", PlayerSave.player_name, 104, 22, TRAINER_CARD_CYAN))
	rows.add_child(_create_trainer_card_stat_row("ID", _get_trainer_id_text(), 104, 22, TRAINER_CARD_CYAN))
	rows.add_child(_create_trainer_card_stat_row("Guild", _get_trainer_stat_text("guild", "-"), 104, 22, TRAINER_CARD_CYAN))
	return panel

func _create_trainer_card_stat_panel(title_text: String, rows: Array[Dictionary]) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, Color("#4b5872"), 8, 2))

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 14)
	margin_container.add_theme_constant_override("margin_top", 6)
	margin_container.add_theme_constant_override("margin_right", 14)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin_container.add_child(layout)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#1ea8ff"))
	title.add_theme_color_override("font_shadow_color", Color("#001427"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layout.add_child(title)

	var row_stack := VBoxContainer.new()
	row_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_stack.alignment = BoxContainer.ALIGNMENT_END
	row_stack.add_theme_constant_override("separation", 2)
	layout.add_child(row_stack)

	for row_value: Dictionary in rows:
		var label_text: String = str(row_value.get("label", ""))
		var value_text: String = str(row_value.get("value", ""))
		var value_color: Color = TRAINER_CARD_GREEN if bool(row_value.get("money", false)) else TRAINER_CARD_CYAN
		row_stack.add_child(_create_trainer_card_stat_row(label_text, value_text, 130, 15, value_color))

	return panel

func _create_trainer_card_stat_row(
	label_text: String,
	value_text: String,
	label_width: float = 82.0,
	font_size: int = 16,
	value_color: Color = TRAINER_CARD_CYAN
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UI_TEXT)
	label.add_theme_color_override("font_shadow_color", Color("#000000"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_color_override("font_shadow_color", Color("#000000"))
	value.add_theme_constant_override("shadow_offset_x", 1)
	value.add_theme_constant_override("shadow_offset_y", 1)
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	if label_text == "Money":
		trainer_card_money_label = value
	elif label_text == "Playtime":
		trainer_card_playtime_label = value

	return row

func _create_trainer_card_appearance_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "Appearance"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 12)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)

	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	tab.add_child(layout)

	layout.add_child(_create_trainer_card_avatar_panel(
		TRAINER_CARD_APPEARANCE_AVATAR_POSITION,
		TRAINER_CARD_APPEARANCE_AVATAR_SCALE
	))

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(92, 0)
	sidebar.add_theme_constant_override("separation", 6)
	layout.add_child(sidebar)

	var editor_stack := VBoxContainer.new()
	editor_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_stack.add_theme_constant_override("separation", 8)
	layout.add_child(editor_stack)

	var content_stack := VBoxContainer.new()
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_theme_constant_override("separation", 8)
	editor_stack.add_child(content_stack)

	for category_value: Variant in APPEARANCE_CATEGORIES:
		if not category_value is Dictionary:
			continue

		var category: Dictionary = category_value as Dictionary
		var category_id: String = str(category.get("id", ""))
		var category_label: String = str(category.get("label", category_id.capitalize()))
		var side_button := Button.new()
		side_button.text = category_label
		side_button.focus_mode = Control.FOCUS_NONE
		side_button.custom_minimum_size = Vector2(0, 28)
		side_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_button.toggle_mode = true
		side_button.button_pressed = category_id == "body"
		side_button.pressed.connect(_on_trainer_card_appearance_category_selected.bind(side_button, content_stack, category_id))
		sidebar.add_child(side_button)
		_apply_button_style(side_button, "primary" if category_id == "body" else "default")

	_create_trainer_card_body_appearance_content(content_stack)
	editor_stack.add_child(_create_trainer_card_appearance_save_row())
	_update_trainer_card_appearance_save_state()
	return tab

func _create_trainer_card_appearance_save_row() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	trainer_card_appearance_status_label = Label.new()
	trainer_card_appearance_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trainer_card_appearance_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trainer_card_appearance_status_label.add_theme_font_size_override("font_size", 13)
	trainer_card_appearance_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	row.add_child(trainer_card_appearance_status_label)

	trainer_card_appearance_save_button = Button.new()
	trainer_card_appearance_save_button.text = "Save"
	trainer_card_appearance_save_button.custom_minimum_size = Vector2(92, 30)
	trainer_card_appearance_save_button.focus_mode = Control.FOCUS_NONE
	trainer_card_appearance_save_button.pressed.connect(_on_trainer_card_appearance_save_pressed)
	_apply_button_style(trainer_card_appearance_save_button, "primary")
	row.add_child(trainer_card_appearance_save_button)
	return row

func _create_trainer_card_badges_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "Badges"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 10)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#0a0f19e8"), Color("#26344a"), 8, 1))
	tab.add_child(panel)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var badge_mark := Control.new()
	badge_mark.custom_minimum_size = Vector2(76, 76)
	badge_mark.draw.connect(_on_trainer_card_region_mark_draw.bind(badge_mark))
	header.add_child(badge_mark)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var region_select := OptionButton.new()
	region_select.custom_minimum_size = Vector2(132, 32)
	region_select.focus_mode = Control.FOCUS_NONE
	region_select.add_item("Kanto")
	region_select.selected = 0
	_apply_button_style(region_select, "default")
	header.add_child(region_select)

	var badge_grid_panel := PanelContainer.new()
	badge_grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge_grid_panel.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, Color("#303744"), 8, 2))
	layout.add_child(badge_grid_panel)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 18)
	grid_margin.add_theme_constant_override("margin_top", 12)
	grid_margin.add_theme_constant_override("margin_right", 18)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	badge_grid_panel.add_child(grid_margin)

	var badge_grid := GridContainer.new()
	badge_grid.columns = 4
	badge_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge_grid.add_theme_constant_override("h_separation", 18)
	badge_grid.add_theme_constant_override("v_separation", 10)
	grid_margin.add_child(badge_grid)

	for badge_value: Variant in KANTO_BADGES:
		if badge_value is Dictionary:
			badge_grid.add_child(_create_trainer_card_badge_slot(badge_value as Dictionary))

	return tab

func _create_trainer_card_badge_slot(badge: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(128, 96)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.tooltip_text = str(badge.get("name", "Badge"))
	slot.add_theme_stylebox_override("panel", _make_panel_style(Color("#07101dcc"), Color("#17263a"), 8, 1))

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(82, 82)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture_path: String = str(badge.get("texture", ""))
	if ResourceLoader.exists(texture_path):
		texture_rect.texture = load(texture_path) as Texture2D
	if not bool(badge.get("unlocked", false)):
		texture_rect.modulate = Color("#ffffffbf")
	center.add_child(texture_rect)
	return slot

func _on_trainer_card_region_mark_draw(mark: Control) -> void:
	var center := mark.size * 0.5
	var needle_color := Color("#f5f7ff")
	var shadow_color := Color("#00000099")
	var red_color := Color("#f0282f")
	var outline_color := Color("#05070b")

	mark.draw_circle(center + Vector2(-12, -10), 32, outline_color)
	mark.draw_arc(center + Vector2(-12, -10), 27, PI, TAU * 1.32, 20, red_color, 13.0, true)
	mark.draw_arc(center + Vector2(-12, -10), 27, 0.0, PI, 20, Color("#ffffff"), 13.0, true)
	mark.draw_circle(center + Vector2(-12, -10), 12, outline_color)
	mark.draw_circle(center + Vector2(-12, -10), 7, Color("#dfe6f3"))

	var shadow_points: PackedVector2Array = PackedVector2Array([
		center + Vector2(2, 1),
		center + Vector2(40, -30),
		center + Vector2(18, 44),
	])
	mark.draw_colored_polygon(shadow_points, shadow_color)
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-2, -3),
		center + Vector2(36, -34),
		center + Vector2(14, 40),
	])
	mark.draw_colored_polygon(points, needle_color)
	mark.draw_polyline(points, outline_color, 3.0, true)

func _on_trainer_card_badge_icon_draw(icon: Control, badge: Dictionary) -> void:
	var unlocked: bool = bool(badge.get("unlocked", false))
	var base_color: Color = badge.get("color", Color.WHITE) as Color
	var accent_color: Color = badge.get("accent", Color.GRAY) as Color
	var shape: String = str(badge.get("shape", "coin"))
	if not unlocked:
		base_color = base_color.darkened(0.28)
		accent_color = accent_color.darkened(0.35)

	match shape:
		"rock":
			_draw_trainer_badge_rock(icon, base_color, accent_color)
		"drop":
			_draw_trainer_badge_drop(icon, base_color, accent_color)
		"sun":
			_draw_trainer_badge_sun(icon, base_color, accent_color)
		"rainbow":
			_draw_trainer_badge_rainbow(icon)
		"heart":
			_draw_trainer_badge_heart(icon, base_color, accent_color)
		"flame":
			_draw_trainer_badge_flame(icon, base_color, accent_color)
		"leaf":
			_draw_trainer_badge_leaf(icon, base_color, accent_color)
		_:
			_draw_trainer_badge_coin(icon, base_color, accent_color)

func _draw_trainer_badge_rock(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(8):
		var angle := -PI * 0.5 + float(index) * TAU / 8.0
		var radius := 37.0 if index % 2 == 0 else 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	icon.draw_colored_polygon(points, base_color)
	icon.draw_polyline(points, Color("#1a1d22"), 4.0, true)
	icon.draw_line(center + Vector2(-24, -10), center + Vector2(24, -22), accent_color, 5.0)
	icon.draw_line(center + Vector2(-18, 22), center + Vector2(28, 6), accent_color, 5.0)

func _draw_trainer_badge_drop(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -40),
		center + Vector2(28, -4),
		center + Vector2(22, 30),
		center + Vector2(0, 40),
		center + Vector2(-22, 30),
		center + Vector2(-28, -4),
	])
	icon.draw_colored_polygon(points, base_color)
	icon.draw_polyline(points, accent_color, 5.0, true)
	icon.draw_circle(center + Vector2(12, -4), 9, Color("#ffffffcc"))
	icon.draw_circle(center + Vector2(4, 18), 4, Color("#ffffff55"))

func _draw_trainer_badge_sun(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	for index in range(10):
		var angle := float(index) * TAU / 10.0
		var point_a := center + Vector2(cos(angle - 0.16), sin(angle - 0.16)) * 24.0
		var point_b := center + Vector2(cos(angle), sin(angle)) * 42.0
		var point_c := center + Vector2(cos(angle + 0.16), sin(angle + 0.16)) * 24.0
		icon.draw_colored_polygon(PackedVector2Array([point_a, point_b, point_c]), base_color)
	icon.draw_circle(center, 29, base_color)
	icon.draw_circle(center, 19, accent_color)
	icon.draw_circle(center, 13, base_color.lightened(0.08))

func _draw_trainer_badge_rainbow(icon: Control) -> void:
	var center := icon.size * 0.5
	var colors: Array[Color] = [
		Color("#ff3333"), Color("#ff9a2c"), Color("#fff248"), Color("#62e84f"),
		Color("#36d7ff"), Color("#3559ff"), Color("#df4cff"), Color("#ffffff"),
	]
	for index in range(colors.size()):
		var angle := -PI * 0.5 + float(index) * TAU / float(colors.size())
		var point_a := center + Vector2(cos(angle - 0.28), sin(angle - 0.28)) * 16.0
		var point_b := center + Vector2(cos(angle), sin(angle)) * 39.0
		var point_c := center + Vector2(cos(angle + 0.28), sin(angle + 0.28)) * 16.0
		icon.draw_colored_polygon(PackedVector2Array([point_a, point_b, point_c]), colors[index])
	icon.draw_circle(center, 18, Color("#d9dde6"))
	icon.draw_circle(center, 8, Color("#6c7280"))

func _draw_trainer_badge_heart(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center + Vector2(-15, -8), 21, base_color)
	icon.draw_circle(center + Vector2(15, -8), 21, base_color)
	icon.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-34, 0),
		center + Vector2(34, 0),
		center + Vector2(0, 42),
	]), base_color)
	icon.draw_arc(center + Vector2(-15, -8), 21, PI * 0.86, TAU * 1.1, 24, accent_color, 4.0, true)
	icon.draw_circle(center + Vector2(14, -17), 8, Color("#ffffff99"))

func _draw_trainer_badge_coin(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center, 39, accent_color)
	icon.draw_circle(center, 32, base_color)
	icon.draw_circle(center, 20, Color("#ffbf32"))
	icon.draw_arc(center, 21, 0.0, TAU, 48, Color("#9b5b10"), 3.0, true)

func _draw_trainer_badge_flame(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -42),
		center + Vector2(22, -14),
		center + Vector2(30, 20),
		center + Vector2(0, 42),
		center + Vector2(-30, 20),
		center + Vector2(-22, -14),
	])
	icon.draw_colored_polygon(points, base_color)
	icon.draw_polyline(points, accent_color, 5.0, true)
	icon.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -18),
		center + Vector2(14, 12),
		center + Vector2(0, 28),
		center + Vector2(-14, 12),
	]), Color("#ffd0d9aa"))

func _draw_trainer_badge_leaf(icon: Control, base_color: Color, accent_color: Color) -> void:
	var center := icon.size * 0.5
	icon.draw_circle(center + Vector2(-12, -10), 18, base_color)
	icon.draw_circle(center + Vector2(10, 4), 26, base_color)
	icon.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-36, 26),
		center + Vector2(38, -28),
		center + Vector2(22, 32),
	]), base_color)
	icon.draw_line(center + Vector2(-26, 24), center + Vector2(36, -26), accent_color, 5.0)
	icon.draw_line(center + Vector2(4, 12), center + Vector2(26, 16), accent_color, 4.0)

func _on_trainer_card_appearance_category_selected(button: Button, content_stack: VBoxContainer, category_id: String) -> void:
	var sidebar: Node = button.get_parent()
	if sidebar != null:
		for child: Node in sidebar.get_children():
			if not child is Button:
				continue
			var side_button: Button = child as Button
			var selected: bool = side_button == button
			side_button.button_pressed = selected
			_apply_button_style(side_button, "primary" if selected else "default")

	_clear_container_children(content_stack)
	trainer_card_part_buttons.clear()
	trainer_card_color_buttons.clear()
	if category_id == "body":
		_create_trainer_card_body_appearance_content(content_stack)
	else:
		_create_trainer_card_part_appearance_content(content_stack, category_id)

func _create_trainer_card_body_appearance_content(content_stack: VBoxContainer) -> void:
	var body_label := Label.new()
	body_label.text = "Body"
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", UI_TEXT)
	content_stack.add_child(body_label)

	var search_input := _create_trainer_card_appearance_search_input("Search bodies")
	search_input.text_changed.connect(_filter_trainer_card_body_buttons)
	content_stack.add_child(search_input)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	trainer_card_body_buttons.clear()
	for body_id: String in _get_body_appearance_ids():
		var body_button := Button.new()
		body_button.text = _format_appearance_option_name("body", body_id)
		body_button.focus_mode = Control.FOCUS_NONE
		body_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_button.pressed.connect(_on_trainer_card_body_selected.bind(body_id))
		grid.add_child(body_button)
		trainer_card_body_buttons[body_id] = body_button

	_refresh_trainer_card_body_buttons()
	_create_trainer_card_color_palette(content_stack, "Eye Color", "eye_color", EYE_COLOR_SWATCHES)

func _create_trainer_card_part_appearance_content(content_stack: VBoxContainer, category_id: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	var title := Label.new()
	title.text = _format_appearance_category_name(normalized_category)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UI_TEXT)
	content_stack.add_child(title)

	var search_input := _create_trainer_card_appearance_search_input("Search %s" % _format_appearance_category_name(normalized_category).to_lower())
	search_input.text_changed.connect(_filter_trainer_card_part_buttons)
	content_stack.add_child(search_input)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var none_button := Button.new()
	none_button.text = "None"
	none_button.focus_mode = Control.FOCUS_NONE
	none_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	none_button.pressed.connect(_on_trainer_card_part_selected.bind(normalized_category, ""))
	grid.add_child(none_button)
	trainer_card_part_buttons["%s:" % normalized_category] = none_button

	for part_id: String in CharacterAppearanceService.get_available_part_ids(normalized_category, PlayerSave.gender):
		var part_button := Button.new()
		part_button.text = _format_appearance_option_name(normalized_category, part_id)
		part_button.focus_mode = Control.FOCUS_NONE
		part_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		part_button.pressed.connect(_on_trainer_card_part_selected.bind(normalized_category, part_id))
		grid.add_child(part_button)
		trainer_card_part_buttons["%s:%s" % [normalized_category, part_id]] = part_button

	_refresh_trainer_card_part_buttons()
	if normalized_category == "hair":
		_create_trainer_card_color_palette(content_stack, "Hair Color", "hair_color", HAIR_COLOR_SWATCHES)

func _create_trainer_card_color_palette(
	content_stack: VBoxContainer,
	title_text: String,
	color_key: String,
	swatches: Array
) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI_TEXT)
	content_stack.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content_stack.add_child(grid)

	for swatch_value: Variant in swatches:
		if not swatch_value is Dictionary:
			continue
		var swatch: Dictionary = swatch_value as Dictionary
		var color_id: String = str(swatch.get("id", ""))
		var swatch_color: Color = swatch.get("color", Color.WHITE) as Color
		var button := Button.new()
		button.text = ""
		button.tooltip_text = str(swatch.get("label", color_id))
		button.custom_minimum_size = Vector2(30, 24)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_trainer_card_color_selected.bind(color_key, color_id))
		grid.add_child(button)
		trainer_card_color_buttons["%s:%s" % [color_key, color_id]] = {
			"button": button,
			"color": swatch_color,
		}
		_apply_color_swatch_button_style(button, swatch_color, _get_player_save_color_value(color_key) == color_id)

func _create_trainer_card_appearance_search_input(placeholder: String) -> LineEdit:
	var search_input := LineEdit.new()
	search_input.placeholder_text = placeholder
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_line_edit_style(search_input)
	return search_input

func _clear_container_children(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _get_body_appearance_ids() -> Array[String]:
	var ids: Array[String] = CharacterAppearanceService.get_available_body_ids(PlayerSave.gender)
	if ids.is_empty():
		ids.append(CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID if PlayerSave.gender == "female" else CharacterAppearanceService.DEFAULT_MALE_BODY_ID)
	return ids

func _get_trainer_id_text() -> String:
	var player_id_text: String = str(PlayerSave.player_id).strip_edges()
	if player_id_text == "":
		return "-"
	return player_id_text

func _get_trainer_stat_text(stat_key: String, fallback: String) -> String:
	if PlayerSave.flags.has("trainer_stats"):
		var stats_value: Variant = PlayerSave.flags.get("trainer_stats")
		if stats_value is Dictionary:
			var stats: Dictionary = stats_value as Dictionary
			if stats.has(stat_key):
				return str(stats.get(stat_key, fallback))

	if PlayerSave.flags.has(stat_key):
		return str(PlayerSave.flags.get(stat_key, fallback))

	return fallback

func _get_formatted_trainer_stat_text(stat_key: String, fallback: String) -> String:
	var stat_text: String = _get_trainer_stat_text(stat_key, fallback)
	if stat_key == "join_date":
		return _format_join_date_text(stat_text, fallback)
	return stat_text

func _format_join_date_text(raw_text: String, fallback: String) -> String:
	var date_text: String = raw_text.strip_edges()
	if date_text == "" or date_text == fallback:
		return fallback

	var date_part: String = date_text
	var date_time_separator_index: int = date_text.find("T")
	if date_time_separator_index >= 0:
		date_part = date_text.substr(0, date_time_separator_index)
	else:
		var space_separator_index: int = date_text.find(" ")
		if space_separator_index >= 0:
			date_part = date_text.substr(0, space_separator_index)

	date_part = date_part.strip_edges()
	var date_parts: PackedStringArray = date_part.split("-", false, 0)
	if date_parts.size() >= 3:
		var year: String = date_parts[0].strip_edges()
		var month: String = date_parts[1].strip_edges()
		var day: String = date_parts[2].strip_edges()
		if year.length() == 4 and year.is_valid_int() and month.is_valid_int() and day.is_valid_int():
			return "%02d-%02d-%04d" % [int(day), int(month), int(year)]

	return date_part if date_part != "" else fallback

func _format_appearance_category_name(category_id: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category_id):
		"body":
			return "Body"
		"hair":
			return "Hair"
		"headgear":
			return "Headgear"
		"facegear":
			return "Facegear"
		"top":
			return "Top"
		"bottom":
			return "Bottom"
		"shoes":
			return "Shoes"
		_:
			return _humanize_appearance_id(category_id)

func _format_appearance_option_name(category_id: String, part_id: String) -> String:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	var normalized_part_id: String = part_id.strip_edges()
	if normalized_category == "body":
		match normalized_part_id:
			"Gen4_Base_v1", "Gen4_Base_F_v1":
				return "Default"
			"Gen4_Base_M_Tan", "Gen4_Base_F_Tan":
				return "Tan"
			"Gen4_Base_M_Dark", "Gen4_Base_F_Dark":
				return "Dark"
	if normalized_category != "body":
		match normalized_part_id:
			"Hair":
				return "Starter Hair"
			"Cap":
				return "Starter Cap"
			"Shirt":
				return "Starter Shirt"
			"Trousers":
				return "Starter Trousers"
			"Shoes":
				return "Starter Shoes"
			"Eyes":
				return "Starter Eyes"
			"Eyebrows":
				return "Starter Eyebrows"
	return _humanize_appearance_id(normalized_part_id)

func _humanize_appearance_id(raw_id: String) -> String:
	var text := raw_id.replace("/", " ").replace("_", " ").replace("-", " ").strip_edges()
	if text == "":
		return raw_id
	return text.capitalize()

func _matches_appearance_search(label_text: String, raw_id: String, search_text: String) -> bool:
	var normalized_search: String = search_text.strip_edges().to_lower()
	if normalized_search == "":
		return true
	return label_text.to_lower().contains(normalized_search) or raw_id.to_lower().contains(normalized_search)

func _filter_trainer_card_body_buttons(search_text: String) -> void:
	for body_id_value: Variant in trainer_card_body_buttons.keys():
		var body_id: String = str(body_id_value)
		var button: Button = trainer_card_body_buttons.get(body_id) as Button
		if button == null:
			continue
		button.visible = _matches_appearance_search(_format_appearance_option_name("body", body_id), body_id, search_text)

func _filter_trainer_card_part_buttons(search_text: String) -> void:
	for key_value: Variant in trainer_card_part_buttons.keys():
		var key: String = str(key_value)
		var button: Button = trainer_card_part_buttons.get(key) as Button
		if button == null:
			continue
		var separator_index: int = key.find(":")
		if separator_index < 0:
			continue
		var category_id: String = key.substr(0, separator_index)
		var part_id: String = key.substr(separator_index + 1)
		var label_text: String = "None" if part_id == "" else _format_appearance_option_name(category_id, part_id)
		button.visible = _matches_appearance_search(label_text, part_id, search_text)

func _refresh_trainer_card_body_buttons() -> void:
	for body_id_value: Variant in trainer_card_body_buttons.keys():
		var body_id: String = str(body_id_value)
		var button_value: Variant = trainer_card_body_buttons.get(body_id)
		if not is_instance_valid(button_value):
			trainer_card_body_buttons.erase(body_id)
			continue
		var button: Button = button_value as Button
		if button == null:
			trainer_card_body_buttons.erase(body_id)
			continue

		var display_name: String = _format_appearance_option_name("body", body_id)
		var is_selected: bool = body_id == String(PlayerSave.appearance_body_id)
		if is_selected:
			button.text = "%s  *" % display_name
			_apply_button_style(button, "primary")
		else:
			button.text = display_name
			_apply_button_style(button)

func _refresh_trainer_card_part_buttons() -> void:
	for key_value: Variant in trainer_card_part_buttons.keys():
		var key: String = str(key_value)
		var button_value: Variant = trainer_card_part_buttons.get(key)
		if not is_instance_valid(button_value):
			trainer_card_part_buttons.erase(key)
			continue
		var button: Button = button_value as Button
		if button == null:
			trainer_card_part_buttons.erase(key)
			continue
		var separator_index: int = key.find(":")
		if separator_index < 0:
			continue
		var category_id: String = key.substr(0, separator_index)
		var part_id: String = key.substr(separator_index + 1)
		var selected_part_id: String = _get_preview_part_id(category_id)
		var display_name: String = "None" if part_id == "" else _format_appearance_option_name(category_id, part_id)
		if part_id == selected_part_id:
			button.text = "%s  *" % display_name
			_apply_button_style(button, "primary")
		else:
			button.text = display_name
			_apply_button_style(button)

func _apply_color_swatch_button_style(button: Button, color: Color, selected: bool) -> void:
	var border_color := Color("#f4d78a") if selected else Color("#4b5872")
	var border_width := 3 if selected else 1
	button.add_theme_stylebox_override("normal", _make_panel_style(color, border_color, 5, border_width))
	button.add_theme_stylebox_override("hover", _make_panel_style(color.lightened(0.12), Color("#62d7ff"), 5, 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(color.darkened(0.12), Color("#f4d78a"), 5, 2))
	button.add_theme_stylebox_override("focus", _make_panel_style(color, border_color, 5, border_width))

func _get_player_save_color_value(color_key: String) -> String:
	match color_key:
		"hair_color":
			return PlayerSave.appearance_hair_color
		"eye_color":
			return PlayerSave.appearance_eye_color
		_:
			return ""

func _refresh_trainer_card_color_buttons() -> void:
	for key_value: Variant in trainer_card_color_buttons.keys():
		var key: String = str(key_value)
		var entry_value: Variant = trainer_card_color_buttons.get(key)
		if not entry_value is Dictionary:
			trainer_card_color_buttons.erase(key)
			continue
		var entry: Dictionary = entry_value as Dictionary
		var button_value: Variant = entry.get("button")
		if not is_instance_valid(button_value):
			trainer_card_color_buttons.erase(key)
			continue
		var button: Button = button_value as Button
		if button == null:
			trainer_card_color_buttons.erase(key)
			continue
		var separator_index: int = key.find(":")
		if separator_index < 0:
			continue
		var color_key: String = key.substr(0, separator_index)
		var color_value: String = key.substr(separator_index + 1)
		var swatch_color: Color = entry.get("color", Color.WHITE) as Color
		_apply_color_swatch_button_style(button, swatch_color, _get_player_save_color_value(color_key) == color_value)

func _on_player_status_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_show_trainer_card()
	get_viewport().set_input_as_handled()

func _on_player_status_panel_mouse_entered() -> void:
	_apply_player_status_panel_hover_style(true)

func _on_player_status_panel_mouse_exited() -> void:
	_apply_player_status_panel_hover_style(false)

func _apply_player_status_panel_hover_style(hovered: bool) -> void:
	if player_status_panel == null:
		return

	var background_color := Color("#0b121fee") if hovered else PLAYER_STATUS_CARD_BACKGROUND
	var border_color := UI_BORDER if hovered else PLAYER_STATUS_CARD_BORDER
	var style := _make_panel_style(background_color, border_color, 14, 1)
	if hovered:
		style.shadow_color = Color(UI_BORDER.r, UI_BORDER.g, UI_BORDER.b, 0.18)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	player_status_panel.add_theme_stylebox_override("panel", style)

func _on_trainer_card_header_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		trainer_card_dragging = true
		trainer_card_drag_offset = mouse_event.global_position - trainer_card_popup.global_position
		_activate_ui_panel(trainer_card_popup)
		get_viewport().set_input_as_handled()

func _handle_trainer_card_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			trainer_card_dragging = false
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_trainer_card_to_global_position(motion_event.global_position - trainer_card_drag_offset)
	get_viewport().set_input_as_handled()

func _move_trainer_card_to_global_position(global_top_left: Vector2) -> void:
	if trainer_card_popup == null:
		return

	var parent_control: Control = trainer_card_popup.get_parent_control()
	if parent_control == null:
		return

	var card_size: Vector2 = trainer_card_popup.size
	var parent_size: Vector2 = parent_control.size
	var clamped_position := Vector2(
		clamp(global_top_left.x, 0.0, max(parent_size.x - card_size.x, 0.0)),
		clamp(global_top_left.y, 0.0, max(parent_size.y - card_size.y, 0.0))
	)
	var anchor_point := Vector2(
		parent_size.x * trainer_card_popup.anchor_left,
		parent_size.y * trainer_card_popup.anchor_top
	)
	var local_offset: Vector2 = clamped_position - anchor_point
	trainer_card_popup.offset_left = local_offset.x
	trainer_card_popup.offset_top = local_offset.y
	trainer_card_popup.offset_right = local_offset.x + card_size.x
	trainer_card_popup.offset_bottom = local_offset.y + card_size.y

func _show_trainer_card() -> void:
	if trainer_card_popup == null:
		return

	_refresh_trainer_card_body_buttons()
	_refresh_avatar_previews()
	_refresh_player_status_card()
	_update_trainer_card_appearance_save_state()
	trainer_card_popup.visible = true
	_activate_ui_panel(trainer_card_popup)

func _mark_trainer_card_appearance_dirty() -> void:
	trainer_card_has_unsaved_appearance_changes = true
	_update_trainer_card_appearance_save_state()
	var world := GameState.get_world()
	if world != null and world.has_method("_publish_world_presence"):
		world.call("_publish_world_presence", true)

func _update_trainer_card_appearance_save_state(message: String = "") -> void:
	if trainer_card_appearance_save_button != null:
		trainer_card_appearance_save_button.disabled = trainer_card_is_saving_appearance or not trainer_card_has_unsaved_appearance_changes
		if trainer_card_is_saving_appearance:
			trainer_card_appearance_save_button.text = "Saving..."
		elif trainer_card_has_unsaved_appearance_changes:
			trainer_card_appearance_save_button.text = "Save"
		else:
			trainer_card_appearance_save_button.text = "Saved"
		_apply_button_style(trainer_card_appearance_save_button, "primary" if trainer_card_has_unsaved_appearance_changes else "default")

	if trainer_card_appearance_status_label == null:
		return
	if message != "":
		trainer_card_appearance_status_label.text = message
	elif trainer_card_is_saving_appearance:
		trainer_card_appearance_status_label.text = "Saving appearance..."
	elif trainer_card_has_unsaved_appearance_changes:
		trainer_card_appearance_status_label.text = "Unsaved appearance changes"
	else:
		trainer_card_appearance_status_label.text = "Appearance saved"

	var status_color := UI_MUTED_TEXT
	if trainer_card_is_saving_appearance:
		status_color = UI_BORDER_FOCUS
	elif trainer_card_has_unsaved_appearance_changes:
		status_color = UI_MONEY
	trainer_card_appearance_status_label.add_theme_color_override("font_color", status_color)

func _on_trainer_card_appearance_save_pressed() -> void:
	if trainer_card_is_saving_appearance:
		return

	trainer_card_is_saving_appearance = true
	_update_trainer_card_appearance_save_state()
	var result: Dictionary = await _save_trainer_card_appearance_to_backend()
	trainer_card_is_saving_appearance = false

	if not bool(result.get("success", false)):
		trainer_card_has_unsaved_appearance_changes = true
		_update_trainer_card_appearance_save_state("Save failed: %s" % str(result.get("error", "Unknown error")))
		return

	if not _save_response_matches_current_appearance(result):
		trainer_card_has_unsaved_appearance_changes = true
		_update_trainer_card_appearance_save_state("Save failed: server did not persist all appearance parts")
		return

	trainer_card_has_unsaved_appearance_changes = false
	_update_trainer_card_appearance_save_state("Appearance saved")

func _save_trainer_card_appearance_to_backend() -> Dictionary:
	var world := GameState.get_world()
	if world == null or not world.has_method("save_current_player_state_now"):
		return {
			"success": false,
			"error": "World is not ready.",
		}

	var result_value: Variant = await world.call("save_current_player_state_now")
	if result_value is Dictionary:
		return result_value as Dictionary
	return {
		"success": false,
		"error": "Invalid save response.",
	}

func _save_response_matches_current_appearance(result: Dictionary) -> bool:
	var state: Dictionary = _staff_dictionary_from_variant(result.get("state", {}))
	var appearance: Dictionary = _staff_dictionary_from_variant(state.get("appearance", {}))
	if appearance.is_empty():
		return false

	var current_appearance: Dictionary = PlayerSave.to_appearance_state()
	var keys: Array[String] = [
		"body",
		"hair",
		"headgear",
		"facegear",
		"top",
		"bottom",
		"shoes",
		"hair_color",
		"skin_tone",
		"eye_color",
	]
	for key: String in keys:
		if str(appearance.get(key, "")).strip_edges() != str(current_appearance.get(key, "")).strip_edges():
			return false

	return int(appearance.get("hair_style_index", 0)) == int(current_appearance.get("hair_style_index", 0))

func _hide_trainer_card() -> void:
	if trainer_card_popup != null:
		trainer_card_popup.visible = false

func _on_trainer_card_body_selected(body_id: String) -> void:
	var was_layered_body: bool = CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_body_appearance"):
		player.call("set_body_appearance", body_id)
	else:
		PlayerSave.appearance_body_id = body_id
		PlayerSave.ensure_layered_appearance_defaults(not was_layered_body)

	_refresh_trainer_card_body_buttons()
	_refresh_trainer_card_part_buttons()
	_refresh_avatar_previews()
	_mark_trainer_card_appearance_dirty()

func _on_trainer_card_part_selected(category_id: String, part_id: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category_id)
	_ensure_layered_body_for_part_selection()
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_appearance_part"):
		player.call("set_appearance_part", normalized_category, part_id)
	else:
		_apply_player_save_appearance_part(normalized_category, part_id)

	_refresh_trainer_card_part_buttons()
	_refresh_avatar_previews()
	_mark_trainer_card_appearance_dirty()

func _on_trainer_card_color_selected(color_key: String, color_value: String) -> void:
	_ensure_layered_body_for_part_selection()
	match color_key:
		"hair_color":
			PlayerSave.appearance_hair_color = color_value
		"eye_color":
			PlayerSave.appearance_eye_color = color_value
		_:
			return

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("refresh_appearance"):
		player.call("refresh_appearance")

	_refresh_trainer_card_color_buttons()
	_refresh_avatar_previews()
	_mark_trainer_card_appearance_dirty()

func _ensure_layered_body_for_part_selection() -> void:
	if CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		return
	PlayerSave.appearance_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID if PlayerSave.gender == "female" else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	PlayerSave.ensure_layered_appearance_defaults()

func _apply_player_save_appearance_part(category_id: String, part_id: String) -> void:
	var normalized_part_id: String = part_id.strip_edges()
	match CharacterAppearanceService.normalize_part_category(category_id):
		"hair":
			PlayerSave.appearance_hair_id = normalized_part_id
			PlayerSave.sync_hair_style_index_from_id()
		"headgear":
			PlayerSave.appearance_headgear_id = normalized_part_id
		"facegear":
			PlayerSave.appearance_facegear_id = normalized_part_id
		"top":
			PlayerSave.appearance_top_id = normalized_part_id
		"bottom":
			PlayerSave.appearance_bottom_id = normalized_part_id
		"shoes":
			PlayerSave.appearance_shoes_id = normalized_part_id

func _get_player_money_value() -> int:
	return max(int(PlayerSave.money), 0)

func _setup_pokemon_summary_popup(card_key: String = "") -> void:
	pokemon_summary_tab_buttons = {}
	pokemon_summary_popup = PanelContainer.new()
	pokemon_summary_popup.name = "PokemonSummaryPopup"
	pokemon_summary_popup.visible = false
	pokemon_summary_popup.custom_minimum_size = POKEMON_SUMMARY_SIZE
	pokemon_summary_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	pokemon_summary_popup.z_index = UI_BASE_Z_INDEX
	pokemon_summary_popup.anchor_left = 0.5
	pokemon_summary_popup.anchor_top = 0.5
	pokemon_summary_popup.anchor_right = 0.5
	pokemon_summary_popup.anchor_bottom = 0.5
	pokemon_summary_popup.offset_left = -POKEMON_SUMMARY_SIZE.x * 0.5
	pokemon_summary_popup.offset_top = -POKEMON_SUMMARY_SIZE.y * 0.5
	pokemon_summary_popup.offset_right = POKEMON_SUMMARY_SIZE.x * 0.5
	pokemon_summary_popup.offset_bottom = POKEMON_SUMMARY_SIZE.y * 0.5
	pokemon_summary_popup.size = POKEMON_SUMMARY_SIZE
	pokemon_summary_popup.add_theme_stylebox_override("panel", _make_pokemon_summary_outer_style())
	pokemon_summary_popup.modulate = Color(1, 1, 1, 0.98)
	pokemon_summary_popup.gui_input.connect(_on_pokemon_summary_card_gui_input.bind(card_key))
	root_control.add_child(pokemon_summary_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 9)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 9)
	margin_container.add_theme_constant_override("margin_bottom", 9)
	pokemon_summary_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin_container.add_child(layout)

	_add_pokemon_summary_owner_bar(layout, card_key)

	var content_row := HBoxContainer.new()
	content_row.custom_minimum_size = Vector2(0, POKEMON_SUMMARY_BODY_HEIGHT)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 7)
	layout.add_child(content_row)

	_add_pokemon_summary_left_panel(content_row, card_key)
	_add_pokemon_summary_right_area(content_row, card_key)

func _add_pokemon_summary_left_panel(content_row: HBoxContainer, card_key: String) -> void:
	var left_panel := PanelContainer.new()
	pokemon_summary_left_panel = left_panel
	left_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#050911f8"), POKEMON_SUMMARY_ACCENT_SOFT))
	content_row.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 6)
	left_margin.add_theme_constant_override("margin_top", 6)
	left_margin.add_theme_constant_override("margin_right", 6)
	left_margin.add_theme_constant_override("margin_bottom", 6)
	left_panel.add_child(left_margin)

	var left_stack := VBoxContainer.new()
	left_stack.add_theme_constant_override("separation", 6)
	left_margin.add_child(left_stack)

	var sprite_frame := Control.new()
	sprite_frame.custom_minimum_size = Vector2(
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.x),
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.y)
	)
	sprite_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	sprite_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sprite_frame.tooltip_text = "Toggle front/back sprite"
	sprite_frame.gui_input.connect(_on_pokemon_summary_sprite_frame_gui_input.bind(card_key))
	left_stack.add_child(sprite_frame)

	var sprite_stage_background := TextureRect.new()
	sprite_stage_background.texture = BATTLE_SUMMARY_SLOT_BG_TEXTURE
	sprite_stage_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_stage_background.stretch_mode = TextureRect.STRETCH_SCALE
	sprite_stage_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_frame.add_child(sprite_stage_background)
	sprite_stage_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sprite_backdrop := PanelContainer.new()
	sprite_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_backdrop.add_theme_stylebox_override("panel", _make_pokemon_summary_sprite_stage_style())
	sprite_frame.add_child(sprite_backdrop)
	sprite_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sprite_viewport_container := SubViewportContainer.new()
	sprite_viewport_container.stretch = true
	sprite_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_frame.add_child(sprite_viewport_container)
	sprite_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	pokemon_summary_sprite_viewport = SubViewport.new()
	pokemon_summary_sprite_viewport.size = POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE
	pokemon_summary_sprite_viewport.transparent_bg = true
	pokemon_summary_sprite_viewport.disable_3d = true
	pokemon_summary_sprite_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sprite_viewport_container.add_child(pokemon_summary_sprite_viewport)

	pokemon_summary_animated_sprite = AnimatedSprite2D.new()
	pokemon_summary_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pokemon_summary_animated_sprite.position = Vector2(
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.x) * 0.5,
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.y) * 0.52
	)
	pokemon_summary_sprite_viewport.add_child(pokemon_summary_animated_sprite)

	pokemon_summary_sprite = TextureRect.new()
	pokemon_summary_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_summary_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokemon_summary_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_frame.add_child(pokemon_summary_sprite)
	pokemon_summary_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ball_button_panel := PanelContainer.new()
	ball_button_panel.custom_minimum_size = Vector2(30, 30)
	ball_button_panel.anchor_left = 0.0
	ball_button_panel.anchor_top = 0.0
	ball_button_panel.anchor_right = 0.0
	ball_button_panel.anchor_bottom = 0.0
	ball_button_panel.offset_left = 6.0
	ball_button_panel.offset_top = 6.0
	ball_button_panel.offset_right = 36.0
	ball_button_panel.offset_bottom = 36.0
	ball_button_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_button_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#06111fe8"), POKEMON_SUMMARY_ACCENT_SOFT, 8, 1))
	sprite_frame.add_child(ball_button_panel)

	var ball_icon_center := CenterContainer.new()
	ball_icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_button_panel.add_child(ball_icon_center)

	pokemon_summary_ball_icon = TextureRect.new()
	pokemon_summary_ball_icon.custom_minimum_size = Vector2(22, 22)
	pokemon_summary_ball_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_summary_ball_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokemon_summary_ball_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_icon_center.add_child(pokemon_summary_ball_icon)

	pokemon_summary_ball_button = Button.new()
	pokemon_summary_ball_button.text = ""
	pokemon_summary_ball_button.pressed.connect(_on_pokemon_summary_ball_button_pressed.bind(card_key))
	pokemon_summary_ball_button.tooltip_text = "Change Poké Ball."
	pokemon_summary_ball_button.focus_mode = Control.FOCUS_NONE
	pokemon_summary_ball_button.flat = true
	pokemon_summary_ball_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pokemon_summary_ball_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pokemon_summary_ball_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pokemon_summary_ball_button.add_theme_stylebox_override("normal", _make_pokemon_summary_held_item_button_style(Color("#00000000"), Color("#00000000")))
	pokemon_summary_ball_button.add_theme_stylebox_override("hover", _make_pokemon_summary_held_item_button_style(Color("#62d7ff14"), POKEMON_SUMMARY_ACCENT_SOFT))
	pokemon_summary_ball_button.add_theme_stylebox_override("pressed", _make_pokemon_summary_held_item_button_style(Color("#62d7ff18"), Color("#62d7ffaa")))
	ball_button_panel.add_child(pokemon_summary_ball_button)

	pokemon_summary_type_icon_row = HBoxContainer.new()
	pokemon_summary_type_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_type_icon_row.alignment = BoxContainer.ALIGNMENT_END
	pokemon_summary_type_icon_row.add_theme_constant_override("separation", 5)
	pokemon_summary_type_icon_row.anchor_left = 1.0
	pokemon_summary_type_icon_row.anchor_top = 0.0
	pokemon_summary_type_icon_row.anchor_right = 1.0
	pokemon_summary_type_icon_row.anchor_bottom = 0.0
	pokemon_summary_type_icon_row.offset_left = -168.0
	pokemon_summary_type_icon_row.offset_top = 6.0
	pokemon_summary_type_icon_row.offset_right = -6.0
	pokemon_summary_type_icon_row.offset_bottom = 28.0
	sprite_frame.add_child(pokemon_summary_type_icon_row)

	pokemon_summary_level_badge_panel = PanelContainer.new()
	pokemon_summary_level_badge_panel.custom_minimum_size = Vector2(54, 24)
	pokemon_summary_level_badge_panel.anchor_left = 1.0
	pokemon_summary_level_badge_panel.anchor_top = 1.0
	pokemon_summary_level_badge_panel.anchor_right = 1.0
	pokemon_summary_level_badge_panel.anchor_bottom = 1.0
	pokemon_summary_level_badge_panel.offset_left = -62.0
	pokemon_summary_level_badge_panel.offset_top = -30.0
	pokemon_summary_level_badge_panel.offset_right = -6.0
	pokemon_summary_level_badge_panel.offset_bottom = -6.0
	pokemon_summary_level_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_level_badge_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#06111fe8"), Color("#f4d78aaa"), 6, 1))
	sprite_frame.add_child(pokemon_summary_level_badge_panel)

	var level_badge_margin := MarginContainer.new()
	level_badge_margin.add_theme_constant_override("margin_left", 6)
	level_badge_margin.add_theme_constant_override("margin_top", 2)
	level_badge_margin.add_theme_constant_override("margin_right", 6)
	level_badge_margin.add_theme_constant_override("margin_bottom", 2)
	level_badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_level_badge_panel.add_child(level_badge_margin)

	pokemon_summary_level_badge_label = Label.new()
	pokemon_summary_level_badge_label.text = "Lv -"
	pokemon_summary_level_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_summary_level_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_level_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_label_clip_width(pokemon_summary_level_badge_label)
	pokemon_summary_level_badge_label.add_theme_font_size_override("font_size", 12)
	pokemon_summary_level_badge_label.add_theme_color_override("font_color", Color("#f4d78a"))
	pokemon_summary_level_badge_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_level_badge_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_level_badge_label.add_theme_constant_override("shadow_offset_y", 1)
	level_badge_margin.add_child(pokemon_summary_level_badge_label)

	var identity_panel := PanelContainer.new()
	identity_panel.custom_minimum_size = Vector2(0, 38)
	identity_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	identity_panel.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	identity_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#0c1119ee"), Color("#3e4654"), 4, 1))
	left_stack.add_child(identity_panel)

	var identity_margin := MarginContainer.new()
	identity_margin.add_theme_constant_override("margin_left", 7)
	identity_margin.add_theme_constant_override("margin_top", 4)
	identity_margin.add_theme_constant_override("margin_right", 7)
	identity_margin.add_theme_constant_override("margin_bottom", 4)
	identity_panel.add_child(identity_margin)

	var identity_stack := VBoxContainer.new()
	identity_stack.add_theme_constant_override("separation", 1)
	identity_margin.add_child(identity_stack)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	identity_stack.add_child(title_row)

	pokemon_summary_shiny_badge = _create_pokemon_summary_shiny_badge()
	title_row.add_child(pokemon_summary_shiny_badge)

	pokemon_summary_title_label = Label.new()
	pokemon_summary_title_label.text = "Pokemon"
	pokemon_summary_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(pokemon_summary_title_label)
	pokemon_summary_title_label.add_theme_font_size_override("font_size", 14)
	pokemon_summary_title_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	pokemon_summary_title_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_title_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_row.add_child(pokemon_summary_title_label)

	pokemon_summary_meta_label = Label.new()
	pokemon_summary_meta_label.text = "Lv -"
	pokemon_summary_meta_label.custom_minimum_size = Vector2(38, 0)
	pokemon_summary_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_make_label_clip_width(pokemon_summary_meta_label)
	pokemon_summary_meta_label.add_theme_font_size_override("font_size", 11)
	pokemon_summary_meta_label.add_theme_color_override("font_color", Color("#f4d78a"))
	title_row.add_child(pokemon_summary_meta_label)

	var identity_meta_row := HBoxContainer.new()
	identity_meta_row.add_theme_constant_override("separation", 4)
	identity_stack.add_child(identity_meta_row)

	pokemon_summary_id_label = Label.new()
	pokemon_summary_id_label.text = "ID: -"
	pokemon_summary_id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(pokemon_summary_id_label)
	pokemon_summary_id_label.add_theme_font_size_override("font_size", 9)
	pokemon_summary_id_label.add_theme_color_override("font_color", Color("#b8c9e4"))
	identity_meta_row.add_child(pokemon_summary_id_label)

	pokemon_summary_hp_label = Label.new()
	pokemon_summary_hp_label.text = "HP -"
	pokemon_summary_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_summary_hp_label.add_theme_font_size_override("font_size", 11)
	pokemon_summary_hp_label.add_theme_color_override("font_color", Color("#f5df9a"))
	left_stack.add_child(pokemon_summary_hp_label)

	pokemon_summary_ball_picker = PanelContainer.new()
	pokemon_summary_ball_picker.visible = false
	pokemon_summary_ball_picker.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912f2"), UI_BORDER_SOFT, 8, 1))
	left_stack.add_child(pokemon_summary_ball_picker)

	var ball_picker_margin := MarginContainer.new()
	ball_picker_margin.add_theme_constant_override("margin_left", 6)
	ball_picker_margin.add_theme_constant_override("margin_top", 6)
	ball_picker_margin.add_theme_constant_override("margin_right", 6)
	ball_picker_margin.add_theme_constant_override("margin_bottom", 6)
	pokemon_summary_ball_picker.add_child(ball_picker_margin)

	var ball_picker_stack := VBoxContainer.new()
	ball_picker_stack.add_theme_constant_override("separation", 4)
	ball_picker_margin.add_child(ball_picker_stack)

	pokemon_summary_ball_search_input = LineEdit.new()
	pokemon_summary_ball_search_input.placeholder_text = "Search Poké Ball..."
	pokemon_summary_ball_search_input.clear_button_enabled = true
	pokemon_summary_ball_search_input.custom_minimum_size = Vector2(0, 28)
	pokemon_summary_ball_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_ball_search_input.text_changed.connect(_on_pokemon_summary_ball_search_changed)
	_apply_line_edit_style(pokemon_summary_ball_search_input)
	ball_picker_stack.add_child(pokemon_summary_ball_search_input)

	pokemon_summary_ball_list = VBoxContainer.new()
	pokemon_summary_ball_list.add_theme_constant_override("separation", 3)
	ball_picker_stack.add_child(pokemon_summary_ball_list)

	pokemon_summary_hp_bar = ProgressBar.new()
	pokemon_summary_hp_bar.custom_minimum_size = Vector2(0, 8)
	pokemon_summary_hp_bar.show_percentage = false
	pokemon_summary_hp_bar.add_theme_stylebox_override("background", _make_panel_style(Color("#05070cee"), Color("#1d2635"), 3, 0))
	pokemon_summary_hp_bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#8dfb64"), Color("#8dfb64"), 3, 0))
	left_stack.add_child(pokemon_summary_hp_bar)

	pokemon_summary_held_item_slot = PanelContainer.new()
	pokemon_summary_held_item_slot.custom_minimum_size = Vector2(0, 38)
	pokemon_summary_held_item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_held_item_slot.add_theme_stylebox_override("panel", _make_pokemon_summary_held_item_slot_style())

	var held_item_slot_background := TextureRect.new()
	held_item_slot_background.name = "HeldItemSlotBackground"
	held_item_slot_background.texture = BATTLE_SUMMARY_SLOT_BG_TEXTURE
	held_item_slot_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	held_item_slot_background.stretch_mode = TextureRect.STRETCH_SCALE
	held_item_slot_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_slot_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	held_item_slot_background.z_index = -1
	pokemon_summary_held_item_slot.add_child(held_item_slot_background)
	left_stack.add_child(pokemon_summary_held_item_slot)

	var held_item_slot_row := HBoxContainer.new()
	held_item_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_slot_row.add_theme_constant_override("separation", 6)
	held_item_slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	held_item_slot_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_summary_held_item_slot.add_child(held_item_slot_row)

	var held_item_slot_text_column := VBoxContainer.new()
	held_item_slot_text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	held_item_slot_text_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	held_item_slot_text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_slot_row.add_child(held_item_slot_text_column)

	var held_item_slot_top_spacer := Control.new()
	held_item_slot_top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	held_item_slot_text_column.add_child(held_item_slot_top_spacer)

	pokemon_summary_held_item_slot_name_label = Label.new()
	pokemon_summary_held_item_slot_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_held_item_slot_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pokemon_summary_held_item_slot_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_held_item_slot_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_make_label_clip_width(pokemon_summary_held_item_slot_name_label)
	pokemon_summary_held_item_slot_name_label.add_theme_font_size_override("font_size", 12)
	pokemon_summary_held_item_slot_name_label.add_theme_color_override("font_color", Color("#f8df9d"))
	pokemon_summary_held_item_slot_name_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_held_item_slot_name_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_held_item_slot_name_label.add_theme_constant_override("shadow_offset_y", 1)
	held_item_slot_text_column.add_child(pokemon_summary_held_item_slot_name_label)

	var held_item_slot_bottom_spacer := Control.new()
	held_item_slot_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	held_item_slot_text_column.add_child(held_item_slot_bottom_spacer)

	var held_item_slot_icon_panel := PanelContainer.new()
	held_item_slot_icon_panel.custom_minimum_size = Vector2(30, 30)
	held_item_slot_icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	held_item_slot_icon_panel.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, Color("#4b607f"), 8, 1))
	var held_item_slot_icon_center := CenterContainer.new()
	held_item_slot_icon_panel.add_child(held_item_slot_icon_center)
	pokemon_summary_held_item_slot_icon = TextureRect.new()
	pokemon_summary_held_item_slot_icon.custom_minimum_size = Vector2(22, 22)
	pokemon_summary_held_item_slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_summary_held_item_slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokemon_summary_held_item_slot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_slot_icon_center.add_child(pokemon_summary_held_item_slot_icon)
	held_item_slot_row.add_child(held_item_slot_icon_panel)

	pokemon_summary_held_item_slot_button = Button.new()
	pokemon_summary_held_item_slot_button.text = ""
	pokemon_summary_held_item_slot_button.pressed.connect(_on_pokemon_summary_held_item_slot_pressed.bind(card_key))
	pokemon_summary_held_item_slot_button.tooltip_text = "Show held item actions."
	pokemon_summary_held_item_slot_button.focus_mode = Control.FOCUS_NONE
	pokemon_summary_held_item_slot_button.flat = true
	pokemon_summary_held_item_slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pokemon_summary_held_item_slot_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pokemon_summary_held_item_slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_held_item_slot_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_summary_held_item_slot_button.add_theme_stylebox_override("normal", _make_pokemon_summary_held_item_button_style(Color("#00000000"), Color("#00000000")))
	pokemon_summary_held_item_slot_button.add_theme_stylebox_override("hover", _make_pokemon_summary_held_item_button_style(Color("#62d7ff14"), POKEMON_SUMMARY_ACCENT_SOFT))
	pokemon_summary_held_item_slot_button.add_theme_stylebox_override("pressed", _make_pokemon_summary_held_item_button_style(Color("#62d7ff18"), Color("#62d7ffaa")))
	pokemon_summary_held_item_slot_button.add_theme_stylebox_override("disabled", _make_pokemon_summary_held_item_button_style(Color("#00000000"), Color("#00000000")))
	pokemon_summary_held_item_slot_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pokemon_summary_held_item_slot.add_child(pokemon_summary_held_item_slot_button)

	pokemon_summary_item_picker = PanelContainer.new()
	pokemon_summary_item_picker.visible = false
	pokemon_summary_item_picker.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912f2"), UI_BORDER_SOFT, 8, 1))
	left_stack.add_child(pokemon_summary_item_picker)

	var picker_margin := MarginContainer.new()
	picker_margin.add_theme_constant_override("margin_left", 6)
	picker_margin.add_theme_constant_override("margin_top", 6)
	picker_margin.add_theme_constant_override("margin_right", 6)
	picker_margin.add_theme_constant_override("margin_bottom", 6)
	pokemon_summary_item_picker.add_child(picker_margin)

	var item_picker_stack := VBoxContainer.new()
	item_picker_stack.add_theme_constant_override("separation", 4)
	picker_margin.add_child(item_picker_stack)

	pokemon_summary_item_search_input = LineEdit.new()
	pokemon_summary_item_search_input.placeholder_text = "Search held item..."
	pokemon_summary_item_search_input.clear_button_enabled = true
	pokemon_summary_item_search_input.custom_minimum_size = Vector2(0, 28)
	pokemon_summary_item_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_item_search_input.text_changed.connect(_on_pokemon_summary_item_search_changed)
	_apply_line_edit_style(pokemon_summary_item_search_input)
	item_picker_stack.add_child(pokemon_summary_item_search_input)

	pokemon_summary_item_list = VBoxContainer.new()
	pokemon_summary_item_list.add_theme_constant_override("separation", 3)
	item_picker_stack.add_child(pokemon_summary_item_list)

func _add_pokemon_summary_right_area(content_row: HBoxContainer, card_key: String) -> void:
	var right_area := VBoxContainer.new()
	pokemon_summary_right_area = right_area
	right_area.custom_minimum_size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
	right_area.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_area.add_theme_constant_override("separation", 4)
	content_row.add_child(right_area)

	var tab_frame := PanelContainer.new()
	tab_frame.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#060912fb"), POKEMON_SUMMARY_ACCENT_SOFT))
	tab_frame.custom_minimum_size = Vector2(0, 34)
	tab_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_frame.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	right_area.add_child(tab_frame)

	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 4)
	tab_margin.add_theme_constant_override("margin_top", 3)
	tab_margin.add_theme_constant_override("margin_right", 4)
	tab_margin.add_theme_constant_override("margin_bottom", 3)
	tab_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_margin.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	tab_frame.add_child(tab_margin)

	var tab_column := HBoxContainer.new()
	pokemon_summary_tab_column = tab_column
	tab_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tab_column.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_column.add_theme_constant_override("separation", 4)
	tab_margin.add_child(tab_column)

	_add_pokemon_summary_tab_buttons(tab_column, card_key)

	var summary_content_panel := PanelContainer.new()
	pokemon_summary_content_panel = summary_content_panel
	summary_content_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, POKEMON_SUMMARY_CONTENT_PANEL_HEIGHT)
	summary_content_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_content_panel.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#070b13fa"), POKEMON_SUMMARY_ACCENT_SOFT))
	right_area.add_child(summary_content_panel)

	var summary_content_margin := MarginContainer.new()
	summary_content_margin.add_theme_constant_override("margin_left", 8)
	summary_content_margin.add_theme_constant_override("margin_top", 7)
	summary_content_margin.add_theme_constant_override("margin_right", 8)
	summary_content_margin.add_theme_constant_override("margin_bottom", 7)
	summary_content_panel.add_child(summary_content_margin)

	pokemon_summary_content_stack = VBoxContainer.new()
	pokemon_summary_content_stack.custom_minimum_size = Vector2(0, POKEMON_SUMMARY_CONTENT_STACK_HEIGHT)
	pokemon_summary_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_theme_constant_override("separation", 5)
	summary_content_margin.add_child(pokemon_summary_content_stack)

func _add_pokemon_summary_owner_bar(layout: VBoxContainer, card_key: String) -> void:
	var header_frame := PanelContainer.new()
	header_frame.custom_minimum_size = Vector2(0, 26)
	header_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	header_frame.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	header_frame.add_theme_stylebox_override("panel", _make_pokemon_summary_header_frame_style())
	layout.add_child(header_frame)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 8)
	header_margin.add_theme_constant_override("margin_top", 2)
	header_margin.add_theme_constant_override("margin_right", 4)
	header_margin.add_theme_constant_override("margin_bottom", 2)
	header_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	header_margin.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	header_frame.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 6)
	header_row.mouse_filter = Control.MOUSE_FILTER_STOP
	header_row.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	header_margin.add_child(header_row)

	pokemon_summary_trainer_label = Label.new()
	pokemon_summary_trainer_label.text = "Trainer's Pokemon"
	pokemon_summary_trainer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_trainer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_trainer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_label_clip_width(pokemon_summary_trainer_label)
	pokemon_summary_trainer_label.add_theme_font_size_override("font_size", 15)
	pokemon_summary_trainer_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	pokemon_summary_trainer_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_trainer_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_trainer_label.add_theme_constant_override("shadow_offset_y", 1)
	pokemon_summary_trainer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(pokemon_summary_trainer_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(24, 22)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = "Close"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_hide_pokemon_summary_popup.bind(card_key))
	close_button.add_theme_stylebox_override("normal", _make_pokemon_summary_button_style(Color("#0e2138f0"), Color("#5a82ad"), true))
	close_button.add_theme_stylebox_override("hover", _make_pokemon_summary_button_style(Color("#241421f0"), UI_DANGER, true))
	close_button.add_theme_stylebox_override("pressed", _make_pokemon_summary_button_style(Color("#0b1019f0"), UI_DANGER, true))
	close_button.add_theme_color_override("font_shadow_color", Color("#00111f"))
	close_button.add_theme_constant_override("shadow_offset_x", 1)
	close_button.add_theme_constant_override("shadow_offset_y", 1)
	close_button.add_theme_color_override("font_color", UI_TEXT)
	header_row.add_child(close_button)

func _add_pokemon_summary_top_accent_bar(layout: VBoxContainer, card_key: String) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 0)
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	layout.add_child(top_bar)

	var top_bar_left := ColorRect.new()
	top_bar_left.color = Color("#ffe29a88")
	top_bar_left.custom_minimum_size = Vector2(60, 2)
	top_bar_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_left.size_flags_stretch_ratio = 1.0
	top_bar_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_bar_left)

	var top_bar_mid := ColorRect.new()
	top_bar_mid.color = Color("#62d7ff77")
	top_bar_mid.custom_minimum_size = Vector2(180, 2)
	top_bar_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_mid.size_flags_stretch_ratio = 2.0
	top_bar_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_bar_mid)

	var top_bar_right := ColorRect.new()
	top_bar_right.color = Color("#9b6cff77")
	top_bar_right.custom_minimum_size = Vector2(60, 2)
	top_bar_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_right.size_flags_stretch_ratio = 1.0
	top_bar_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_bar_right)

func _add_pokemon_summary_header(layout: VBoxContainer, card_key: String) -> void:
	var header_frame := PanelContainer.new()
	header_frame.add_theme_stylebox_override("panel", _make_pokemon_summary_header_frame_style())
	header_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	header_frame.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	layout.add_child(header_frame)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 6)
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_right", 6)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_margin.mouse_filter = Control.MOUSE_FILTER_STOP
	header_margin.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	header_frame.add_child(header_margin)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_pokemon_summary_header_gui_input.bind(card_key))
	header_margin.add_child(header)

	pokemon_summary_title_label = Label.new()
	pokemon_summary_title_label.text = "Pokemon Summary"
	pokemon_summary_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_title_label.size_flags_stretch_ratio = 1.0
	_make_label_clip_width(pokemon_summary_title_label)
	pokemon_summary_title_label.add_theme_font_size_override("font_size", 21)
	pokemon_summary_title_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_title_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_title_label.add_theme_constant_override("shadow_offset_y", 1)
	pokemon_summary_title_label.add_theme_constant_override("outline_size", 1)
	pokemon_summary_title_label.add_theme_color_override("font_outline_color", Color("#001b34"))
	pokemon_summary_title_label.add_theme_color_override("font_color", UI_TEXT)
	pokemon_summary_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pokemon_summary_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.size_flags_stretch_ratio = 1.0
	title_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	title_row.add_theme_constant_override("separation", 5)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(pokemon_summary_title_label)

	pokemon_summary_shiny_badge = _create_pokemon_summary_shiny_badge()
	title_row.add_child(pokemon_summary_shiny_badge)
	header.add_child(title_row)

	pokemon_summary_id_label = Label.new()
	pokemon_summary_id_label.text = "ID: -"
	pokemon_summary_id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_id_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	pokemon_summary_id_label.custom_minimum_size = Vector2(50, 0)
	pokemon_summary_id_label.add_theme_font_size_override("font_size", 10)
	pokemon_summary_id_label.add_theme_color_override("font_color", Color("#f4d78a"))
	pokemon_summary_id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pokemon_summary_id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(pokemon_summary_id_label)

	var id_divider := ColorRect.new()
	id_divider.custom_minimum_size = Vector2(1, 18)
	id_divider.color = Color("#d8b767")
	id_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(id_divider)

	var meta_block := VBoxContainer.new()
	meta_block.custom_minimum_size = Vector2(118, 0)
	meta_block.size_flags_horizontal = Control.SIZE_SHRINK_END
	meta_block.add_theme_constant_override("separation", 2)
	meta_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(meta_block)

	pokemon_summary_meta_label = Label.new()
	pokemon_summary_meta_label.text = "--"
	pokemon_summary_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(pokemon_summary_meta_label)
	pokemon_summary_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_meta_label.add_theme_font_size_override("font_size", 11)
	pokemon_summary_meta_label.add_theme_color_override("font_color", Color("#d9ecff"))
	pokemon_summary_meta_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	pokemon_summary_meta_label.add_theme_constant_override("shadow_offset_x", 1)
	pokemon_summary_meta_label.add_theme_constant_override("shadow_offset_y", 1)
	pokemon_summary_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_block.add_child(pokemon_summary_meta_label)

	pokemon_summary_trainer_label = Label.new()
	pokemon_summary_trainer_label.text = "Original Trainer: -"
	pokemon_summary_trainer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(pokemon_summary_trainer_label)
	pokemon_summary_trainer_label.add_theme_font_size_override("font_size", 9)
	pokemon_summary_trainer_label.add_theme_color_override("font_color", Color("#9eb7d8"))
	pokemon_summary_trainer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_block.add_child(pokemon_summary_trainer_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(26, 24)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_pokemon_summary_popup.bind(card_key))
	close_button.add_theme_stylebox_override("normal", _make_pokemon_summary_button_style(Color("#0e2138f0"), Color("#5a82ad"), true))
	close_button.add_theme_stylebox_override("hover", _make_pokemon_summary_button_style(Color("#241421f0"), UI_DANGER, true))
	close_button.add_theme_stylebox_override("pressed", _make_pokemon_summary_button_style(Color("#0b1019f0"), UI_DANGER, true))
	close_button.add_theme_color_override("font_shadow_color", Color("#00111f"))
	close_button.add_theme_constant_override("shadow_offset_x", 1)
	close_button.add_theme_constant_override("shadow_offset_y", 1)
	close_button.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(close_button)

func _create_pokemon_summary_shiny_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.visible = false
	badge.custom_minimum_size = Vector2(16, 16)
	badge.tooltip_text = "Shiny Pokemon"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#15191fee")
	badge_style.border_color = Color("#f4d36a")
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	badge_style.shadow_size = 3
	badge_style.shadow_color = Color("#f4d36a33")
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var badge_padding := MarginContainer.new()
	badge_padding.add_theme_constant_override("margin_left", 2)
	badge_padding.add_theme_constant_override("margin_top", 0)
	badge_padding.add_theme_constant_override("margin_right", 2)
	badge_padding.add_theme_constant_override("margin_bottom", 0)
	badge_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_padding)

	pokemon_summary_shiny_badge_label = Label.new()
	pokemon_summary_shiny_badge_label.text = "*"
	pokemon_summary_shiny_badge_label.add_theme_font_size_override("font_size", 13)
	pokemon_summary_shiny_badge_label.add_theme_color_override("font_color", Color("#f4d36a"))
	pokemon_summary_shiny_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_summary_shiny_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_shiny_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_label_clip_width(pokemon_summary_shiny_badge_label)
	badge_padding.add_child(pokemon_summary_shiny_badge_label)
	return badge

func _add_pokemon_summary_tab_buttons(tab_column: HBoxContainer, card_key: String) -> void:
	var general_tab := _create_pokemon_summary_tab_button("general", "Info", POKEMON_SUMMARY_ACCENT, card_key)
	var iv_tab := _create_pokemon_summary_tab_button("ivs", "IVs", Color("#1fb6ff"), card_key)
	var ev_tab := _create_pokemon_summary_tab_button("evs", "EVs", Color("#ffb347"), card_key)
	var moves_tab := _create_pokemon_summary_tab_button("moves", "Moves", Color("#ff7b54"), card_key)
	tab_column.add_child(general_tab)
	tab_column.add_child(iv_tab)
	tab_column.add_child(ev_tab)
	tab_column.add_child(moves_tab)

func _setup_pokemon_summary_ev_allocate_popup() -> void:
	pokemon_summary_ev_allocate_popup = PanelContainer.new()
	pokemon_summary_ev_allocate_popup.name = "PokemonSummaryEvAllocatePopup"
	pokemon_summary_ev_allocate_popup.visible = false
	pokemon_summary_ev_allocate_popup.custom_minimum_size = Vector2(300, 210)
	pokemon_summary_ev_allocate_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	pokemon_summary_ev_allocate_popup.z_index = UI_BASE_Z_INDEX + 2
	pokemon_summary_ev_allocate_popup.anchor_left = 0.5
	pokemon_summary_ev_allocate_popup.anchor_top = 0.5
	pokemon_summary_ev_allocate_popup.anchor_right = 0.5
	pokemon_summary_ev_allocate_popup.anchor_bottom = 0.5
	pokemon_summary_ev_allocate_popup.offset_left = -150
	pokemon_summary_ev_allocate_popup.offset_top = -105
	pokemon_summary_ev_allocate_popup.offset_right = 150
	pokemon_summary_ev_allocate_popup.offset_bottom = 105
	pokemon_summary_ev_allocate_popup.add_theme_stylebox_override("panel", _make_pokemon_summary_outer_style())
	root_control.add_child(pokemon_summary_ev_allocate_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	pokemon_summary_ev_allocate_popup.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	pokemon_summary_ev_allocate_stat_label = Label.new()
	pokemon_summary_ev_allocate_stat_label.text = "Allocate EVs"
	pokemon_summary_ev_allocate_stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_ev_allocate_stat_label.add_theme_font_size_override("font_size", 16)
	pokemon_summary_ev_allocate_stat_label.add_theme_color_override("font_color", Color("#f5df9a"))
	header.add_child(pokemon_summary_ev_allocate_stat_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_pokemon_summary_ev_allocate_popup)
	header.add_child(close_button)
	_apply_button_style(close_button)

	pokemon_summary_ev_allocate_current_label = Label.new()
	pokemon_summary_ev_allocate_current_label.add_theme_font_size_override("font_size", 12)
	pokemon_summary_ev_allocate_current_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(pokemon_summary_ev_allocate_current_label)

	pokemon_summary_ev_allocate_input = SpinBox.new()
	pokemon_summary_ev_allocate_input.min_value = 0
	pokemon_summary_ev_allocate_input.max_value = 252
	pokemon_summary_ev_allocate_input.step = 1
	pokemon_summary_ev_allocate_input.value_changed.connect(_on_summary_ev_allocate_value_changed)
	layout.add_child(pokemon_summary_ev_allocate_input)

	pokemon_summary_ev_allocate_status_label = Label.new()
	pokemon_summary_ev_allocate_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pokemon_summary_ev_allocate_status_label.add_theme_font_size_override("font_size", 11)
	pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(pokemon_summary_ev_allocate_status_label)

	pokemon_summary_ev_allocate_confirm_button = Button.new()
	pokemon_summary_ev_allocate_confirm_button.text = "Confirm"
	pokemon_summary_ev_allocate_confirm_button.custom_minimum_size = Vector2(0, 34)
	pokemon_summary_ev_allocate_confirm_button.focus_mode = Control.FOCUS_NONE
	pokemon_summary_ev_allocate_confirm_button.pressed.connect(_on_summary_ev_allocate_confirm_pressed)
	layout.add_child(pokemon_summary_ev_allocate_confirm_button)
	_apply_button_style(pokemon_summary_ev_allocate_confirm_button, "primary")

func _create_pokemon_summary_tab_button(tab_id: String, label_text: String, accent_color: Color, card_key: String = "") -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(POKEMON_SUMMARY_TAB_COLUMN_WIDTH, 28)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = label_text
	button.pressed.connect(_on_pokemon_summary_tab_selected.bind(tab_id, card_key))
	pokemon_summary_tab_buttons[tab_id] = button
	_apply_summary_tab_style(button, false, accent_color)
	return button

func _on_pokemon_summary_tab_selected(tab_id: String, card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	pokemon_summary_active_tab = tab_id
	_store_active_pokemon_summary_card_context()
	_refresh_pokemon_summary()

func _refresh_pokemon_summary_tab_buttons() -> void:
	for tab_id_value: Variant in pokemon_summary_tab_buttons.keys():
		var tab_id: String = str(tab_id_value)
		var button: Button = pokemon_summary_tab_buttons.get(tab_id) as Button
		if button == null:
			continue
		var accent_color: Color = _pokemon_summary_tab_color(tab_id)
		_apply_summary_tab_style(button, tab_id == pokemon_summary_active_tab, accent_color)

func _pokemon_summary_tab_color(tab_id: String) -> Color:
	match tab_id:
		"ivs":
			return Color("#1fb6ff")
		"evs":
			return Color("#ffb347")
		"moves":
			return Color("#ff7b54")
		_:
			return POKEMON_SUMMARY_ACCENT

func _apply_summary_tab_style(button: Button, selected: bool, accent_color: Color) -> void:
	var bg: Color = Color("#090d14f2") if not selected else POKEMON_SUMMARY_ACCENT
	var border: Color = Color("#27313f") if not selected else Color("#b9efff")
	button.add_theme_color_override("font_color", Color("#14161c") if selected else Color("#dde5f2"))
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_shadow_color", Color("#00000000") if selected else Color("#00111f"))
	button.add_theme_constant_override("shadow_offset_x", 0 if selected else 1)
	button.add_theme_constant_override("shadow_offset_y", 0 if selected else 1)
	button.text = button.text.to_upper()
	button.add_theme_stylebox_override("normal", _make_pokemon_summary_tab_button_style(bg, border, selected, accent_color))
	button.add_theme_stylebox_override("hover", _make_pokemon_summary_tab_button_style(Color("#121a28f2"), POKEMON_SUMMARY_ACCENT_SOFT, false, accent_color))
	button.add_theme_stylebox_override("pressed", _make_pokemon_summary_tab_button_style(POKEMON_SUMMARY_ACCENT_DARK, Color("#b9efff"), true, accent_color))
	button.add_theme_stylebox_override("focus", _make_pokemon_summary_tab_button_style(bg, accent_color, selected, accent_color))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_pokemon_summary_tab_button_style(
	background_color: Color,
	border_color: Color,
	selected: bool,
	accent_color: Color
) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 3, 1)
	style.content_margin_left = 5
	style.content_margin_top = 4
	style.content_margin_right = 5
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if selected:
		style.border_color = accent_color
		style.bg_color = background_color
	else:
		style.border_color = border_color
	return style

func _setup_bag_popup() -> void:
	bag_popup = PanelContainer.new()
	bag_popup.name = "BagPopup"
	bag_popup.visible = false
	bag_popup.custom_minimum_size = BAG_SIZE
	bag_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_popup.z_index = UI_BASE_Z_INDEX
	bag_popup.anchor_left = 0.5
	bag_popup.anchor_top = 0.5
	bag_popup.anchor_right = 0.5
	bag_popup.anchor_bottom = 0.5
	bag_popup.offset_left = -BAG_SIZE.x * 0.5
	bag_popup.offset_top = -BAG_SIZE.y * 0.5
	bag_popup.offset_right = BAG_SIZE.x * 0.5
	bag_popup.offset_bottom = BAG_SIZE.y * 0.5
	bag_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(bag_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 14)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 14)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	bag_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_bag_header_gui_input)
	layout.add_child(header)

	var title_label := Label.new()
	title_label.text = "Bag"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_bag_popup)
	_apply_button_style(close_button)
	header.add_child(close_button)

	bag_search_input = LineEdit.new()
	bag_search_input.placeholder_text = ""
	bag_search_input.custom_minimum_size = Vector2(420, 30)
	bag_search_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bag_search_input.text_changed.connect(_on_bag_search_changed)
	_apply_line_edit_style(bag_search_input)
	layout.add_child(bag_search_input)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14)
	layout.add_child(content_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_row.add_child(scroll)

	bag_item_grid = GridContainer.new()
	bag_item_grid.columns = 7
	bag_item_grid.add_theme_constant_override("h_separation", 10)
	bag_item_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(bag_item_grid)

	var category_column := VBoxContainer.new()
	category_column.custom_minimum_size = Vector2(150, 0)
	category_column.add_theme_constant_override("separation", 10)
	content_row.add_child(category_column)

	for category_value: Variant in BAG_CATEGORIES:
		var category: Dictionary = category_value as Dictionary
		var category_id := str(category.get("id", ""))
		var category_button := Button.new()
		category_button.text = str(category.get("label", category_id))
		category_button.custom_minimum_size = Vector2(140, 44)
		category_button.focus_mode = Control.FOCUS_NONE
		category_button.pressed.connect(_on_bag_category_selected.bind(category_id))
		category_column.add_child(category_button)
		bag_category_buttons[category_id] = category_button

	_refresh_bag_category_buttons()
	_refresh_bag_items()

func _setup_bag_item_use_popup() -> void:
	bag_item_use_popup = PanelContainer.new()
	bag_item_use_popup.name = "BagItemUsePopup"
	bag_item_use_popup.visible = false
	bag_item_use_popup.custom_minimum_size = Vector2(440, 390)
	bag_item_use_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_item_use_popup.z_index = UI_MODAL_Z_INDEX
	bag_item_use_popup.anchor_left = 0.5
	bag_item_use_popup.anchor_top = 0.5
	bag_item_use_popup.anchor_right = 0.5
	bag_item_use_popup.anchor_bottom = 0.5
	bag_item_use_popup.offset_left = -220
	bag_item_use_popup.offset_top = -195
	bag_item_use_popup.offset_right = 220
	bag_item_use_popup.offset_bottom = 195
	bag_item_use_popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912fa"), POKEMON_SUMMARY_ACCENT_SOFT, 8, 1))
	root_control.add_child(bag_item_use_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	bag_item_use_popup.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	bag_item_use_title_label = Label.new()
	bag_item_use_title_label.text = "Use Item"
	bag_item_use_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_item_use_title_label.add_theme_font_size_override("font_size", 18)
	bag_item_use_title_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	header.add_child(bag_item_use_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_bag_item_use_popup)
	_apply_button_style(close_button)
	header.add_child(close_button)

	bag_item_use_item_label = Label.new()
	bag_item_use_item_label.text = "Select an item."
	bag_item_use_item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_item_use_item_label.add_theme_font_size_override("font_size", 13)
	bag_item_use_item_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(bag_item_use_item_label)

	var party_label := Label.new()
	party_label.text = "Choose Pokemon"
	party_label.add_theme_font_size_override("font_size", 11)
	party_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(party_label)

	var party_scroll := ScrollContainer.new()
	party_scroll.custom_minimum_size = Vector2(0, 170)
	party_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(party_scroll)

	bag_item_use_party_list = VBoxContainer.new()
	bag_item_use_party_list.add_theme_constant_override("separation", 6)
	bag_item_use_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_scroll.add_child(bag_item_use_party_list)

	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 8)
	layout.add_child(quantity_row)

	var quantity_label := Label.new()
	quantity_label.text = "Amount"
	quantity_label.custom_minimum_size = Vector2(84, 0)
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	quantity_row.add_child(quantity_label)

	bag_item_use_quantity_spinbox = SpinBox.new()
	bag_item_use_quantity_spinbox.min_value = 1
	bag_item_use_quantity_spinbox.max_value = 1
	bag_item_use_quantity_spinbox.value = 1
	bag_item_use_quantity_spinbox.step = 1
	bag_item_use_quantity_spinbox.editable = false
	bag_item_use_quantity_spinbox.custom_minimum_size = Vector2(116, 0)
	bag_item_use_quantity_spinbox.value_changed.connect(_on_bag_item_use_quantity_changed)
	quantity_row.add_child(bag_item_use_quantity_spinbox)

	bag_item_use_status_label = Label.new()
	bag_item_use_status_label.text = "Select a Pokemon first."
	bag_item_use_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_item_use_status_label.add_theme_font_size_override("font_size", 12)
	bag_item_use_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(bag_item_use_status_label)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(112, 32)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(_hide_bag_item_use_popup)
	_apply_button_style(cancel_button)
	action_row.add_child(cancel_button)

	bag_item_use_confirm_button = Button.new()
	bag_item_use_confirm_button.text = "Use"
	bag_item_use_confirm_button.custom_minimum_size = Vector2(128, 32)
	bag_item_use_confirm_button.focus_mode = Control.FOCUS_NONE
	bag_item_use_confirm_button.disabled = true
	bag_item_use_confirm_button.pressed.connect(_on_bag_item_use_confirm_pressed)
	_apply_button_style(bag_item_use_confirm_button, "primary")
	action_row.add_child(bag_item_use_confirm_button)

func _refresh_bag_items() -> void:
	if bag_item_grid == null:
		return
	for child: Node in bag_item_grid.get_children():
		child.queue_free()

	var search_text := ""
	if bag_search_input != null:
		search_text = bag_search_input.text.strip_edges().to_lower()

	if bag_inventory_loading:
		bag_item_grid.add_child(_create_bag_empty_state("Loading bag..."))
		return

	if not bag_inventory_loaded:
		bag_item_grid.add_child(_create_bag_empty_state("Open your bag to load items."))
		return

	var visible_count := 0
	for item_value: Variant in bag_inventory_items:
		var item: Dictionary = item_value as Dictionary
		var item_category := str(item.get("category", "general"))
		var item_name := str(item.get("name", ""))
		var item_id := str(item.get("id", ""))
		if active_bag_category != "general" and item_category != active_bag_category:
			continue
		if search_text != "" and not item_name.to_lower().contains(search_text) and not item_id.to_lower().contains(search_text):
			continue
		bag_item_grid.add_child(_create_bag_item_slot(item))
		visible_count += 1

	if visible_count <= 0:
		bag_item_grid.add_child(_create_bag_empty_state("No items in this tab."))

func _create_bag_empty_state(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(360, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	return label

func _create_bag_item_slot(item: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(78, 92)
	slot.add_theme_stylebox_override("panel", _make_panel_style(Color("#071827f2"), Color("#557999"), 8, 1))
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = str(item.get("name", "Item"))
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.gui_input.connect(_on_bag_item_slot_gui_input.bind(item.duplicate(true)))

	var margin_container := MarginContainer.new()
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", 5)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_right", 5)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	slot.add_child(margin_container)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	margin_container.add_child(stack)

	var icon_wrap := Control.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.custom_minimum_size = Vector2(64, 44)
	stack.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_item_icon(str(item.get("id", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)

	var quantity_label := Label.new()
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.text = "x%s" % max(int(item.get("quantity", 1)), 1)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 11)
	quantity_label.add_theme_color_override("font_color", UI_MONEY)
	stack.add_child(quantity_label)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = _ellipsize_text(str(item.get("name", "Item")), 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(name_label)
	return slot

func _on_bag_item_slot_gui_input(event: InputEvent, item: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	_on_bag_item_selected(item)

func _on_bag_item_selected(item: Dictionary) -> void:
	var item_id := _normalize_item_id(str(item.get("id", "")))
	if item_id == "":
		return
	if _is_pokemon_usable_item_id(item_id):
		_show_bag_item_use_popup(item)
		return

	_add_chat_message("%s cannot be used from the Bag yet." % str(item.get("name", _item_name_from_id(item_id))))

func _show_bag_item_use_popup(item: Dictionary) -> void:
	if bag_item_use_popup == null:
		return

	bag_item_use_pending_item = item.duplicate(true)
	bag_item_use_selected_slot = -1
	bag_item_use_in_progress = false
	var item_id := _normalize_item_id(str(item.get("id", "")))
	var item_name := str(item.get("name", _item_name_from_id(item_id)))
	var quantity: int = max(int(item.get("quantity", 1)), 1)
	bag_item_use_title_label.text = "Use %s" % item_name
	bag_item_use_item_label.text = "%s x%s" % [item_name, quantity]
	bag_item_use_quantity_spinbox.max_value = min(quantity, 99)
	bag_item_use_quantity_spinbox.value = 1
	bag_item_use_quantity_spinbox.editable = false
	if bag_item_use_confirm_button != null:
		bag_item_use_confirm_button.disabled = true
	bag_item_use_status_label.text = "Select a Pokemon first."
	bag_item_use_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	_refresh_bag_item_use_party_list()
	bag_item_use_popup.visible = true
	bag_item_use_popup.move_to_front()
	_activate_ui_panel(bag_item_use_popup)

func _hide_bag_item_use_popup() -> void:
	if bag_item_use_in_progress:
		return
	if bag_item_use_popup != null:
		bag_item_use_popup.visible = false
	bag_item_use_pending_item = {}
	bag_item_use_selected_slot = -1

func _refresh_bag_item_use_party_list() -> void:
	if bag_item_use_party_list == null:
		return
	for child: Node in bag_item_use_party_list.get_children():
		child.queue_free()

	if PlayerSave.party.is_empty():
		bag_item_use_party_list.add_child(_create_bag_empty_state("Your party is empty."))
		return

	for slot_index in range(PlayerSave.party.size()):
		var pokemon: Pokemon = PlayerSave.party[slot_index]
		if pokemon == null:
			continue
		bag_item_use_party_list.add_child(_create_bag_item_use_pokemon_button(pokemon, slot_index))

func _on_bag_item_use_quantity_changed(_value: float) -> void:
	if bag_item_use_popup == null or not bag_item_use_popup.visible:
		return
	if bag_item_use_in_progress:
		return
	_refresh_bag_item_use_selected_preview()
	_refresh_bag_item_use_party_list()

func _create_bag_item_use_pokemon_button(pokemon: Pokemon, slot_index: int) -> Control:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 44)
	button.focus_mode = Control.FOCUS_NONE
	var item_id := _normalize_item_id(str(bag_item_use_pending_item.get("id", "")))
	var requested_quantity := 1
	if bag_item_use_quantity_spinbox != null:
		requested_quantity = clampi(int(bag_item_use_quantity_spinbox.value), 1, int(bag_item_use_quantity_spinbox.max_value))
	var preview: Dictionary = {}
	var preview_text := ""
	if slot_index == bag_item_use_selected_slot:
		preview = _bag_item_use_preview_for_pokemon(pokemon, item_id, requested_quantity)
		preview_text = str(preview.get("label", ""))
	button.text = "%s  Lv. %s%s" % [
		pokemon.species,
		max(pokemon.level, 1),
		"  ->  %s" % preview_text if preview_text != "" else "",
	]
	button.tooltip_text = str(preview.get("tooltip", button.text))
	button.disabled = bag_item_use_in_progress or pokemon.owned_pokemon_id <= 0 or not _bag_item_can_affect_pokemon(pokemon, item_id)
	if pokemon.owned_pokemon_id <= 0:
		button.tooltip_text = "%s is missing an ownership id." % pokemon.species
	elif button.disabled and not bag_item_use_in_progress:
		var disabled_preview := _bag_item_use_preview_for_pokemon(pokemon, item_id, requested_quantity)
		button.tooltip_text = str(disabled_preview.get("tooltip", button.tooltip_text))
	button.pressed.connect(_on_bag_item_use_pokemon_selected.bind(slot_index))
	_apply_button_style(button, "primary" if slot_index == bag_item_use_selected_slot else "default")
	return button

func _bag_item_use_preview_for_pokemon(pokemon: Pokemon, item_id: String, requested_quantity: int) -> Dictionary:
	if pokemon == null:
		return {}
	if _is_ev_item_id(item_id):
		return _bag_ev_item_use_preview_for_pokemon(pokemon, item_id, requested_quantity)
	if not _is_exp_item_id(item_id):
		return {}

	var current_level: int = clampi(max(pokemon.level, 1), 1, POKEMON_MAX_LEVEL)
	if current_level >= POKEMON_MAX_LEVEL:
		return {
			"label": "Max level",
			"tooltip": "%s is already Lv. 100." % pokemon.species,
		}

	var growth_rate := _normalize_exp_growth_rate(pokemon.growth_rate)
	var current_exp := _pokemon_preview_current_experience(pokemon, growth_rate)
	var max_exp := _pokemon_exp_for_level(growth_rate, POKEMON_MAX_LEVEL)
	var remaining_exp: int = max(max_exp - current_exp, 0)
	if remaining_exp <= 0:
		return {
			"label": "Max level",
			"tooltip": "%s is already at the level cap." % pokemon.species,
		}

	var quantity: int = max(requested_quantity, 1)
	var used_quantity: int = quantity
	var gained_exp := 0
	var target_level := current_level
	if item_id == "rare-candy":
		used_quantity = min(quantity, POKEMON_MAX_LEVEL - current_level)
		target_level = min(current_level + used_quantity, POKEMON_MAX_LEVEL)
		var target_exp: int = _pokemon_exp_for_level(growth_rate, target_level)
		gained_exp = min(max(target_exp - current_exp, 0), remaining_exp)
	else:
		var candy_exp: int = int(EXP_CANDY_EXPERIENCE.get(item_id, 0))
		if candy_exp <= 0:
			return {}
		used_quantity = min(quantity, int(ceil(float(remaining_exp) / float(candy_exp))))
		gained_exp = min(used_quantity * candy_exp, remaining_exp)
		target_level = _pokemon_level_for_exp(growth_rate, current_exp + gained_exp)

	var label := "+%s EXP" % gained_exp
	if target_level > current_level:
		label = "Lv. %s  +%s EXP" % [target_level, gained_exp]
	if used_quantity < quantity:
		label += "  uses %s/%s" % [used_quantity, quantity]

	return {
		"label": label,
		"tooltip": "%s\nUses %sx item(s)\nEstimated gain: %s EXP\nEstimated level: %s -> %s" % [
			pokemon.species,
			used_quantity,
			gained_exp,
			current_level,
			target_level,
		],
	}

func _bag_ev_item_use_preview_for_pokemon(pokemon: Pokemon, item_id: String, requested_quantity: int) -> Dictionary:
	var effect: Dictionary = EV_ITEM_EFFECTS.get(item_id, {})
	var stat_id := str(effect.get("stat", "")).strip_edges()
	var potency: int = max(int(effect.get("potency", 0)), 0)
	if stat_id == "" or potency <= 0:
		return {}

	var current_evs: Dictionary = pokemon.evs
	var current_stored_evs: Dictionary = pokemon.stored_evs
	var current_value: int = clampi(int(current_stored_evs.get(stat_id, 0)), 0, POKEMON_EV_STAT_LIMIT)
	var allocated_total: int = _get_summary_ev_total(current_evs)
	var stored_total: int = _get_summary_ev_total(current_stored_evs)
	var max_gain: int = min(
		max(POKEMON_EV_STAT_LIMIT - current_value, 0),
		max(POKEMON_EV_TOTAL_LIMIT - allocated_total - stored_total, 0)
	)
	var stat_label := _summary_stat_label(stat_id)
	if max_gain <= 0:
		return {
			"label": "Storage full",
			"tooltip": "%s cannot store more EVs right now.\nStored %s EVs: %s/%s\nAllocated EVs: %s/%s\nStored EVs: %s" % [
				pokemon.species,
				stat_label,
				current_value,
				POKEMON_EV_STAT_LIMIT,
				allocated_total,
				POKEMON_EV_TOTAL_LIMIT,
				stored_total,
			],
		}

	var quantity: int = max(requested_quantity, 1)
	var used_quantity: int = min(quantity, int(ceil(float(max_gain) / float(potency))))
	var gained_evs: int = min(used_quantity * potency, max_gain)
	var new_value: int = current_value + gained_evs
	var new_stored_total: int = stored_total + gained_evs
	var label := "Stored %s %s -> %s" % [stat_label, current_value, new_value]
	if used_quantity < quantity:
		label += "  uses %s/%s" % [used_quantity, quantity]

	return {
		"label": label,
		"tooltip": "%s\nUses %sx item(s)\nStored %s EVs: %s -> %s\nStored EV total: %s -> %s\nAllocated EVs: %s / %s" % [
			pokemon.species,
			used_quantity,
			stat_label,
			current_value,
			new_value,
			stored_total,
			new_stored_total,
			allocated_total,
			POKEMON_EV_TOTAL_LIMIT,
		],
	}

func _bag_item_can_affect_pokemon(pokemon: Pokemon, item_id: String) -> bool:
	if pokemon == null:
		return false
	var preview := _bag_item_use_preview_for_pokemon(pokemon, item_id, 1)
	if preview.is_empty():
		return false
	var label := str(preview.get("label", ""))
	return not label.contains("Max level") and not label.contains("EV cap") and not label.contains("Storage full")

func _pokemon_preview_current_experience(pokemon: Pokemon, growth_rate: String) -> int:
	var level_floor_exp: int = _pokemon_exp_for_level(growth_rate, max(pokemon.level, 1))
	return max(max(pokemon.experience, pokemon.current_level_exp), level_floor_exp)

func _normalize_exp_growth_rate(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if normalized in ["slow", "medium", "fast", "medium-slow", "slow-then-very-fast", "fast-then-very-slow"]:
		return normalized
	return "medium"

func _pokemon_level_for_exp(growth_rate: String, experience: int) -> int:
	var safe_experience: int = max(experience, 0)
	var resolved_level := 1
	for candidate_level in range(2, POKEMON_MAX_LEVEL + 1):
		if _pokemon_exp_for_level(growth_rate, candidate_level) > safe_experience:
			break
		resolved_level = candidate_level
	return resolved_level

func _pokemon_exp_for_level(growth_rate: String, level: int) -> int:
	var resolved_level: int = clampi(level, 1, POKEMON_MAX_LEVEL)
	if resolved_level <= 1:
		return 0

	var cube: int = resolved_level * resolved_level * resolved_level
	match _normalize_exp_growth_rate(growth_rate):
		"fast":
			return _pokemon_exp_floor_div(4 * cube, 5)
		"medium":
			return cube
		"medium-slow":
			return max(0, _pokemon_exp_floor_div(6 * cube, 5) - (15 * resolved_level * resolved_level) + (100 * resolved_level) - 140)
		"slow":
			return _pokemon_exp_floor_div(5 * cube, 4)
		"slow-then-very-fast":
			if resolved_level <= 50:
				return _pokemon_exp_floor_div(cube * (100 - resolved_level), 50)
			if resolved_level <= 68:
				return _pokemon_exp_floor_div(cube * (150 - resolved_level), 100)
			if resolved_level <= 98:
				return _pokemon_exp_floor_div(cube * _pokemon_exp_floor_div(1911 - (10 * resolved_level), 3), 500)
			return _pokemon_exp_floor_div(cube * (160 - resolved_level), 100)
		_:
			if resolved_level <= 15:
				return _pokemon_exp_floor_div(cube * (_pokemon_exp_floor_div(resolved_level + 1, 3) + 24), 50)
			if resolved_level <= 36:
				return _pokemon_exp_floor_div(cube * (resolved_level + 14), 50)
			return _pokemon_exp_floor_div(cube * (_pokemon_exp_floor_div(resolved_level, 2) + 32), 50)

func _pokemon_exp_floor_div(numerator: int, denominator: int) -> int:
	if denominator == 0:
		return 0
	return int(floor(float(numerator) / float(denominator)))

func _on_bag_item_use_pokemon_selected(slot_index: int) -> void:
	if bag_item_use_in_progress:
		return
	if slot_index < 0 or slot_index >= PlayerSave.party.size():
		return

	var pokemon: Pokemon = PlayerSave.party[slot_index]
	if pokemon == null or pokemon.owned_pokemon_id <= 0:
		_set_bag_item_use_status("This Pokemon is missing an ownership id.", true)
		return

	var item_id := _normalize_item_id(str(bag_item_use_pending_item.get("id", "")))
	if not _is_pokemon_usable_item_id(item_id):
		_set_bag_item_use_status("This item cannot be used on Pokemon yet.", true)
		return
	if not _bag_item_can_affect_pokemon(pokemon, item_id):
		var preview := _bag_item_use_preview_for_pokemon(pokemon, item_id, 1)
		_set_bag_item_use_status(str(preview.get("label", "This item would have no effect.")), true)
		return

	bag_item_use_selected_slot = slot_index
	bag_item_use_quantity_spinbox.editable = true
	if bag_item_use_confirm_button != null:
		bag_item_use_confirm_button.disabled = false
	_refresh_bag_item_use_selected_preview()
	_refresh_bag_item_use_party_list()

func _refresh_bag_item_use_selected_preview() -> void:
	if bag_item_use_selected_slot < 0 or bag_item_use_selected_slot >= PlayerSave.party.size():
		_set_bag_item_use_status("Select a Pokemon first.", false)
		return

	var pokemon: Pokemon = PlayerSave.party[bag_item_use_selected_slot]
	if pokemon == null:
		_set_bag_item_use_status("Select a Pokemon first.", false)
		return

	var item_id := _normalize_item_id(str(bag_item_use_pending_item.get("id", "")))
	var quantity: int = clampi(int(bag_item_use_quantity_spinbox.value), 1, int(bag_item_use_quantity_spinbox.max_value))
	var preview := _bag_item_use_preview_for_pokemon(pokemon, item_id, quantity)
	var preview_text := str(preview.get("label", ""))
	if preview_text == "":
		preview_text = "No item change"
	_set_bag_item_use_status("%s selected. %s" % [pokemon.species, preview_text], false)

func _on_bag_item_use_confirm_pressed() -> void:
	if bag_item_use_in_progress:
		return
	if bag_item_use_selected_slot < 0 or bag_item_use_selected_slot >= PlayerSave.party.size():
		_set_bag_item_use_status("Select a Pokemon first.", true)
		return

	var pokemon: Pokemon = PlayerSave.party[bag_item_use_selected_slot]
	if pokemon == null or pokemon.owned_pokemon_id <= 0:
		_set_bag_item_use_status("This Pokemon is missing an ownership id.", true)
		return

	var item_id := _normalize_item_id(str(bag_item_use_pending_item.get("id", "")))
	var quantity: int = clampi(int(bag_item_use_quantity_spinbox.value), 1, int(bag_item_use_quantity_spinbox.max_value))
	if not _is_pokemon_usable_item_id(item_id):
		_set_bag_item_use_status("This item cannot be used on Pokemon yet.", true)
		return
	if not _bag_item_can_affect_pokemon(pokemon, item_id):
		var preview := _bag_item_use_preview_for_pokemon(pokemon, item_id, quantity)
		_set_bag_item_use_status(str(preview.get("label", "This item would have no effect.")), true)
		return

	bag_item_use_in_progress = true
	bag_item_use_quantity_spinbox.editable = false
	if bag_item_use_confirm_button != null:
		bag_item_use_confirm_button.disabled = true
	_set_bag_item_use_status("Using item...", false)
	_refresh_bag_item_use_party_list()

	var result: Dictionary = await InventoryService.use_pokemon_item(pokemon.owned_pokemon_id, item_id, quantity)
	bag_item_use_in_progress = false
	bag_item_use_quantity_spinbox.editable = true
	if bag_item_use_confirm_button != null:
		bag_item_use_confirm_button.disabled = false
	if not bool(result.get("success", false)):
		_set_bag_item_use_status("Could not use item: %s" % str(result.get("error", "Unknown error")), true)
		_refresh_bag_item_use_party_list()
		return

	PlayerWalletService.apply_wallet_result(result)
	var inventory_value: Variant = result.get("inventory", [])
	if inventory_value is Array:
		bag_inventory_items = _normalize_bag_inventory_items(inventory_value)
		bag_inventory_loaded = true
	_refresh_bag_items()
	_refresh_open_pokemon_summary_cards()
	_refresh_player_status_card()
	var reward: Dictionary = _staff_dictionary_from_variant(result.get("reward", {}))
	_add_bag_item_use_success_message(item_id, reward)
	_notify_progression_reward(reward)
	_hide_bag_item_use_popup()

func _set_bag_item_use_status(message: String, is_error: bool) -> void:
	if bag_item_use_status_label == null:
		return
	bag_item_use_status_label.text = message
	bag_item_use_status_label.add_theme_color_override("font_color", UI_DANGER if is_error else UI_MUTED_TEXT)

func _add_bag_item_use_success_message(item_id: String, reward: Dictionary) -> void:
	var item_name := str(bag_item_use_pending_item.get("name", _item_name_from_id(item_id)))
	var quantity: int = 1
	var effort_value: Variant = reward.get("effort", [])
	if effort_value is Array:
		var effort_array: Array = effort_value as Array
		if not effort_array.is_empty() and effort_array[0] is Dictionary:
			var effort_entry: Dictionary = effort_array[0]
			quantity = max(int(effort_entry.get("quantity", quantity)), 1)
			var stat_id := str(effort_entry.get("stat", "")).strip_edges()
			var ev_changes: Dictionary = _staff_dictionary_from_variant(effort_entry.get("storedEvChanges", effort_entry.get("evChanges", {})))
			var gained_evs: int = max(int(ev_changes.get(stat_id, 0)), 0)
			var suffix: String = " %s stored +%s %s EVs." % [
				str(effort_entry.get("species", "Pokemon")),
				gained_evs,
				_summary_stat_label(stat_id),
			] if gained_evs > 0 else ""
			_add_chat_message("Used %sx %s.%s" % [quantity, item_name, suffix])
			return

	var experience_gained: int = 0
	var experience_value: Variant = reward.get("experience", [])
	if experience_value is Array:
		var experience_array: Array = experience_value as Array
		if experience_array.is_empty() or not (experience_array[0] is Dictionary):
			_add_chat_message("Used %sx %s." % [quantity, item_name])
			return
		var experience_entry: Dictionary = experience_array[0]
		quantity = max(int(experience_entry.get("quantity", quantity)), 1)
		experience_gained = max(int(experience_entry.get("experience", 0)), 0)
	var suffix: String = " Gained %s EXP." % experience_gained if experience_gained > 0 else ""
	_add_chat_message("Used %sx %s.%s" % [quantity, item_name, suffix])

func _notify_progression_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var world := GameState.get_world()
	if world != null and world.has_method("notify_progression_reward"):
		world.call("notify_progression_reward", reward)
		return

	queue_reward_move_learn_candidates(reward)

func _is_exp_item_id(item_id: String) -> bool:
	return EXP_ITEM_IDS.has(_normalize_item_id(item_id))

func _is_ev_item_id(item_id: String) -> bool:
	return EV_ITEM_EFFECTS.has(_normalize_item_id(item_id))

func _is_pokemon_usable_item_id(item_id: String) -> bool:
	return _is_exp_item_id(item_id) or _is_ev_item_id(item_id)

func _load_item_icon(item_id: String) -> Texture2D:
	var normalized := item_id.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	var candidates: Array[String] = [
		BAG_ICON_ROOT + normalized + ".png",
		BAG_ICON_ROOT + item_id.strip_edges() + ".png",
		BAG_ICON_ROOT + "000.png",
	]
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _ellipsize_text(value: String, max_length: int) -> String:
	if value.length() <= max_length:
		return value
	return value.substr(0, max(max_length - 3, 1)) + "..."

func _on_bag_button_pressed() -> void:
	_toggle_bag_popup()

func _toggle_bag_popup() -> void:
	if bag_popup == null:
		return
	bag_popup.visible = not bag_popup.visible
	if bag_popup.visible:
		_activate_ui_panel(bag_popup)
		_load_bag_inventory()
		if bag_button.has_focus():
			bag_button.release_focus()
	else:
		_hide_bag_popup()
		_deactivate_ui_panel(bag_popup)

func _load_bag_inventory() -> void:
	if bag_inventory_loading:
		return

	bag_inventory_loading = true
	_refresh_bag_items()

	var inventory_result: Dictionary = await InventoryService.load_inventory()
	bag_inventory_loading = false
	if bool(inventory_result.get("success", false)):
		bag_inventory_items = _normalize_bag_inventory_items(inventory_result.get("items", []))
		bag_inventory_loaded = true
	else:
		bag_inventory_items = []
		bag_inventory_loaded = true
		push_warning("Bag inventory failed to load: %s" % str(inventory_result.get("error", "Unknown error")))
	_refresh_bag_items()

func _normalize_bag_inventory_items(items_value: Variant) -> Array[Dictionary]:
	var normalized_items: Array[Dictionary] = []
	if typeof(items_value) != TYPE_ARRAY:
		return normalized_items

	var items: Array = items_value
	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("itemId", item.get("id", ""))).strip_edges()
		if item_id == "":
			continue
		var backend_category := str(item.get("category", "")).strip_edges()
		normalized_items.append({
			"id": item_id,
			"name": str(item.get("name", _item_name_from_id(item_id))),
			"category": _normalize_backend_bag_category(backend_category, item_id),
			"isHoldable": bool(item.get("isHoldable", false)),
			"quantity": max(int(item.get("quantity", 1)), 1),
		})
	return normalized_items

func _normalize_backend_bag_category(category: String, item_id: String) -> String:
	var normalized := category.strip_edges().to_lower().replace("-", "_")
	match normalized:
		"held_items", "berries":
			return "held_items"
		"poke_balls", "pokeballs":
			return "pokeball"
		"medicine", "machines", "power_stones", "cosmetics", "currency":
			return normalized

	return _guess_bag_category(item_id)

func _item_name_from_id(item_id: String) -> String:
	var words := item_id.replace("_", "-").split("-")
	var formatted_words: Array[String] = []
	for word: String in words:
		if word == "":
			continue
		formatted_words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(formatted_words)

func _normalize_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")

func _guess_bag_category(item_id: String) -> String:
	var normalized := item_id.strip_edges().to_lower()
	if normalized.ends_with("ball") or normalized.contains("-ball"):
		return "pokeball"
	if normalized.contains("potion") or normalized.contains("heal") or normalized.contains("revive") or normalized.contains("medicine"):
		return "medicine"
	if normalized.begins_with("tm") or normalized.begins_with("hm"):
		return "machines"
	if normalized.ends_with("berry"):
		return "held_items"
	if normalized.ends_with("ite") or normalized.contains("ite-") or normalized.ends_with("-z") or normalized.ends_with("ium-z"):
		return "power_stones"
	if normalized.contains("leftovers") or normalized.contains("choice-") or normalized.contains("scarf") or normalized.contains("band") or normalized.contains("orb") or normalized.contains("vest"):
		return "held_items"
	if normalized.contains("skin") or normalized.contains("outfit") or normalized.contains("cosmetic") or normalized.contains("mount") or normalized.contains("ride"):
		return "cosmetics"
	if normalized.contains("coin") or normalized.contains("token") or normalized.contains("currency"):
		return "currency"
	return "general"

func _hide_bag_popup() -> void:
	if bag_popup != null:
		bag_popup.visible = false
	if bag_item_use_popup != null and bag_item_use_popup.visible and not bag_item_use_in_progress:
		bag_item_use_popup.visible = false
		bag_item_use_pending_item = {}
	if bag_button.has_focus():
		bag_button.release_focus()

func _on_bag_category_selected(category_id: String) -> void:
	active_bag_category = category_id
	_refresh_bag_category_buttons()
	_refresh_bag_items()

func _on_bag_search_changed(_new_text: String) -> void:
	_refresh_bag_items()

func _refresh_bag_category_buttons() -> void:
	for category_id_value: Variant in bag_category_buttons.keys():
		var category_id := str(category_id_value)
		var category_button: Button = bag_category_buttons.get(category_id) as Button
		if category_button == null:
			continue
		_apply_button_style(category_button, "primary" if category_id == active_bag_category else "default")

func _on_bag_header_gui_input(event: InputEvent) -> void:
	if bag_popup == null:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		bag_dragging = true
		bag_drag_offset = mouse_event.global_position - bag_popup.global_position
		_activate_ui_panel(bag_popup)
	else:
		bag_dragging = false
	get_viewport().set_input_as_handled()

func _handle_bag_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			bag_dragging = false
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_bag_to_global_position(motion_event.global_position - bag_drag_offset)
	get_viewport().set_input_as_handled()

func _move_bag_to_global_position(global_top_left: Vector2) -> void:
	if bag_popup == null:
		return

	var parent_control: Control = bag_popup.get_parent_control()
	if parent_control == null:
		return

	var parent_size: Vector2 = parent_control.size
	var popup_size: Vector2 = bag_popup.size
	var clamped_position := Vector2(
		clamp(global_top_left.x, 0.0, max(parent_size.x - popup_size.x, 0.0)),
		clamp(global_top_left.y, 0.0, max(parent_size.y - popup_size.y, 0.0))
	)
	var anchor_offset := Vector2(
		parent_size.x * bag_popup.anchor_left,
		parent_size.y * bag_popup.anchor_top
	)
	var local_offset := clamped_position - anchor_offset
	bag_popup.offset_left = local_offset.x
	bag_popup.offset_top = local_offset.y
	bag_popup.offset_right = local_offset.x + popup_size.x
	bag_popup.offset_bottom = local_offset.y + popup_size.y

func _get_pokemon_summary_card_key(pokemon: Pokemon, slot_index: int = -1, mode: String = "interactive") -> String:
	if pokemon == null:
		return "%s:slot:%s" % [mode, slot_index]
	if pokemon.owned_pokemon_id > 0:
		return "%s:owned:%s" % [mode, pokemon.owned_pokemon_id]
	var instance_id: String = pokemon.instance_id.strip_edges()
	if instance_id != "":
		return "%s:instance:%s" % [mode, instance_id]
	if slot_index >= 0:
		return "%s:slot:%s" % [mode, slot_index]
	return "%s:preview:%s:%s:%s" % [mode, pokemon.species, pokemon.level, str(pokemon.moves).hash()]

func _find_party_slot_for_summary_key(card_key: String) -> int:
	if not card_key.begins_with("interactive:"):
		return -1
	for slot_index in range(PlayerSave.party.size()):
		var pokemon: Pokemon = PlayerSave.party[slot_index]
		if _get_pokemon_summary_card_key(pokemon, slot_index, "interactive") == card_key:
			return slot_index
	return -1

func _capture_pokemon_summary_card_context(card_key: String, pokemon: Pokemon, mode: String, slot_index: int) -> Dictionary:
	return {
		"key": card_key,
		"popup": pokemon_summary_popup,
		"left_panel": pokemon_summary_left_panel,
		"right_area": pokemon_summary_right_area,
		"content_panel": pokemon_summary_content_panel,
		"tab_column": pokemon_summary_tab_column,
		"sprite": pokemon_summary_sprite,
		"sprite_viewport": pokemon_summary_sprite_viewport,
		"animated_sprite": pokemon_summary_animated_sprite,
		"level_badge_panel": pokemon_summary_level_badge_panel,
		"level_badge_label": pokemon_summary_level_badge_label,
		"ball_button": pokemon_summary_ball_button,
		"ball_icon": pokemon_summary_ball_icon,
		"ball_picker": pokemon_summary_ball_picker,
		"ball_search_input": pokemon_summary_ball_search_input,
		"ball_list": pokemon_summary_ball_list,
		"type_icon_row": pokemon_summary_type_icon_row,
		"title_label": pokemon_summary_title_label,
		"id_label": pokemon_summary_id_label,
		"meta_label": pokemon_summary_meta_label,
		"held_item_slot": pokemon_summary_held_item_slot,
		"held_item_slot_button": pokemon_summary_held_item_slot_button,
		"held_item_slot_icon": pokemon_summary_held_item_slot_icon,
		"held_item_slot_name_label": pokemon_summary_held_item_slot_name_label,
		"hp_bar": pokemon_summary_hp_bar,
		"hp_label": pokemon_summary_hp_label,
		"content_stack": pokemon_summary_content_stack,
		"tab_buttons": pokemon_summary_tab_buttons.duplicate(),
		"shiny_badge": pokemon_summary_shiny_badge,
		"shiny_badge_label": pokemon_summary_shiny_badge_label,
		"trainer_label": pokemon_summary_trainer_label,
		"stats_list": pokemon_summary_stats_list,
		"moves_list": pokemon_summary_moves_list,
		"item_picker": pokemon_summary_item_picker,
		"item_search_input": pokemon_summary_item_search_input,
		"item_list": pokemon_summary_item_list,
		"preview_pokemon": pokemon if mode == "readonly" else null,
		"mode": mode,
		"selected_slot": slot_index,
		"active_tab": "general",
		"sprite_side": "front",
		"dragging": false,
		"drag_offset": Vector2.ZERO,
	}

func _apply_pokemon_summary_card_context(card_key: String) -> bool:
	if card_key == "":
		return pokemon_summary_popup != null
	var context: Dictionary = pokemon_summary_open_cards.get(card_key, {})
	if context.is_empty():
		return false
	pokemon_summary_active_card_key = card_key
	pokemon_summary_popup = context.get("popup") as PanelContainer
	pokemon_summary_left_panel = context.get("left_panel") as PanelContainer
	pokemon_summary_right_area = context.get("right_area") as VBoxContainer
	pokemon_summary_content_panel = context.get("content_panel") as PanelContainer
	pokemon_summary_tab_column = context.get("tab_column") as HBoxContainer
	pokemon_summary_sprite = context.get("sprite") as TextureRect
	pokemon_summary_sprite_viewport = context.get("sprite_viewport") as SubViewport
	pokemon_summary_animated_sprite = context.get("animated_sprite") as AnimatedSprite2D
	pokemon_summary_level_badge_panel = context.get("level_badge_panel") as PanelContainer
	pokemon_summary_level_badge_label = context.get("level_badge_label") as Label
	pokemon_summary_ball_button = context.get("ball_button") as Button
	pokemon_summary_ball_icon = context.get("ball_icon") as TextureRect
	pokemon_summary_ball_picker = context.get("ball_picker") as PanelContainer
	pokemon_summary_ball_search_input = context.get("ball_search_input") as LineEdit
	pokemon_summary_ball_list = context.get("ball_list") as VBoxContainer
	pokemon_summary_type_icon_row = context.get("type_icon_row") as HBoxContainer
	pokemon_summary_title_label = context.get("title_label") as Label
	pokemon_summary_id_label = context.get("id_label") as Label
	pokemon_summary_meta_label = context.get("meta_label") as Label
	pokemon_summary_held_item_slot = context.get("held_item_slot") as PanelContainer
	pokemon_summary_held_item_slot_button = context.get("held_item_slot_button") as Button
	pokemon_summary_held_item_slot_icon = context.get("held_item_slot_icon") as TextureRect
	pokemon_summary_held_item_slot_name_label = context.get("held_item_slot_name_label") as Label
	pokemon_summary_hp_bar = context.get("hp_bar") as ProgressBar
	pokemon_summary_hp_label = context.get("hp_label") as Label
	pokemon_summary_content_stack = context.get("content_stack") as VBoxContainer
	pokemon_summary_tab_buttons = (context.get("tab_buttons", {}) as Dictionary).duplicate()
	pokemon_summary_shiny_badge = context.get("shiny_badge") as PanelContainer
	pokemon_summary_shiny_badge_label = context.get("shiny_badge_label") as Label
	pokemon_summary_trainer_label = context.get("trainer_label") as Label
	pokemon_summary_stats_list = context.get("stats_list") as VBoxContainer
	pokemon_summary_moves_list = context.get("moves_list") as VBoxContainer
	pokemon_summary_item_picker = context.get("item_picker") as PanelContainer
	pokemon_summary_item_search_input = context.get("item_search_input") as LineEdit
	pokemon_summary_item_list = context.get("item_list") as VBoxContainer
	pokemon_summary_preview_pokemon = context.get("preview_pokemon") as Pokemon
	pokemon_summary_mode = str(context.get("mode", "interactive"))
	pokemon_summary_selected_slot = int(context.get("selected_slot", -1))
	pokemon_summary_active_tab = str(context.get("active_tab", "general"))
	pokemon_summary_sprite_side = str(context.get("sprite_side", "front"))
	pokemon_summary_dragging = bool(context.get("dragging", false))
	pokemon_summary_drag_offset = context.get("drag_offset", Vector2.ZERO) as Vector2
	return pokemon_summary_popup != null

func _store_active_pokemon_summary_card_context() -> void:
	if pokemon_summary_active_card_key == "":
		return
	var context: Dictionary = pokemon_summary_open_cards.get(pokemon_summary_active_card_key, {})
	if context.is_empty():
		return
	context["active_tab"] = pokemon_summary_active_tab
	context["selected_slot"] = pokemon_summary_selected_slot
	context["preview_pokemon"] = pokemon_summary_preview_pokemon
	context["mode"] = pokemon_summary_mode
	context["sprite_side"] = pokemon_summary_sprite_side
	context["dragging"] = pokemon_summary_dragging
	context["drag_offset"] = pokemon_summary_drag_offset
	pokemon_summary_open_cards[pokemon_summary_active_card_key] = context

func _focus_pokemon_summary_card(card_key: String) -> void:
	if not _apply_pokemon_summary_card_context(card_key):
		return
	_store_active_pokemon_summary_card_context()
	if pokemon_summary_popup != null:
		pokemon_summary_popup.visible = true
		_activate_ui_panel(pokemon_summary_popup)

func _position_new_pokemon_summary_card() -> void:
	if pokemon_summary_popup == null:
		return
	var parent_control: Control = pokemon_summary_popup.get_parent_control()
	if parent_control == null:
		return
	var parent_size: Vector2 = parent_control.size
	var card_size: Vector2 = POKEMON_SUMMARY_SIZE
	var base_position: Vector2 = (parent_size - card_size) * 0.5
	var offset_step := Vector2(28, 24)
	var offset_index: int = pokemon_summary_next_card_offset_index % 8
	pokemon_summary_next_card_offset_index += 1
	_move_pokemon_summary_to_global_position(base_position + (offset_step * float(offset_index)))

func _refresh_open_pokemon_summary_cards() -> void:
	var keys: Array = pokemon_summary_open_cards.keys()
	for key_value: Variant in keys:
		var card_key: String = str(key_value)
		if not _apply_pokemon_summary_card_context(card_key):
			continue
		if pokemon_summary_popup == null or not pokemon_summary_popup.visible:
			continue
		_refresh_pokemon_summary()
	_store_active_pokemon_summary_card_context()

func _show_pokemon_summary(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= PlayerSave.party.size():
		return

	var pokemon: Pokemon = PlayerSave.party[slot_index]
	var card_key: String = _get_pokemon_summary_card_key(pokemon, slot_index, "interactive")
	if pokemon_summary_open_cards.has(card_key):
		_focus_pokemon_summary_card(card_key)
		return

	_setup_pokemon_summary_popup(card_key)
	pokemon_summary_preview_pokemon = null
	pokemon_summary_mode = "interactive"
	pokemon_summary_selected_slot = slot_index
	pokemon_summary_sprite_side = "front"
	pokemon_summary_item_picker.visible = false
	pokemon_summary_ball_picker.visible = false
	pokemon_summary_active_tab = "general"
	pokemon_summary_active_card_key = card_key
	pokemon_summary_open_cards[card_key] = _capture_pokemon_summary_card_context(card_key, pokemon, "interactive", slot_index)
	_position_new_pokemon_summary_card()
	_set_pokemon_summary_popup_size()
	_refresh_pokemon_summary()
	pokemon_summary_popup.visible = true
	_activate_ui_panel(pokemon_summary_popup)

func _hide_pokemon_summary_popup(card_key: String = "") -> void:
	if card_key != "":
		_apply_pokemon_summary_card_context(card_key)
	if pokemon_summary_popup != null:
		pokemon_summary_popup.visible = false
		_deactivate_ui_panel(pokemon_summary_popup)
		pokemon_summary_popup.queue_free()
	if card_key == "":
		card_key = pokemon_summary_active_card_key
	if card_key != "":
		pokemon_summary_open_cards.erase(card_key)
		if pokemon_summary_active_card_key == card_key:
			pokemon_summary_active_card_key = ""
		if pokemon_summary_dragging_card_key == card_key:
			pokemon_summary_dragging_card_key = ""
	_hide_pokemon_summary_ev_allocate_popup()
	pokemon_summary_preview_pokemon = null
	pokemon_summary_mode = "interactive"
	pokemon_summary_selected_slot = -1
	pokemon_summary_dragging = false

func _refresh_pokemon_summary() -> void:
	var pokemon: Pokemon = pokemon_summary_preview_pokemon
	if pokemon == null:
		var resolved_slot: int = _find_party_slot_for_summary_key(pokemon_summary_active_card_key)
		if resolved_slot >= 0:
			pokemon_summary_selected_slot = resolved_slot
		if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
			_hide_pokemon_summary_popup(pokemon_summary_active_card_key)
			return
		pokemon = PlayerSave.party[pokemon_summary_selected_slot]
	if pokemon == null:
		_hide_pokemon_summary_popup(pokemon_summary_active_card_key)
		return

	_set_pokemon_summary_popup_size()
	pokemon_summary_title_label.text = pokemon.species
	pokemon_summary_title_label.tooltip_text = pokemon.species
	var summary_id: String = str(pokemon.owned_pokemon_id) if pokemon.owned_pokemon_id > 0 else ""
	if summary_id == "":
		summary_id = pokemon.instance_id.strip_edges()
	pokemon_summary_id_label.text = "ID: %s" % summary_id if summary_id != "" else "ID: -"
	pokemon_summary_id_label.tooltip_text = pokemon_summary_id_label.text
	pokemon_summary_shiny_badge.visible = pokemon.shiny
	if pokemon_summary_shiny_badge_label != null:
		pokemon_summary_shiny_badge_label.text = "*"
	pokemon_summary_trainer_label.text = _get_pokemon_summary_current_trainer_title_text(pokemon)
	var level_text := "Lv %s" % str(max(pokemon.level, 1))
	pokemon_summary_meta_label.text = level_text
	if pokemon_summary_level_badge_label != null:
		pokemon_summary_level_badge_label.text = level_text
		pokemon_summary_level_badge_label.tooltip_text = level_text
	if pokemon_summary_level_badge_panel != null:
		pokemon_summary_level_badge_panel.tooltip_text = level_text
	pokemon_summary_trainer_label.tooltip_text = pokemon_summary_trainer_label.text
	pokemon_summary_meta_label.tooltip_text = pokemon_summary_meta_label.text
	_set_pokemon_summary_sprite(pokemon)
	_refresh_pokemon_summary_type_icons(pokemon)
	_set_pokemon_summary_ball_button(pokemon)

	_set_pokemon_summary_held_item_slot(pokemon)
	if _is_pokemon_summary_readonly():
		_hide_pokemon_summary_ev_allocate_popup()
		pokemon_summary_item_picker.visible = false
		pokemon_summary_ball_picker.visible = false
	pokemon_summary_hp_bar.max_value = max(pokemon.max_hp, 1)
	pokemon_summary_hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	pokemon_summary_hp_label.text = "HP %s / %s" % [max(pokemon.current_hp, 0), max(pokemon.max_hp, 1)]
	_refresh_pokemon_summary_tab_buttons()
	_render_pokemon_summary_content(pokemon)
	_store_active_pokemon_summary_card_context()
	call_deferred("_set_pokemon_summary_popup_size_for_card", pokemon_summary_active_card_key)

func _set_pokemon_summary_popup_size_for_card(card_key: String) -> void:
	if card_key != "":
		_apply_pokemon_summary_card_context(card_key)
	_set_pokemon_summary_popup_size()

func _get_active_pokemon_summary_pokemon() -> Pokemon:
	if pokemon_summary_preview_pokemon != null:
		return pokemon_summary_preview_pokemon
	var resolved_slot: int = _find_party_slot_for_summary_key(pokemon_summary_active_card_key)
	if resolved_slot >= 0:
		pokemon_summary_selected_slot = resolved_slot
	if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
		return null
	return PlayerSave.party[pokemon_summary_selected_slot]

func _on_pokemon_summary_sprite_frame_gui_input(event: InputEvent, card_key: String = "") -> void:
	if not _apply_pokemon_summary_card_context(card_key):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		pokemon_summary_sprite_side = "back" if _get_pokemon_summary_sprite_side() == "front" else "front"
		_store_active_pokemon_summary_card_context()
		var pokemon: Pokemon = _get_active_pokemon_summary_pokemon()
		if pokemon != null:
			_set_pokemon_summary_sprite(pokemon)

func _make_label_clip_width(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2.ZERO

func _set_pokemon_summary_sprite(pokemon: Pokemon) -> void:
	if pokemon_summary_animated_sprite == null:
		return

	var sprite_side: String = _get_pokemon_summary_sprite_side()
	var loaded_frames: Variant = pokemon_summary_sprite_loader.call(
		"_load_sprite_frames",
		pokemon.species,
		sprite_side,
		pokemon.shiny
	)
	var frames: SpriteFrames = loaded_frames as SpriteFrames
	if frames != null:
		pokemon_summary_sprite.visible = false
		pokemon_summary_animated_sprite.visible = true
		pokemon_summary_animated_sprite.sprite_frames = frames
		var animation_names: PackedStringArray = frames.get_animation_names()
		if frames.has_animation("idle"):
			pokemon_summary_animated_sprite.animation = "idle"
		elif not animation_names.is_empty():
			pokemon_summary_animated_sprite.animation = animation_names[0]
		pokemon_summary_animated_sprite.frame = 0
		pokemon_summary_animated_sprite.position = _get_pokemon_summary_sprite_position()
		pokemon_summary_animated_sprite.scale = _get_pokemon_summary_sprite_scale(frames)
		_apply_pokemon_summary_sprite_center_offset(frames, pokemon_summary_animated_sprite.animation)
		pokemon_summary_animated_sprite.play()
		return

	pokemon_summary_animated_sprite.stop()
	pokemon_summary_animated_sprite.visible = false
	pokemon_summary_sprite.visible = true
	pokemon_summary_sprite.texture = PokemonAssets.load_home_sprite(pokemon.species, pokemon.shiny)
	if pokemon_summary_sprite.texture == null:
		pokemon_summary_sprite.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)

func _get_pokemon_summary_sprite_side() -> String:
	return "back" if pokemon_summary_sprite_side == "back" else "front"

func _refresh_pokemon_summary_type_icons(pokemon: Pokemon) -> void:
	if pokemon_summary_type_icon_row == null:
		return

	for child: Node in pokemon_summary_type_icon_row.get_children():
		child.queue_free()

	var added_count: int = 0
	for type_value: String in _string_array_from_value(pokemon.types):
		var type_label: Texture2D = _load_pokemon_type_text_label(type_value)
		if type_label == null:
			continue

		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(76, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = type_label
		icon.tooltip_text = type_value.capitalize()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pokemon_summary_type_icon_row.add_child(icon)
		added_count += 1
		if added_count >= 2:
			break

func _load_pokemon_type_icon(type_name: String) -> Texture2D:
	var normalized_type: String = type_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	if normalized_type == "":
		return null

	var path: String = "%s%s.png" % [POKEMON_TYPE_ICON_ROOT, normalized_type]
	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D

func _load_pokemon_type_text_label(type_name: String) -> Texture2D:
	var normalized_type: String = type_name.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	if normalized_type == "":
		return null

	var path: String = "%s%s.png" % [MOVE_LEARN_TYPE_LABEL_ROOT, normalized_type]
	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D

func _get_pokemon_summary_sprite_position() -> Vector2:
	return Vector2(
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.x) * 0.5,
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.y) * 0.52
	)

func _get_pokemon_summary_sprite_scale(frames: SpriteFrames) -> Vector2:
	var render_scale := 1.0
	if pokemon_summary_sprite_loader.has_method("_get_sprite_frames_render_scale"):
		var render_scale_value: Variant = pokemon_summary_sprite_loader.call("_get_sprite_frames_render_scale", frames)
		render_scale = float(render_scale_value)

	var display_scale_multiplier := 1.0
	if pokemon_summary_sprite_loader.has_method("_get_sprite_frames_display_scale_multiplier"):
		var display_scale_value: Variant = pokemon_summary_sprite_loader.call("_get_sprite_frames_display_scale_multiplier", frames)
		display_scale_multiplier = float(display_scale_value)

	var visual_rect: Rect2 = _get_pokemon_summary_sprite_visual_rect(frames, "idle")
	if visual_rect.size == Vector2.ZERO and pokemon_summary_animated_sprite != null:
		visual_rect = _get_pokemon_summary_sprite_visual_rect(frames, pokemon_summary_animated_sprite.animation)
	var normalized_frame_size: Vector2 = visual_rect.size / max(render_scale, 1.0)
	if normalized_frame_size == Vector2.ZERO:
		normalized_frame_size = _get_pokemon_summary_sprite_frame_size(frames) / max(render_scale, 1.0)
	var fit_scale: float = min(
		POKEMON_SUMMARY_SPRITE_MAX_SIZE.x / max(normalized_frame_size.x, 1.0),
		POKEMON_SUMMARY_SPRITE_MAX_SIZE.y / max(normalized_frame_size.y, 1.0)
	)
	var scale_value: float = clamp(fit_scale * display_scale_multiplier, POKEMON_SUMMARY_SPRITE_MIN_SCALE, POKEMON_SUMMARY_SPRITE_MAX_SCALE)
	var texture_scale: float = scale_value / max(render_scale, 1.0)
	return Vector2(texture_scale, texture_scale)

func _get_pokemon_summary_sprite_frame_size(frames: SpriteFrames) -> Vector2:
	if pokemon_summary_sprite_loader.has_method("_get_sprite_frames_frame_size"):
		var frame_size_value: Variant = pokemon_summary_sprite_loader.call("_get_sprite_frames_frame_size", frames)
		if frame_size_value is Vector2:
			return frame_size_value as Vector2
		if frame_size_value is Vector2i:
			return Vector2(frame_size_value as Vector2i)

	if frames != null and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		var texture: Texture2D = frames.get_frame_texture("idle", 0)
		if texture != null:
			return texture.get_size()

	return Vector2(48, 57)

func _apply_pokemon_summary_sprite_center_offset(frames: SpriteFrames, animation_name: String) -> void:
	var frame_size: Vector2 = _get_pokemon_summary_sprite_frame_size(frames)
	var visual_rect: Rect2 = _get_pokemon_summary_sprite_visual_rect(frames, animation_name)
	if visual_rect.size == Vector2.ZERO:
		pokemon_summary_animated_sprite.centered = true
		pokemon_summary_animated_sprite.offset = Vector2.ZERO
		return

	pokemon_summary_animated_sprite.centered = true
	pokemon_summary_animated_sprite.offset = (frame_size * 0.5) - visual_rect.get_center()

func _get_pokemon_summary_sprite_visual_rect(frames: SpriteFrames, animation_name: String) -> Rect2:
	if frames == null or animation_name == "" or not frames.has_animation(animation_name):
		return Rect2()

	var has_rect: bool = false
	var combined_rect: Rect2 = Rect2()
	for frame_index in range(frames.get_frame_count(animation_name)):
		var texture: Texture2D = frames.get_frame_texture(animation_name, frame_index)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		var used_rect_i: Rect2i = image.get_used_rect()
		if used_rect_i.size == Vector2i.ZERO:
			continue
		var used_rect: Rect2 = Rect2(Vector2(used_rect_i.position), Vector2(used_rect_i.size))
		if not has_rect:
			combined_rect = used_rect
			has_rect = true
		else:
			combined_rect = combined_rect.merge(used_rect)

	return combined_rect if has_rect else Rect2()

func _render_pokemon_summary_content(pokemon: Pokemon) -> void:
	for child: Node in pokemon_summary_content_stack.get_children():
		child.queue_free()

	match pokemon_summary_active_tab:
		"ivs":
			_render_pokemon_summary_ivs(pokemon)
		"evs":
			_render_pokemon_summary_evs(pokemon)
		"moves":
			_render_pokemon_summary_moves_tab(pokemon)
		_:
			_render_pokemon_summary_general(pokemon)

func _render_pokemon_summary_general(pokemon: Pokemon) -> void:
	var top_metrics := HBoxContainer.new()
	top_metrics.add_theme_constant_override("separation", 8)
	top_metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_child(top_metrics)
	top_metrics.add_child(_create_summary_experience_metric_card(pokemon, Color("#62d7ff"), 148.0))
	top_metrics.add_child(_create_summary_metric_card("Happiness", "Happiness progress is not tracked yet.", 0, 255, Color("#f2cf78"), 148.0))

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 8)
	info_grid.add_theme_constant_override("v_separation", 7)
	info_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_child(info_grid)
	info_grid.add_child(_create_summary_field_card("Original Trainer", _get_pokemon_summary_original_trainer_text(pokemon), Color("#9eb7d8"), false, 148.0))
	info_grid.add_child(_create_summary_field_card(
		"Ability",
		_get_summary_ability_display_name(pokemon.ability),
		Color("#ffb15f"),
		false,
		148.0,
		Color(0, 0, 0, 0),
		Color(0, 0, 0, 0),
		_get_summary_ability_description_text(pokemon.ability)
	))
	info_grid.add_child(_create_summary_field_card("Nature", _default_text(pokemon.nature), Color("#f2cf78"), false, 148.0))
	info_grid.add_child(_create_summary_field_card("Location", _get_pokemon_summary_location_text(pokemon), Color("#62d7ff"), false, 148.0))
	info_grid.add_child(_create_summary_field_card("Caught Date", _get_pokemon_summary_caught_date_text(pokemon), Color("#d9ecff"), false, 148.0))
	info_grid.add_child(_create_summary_field_card("Caught Level", _get_pokemon_summary_caught_level_text(pokemon), Color("#d9ecff"), false, 148.0))

	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 7)
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_child(stat_grid)
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(pokemon.stats.get(stat_id, 0))
		var stat_color: Color = stat.get("color", UI_BORDER_FOCUS) as Color
		var value_color := Color(0, 0, 0, 0)
		var border_color := Color(0, 0, 0, 0)
		var nature_role: String = _get_pokemon_summary_nature_stat_role(pokemon.nature, stat_id)
		if nature_role == "boosted":
			stat_color = POKEMON_SUMMARY_NATURE_BOOST_COLOR
			value_color = POKEMON_SUMMARY_NATURE_BOOST_COLOR
			border_color = Color("#375f3b")
		elif nature_role == "lowered":
			stat_color = POKEMON_SUMMARY_NATURE_DROP_COLOR
			value_color = POKEMON_SUMMARY_NATURE_DROP_COLOR
			border_color = Color("#704329")
		stat_grid.add_child(_create_summary_field_card(
			str(stat.get("label", stat_id)),
			str(value),
			stat_color,
			true,
			96.0,
			value_color,
			border_color
		))

func _create_summary_metric_card(
	label_text: String,
	value_text: String,
	value: int,
	max_value: int,
	accent_color: Color,
	min_width: float = 96.0
) -> Control:
	var tooltip_text := value_text.strip_edges()
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(min_width, 30)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	if tooltip_text != "":
		stack.tooltip_text = tooltip_text

	var label := Label.new()
	label.text = label_text.to_upper()
	label.tooltip_text = tooltip_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent_color)
	stack.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = max(max_value, 1)
	bar.value = clamp(value, 0, max(max_value, 1))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.tooltip_text = tooltip_text
	bar.add_theme_stylebox_override("background", _make_panel_style(
		Color("#06080de8"),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.48),
		3,
		1
	))
	bar.add_theme_stylebox_override("fill", _make_panel_style(accent_color, accent_color, 3, 0))
	stack.add_child(bar)
	return stack

func _create_summary_experience_metric_card(pokemon: Pokemon, accent_color: Color, min_width: float = 96.0) -> Control:
	var current_exp: int = max(pokemon.experience, 0)
	var current_level_exp: int = max(pokemon.current_level_exp, 0)
	var next_level_exp: int = max(pokemon.next_level_exp, current_level_exp)
	var is_max_level := pokemon.level >= 100
	var has_next_level_range := next_level_exp > current_level_exp and not is_max_level
	var level_exp_range: int = 1 if is_max_level else next_level_exp - current_level_exp if has_next_level_range else 1
	var earned_level_exp: int = level_exp_range if is_max_level else clampi(current_exp - current_level_exp, 0, level_exp_range)
	var next_level_remaining: int = max(next_level_exp - current_exp, 0) if has_next_level_range else 0
	var target_level: int = min(pokemon.level + 1, 100)
	var value_text := str(current_exp) if current_exp > 0 or has_next_level_range else "-"
	var detail_text := "%s EXP to Lv. %s" % [next_level_remaining, target_level] if has_next_level_range else "Max level"
	var tooltip_text := "Current EXP: %s\n%s" % [value_text, detail_text]

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(min_width, 30)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	stack.tooltip_text = tooltip_text

	var label := Label.new()
	label.text = "EXP"
	label.tooltip_text = tooltip_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent_color)
	stack.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = level_exp_range
	bar.value = earned_level_exp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.tooltip_text = tooltip_text
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#06080de8"), Color("#5f829a"), 3, 1))
	bar.add_theme_stylebox_override("fill", _make_panel_style(accent_color, accent_color, 3, 0))
	stack.add_child(bar)
	return stack

func _create_summary_field_card(
	label_text: String,
	value_text: String,
	accent_color: Color,
	emphasize_value: bool = false,
	min_width: float = 96.0,
	value_color: Color = Color(0, 0, 0, 0),
	border_color: Color = Color(0, 0, 0, 0),
	tooltip_text: String = ""
) -> Control:
	var resolved_tooltip: String = tooltip_text.strip_edges()
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(min_width, 41)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	if resolved_tooltip != "":
		stack.tooltip_text = resolved_tooltip

	var label := Label.new()
	label.text = label_text.to_upper()
	label.tooltip_text = resolved_tooltip if resolved_tooltip != "" else label_text
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent_color)
	stack.add_child(label)

	var value_panel := PanelContainer.new()
	value_panel.custom_minimum_size = Vector2(0, 23)
	value_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if resolved_tooltip != "":
		value_panel.tooltip_text = resolved_tooltip
	var resolved_border_color: Color = border_color if border_color.a > 0.0 else Color("#2d333c")
	value_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#15191fee"), resolved_border_color, 4, 1))
	stack.add_child(value_panel)

	var value_margin := MarginContainer.new()
	value_margin.add_theme_constant_override("margin_left", 6)
	value_margin.add_theme_constant_override("margin_top", 2)
	value_margin.add_theme_constant_override("margin_right", 6)
	value_margin.add_theme_constant_override("margin_bottom", 2)
	value_panel.add_child(value_margin)

	var value := Label.new()
	value.text = _default_text(value_text)
	value.tooltip_text = resolved_tooltip if resolved_tooltip != "" else value.text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_label_clip_width(value)
	value.add_theme_font_size_override("font_size", 13 if emphasize_value else 12)
	var resolved_value_color: Color = value_color if value_color.a > 0.0 else (Color("#f4f7ff") if emphasize_value else Color("#e8f0ff"))
	value.add_theme_color_override("font_color", resolved_value_color)
	value_margin.add_child(value)
	return stack

func _get_pokemon_origin_summary_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var location_name: String = str(origin.get("locationName", pokemon.location)).strip_edges()
	var method: String = str(origin.get("method", "")).strip_edges()
	var met_level: int = int(origin.get("metLevel", 0))
	if location_name == "":
		location_name = pokemon.location.strip_edges()
	if location_name == "":
		location_name = "Unknown Location"

	var parts: Array[String] = [location_name]
	if method != "":
		parts.append(_format_pokemon_origin_method(method))
	if met_level > 0:
		parts.append("Lv %s" % met_level)
	return " - ".join(parts)

func _get_pokemon_summary_location_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var location_name: String = str(origin.get("locationName", pokemon.location)).strip_edges()
	var region_name: String = str(origin.get("regionName", origin.get("region", ""))).strip_edges()
	if location_name == "":
		location_name = pokemon.location.strip_edges()
	if location_name == "":
		location_name = "Unknown Location"
	if region_name != "" and region_name.to_lower() != "unknown" and region_name != location_name:
		return "%s - %s" % [region_name, location_name]
	return location_name

func _get_pokemon_summary_caught_level_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var met_level: int = int(origin.get("metLevel", origin.get("met_level", 0)))
	if met_level <= 0:
		met_level = int(origin.get("level", 0))
	if met_level <= 0:
		met_level = max(pokemon.level, 1)
	var method: String = _get_pokemon_summary_method_text(pokemon)
	return "%s - %s" % [met_level, method] if method != "" else str(met_level)

func _get_pokemon_summary_method_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var method: String = str(origin.get("method", "")).strip_edges()
	return _format_pokemon_origin_method(method) if method != "" else ""

func _get_pokemon_summary_current_trainer_title_text(_pokemon: Pokemon) -> String:
	var origin: Dictionary = _pokemon.origin
	var trainer_name := str(_get_first_dictionary_value(
		origin,
		["currentTrainerName", "current_trainer_name", "ownerName", "owner_name"],
		PlayerSave.player_name
	)).strip_edges()
	if trainer_name == "":
		trainer_name = "Trainer"
	return "%s's Pokemon" % trainer_name

func _get_pokemon_summary_original_trainer_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var trainer_name := str(_get_first_dictionary_value(
		origin,
		["originalTrainerName", "original_trainer_name", "otName", "ot_name"],
		""
	)).strip_edges()
	if trainer_name != "":
		return trainer_name

	var original_trainer_user_id := str(_get_first_dictionary_value(
		origin,
		["originalTrainerUserId", "original_trainer_user_id", "originalOwnerUserId", "original_owner_user_id"],
		""
	)).strip_edges()
	if original_trainer_user_id != "":
		var current_player_id := str(PlayerSave.player_id).strip_edges()
		if current_player_id != "" and original_trainer_user_id == current_player_id:
			return PlayerSave.player_name

		return "Trainer #%s" % original_trainer_user_id

	return "-"

func _get_pokemon_summary_caught_date_text(pokemon: Pokemon) -> String:
	var origin: Dictionary = pokemon.origin
	var raw_date := str(_get_first_dictionary_value(
		origin,
		["caughtAt", "caught_at", "metAt", "met_at", "createdAt", "created_at"],
		""
	)).strip_edges()
	var date_text := "-"
	if raw_date == "":
		return date_text

	var date_part := raw_date.split("T")[0].split(" ")[0]
	var pieces := date_part.split("-")
	if pieces.size() == 3 and pieces[0].length() == 4:
		date_text = "%s/%s/%s" % [pieces[2], pieces[1], pieces[0]]
	else:
		date_text = date_part
	return date_text

func _format_pokemon_origin_method(method: String) -> String:
	match method.strip_edges().to_lower():
		"gift":
			return "Gift"
		"caught":
			return "Caught"
		"generated":
			return "Generated"
		"npc_trade":
			return "NPC Trade"
		"chest":
			return "Chest"
		_:
			return method.capitalize()

func _render_pokemon_summary_ivs(pokemon: Pokemon) -> void:
	_add_summary_section_title("Individual Values", Color("#62d7ff"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_child(grid)
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(pokemon.ivs.get(stat_id, 0))
		grid.add_child(_create_summary_value_orb(str(stat.get("label", stat_id)), value, 31, stat.get("color", UI_BORDER_FOCUS) as Color))

func _render_pokemon_summary_evs(pokemon: Pokemon) -> void:
	var allocated_total: int = _get_summary_ev_total(pokemon.evs)
	_add_summary_section_title("Allocated EVs (%s/510)" % allocated_total, POKEMON_SUMMARY_ACCENT)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.add_child(grid)
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(pokemon.evs.get(stat_id, 0))
		grid.add_child(_create_summary_ev_box(
			stat_id,
			str(stat.get("label", stat_id)),
			value,
			stat.get("color", UI_BORDER_FOCUS) as Color
		))
	_add_summary_section_title("Stored EVs", POKEMON_SUMMARY_ACCENT)
	pokemon_summary_content_stack.add_child(_create_summary_stored_evs_panel(pokemon.evs, pokemon.stored_evs))

func _render_pokemon_summary_moves_tab(pokemon: Pokemon) -> void:
	_add_summary_section_title("Moves", POKEMON_SUMMARY_ACCENT)
	for move_index in range(4):
		var move_value: Variant = {}
		var move_name: String = "-"
		var pp_text: String = "--/--"
		var move_type: String = ""
		if move_index < pokemon.moves.size():
			move_value = pokemon.moves[move_index]
			move_name = _get_summary_move_name(move_value)
			pp_text = _get_summary_move_pp_text(move_value)
			move_type = _get_summary_move_type(move_value)
		pokemon_summary_content_stack.add_child(_create_summary_move_card(
			move_index + 1,
			move_name,
			pp_text,
			move_type,
			_get_summary_move_power_text(move_value),
			_get_summary_move_accuracy_text(move_value),
			_get_summary_move_description_text(move_value)
		))

func _add_summary_section_title(title_text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 22)
	panel.add_theme_stylebox_override("panel", _make_pokemon_summary_section_title_style(color))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	var label := Label.new()
	label.text = title_text.to_upper()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(label)
	pokemon_summary_content_stack.add_child(panel)

func _create_summary_info_row(label_text: String, value_text: String, accent_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_pokemon_summary_row_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label := Label.new()
	label.text = label_text.to_upper()
	label.custom_minimum_size = Vector2(84, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_make_label_clip_width(label)
	label.custom_minimum_size = Vector2(84, 0)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent_color)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.tooltip_text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(value)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(value)
	return panel

func _create_summary_value_orb(label_text: String, value: int, max_value: int, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 50)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color(color.r, color.g, color.b, 0.48), 7, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var label := Label.new()
	label.text = label_text.to_upper()
	label.tooltip_text = label_text
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	stack.add_child(value_row)

	var value_label := Label.new()
	value_label.text = str(clamp(value, 0, max_value))
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	value_row.add_child(value_label)

	var max_label := Label.new()
	max_label.text = "/%s" % max(max_value, 1)
	max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	max_label.add_theme_font_size_override("font_size", 10)
	max_label.add_theme_color_override("font_color", Color("#b8c9e4"))
	value_row.add_child(max_label)

	var bar := ProgressBar.new()
	bar.max_value = max(max_value, 1)
	bar.value = clamp(value, 0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#050912e8"), Color("#263b58"), 8, 0))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 8, 0))
	stack.add_child(bar)
	return panel

func _create_summary_ev_box(stat_id: String, label_text: String, value: int, color: Color) -> Control:
	var panel: Control = PanelContainer.new() if _is_pokemon_summary_readonly() else Button.new()
	panel.custom_minimum_size = Vector2(96, 50)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if panel is Button:
		var button: Button = panel as Button
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Allocate %s EVs" % label_text
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_summary_allocated_ev_pressed.bind(stat_id, label_text, pokemon_summary_active_card_key))
		button.add_theme_stylebox_override("normal", _make_panel_style(Color("#081321ef"), Color(color.r, color.g, color.b, 0.42), 7, 1))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color("#10243cf2"), color, 7, 1))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#050912f4"), color, 7, 1))
	else:
		(panel as PanelContainer).add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color(color.r, color.g, color.b, 0.42), 7, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var label := Label.new()
	label.text = label_text.to_upper()
	label.tooltip_text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	value_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(value_row)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	value_row.add_child(value_label)

	var cap_label := Label.new()
	cap_label.text = "/252"
	cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_label.add_theme_font_size_override("font_size", 10)
	cap_label.add_theme_color_override("font_color", Color("#b8c9e4"))
	value_row.add_child(cap_label)

	var bar := ProgressBar.new()
	bar.max_value = 252
	bar.value = clamp(value, 0, 252)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#050912e8"), Color("#263b58"), 8, 0))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 8, 0))
	stack.add_child(bar)
	return panel

func _create_summary_ev_total_panel(total_evs: int) -> Control:
	var clamped_total: int = clampi(total_evs, 0, POKEMON_EV_TOTAL_LIMIT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color("#62d7ff70"), 6, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var title := Label.new()
	title.text = "TOTAL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	title.add_theme_color_override("font_shadow_color", Color("#00111f"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(title)

	var value_label := Label.new()
	value_label.text = "%s / %s" % [clamped_total, POKEMON_EV_TOTAL_LIMIT]
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("#f4f7ff") if clamped_total < POKEMON_EV_TOTAL_LIMIT else Color("#f5df9a"))
	row.add_child(value_label)

	var bar := ProgressBar.new()
	bar.max_value = POKEMON_EV_TOTAL_LIMIT
	bar.value = clamped_total
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.tooltip_text = "Total EVs: %s / %s" % [clamped_total, POKEMON_EV_TOTAL_LIMIT]
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#050912e8"), Color("#263b58"), 3, 1))
	bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#62d7ff"), Color("#62d7ff"), 3, 0))
	stack.add_child(bar)

	return panel

func _create_summary_ev_training_row(stat_id: String, label_text: String, value: int, color: Color) -> Control:
	var clamped_value: int = clampi(value, 0, POKEMON_EV_STAT_LIMIT)
	var capped := clamped_value >= POKEMON_EV_STAT_LIMIT
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 31)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "%s EVs: %s / %s" % [label_text, clamped_value, POKEMON_EV_STAT_LIMIT]
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color("#081321ef"),
			Color("#f5df9aaa") if capped else Color(color.r, color.g, color.b, 0.48),
			5,
			1
		)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var stat_label := Label.new()
	stat_label.text = label_text.to_upper()
	stat_label.custom_minimum_size = Vector2(58, 0)
	stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(stat_label)
	stat_label.add_theme_font_size_override("font_size", 10)
	stat_label.add_theme_color_override("font_color", color)
	row.add_child(stat_label)

	var bar := ProgressBar.new()
	bar.max_value = POKEMON_EV_STAT_LIMIT
	bar.value = clamped_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#050912e8"), Color("#263b58"), 3, 1))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 3, 0))
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = "%s/%s" % [clamped_value, POKEMON_EV_STAT_LIMIT]
	value_label.custom_minimum_size = Vector2(58, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color("#f5df9a") if capped else Color("#f4f7ff"))
	row.add_child(value_label)

	return panel

func _create_summary_stored_evs_panel(allocated_evs: Dictionary, stored_evs: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 104)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), POKEMON_SUMMARY_ACCENT_FAINT, 7, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var allocated_total: int = 0
	var stored_total: int = 0
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		allocated_total += int(allocated_evs.get(stat_id, 0))
		stored_total += int(stored_evs.get(stat_id, 0))

	var total_label := Label.new()
	total_label.text = "AVAILABLE: %s    TOTAL CAPACITY: %s / %s" % [stored_total, allocated_total + stored_total, POKEMON_EV_TOTAL_LIMIT]
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_size_override("font_size", 10)
	total_label.add_theme_color_override("font_color", Color("#f5df9a"))
	stack.add_child(total_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(grid)

	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var label_text: String = str(stat.get("label", stat_id))
		var color: Color = stat.get("color", UI_BORDER_FOCUS) as Color
		var value: int = int(stored_evs.get(stat_id, 0))
		grid.add_child(_create_summary_stored_ev_chip(label_text, value, color))

	return panel

func _create_summary_stored_ev_chip(label_text: String, value: int, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(88, 34)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912e8"), Color(color.r, color.g, color.b, 0.55), 6, 1))

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color("#f4f7ff"))
	stack.add_child(value_label)

	return panel

func _on_summary_allocated_ev_pressed(stat_id: String, label_text: String, card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
		return

	var pokemon: Pokemon = PlayerSave.party[pokemon_summary_selected_slot]
	var current_value: int = int(pokemon.evs.get(stat_id, 0))
	var allocated_total: int = _get_summary_ev_total(pokemon.evs)
	var stored_total: int = _get_summary_ev_total(pokemon.stored_evs)
	var total_room: int = max(510 - allocated_total, 0)
	var max_value: int = min(252, current_value + stored_total, current_value + total_room)

	pokemon_summary_ev_allocate_stat_id = stat_id
	pokemon_summary_ev_allocate_stat_label.text = "Allocate %s EVs" % label_text
	pokemon_summary_ev_allocate_current_label.text = "Current: %s    Allocated: %s / 510    Stored: %s" % [current_value, allocated_total, stored_total]
	pokemon_summary_ev_allocate_input.min_value = current_value
	pokemon_summary_ev_allocate_input.max_value = max(current_value, max_value)
	pokemon_summary_ev_allocate_input.value = current_value
	pokemon_summary_ev_allocate_popup.visible = true
	_activate_ui_panel(pokemon_summary_ev_allocate_popup)
	_store_active_pokemon_summary_card_context()
	_refresh_summary_ev_allocate_status()

func _hide_pokemon_summary_ev_allocate_popup() -> void:
	if pokemon_summary_ev_allocate_popup != null:
		pokemon_summary_ev_allocate_popup.visible = false
		_deactivate_ui_panel(pokemon_summary_ev_allocate_popup)
	pokemon_summary_ev_allocate_stat_id = ""

func _on_summary_ev_allocate_value_changed(_value: float) -> void:
	_refresh_summary_ev_allocate_status()

func _on_summary_ev_allocate_confirm_pressed() -> void:
	if pokemon_summary_ev_allocate_confirm_button.disabled:
		return

	if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
		return

	var pokemon: Pokemon = PlayerSave.party[pokemon_summary_selected_slot]
	if pokemon == null or pokemon.owned_pokemon_id <= 0:
		pokemon_summary_ev_allocate_status_label.text = "This Pokemon is missing an ownership id."
		pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_DANGER)
		return

	var stat_id: String = pokemon_summary_ev_allocate_stat_id
	var requested_value: int = int(pokemon_summary_ev_allocate_input.value)
	pokemon_summary_ev_allocate_confirm_button.disabled = true
	pokemon_summary_ev_allocate_input.editable = false
	pokemon_summary_ev_allocate_status_label.text = "Allocating EVs..."
	pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)

	var result: Dictionary = await PlayerPartyStateService.allocate_pokemon_evs(pokemon.owned_pokemon_id, stat_id, requested_value)
	pokemon_summary_ev_allocate_input.editable = true
	if not bool(result.get("success", false)):
		pokemon_summary_ev_allocate_status_label.text = str(result.get("error", "Could not allocate EVs."))
		pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_DANGER)
		_refresh_summary_ev_allocate_status()
		return

	var allocation: Dictionary = _staff_dictionary_from_variant(result.get("allocation", {}))
	var added_value: int = max(int(allocation.get("addedValue", 0)), 0)
	_add_chat_message("%s allocated +%s %s EVs." % [
		str(allocation.get("species", pokemon.species)),
		added_value,
		_summary_stat_label(stat_id),
	])
	_hide_pokemon_summary_ev_allocate_popup()
	_refresh_open_pokemon_summary_cards()

func _refresh_summary_ev_allocate_status() -> void:
	if pokemon_summary_ev_allocate_popup == null or not pokemon_summary_ev_allocate_popup.visible:
		return
	if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
		pokemon_summary_ev_allocate_confirm_button.disabled = true
		return

	var pokemon: Pokemon = PlayerSave.party[pokemon_summary_selected_slot]
	var stat_id: String = pokemon_summary_ev_allocate_stat_id
	var current_value: int = int(pokemon.evs.get(stat_id, 0))
	var requested_value: int = int(pokemon_summary_ev_allocate_input.value)
	var added_value: int = requested_value - current_value
	var allocated_total: int = _get_summary_ev_total(pokemon.evs)
	var stored_total: int = _get_summary_ev_total(pokemon.stored_evs)
	var requested_allocated_total: int = allocated_total + max(added_value, 0)
	var error_text := ""

	if requested_value < current_value:
		error_text = "Value cannot be lower than the current allocated EVs."
	elif requested_value > 252:
		error_text = "A stat cannot exceed 252 EVs."
	elif requested_allocated_total > 510:
		error_text = "Allocated EVs cannot exceed 510 total."
	elif added_value > stored_total:
		error_text = "Not enough stored EVs available."

	if error_text != "":
		pokemon_summary_ev_allocate_status_label.text = error_text
		pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_DANGER)
		pokemon_summary_ev_allocate_confirm_button.disabled = true
		return

	pokemon_summary_ev_allocate_status_label.text = "Will allocate +%s EVs. New allocated total: %s / 510." % [max(added_value, 0), requested_allocated_total]
	pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	pokemon_summary_ev_allocate_confirm_button.disabled = added_value <= 0

func _get_summary_ev_total(evs: Dictionary) -> int:
	var total := 0
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		total += clampi(int(evs.get(str(stat.get("id", "")), 0)), 0, POKEMON_EV_STAT_LIMIT)
	return clampi(total, 0, POKEMON_EV_TOTAL_LIMIT)

func _create_summary_move_card(
	move_number: int,
	move_name: String,
	pp_text: String,
	move_type: String = "",
	power_text: String = "-",
	accuracy_text: String = "-",
	description_text: String = ""
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)
	panel.tooltip_text = description_text
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), POKEMON_SUMMARY_ACCENT_FAINT, 8, 1))

	var margin := MarginContainer.new()
	margin.tooltip_text = description_text
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.tooltip_text = description_text
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var top_row := HBoxContainer.new()
	top_row.tooltip_text = description_text
	top_row.add_theme_constant_override("separation", 6)
	stack.add_child(top_row)

	var number_label := Label.new()
	number_label.text = str(move_number)
	number_label.tooltip_text = description_text
	number_label.custom_minimum_size = Vector2(22, 22)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 11)
	number_label.add_theme_color_override("font_color", Color("#101827"))
	number_label.add_theme_stylebox_override("normal", _make_panel_style(POKEMON_SUMMARY_ACCENT, Color("#b9efff"), 12, 1))
	top_row.add_child(number_label)

	var move_label := Label.new()
	move_label.text = move_name
	move_label.tooltip_text = description_text if description_text != "" else move_name
	move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(move_label)
	move_label.add_theme_font_size_override("font_size", 13)
	move_label.add_theme_color_override("font_color", Color("#f5df9a"))
	top_row.add_child(move_label)

	var type_icon_texture: Texture2D = _load_pokemon_type_icon(move_type)
	if type_icon_texture != null:
		var type_icon := TextureRect.new()
		type_icon.custom_minimum_size = Vector2(24, 24)
		type_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		type_icon.texture = type_icon_texture
		type_icon.tooltip_text = description_text if description_text != "" else move_type.capitalize()
		type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(type_icon)
	elif move_type.strip_edges() != "":
		top_row.add_child(_create_summary_move_type_label(move_type))

	var meta_row := HBoxContainer.new()
	meta_row.tooltip_text = description_text
	meta_row.add_theme_constant_override("separation", 8)
	stack.add_child(meta_row)
	meta_row.add_child(_create_summary_move_meta_label("PP", pp_text, Color("#ff5da8"), description_text))
	meta_row.add_child(_create_summary_move_meta_label("Power", power_text, Color("#f2cf78"), description_text))
	meta_row.add_child(_create_summary_move_meta_label("ACC", accuracy_text, Color("#d9ecff"), description_text))
	return panel

func _create_summary_move_type_label(move_type: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(42, 20)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#101827e8"), POKEMON_SUMMARY_ACCENT_FAINT, 5, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var label := Label.new()
	label.text = move_type.to_upper()
	label.tooltip_text = move_type.capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#f5df9a"))
	margin.add_child(label)
	return panel

func _create_summary_move_meta_label(label_text: String, value_text: String, color: Color, tooltip_text: String = "") -> Control:
	var label := Label.new()
	label.text = "%s: %s" % [label_text, value_text]
	label.tooltip_text = tooltip_text if tooltip_text != "" else label.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_label_clip_width(label)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	return label

func _render_stat_bar_list(values: Dictionary, max_value: int, use_actual_max: bool) -> void:
	var actual_max: int = max_value
	if use_actual_max:
		actual_max = 1
		for stat_value: Variant in _summary_stat_order():
			var stat: Dictionary = stat_value
			actual_max = max(actual_max, int(values.get(str(stat.get("id", "")), 0)))
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(values.get(stat_id, 0))
		pokemon_summary_content_stack.add_child(_create_summary_stat_row(
			str(stat.get("label", stat_id)),
			value,
			actual_max,
			stat.get("color", UI_BORDER_FOCUS) as Color
		))

func _summary_stat_order() -> Array[Dictionary]:
	return [
		{"id": "hp", "label": "HP", "color": Color("#ff5d69")},
		{"id": "atk", "label": "ATK", "color": Color("#ffb347")},
		{"id": "def", "label": "DEF", "color": Color("#ffd95d")},
		{"id": "spa", "label": "SP.ATK", "color": Color("#38bdf8")},
		{"id": "spd", "label": "SP.DEF", "color": Color("#73e26d")},
		{"id": "spe", "label": "SPEED", "color": Color("#e879f9")},
	]

func _summary_stat_label(stat_id: String) -> String:
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		if str(stat.get("id", "")) == stat_id:
			return str(stat.get("label", stat_id))
	return stat_id.to_upper()

func _get_pokemon_summary_nature_stat_role(nature: String, stat_id: String) -> String:
	if stat_id == "hp":
		return ""

	var nature_key := nature.strip_edges().to_lower().replace(" ", "-")
	var changes_value: Variant = POKEMON_SUMMARY_NATURE_CHANGES.get(nature_key, {})
	if not (changes_value is Dictionary):
		return ""

	var changes: Dictionary = changes_value
	if stat_id == str(changes.get("boosted", "")):
		return "boosted"
	if stat_id == str(changes.get("lowered", "")):
		return "lowered"
	return ""

func _refresh_pokemon_summary_stats(pokemon: Pokemon) -> void:
	for child: Node in pokemon_summary_stats_list.get_children():
		child.queue_free()

	var stat_order: Array[Dictionary] = [
		{"id": "hp", "label": "HP", "color": Color("#ff5d69")},
		{"id": "atk", "label": "ATK", "color": Color("#ffb347")},
		{"id": "def", "label": "DEF", "color": Color("#ffd95d")},
		{"id": "spa", "label": "SP.ATK", "color": Color("#38bdf8")},
		{"id": "spd", "label": "SP.DEF", "color": Color("#73e26d")},
		{"id": "spe", "label": "SPEED", "color": Color("#e879f9")},
	]
	var max_stat: int = 1
	for stat_value: Variant in stat_order:
		var stat: Dictionary = stat_value
		max_stat = max(max_stat, int(pokemon.stats.get(str(stat.get("id", "")), 0)))

	for stat_value: Variant in stat_order:
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(pokemon.stats.get(stat_id, 0))
		var stat_color: Color = stat.get("color", UI_BORDER_FOCUS) as Color
		pokemon_summary_stats_list.add_child(_create_summary_stat_row(
			str(stat.get("label", stat_id)),
			value,
			max_stat,
			stat_color
		))

func _create_summary_stat_row(label_text: String, value: int, max_stat: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(46, 15)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = max(max_stat, 1)
	bar.value = clamp(value, 0, max_stat)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#060b14ee"), Color("#2f4668"), 8, 1))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 8, 0))
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size = Vector2(30, 15)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 9)
	value_label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(value_label)
	return row

func _refresh_pokemon_summary_moves(pokemon: Pokemon) -> void:
	for child: Node in pokemon_summary_moves_list.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Moves"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI_MONEY)
	pokemon_summary_moves_list.add_child(title)

	for move_index in range(4):
		var move_name: String = "-"
		var pp_text: String = "--/--"
		if move_index < pokemon.moves.size():
			var move_value: Variant = pokemon.moves[move_index]
			move_name = _get_summary_move_name(move_value)
			pp_text = _get_summary_move_pp_text(move_value)
		pokemon_summary_moves_list.add_child(_create_summary_move_row(move_index + 1, move_name, pp_text))

func _create_summary_move_row(move_number: int, move_name: String, pp_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#071827f2"), Color("#284465"), 8, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var label := Label.new()
	label.text = "%s. %s  %s" % [move_number, move_name, pp_text]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_TEXT)
	margin.add_child(label)
	return panel

func _set_pokemon_summary_ball_button(pokemon: Pokemon) -> void:
	if pokemon_summary_ball_button == null or pokemon_summary_ball_icon == null:
		return

	var ball_item_id := _get_pokemon_ball_item_id(pokemon)
	var ball_texture := _load_item_icon(ball_item_id)
	pokemon_summary_ball_icon.texture = ball_texture
	pokemon_summary_ball_icon.modulate = Color(1, 1, 1, 0.45) if ball_texture == null else Color(1, 1, 1, 1)
	pokemon_summary_ball_button.disabled = _is_pokemon_summary_readonly()
	pokemon_summary_ball_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if _is_pokemon_summary_readonly() else Control.CURSOR_POINTING_HAND
	pokemon_summary_ball_button.tooltip_text = "Read-only preview." if _is_pokemon_summary_readonly() else "Change Poké Ball: %s" % _item_name_from_id(ball_item_id)

func _on_pokemon_summary_ball_button_pressed(card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if not (pokemon_value is Pokemon):
		_add_chat_message("This Pokemon is missing an ownership id.")
		return
	var pokemon: Pokemon = pokemon_value as Pokemon
	if pokemon.owned_pokemon_id <= 0:
		_add_chat_message("This Pokemon is missing an ownership id.")
		return

	await _ensure_bag_inventory_loaded()
	_apply_pokemon_summary_card_context(card_key)
	if pokemon_summary_ball_search_input != null:
		pokemon_summary_ball_search_input.text = ""
	_refresh_pokemon_summary_ball_picker(pokemon)
	pokemon_summary_ball_picker.visible = not pokemon_summary_ball_picker.visible
	if pokemon_summary_item_picker != null:
		pokemon_summary_item_picker.visible = false
	if pokemon_summary_ball_picker.visible and pokemon_summary_ball_search_input != null:
		pokemon_summary_ball_search_input.grab_focus.call_deferred()
	_store_active_pokemon_summary_card_context()

func _refresh_pokemon_summary_ball_picker(pokemon: Pokemon) -> void:
	if pokemon_summary_ball_list == null:
		return
	for child: Node in pokemon_summary_ball_list.get_children():
		child.queue_free()

	var current_ball_item_id := _get_pokemon_ball_item_id(pokemon)
	var query := ""
	if pokemon_summary_ball_search_input != null:
		query = pokemon_summary_ball_search_input.text.strip_edges().to_lower()
	var added_count := 0
	var has_more_matches := false
	for item_value: Variant in bag_inventory_items:
		var item: Dictionary = item_value
		if not _is_pokeball_bag_item(item):
			continue
		if not _matches_summary_item_picker_query(item, query):
			continue
		if added_count >= 5:
			has_more_matches = true
			break
		pokemon_summary_ball_list.add_child(_create_summary_ball_choice(item, current_ball_item_id))
		added_count += 1

	if added_count <= 0:
		var empty_label := Label.new()
		empty_label.text = "No matching Poké Balls." if query != "" else "No Poké Balls in your bag."
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokemon_summary_ball_list.add_child(empty_label)
	elif query == "" and has_more_matches:
		pokemon_summary_ball_list.add_child(_create_summary_picker_hint("Search to narrow Poké Balls."))

func _on_pokemon_summary_ball_search_changed(_text: String) -> void:
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if pokemon_value is Pokemon:
		_refresh_pokemon_summary_ball_picker(pokemon_value as Pokemon)

func _matches_summary_item_picker_query(item: Dictionary, query: String) -> bool:
	var normalized_query: String = query.strip_edges().to_lower()
	if normalized_query == "":
		return true
	var item_id: String = str(item.get("id", "")).strip_edges()
	var item_name: String = str(item.get("name", _item_name_from_id(item_id))).strip_edges()
	var haystack: String = ("%s %s" % [item_id, item_name]).to_lower()
	return haystack.contains(normalized_query)

func _create_summary_picker_hint(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	return label

func _create_summary_ball_choice(item: Dictionary, current_ball_item_id: String) -> Control:
	var button := Button.new()
	var item_id := str(item.get("id", "")).strip_edges()
	var is_current := _normalize_item_id(item_id) == _normalize_item_id(current_ball_item_id)
	var prefix := "✓ " if is_current else ""
	button.text = "%s%s  x%s" % [prefix, _ellipsize_text(str(item.get("name", _item_name_from_id(item_id))), 18), max(int(item.get("quantity", 1)), 1)]
	button.tooltip_text = item_id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = is_current
	button.pressed.connect(_on_pokemon_summary_ball_selected.bind(item_id, pokemon_summary_active_card_key))
	_apply_button_style(button)
	return button

func _on_pokemon_summary_ball_selected(item_id: String, card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if not (pokemon_value is Pokemon):
		_add_chat_message("This Pokemon is missing an ownership id.")
		return
	var pokemon: Pokemon = pokemon_value as Pokemon
	if pokemon.owned_pokemon_id <= 0:
		_add_chat_message("This Pokemon is missing an ownership id.")
		return

	var current_ball_item_id := _get_pokemon_ball_item_id(pokemon)
	if _normalize_item_id(item_id) == _normalize_item_id(current_ball_item_id):
		return

	pokemon_summary_pending_ball_item_id = item_id
	pokemon_summary_pending_ball_card_key = card_key
	_show_ui_confirm_popup(
		"Change Poké Ball",
		"Change this Pokemon's Poké Ball from %s to %s?\n\n%s will not be returned to your Bag, and %s will be consumed."
			% [
				_item_name_from_id(current_ball_item_id),
				_item_name_from_id(item_id),
				_item_name_from_id(current_ball_item_id),
				_item_name_from_id(item_id),
			],
		"Change Ball",
		Callable(self, "_on_pokemon_summary_ball_change_confirmed"),
		Vector2i(480, 0)
	)

func _on_pokemon_summary_ball_change_confirmed() -> void:
	var item_id := pokemon_summary_pending_ball_item_id
	var card_key := pokemon_summary_pending_ball_card_key
	pokemon_summary_pending_ball_item_id = ""
	pokemon_summary_pending_ball_card_key = ""
	if item_id == "":
		return
	await _apply_pokemon_summary_ball_change(item_id, card_key)

func _apply_pokemon_summary_ball_change(item_id: String, card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if not (pokemon_value is Pokemon):
		_add_chat_message("This Pokemon is missing an ownership id.")
		return
	var pokemon: Pokemon = pokemon_value as Pokemon
	if pokemon.owned_pokemon_id <= 0:
		_add_chat_message("This Pokemon is missing an ownership id.")
		return

	var result: Dictionary = await PlayerPartyStateService.set_pokemon_ball(pokemon.owned_pokemon_id, item_id)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not change Poké Ball: %s" % str(result.get("error", "Unknown error")))
		return

	bag_inventory_items = _normalize_bag_inventory_items(result.get("inventory", []))
	bag_inventory_loaded = true
	pokemon_summary_ball_picker.visible = false
	_store_active_pokemon_summary_card_context()
	_refresh_open_pokemon_summary_cards()
	if bag_popup != null and bag_popup.visible:
		_refresh_bag_items()

func _on_pokemon_summary_held_item_slot_pressed(card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if not (pokemon_value is Pokemon):
		_add_chat_message("This Pokemon is missing an ownership id.")
		return
	var pokemon: Pokemon = pokemon_value as Pokemon
	if pokemon.owned_pokemon_id <= 0:
		_add_chat_message("This Pokemon is missing an ownership id.")
		return

	var held_item_id: String = _get_pokemon_held_item_id(pokemon)
	if held_item_id != "":
		var result: Dictionary = await PlayerPartyStateService.take_pokemon_held_item(pokemon.owned_pokemon_id)
		if not bool(result.get("success", false)):
			_add_chat_message("Could not take item: %s" % str(result.get("error", "Unknown error")))
			return
		bag_inventory_items = _normalize_bag_inventory_items(result.get("inventory", []))
		bag_inventory_loaded = true
		_refresh_open_pokemon_summary_cards()
		if bag_popup != null and bag_popup.visible:
			_refresh_bag_items()
		return

	await _ensure_bag_inventory_loaded()
	_apply_pokemon_summary_card_context(card_key)
	if pokemon_summary_item_search_input != null:
		pokemon_summary_item_search_input.text = ""
	_refresh_pokemon_summary_item_picker()
	pokemon_summary_item_picker.visible = not pokemon_summary_item_picker.visible
	if pokemon_summary_ball_picker != null:
		pokemon_summary_ball_picker.visible = false
	if pokemon_summary_item_picker.visible and pokemon_summary_item_search_input != null:
		pokemon_summary_item_search_input.grab_focus.call_deferred()
	_store_active_pokemon_summary_card_context()

func _set_pokemon_summary_held_item_slot(pokemon: Pokemon) -> void:
	if pokemon_summary_held_item_slot == null or pokemon_summary_held_item_slot_name_label == null or pokemon_summary_held_item_slot_icon == null:
		return

	var held_item_id: String = _get_pokemon_held_item_id(pokemon)
	var has_item: bool = held_item_id != ""
	var icon_texture: Texture2D = null
	if has_item:
		icon_texture = _load_item_icon(held_item_id)
		pokemon_summary_held_item_slot_name_label.text = _item_name_from_id(held_item_id)
		pokemon_summary_held_item_slot_name_label.tooltip_text = pokemon_summary_held_item_slot_name_label.text
		if pokemon_summary_held_item_slot_button != null:
			pokemon_summary_held_item_slot_button.tooltip_text = "Read-only preview." if _is_pokemon_summary_readonly() else "Click to take held item."
	else:
		pokemon_summary_held_item_slot_name_label.text = "No held item"
		pokemon_summary_held_item_slot_name_label.tooltip_text = pokemon_summary_held_item_slot_name_label.text
		if pokemon_summary_held_item_slot_button != null:
			pokemon_summary_held_item_slot_button.tooltip_text = "Read-only preview." if _is_pokemon_summary_readonly() else "Click to give a held item."
	if pokemon_summary_held_item_slot_button != null:
		pokemon_summary_held_item_slot_button.disabled = _is_pokemon_summary_readonly()
		pokemon_summary_held_item_slot_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if _is_pokemon_summary_readonly() else Control.CURSOR_POINTING_HAND

	pokemon_summary_held_item_slot_icon.texture = icon_texture
	if icon_texture == null:
		pokemon_summary_held_item_slot_icon.modulate = Color(1, 1, 1, 0.35)
	else:
		pokemon_summary_held_item_slot_icon.modulate = Color(1, 1, 1, 1)

func _refresh_pokemon_summary_item_picker() -> void:
	for child: Node in pokemon_summary_item_list.get_children():
		child.queue_free()

	var query := ""
	if pokemon_summary_item_search_input != null:
		query = pokemon_summary_item_search_input.text.strip_edges().to_lower()
	var added_count: int = 0
	var has_more_matches := false
	for item_value: Variant in bag_inventory_items:
		var item: Dictionary = item_value
		if not _is_holdable_bag_item(item):
			continue
		if not _matches_summary_item_picker_query(item, query):
			continue
		if added_count >= 5:
			has_more_matches = true
			break
		pokemon_summary_item_list.add_child(_create_summary_item_choice(item))
		added_count += 1

	if added_count <= 0:
		var empty_label := Label.new()
		empty_label.text = "No matching held items." if query != "" else "No held items in your bag."
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokemon_summary_item_list.add_child(empty_label)
	elif query == "" and has_more_matches:
		pokemon_summary_item_list.add_child(_create_summary_picker_hint("Search to narrow held items."))

func _on_pokemon_summary_item_search_changed(_text: String) -> void:
	_refresh_pokemon_summary_item_picker()

func _create_summary_item_choice(item: Dictionary) -> Control:
	var button := Button.new()
	var item_id: String = str(item.get("id", ""))
	button.text = "%s  x%s" % [_ellipsize_text(str(item.get("name", item_id)), 18), max(int(item.get("quantity", 1)), 1)]
	button.tooltip_text = item_id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pokemon_summary_item_selected.bind(item_id, pokemon_summary_active_card_key))
	_apply_button_style(button)
	return button

func _on_pokemon_summary_item_selected(item_id: String, card_key: String = "") -> void:
	_apply_pokemon_summary_card_context(card_key)
	if _is_pokemon_summary_readonly():
		return
	var pokemon_value: Variant = _get_selected_summary_pokemon()
	if not (pokemon_value is Pokemon):
		_add_chat_message("This Pokemon is missing an ownership id.")
		return
	var pokemon: Pokemon = pokemon_value as Pokemon
	if pokemon.owned_pokemon_id <= 0:
		_add_chat_message("This Pokemon is missing an ownership id.")
		return

	var result: Dictionary = await PlayerPartyStateService.give_pokemon_held_item(pokemon.owned_pokemon_id, item_id)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not give item: %s" % str(result.get("error", "Unknown error")))
		return

	bag_inventory_items = _normalize_bag_inventory_items(result.get("inventory", []))
	bag_inventory_loaded = true
	pokemon_summary_item_picker.visible = false
	_store_active_pokemon_summary_card_context()
	_refresh_open_pokemon_summary_cards()
	if bag_popup != null and bag_popup.visible:
		_refresh_bag_items()

func _ensure_bag_inventory_loaded() -> void:
	if bag_inventory_loaded and not bag_inventory_loading:
		return
	await _load_bag_inventory()

func _get_selected_summary_pokemon() -> Variant:
	if pokemon_summary_selected_slot < 0 or pokemon_summary_selected_slot >= PlayerSave.party.size():
		return null
	return PlayerSave.party[pokemon_summary_selected_slot]

func _is_pokemon_summary_readonly() -> bool:
	return pokemon_summary_mode == "readonly"

func _get_pokemon_held_item_id(pokemon: Pokemon) -> String:
	var item_id: String = pokemon.item.strip_edges().to_lower()
	return item_id

func _is_holdable_bag_item(item: Dictionary) -> bool:
	if bool(item.get("isHoldable", false)):
		return true
	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	var item_id: String = str(item.get("id", "")).strip_edges().to_lower()
	if SPECIAL_HOLDABLE_ITEM_IDS.has(_normalize_item_id(item_id)):
		return true
	return category in ["held_items", "power_stones"] or item_id.ends_with("berry") or item_id.ends_with("--held")

func _is_pokeball_bag_item(item: Dictionary) -> bool:
	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	var item_id: String = str(item.get("id", "")).strip_edges().to_lower()
	return category == "pokeball" or item_id.ends_with("ball") or item_id.contains("-ball")

func _get_pokemon_ball_item_id(pokemon: Pokemon) -> String:
	var ball_item_id := _normalize_item_id(pokemon.ball_item_id)
	return ball_item_id if ball_item_id != "" else "poke-ball"

func _format_move_name(move_id: String) -> String:
	return _item_name_from_id(move_id)

func _format_identifier_display_name(raw_value: String) -> String:
	var cleaned: String = raw_value.strip_edges()
	if cleaned == "":
		return ""

	var words: PackedStringArray = cleaned.replace("_", "-").split("-")
	for index in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)

func _get_summary_move_name(move_value: Variant) -> String:
	if move_value is Dictionary:
		var move_data: Dictionary = move_value as Dictionary
		var move_name: String = str(move_data.get("name", "")).strip_edges()
		if move_name != "":
			return move_name
		return _format_move_name(str(move_data.get("id", move_data.get("move", ""))))

	return _format_move_name(str(move_value))

func _get_summary_move_type(move_value: Variant) -> String:
	if not (move_value is Dictionary):
		var metadata: Dictionary = _lookup_summary_move_metadata(str(move_value))
		var metadata_type: String = str(metadata.get("type", "")).strip_edges()
		return metadata_type if metadata_type != "" else _lookup_summary_move_type(str(move_value))

	var move_data: Dictionary = move_value as Dictionary
	for key in ["type", "moveType", "move_type"]:
		var type_text: String = str(move_data.get(key, "")).strip_edges()
		if type_text != "":
			return type_text

	var metadata_value: Variant = move_data.get("metadata", move_data.get("data", {}))
	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value as Dictionary
		for key in ["type", "moveType", "move_type"]:
			var type_text: String = str(metadata.get(key, "")).strip_edges()
			if type_text != "":
				return type_text

	for key in ["id", "move", "moveId", "move_id", "name"]:
		var move_key: String = str(move_data.get(key, "")).strip_edges()
		var metadata: Dictionary = _lookup_summary_move_metadata(move_key)
		var metadata_type: String = str(metadata.get("type", "")).strip_edges()
		if metadata_type != "":
			return metadata_type
		var indexed_type: String = _lookup_summary_move_type(move_key)
		if indexed_type != "":
			return indexed_type

	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value as Dictionary
		for key in ["id", "move", "moveId", "move_id", "name"]:
			var move_key: String = str(metadata.get(key, "")).strip_edges()
			var indexed_metadata: Dictionary = _lookup_summary_move_metadata(move_key)
			var indexed_metadata_type: String = str(indexed_metadata.get("type", "")).strip_edges()
			if indexed_metadata_type != "":
				return indexed_metadata_type
			var indexed_type: String = _lookup_summary_move_type(move_key)
			if indexed_type != "":
				return indexed_type

	var fallback_metadata: Dictionary = _lookup_summary_move_metadata(_get_summary_move_name(move_value))
	var fallback_metadata_type: String = str(fallback_metadata.get("type", "")).strip_edges()
	return fallback_metadata_type if fallback_metadata_type != "" else _lookup_summary_move_type(_get_summary_move_name(move_value))

func _lookup_summary_move_type(move_key: String) -> String:
	var normalized_key: String = _normalize_summary_move_lookup_key(move_key)
	if normalized_key == "":
		return ""
	_ensure_summary_move_type_index_loaded()
	if pokemon_summary_move_type_index.is_empty():
		return ""
	return str(pokemon_summary_move_type_index.get(normalized_key, ""))

func _ensure_summary_move_type_index_loaded() -> void:
	if pokemon_summary_move_type_index_loaded:
		return
	pokemon_summary_move_type_index_loaded = true
	pokemon_summary_move_type_index.clear()

	if not FileAccess.file_exists(MOVE_TYPE_INDEX_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(MOVE_TYPE_INDEX_PATH)
	if json_text.strip_edges() == "":
		return

	var parsed_value: Variant = JSON.parse_string(json_text)
	if not (parsed_value is Dictionary):
		return

	var parsed_dictionary: Dictionary = parsed_value as Dictionary
	for key_value: Variant in parsed_dictionary.keys():
		var normalized_key: String = _normalize_summary_move_lookup_key(str(key_value))
		var move_type: String = str(parsed_dictionary.get(key_value, "")).strip_edges().to_lower()
		if normalized_key != "" and move_type != "":
			pokemon_summary_move_type_index[normalized_key] = move_type

func _lookup_summary_move_metadata(move_key: String) -> Dictionary:
	var normalized_key: String = _normalize_summary_move_lookup_key(move_key)
	if normalized_key == "":
		return {}
	_ensure_summary_move_summary_index_loaded()
	if pokemon_summary_move_summary_index.is_empty():
		return {}
	var metadata_value: Variant = pokemon_summary_move_summary_index.get(normalized_key, {})
	return (metadata_value as Dictionary).duplicate(true) if metadata_value is Dictionary else {}

func _merge_summary_move_metadata(move_data: Dictionary) -> Dictionary:
	var merged := move_data.duplicate(true)
	for lookup_key_value: Variant in ["id", "move", "moveId", "move_id", "name"]:
		var lookup_key := str(merged.get(str(lookup_key_value), "")).strip_edges()
		var metadata := _lookup_summary_move_metadata(lookup_key)
		if metadata.is_empty():
			continue
		for key_value: Variant in metadata.keys():
			if not merged.has(key_value):
				merged[key_value] = metadata.get(key_value)
		return merged
	return merged

func _ensure_summary_move_summary_index_loaded() -> void:
	if pokemon_summary_move_summary_index_loaded:
		return
	pokemon_summary_move_summary_index_loaded = true
	pokemon_summary_move_summary_index.clear()

	if not FileAccess.file_exists(MOVE_SUMMARY_INDEX_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(MOVE_SUMMARY_INDEX_PATH)
	if json_text.strip_edges() == "":
		return

	var parsed_value: Variant = JSON.parse_string(json_text)
	if not (parsed_value is Dictionary):
		return

	var parsed_dictionary: Dictionary = parsed_value as Dictionary
	for key_value: Variant in parsed_dictionary.keys():
		var move_metadata_value: Variant = parsed_dictionary.get(key_value, {})
		if not (move_metadata_value is Dictionary):
			continue
		var move_metadata: Dictionary = (move_metadata_value as Dictionary).duplicate(true)
		_add_summary_move_metadata_alias(str(key_value), move_metadata)
		_add_summary_move_metadata_alias(str(move_metadata.get("id", "")), move_metadata)
		_add_summary_move_metadata_alias(str(move_metadata.get("name", "")), move_metadata)

func _add_summary_move_metadata_alias(move_key: String, move_metadata: Dictionary) -> void:
	var normalized_key: String = _normalize_summary_move_lookup_key(move_key)
	if normalized_key != "" and not pokemon_summary_move_summary_index.has(normalized_key):
		pokemon_summary_move_summary_index[normalized_key] = move_metadata

func _lookup_summary_ability_metadata(ability_key: String) -> Dictionary:
	var normalized_key: String = _normalize_summary_ability_lookup_key(ability_key)
	if normalized_key == "":
		return {}
	_ensure_summary_ability_summary_index_loaded()
	if pokemon_summary_ability_summary_index.is_empty():
		return {}
	var metadata_value: Variant = pokemon_summary_ability_summary_index.get(normalized_key, {})
	return (metadata_value as Dictionary).duplicate(true) if metadata_value is Dictionary else {}

func _ensure_summary_ability_summary_index_loaded() -> void:
	if pokemon_summary_ability_summary_index_loaded:
		return
	pokemon_summary_ability_summary_index_loaded = true
	pokemon_summary_ability_summary_index.clear()

	if not FileAccess.file_exists(ABILITY_SUMMARY_INDEX_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(ABILITY_SUMMARY_INDEX_PATH)
	if json_text.strip_edges() == "":
		return

	var parsed_value: Variant = JSON.parse_string(json_text)
	if not (parsed_value is Dictionary):
		return

	var parsed_dictionary: Dictionary = parsed_value as Dictionary
	for key_value: Variant in parsed_dictionary.keys():
		var ability_metadata_value: Variant = parsed_dictionary.get(key_value, {})
		if not (ability_metadata_value is Dictionary):
			continue
		var ability_metadata: Dictionary = (ability_metadata_value as Dictionary).duplicate(true)
		_add_summary_ability_metadata_alias(str(key_value), ability_metadata)
		_add_summary_ability_metadata_alias(str(ability_metadata.get("id", "")), ability_metadata)
		_add_summary_ability_metadata_alias(str(ability_metadata.get("name", "")), ability_metadata)

func _add_summary_ability_metadata_alias(ability_key: String, ability_metadata: Dictionary) -> void:
	var normalized_key: String = _normalize_summary_ability_lookup_key(ability_key)
	if normalized_key != "" and not pokemon_summary_ability_summary_index.has(normalized_key):
		pokemon_summary_ability_summary_index[normalized_key] = ability_metadata

func _normalize_summary_ability_lookup_key(value: String) -> String:
	var normalized_key: String = value.strip_edges().to_lower()
	if normalized_key == "":
		return ""
	normalized_key = normalized_key.replace("_", "-")
	normalized_key = normalized_key.replace(" ", "-")
	while normalized_key.contains("--"):
		normalized_key = normalized_key.replace("--", "-")
	return normalized_key

func _get_summary_ability_description_text(ability_value: String) -> String:
	var metadata: Dictionary = _lookup_summary_ability_metadata(ability_value)
	var description: String = str(_get_first_dictionary_value(
		metadata,
		["shortDesc", "short_desc", "shortDescription", "short_description", "flavorText", "flavor_text"],
		""
	)).strip_edges()
	if description == "":
		description = str(_get_first_dictionary_value(metadata, ["desc", "description"], "")).strip_edges()
	return description

func _get_summary_ability_display_name(ability_value: String) -> String:
	var cleaned: String = ability_value.strip_edges()
	if cleaned == "":
		return "-"

	var metadata: Dictionary = _lookup_summary_ability_metadata(cleaned)
	var metadata_name: String = str(_get_first_dictionary_value(metadata, ["name", "displayName", "display_name"], "")).strip_edges()
	if metadata_name != "":
		return metadata_name

	return _format_identifier_display_name(cleaned)

func _normalize_summary_move_lookup_key(value: String) -> String:
	var normalized_key: String = value.strip_edges().to_lower()
	if normalized_key == "":
		return ""
	normalized_key = normalized_key.replace("_", "-")
	normalized_key = normalized_key.replace(" ", "-")
	while normalized_key.contains("--"):
		normalized_key = normalized_key.replace("--", "-")
	return normalized_key

func _get_summary_move_pp_text(move_value: Variant) -> String:
	if not (move_value is Dictionary):
		return "--/--"

	var current_pp: int = int(_get_first_dictionary_value(
		move_value as Dictionary,
		["pp", "currentPp", "currentPP", "current_pp"],
		0
	))
	var max_pp: int = int(_get_first_dictionary_value(
		move_value as Dictionary,
		["maxpp", "maxPp", "maxPP", "max_pp", "pp"],
		current_pp
	))
	if max_pp <= 0:
		var indexed_pp_value: Variant = _get_summary_move_data_value(move_value, ["pp", "maxpp", "maxPp", "maxPP", "max_pp"], null)
		if indexed_pp_value != null and str(indexed_pp_value).strip_edges() != "":
			max_pp = int(indexed_pp_value)
			current_pp = max_pp
	if max_pp <= 0:
		return "--/--"
	return "%s/%s" % [clamp(current_pp, 0, max_pp), max_pp]

func _get_summary_move_power_text(move_value: Variant) -> String:
	var power_value: Variant = _get_summary_move_data_value(move_value, ["basePower", "base_power", "power"], null)
	if power_value == null or str(power_value).strip_edges() == "":
		return "-"

	var power: int = int(power_value)
	if power <= 0:
		return "-"
	return str(power)

func _get_summary_move_accuracy_text(move_value: Variant) -> String:
	var accuracy_value: Variant = _get_summary_move_data_value(move_value, ["accuracy", "acc"], null)
	if accuracy_value is bool:
		return "Always" if bool(accuracy_value) else "-"
	if accuracy_value == null or str(accuracy_value).strip_edges() == "":
		return "-"

	var accuracy: int = int(accuracy_value)
	if accuracy <= 0:
		return "-"
	return "%s%%" % accuracy

func _get_summary_move_description_text(move_value: Variant) -> String:
	var description: String = str(_get_summary_move_data_value(
		move_value,
		["shortDesc", "short_desc", "shortDescription", "short_description"],
		""
	)).strip_edges()
	if description == "":
		description = str(_get_summary_move_data_value(move_value, ["desc", "description"], "")).strip_edges()
	return description

func _get_summary_move_data_value(move_value: Variant, keys: Array[String], fallback: Variant) -> Variant:
	if not (move_value is Dictionary):
		var metadata: Dictionary = _lookup_summary_move_metadata(str(move_value))
		for key_value: Variant in keys:
			var key: String = str(key_value)
			if metadata.has(key):
				return metadata.get(key)
		return fallback

	var move_data: Dictionary = move_value as Dictionary
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if move_data.has(key):
			return move_data.get(key)

	for metadata_key_value: Variant in ["metadata", "data"]:
		var metadata_key: String = str(metadata_key_value)
		var metadata_value: Variant = move_data.get(metadata_key, {})
		if not (metadata_value is Dictionary):
			continue
		var metadata: Dictionary = metadata_value as Dictionary
		for key_value: Variant in keys:
			var key: String = str(key_value)
			if metadata.has(key):
				return metadata.get(key)

	for lookup_key_value: Variant in ["id", "move", "moveId", "move_id", "name"]:
		var lookup_key: String = str(move_data.get(str(lookup_key_value), "")).strip_edges()
		var indexed_metadata: Dictionary = _lookup_summary_move_metadata(lookup_key)
		for key_value: Variant in keys:
			var key: String = str(key_value)
			if indexed_metadata.has(key):
				return indexed_metadata.get(key)

	for metadata_key_value: Variant in ["metadata", "data"]:
		var metadata_key: String = str(metadata_key_value)
		var metadata_value: Variant = move_data.get(metadata_key, {})
		if not (metadata_value is Dictionary):
			continue
		var metadata: Dictionary = metadata_value as Dictionary
		for lookup_key_value: Variant in ["id", "move", "moveId", "move_id", "name"]:
			var lookup_key: String = str(metadata.get(str(lookup_key_value), "")).strip_edges()
			var indexed_metadata: Dictionary = _lookup_summary_move_metadata(lookup_key)
			for key_value: Variant in keys:
				var key: String = str(key_value)
				if indexed_metadata.has(key):
					return indexed_metadata.get(key)

	var fallback_metadata: Dictionary = _lookup_summary_move_metadata(_get_summary_move_name(move_value))
	for key_value: Variant in keys:
		var key: String = str(key_value)
		if fallback_metadata.has(key):
			return fallback_metadata.get(key)

	return fallback

func _get_first_dictionary_value(dictionary: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key in keys:
		if dictionary.has(key):
			return dictionary.get(key)

	return fallback

func _default_text(value: String) -> String:
	var text: String = value.strip_edges()
	return text if text != "" else "-"

func _generate_default_inventory() -> Array[Dictionary]:
	return [
		{"id": "potion", "name": "Potion", "category": "medicine", "quantity": 6, "description": "Restores 20 HP to one Pokemon."},
		{"id": "super-potion", "name": "Super Potion", "category": "medicine", "quantity": 3, "description": "Restores 60 HP to one Pokemon."},
		{"id": "poke-ball", "name": "Poke Ball", "category": "pokeball", "quantity": 10, "description": "A standard capsule for catching wild Pokemon."},
		{"id": "great-ball", "name": "Great Ball", "category": "pokeball", "quantity": 5, "description": "A good, high-performance Ball."},
		{"id": "rare-candy", "name": "Rare Candy", "category": "general", "quantity": 1, "description": "Raises a Pokemon's level by one."},
		{"id": "choice-band", "name": "Choice Band", "category": "held_items", "quantity": 1, "description": "Boosts Attack but locks the holder into one move."},
	]

func _get_bag_item_name(item_id: String) -> String:
	for item: Dictionary in bag_inventory_items:
		if str(item.get("id", "")) == item_id:
			return str(item.get("name", item_id))
	return ""

func _string_array_from_value(value: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (value is Array):
		return values
	var source: Array = value
	for item: Variant in source:
		values.append(str(item))
	return values

func _on_pokemon_summary_card_gui_input(event: InputEvent, card_key: String = "") -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _apply_pokemon_summary_card_context(card_key):
		return
	if pokemon_summary_popup != null:
		_activate_ui_panel(pokemon_summary_popup)
	_store_active_pokemon_summary_card_context()

func _on_pokemon_summary_header_gui_input(event: InputEvent, card_key: String = "") -> void:
	if not _apply_pokemon_summary_card_context(card_key):
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		pokemon_summary_dragging = true
		pokemon_summary_dragging_card_key = card_key
		pokemon_summary_drag_offset = mouse_event.global_position - pokemon_summary_popup.global_position
		_activate_ui_panel(pokemon_summary_popup)
	else:
		pokemon_summary_dragging = false
		pokemon_summary_dragging_card_key = ""
	_store_active_pokemon_summary_card_context()
	get_viewport().set_input_as_handled()

func _handle_pokemon_summary_drag_input(event: InputEvent) -> void:
	if pokemon_summary_dragging_card_key != "":
		_apply_pokemon_summary_card_context(pokemon_summary_dragging_card_key)
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			pokemon_summary_dragging = false
			pokemon_summary_dragging_card_key = ""
			_store_active_pokemon_summary_card_context()
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_pokemon_summary_to_global_position(motion_event.global_position - pokemon_summary_drag_offset)
	_store_active_pokemon_summary_card_context()
	get_viewport().set_input_as_handled()

func _move_pokemon_summary_to_global_position(global_top_left: Vector2) -> void:
	if pokemon_summary_popup == null:
		return
	var parent_control: Control = pokemon_summary_popup.get_parent_control()
	if parent_control == null:
		return
	var parent_size: Vector2 = parent_control.size
	var popup_size: Vector2 = POKEMON_SUMMARY_SIZE
	var clamped_position: Vector2 = Vector2(
		clamp(global_top_left.x, 0.0, max(parent_size.x - popup_size.x, 0.0)),
		clamp(global_top_left.y, 0.0, max(parent_size.y - popup_size.y, 0.0))
	)
	var anchor_offset: Vector2 = Vector2(
		parent_size.x * pokemon_summary_popup.anchor_left,
		parent_size.y * pokemon_summary_popup.anchor_top
	)
	var local_offset: Vector2 = clamped_position - anchor_offset
	pokemon_summary_popup.offset_left = local_offset.x
	pokemon_summary_popup.offset_top = local_offset.y
	pokemon_summary_popup.offset_right = local_offset.x + popup_size.x
	pokemon_summary_popup.offset_bottom = local_offset.y + popup_size.y
	pokemon_summary_popup.size = popup_size

func _set_pokemon_summary_popup_size() -> void:
	if pokemon_summary_popup == null:
		return

	pokemon_summary_popup.custom_minimum_size = POKEMON_SUMMARY_SIZE
	pokemon_summary_popup.size = POKEMON_SUMMARY_SIZE
	pokemon_summary_popup.offset_right = pokemon_summary_popup.offset_left + POKEMON_SUMMARY_SIZE.x
	pokemon_summary_popup.offset_bottom = pokemon_summary_popup.offset_top + POKEMON_SUMMARY_SIZE.y
	if pokemon_summary_left_panel != null:
		pokemon_summary_left_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
		pokemon_summary_left_panel.size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
	if pokemon_summary_right_area != null:
		pokemon_summary_right_area.custom_minimum_size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
		pokemon_summary_right_area.size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, POKEMON_SUMMARY_BODY_HEIGHT)
	if pokemon_summary_content_panel != null:
		pokemon_summary_content_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, POKEMON_SUMMARY_CONTENT_PANEL_HEIGHT)
		pokemon_summary_content_panel.size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, POKEMON_SUMMARY_CONTENT_PANEL_HEIGHT)
	if pokemon_summary_content_stack != null:
		pokemon_summary_content_stack.custom_minimum_size = Vector2(0, POKEMON_SUMMARY_CONTENT_STACK_HEIGHT)
		pokemon_summary_content_stack.size = Vector2(pokemon_summary_content_stack.size.x, POKEMON_SUMMARY_CONTENT_STACK_HEIGHT)
	if pokemon_summary_tab_column != null:
		pokemon_summary_tab_column.custom_minimum_size = Vector2(0, 28)
		pokemon_summary_tab_column.size = Vector2(pokemon_summary_tab_column.size.x, 28)

func _set_mail_popup_size() -> void:
	if mail_popup == null:
		return

	var global_top_left: Vector2 = mail_popup.global_position
	mail_popup.grow_horizontal = Control.GROW_DIRECTION_END
	mail_popup.grow_vertical = Control.GROW_DIRECTION_END
	mail_popup.custom_minimum_size = MAIL_POPUP_SIZE
	mail_popup.size = MAIL_POPUP_SIZE
	_move_mail_to_global_position(global_top_left)

func _on_mail_header_gui_input(event: InputEvent) -> void:
	if mail_popup == null:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		mail_dragging = true
		mail_drag_offset = mouse_event.global_position - mail_popup.global_position
		_activate_ui_panel(mail_popup)
	else:
		mail_dragging = false
	get_viewport().set_input_as_handled()

func _handle_mail_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			mail_dragging = false
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_mail_to_global_position(motion_event.global_position - mail_drag_offset)
	get_viewport().set_input_as_handled()

func _move_mail_to_global_position(global_top_left: Vector2) -> void:
	if mail_popup == null:
		return

	var parent_control: Control = mail_popup.get_parent_control()
	if parent_control == null:
		return

	var parent_size: Vector2 = parent_control.size
	var popup_size: Vector2 = MAIL_POPUP_SIZE
	var clamped_position: Vector2 = Vector2(
		clamp(global_top_left.x, 0.0, max(parent_size.x - popup_size.x, 0.0)),
		clamp(global_top_left.y, 0.0, max(parent_size.y - popup_size.y, 0.0))
	)
	var anchor_offset: Vector2 = Vector2(
		parent_size.x * mail_popup.anchor_left,
		parent_size.y * mail_popup.anchor_top
	)
	var local_offset: Vector2 = clamped_position - anchor_offset
	mail_popup.offset_left = local_offset.x
	mail_popup.offset_top = local_offset.y
	mail_popup.offset_right = local_offset.x + popup_size.x
	mail_popup.offset_bottom = local_offset.y + popup_size.y
	mail_popup.size = popup_size

func _on_item_dex_header_gui_input(event: InputEvent) -> void:
	if item_dex_popup == null:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		item_dex_dragging = true
		item_dex_drag_offset = mouse_event.global_position - item_dex_popup.global_position
		_activate_ui_panel(item_dex_popup)
	else:
		item_dex_dragging = false
	get_viewport().set_input_as_handled()

func _handle_item_dex_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			item_dex_dragging = false
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_item_dex_to_global_position(motion_event.global_position - item_dex_drag_offset)
	get_viewport().set_input_as_handled()

func _move_item_dex_to_global_position(global_top_left: Vector2) -> void:
	_move_overlay_popup_to_global_position(item_dex_popup, global_top_left)

func _on_pokedex_header_gui_input(event: InputEvent) -> void:
	if pokedex_popup == null:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		pokedex_dragging = true
		pokedex_drag_offset = mouse_event.global_position - pokedex_popup.global_position
		_activate_ui_panel(pokedex_popup)
	else:
		pokedex_dragging = false
	get_viewport().set_input_as_handled()

func _handle_pokedex_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			pokedex_dragging = false
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseMotion):
		return

	var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	_move_pokedex_to_global_position(motion_event.global_position - pokedex_drag_offset)
	get_viewport().set_input_as_handled()

func _move_pokedex_to_global_position(global_top_left: Vector2) -> void:
	_move_overlay_popup_to_global_position(pokedex_popup, global_top_left)

func _move_overlay_popup_to_global_position(popup: Control, global_top_left: Vector2) -> void:
	if popup == null:
		return

	var parent_control: Control = popup.get_parent_control()
	if parent_control == null:
		return

	var parent_size: Vector2 = parent_control.size
	var popup_size: Vector2 = popup.size
	if popup_size.x <= 0.0 or popup_size.y <= 0.0:
		popup_size = popup.custom_minimum_size
	var clamped_position: Vector2 = Vector2(
		clamp(global_top_left.x, 0.0, max(parent_size.x - popup_size.x, 0.0)),
		clamp(global_top_left.y, 0.0, max(parent_size.y - popup_size.y, 0.0))
	)
	var anchor_offset: Vector2 = Vector2(
		parent_size.x * popup.anchor_left,
		parent_size.y * popup.anchor_top
	)
	var local_offset: Vector2 = clamped_position - anchor_offset
	popup.offset_left = local_offset.x
	popup.offset_top = local_offset.y
	popup.offset_right = local_offset.x + popup_size.x
	popup.offset_bottom = local_offset.y + popup_size.y
	popup.size = popup_size

func _format_money(value: int) -> String:
	var value_text := str(max(value, 0))
	var formatted := ""
	var counter := 0

	for index in range(value_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			formatted = "," + formatted
		formatted = value_text.substr(index, 1) + formatted
		counter += 1

	return formatted

func _format_playtime(total_seconds: int) -> String:
	var safe_seconds: int = max(total_seconds, 0)
	var hours: int = safe_seconds / 3600
	return "%s H." % hours

func _make_panel_style(background_color: Color, border_color: Color, corner_radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style

func _make_pokemon_summary_outer_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#030509fc"), POKEMON_SUMMARY_ACCENT_SOFT, 6, 1)
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_pokemon_summary_inner_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, 5, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_header_frame_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#101827f4"), POKEMON_SUMMARY_ACCENT_SOFT, 4, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _make_pokemon_summary_sprite_stage_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#00000000"), POKEMON_SUMMARY_ACCENT_FAINT, 4, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_section_title_style(color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(Color("#080c13f0"), Color(color.r, color.g, color.b, 0.72), 3, 1)
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.border_width_left = 3
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _create_pokemon_summary_chip(label_text: String, background_color: Color, text_color: Color, compact: bool = false) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _make_panel_style(background_color, Color("#8aadd922"), 7, 1))
	var chip_margin := MarginContainer.new()
	chip_margin.add_theme_constant_override("margin_left", 6)
	chip_margin.add_theme_constant_override("margin_top", 3 if compact else 4)
	chip_margin.add_theme_constant_override("margin_right", 6)
	chip_margin.add_theme_constant_override("margin_bottom", 3 if compact else 4)
	chip.add_child(chip_margin)
	var chip_label := Label.new()
	chip_label.text = label_text
	chip_label.add_theme_font_size_override("font_size", 9 if compact else 11)
	chip_label.add_theme_color_override("font_color", text_color)
	chip_label.add_theme_color_override("font_shadow_color", Color("#00111f"))
	chip_label.add_theme_constant_override("shadow_offset_x", 1)
	chip_label.add_theme_constant_override("shadow_offset_y", 1)
	chip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip_margin.add_child(chip_label)
	return chip

func _make_pokemon_summary_row_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#0b1019e8"), Color("#3e4654"), 4, 1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_pokemon_summary_button_style(background_color: Color, border_color: Color, selected: bool) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 4, 1)
	if selected:
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_held_item_slot_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#0c1119ee"), Color("#3e4654"), 4, 1)
	style.content_margin_left = 7
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style

func _make_pokemon_summary_held_item_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 4, 1)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _make_glass_panel_style(corner_radius: int = 10, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(UI_BG, UI_BORDER_SOFT, corner_radius, border_width)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style

func _make_gold_panel_style(corner_radius: int = 12, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(UI_BG, UI_BORDER, corner_radius, border_width)
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style

func _make_button_style(background_color: Color, border_color: Color, corner_radius: int = 8, border_width: int = 1) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, corner_radius, border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_SLOT_BG
	var hover_bg := Color("#151f36f2")
	var pressed_bg := Color("#080d18f2")
	var border := UI_BORDER_SOFT
	var hover_border := UI_BORDER
	var font_color := UI_TEXT

	if variant == "primary":
		normal_bg = Color("#152447ee")
		hover_bg = Color("#1d3268f2")
		pressed_bg = Color("#0d1730f2")
		border = UI_BORDER_FOCUS
		hover_border = UI_PURPLE_HOVER
	elif variant == "danger":
		normal_bg = UI_DANGER_BG
		hover_bg = Color("#3a151cee")
		pressed_bg = Color("#19090dee")
		border = Color("#7a2b33")
		hover_border = UI_DANGER
		font_color = UI_DANGER

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.45))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, hover_border))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("#0e1a30ee"), UI_BORDER_FOCUS, 8, 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _apply_line_edit_style(line_edit: LineEdit) -> void:
	line_edit.add_theme_color_override("font_color", UI_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.68))
	line_edit.add_theme_stylebox_override("normal", _make_button_style(UI_INPUT_BG, UI_BORDER_SOFT, 8, 1))
	line_edit.add_theme_stylebox_override("focus", _make_button_style(UI_INPUT_BG, UI_BORDER_FOCUS, 8, 1))
	line_edit.add_theme_stylebox_override("read_only", _make_button_style(
		Color(UI_INPUT_BG.r, UI_INPUT_BG.g, UI_INPUT_BG.b, 0.58),
		Color(UI_BORDER_SOFT.r, UI_BORDER_SOFT.g, UI_BORDER_SOFT.b, 0.55),
		8,
		1
	))

func _apply_text_edit_style(text_edit: TextEdit) -> void:
	text_edit.add_theme_color_override("font_color", UI_TEXT)
	text_edit.add_theme_color_override("font_placeholder_color", Color(UI_MUTED_TEXT.r, UI_MUTED_TEXT.g, UI_MUTED_TEXT.b, 0.68))
	text_edit.add_theme_stylebox_override("normal", _make_button_style(UI_INPUT_BG, UI_BORDER_SOFT, 8, 1))
	text_edit.add_theme_stylebox_override("focus", _make_button_style(UI_INPUT_BG, UI_BORDER_FOCUS, 8, 1))

func _apply_slot_panel_style(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, UI_BORDER_SOFT, 8, 1))

func _apply_icon_slot_hover_style(panel: PanelContainer, hovered: bool) -> void:
	var active := bool(panel.get_meta("active", false))
	var background_color := UI_SLOT_BG
	var border_color := UI_BORDER_SOFT
	if active:
		background_color = UI_REPEL_BG
		border_color = Color("#58d96f")
	if hovered:
		background_color = Color("#1b6f34e8") if active else Color("#151f36f2")
		border_color = Color("#72f28a") if active else UI_BORDER
	var style := _make_panel_style(background_color, border_color, 8, 1)
	if hovered:
		style.shadow_color = Color(UI_BORDER.r, UI_BORDER.g, UI_BORDER.b, 0.34)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", style)

func _setup_icon_slot_hover(panel: PanelContainer, button: TextureButton) -> void:
	_apply_icon_slot_hover_style(panel, false)
	if not panel.mouse_entered.is_connected(_on_icon_slot_mouse_entered.bind(panel)):
		panel.mouse_entered.connect(_on_icon_slot_mouse_entered.bind(panel))
	if not panel.mouse_exited.is_connected(_on_icon_slot_mouse_exited.bind(panel)):
		panel.mouse_exited.connect(_on_icon_slot_mouse_exited.bind(panel))
	if not button.mouse_entered.is_connected(_on_icon_slot_mouse_entered.bind(panel)):
		button.mouse_entered.connect(_on_icon_slot_mouse_entered.bind(panel))
	if not button.mouse_exited.is_connected(_on_icon_slot_mouse_exited.bind(panel)):
		button.mouse_exited.connect(_on_icon_slot_mouse_exited.bind(panel))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _set_icon_slot_active(panel: PanelContainer, active: bool) -> void:
	panel.set_meta("active", active)
	_apply_icon_slot_hover_style(panel, false)

func _on_icon_slot_mouse_entered(panel: PanelContainer) -> void:
	_apply_icon_slot_hover_style(panel, true)

func _on_icon_slot_mouse_exited(panel: PanelContainer) -> void:
	_apply_icon_slot_hover_style(panel, false)

func _apply_premium_overlay_styles() -> void:
	party_panel.add_theme_stylebox_override("panel", _make_glass_panel_style())
	chat_panel.add_theme_stylebox_override("panel", _make_glass_panel_style())
	location_panel.add_theme_stylebox_override("panel", _make_glass_panel_style(12))
	options_panel.add_theme_stylebox_override("panel", _make_glass_panel_style())
	actions_panel.add_theme_stylebox_override("panel", _make_glass_panel_style())
	socials_menu.add_theme_stylebox_override("panel", _make_glass_panel_style())
	dev_pokemon_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(12, 1))
	dev_actions_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	if player_status_panel != null:
		player_status_panel.add_theme_stylebox_override("panel", _make_glass_panel_style(14, 1))

	_apply_line_edit_style(chat_input)
	_apply_text_edit_style(dev_pokemon_text)

	_apply_button_style(general_chat_tab_button, "primary")
	_apply_button_style(trade_chat_tab_button, "primary")
	_apply_button_style(system_chat_tab_button, "primary")
	_apply_button_style(send_button, "primary")
	_apply_button_style(dev_pokemon_add_button, "primary")
	_apply_button_style(dev_pokemon_close_button)
	_apply_button_style(dev_add_pokemon_button, "primary")
	_apply_button_style(dev_spawn_pokemon_button, "primary")
	if dev_add_button != null:
		_apply_button_style(dev_add_button, "primary")
	if dev_heal_party_button != null:
		_apply_button_style(dev_heal_party_button, "primary")
	if dev_preview_evolution_button != null:
		_apply_button_style(dev_preview_evolution_button, "primary")
	if dev_add_item_button != null:
		_apply_button_style(dev_add_item_button, "primary")
	if dev_add_money_button != null:
		_apply_button_style(dev_add_money_button, "primary")
	_apply_button_style(dev_clear_party_button, "danger")
	dev_clear_party_button.text = "Clear"
	_apply_button_style(dev_actions_close_button)
	_apply_socials_menu_style()

	if map_slot != null:
		_apply_icon_slot_hover_style(map_slot, false)
	if bag_slot != null:
		_apply_icon_slot_hover_style(bag_slot, false)
	if settings_slot != null:
		_apply_icon_slot_hover_style(settings_slot, false)
	if repel_slot != null:
		_set_icon_slot_active(repel_slot, GameState.repel_enabled)
	if follower_slot != null:
		_set_icon_slot_active(follower_slot, GameState.show_follower)
	if dev_actions_slot != null:
		_apply_icon_slot_hover_style(dev_actions_slot, false)
	if item_dex_slot != null:
		_apply_icon_slot_hover_style(item_dex_slot, false)

	for panel_id_value: Variant in collapsible_panels.keys():
		var panel_id := str(panel_id_value)
		var state: Dictionary = collapsible_panels.get(panel_id, {})
		var button: Button = state.get("button") as Button
		if button != null:
			_apply_button_style(button)
	if chat_resize_button != null:
		_apply_button_style(chat_resize_button)

func _apply_socials_menu_style() -> void:
	var title_label: Label = socials_menu.get_node_or_null("MarginContainer/VBoxContainer/Title") as Label
	if title_label != null:
		title_label.add_theme_color_override("font_color", UI_TEXT)
		title_label.add_theme_font_size_override("font_size", 18)

	_apply_button_style(socials_friend_list_button, "primary")
	_apply_button_style(socials_mail_button, "primary")
	_apply_button_style(socials_close_button)

func _setup_collapsible_panels() -> void:
	_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "right_center")
	_register_collapsible_panel("chat", chat_panel, "right")
	_register_collapsible_panel("player_status", player_status_panel, "left")
	_register_collapsible_panel("party", party_panel, "left")
	_register_collapsible_panel("location", location_panel, "right_center")
	_register_collapsible_panel("options", options_panel, "right")
	_register_collapsible_panel("actions", actions_panel, "action_bar", toggle_actions_collapse_button)
	_register_collapsible_panel("dex_actions", dex_actions_panel, "action_bar", dex_actions_collapse_button)
	_register_collapsible_panel("staff_actions", staff_actions_panel, "action_bar", staff_actions_collapse_button)
	_position_collapsible_buttons()

func _setup_chat_resize_button() -> void:
	chat_panel.custom_minimum_size = CHAT_MIN_SIZE
	chat_resize_button = Button.new()
	chat_resize_button.custom_minimum_size = COLLAPSE_BUTTON_SIZE
	chat_resize_button.size = COLLAPSE_BUTTON_SIZE
	chat_resize_button.text = "[]"
	chat_resize_button.tooltip_text = "Resize chat"
	chat_resize_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chat_resize_button.focus_mode = Control.FOCUS_NONE
	chat_resize_button.z_index = UI_BASE_Z_INDEX
	chat_resize_button.gui_input.connect(_on_chat_resize_button_gui_input)
	_connect_normal_ui_group_focus(chat_resize_button, chat_panel, false)
	root_control.add_child(chat_resize_button)
	_position_chat_resize_button()

func _on_chat_resize_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_focus_normal_ui_group(chat_panel)
		chat_resize_dragging = true
		chat_resize_drag_start_mouse = root_control.get_local_mouse_position()
		chat_resize_drag_start_rect = chat_panel.get_rect()
		get_viewport().set_input_as_handled()

func _register_collapsible_panel(panel_id: String, panel: Control, side: String, existing_button: Button = null) -> void:
	var button := existing_button
	if button == null:
		button = Button.new()
		root_control.add_child(button)
	button.custom_minimum_size = COLLAPSE_BUTTON_SIZE
	button.size = COLLAPSE_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = UI_BASE_Z_INDEX
	button.text = "-"
	button.tooltip_text = "Collapse"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_collapsible_panel_button_pressed.bind(panel_id))
	_connect_normal_ui_group_focus(button, panel, false)

	collapsible_panels[panel_id] = {
		"panel": panel,
		"button": button,
		"side": side,
		"collapsed": false,
		"available": true,
	}

func _on_collapsible_panel_button_pressed(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var panel: Control = state.get("panel") as Control
	_focus_normal_ui_group(panel)

	var collapsed := not bool(state.get("collapsed", false))
	state["collapsed"] = collapsed
	collapsible_panels[panel_id] = state
	_apply_collapsible_panel_state(panel_id)

func _set_collapsible_panel_available(panel_id: String, available: bool) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	state["available"] = available
	collapsible_panels[panel_id] = state
	_apply_collapsible_panel_state(panel_id)

func _apply_collapsible_panel_state(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var panel: Control = state.get("panel") as Control
	var button: Button = state.get("button") as Button
	if panel == null or button == null:
		return

	var available := bool(state.get("available", true))
	var collapsed := bool(state.get("collapsed", false))
	panel.visible = available and not collapsed
	button.visible = available
	button.text = "+" if collapsed else "-"
	button.tooltip_text = "Expand" if collapsed else "Collapse"
	if collapsed and panel_id == "staff_actions":
		dev_actions_popup.visible = false
		if staff_tools_popup != null:
			staff_tools_popup.visible = false
		if staff_impersonate_popup != null:
			staff_impersonate_popup.visible = false
	if collapsed and panel_id == "dex_actions":
		if item_dex_popup != null:
			item_dex_popup.visible = false
		if pokedex_popup != null:
			pokedex_popup.visible = false
	if panel_id == "chat":
		chat_tabs_panel.visible = available and not collapsed
		_position_chat_tabs_panel()
		_position_chat_resize_button()
	if panel_id == "options":
		_refresh_socials_attention_badge()
	_position_collapsible_button(panel_id)

func _position_collapsible_buttons() -> void:
	for panel_id_value: Variant in collapsible_panels.keys():
		var panel_id := str(panel_id_value)
		_position_collapsible_button(panel_id)
	_position_chat_tabs_panel()
	_position_chat_resize_button()

func _position_collapsible_button(panel_id: String) -> void:
	var state: Dictionary = collapsible_panels.get(panel_id, {})
	if state.is_empty():
		return

	var panel: Control = state.get("panel") as Control
	var button: Button = state.get("button") as Button
	if panel == null or button == null:
		return

	var side := str(state.get("side", "right"))
	var collapsed := bool(state.get("collapsed", false))
	var rect := panel.get_rect()
	var position := rect.position
	if collapsed:
		match side:
			"action_bar":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"left":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"right":
				position.x = rect.position.x
				position.y = rect.position.y
			"right_center":
				position.x = rect.position.x
				position.y = rect.position.y + ((rect.size.y - COLLAPSE_BUTTON_SIZE.y) / 2.0)
			"bottom":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			_:
				position.x = rect.position.x
				position.y = rect.position.y
	else:
		match side:
			"action_bar":
				position.x = rect.position.x - COLLAPSE_BUTTON_SIZE.x - COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y
			"left":
				position.x = rect.position.x - COLLAPSE_BUTTON_SIZE.x - COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y
			"right":
				position.x = rect.position.x + rect.size.x + COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y
			"right_center":
				position.x = rect.position.x + rect.size.x + COLLAPSE_BUTTON_MARGIN
				position.y = rect.position.y + ((rect.size.y - COLLAPSE_BUTTON_SIZE.y) / 2.0)
			"bottom":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y + rect.size.y + COLLAPSE_BUTTON_MARGIN
			_:
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y

	button.position = position
	button.size = COLLAPSE_BUTTON_SIZE

func _position_chat_resize_button() -> void:
	if chat_resize_button == null:
		return

	var state: Dictionary = collapsible_panels.get("chat", {})
	if state.is_empty():
		chat_resize_button.visible = false
		return

	var collapse_button: Button = state.get("button") as Button
	var available := bool(state.get("available", true))
	var collapsed := bool(state.get("collapsed", false))
	chat_resize_button.visible = available and not collapsed
	if not chat_resize_button.visible or collapse_button == null:
		return

	chat_resize_button.position = collapse_button.position + Vector2(0.0, COLLAPSE_BUTTON_SIZE.y + CHAT_RESIZE_BUTTON_GAP)
	chat_resize_button.size = COLLAPSE_BUTTON_SIZE

func _position_chat_tabs_panel() -> void:
	if chat_tabs_panel == null or chat_panel == null:
		return

	var state: Dictionary = collapsible_panels.get("chat", {})
	var available := bool(state.get("available", true))
	var collapsed := bool(state.get("collapsed", false))
	chat_tabs_panel.visible = available and not collapsed
	if not chat_tabs_panel.visible:
		return

	var tabs_size := chat_tabs_panel.get_combined_minimum_size()
	chat_tabs_panel.size = tabs_size
	chat_tabs_panel.position = chat_panel.position + Vector2(0.0, -tabs_size.y - CHAT_TABS_GAP)

func _set_chat_panel_size(size: Vector2) -> void:
	var clamped_size := Vector2(
		clampf(size.x, CHAT_MIN_SIZE.x, CHAT_MAX_SIZE.x),
		clampf(size.y, CHAT_MIN_SIZE.y, CHAT_MAX_SIZE.y)
	)
	chat_panel.offset_right = chat_panel.offset_left + clamped_size.x
	chat_panel.offset_top = chat_panel.offset_bottom - clamped_size.y
	_position_chat_tabs_panel()
	_position_collapsible_button("chat")
	_position_chat_resize_button()

func _is_settings_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE

func _close_active_overlay_for_escape() -> bool:
	var candidate: Dictionary = _get_active_escape_close_candidate()
	if candidate.is_empty():
		return false

	var close_callable: Callable = candidate.get("close", Callable())
	if not close_callable.is_valid():
		return false

	close_callable.call()
	return true

func _get_active_escape_close_candidate() -> Dictionary:
	var active_candidate: Dictionary = {}
	for candidate: Dictionary in _get_escape_close_candidates():
		var panel: Control = candidate.get("panel") as Control
		if panel == null or not panel.visible:
			continue
		if active_candidate.is_empty() or _is_escape_panel_above(panel, active_candidate.get("panel") as Control):
			active_candidate = candidate

	return active_candidate

func _get_escape_close_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = [
		{"panel": mail_compose_help_popup, "close": Callable(self, "_hide_mail_compose_help_popup")},
		{"panel": pokemon_summary_ev_allocate_popup, "close": Callable(self, "_hide_pokemon_summary_ev_allocate_popup")},
		{"panel": pokemon_summary_ball_picker, "close": Callable(self, "_hide_pokemon_summary_ball_picker_for_escape")},
		{"panel": pokemon_summary_item_picker, "close": Callable(self, "_hide_pokemon_summary_item_picker_for_escape")},
		{"panel": bag_item_use_popup, "close": Callable(self, "_hide_bag_item_use_popup_for_escape")},
		{"panel": mail_compose_popup, "close": Callable(self, "_on_mail_compose_close_button_pressed")},
		{"panel": staff_impersonate_popup, "close": Callable(self, "_hide_staff_impersonate_popup")},
		{"panel": dev_add_item_popup, "close": Callable(self, "_hide_dev_add_item_popup_for_escape")},
		{"panel": dev_add_money_popup, "close": Callable(self, "_hide_dev_add_money_popup_for_escape")},
		{"panel": dev_add_menu_popup, "close": Callable(self, "_hide_dev_add_menu_popup")},
		{"panel": dev_clear_menu_popup, "close": Callable(self, "_hide_dev_clear_menu_popup_for_escape")},
		{"panel": pvp_room_popup, "close": Callable(self, "_hide_pvp_room_popup")},
		{"panel": pokedex_popup, "close": Callable(self, "_hide_pokedex_popup")},
		{"panel": item_dex_popup, "close": Callable(self, "_hide_item_dex_popup")},
		{"panel": mail_popup, "close": Callable(self, "_on_mail_close_button_pressed")},
		{"panel": socials_menu, "close": Callable(self, "_hide_socials_menu")},
		{"panel": staff_tools_popup, "close": Callable(self, "_hide_staff_tools_popup")},
		{"panel": dev_pokemon_popup, "close": Callable(self, "_hide_dev_pokemon_popup_for_escape")},
		{"panel": dev_actions_popup, "close": Callable(self, "_hide_dev_actions_popup_for_escape")},
		{"panel": bag_popup, "close": Callable(self, "_hide_bag_popup_for_escape")},
		{"panel": trainer_card_popup, "close": Callable(self, "_hide_trainer_card_for_escape")},
		{"panel": settings_menu, "close": Callable(self, "_close_settings_menu_for_escape")},
	]

	for context_value: Variant in pokemon_summary_open_cards.values():
		if not (context_value is Dictionary):
			continue
		var context: Dictionary = context_value as Dictionary
		var summary_panel: Control = context.get("popup") as Control
		var card_key := str(context.get("key", ""))
		if summary_panel != null and card_key != "":
			candidates.append({
				"panel": summary_panel,
				"close": Callable(self, "_hide_pokemon_summary_popup").bind(card_key),
			})

	return candidates

func _is_escape_panel_above(panel: Control, other_panel: Control) -> bool:
	if other_panel == null:
		return true
	if panel.z_index != other_panel.z_index:
		return panel.z_index > other_panel.z_index

	var panel_parent := panel.get_parent()
	var other_parent := other_panel.get_parent()
	if panel_parent != null and panel_parent == other_parent:
		return panel.get_index() > other_panel.get_index()

	return false

func _hide_pokemon_summary_ball_picker_for_escape() -> void:
	if pokemon_summary_ball_picker != null:
		pokemon_summary_ball_picker.visible = false
	_store_active_pokemon_summary_card_context()

func _hide_pokemon_summary_item_picker_for_escape() -> void:
	if pokemon_summary_item_picker != null:
		pokemon_summary_item_picker.visible = false
	_store_active_pokemon_summary_card_context()

func _hide_bag_popup_for_escape() -> void:
	_hide_bag_popup()
	_deactivate_ui_panel(bag_popup)

func _hide_bag_item_use_popup_for_escape() -> void:
	_hide_bag_item_use_popup()
	_deactivate_ui_panel(bag_item_use_popup)

func _hide_dev_actions_popup_for_escape() -> void:
	if dev_actions_popup != null:
		dev_actions_popup.visible = false
		_deactivate_ui_panel(dev_actions_popup)

func _hide_dev_pokemon_popup_for_escape() -> void:
	_on_dev_pokemon_close_button_pressed()
	_deactivate_ui_panel(dev_pokemon_popup)

func _hide_dev_add_item_popup_for_escape() -> void:
	_hide_dev_add_item_popup()
	_deactivate_ui_panel(dev_add_item_popup)

func _hide_dev_add_money_popup_for_escape() -> void:
	_hide_dev_add_money_popup()
	_deactivate_ui_panel(dev_add_money_popup)

func _hide_dev_clear_menu_popup_for_escape() -> void:
	_hide_dev_clear_menu_popup()

func _hide_dev_clear_menu_popup() -> void:
	if dev_clear_menu_popup != null:
		dev_clear_menu_popup.visible = false
		_deactivate_ui_panel(dev_clear_menu_popup)

func _hide_trainer_card_for_escape() -> void:
	_hide_trainer_card()
	_deactivate_ui_panel(trainer_card_popup)

func _close_settings_menu_for_escape() -> void:
	if settings_menu.has_method("close"):
		settings_menu.call("close")
	else:
		settings_menu.visible = false
		_on_settings_menu_closed()
	_deactivate_ui_panel(settings_menu)

func _toggle_settings_menu() -> void:
	if settings_menu.visible:
		_close_settings_menu_for_escape()
		return

	_on_settings_button_pressed()

func _build_party_slots() -> void:
	party_slots.clear()

	party_slot_template.visible = false
	party_slots.append(party_slot_template)
	_register_party_slot_drag_handlers(party_slot_template, 0)

	for i in range(MAX_PARTY_SIZE - 1):
		var slot := party_slot_template.duplicate()
		party_container.add_child(slot)
		party_slots.append(slot)
		_register_party_slot_drag_handlers(slot, i + 1)

func _refresh_party() -> void:
	_set_collapsible_panel_available("party", PlayerSave.party.size() > 0)

	for slot_number in range(party_slots.size()):
		var slot = party_slots[slot_number]
		slot.set("slot_index", slot_number)

		if slot_number < PlayerSave.party.size():
			slot.set_pokemon(PlayerSave.party[slot_number])
		else:
			slot.set_empty()

	_refresh_open_pokemon_summary_cards()

func _register_party_slot_drag_handlers(slot: Node, slot_index: int) -> void:
	slot.set("slot_index", slot_index)
	var drag_started_callable := Callable(self, "_on_party_slot_drag_started")
	var drag_released_callable := Callable(self, "_on_party_slot_drag_released")
	var clicked_callable := Callable(self, "_on_party_slot_clicked")
	if slot.has_signal("drag_started") and not slot.is_connected("drag_started", drag_started_callable):
		slot.connect("drag_started", drag_started_callable)
	if slot.has_signal("drag_released") and not slot.is_connected("drag_released", drag_released_callable):
		slot.connect("drag_released", drag_released_callable)
	if slot.has_signal("clicked") and not slot.is_connected("clicked", clicked_callable):
		slot.connect("clicked", clicked_callable)

func _on_party_slot_clicked(slot_index: int) -> void:
	_focus_normal_ui_group(party_panel)
	if slot_index < 0 or slot_index >= PlayerSave.party.size():
		return
	_show_pokemon_summary(slot_index)

func _on_party_slot_drag_started(slot_index: int) -> void:
	_focus_normal_ui_group(party_panel)
	if slot_index < 0 or slot_index >= PlayerSave.party.size():
		return

	party_drag_start_index = slot_index
	party_dragging = true
	_start_party_drag_visual(slot_index)

func _on_party_slot_drag_released(_slot_index: int, global_position: Vector2) -> void:
	if not party_dragging:
		return

	_finish_party_drag(global_position)

func _handle_party_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_party_drag_visual_position()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_party_drag(mouse_event.global_position)
			get_viewport().set_input_as_handled()

func _start_party_drag_visual(slot_index: int) -> void:
	_clear_party_drag_visual()

	party_drag_source_slot = party_slots[slot_index] as Control
	if party_drag_source_slot == null:
		return

	var source_global_rect := party_drag_source_slot.get_global_rect()
	party_drag_pointer_offset = party_drag_source_slot.get_global_mouse_position() - source_global_rect.position
	party_drag_start_mouse_position = party_drag_source_slot.get_global_mouse_position()
	party_drag_source_slot.modulate = Color(1.0, 1.0, 1.0, 0.35)

	party_drag_visual = party_drag_source_slot.duplicate() as Control
	if party_drag_visual == null:
		return

	party_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_drag_visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	party_drag_visual.custom_minimum_size = source_global_rect.size
	party_drag_visual.size = source_global_rect.size
	party_drag_visual.z_index = UI_DRAG_Z_INDEX
	party_drag_visual.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_set_control_tree_mouse_filter(party_drag_visual, Control.MOUSE_FILTER_IGNORE)
	root_control.add_child(party_drag_visual)
	_update_party_drag_visual_position()

func _update_party_drag_visual_position() -> void:
	if party_drag_visual == null:
		return

	var local_mouse_position := root_control.get_local_mouse_position()
	party_drag_visual.position = local_mouse_position - party_drag_pointer_offset

func _finish_party_drag(global_position: Vector2) -> void:
	if not party_dragging:
		return

	party_dragging = false
	if _try_attach_party_drag_to_chat(global_position):
		party_drag_start_index = -1
		_clear_party_drag_visual()
		return

	var target_index := _get_party_slot_index_at_position(global_position)
	if target_index == party_drag_start_index and party_drag_start_mouse_position.distance_to(global_position) <= 8.0:
		var clicked_slot_index := party_drag_start_index
		party_drag_start_index = -1
		_clear_party_drag_visual()
		_show_pokemon_summary(clicked_slot_index)
		return

	if target_index < 0 or target_index >= PlayerSave.party.size() or target_index == party_drag_start_index:
		party_drag_start_index = -1
		_clear_party_drag_visual()
		return

	var source_index := party_drag_start_index
	var dragged_pokemon: Pokemon = PlayerSave.party[source_index]
	PlayerSave.party[source_index] = PlayerSave.party[target_index]
	PlayerSave.party[target_index] = dragged_pokemon
	party_drag_start_index = -1
	_clear_party_drag_visual()
	PlayerSave.party_changed.emit()
	var result: Dictionary = await PlayerPartyStateService.swap_party_slots(source_index, target_index)
	if not bool(result.get("success", false)):
		PlayerSave.party[target_index] = PlayerSave.party[source_index]
		PlayerSave.party[source_index] = dragged_pokemon
		PlayerSave.party_changed.emit()
		_add_chat_message("Could not save party order. Please report this to staff.")
		push_warning("UIOverlay: party swap failed: %s" % str(result.get("error", "Unknown error")))

func _clear_party_drag_visual() -> void:
	if party_drag_source_slot != null:
		party_drag_source_slot.modulate = Color.WHITE
	party_drag_source_slot = null

	if party_drag_visual != null:
		party_drag_visual.queue_free()
	party_drag_visual = null

func _setup_chat_pokemon_attachment_preview() -> void:
	_refresh_pending_chat_pokemon_attachment_preview()

func _try_attach_party_drag_to_chat(global_position: Vector2) -> bool:
	if party_drag_start_index < 0 or party_drag_start_index >= PlayerSave.party.size():
		return false
	if chat_panel == null or not chat_panel.visible:
		return false
	if not chat_panel.get_global_rect().has_point(global_position):
		return false

	var pokemon: Pokemon = PlayerSave.party[party_drag_start_index]
	pending_chat_pokemon_attachments.append(pokemon.to_persistence_dict())
	_refresh_pending_chat_pokemon_attachment_preview()
	chat_input.grab_focus()
	return true

func _refresh_pending_chat_pokemon_attachment_preview() -> void:
	for button: Button in chat_pokemon_attachment_buttons:
		if button != null:
			button.queue_free()
	chat_pokemon_attachment_buttons.clear()

	for index in range(pending_chat_pokemon_attachments.size()):
		var pokemon_payload: Dictionary = pending_chat_pokemon_attachments[index]
		var button := _create_pending_chat_pokemon_button(pokemon_payload, index)
		chat_input_row.add_child(button)
		chat_input_row.move_child(button, chat_input.get_index())
		chat_pokemon_attachment_buttons.append(button)

func _create_pending_chat_pokemon_button(pokemon_payload: Dictionary, index: int) -> Button:
	var species: String = str(pokemon_payload.get("species", "Pokemon"))
	var shiny: bool = bool(pokemon_payload.get("shiny", false))
	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Attached: %s. Click to remove." % species
	button.pressed.connect(_remove_pending_chat_pokemon_attachment.bind(index))
	_apply_button_style(button)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = PokemonAssets.load_home_sprite(species, shiny)
	if icon.texture == null:
		icon.texture = PokemonAssets.load_party_icon(species, shiny)
	button.add_child(icon)
	return button

func _remove_pending_chat_pokemon_attachment(index: int) -> void:
	if index >= 0 and index < pending_chat_pokemon_attachments.size():
		pending_chat_pokemon_attachments.remove_at(index)
	_refresh_pending_chat_pokemon_attachment_preview()
	if pending_chat_pokemon_attachments.is_empty():
		_apply_chat_tab_state()

func _clear_pending_chat_pokemon_attachments() -> void:
	pending_chat_pokemon_attachments.clear()
	_refresh_pending_chat_pokemon_attachment_preview()
	_apply_chat_tab_state()

func _set_control_tree_mouse_filter(node: Node, mouse_filter_value: int) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = mouse_filter_value

	for child: Node in node.get_children():
		_set_control_tree_mouse_filter(child, mouse_filter_value)

func _get_party_slot_index_at_position(global_position: Vector2) -> int:
	for slot_index in range(party_slots.size()):
		var slot := party_slots[slot_index] as Control
		if slot == null or not slot.visible:
			continue
		if slot.get_global_rect().has_point(global_position):
			return slot_index

	return -1

func _on_send_button_pressed() -> void:
	if active_chat_tab == CHAT_TAB_SYSTEM:
		return

	_submit_chat_input_deferred()

func _on_chat_text_submitted(_text: String) -> void:
	if active_chat_tab == CHAT_TAB_SYSTEM:
		return

	_submit_chat_input_deferred()

func _on_chat_tab_pressed(tab_id: String) -> void:
	if active_chat_tab == tab_id:
		return

	active_chat_tab = tab_id
	_apply_chat_tab_state()

func _apply_chat_tab_state() -> void:
	var input_active: bool = active_chat_tab != CHAT_TAB_SYSTEM
	var general_active: bool = active_chat_tab == CHAT_TAB_GENERAL
	general_chat_tab_button.add_theme_color_override("font_color", Color(CHAT_SYSTEM_LABEL_COLOR if general_active else CHAT_MESSAGE_COLOR))
	trade_chat_tab_button.add_theme_color_override("font_color", Color(CHAT_SYSTEM_LABEL_COLOR if active_chat_tab == CHAT_TAB_TRADE else CHAT_MESSAGE_COLOR))
	system_chat_tab_button.add_theme_color_override("font_color", Color(CHAT_SYSTEM_LABEL_COLOR if active_chat_tab == CHAT_TAB_SYSTEM else CHAT_MESSAGE_COLOR))
	chat_input.editable = input_active
	chat_input.placeholder_text = "Trade chat has a 2 minute cooldown" if active_chat_tab == CHAT_TAB_TRADE else ("" if input_active else "System messages only")
	send_button.disabled = not input_active
	if not input_active:
		chat_input.release_focus()
	_refresh_chat_message_visibility()
	_scroll_chat_to_bottom.call_deferred()

func _refresh_chat_message_visibility() -> void:
	for child: Node in message_list.get_children():
		if child == message_entry_template:
			continue

		var category: String = str(child.get_meta("chat_category", CHAT_CATEGORY_USER))
		child.visible = _should_show_chat_category(category)

func _submit_chat_input_deferred() -> void:
	if chat_submit_in_progress:
		return

	chat_submit_in_progress = true
	_submit_chat_input_async.call_deferred()

func _submit_chat_input_async() -> void:
	var text := chat_input.text.strip_edges()
	if text.to_lower() == "/team":
		await _share_party_to_chat()
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	var pokemon_attachments: Array[Dictionary] = _get_chat_pokemon_attachments_with_current_trainer(
		pending_chat_pokemon_attachments,
		PlayerSave.player_name,
		PlayerSave.player_id
	)
	if text == "" and pokemon_attachments.is_empty():
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	chat_input.clear()
	if text.begins_with("/"):
		_add_chat_message("Command not recognized.")
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if not ChatRealtimeService.send_chat_message(text, _get_active_chat_channel(), pokemon_attachments):
		_add_chat_message("Chat is reconnecting. Please try again in a moment.")
	else:
		_clear_pending_chat_pokemon_attachments()
	chat_submit_in_progress = false
	_keep_chat_input_focused()

func _share_party_to_chat() -> void:
	if PlayerSave.party.is_empty():
		_add_chat_message("You need a Pokemon in your party first.")
		return

	var attachments: Array[Dictionary] = []
	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null:
			attachments.append(_pokemon_preview_payload_with_current_trainer(
				pokemon.to_persistence_dict(),
				PlayerSave.player_name,
				PlayerSave.player_id
			))

	chat_input.clear()
	if not ChatRealtimeService.send_chat_message("", _get_active_chat_channel(), attachments):
		_add_chat_message("Chat is reconnecting. Please try again in a moment.")

func _get_active_chat_channel() -> String:
	if active_chat_tab == CHAT_TAB_TRADE:
		return CHAT_CHANNEL_TRADE
	return CHAT_CHANNEL_GLOBAL

func _keep_chat_input_focused() -> void:
	_restore_chat_input_focus.call_deferred()

func _restore_chat_input_focus() -> void:
	chat_input.grab_focus()
	chat_input.caret_column = chat_input.text.length()

func _handle_start_encounter_command(pokemon_text: String) -> bool:
	pokemon_text = _clean_encounter_paste_text(pokemon_text)
	if pokemon_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste set first.")
		return false

	if PlayerSave.party.is_empty():
		_add_chat_message("You need a Pokemon in your party first.")
		return false

	var world := GameState.get_world()
	if world == null or not world.has_method("start_dev_wild_battle"):
		_add_chat_message("Cannot start a wild battle from here.")
		return false

	_add_chat_message("Creating wild Pokemon...")
	var response: Dictionary = await PokemonDataApiClient.create_pokemon_from_text(parse_pokemon_request, pokemon_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		_add_chat_message("Create failed: response did not include Pokemon data.")
		return false

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
	if pokemon == null:
		print_debug("Dev encounter Pokemon failed after backend create. pokemon_data=", pokemon_data, " response=", response)
		var reason: String = PokemonFactory.last_error_message
		if reason == "":
			reason = "Unknown reason."

		_add_chat_message("Could not create wild Pokemon. Reason: %s" % reason)
		return false

	_add_chat_message("Starting wild encounter: %s Lv. %s." % [pokemon.species, pokemon.level])
	await world.start_dev_wild_battle(pokemon)
	return true

func _handle_add_pokemon_command(pokemon_text: String) -> bool:
	pokemon_text = _clean_pokemon_paste_text(pokemon_text)
	if pokemon_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste set first.")
		return false

	if PlayerSave.party.size() >= MAX_PARTY_SIZE:
		_add_chat_message("Party is full.")
		return false

	_add_chat_message("Creating Pokemon...")
	var response: Dictionary = await PokemonDataApiClient.create_pokemon_from_text(parse_pokemon_request, pokemon_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var pokemon_value: Variant = response.get("pokemon", {})
	if not (pokemon_value is Dictionary):
		_add_chat_message("Create failed: response did not include Pokemon data.")
		return false

	var parsed_pokemon_data: Dictionary = pokemon_value as Dictionary
	var parsed_pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(parsed_pokemon_data)
	if parsed_pokemon == null:
		print_debug("Dev add Pokemon failed after backend create. pokemon_data=", parsed_pokemon_data, " response=", response)
		var reason: String = PokemonFactory.last_error_message
		if reason == "":
			reason = "Unknown reason."

		_add_chat_message("Could not create Pokemon from backend data. Reason: %s" % reason)
		return false

	var create_result: Dictionary = await PlayerPartyStateService.dev_create_pokemon(parsed_pokemon_data, true)
	if not bool(create_result.get("success", false)):
		_add_chat_message("Could not save Pokemon: %s" % str(create_result.get("error", "Unknown error")))
		return false

	var pokemon: Pokemon = _pokemon_from_create_result(create_result, parsed_pokemon)
	_add_chat_message("Added %s Lv. %s to party." % [pokemon.species, pokemon.level])
	return true

func _handle_add_team_command(team_text: String) -> bool:
	team_text = _clean_team_paste_text(team_text)
	if team_text.strip_edges() == "":
		_add_chat_message("Paste a Showdown/Pokepaste team first.")
		return false

	var open_slots: int = MAX_PARTY_SIZE - PlayerSave.party.size()
	if open_slots <= 0:
		_add_chat_message("Party is full.")
		return false

	_add_chat_message("Creating team...")
	var response: Dictionary = await PokemonDataApiClient.create_team_from_text(parse_pokemon_request, team_text)
	if not bool(response.get("success", false)):
		_add_chat_message("Create failed: %s" % str(response.get("error", "Unknown error")))
		return false

	var team_value: Variant = response.get("team", [])
	if not (team_value is Array):
		_add_chat_message("Create failed: response did not include team data.")
		return false

	var team_data: Array = team_value as Array
	if team_data.is_empty():
		_add_chat_message("Create failed: team was empty.")
		return false
	if team_data.size() > open_slots:
		_add_chat_message("Not enough party space. Open slots: %s, parsed Pokemon: %s." % [open_slots, team_data.size()])
		return false

	var parsed_pokemon_payloads: Array[Dictionary] = []
	for index in range(team_data.size()):
		var pokemon_value: Variant = team_data[index]
		if not (pokemon_value is Dictionary):
			_add_chat_message("Could not create team. Reason: Pokemon %s did not include Pokemon data." % [index + 1])
			return false

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
		if pokemon == null:
			print_debug("Dev add team Pokemon failed after backend create. index=", index, " pokemon_data=", pokemon_data, " response=", response)
			var reason: String = PokemonFactory.last_error_message
			if reason == "":
				reason = "Unknown reason."

			_add_chat_message("Could not create team. Pokemon %s reason: %s" % [index + 1, reason])
			return false

		parsed_pokemon_payloads.append(pokemon_data)

	var created_count := 0
	for pokemon_data: Dictionary in parsed_pokemon_payloads:
		var create_result: Dictionary = await PlayerPartyStateService.dev_create_pokemon(pokemon_data, true)
		if not bool(create_result.get("success", false)):
			_add_chat_message("Created %s Pokemon, then failed: %s" % [created_count, str(create_result.get("error", "Unknown error"))])
			return false
		created_count += 1

	_add_chat_message("Added %s Pokemon to party." % created_count)
	return true

func _pokemon_from_create_result(create_result: Dictionary, fallback: Pokemon) -> Pokemon:
	var pokemon_response: Dictionary = {}
	var pokemon_response_value: Variant = create_result.get("pokemon", {})
	if pokemon_response_value is Dictionary:
		pokemon_response = pokemon_response_value as Dictionary

	var pokemon_payload_value: Variant = pokemon_response.get("pokemon", {})
	if pokemon_payload_value is Dictionary:
		var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_payload_value as Dictionary)
		if pokemon != null:
			return pokemon

	return fallback

func _clean_pokemon_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")
	return cleaned_text

func _clean_team_paste_text(team_text: String) -> String:
	var cleaned_text := team_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")
	return cleaned_text

func _clean_encounter_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")
	return cleaned_text

func _on_dev_pokemon_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	_show_dev_pokemon_popup(DevPokemonPopupMode.POKEMON)

func _on_repel_toggle_toggled(toggled_on: bool) -> void:
	GameState.repel_enabled = toggled_on
	_set_icon_slot_active(repel_slot, GameState.repel_enabled)
	var state_text := "enabled" if GameState.repel_enabled else "disabled"
	_add_chat_message("Repel %s." % state_text)
	await _save_toggle_preferences()

func _load_toggle_preferences() -> void:
	var result: Dictionary = await PlayerGameStateService.load_player_preferences()
	if not bool(result.get("success", false)):
		push_warning("UIOverlay: toggle preference load failed: %s" % str(result.get("error", "Unknown error")))
		return

	var preferences_value: Variant = result.get("preferences", {})
	var preferences: Dictionary = preferences_value if preferences_value is Dictionary else {}
	GameState.show_follower = bool(preferences.get("showFollower", true))
	GameState.repel_enabled = bool(preferences.get("showRepel", GameState.repel_enabled))
	GameState.running_shoes_enabled = bool(preferences.get("runningShoes", GameState.running_shoes_enabled))
	running_shoes_button.set_pressed_no_signal(GameState.running_shoes_enabled)
	_set_icon_slot_active(running_shoes_slot, GameState.running_shoes_enabled)
	repel_toggle_button.set_pressed_no_signal(GameState.repel_enabled)
	_set_icon_slot_active(repel_slot, GameState.repel_enabled)
	follower_toggle_button.set_pressed_no_signal(GameState.show_follower)
	_set_icon_slot_active(follower_slot, GameState.show_follower)
	_refresh_world_running_shoes_state()
	_refresh_world_follower_visibility()

func _on_follower_toggle_toggled(toggled_on: bool) -> void:
	GameState.show_follower = toggled_on
	_set_icon_slot_active(follower_slot, GameState.show_follower)
	_refresh_world_follower_visibility()
	await _save_toggle_preferences()

func _save_toggle_preferences() -> void:
	var result: Dictionary = await PlayerGameStateService.save_player_preferences({
		"showFollower": GameState.show_follower,
		"showRepel": GameState.repel_enabled,
		"runningShoes": GameState.running_shoes_enabled,
	})
	if not bool(result.get("success", false)):
		_add_chat_message("Could not save toggle settings. Please contact staff.")
		push_warning("UIOverlay: toggle preference save failed: %s" % str(result.get("error", "Unknown error")))
		return

	var preferences_value: Variant = result.get("preferences", {})
	if preferences_value is Dictionary:
		var preferences: Dictionary = preferences_value as Dictionary
		GameState.show_follower = bool(preferences.get("showFollower", GameState.show_follower))
		GameState.repel_enabled = bool(preferences.get("showRepel", GameState.repel_enabled))
		GameState.running_shoes_enabled = bool(preferences.get("runningShoes", GameState.running_shoes_enabled))

func _refresh_world_follower_visibility() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var player := tree.get_first_node_in_group("player")
	if player == null:
		var world := GameState.get_world()
		if world != null:
			player = world.get_node_or_null("Player")

	if player != null and player.has_method("set_show_follower"):
		player.call("set_show_follower", GameState.show_follower)

func _refresh_world_running_shoes_state() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var player_node := tree.get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_running_shoes_enabled"):
		player_node.call("set_running_shoes_enabled", GameState.running_shoes_enabled)

func _on_dev_actions_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = not dev_actions_popup.visible
	if dev_actions_popup.visible:
		_activate_ui_panel(dev_actions_popup)
	else:
		_deactivate_ui_panel(dev_actions_popup)

func _on_staff_tools_button_pressed() -> void:
	if not _can_impersonate_accounts():
		return
	if staff_tools_popup == null:
		return

	staff_tools_popup.visible = not staff_tools_popup.visible
	if staff_tools_popup.visible:
		_activate_ui_panel(staff_tools_popup)
	else:
		_deactivate_ui_panel(staff_tools_popup)

func _hide_staff_tools_popup() -> void:
	if staff_tools_popup != null:
		staff_tools_popup.visible = false
		_deactivate_ui_panel(staff_tools_popup)

func _on_staff_impersonate_button_pressed() -> void:
	if not _can_impersonate_accounts():
		_add_chat_message("You do not have permission to impersonate accounts.")
		return
	if staff_impersonate_popup == null:
		return
	staff_impersonate_popup.visible = not staff_impersonate_popup.visible
	if staff_impersonate_popup.visible and staff_impersonate_token_input != null:
		_activate_ui_panel(staff_impersonate_popup)
		staff_impersonate_token_input.grab_focus()
	elif not staff_impersonate_popup.visible:
		_deactivate_ui_panel(staff_impersonate_popup)

func _hide_staff_impersonate_popup() -> void:
	if staff_impersonate_popup != null:
		staff_impersonate_popup.visible = false
		_deactivate_ui_panel(staff_impersonate_popup)

func _on_staff_impersonate_confirm_pressed() -> void:
	if not _can_impersonate_accounts():
		_add_chat_message("You do not have permission to impersonate accounts.")
		return
	if staff_impersonate_token_input == null:
		return

	var token := staff_impersonate_token_input.text.strip_edges()
	if token == "":
		_add_chat_message("Enter an impersonation token first.")
		return

	if staff_impersonate_confirm_button != null:
		staff_impersonate_confirm_button.disabled = true

	var auth_result: Dictionary = await AuthService.impersonate_with_token(token)
	if not auth_result.get("success", false):
		if staff_impersonate_confirm_button != null:
			staff_impersonate_confirm_button.disabled = false
		_add_chat_message("Impersonation failed: %s" % str(auth_result.get("error", "Invalid token")))
		return

	var profile_result: Dictionary = await PlayerGameStateService.load_player_profile()
	if staff_impersonate_confirm_button != null:
		staff_impersonate_confirm_button.disabled = false
	if not profile_result.get("success", false):
		_add_chat_message("Impersonated login succeeded, but profile loading failed.")
		return

	_apply_impersonated_profile(profile_result)
	if staff_impersonate_token_input != null:
		staff_impersonate_token_input.text = ""
	_hide_staff_impersonate_popup()
	_refresh_dev_tools_visibility()
	_refresh_party()
	_add_chat_message("Now impersonating %s." % AuthService.get_display_name())

func _apply_impersonated_profile(profile_response: Dictionary) -> void:
	var user: Dictionary = _staff_dictionary_from_variant(profile_response.get("user", {}))
	var preferences: Dictionary = _staff_dictionary_from_variant(profile_response.get("preferences", {}))
	var party_response: Dictionary = _staff_dictionary_from_variant(profile_response.get("party", {}))
	var position_response: Dictionary = _staff_dictionary_from_variant(profile_response.get("position", {}))
	var wallet: Dictionary = _staff_dictionary_from_variant(profile_response.get("wallet", {}))
	var stats_response: Dictionary = _staff_dictionary_from_variant(profile_response.get("stats", {}))
	var stats: Dictionary = _staff_dictionary_from_variant(stats_response.get("stats", {}))

	PlayerSave.player_name = str(user.get("displayName", user.get("username", PlayerSave.player_name)))
	PlayerSave.gender = CharacterAppearanceService.normalize_gender(str(user.get("gender", PlayerSave.gender)))
	PlayerSave.ensure_body_matches_gender()
	PlayerSave.money = max(int(wallet.get("money", PlayerSave.money)), 0)
	PlayerSave.playtime_seconds = max(int(stats.get("playtimeSeconds", PlayerSave.playtime_seconds)), 0)
	_apply_impersonated_saved_world_state(position_response)

	if bool(party_response.get("hasParty", false)):
		var party_value: Variant = party_response.get("party", [])
		if party_value is Array:
			PlayerSave.replace_party_from_state(party_value as Array)
		else:
			PlayerSave.replace_party_from_state([])
	else:
		PlayerSave.replace_party_from_state([])

	if preferences.has("textSpeed"):
		PlayerSave.text_speed = str(preferences.get("textSpeed"))
	if preferences.has("battleStyle"):
		PlayerSave.battle_style = str(preferences.get("battleStyle"))
	if preferences.has("soundVolume"):
		PlayerSave.sound_volume = float(preferences.get("soundVolume"))
	if preferences.has("musicVolume"):
		PlayerSave.music_volume = float(preferences.get("musicVolume"))
	if preferences.has("showFollower"):
		GameState.show_follower = bool(preferences.get("showFollower"))
		follower_toggle_button.set_pressed_no_signal(GameState.show_follower)
		_set_icon_slot_active(follower_slot, GameState.show_follower)
		_refresh_world_follower_visibility()
	if preferences.has("showRepel"):
		GameState.repel_enabled = bool(preferences.get("showRepel"))
		repel_toggle_button.set_pressed_no_signal(GameState.repel_enabled)
		_set_icon_slot_active(repel_slot, GameState.repel_enabled)
	if preferences.has("runningShoes"):
		GameState.running_shoes_enabled = bool(preferences.get("runningShoes"))
		running_shoes_button.set_pressed_no_signal(GameState.running_shoes_enabled)
		_set_icon_slot_active(running_shoes_slot, GameState.running_shoes_enabled)
		_refresh_world_running_shoes_state()

	_refresh_player_status_card()
	_refresh_avatar_previews()
	_refresh_world_player_display_name()
	mail_ids_initialized = false
	play_existing_mail_notification_on_next_inbox_load = true
	known_mail_ids.clear()
	_reset_impersonated_account_caches()
	_load_mailbox.call_deferred()
	if trainer_card_popup != null and trainer_card_popup.visible:
		_rebuild_trainer_card_popup(true)

func _refresh_world_player_display_name() -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node == null:
		var world := GameState.get_world()
		if world != null:
			player_node = world.get_node_or_null("Player")
	if player_node != null and player_node.has_method("set_display_name"):
		player_node.call("set_display_name", PlayerSave.player_name, true)
	if player_node != null and player_node.has_method("refresh_appearance"):
		player_node.call("refresh_appearance")
	elif player_node != null and player_node.has_method("set_body_appearance"):
		player_node.call("set_body_appearance", PlayerSave.appearance_body_id)
	if player_node != null and player_node.has_method("set_role_from_user"):
		player_node.call("set_role_from_user", AuthService.current_user)

func _reset_impersonated_account_caches() -> void:
	bag_inventory_items = []
	bag_inventory_loaded = false
	bag_inventory_loading = false
	if bag_popup != null and bag_popup.visible:
		_load_bag_inventory()

	var world := GameState.get_world()
	if world != null and world.has_method("_publish_world_presence"):
		world.call("_publish_world_presence", true)

func _apply_impersonated_saved_world_state(position_response: Dictionary) -> void:
	if not bool(position_response.get("hasState", false)):
		_reset_impersonated_appearance_to_defaults()
		GameState.set_prepared_world_state({})
		return
	var state: Dictionary = _staff_dictionary_from_variant(position_response.get("state", {}))
	var appearance: Dictionary = _staff_dictionary_from_variant(state.get("appearance", {}))
	if not appearance.is_empty():
		PlayerSave.apply_appearance_state(appearance)
	else:
		_reset_impersonated_appearance_to_defaults()

	GameState.set_prepared_world_state({
		"savedState": state,
		"hasSavedState": not state.is_empty(),
	})

	var position_data: Dictionary = _staff_dictionary_from_variant(state.get("position", {}))
	if position_data.is_empty():
		return

	var saved_position := Vector2(
		float(position_data.get("x", GameState.player_position.x)),
		float(position_data.get("y", GameState.player_position.y))
	)
	GameState.player_position = saved_position
	GameState.has_player_position = true

	var saved_scene_path := str(state.get("mapScenePath", "")).strip_edges()
	var current_scene_path := ""
	if GameState.current_map != null:
		current_scene_path = str(GameState.current_map.scene_file_path).strip_edges()
	if saved_scene_path != "" and current_scene_path != "" and saved_scene_path != current_scene_path:
		return

	var player_node := get_tree().get_first_node_in_group("player")
	if player_node == null:
		var world := GameState.get_world()
		if world != null:
			player_node = world.get_node_or_null("Player")
	if player_node == null:
		return

	player_node.global_position = saved_position
	player_node.set("target_position", saved_position)
	player_node.set("move_start_position", saved_position)
	var facing_direction := _direction_from_name(str(state.get("facingDirection", "")))
	if facing_direction != Vector2.ZERO:
		GameState.player_direction = facing_direction
		player_node.set("last_direction", facing_direction)

func _direction_from_name(direction_name: String) -> Vector2:
	match direction_name.strip_edges().to_lower():
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.ZERO

func _reset_impersonated_appearance_to_defaults() -> void:
	PlayerSave.appearance_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID if PlayerSave.gender == "female" else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	PlayerSave.appearance_hair_id = CharacterAppearanceService.get_default_part_id("hair", PlayerSave.gender)
	PlayerSave.appearance_headgear_id = CharacterAppearanceService.get_default_part_id("headgear", PlayerSave.gender)
	PlayerSave.appearance_facegear_id = CharacterAppearanceService.get_default_part_id("facegear", PlayerSave.gender)
	PlayerSave.appearance_top_id = CharacterAppearanceService.get_default_part_id("top", PlayerSave.gender)
	PlayerSave.appearance_bottom_id = CharacterAppearanceService.get_default_part_id("bottom", PlayerSave.gender)
	PlayerSave.appearance_shoes_id = CharacterAppearanceService.get_default_part_id("shoes", PlayerSave.gender)
	PlayerSave.sync_hair_style_index_from_id()
	PlayerSave.appearance_hair_color = CharacterAppearanceService.DEFAULT_HAIR_COLOR
	PlayerSave.appearance_skin_tone = CharacterAppearanceService.DEFAULT_SKIN_TONE
	PlayerSave.appearance_eye_color = CharacterAppearanceService.DEFAULT_EYE_COLOR
	PlayerSave.ensure_body_matches_gender()

func _rebuild_trainer_card_popup(keep_visible: bool) -> void:
	if trainer_card_popup == null:
		return

	var old_offset_left := trainer_card_popup.offset_left
	var old_offset_top := trainer_card_popup.offset_top
	var old_offset_right := trainer_card_popup.offset_right
	var old_offset_bottom := trainer_card_popup.offset_bottom
	trainer_card_popup.queue_free()
	trainer_card_popup = null
	trainer_card_avatar_viewports.clear()
	trainer_card_body_buttons.clear()
	trainer_card_part_buttons.clear()
	trainer_card_color_buttons.clear()
	trainer_card_appearance_save_button = null
	trainer_card_appearance_status_label = null
	trainer_card_money_label = null
	trainer_card_playtime_label = null
	trainer_card_name_label = null
	_setup_trainer_card_popup()
	trainer_card_popup.offset_left = old_offset_left
	trainer_card_popup.offset_top = old_offset_top
	trainer_card_popup.offset_right = old_offset_right
	trainer_card_popup.offset_bottom = old_offset_bottom
	trainer_card_popup.visible = keep_visible
	if keep_visible:
		_activate_ui_panel(trainer_card_popup)

func _staff_dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _on_item_dex_button_pressed() -> void:
	await _show_item_dex_popup()

func _on_pokedex_button_pressed() -> void:
	await _show_pokedex_popup()

func _on_content_creator_tools_button_pressed() -> void:
	if not _can_use_content_creator_tools():
		return
	_add_chat_message("Content Creator Tools are not implemented yet.")

func _show_item_dex_popup() -> void:
	_position_item_dex_popup()
	item_dex_popup.visible = true
	_activate_ui_panel(item_dex_popup)
	item_dex_search_input.grab_focus.call_deferred()
	await _refresh_item_dex_results()

func _hide_item_dex_popup() -> void:
	item_dex_popup.visible = false
	_deactivate_ui_panel(item_dex_popup)

func _show_pokedex_popup() -> void:
	if pokedex_popup == null:
		return
	_position_pokedex_popup()
	pokedex_popup.visible = true
	_activate_ui_panel(pokedex_popup)
	if pokedex_search_input != null:
		pokedex_search_input.grab_focus.call_deferred()
	await _refresh_pokedex_results()

func _hide_pokedex_popup() -> void:
	if pokedex_popup != null:
		pokedex_popup.visible = false
		_deactivate_ui_panel(pokedex_popup)

func _on_pokedex_search_changed(_text: String) -> void:
	pokedex_search_request_id += 1
	if pokedex_search_debounce_timer == null:
		_refresh_pokedex_results()
		return
	pokedex_search_debounce_timer.start()

func _refresh_pokedex_results() -> void:
	if pokedex_results_list == null:
		return
	for child: Node in pokedex_results_list.get_children():
		child.queue_free()

	var query := ""
	if pokedex_search_input != null:
		query = pokedex_search_input.text.strip_edges()

	var loading_label := Label.new()
	loading_label.text = "Searching..."
	loading_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	pokedex_results_list.add_child(loading_label)

	pokedex_search_request_id += 1
	var request_id := pokedex_search_request_id
	var search_result: Dictionary = await PokedexService.search_species(query, 80)
	if request_id != pokedex_search_request_id:
		return

	for child: Node in pokedex_results_list.get_children():
		child.queue_free()

	if not bool(search_result.get("success", false)):
		var error_label := Label.new()
		error_label.text = "Could not load species."
		error_label.add_theme_color_override("font_color", UI_DANGER)
		pokedex_results_list.add_child(error_label)
		return

	var species_results: Array = _array_from_variant(search_result.get("species", []))
	var count := 0
	var first_species_id := ""
	for species_value: Variant in species_results:
		if typeof(species_value) != TYPE_DICTIONARY:
			continue
		var species: Dictionary = species_value
		var species_id := str(species.get("id", "")).strip_edges()
		if first_species_id == "" and species_id != "":
			first_species_id = species_id
		pokedex_results_list.add_child(_create_pokedex_species_button(species))
		count += 1

	if count == 0:
		var empty_label := Label.new()
		empty_label.text = "No species results."
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokedex_results_list.add_child(empty_label)
	elif pokedex_selected_species_id == "" and pokedex_selected_species.is_empty() and first_species_id != "":
		await _on_pokedex_species_selected(first_species_id)

func _create_pokedex_species_button(species: Dictionary) -> Control:
	var species_id := str(species.get("id", "")).strip_edges()
	var species_name := str(species.get("name", species_id))
	var national_number := int(species.get("nationalDexNumber", 0))
	var type_text := _format_pokedex_type_list(_array_from_variant(species.get("types", [])))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s%s" % [species_name, " - %s" % type_text if type_text != "" else ""]
	button.pressed.connect(_on_pokedex_species_selected.bind(species_id))
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#07111ed8"), Color("#d6c78f44"), 3, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#10213aee"), Color("#d6c78faa"), 3, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#050a12ee"), Color("#d6c78f"), 3, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("#10213aee"), UI_BORDER_FOCUS, 3, 1))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_pokedex_species_list_icon(species)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var number_label := Label.new()
	number_label.text = "#%03d" % national_number if national_number > 0 else "#---"
	number_label.custom_minimum_size = Vector2(44, 0)
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 11)
	number_label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	row.add_child(number_label)

	var label_stack := VBoxContainer.new()
	label_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_stack.add_theme_constant_override("separation", 0)
	row.add_child(label_stack)

	var name_label := Label.new()
	name_label.text = species_name
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	label_stack.add_child(name_label)

	var meta_label := Label.new()
	meta_label.text = type_text if type_text != "" else "Unknown type"
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	label_stack.add_child(meta_label)
	return button

func _on_pokedex_species_selected(species_id: String) -> void:
	var normalized_species_id := species_id.strip_edges()
	if normalized_species_id == "":
		return

	_set_pokedex_detail_message("Loading species...")
	var detail_result: Dictionary = await PokedexService.get_species_detail(normalized_species_id)
	if not bool(detail_result.get("success", false)):
		pokedex_selected_species = {}
		_set_pokedex_header_from_species({})
		_set_pokedex_detail_message("Could not load species.")
		return

	var species_value: Variant = detail_result.get("species", {})
	if typeof(species_value) != TYPE_DICTIONARY:
		pokedex_selected_species = {}
		_set_pokedex_header_from_species({})
		_set_pokedex_detail_message("Species detail is empty.")
		return

	pokedex_selected_species = species_value
	pokedex_selected_species_id = normalized_species_id
	pokedex_sprite_side = "front"
	_set_pokedex_header_from_species(pokedex_selected_species)
	_refresh_pokedex_detail()

func _create_pokedex_tab_button(tab_id: String, label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(84, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pokedex_tab_pressed.bind(tab_id))
	pokedex_tab_buttons[tab_id] = button
	return button

func _on_pokedex_tab_pressed(tab_id: String) -> void:
	if pokedex_active_tab == tab_id:
		return
	pokedex_active_tab = tab_id
	_refresh_pokedex_tab_buttons()
	_refresh_pokedex_detail()

func _refresh_pokedex_tab_buttons() -> void:
	for tab_id_value: Variant in pokedex_tab_buttons.keys():
		var tab_id := str(tab_id_value)
		var button: Button = pokedex_tab_buttons.get(tab_id) as Button
		if button == null:
			continue
		_apply_button_style(button, "primary" if tab_id == pokedex_active_tab else "default")

func _set_pokedex_header_from_species(species: Dictionary) -> void:
	if pokedex_name_label == null or pokedex_meta_label == null:
		return

	if species.is_empty():
		pokedex_name_label.text = "Select a species"
		pokedex_meta_label.text = "No species selected."
		_clear_pokedex_species_sprite()
		_refresh_pokedex_type_row([])
		_refresh_pokedex_header_stats({})
		return

	var species_name := str(species.get("name", species.get("id", "Unknown")))
	var national_number := int(species.get("nationalDexNumber", 0))
	var rarity := str(species.get("rarity", "")).strip_edges()
	var meta_parts: Array[String] = []
	if national_number > 0:
		meta_parts.append("#%03d" % national_number)
	if rarity != "":
		meta_parts.append(_format_identifier_display_name(rarity))

	pokedex_name_label.text = species_name
	pokedex_meta_label.text = " / ".join(meta_parts) if not meta_parts.is_empty() else "Species data"
	_set_pokedex_species_sprite(species)
	_refresh_pokedex_type_row(_array_from_variant(species.get("types", [])))
	var stats_value: Variant = species.get("baseStats", {})
	_refresh_pokedex_header_stats(stats_value if typeof(stats_value) == TYPE_DICTIONARY else {})

func _refresh_pokedex_type_row(types: Array) -> void:
	if pokedex_type_row == null:
		return
	for child: Node in pokedex_type_row.get_children():
		child.queue_free()

	for type_value: Variant in types:
		var type_name := str(type_value).strip_edges()
		if type_name == "":
			continue
		pokedex_type_row.add_child(_create_pokedex_type_badge(type_name))

func _clear_pokedex_species_sprite() -> void:
	if pokedex_animated_sprite != null:
		pokedex_animated_sprite.stop()
		pokedex_animated_sprite.sprite_frames = null
		pokedex_animated_sprite.visible = false
	if pokedex_sprite != null:
		pokedex_sprite.texture = null
		pokedex_sprite.visible = true
	if pokedex_sprite_panel != null:
		pokedex_sprite_panel.tooltip_text = "Select a Pokemon"

func _set_pokedex_species_sprite(species: Dictionary) -> void:
	if pokedex_animated_sprite == null or pokedex_sprite == null:
		return

	var loaded_frames: SpriteFrames = null
	for candidate: String in _pokedex_species_sprite_candidates(species):
		var frames_value: Variant = pokedex_sprite_loader.call(
			"_load_sprite_frames",
			candidate,
			_get_pokedex_sprite_side(),
			false
		)
		loaded_frames = frames_value as SpriteFrames
		if loaded_frames != null:
			break

	if loaded_frames != null:
		pokedex_sprite.visible = false
		pokedex_animated_sprite.visible = true
		pokedex_animated_sprite.sprite_frames = loaded_frames
		var animation_names: PackedStringArray = loaded_frames.get_animation_names()
		if loaded_frames.has_animation("idle"):
			pokedex_animated_sprite.animation = "idle"
		elif not animation_names.is_empty():
			pokedex_animated_sprite.animation = animation_names[0]
		pokedex_animated_sprite.frame = 0
		pokedex_animated_sprite.position = _get_pokedex_sprite_position()
		pokedex_animated_sprite.scale = _get_pokedex_sprite_scale(loaded_frames)
		_apply_pokedex_sprite_center_offset(loaded_frames, pokedex_animated_sprite.animation)
		pokedex_animated_sprite.play()
	else:
		pokedex_animated_sprite.stop()
		pokedex_animated_sprite.visible = false
		pokedex_sprite.visible = true
		pokedex_sprite.texture = _load_pokedex_species_texture(species)

	if pokedex_sprite_panel != null:
		pokedex_sprite_panel.tooltip_text = "Show %s sprite" % ("front" if _get_pokedex_sprite_side() == "back" else "back")

func _pokedex_species_sprite_candidates(species: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	for candidate_value: Variant in [
		species.get("name", ""),
		species.get("id", ""),
		species.get("showdownId", ""),
	]:
		var candidate := str(candidate_value).strip_edges()
		if candidate != "" and not candidates.has(candidate):
			candidates.append(candidate)
	return candidates

func _get_pokedex_sprite_side() -> String:
	return "back" if pokedex_sprite_side == "back" else "front"

func _get_pokedex_sprite_position() -> Vector2:
	if pokedex_sprite_viewport == null:
		return Vector2(88, 70)
	return Vector2(
		float(pokedex_sprite_viewport.size.x) * 0.5,
		float(pokedex_sprite_viewport.size.y) * 0.55
	)

func _get_pokedex_sprite_scale(frames: SpriteFrames) -> Vector2:
	var render_scale := 1.0
	if pokedex_sprite_loader.has_method("_get_sprite_frames_render_scale"):
		var render_scale_value: Variant = pokedex_sprite_loader.call("_get_sprite_frames_render_scale", frames)
		render_scale = float(render_scale_value)

	var display_scale_multiplier := 1.0
	if pokedex_sprite_loader.has_method("_get_sprite_frames_display_scale_multiplier"):
		var display_scale_value: Variant = pokedex_sprite_loader.call("_get_sprite_frames_display_scale_multiplier", frames)
		display_scale_multiplier = float(display_scale_value)

	var visual_rect: Rect2 = _get_pokedex_sprite_visual_rect(frames, "idle")
	if visual_rect.size == Vector2.ZERO and pokedex_animated_sprite != null:
		visual_rect = _get_pokedex_sprite_visual_rect(frames, pokedex_animated_sprite.animation)
	var normalized_frame_size: Vector2 = visual_rect.size / max(render_scale, 1.0)
	if normalized_frame_size == Vector2.ZERO:
		normalized_frame_size = _get_pokedex_sprite_frame_size(frames) / max(render_scale, 1.0)
	var fit_scale: float = min(
		126.0 / max(normalized_frame_size.x, 1.0),
		104.0 / max(normalized_frame_size.y, 1.0)
	)
	var scale_value: float = clamp(fit_scale * display_scale_multiplier, 0.65, 2.0)
	var texture_scale: float = scale_value / max(render_scale, 1.0)
	return Vector2(texture_scale, texture_scale)

func _get_pokedex_sprite_frame_size(frames: SpriteFrames) -> Vector2:
	if pokedex_sprite_loader.has_method("_get_sprite_frames_frame_size"):
		var frame_size_value: Variant = pokedex_sprite_loader.call("_get_sprite_frames_frame_size", frames)
		if frame_size_value is Vector2:
			return frame_size_value as Vector2
		if frame_size_value is Vector2i:
			return Vector2(frame_size_value as Vector2i)

	if frames != null and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		var texture: Texture2D = frames.get_frame_texture("idle", 0)
		if texture != null:
			return texture.get_size()

	return Vector2(48, 57)

func _apply_pokedex_sprite_center_offset(frames: SpriteFrames, animation_name: String) -> void:
	var frame_size: Vector2 = _get_pokedex_sprite_frame_size(frames)
	var visual_rect: Rect2 = _get_pokedex_sprite_visual_rect(frames, animation_name)
	if visual_rect.size == Vector2.ZERO:
		pokedex_animated_sprite.centered = true
		pokedex_animated_sprite.offset = Vector2.ZERO
		return

	pokedex_animated_sprite.centered = true
	pokedex_animated_sprite.offset = (frame_size * 0.5) - visual_rect.get_center()

func _get_pokedex_sprite_visual_rect(frames: SpriteFrames, animation_name: String) -> Rect2:
	if frames == null or animation_name == "" or not frames.has_animation(animation_name):
		return Rect2()

	var has_rect := false
	var combined_rect := Rect2()
	for frame_index in range(frames.get_frame_count(animation_name)):
		var texture: Texture2D = frames.get_frame_texture(animation_name, frame_index)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		var used_rect_i: Rect2i = image.get_used_rect()
		if used_rect_i.size == Vector2i.ZERO:
			continue
		var used_rect := Rect2(Vector2(used_rect_i.position), Vector2(used_rect_i.size))
		if not has_rect:
			combined_rect = used_rect
			has_rect = true
		else:
			combined_rect = combined_rect.merge(used_rect)

	return combined_rect if has_rect else Rect2()

func _on_pokedex_sprite_panel_gui_input(event: InputEvent) -> void:
	if pokedex_selected_species.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			pokedex_sprite_side = "back" if _get_pokedex_sprite_side() == "front" else "front"
			_set_pokedex_species_sprite(pokedex_selected_species)
			get_viewport().set_input_as_handled()

func _load_pokedex_species_texture(species: Dictionary) -> Texture2D:
	var species_name := str(species.get("name", species.get("id", ""))).strip_edges()
	var species_id := str(species.get("id", "")).strip_edges()
	var showdown_id := str(species.get("showdownId", "")).strip_edges()
	for candidate: String in [species_name, species_id, showdown_id]:
		if candidate == "":
			continue
		var texture := PokemonAssets.load_home_sprite(candidate, false)
		if texture != null:
			return texture
		texture = PokemonAssets.load_party_icon(candidate, false)
		if texture != null:
			return texture
	return PokemonAssets.load_unknown_icon()

func _load_pokedex_species_list_icon(species: Dictionary) -> Texture2D:
	var cache_key := str(species.get("id", species.get("showdownId", species.get("name", "")))).strip_edges()
	if cache_key != "" and pokedex_species_list_icon_cache.has(cache_key):
		return pokedex_species_list_icon_cache[cache_key] as Texture2D

	var texture: Texture2D = null
	for candidate: String in _pokedex_species_sprite_candidates(species):
		if PokemonAssets.load_home_sprite(candidate, false) != null:
			texture = PokemonAssets.load_party_icon(candidate, false)
			break

	if texture == null:
		var sprite_frame := _load_first_pokedex_sprite_frame(species)
		if sprite_frame != null:
			texture = sprite_frame

	if texture == null:
		texture = PokemonAssets.load_unknown_icon()

	if cache_key != "":
		pokedex_species_list_icon_cache[cache_key] = texture
	return texture

func _load_first_pokedex_sprite_frame(species: Dictionary) -> Texture2D:
	for candidate: String in _pokedex_species_sprite_candidates(species):
		var frames_value: Variant = pokedex_sprite_loader.call("_load_sprite_frames", candidate, "front", false)
		var frames := frames_value as SpriteFrames
		if frames == null:
			continue

		var animation_name := "idle"
		if not frames.has_animation(animation_name):
			var animation_names := frames.get_animation_names()
			if animation_names.is_empty():
				continue
			animation_name = animation_names[0]

		if frames.get_frame_count(animation_name) > 0:
			return frames.get_frame_texture(animation_name, 0)

	return null

func _refresh_pokedex_header_stats(stats: Dictionary) -> void:
	if pokedex_header_stats_stack == null:
		return
	for child: Node in pokedex_header_stats_stack.get_children():
		child.queue_free()

	if stats.is_empty():
		var empty_label := Label.new()
		empty_label.text = "BASE STATS"
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokedex_header_stats_stack.add_child(empty_label)
		return

	var total := 0
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id := str(stat.get("id", ""))
		var stat_label := str(stat.get("label", stat_id.to_upper()))
		var color: Color = stat.get("color", UI_BORDER_FOCUS) as Color
		var value := int(stats.get(stat_id, 0))
		total += value
		pokedex_header_stats_stack.add_child(_create_pokedex_header_stat_row(stat_label, value, color))
	pokedex_header_stats_stack.add_child(_create_pokedex_header_stat_total_row(total))

func _create_pokedex_header_stat_row(label_text: String, value: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 18)
	row.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(48, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.max_value = POKEDEX_BASE_STAT_BAR_MAX
	bar.value = clampi(value, 0, POKEDEX_BASE_STAT_BAR_MAX)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(96, 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#06101be8"), Color("#d6c78f44"), 2, 1))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 2, 0))
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size = Vector2(32, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("#f2ead2"))
	row.add_child(value_label)
	return row

func _create_pokedex_header_stat_total_row(total: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 20)
	row.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = "TOTAL"
	label.custom_minimum_size = Vector2(48, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	row.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(96, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var value_label := Label.new()
	value_label.text = str(total)
	value_label.custom_minimum_size = Vector2(32, 0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("#f2ead2"))
	row.add_child(value_label)
	return row

func _refresh_pokedex_detail() -> void:
	if pokedex_detail_stack == null:
		return
	for child: Node in pokedex_detail_stack.get_children():
		child.queue_free()

	if pokedex_selected_species.is_empty():
		_set_pokedex_detail_message("Search and select a Pokemon to view its data.")
		return

	match pokedex_active_tab:
		"general":
			_build_pokedex_general_tab()
		"locations":
			_build_pokedex_locations_tab()
		"evolutions":
			_build_pokedex_evolutions_tab()
		"drops":
			_build_pokedex_placeholder_tab("Drops", [])
		_:
			_build_pokedex_moves_tab()

func _set_pokedex_detail_message(message: String) -> void:
	if pokedex_detail_stack == null:
		return
	for child: Node in pokedex_detail_stack.get_children():
		child.queue_free()

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	pokedex_detail_stack.add_child(label)

func _build_pokedex_general_tab() -> void:
	pokedex_detail_stack.add_child(_create_pokedex_section_title("Profile"))

	pokedex_detail_stack.add_child(_create_pokedex_info_line(
		"Egg Groups",
		_format_pokedex_value_list(_array_from_variant(pokedex_selected_species.get("eggGroups", pokedex_selected_species.get("egg_groups", []))))
	))

	pokedex_detail_stack.add_child(_create_pokedex_section_title("Abilities"))
	var abilities := _array_from_variant(pokedex_selected_species.get("abilities", []))
	var added_abilities := _add_pokedex_ability_rows(abilities)
	if added_abilities <= 0:
		pokedex_detail_stack.add_child(_create_pokedex_muted_message("No abilities available."))

	pokedex_detail_stack.add_child(_create_pokedex_section_title("Training"))
	pokedex_detail_stack.add_child(_create_pokedex_info_line(
		"Growth",
		_format_identifier_display_name(str(pokedex_selected_species.get("growthRate", ""))) if str(pokedex_selected_species.get("growthRate", "")).strip_edges() != "" else "Unknown"
	))
	pokedex_detail_stack.add_child(_create_pokedex_info_line(
		"Base EXP",
		str(int(pokedex_selected_species.get("baseExperience", 0)))
	))
	pokedex_detail_stack.add_child(_create_pokedex_ev_yield_panel(_get_pokedex_ev_yield()))

func _add_pokedex_ability_rows(abilities: Array) -> int:
	var added_count := 0
	for ability_value: Variant in abilities:
		if typeof(ability_value) != TYPE_DICTIONARY:
			continue
		var ability: Dictionary = ability_value
		var ability_name := str(ability.get("name", ability.get("id", ""))).strip_edges()
		if ability_name == "":
			continue
		var slot := str(ability.get("slot", "")).strip_edges()
		var label := _format_pokedex_ability_slot_label(slot)
		var ability_row := _create_pokedex_info_line(label, ability_name)
		var ability_description := _get_summary_ability_description_text(ability_name)
		if ability_description != "":
			ability_row.tooltip_text = ability_description
		pokedex_detail_stack.add_child(ability_row)
		added_count += 1
	return added_count

func _format_pokedex_ability_slot_label(slot: String) -> String:
	match slot.strip_edges().to_lower():
		"primary":
			return "Ability 1"
		"secondary":
			return "Ability 2"
		"hidden":
			return "Hidden Ability"
		_:
			return "Ability"

func _get_pokedex_ev_yield() -> Dictionary:
	var yield_value: Variant = pokedex_selected_species.get("evYield", pokedex_selected_species.get("ev_yield", {}))
	var raw_yield: Dictionary = yield_value if typeof(yield_value) == TYPE_DICTIONARY else {}
	var result: Dictionary = {}
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id := str(stat.get("id", ""))
		result[stat_id] = max(0, int(raw_yield.get(stat_id, 0)))
	return result

func _create_pokedex_ev_yield_panel(ev_yield: Dictionary) -> Control:
	var total := 0
	for value: Variant in ev_yield.values():
		total += max(0, int(value))

	var wrapper := HBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_BEGIN

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(192, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912e8"), Color("#38bdf866"), 5, 1))
	wrapper.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)

	var title := Label.new()
	title.text = "EV YIELD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	header.add_child(title)

	var total_label := Label.new()
	total_label.text = "%d total" % total if total > 0 else "Unknown"
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color("#f2ead2") if total > 0 else UI_MUTED_TEXT)
	header.add_child(total_label)

	if total <= 0:
		stack.add_child(_create_pokedex_muted_message("No EV yield data available."))
		return wrapper

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	stack.add_child(chip_row)

	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id := str(stat.get("id", ""))
		var value := int(ev_yield.get(stat_id, 0))
		if value <= 0:
			continue
		chip_row.add_child(_create_pokedex_ev_yield_chip(
			str(stat.get("label", stat_id.to_upper())),
			value,
			stat.get("color", UI_BORDER_FOCUS) as Color
		))
	return wrapper

func _create_pokedex_ev_yield_chip(label_text: String, value: int, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(86, 30)
	chip.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ed8"), Color(color.r, color.g, color.b, 0.68), 4, 1))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)

	var value_label := Label.new()
	value_label.text = "+%d" % value
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(value_label)
	return chip

func _build_pokedex_placeholder_tab(title_text: String, entries: Array) -> void:
	pokedex_detail_stack.add_child(_create_pokedex_section_title(title_text))
	if entries.is_empty():
		pokedex_detail_stack.add_child(_create_pokedex_muted_message("%s data is not available yet." % title_text))
		return
	for entry_value: Variant in entries:
		pokedex_detail_stack.add_child(_create_pokedex_muted_message(str(entry_value)))

func _build_pokedex_locations_tab() -> void:
	pokedex_detail_stack.add_child(_create_pokedex_section_title("Wild Locations"))

	var locations := _array_from_variant(pokedex_selected_species.get("locations", []))
	if locations.is_empty():
		pokedex_detail_stack.add_child(_create_pokedex_muted_message("No known wild locations."))
		return

	for location_value: Variant in locations:
		if typeof(location_value) != TYPE_DICTIONARY:
			continue
		pokedex_detail_stack.add_child(_create_pokedex_location_row(location_value as Dictionary))

func _create_pokedex_location_row(location: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), POKEMON_SUMMARY_ACCENT_FAINT, 5, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var area_name := str(location.get("areaName", location.get("areaId", "Unknown Area"))).strip_edges()
	var area_label := Label.new()
	area_label.text = area_name if area_name != "" else "Unknown Area"
	area_label.custom_minimum_size = Vector2(210, 0)
	area_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	area_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	area_label.add_theme_font_size_override("font_size", 14)
	area_label.add_theme_color_override("font_color", Color("#f5df9a"))
	row.add_child(area_label)

	var encounter_stack := VBoxContainer.new()
	encounter_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encounter_stack.add_theme_constant_override("separation", 1)
	row.add_child(encounter_stack)

	var encounter_type := str(location.get("encounterType", "Wild")).strip_edges()
	var level_text := _format_pokedex_location_level_range(location)
	var method_label := Label.new()
	method_label.text = "%s - %s" % [encounter_type if encounter_type != "" else "Wild", level_text]
	method_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	method_label.add_theme_font_size_override("font_size", 12)
	method_label.add_theme_color_override("font_color", UI_TEXT)
	encounter_stack.add_child(method_label)

	var rarity_label := Label.new()
	rarity_label.text = "Rarity: %s" % _get_pokedex_selected_rarity_label()
	rarity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	encounter_stack.add_child(rarity_label)

	panel.tooltip_text = "%s\n%s\n%s" % [area_label.text, method_label.text, rarity_label.text]
	return panel

func _format_pokedex_location_level_range(location: Dictionary) -> String:
	var min_level: int = max(1, int(location.get("minLevel", location.get("min_level", 1))))
	var max_level: int = max(min_level, int(location.get("maxLevel", location.get("max_level", min_level))))
	if min_level == max_level:
		return "Lv. %d" % min_level
	return "Lv. %d-%d" % [min_level, max_level]

func _get_pokedex_selected_rarity_label() -> String:
	var rarity := str(pokedex_selected_species.get("rarity", "")).strip_edges()
	return _format_identifier_display_name(rarity) if rarity != "" else "Unknown"

func _build_pokedex_evolutions_tab() -> void:
	pokedex_detail_stack.add_child(_create_pokedex_section_title("Evolves Into"))

	var evolutions := _array_from_variant(pokedex_selected_species.get("evolutions", []))
	if evolutions.is_empty():
		pokedex_detail_stack.add_child(_create_pokedex_muted_message("No known evolutions."))
		return

	for evolution_value: Variant in evolutions:
		if typeof(evolution_value) != TYPE_DICTIONARY:
			continue
		pokedex_detail_stack.add_child(_create_pokedex_evolution_row(evolution_value as Dictionary))

func _create_pokedex_evolution_row(evolution: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 54)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), POKEMON_SUMMARY_ACCENT_FAINT, 5, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var name_label := Label.new()
	name_label.text = str(evolution.get("speciesName", evolution.get("speciesId", "Unknown")))
	name_label.custom_minimum_size = Vector2(180, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("#f5df9a"))
	row.add_child(name_label)

	var detail_stack := VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", 1)
	row.add_child(detail_stack)

	var trigger_text := _format_pokedex_evolution_trigger(evolution)
	var trigger_label := Label.new()
	trigger_label.text = "Trigger: %s" % trigger_text
	trigger_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trigger_label.add_theme_font_size_override("font_size", 12)
	trigger_label.add_theme_color_override("font_color", UI_TEXT)
	detail_stack.add_child(trigger_label)

	var condition_text := str(evolution.get("condition", "Unknown condition")).strip_edges()
	if condition_text == "":
		condition_text = "Unknown condition"
	var condition_label := Label.new()
	condition_label.text = "Condition: %s" % condition_text
	condition_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	condition_label.add_theme_font_size_override("font_size", 10)
	condition_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	detail_stack.add_child(condition_label)

	panel.tooltip_text = "%s\n%s" % [trigger_label.text, condition_label.text]
	return panel

func _format_pokedex_evolution_trigger(evolution: Dictionary) -> String:
	var method := str(evolution.get("method", "")).strip_edges()
	var trigger := str(evolution.get("trigger", "")).strip_edges()
	var normalized_method := method.strip_edges().to_lower().replace("_", "-")
	var normalized_trigger := trigger.strip_edges().to_lower().replace("_", "-")
	if normalized_method == "item" or normalized_trigger == "use-item" or normalized_trigger == "item":
		return "Item"
	if trigger != "":
		return _format_pokedex_evolution_label(trigger)
	if method != "":
		return _format_pokedex_evolution_label(method)
	return "Unknown"

func _format_pokedex_evolution_label(value: String) -> String:
	var text := value.strip_edges().replace("_", " ").replace("-", " ")
	return text.capitalize() if text != "" else "Unknown"

func _build_pokedex_moves_tab() -> void:
	var moves_value: Variant = pokedex_selected_species.get("moves", {})
	var moves: Dictionary = moves_value if typeof(moves_value) == TYPE_DICTIONARY else {}
	var level_up_moves := _array_from_variant(moves.get("levelUp", []))
	pokedex_detail_stack.add_child(_create_pokedex_section_title("Level-Up Moves"))

	if level_up_moves.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No level-up moves available."
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokedex_detail_stack.add_child(empty_label)
		return

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	header.add_child(_create_pokedex_move_header_label("Lv", 36))
	header.add_child(_create_pokedex_move_header_label("Move", 190))
	header.add_child(_create_pokedex_move_header_label("Type", 92))
	header.add_child(_create_pokedex_move_header_label("Category", 92))
	header.add_child(_create_pokedex_move_header_label("Power", 52))
	header.add_child(_create_pokedex_move_header_label("Acc", 52))
	header.add_child(_create_pokedex_move_header_label("PP", 42))
	pokedex_detail_stack.add_child(header)

	for move_value: Variant in level_up_moves:
		if typeof(move_value) != TYPE_DICTIONARY:
			continue
		var move: Dictionary = move_value
		pokedex_detail_stack.add_child(_create_pokedex_move_row(move))

func _create_pokedex_section_title(title_text: String) -> Control:
	var label := Label.new()
	label.text = title_text.to_upper()
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	return label

func _create_pokedex_muted_message(message: String) -> Control:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	return label

func _create_pokedex_info_line(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(86, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(value)
	return row

func _create_pokedex_stat_chip(label_text: String, value: int, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(84, 44)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912e8"), Color(color.r, color.g, color.b, 0.56), 5, 1))

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(value_label)
	return panel

func _create_pokedex_move_header_label(label_text: String, width: float) -> Control:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", POKEMON_SUMMARY_ACCENT)
	return label

func _create_pokedex_move_row(move: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 34)
	row_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), POKEMON_SUMMARY_ACCENT_FAINT, 5, 1))
	var move_description := _get_summary_move_description_text(move)
	if move_description != "":
		row_panel.tooltip_text = move_description

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	row_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	row.add_child(_create_pokedex_move_value_label(str(int(move.get("level", 1))), 36, POKEMON_SUMMARY_ACCENT))
	row.add_child(_create_pokedex_move_value_label(str(move.get("name", move.get("id", ""))), 190, UI_TEXT, true))
	row.add_child(_create_pokedex_move_type_cell(str(move.get("type", "")), 92))
	row.add_child(_create_pokedex_move_category_cell(str(move.get("category", "")), 92))
	row.add_child(_create_pokedex_move_value_label(_format_pokedex_move_number(move.get("power", null)), 52, UI_TEXT))
	row.add_child(_create_pokedex_move_value_label(_format_pokedex_move_number(move.get("accuracy", null)), 52, UI_TEXT))
	row.add_child(_create_pokedex_move_value_label(str(int(move.get("pp", 0))), 42, UI_TEXT))
	return row_panel

func _create_pokedex_move_value_label(text_value: String, width: float, color: Color, trim: bool = false) -> Control:
	var label := Label.new()
	label.text = text_value if text_value.strip_edges() != "" else "-"
	label.custom_minimum_size = Vector2(width, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	if trim:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _create_pokedex_move_type_cell(type_name: String, width: float) -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(width, 0)
	var texture := _load_pokemon_type_text_label(type_name)
	if texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(76, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture
		icon.tooltip_text = type_name.capitalize()
		center.add_child(icon)
		return center
	center.add_child(_create_pokedex_move_value_label(_compact_pokedex_text(type_name), width, Color("#f5df9a"), true))
	return center

func _create_pokedex_move_category_cell(category: String, width: float) -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(width, 0)
	var key := category.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	var texture_path := str(MOVE_CATEGORY_LABEL_PATHS.get(key, ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture := load(texture_path) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(72, 20)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = texture
			icon.tooltip_text = _format_identifier_display_name(category)
			center.add_child(icon)
			return center
	center.add_child(_create_pokedex_move_value_label(_compact_pokedex_text(category), width, UI_MUTED_TEXT, true))
	return center

func _create_pokedex_type_badge(type_name: String) -> Control:
	var type_label: Texture2D = _load_pokemon_type_text_label(type_name)
	if type_label != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(92, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = type_label
		icon.tooltip_text = type_name.capitalize()
		return icon
	return _create_summary_move_type_label(type_name)

func _format_pokedex_type_list(types: Array) -> String:
	var names: Array[String] = []
	for type_value: Variant in types:
		var type_name := str(type_value).strip_edges()
		if type_name != "":
			names.append(type_name)
	return " / ".join(names)

func _format_pokedex_value_list(values: Array) -> String:
	var names: Array[String] = []
	for value: Variant in values:
		var text := str(value).strip_edges()
		if text != "":
			names.append(text)
	return ", ".join(names) if not names.is_empty() else "Unknown"

func _format_pokedex_move_number(value: Variant) -> String:
	if value == null:
		return "-"
	var text := str(value).strip_edges()
	if text == "" or text == "0" or text == "0.0":
		return "-"
	if value is int:
		return str(value)
	if value is float:
		return str(int(value))
	if text.is_valid_int():
		return str(int(text))
	if text.is_valid_float():
		return str(int(float(text)))
	return text

func _compact_pokedex_text(value: String) -> String:
	var text := value.strip_edges()
	return text if text != "" else "-"

func _on_item_dex_search_changed(_text: String) -> void:
	_refresh_item_dex_results()

func _refresh_item_dex_results() -> void:
	if item_dex_results_list == null:
		return
	for child: Node in item_dex_results_list.get_children():
		child.queue_free()

	var query := ""
	if item_dex_search_input != null:
		query = item_dex_search_input.text.strip_edges().to_lower()

	var loading_label := Label.new()
	loading_label.text = "Searching..."
	loading_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	item_dex_results_list.add_child(loading_label)

	item_dex_search_request_id += 1
	var request_id := item_dex_search_request_id
	var search_result: Dictionary = await InventoryService.search_items(query)
	if request_id != item_dex_search_request_id:
		return

	for child: Node in item_dex_results_list.get_children():
		child.queue_free()

	if not bool(search_result.get("success", false)):
		var error_label := Label.new()
		error_label.text = "Could not load items."
		error_label.add_theme_color_override("font_color", UI_DANGER)
		item_dex_results_list.add_child(error_label)
		return

	var items := _normalize_dev_item_results(search_result.get("items", []))
	var count := 0
	for item_value: Variant in items:
		var item: Dictionary = item_value as Dictionary
		item_dex_results_list.add_child(_create_item_dex_result_button(item))
		count += 1
		if count >= 40:
			break

	if count == 0:
		var empty_label := Label.new()
		empty_label.text = "No item results."
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		item_dex_results_list.add_child(empty_label)

func _create_item_dex_result_button(item: Dictionary) -> Control:
	var item_id := str(item.get("id", ""))
	var item_name := str(item.get("name", item_id))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(item.get("shortDesc", item.get("desc", "")))
	button.pressed.connect(_on_item_dex_result_selected.bind(item))
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#07111ed8"), Color("#d6c78f44"), 3, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#10213aee"), Color("#d6c78faa"), 3, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#050a12ee"), Color("#d6c78f"), 3, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("#10213aee"), UI_BORDER_FOCUS, 3, 1))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture = _load_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label_stack := VBoxContainer.new()
	label_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	label_stack.add_theme_constant_override("separation", 0)
	row.add_child(label_stack)

	var label := Label.new()
	label.text = item_name
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_TEXT)
	label_stack.add_child(label)

	var meta_label := Label.new()
	meta_label.text = _format_item_dex_category_label(item)
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.add_theme_font_size_override("font_size", 10)
	meta_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	label_stack.add_child(meta_label)
	return button

func _on_item_dex_result_selected(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	item_dex_icon.texture = _load_item_icon(item_id)
	item_dex_name_label.text = str(item.get("name", item_id))
	item_dex_meta_label.text = _format_item_dex_meta(item)
	var description := str(item.get("shortDesc", ""))
	if description == "":
		description = str(item.get("desc", ""))
	if description == "":
		description = "No item summary available yet."
	item_dex_description_label.text = description
	var effect_text := _format_item_dex_effect_info(item)
	if item_dex_effect_section_label != null:
		item_dex_effect_section_label.visible = effect_text != ""
	if item_dex_effect_label != null:
		item_dex_effect_label.text = effect_text
		item_dex_effect_label.visible = effect_text != ""
	var capture_text := _format_item_dex_capture_info(item)
	if item_dex_capture_section_label != null:
		item_dex_capture_section_label.visible = capture_text != ""
	if item_dex_capture_label != null:
		item_dex_capture_label.text = capture_text
		item_dex_capture_label.visible = capture_text != ""
	item_dex_sources_label.text = _format_item_dex_sources(item)

func _format_item_dex_meta(item: Dictionary) -> String:
	var category_text := _format_item_dex_category_label(item)
	var cost_value: Variant = item.get("cost", null)
	var cost_text := "Unknown"
	if cost_value != null:
		cost_text = "$%s" % _format_money(int(cost_value))
	var meta_parts: Array[String] = ["Category: %s" % category_text]
	var potency_text := _format_item_dex_potency(item)
	if potency_text != "":
		meta_parts.append("Potency: %s" % potency_text)
	meta_parts.append("Base price: %s" % cost_text)
	return "    ".join(meta_parts)

func _format_item_dex_category_label(item: Dictionary) -> String:
	var category := _format_identifier_display_name(str(item.get("category", "-")))
	var sub_category := _format_identifier_display_name(str(item.get("subCategory", "")))
	if sub_category == "":
		return category
	return "%s / %s" % [category, sub_category]

func _format_item_dex_potency(item: Dictionary) -> String:
	var potency_value: Variant = item.get("potency", null)
	if potency_value == null:
		return ""
	var potency_unit := str(item.get("potencyUnit", "")).strip_edges()
	var potency_number := float(potency_value)
	var potency_text := str(int(potency_number)) if is_equal_approx(potency_number, float(int(potency_number))) else str(potency_number)
	match potency_unit:
		"experience":
			return "%s EXP" % potency_text
		"hp":
			return "%s HP" % potency_text
		"percent_hp":
			return "%s%% HP" % potency_text
		"pp":
			return "%s PP" % potency_text
		"pp_all":
			return "%s PP per move" % potency_text
		"percent_max_pp":
			return "%s%% max PP" % potency_text
		"full_hp":
			return "Full HP"
		"full_hp_status":
			return "Full HP + status cure"
		"full_pp":
			return "Full PP"
		"full_pp_all":
			return "Full PP per move"
		"level":
			return "+%s level" % potency_text
		"ability_change":
			return "1 ability change"
		"status":
			return "1 status cure"
		"ev":
			return "+%s EV" % potency_text
		"nature":
			return "1 nature change"
		"stat":
			return "+%s stat" % potency_text
		_:
			return potency_text

func _format_item_dex_effect_info(item: Dictionary) -> String:
	var sub_category := str(item.get("subCategory", "")).strip_edges()
	var potency_text := _format_item_dex_potency(item)
	if sub_category == "" and potency_text == "":
		return ""

	var lines: Array[String] = []
	if sub_category != "":
		lines.append("Type: %s" % _format_identifier_display_name(sub_category))
	if sub_category == "ev":
		var stat_text := _summary_stat_label(str(item.get("stat", "")).strip_edges())
		if stat_text != "":
			lines.append("Stat: %s" % stat_text)
	if potency_text != "":
		lines.append("Potency: %s" % potency_text)

	var item_id := _normalize_item_id(str(item.get("id", "")))
	match sub_category:
		"exp":
			lines.append("Grants experience to the selected Pokemon.")
		"level":
			lines.append("Raises the selected Pokemon by the listed number of levels.")
		"heal":
			lines.append("Restores HP to the selected Pokemon.")
		"revive":
			lines.append("Revives a fainted Pokemon with the listed HP amount.")
		"pp":
			lines.append("Restores or increases move PP.")
		"status":
			lines.append("Cures a status condition.")
		"ability":
			lines.append("Changes an eligible Pokemon's ability.")
		"ev":
			lines.append("Changes effort values for one stat.")
		"nature":
			lines.append("Changes how stat growth is treated for the Pokemon.")
		"stat":
			lines.append("Raises a stat-related value.")
		_:
			if item_id != "":
				lines.append("Structured effect metadata is available for this item.")
	return "\n".join(lines)

func _format_item_dex_capture_info(item: Dictionary) -> String:
	if not _is_item_dex_pokeball(item):
		return ""

	var item_id := _normalize_item_id(str(item.get("id", "")))
	if item_id == "master-ball":
		return "Guaranteed catch.\nMaster Ball always catches wild Pokemon in the current capture rules."

	var multiplier := float(ITEM_DEX_CAPTURE_BALL_MULTIPLIERS.get(item_id, 1.0))
	var lines: Array[String] = [
		"Current capture modifier: x%s" % _format_item_dex_multiplier(multiplier),
	]
	var reference_note := _extract_item_dex_capture_effect_note(item)
	if reference_note != "":
		lines.append(reference_note)
	lines.append("Actual catch chance also depends on target HP, species catch rate, and status.")
	return "\n".join(lines)

func _is_item_dex_pokeball(item: Dictionary) -> bool:
	var item_id := _normalize_item_id(str(item.get("id", "")))
	var category := str(item.get("category", "")).strip_edges().to_lower().replace("-", "_")
	if category in ["balls", "poke_balls", "pokeballs", "pokeball"]:
		return true
	return item_id.ends_with("ball") or item_id.contains("-ball")

func _extract_item_dex_capture_effect_note(item: Dictionary) -> String:
	var text := str(item.get("shortDesc", ""))
	if text == "":
		text = str(item.get("desc", ""))
	text = text.strip_edges()
	if text == "":
		return ""
	var lower_text := text.to_lower()
	if lower_text.contains("success rate") or lower_text.contains("catch rate") or lower_text.contains("catches"):
		return "Reference effect: %s" % text
	return ""

func _format_item_dex_multiplier(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return "%.1f" % value

func _format_item_dex_sources(item: Dictionary) -> String:
	var summary_value: Variant = item.get("sourceSummary", [])
	if typeof(summary_value) != TYPE_ARRAY:
		return "No known repeatable ways yet."

	var summaries: Array = summary_value
	if summaries.is_empty():
		return "No known repeatable ways yet."

	var lines: Array[String] = []
	for summary_value_item: Variant in summaries:
		if typeof(summary_value_item) != TYPE_DICTIONARY:
			continue
		var summary: Dictionary = summary_value_item
		var label := str(summary.get("label", summary.get("type", "Source")))
		var count: int = int(summary.get("count", 0))
		lines.append("%s (%s)" % [label, count])

		var preview_value: Variant = summary.get("preview", [])
		if typeof(preview_value) != TYPE_ARRAY:
			continue

		var previews: Array = preview_value
		for preview_item: Variant in previews:
			lines.append("- %s" % str(preview_item))

		var hidden_count: int = count - previews.size()
		if hidden_count > 0:
			lines.append("+%s more" % hidden_count)
	return "\n".join(lines)

func _on_dev_add_pokemon_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_add_team_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_spawn_pokemon_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.SPAWN)

func _on_dev_add_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	dev_add_menu_popup.visible = not dev_add_menu_popup.visible
	if dev_add_menu_popup.visible:
		_position_dev_add_menu_popup()
		_activate_ui_panel(dev_add_menu_popup)
	else:
		_deactivate_ui_panel(dev_add_menu_popup)

func _on_dev_preview_evolution_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	_hide_dev_add_menu_popup()
	await play_evolution_preview("Pidgey", "Pidgeotto")

func _position_dev_add_menu_popup() -> void:
	_position_dev_slot_popup(dev_add_menu_popup)

func _position_dev_clear_menu_popup() -> void:
	_position_dev_slot_popup(dev_clear_menu_popup)

func _position_dev_slot_popup(popup: Control) -> void:
	if popup == null or dev_actions_slot == null:
		return

	var parent_control: Control = popup.get_parent_control()
	if parent_control == null:
		return

	var slot_rect: Rect2 = dev_actions_slot.get_global_rect()
	var popup_size: Vector2 = popup.get_combined_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = popup.custom_minimum_size

	var parent_size: Vector2 = parent_control.size
	var parent_global_position: Vector2 = parent_control.global_position
	var target_position: Vector2 = slot_rect.position + Vector2(0.0, slot_rect.size.y + 8.0) - parent_global_position
	if target_position.y + popup_size.y > parent_size.y - 12.0:
		target_position.y = slot_rect.position.y - parent_global_position.y - popup_size.y - 8.0

	target_position.x = clamp(target_position.x, 12.0, max(parent_size.x - popup_size.x - 12.0, 12.0))
	target_position.y = clamp(target_position.y, 12.0, max(parent_size.y - popup_size.y - 12.0, 12.0))
	popup.position = target_position

func _hide_dev_add_menu_popup() -> void:
	if dev_add_menu_popup == null:
		return

	dev_add_menu_popup.visible = false
	_deactivate_ui_panel(dev_add_menu_popup)

func _on_dev_add_item_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	_hide_dev_add_menu_popup()
	dev_actions_popup.visible = false
	await _show_dev_add_item_popup()

func _on_dev_add_money_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	_hide_dev_add_menu_popup()
	dev_actions_popup.visible = false
	_show_dev_add_money_popup()

func _on_dev_heal_party_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	if PlayerSave.party.is_empty():
		_add_chat_message("No Pokemon to heal.")
		return

	dev_actions_popup.visible = false
	_hide_dev_add_menu_popup()
	dev_heal_party_button.disabled = true
	for pokemon: Pokemon in PlayerSave.party:
		_heal_dev_party_pokemon(pokemon)

	PlayerSave.party_changed.emit()
	var result: Dictionary = await PlayerPartyStateService.save_current_party()
	dev_heal_party_button.disabled = false
	if not bool(result.get("success", false)):
		_add_chat_message("Could not save healed party: %s" % str(result.get("error", "Unknown error")))
		push_warning("UIOverlay: dev heal party save failed: %s" % str(result.get("error", "Unknown error")))
		return

	_refresh_party()
	_refresh_open_pokemon_summary_cards()
	_add_chat_message("Party healed.")

func _heal_dev_party_pokemon(pokemon: Pokemon) -> void:
	if pokemon == null:
		return

	var restored_max_hp: int = max(pokemon.max_hp, int(pokemon.stats.get("hp", pokemon.max_hp)), 1)
	pokemon.max_hp = restored_max_hp
	pokemon.current_hp = restored_max_hp
	pokemon.has_saved_hp_state = true

	for move_index in range(pokemon.moves.size()):
		pokemon.moves[move_index] = _heal_dev_party_move(pokemon.moves[move_index])

func _heal_dev_party_move(move_value: Variant) -> Variant:
	if not (move_value is Dictionary):
		return move_value

	var move_data: Dictionary = (move_value as Dictionary).duplicate(true)
	var max_pp: int = int(_get_first_dictionary_value(
		move_data,
		["maxPp", "maxpp", "maxPP", "max_pp", "pp"],
		0
	))
	if max_pp <= 0:
		return move_data

	move_data["pp"] = max_pp
	move_data["currentPp"] = max_pp
	move_data["currentPP"] = max_pp
	move_data["current_pp"] = max_pp
	move_data["maxPp"] = max_pp
	move_data["maxpp"] = max_pp
	return move_data

func _show_dev_add_item_popup() -> void:
	if not _can_use_dev_tools():
		return

	dev_selected_item = {}
	dev_item_confirm_button.disabled = true
	dev_item_quantity_spinbox.value = 1
	dev_item_search_input.clear()
	dev_add_item_popup.visible = true
	_activate_ui_panel(dev_add_item_popup)
	dev_item_search_input.grab_focus.call_deferred()
	await _refresh_dev_item_results()

func _hide_dev_add_item_popup() -> void:
	dev_add_item_popup.visible = false
	dev_selected_item = {}

func _show_dev_add_money_popup() -> void:
	if not _can_use_dev_tools():
		return

	dev_money_amount_spinbox.value = 1000
	dev_add_money_popup.visible = true
	_activate_ui_panel(dev_add_money_popup)
	dev_money_amount_spinbox.grab_focus.call_deferred()

func _hide_dev_add_money_popup() -> void:
	dev_add_money_popup.visible = false

func _on_dev_money_confirm_pressed() -> void:
	if not _can_use_dev_tools():
		return

	var amount: int = max(int(dev_money_amount_spinbox.value), 1)
	dev_money_confirm_button.disabled = true
	var result: Dictionary = await PlayerWalletService.dev_add_money(amount)
	dev_money_confirm_button.disabled = false
	if not bool(result.get("success", false)):
		_add_chat_message("Could not add money: %s" % str(result.get("error", "Unknown error")))
		return

	PlayerWalletService.apply_wallet_result(result)
	refresh_money_display()
	_add_chat_message("Added %s." % _format_money(amount))
	_hide_dev_add_money_popup()

func _load_dev_item_catalog() -> void:
	dev_item_catalog.clear()
	var directory := DirAccess.open(BAG_ICON_ROOT)
	if directory == null:
		push_warning("Dev Add Item: could not open item icon directory.")
		return

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name == "":
			break
		if directory.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".png"):
			continue
		if file_name.to_lower() == "back.png" or file_name == "000.png":
			continue

		var file_stem := file_name.get_basename()
		var item_id := _dev_item_id_from_icon_stem(file_stem)
		dev_item_catalog.append({
			"id": item_id,
			"name": _item_name_from_id(item_id),
			"icon": BAG_ICON_ROOT + file_name,
		})
	directory.list_dir_end()
	dev_item_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)

func _dev_item_id_from_icon_stem(file_stem: String) -> String:
	return file_stem.strip_edges().to_lower()

func _on_dev_item_search_changed(_text: String) -> void:
	if not _can_use_dev_tools():
		return

	dev_selected_item = {}
	dev_item_confirm_button.disabled = true
	_refresh_dev_item_results()

func _refresh_dev_item_results() -> void:
	if not _can_use_dev_tools():
		return

	if dev_item_results_list == null:
		return
	for child: Node in dev_item_results_list.get_children():
		child.queue_free()

	var query := ""
	if dev_item_search_input != null:
		query = dev_item_search_input.text.strip_edges().to_lower()

	var loading_label := Label.new()
	loading_label.text = "Searching..."
	loading_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	dev_item_results_list.add_child(loading_label)

	dev_item_search_request_id += 1
	var request_id := dev_item_search_request_id
	var search_result: Dictionary = await InventoryService.search_dev_items(query)
	if request_id != dev_item_search_request_id:
		return

	for child: Node in dev_item_results_list.get_children():
		child.queue_free()

	if not bool(search_result.get("success", false)):
		var error_label := Label.new()
		error_label.text = "Could not load items."
		error_label.add_theme_color_override("font_color", UI_DANGER)
		dev_item_results_list.add_child(error_label)
		return

	dev_item_catalog = _normalize_dev_item_results(search_result.get("items", []))
	var count := 0
	for item_value: Variant in dev_item_catalog:
		var item: Dictionary = item_value as Dictionary
		dev_item_results_list.add_child(_create_dev_item_result_button(item))
		count += 1
		if count >= 8:
			break

	if count == 0:
		var empty_label := Label.new()
		empty_label.text = "No item results."
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		dev_item_results_list.add_child(empty_label)

func _normalize_dev_item_results(items_value: Variant) -> Array[Dictionary]:
	var normalized_items: Array[Dictionary] = []
	if typeof(items_value) != TYPE_ARRAY:
		return normalized_items

	var items: Array = items_value
	for item_value: Variant in items:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id == "":
			continue
		normalized_items.append({
			"id": item_id,
			"name": str(item.get("name", _item_name_from_id(item_id))),
			"category": str(item.get("category", "")),
			"subCategory": item.get("subCategory", null),
			"shortDesc": str(item.get("shortDesc", "")),
			"desc": str(item.get("desc", "")),
			"cost": item.get("cost", null),
			"potency": item.get("potency", null),
			"potencyUnit": item.get("potencyUnit", null),
			"sources": item.get("sources", []),
			"sourceSummary": item.get("sourceSummary", []),
		})
	return normalized_items

func _create_dev_item_result_button(item: Dictionary) -> Control:
	var item_id := str(item.get("id", ""))
	var item_name := str(item.get("name", item_id))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(item.get("shortDesc", item.get("desc", "")))
	button.pressed.connect(_on_dev_item_result_selected.bind(item))
	_apply_button_style(button, "primary" if item_id == str(dev_selected_item.get("id", "")) else "default")

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture = _load_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = item_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)
	return button

func _on_dev_item_result_selected(item: Dictionary) -> void:
	if not _can_use_dev_tools():
		return

	dev_selected_item = item.duplicate(true)
	dev_item_confirm_button.disabled = false
	for child: Node in dev_item_results_list.get_children():
		if child is Button:
			var button: Button = child as Button
			_apply_button_style(button, "primary" if button.tooltip_text == str(dev_selected_item.get("shortDesc", dev_selected_item.get("desc", ""))) else "default")

func _on_dev_item_confirm_pressed() -> void:
	if not _can_use_dev_tools():
		return

	if dev_selected_item.is_empty():
		return
	var item_id := str(dev_selected_item.get("id", ""))
	var quantity: int = max(int(dev_item_quantity_spinbox.value), 1)
	dev_item_confirm_button.disabled = true
	var result: Dictionary = await InventoryService.dev_add_item(item_id, quantity)
	dev_item_confirm_button.disabled = false
	if not bool(result.get("success", false)):
		_add_chat_message("Could not add item: %s" % str(result.get("error", "Unknown error")))
		return

	_add_chat_message("Added %sx %s." % [quantity, str(dev_selected_item.get("name", item_id))])
	bag_inventory_items = _normalize_bag_inventory_items(result.get("items", []))
	bag_inventory_loaded = true
	if bag_popup != null and bag_popup.visible:
		_refresh_bag_items()
	_hide_dev_add_item_popup()

func _on_dev_clear_party_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_actions_popup.visible = false
	_hide_dev_add_menu_popup()
	dev_clear_menu_popup.visible = true
	_position_dev_clear_menu_popup()
	_activate_ui_panel(dev_clear_menu_popup)

func _on_dev_clear_party_option_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_clear_menu_popup.visible = false
	_show_ui_confirm_popup(
		"Clear Party",
		"This will remove every Pokemon from your party. This cannot be undone.",
		"Clear Party",
		Callable(self, "_on_clear_party_confirmed"),
		Vector2i(460, 0),
		true
	)

func _on_dev_clear_inventory_option_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_clear_menu_popup.visible = false
	_show_ui_confirm_popup(
		"Clear Inventory",
		"This will remove every item from your inventory. This cannot be undone.",
		"Clear Inventory",
		Callable(self, "_on_clear_inventory_confirmed"),
		Vector2i(460, 0),
		true
	)

func _on_clear_party_confirmed() -> void:
	if not _can_use_dev_tools():
		return

	PlayerSave.party.clear()
	PlayerSave.party_changed.emit()
	await _save_party_state_after_change()
	dev_actions_popup.visible = false
	_add_chat_message("Party cleared.")

func _on_clear_inventory_confirmed() -> void:
	if not _can_use_dev_tools():
		return

	var result: Dictionary = await InventoryService.dev_clear_inventory()
	if not bool(result.get("success", false)):
		_add_chat_message("Could not clear inventory: %s" % str(result.get("error", "Unknown error")))
		return

	bag_inventory_items = []
	bag_inventory_loaded = true
	if bag_popup != null and bag_popup.visible:
		_refresh_bag_items()
	_add_chat_message("Inventory cleared.")

func _save_party_state_after_change() -> void:
	var result: Dictionary = await PlayerPartyStateService.save_current_party()
	if not bool(result.get("success", false)):
		_add_chat_message("Could not save party. Please report this to staff.")
		push_warning("UIOverlay: party save failed: %s" % str(result.get("error", "Unknown error")))

func _on_dev_actions_close_button_pressed() -> void:
	dev_actions_popup.visible = false
	_hide_dev_add_menu_popup()

func _show_dev_pokemon_popup(mode: int) -> void:
	if not _can_use_dev_tools():
		return

	dev_pokemon_popup_mode = mode
	match dev_pokemon_popup_mode:
		DevPokemonPopupMode.TEAM:
			dev_pokemon_title.text = "Create Pokemon"
			dev_pokemon_add_button.text = "Create"
			dev_pokemon_text.placeholder_text = "Paste one Pokemon or a full Showdown/Pokepaste team here"
		DevPokemonPopupMode.SPAWN:
			dev_pokemon_title.text = "Spawn Pokemon"
			dev_pokemon_add_button.text = "Spawn"
			dev_pokemon_text.placeholder_text = "Enter a Pokemon name, Showdown set, or Pokepaste"
		_:
			dev_pokemon_title.text = "Add Pokemon"
			dev_pokemon_add_button.text = "Add"
			dev_pokemon_text.placeholder_text = "Paste Showdown/Pokepaste text here"

	dev_pokemon_popup.visible = true
	_activate_ui_panel(dev_pokemon_popup)
	dev_pokemon_text.grab_focus()

func _on_dev_pokemon_add_button_pressed() -> void:
	if not _can_use_dev_tools():
		return

	var added: bool = false
	match dev_pokemon_popup_mode:
		DevPokemonPopupMode.TEAM:
			added = await _handle_add_team_command(dev_pokemon_text.text)
		DevPokemonPopupMode.SPAWN:
			added = await _handle_start_encounter_command(dev_pokemon_text.text)
		_:
			added = await _handle_add_pokemon_command(dev_pokemon_text.text)

	if added:
		dev_pokemon_text.clear()
		dev_pokemon_popup.visible = false

func _on_dev_pokemon_close_button_pressed() -> void:
	dev_pokemon_popup.visible = false
	dev_pokemon_popup_mode = DevPokemonPopupMode.POKEMON
	chat_input.grab_focus()

func _on_settings_button_pressed() -> void:
	if settings_menu.has_method("open"):
		settings_menu.call("open")
		_activate_ui_panel(settings_menu)
		return

	settings_menu.visible = true
	_activate_ui_panel(settings_menu)

func _on_socials_button_pressed() -> void:
	if socials_menu.visible:
		_hide_socials_menu()
		return

	socials_menu.visible = true
	_position_socials_menu()
	_activate_ui_panel(socials_menu)

func _position_socials_menu() -> void:
	if socials_menu == null or socials_slot == null:
		return

	var slot_rect: Rect2 = socials_slot.get_global_rect()
	var menu_size: Vector2 = socials_menu.get_combined_minimum_size()
	if menu_size == Vector2.ZERO:
		menu_size = socials_menu.size

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var target_position := Vector2(slot_rect.position.x, slot_rect.position.y + slot_rect.size.y + 8.0)
	if target_position.x + menu_size.x > viewport_size.x - 12.0:
		target_position.x = viewport_size.x - menu_size.x - 12.0
	target_position.x = max(target_position.x, 12.0)
	socials_menu.position = target_position

func _hide_socials_menu() -> void:
	socials_menu.visible = false
	_deactivate_ui_panel(socials_menu)

func _on_socials_friend_list_button_pressed() -> void:
	_add_chat_message("Friend list is not implemented yet.")

func _on_socials_mail_button_pressed() -> void:
	_hide_socials_menu()
	_set_mail_popup_size()
	mail_popup.visible = true
	_activate_ui_panel(mail_popup)
	_load_mailbox()


func _setup_socials_attention_badge() -> void:
	if socials_attention_badge == null:
		return

	if socials_button != null and socials_attention_badge.get_parent() != socials_button:
		var current_parent := socials_attention_badge.get_parent()
		if current_parent != null:
			current_parent.remove_child(socials_attention_badge)
		socials_button.add_child(socials_attention_badge)
	socials_attention_badge.set_as_top_level(false)
	socials_attention_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socials_attention_badge.custom_minimum_size = Vector2.ZERO
	_position_attention_badge_in_parent(socials_attention_badge, 0.0, 2.0)
	socials_attention_badge.z_index = 100
	socials_attention_badge.add_theme_stylebox_override("panel", _make_attention_badge_style())
	socials_friend_list_attention_badge = _create_socials_menu_attention_badge(socials_friend_list_button)
	socials_mail_attention_badge = _create_socials_menu_attention_badge(socials_mail_button)
	_refresh_socials_attention_badge()


func _make_attention_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ff3434")
	style.border_color = Color("#ff8a8a")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color("#ff343499")
	style.shadow_size = 6
	style.shadow_offset = Vector2.ZERO
	return style


func _position_attention_badge_in_parent(badge: Panel, right_offset: float = 2.0, top_offset: float = 2.0) -> void:
	if badge == null:
		return
	var badge_size := Vector2(12, 12)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	badge.offset_left = -badge_size.x - right_offset
	badge.offset_top = top_offset
	badge.offset_right = -right_offset
	badge.offset_bottom = top_offset + badge_size.y
	badge.size = badge_size


func _create_socials_menu_attention_badge(button: Button) -> Panel:
	if button == null:
		return null

	var badge := Panel.new()
	badge.name = "AttentionBadge"
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2.ZERO
	badge.z_index = 100
	badge.add_theme_stylebox_override("panel", _make_attention_badge_style())
	button.add_child(badge)
	_position_attention_badge_in_parent(badge, 6.0, 4.0)
	return badge


func _set_socials_attention(source: String, active: bool) -> void:
	var normalized_source := source.strip_edges().to_lower()
	if normalized_source == "":
		return
	socials_attention_sources[normalized_source] = active
	_refresh_socials_attention_badge()

func _refresh_socials_attention_badge() -> void:
	var has_attention := _has_socials_attention()
	if socials_attention_badge != null:
		socials_attention_badge.visible = has_attention and options_panel != null and options_panel.visible and socials_slot != null and socials_slot.visible
	if socials_mail_attention_badge != null:
		socials_mail_attention_badge.visible = bool(socials_attention_sources.get("mail", false))
	if socials_friend_list_attention_badge != null:
		socials_friend_list_attention_badge.visible = bool(socials_attention_sources.get("friend_list", false))


func _has_socials_attention() -> bool:
	for value: Variant in socials_attention_sources.values():
		if bool(value):
			return true
	return false

func _on_socials_close_button_pressed() -> void:
	_hide_socials_menu()

func _update_mail_attention_session_state() -> bool:
	return _update_mail_attention_session_state_for_messages(mailbox_messages, active_mail_box == "inbox")


func _update_mail_attention_session_state_for_messages(messages: Array[Dictionary], respect_active_box: bool = true) -> bool:
	if respect_active_box and active_mail_box != "inbox":
		return false

	var has_new_inbox_mail := false
	var has_any_inbox_mail := false

	for message_value: Variant in messages:
		if not (message_value is Dictionary):
			continue
		var message: Dictionary = message_value as Dictionary
		var mail_id: int = int(message.get("id", -1))
		if mail_id <= 0:
			continue
		has_any_inbox_mail = true
		if not mail_ids_initialized:
			known_mail_ids[mail_id] = true
			continue
		if not known_mail_ids.has(mail_id):
			known_mail_ids[mail_id] = true
			has_new_inbox_mail = true

	if not mail_ids_initialized:
		mail_ids_initialized = true
	return has_new_inbox_mail and has_any_inbox_mail


func _refresh_mail_attention_from_inbox() -> void:
	var result: Dictionary = await MailService.load_mail("inbox")
	if not bool(result.get("success", false)):
		return

	var inbox_messages: Array[Dictionary] = _normalize_mailbox_messages(result.get("mail", []))
	var has_new_inbox_mail: bool = _update_mail_attention_session_state_for_messages(inbox_messages, false)
	var has_mail_attention: bool = _mail_messages_need_attention(inbox_messages)
	if has_new_inbox_mail and _mail_messages_have_unread(inbox_messages):
		_play_mail_notification_sound()
	_set_socials_attention("mail", has_mail_attention)


func _refresh_mail_attention_from_messages(messages: Array[Dictionary]) -> void:
	if active_mail_box != "inbox":
		return

	_set_socials_attention("mail", _mail_messages_need_attention(messages))


func _mail_messages_need_attention(messages: Array[Dictionary]) -> bool:
	var has_attention := false
	for message_value: Variant in messages:
		if not (message_value is Dictionary):
			continue
		var message: Dictionary = message_value as Dictionary
		if not _mail_message_is_read(message):
			has_attention = true
			break

		if _mail_has_unclaimed_attachments(_array_from_variant(message.get("attachments", []))):
			has_attention = true
			break
	return has_attention


func _mail_messages_have_unread(messages: Array[Dictionary]) -> bool:
	for message_value: Variant in messages:
		if not (message_value is Dictionary):
			continue
		var message: Dictionary = message_value as Dictionary
		if not _mail_message_is_read(message):
			return true
	return false


func _mail_message_is_read(message: Dictionary) -> bool:
	var read_at: Variant = message.get("readAt", message.get("read_at", null))
	if read_at == null:
		return false
	return str(read_at).strip_edges() != ""

func _on_mail_compose_button_pressed() -> void:
	_open_mail_compose_popup("", "")

func _open_mail_compose_popup(recipient: String = "", subject: String = "") -> void:
	mail_compose_recipient_input.clear()
	mail_compose_subject_input.clear()
	mail_compose_body_input.clear()
	mail_compose_recipient_input.text = recipient.strip_edges()
	mail_compose_subject_input.text = subject.strip_edges()
	mail_selected_item_attachments.clear()
	mail_selected_pokemon_ids.clear()
	mail_selected_item_for_attachment = {}
	_prepare_mail_attachment_options()
	mail_compose_popup.visible = true
	_activate_ui_panel(mail_compose_popup)
	mail_compose_recipient_input.grab_focus()

func _on_mail_close_button_pressed() -> void:
	mail_popup.visible = false
	_deactivate_ui_panel(mail_popup)
	mail_dragging = false

func _on_mail_box_selected(box: String) -> void:
	active_mail_box = "sent" if box == "sent" else "inbox"
	selected_mail_id = -1
	_apply_button_style(mail_inbox_button, "primary" if active_mail_box == "inbox" else "default")
	_apply_button_style(mail_sent_button, "primary" if active_mail_box == "sent" else "default")
	_load_mailbox()

func _on_mail_claim_button_pressed() -> void:
	if selected_mail_id <= 0:
		return
	var selected_mail := _get_mail_by_id(selected_mail_id)
	var previous_attachments: Array = _array_from_variant(selected_mail.get("attachments", []))

	var result: Dictionary = await MailService.claim_mail(selected_mail_id)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not claim mail: %s" % str(result.get("error", "Unknown error")))
		return

	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		PlayerSave.replace_party_from_state(party_value as Array)
	var inventory_value: Variant = result.get("inventory", [])
	if inventory_value is Array:
		bag_inventory_items = _normalize_bag_inventory_items(inventory_value)
		bag_inventory_loaded = true
		_refresh_bag_items()

	var claimed_mail: Dictionary = _mail_dictionary_from_variant(result.get("mail", {}))
	_emit_mail_claim_messages(previous_attachments, claimed_mail)
	await _load_mailbox()
	_refresh_mail_attention_from_messages(mailbox_messages)


func _on_mail_attachment_claim_pressed(attachment_id: int) -> void:
	if selected_mail_id <= 0:
		return
	if active_mail_box != "inbox":
		return
	var selected_mail := _get_mail_by_id(selected_mail_id)
	var previous_attachments: Array = _array_from_variant(selected_mail.get("attachments", []))

	var result: Dictionary = await MailService.claim_mail_attachment(selected_mail_id, attachment_id)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not claim attachment: %s" % str(result.get("error", "Unknown error")))
		return

	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		PlayerSave.replace_party_from_state(party_value as Array)
	var inventory_value: Variant = result.get("inventory", [])
	if inventory_value is Array:
		bag_inventory_items = _normalize_bag_inventory_items(inventory_value)
		bag_inventory_loaded = true
		_refresh_bag_items()

	var claimed_mail: Dictionary = _mail_dictionary_from_variant(result.get("mail", {}))
	_emit_mail_claim_messages(previous_attachments, claimed_mail)
	await _load_mailbox()
	_refresh_mail_attention_from_messages(mailbox_messages)

func _emit_mail_claim_messages(previous_attachments: Array, claimed_mail: Dictionary) -> void:
	var after_attachments: Array = _array_from_variant(claimed_mail.get("attachments", []))
	var attachment_map: Dictionary = {}
	for attachment_value: Variant in after_attachments:
		if not (attachment_value is Dictionary):
			continue
		var attachment: Dictionary = attachment_value as Dictionary
		var attachment_id: int = int(attachment.get("id", -1))
		if attachment_id > 0:
			attachment_map[attachment_id] = attachment

	for previous_attachment_value: Variant in previous_attachments:
		if not (previous_attachment_value is Dictionary):
			continue
		var previous_attachment: Dictionary = previous_attachment_value as Dictionary
		var attachment_id: int = int(previous_attachment.get("id", -1))
		if attachment_id <= 0:
			continue
		if _mail_attachment_is_claimed(previous_attachment):
			continue

		var after_attachment: Variant = attachment_map.get(attachment_id, {})
		if not (after_attachment is Dictionary):
			continue
		var attachment: Dictionary = after_attachment as Dictionary
		if not _mail_attachment_is_claimed(attachment):
			continue

		var attachment_type: String = str(attachment.get("type", ""))
		var payload: Dictionary = {}
		var payload_value: Variant = attachment.get("payload", {})
		if payload_value is Dictionary:
			payload = payload_value as Dictionary

		match attachment_type:
			"item":
				var item_name: String = str(payload.get("name", payload.get("itemId", "Item")))
				var quantity: int = int(payload.get("quantity", 1))
				_add_chat_message("Received %sx %s." % [quantity, item_name])
			"pokemon":
				var pokemon_payload: Dictionary = {}
				var pokemon_value: Variant = payload.get("pokemon", {})
				if pokemon_value is Dictionary:
					pokemon_payload = pokemon_value as Dictionary
				var species: String = str(pokemon_payload.get("species", "Pokemon"))
				var level: int = int(pokemon_payload.get("level", 1))
				_add_chat_message("Received Pokemon: %s (Lv. %s)." % [species, level])
			_:
				_add_chat_message("Mail attachment claimed.")

func _on_mail_delete_button_pressed() -> void:
	if selected_mail_id <= 0:
		return

	var result: Dictionary = await MailService.delete_mail(selected_mail_id, active_mail_box)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not delete mail: %s" % str(result.get("error", "Unknown error")))
		return

	selected_mail_id = -1
	mailbox_messages = _normalize_mailbox_messages(result.get("mail", []))
	if not mailbox_messages.is_empty():
		selected_mail_id = int(mailbox_messages[0].get("id", -1))
	_refresh_mailbox()
	_refresh_mail_attention_from_messages(mailbox_messages)
	_add_chat_message("Mail deleted.")

func _prepare_mail_attachment_options() -> void:
	mail_compose_inventory_items.clear()
	mail_compose_party_pokemon.clear()
	_refresh_mail_attachment_summary()
	_refresh_mail_pokemon_attachment_options()
	_load_mail_item_attachment_options()

func _load_mail_item_attachment_options() -> void:
	mail_item_search_input.text = "Loading bag..."
	mail_item_search_input.editable = false
	mail_add_item_button.disabled = true
	_clear_mail_item_suggestions()

	var result: Dictionary = await InventoryService.load_inventory()
	if not bool(result.get("success", false)):
		mail_item_search_input.text = ""
		mail_item_search_input.placeholder_text = "Could not load bag"
		return

	mail_compose_inventory_items = _normalize_bag_inventory_items(result.get("items", []))
	mail_item_search_input.text = ""
	mail_item_search_input.editable = true
	mail_item_search_input.placeholder_text = "Search items in your bag" if not mail_compose_inventory_items.is_empty() else "No items in bag"
	mail_add_item_button.disabled = true

func _on_mail_item_search_changed(_text: String) -> void:
	mail_selected_item_for_attachment = {}
	mail_add_item_button.disabled = true
	_refresh_mail_item_suggestions()

func _refresh_mail_item_suggestions() -> void:
	_clear_mail_item_suggestions()

	var query: String = mail_item_search_input.text.strip_edges().to_lower()
	if query == "":
		return

	var added_count := 0
	for item: Dictionary in mail_compose_inventory_items:
		if not _is_mail_tradeable_bag_item(item):
			continue
		var item_id: String = str(item.get("id", "")).strip_edges()
		if _is_mail_item_already_attached(item_id):
			continue
		var item_name: String = str(item.get("name", _item_name_from_id(item_id))).strip_edges()
		var haystack: String = ("%s %s" % [item_id, item_name]).to_lower()
		if not haystack.contains(query):
			continue

		var button := Button.new()
		button.text = "%s x%s" % [item_name, int(item.get("quantity", 1))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 30)
		_apply_mail_card_style(button, false, false)
		button.pressed.connect(_on_mail_item_suggestion_pressed.bind(item))
		mail_item_suggestions.add_child(button)
		added_count += 1
		if added_count >= 6:
			break

func _clear_mail_item_suggestions() -> void:
	for child: Node in mail_item_suggestions.get_children():
		child.queue_free()

func _on_mail_item_suggestion_pressed(item: Dictionary) -> void:
	mail_selected_item_for_attachment = item.duplicate(true)
	var item_id: String = str(item.get("id", "")).strip_edges()
	mail_item_search_input.text = str(item.get("name", _item_name_from_id(item_id)))
	mail_item_quantity.max_value = max(int(item.get("quantity", 1)), 1)
	mail_item_quantity.value = 1
	mail_add_item_button.disabled = false
	_clear_mail_item_suggestions()

func _is_mail_tradeable_bag_item(item: Dictionary) -> bool:
	var category: String = str(item.get("category", "")).strip_edges().to_lower()
	return category not in ["key_items", "key-items", "important"]

func _is_mail_item_already_attached(item_id: String) -> bool:
	var normalized_item_id: String = item_id.strip_edges().to_lower()
	for attachment: Dictionary in mail_selected_item_attachments:
		if str(attachment.get("itemId", "")).strip_edges().to_lower() == normalized_item_id:
			return true
	return false

func _refresh_mail_pokemon_attachment_options() -> void:
	mail_compose_party_pokemon.clear()
	mail_pokemon_option.clear()
	for pokemon: Pokemon in PlayerSave.party:
		if pokemon == null:
			continue
		if pokemon.owned_pokemon_id <= 0:
			continue
		if not pokemon.tradable:
			continue
		if _get_pokemon_held_item_id(pokemon) != "":
			continue
		if mail_selected_pokemon_ids.has(pokemon.owned_pokemon_id):
			continue
		mail_compose_party_pokemon.append(pokemon)
		mail_pokemon_option.add_item("%s Lv. %s" % [pokemon.species, pokemon.level], mail_compose_party_pokemon.size() - 1)

	if mail_compose_party_pokemon.is_empty():
		mail_pokemon_option.add_item("No eligible Pokemon", -1)
		mail_pokemon_option.disabled = true
		mail_add_pokemon_button.disabled = true
	else:
		mail_pokemon_option.disabled = false
		mail_add_pokemon_button.disabled = mail_selected_pokemon_ids.size() >= 5 or mail_selected_pokemon_ids.size() >= max(PlayerSave.party.size() - 1, 0)

func _on_mail_add_item_attachment_pressed() -> void:
	if mail_selected_item_for_attachment.is_empty():
		return
	if mail_selected_item_attachments.size() >= 5:
		_add_chat_message("You can attach up to 5 item stacks.")
		return

	var item: Dictionary = mail_selected_item_for_attachment
	var available_quantity: int = int(item.get("quantity", 1))
	var quantity: int = clampi(int(mail_item_quantity.value), 1, available_quantity)
	var item_id: String = str(item.get("id", "")).strip_edges()
	if item_id == "":
		return

	for attachment: Dictionary in mail_selected_item_attachments:
		if str(attachment.get("itemId", "")) == item_id:
			attachment["quantity"] = min(int(attachment.get("quantity", 1)) + quantity, available_quantity)
			_refresh_mail_attachment_summary()
			return

	mail_selected_item_attachments.append({
		"itemId": item_id,
		"name": str(item.get("name", _item_name_from_id(item_id))),
		"quantity": quantity,
	})
	mail_selected_item_for_attachment = {}
	mail_item_search_input.clear()
	mail_add_item_button.disabled = true
	_refresh_mail_attachment_summary()

func _on_mail_add_pokemon_attachment_pressed() -> void:
	if mail_selected_pokemon_ids.size() >= 5:
		_add_chat_message("You can attach up to 5 Pokemon.")
		return
	if mail_selected_pokemon_ids.size() >= max(PlayerSave.party.size() - 1, 0):
		_add_chat_message("You must keep at least one Pokemon in your party.")
		return

	var selected_index: int = mail_pokemon_option.selected
	if selected_index < 0 or selected_index >= mail_compose_party_pokemon.size():
		return

	var pokemon: Pokemon = mail_compose_party_pokemon[selected_index]
	if pokemon == null or pokemon.owned_pokemon_id <= 0:
		return

	mail_selected_pokemon_ids.append(pokemon.owned_pokemon_id)
	_refresh_mail_pokemon_attachment_options()
	_refresh_mail_attachment_summary()

func _refresh_mail_attachment_summary() -> void:
	for child: Node in mail_selected_attachments_list.get_children():
		child.queue_free()

	var has_attachments: bool = not mail_selected_item_attachments.is_empty() or not mail_selected_pokemon_ids.is_empty()
	var has_item_attachments: bool = not mail_selected_item_attachments.is_empty()
	var has_pokemon_attachments: bool = not mail_selected_pokemon_ids.is_empty()

	_add_mail_summary_text("Attachment Overview")
	_add_mail_summary_divider()

	_add_mail_summary_text("Items")
	for attachment: Dictionary in mail_selected_item_attachments:
		_add_mail_summary_text("%sx %s" % [
			int(attachment.get("quantity", 1)),
			str(attachment.get("name", attachment.get("itemId", "Item"))),
		])
	if not has_item_attachments:
		_add_mail_summary_text("None")

	if has_item_attachments and has_pokemon_attachments:
		_add_mail_summary_divider()
	_add_mail_summary_text("Pokemon")
	for pokemon_id: int in mail_selected_pokemon_ids:
		var pokemon: Pokemon = _get_party_pokemon_by_owned_id(pokemon_id)
		if pokemon != null:
			_add_mail_summary_text("%s Lv. %s" % [pokemon.species, pokemon.level])
	if not has_pokemon_attachments:
		_add_mail_summary_text("None")

	if not has_attachments:
		_add_mail_summary_text("Selected attachments: none")
	_add_mail_summary_divider()
	_add_mail_summary_text("Item attachments: %s / 5" % mail_selected_item_attachments.size())
	_add_mail_summary_text("Pokemon attachments: %s / 5" % mail_selected_pokemon_ids.size())
	_add_mail_summary_text("Party kept: %s Pokemon" % max(PlayerSave.party.size() - mail_selected_pokemon_ids.size(), 0))

func _add_mail_summary_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	mail_selected_attachments_list.add_child(label)

func _add_mail_summary_divider() -> void:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color("#d8b76766")
	mail_selected_attachments_list.add_child(divider)

func _get_party_pokemon_by_owned_id(owned_pokemon_id: int) -> Pokemon:
	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null and pokemon.owned_pokemon_id == owned_pokemon_id:
			return pokemon
	return null

func _on_mail_compose_send_button_pressed() -> void:
	if not mail_selected_pokemon_ids.is_empty() and mail_selected_pokemon_ids.size() >= PlayerSave.party.size():
		_add_chat_message("You must keep at least one Pokemon in your party.")
		return

	var result: Dictionary = await MailService.send_mail(
		mail_compose_recipient_input.text,
		mail_compose_subject_input.text,
		mail_compose_body_input.text,
		mail_selected_item_attachments,
		mail_selected_pokemon_ids
	)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not send mail: %s" % str(result.get("error", "Unknown error")))
		return

	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		PlayerSave.replace_party_from_state(party_value as Array)
	var inventory_value: Variant = result.get("inventory", [])
	if inventory_value is Array:
		bag_inventory_items = _normalize_bag_inventory_items(inventory_value)
		bag_inventory_loaded = true
		_refresh_bag_items()
	var wallet_value: Variant = result.get("wallet", {})
	if wallet_value is Dictionary:
		PlayerWalletService.apply_wallet_result({"success": true, "wallet": wallet_value})
		refresh_money_display()

	mail_selected_item_attachments.clear()
	mail_selected_pokemon_ids.clear()
	mail_compose_popup.visible = false
	_deactivate_ui_panel(mail_compose_popup)
	var sent_mail: Dictionary = result.get("sent", {}) as Dictionary
	var fee_paid: int = int(sent_mail.get("feePaid", sent_mail.get("fee_paid", 0)))
	if fee_paid > 0:
		_add_chat_message("Mail sent. Paid %s." % _format_money(fee_paid))
	else:
		_add_chat_message("Mail sent.")
	_load_mailbox()

func _on_mail_compose_close_button_pressed() -> void:
	mail_compose_popup.visible = false
	_deactivate_ui_panel(mail_compose_popup)
	_hide_mail_compose_help_popup()

func _load_mailbox() -> void:
	var result: Dictionary = await MailService.load_mail(active_mail_box)
	if not bool(result.get("success", false)):
		_add_chat_message("Could not load mail: %s" % str(result.get("error", "Unknown error")))
		return

	mailbox_messages = _normalize_mailbox_messages(result.get("mail", []))
	var has_new_inbox_mail := false
	var has_mail_attention := false
	var has_unread_mail := false
	if active_mail_box == "inbox":
		has_mail_attention = _mail_messages_need_attention(mailbox_messages)
		has_unread_mail = _mail_messages_have_unread(mailbox_messages)
		has_new_inbox_mail = _update_mail_attention_session_state()
		if has_unread_mail and (has_new_inbox_mail or play_existing_mail_notification_on_next_inbox_load):
			_play_mail_notification_sound()
	play_existing_mail_notification_on_next_inbox_load = false
	if mail_popup != null and mail_popup.visible:
		if selected_mail_id > 0 and _get_mail_by_id(selected_mail_id).is_empty():
			selected_mail_id = -1
		if selected_mail_id <= 0 and not mailbox_messages.is_empty():
			selected_mail_id = int(mailbox_messages[0].get("id", -1))
			_mark_selected_mail_read()
	else:
		selected_mail_id = -1
	_refresh_mail_attention_from_messages(mailbox_messages)
	_refresh_mailbox()

func _normalize_mailbox_messages(value: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (value is Array):
		return normalized

	for mail_value: Variant in value:
		if not (mail_value is Dictionary):
			continue
		normalized.append((mail_value as Dictionary).duplicate(true))
	return normalized

func _refresh_mailbox() -> void:
	_refresh_mail_list()
	_refresh_mail_detail()
	_set_mail_popup_size.call_deferred()

func _refresh_mail_list() -> void:
	if mail_list == null:
		return

	for child: Node in mail_list.get_children():
		if child == mail_empty_inbox_label or child.name == "InboxLabel":
			continue
		child.queue_free()

	mail_empty_inbox_label.visible = mailbox_messages.is_empty()
	mail_empty_inbox_label.text = "No sent mail yet." if active_mail_box == "sent" else "No mail yet."
	for mail: Dictionary in mailbox_messages:
		var button := Button.new()
		var mail_id: int = int(mail.get("id", -1))
		var subject: String = str(mail.get("subject", "Mail")).strip_edges()
		var sender: String = str(mail.get("senderDisplayName", mail.get("senderUsername", "Unknown"))).strip_edges()
		var recipient: String = str(mail.get("recipientUsername", "Unknown")).strip_edges()
		var attachment_count: int = _array_from_variant(mail.get("attachments", [])).size()
		button.text = "%s\n%s %s%s" % [
			subject if subject != "" else "Mail",
			"To:" if active_mail_box == "sent" else "From:",
			(recipient if recipient != "" else "Unknown") if active_mail_box == "sent" else (sender if sender != "" else "Unknown"),
			" - %s attachment(s)" % attachment_count if attachment_count > 0 else "",
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = mail_id <= 0
		_apply_mail_card_style(button, mail_id == selected_mail_id, attachment_count > 0)
		button.pressed.connect(_on_mail_selected.bind(mail_id))
		mail_list.add_child(button)

func _on_mail_selected(mail_id: int) -> void:
	selected_mail_id = mail_id
	_refresh_mailbox()
	_refresh_mail_attention_from_messages(mailbox_messages)
	_mark_selected_mail_read()


func _mark_selected_mail_read() -> void:
	if active_mail_box != "inbox" or selected_mail_id <= 0:
		return

	var selected_mail: Dictionary = _get_mail_by_id(selected_mail_id)
	if selected_mail.is_empty() or _mail_message_is_read(selected_mail):
		return

	_set_mail_read_locally(selected_mail_id, Time.get_datetime_string_from_system(true))
	_refresh_mail_attention_from_messages(mailbox_messages)
	var result: Dictionary = await MailService.mark_mail_read(selected_mail_id)
	if not bool(result.get("success", false)):
		return

	var mail_value: Variant = result.get("mail", {})
	if mail_value is Dictionary:
		_replace_mailbox_message(mail_value as Dictionary)
		_refresh_mailbox()
		_refresh_mail_attention_from_messages(mailbox_messages)


func _set_mail_read_locally(mail_id: int, read_at: String) -> void:
	for index: int in range(mailbox_messages.size()):
		if int(mailbox_messages[index].get("id", -1)) != mail_id:
			continue
		mailbox_messages[index]["readAt"] = read_at
		return


func _replace_mailbox_message(mail: Dictionary) -> void:
	var mail_id: int = int(mail.get("id", -1))
	if mail_id <= 0:
		return
	for index: int in range(mailbox_messages.size()):
		if int(mailbox_messages[index].get("id", -1)) == mail_id:
			mailbox_messages[index] = mail.duplicate(true)
			return

func _refresh_mail_detail() -> void:
	var mail: Dictionary = _get_mail_by_id(selected_mail_id)
	if mail.is_empty():
		mail_subject_label.text = "Select a mail"
		mail_sender_label.text = "Sender: -"
		mail_body_label.text = "Mail messages and reward attachments will appear here."
		_render_mail_attachments([])
		mail_claim_button.visible = true
		mail_reply_button.visible = false
		mail_claim_button.text = "Claim Attachments" if active_mail_box == "inbox" else "No Claim Action"
		mail_claim_button.disabled = true
		mail_delete_button.disabled = true
		return

	mail_subject_label.text = str(mail.get("subject", "Mail"))
	if active_mail_box == "sent":
		mail_sender_label.text = "To: @%s" % str(mail.get("recipientUsername", "-"))
	else:
		mail_sender_label.text = "Sender: %s (@%s)" % [
			str(mail.get("senderDisplayName", "Unknown")),
			str(mail.get("senderUsername", "-")),
		]
	mail_body_label.text = str(mail.get("body", ""))
	if mail_body_label.text.strip_edges() == "":
		mail_body_label.text = "(No message)"

	var attachments: Array = _array_from_variant(mail.get("attachments", []))
	_render_mail_attachments(attachments)
	mail_claim_button.visible = true
	mail_reply_button.visible = _mail_can_reply(mail)
	mail_claim_button.text = "Claim Attachments" if active_mail_box == "inbox" else "No Claim Action"
	mail_claim_button.disabled = active_mail_box != "inbox" or not _mail_has_unclaimed_attachments(attachments)
	mail_delete_button.disabled = active_mail_box == "inbox" and _mail_has_unclaimed_attachments(attachments)

func _on_mail_reply_button_pressed() -> void:
	if selected_mail_id <= 0:
		return

	var selected_mail: Dictionary = _get_mail_by_id(selected_mail_id)
	if selected_mail.is_empty():
		return

	var raw_subject: String = str(selected_mail.get("subject", "")).strip_edges()
	var subject: String = _format_reply_subject(raw_subject)

	var recipient: String = str(
		selected_mail.get("senderUsername", "")
		if active_mail_box != "sent"
		else selected_mail.get("recipientUsername", "")
	).strip_edges().to_lower()
	if recipient == "":
		return

	_open_mail_compose_popup(recipient, subject)

func _format_reply_subject(subject: String) -> String:
	var normalized: String = subject.strip_edges()
	if normalized == "":
		return "Re: "
	if normalized.to_lower().begins_with("re:"):
		return normalized
	return "Re: %s" % normalized

func _mail_can_reply(mail: Dictionary) -> bool:
	if mail.is_empty():
		return false

	var can_reply_as_sender: bool = str(mail.get("senderUsername", "")).strip_edges() != ""
	var can_reply_as_recipient: bool = str(mail.get("recipientUsername", "")).strip_edges() != ""
	return can_reply_as_sender if active_mail_box != "sent" else can_reply_as_recipient

func _get_mail_by_id(mail_id: int) -> Dictionary:
	for mail: Dictionary in mailbox_messages:
		if int(mail.get("id", -1)) == mail_id:
			return mail
	return {}

func _render_mail_attachments(attachments: Array) -> void:
	for child: Node in mail_attachment_list.get_children():
		child.queue_free()

	if attachments.is_empty():
		var empty_label := Label.new()
		empty_label.text = "None"
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		mail_attachment_list.add_child(empty_label)
		return

	for attachment_value: Variant in attachments:
		if not (attachment_value is Dictionary):
			continue
		var attachment: Dictionary = attachment_value as Dictionary
		var payload: Dictionary = {}
		if attachment.get("payload", {}) is Dictionary:
			payload = attachment.get("payload", {}) as Dictionary
		var claimed: bool = _mail_attachment_is_claimed(attachment)
		var suffix := " (claimed)" if claimed else ""
		var attachment_id: int = int(attachment.get("id", -1))
		var can_claim: bool = active_mail_box == "inbox" and attachment_id > 0 and not claimed
		match str(attachment.get("type", "")):
			"item":
				mail_attachment_list.add_child(_create_mail_attachment_row(
					_load_item_icon(str(payload.get("itemId", ""))),
					"%sx %s%s" % [
					int(payload.get("quantity", 1)),
					str(payload.get("name", payload.get("itemId", "Item"))),
					suffix,
					],
					{},
					attachment_id,
					can_claim
				))
			"pokemon":
				var pokemon_payload: Dictionary = {}
				if payload.get("pokemon", {}) is Dictionary:
					pokemon_payload = payload.get("pokemon", {}) as Dictionary
				var species: String = str(pokemon_payload.get("species", "Pokemon"))
				var shiny: bool = bool(pokemon_payload.get("shiny", false))
				mail_attachment_list.add_child(_create_mail_attachment_row(
					PokemonAssets.load_party_icon(species, shiny),
					"%s Lv. %s%s" % [
					species,
					int(pokemon_payload.get("level", 1)),
					suffix,
					],
					pokemon_payload,
					attachment_id,
					can_claim
				))
			_:
				mail_attachment_list.add_child(_create_mail_attachment_row(
					null,
					"Attachment%s" % suffix,
					{},
					attachment_id,
					can_claim
				))

func _create_mail_attachment_row(
	icon_texture: Texture2D,
	text: String,
	pokemon_payload: Dictionary = {},
	attachment_id: int = -1,
	can_claim: bool = false
) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 42)
	panel.add_theme_stylebox_override("panel", _make_mail_attachment_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_texture
	row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	if not pokemon_payload.is_empty():
		var summary_button := Button.new()
		summary_button.text = "Summary"
		summary_button.custom_minimum_size = Vector2(74, 26)
		summary_button.focus_mode = Control.FOCUS_NONE
		summary_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		summary_button.tooltip_text = "View Pokemon summary"
		summary_button.pressed.connect(_on_mail_pokemon_attachment_pressed.bind(pokemon_payload))
		_apply_button_style(summary_button)
		row.add_child(summary_button)

	if can_claim:
		var claim_button := Button.new()
		claim_button.text = "Claim"
		claim_button.custom_minimum_size = Vector2(58, 26)
		claim_button.focus_mode = Control.FOCUS_NONE
		claim_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		claim_button.disabled = active_mail_box != "inbox"
		claim_button.pressed.connect(_on_mail_attachment_claim_pressed.bind(attachment_id))
		_apply_button_style(claim_button, "primary")
		row.add_child(claim_button)

	return panel

func _on_mail_pokemon_attachment_pressed(pokemon_payload: Dictionary) -> void:
	_open_readonly_pokemon_summary(pokemon_payload)

func _open_readonly_pokemon_summary(pokemon_payload: Dictionary) -> void:
	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_payload)
	if pokemon == null:
		_add_chat_message("Could not open Pokemon summary: %s" % PokemonFactory.last_error_message)
		return

	var card_key: String = _get_pokemon_summary_card_key(pokemon, -1, "readonly")
	if pokemon_summary_open_cards.has(card_key):
		_focus_pokemon_summary_card(card_key)
		return

	_setup_pokemon_summary_popup(card_key)
	pokemon_summary_preview_pokemon = pokemon
	pokemon_summary_mode = "readonly"
	pokemon_summary_selected_slot = -1
	pokemon_summary_sprite_side = "front"
	pokemon_summary_item_picker.visible = false
	pokemon_summary_ball_picker.visible = false
	pokemon_summary_active_tab = "general"
	pokemon_summary_active_card_key = card_key
	pokemon_summary_open_cards[card_key] = _capture_pokemon_summary_card_context(card_key, pokemon, "readonly", -1)
	_position_new_pokemon_summary_card()
	_set_pokemon_summary_popup_size()
	_refresh_pokemon_summary()
	pokemon_summary_popup.visible = true
	_activate_ui_panel(pokemon_summary_popup)

func _make_mail_outer_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#07101bf4"), Color("#e6c777"), 12, 1)
	style.shadow_color = Color("#00000088")
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_mail_inner_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#0a1423e8"), Color("#315070"), 8, 1)
	style.shadow_color = Color("#00000044")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style

func _make_mail_attachment_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#101b2cf0"), Color("#d8b76755"), 8, 1)
	style.shadow_color = Color("#00000044")
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

func _apply_mail_card_style(button: Button, selected: bool, has_attachments: bool) -> void:
	var border := Color("#d8b767") if selected else Color("#315070")
	if has_attachments and not selected:
		border = Color("#7aa7f4")
	var normal_bg := Color("#172234f2") if selected else Color("#101724e8")
	var hover_bg := Color("#1f2b42f2")
	var pressed_bg := Color("#0b1322f2")
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border, 7, 1))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, UI_BORDER, 7, 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, UI_BORDER, 7, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_bg, UI_BORDER_FOCUS, 7, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)

func _mail_has_unclaimed_attachments(attachments: Array) -> bool:
	for attachment_value: Variant in attachments:
		if not (attachment_value is Dictionary):
			continue
		var attachment: Dictionary = attachment_value as Dictionary
		if not _mail_attachment_is_claimed(attachment):
			return true
	return false

func _mail_attachment_is_claimed(attachment: Dictionary) -> bool:
	var claimed_at: Variant = attachment.get("claimedAt", attachment.get("claimed_at", null))
	if claimed_at == null:
		return false
	return str(claimed_at).strip_edges() != ""

func _mail_dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _array_from_variant(value: Variant) -> Array:
	if value is Array:
		return value as Array
	return []

func _on_guild_button_pressed() -> void:
	_add_chat_message("Guild is not implemented yet.")

func _on_pvp_button_pressed() -> void:
	if pvp_room_popup == null:
		return
	if pvp_room_popup.visible:
		_hide_pvp_room_popup()
		return
	pvp_room_popup.visible = true
	_activate_ui_panel(pvp_room_popup)
	await _refresh_pvp_queue_list()
	await _refresh_pvp_match_history()

func _hide_pvp_room_popup() -> void:
	if pvp_room_popup == null:
		return
	if pvp_poll_timer != null:
		pvp_poll_timer.stop()
	pvp_polling_active = false
	pvp_queue_polling_active = false
	pvp_queue_poll_in_flight = false
	pvp_queue_list_in_flight = false
	pvp_history_in_flight = false
	pvp_poll_elapsed = 0.0
	pvp_room_popup.visible = false
	_deactivate_ui_panel(pvp_room_popup)

func _on_pvp_create_room_pressed() -> void:
	if pvp_battle_starting:
		return
	_set_pvp_room_busy(true, "Creating room...")
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.create_pvp_room(
		request,
		BattleApiPayloads.from_player_save(PlayerSave)
	)
	request.queue_free()
	_set_pvp_room_busy(false)

	if not bool(response.get("success", false)):
		_set_pvp_status("Could not create room: %s" % str(response.get("error", "Unknown error")))
		return

	pvp_active_room_code = str(response.get("roomCode", "")).strip_edges()
	pvp_room_code_label.text = "Room Code: %s" % pvp_active_room_code
	pvp_copy_code_button.disabled = pvp_active_room_code == ""
	_set_pvp_status("Waiting for another player...")
	if pvp_active_room_code != "":
		_start_pvp_room_polling()

func _on_pvp_join_room_pressed() -> void:
	if pvp_battle_starting:
		return
	var room_code := pvp_room_code_input.text.strip_edges().to_upper()
	if room_code == "":
		_set_pvp_status("Enter a room code first.")
		return

	_set_pvp_room_busy(true, "Joining room...")
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.join_pvp_room(
		request,
		room_code,
		BattleApiPayloads.from_player_save(PlayerSave)
	)
	request.queue_free()
	_set_pvp_room_busy(false)

	if not bool(response.get("success", false)):
		if _can_reconnect_to_started_pvp_room(response):
			pvp_active_room_code = str(response.get("roomCode", room_code)).strip_edges()
			pvp_room_code_label.text = "Room Code: %s" % pvp_active_room_code
			pvp_copy_code_button.disabled = pvp_active_room_code == ""
			_set_pvp_status("Room already started. Reconnecting...")
			await _start_pvp_battle_from_response(_normalize_started_pvp_reconnect_response(response))
			return
		_set_pvp_status("Could not join room: %s" % str(response.get("error", "Unknown error")))
		return

	pvp_active_room_code = str(response.get("roomCode", room_code)).strip_edges()
	pvp_room_code_label.text = "Room Code: %s" % pvp_active_room_code
	pvp_copy_code_button.disabled = pvp_active_room_code == ""
	await _start_pvp_battle_from_response(response)

func _on_pvp_join_queue_pressed() -> void:
	if pvp_battle_starting:
		return
	_set_pvp_room_busy(true, "Joining queue...")
	_set_pvp_queue_status("Queue Status: joining...")
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.join_pvp_queue(
		request,
		pvp_active_queue_id,
		BattleApiPayloads.from_player_save(PlayerSave)
	)
	request.queue_free()
	_set_pvp_room_busy(false)

	if not bool(response.get("success", false)):
		_set_pvp_queue_status("Queue Status: join failed: %s" % str(response.get("error", "Unknown error")))
		return

	var entry: Dictionary = _pvp_queue_entry_from_response(response)
	if entry.is_empty():
		_set_pvp_queue_status("Queue Status: joined, but server returned no entry.")
		return

	_update_pvp_queue_state_from_entry(entry)
	var status := str(entry.get("status", "")).strip_edges().to_lower()
	if status == "matched" and pvp_active_queue_match_id != "":
		await _open_pvp_queue_match(true)
	else:
		_start_pvp_queue_polling()

func _refresh_pvp_queue_list() -> void:
	if pvp_queue_list_in_flight or pvp_battle_starting:
		return
	pvp_queue_list_in_flight = true
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.get_pvp_queues(request)
	request.queue_free()
	pvp_queue_list_in_flight = false

	if not bool(response.get("success", false)):
		if pvp_available_queues.is_empty():
			_populate_pvp_queue_select([
				{"id": "casual_queue_v1", "name": "Casual Queue", "mode": "casual"},
			])
		return

	var queues_value: Variant = response.get("queues", [])
	if not (queues_value is Array):
		return

	var queues: Array[Dictionary] = []
	for item: Variant in queues_value as Array:
		if not (item is Dictionary):
			continue
		var queue: Dictionary = item as Dictionary
		if str(queue.get("status", "")).strip_edges().to_lower() != "active":
			continue
		var queue_id := str(queue.get("id", "")).strip_edges()
		if queue_id == "":
			continue
		queues.append(queue.duplicate(true))

	if queues.is_empty():
		return
	_populate_pvp_queue_select(queues)

func _populate_pvp_queue_select(queues: Array[Dictionary]) -> void:
	pvp_available_queues = queues
	if pvp_queue_select == null:
		return

	pvp_queue_select.clear()
	for queue: Dictionary in pvp_available_queues:
		var queue_id := str(queue.get("id", "")).strip_edges()
		if queue_id == "":
			continue
		var queue_name := str(queue.get("name", queue_id)).strip_edges()
		var queue_mode := str(queue.get("mode", "")).strip_edges()
		var label := queue_name
		if queue_mode != "":
			label = "%s (%s)" % [queue_name, queue_mode.capitalize()]
		pvp_queue_select.add_item(label)
		pvp_queue_select.set_item_metadata(pvp_queue_select.item_count - 1, queue_id)

	if pvp_queue_select.item_count == 0:
		pvp_queue_select.add_item("Casual Queue")
		pvp_queue_select.set_item_metadata(0, "casual_queue_v1")

	if not _select_pvp_queue_by_id(pvp_active_queue_id):
		pvp_active_queue_id = str(pvp_queue_select.get_item_metadata(0)).strip_edges()
		pvp_queue_select.select(0)

func _select_pvp_queue_by_id(queue_id: String) -> bool:
	if pvp_queue_select == null:
		return false
	var normalized_queue_id := queue_id.strip_edges()
	for index in range(pvp_queue_select.item_count):
		var metadata_value: Variant = pvp_queue_select.get_item_metadata(index)
		if str(metadata_value).strip_edges() == normalized_queue_id:
			pvp_queue_select.select(index)
			return true
	return false

func _on_pvp_queue_selected(index: int) -> void:
	if pvp_queue_select == null:
		return
	if pvp_battle_starting or pvp_active_queue_entry_id != "" or pvp_active_queue_match_id != "":
		_select_pvp_queue_by_id(pvp_active_queue_id)
		return
	if index < 0 or index >= pvp_queue_select.item_count:
		return
	var queue_id := str(pvp_queue_select.get_item_metadata(index)).strip_edges()
	if queue_id == "":
		return
	pvp_active_queue_id = queue_id
	_set_pvp_queue_status("Queue Status: idle")
	_refresh_pvp_queue_buttons("idle")

func _on_pvp_history_refresh_pressed() -> void:
	await _refresh_pvp_match_history()

func _refresh_pvp_match_history() -> void:
	if pvp_history_in_flight:
		return
	pvp_history_in_flight = true
	if pvp_history_refresh_button != null:
		pvp_history_refresh_button.disabled = true
	if pvp_history_status_label != null:
		pvp_history_status_label.text = "Loading recent matches..."
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.get_pvp_match_history(request, 20, 0)
	request.queue_free()
	pvp_history_in_flight = false
	if pvp_history_refresh_button != null:
		pvp_history_refresh_button.disabled = false

	if not bool(response.get("success", false)):
		if pvp_history_status_label != null:
			pvp_history_status_label.text = "Could not load match history."
		_render_pvp_history_matches([], 0)
		return

	var matches_value: Variant = response.get("matches", [])
	var matches: Array = matches_value as Array if matches_value is Array else []
	var user_id := _pvp_history_variant_to_user_id(response.get("userId", 0))
	if pvp_history_status_label != null:
		pvp_history_status_label.text = "Recent matches"
	_render_pvp_history_matches(matches, user_id)

func _render_pvp_history_matches(matches: Array, user_id: int) -> void:
	if pvp_history_list == null:
		return
	for child in pvp_history_list.get_children():
		child.queue_free()

	if matches.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No PvP matches yet."
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pvp_history_list.add_child(empty_label)
		return

	for item: Variant in matches:
		if not (item is Dictionary):
			continue
		pvp_history_list.add_child(_create_pvp_history_card(item as Dictionary, user_id))

func _create_pvp_history_card(match: Dictionary, user_id: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912e8"), Color("#d9b45f"), 6, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title := Label.new()
	title.text = _pvp_history_title(match, user_id)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UI_TEXT)
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	var status := Label.new()
	status.text = _pvp_history_result_label(match, user_id)
	status.add_theme_color_override("font_color", _pvp_history_result_color(status.text))
	header.add_child(status)

	var detail := Label.new()
	detail.text = _pvp_history_detail(match, user_id)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(detail)

	return card

func _pvp_history_title(match: Dictionary, user_id: int) -> String:
	var opponent_name := _pvp_history_opponent_name(match, user_id)
	var result_label := _pvp_history_result_label(match, user_id)
	var mode := _pvp_history_mode_label(match)
	if opponent_name != "":
		return "%s vs %s%s" % [result_label, opponent_name, " - %s" % mode if mode != "" else ""]
	var participants := _array_from_variant(match.get("participants", []))
	var names: Array[String] = []
	for participant_value: Variant in participants:
		if not (participant_value is Dictionary):
			continue
		var participant: Dictionary = participant_value as Dictionary
		var display_name := str(participant.get("displayName", "Player")).strip_edges()
		if display_name != "":
			names.append(display_name)
	var matchup := " vs ".join(names) if names.size() >= 2 else "PvP Match"
	return "%s%s" % [matchup, " - %s" % mode if mode != "" else ""]

func _pvp_history_detail(match: Dictionary, user_id: int) -> String:
	var winner_user_id := _pvp_history_variant_to_user_id(match.get("winnerUserId", 0))
	var loser_user_id := _pvp_history_variant_to_user_id(match.get("loserUserId", 0))
	var winner_name := _pvp_history_participant_name(match, winner_user_id)
	var loser_name := _pvp_history_participant_name(match, loser_user_id)
	var opponent_name := _pvp_history_opponent_name(match, user_id)
	var reason := _pvp_history_reason_label(match)
	var settled_at := _pvp_history_time_label(str(match.get("settledAt", match.get("endedAt", ""))).strip_edges())
	var final_seq := _pvp_history_seq_label(match.get("finalEventSeq", null))
	var result_text := "Result pending"
	if user_id > 0 and winner_user_id == user_id and opponent_name != "":
		result_text = "You defeated %s" % opponent_name
	elif user_id > 0 and loser_user_id == user_id and opponent_name != "":
		result_text = "You lost to %s" % opponent_name
	elif winner_name != "":
		result_text = "%s defeated %s" % [winner_name, loser_name if loser_name != "" else "opponent"]
	if reason != "":
		result_text = "%s by %s" % [result_text, reason]
	if final_seq != "":
		result_text = "%s · %s" % [result_text, final_seq]
	if settled_at != "":
		result_text = "%s · %s" % [result_text, settled_at]
	return result_text

func _pvp_history_result_label(match: Dictionary, user_id: int) -> String:
	var winner_user_id := _pvp_history_variant_to_user_id(match.get("winnerUserId", 0))
	var loser_user_id := _pvp_history_variant_to_user_id(match.get("loserUserId", 0))
	if user_id > 0 and winner_user_id == user_id:
		return "Win"
	if user_id > 0 and loser_user_id == user_id:
		return "Loss"
	var status := str(match.get("status", "")).strip_edges()
	return status.capitalize() if status != "" else "Pending"

func _pvp_history_result_color(result_label: String) -> Color:
	var normalized := result_label.strip_edges().to_lower()
	if normalized == "win":
		return Color("#65e38b")
	if normalized == "loss":
		return Color("#ff7a7a")
	return Color("#f5df9a")

func _pvp_history_opponent_name(match: Dictionary, user_id: int) -> String:
	if user_id <= 0:
		return ""
	var participants := _array_from_variant(match.get("participants", []))
	for participant_value: Variant in participants:
		if not (participant_value is Dictionary):
			continue
		var participant: Dictionary = participant_value as Dictionary
		if _pvp_history_variant_to_user_id(participant.get("userId", 0)) != user_id:
			return str(participant.get("displayName", "Player")).strip_edges()
	return ""

func _pvp_history_mode_label(match: Dictionary) -> String:
	var mode := str(match.get("mode", "")).strip_edges().to_lower()
	if mode == "":
		return ""
	return mode.capitalize()

func _pvp_history_reason_label(match: Dictionary) -> String:
	var reason := str(match.get("reason", "")).strip_edges().to_lower()
	match reason:
		"battle_end":
			return "Battle End"
		"forfeit":
			return "Forfeit"
		"timeout":
			return "Timeout"
		"disconnect":
			return "Disconnect"
		_:
			return reason.replace("_", " ").capitalize() if reason != "" else ""

func _pvp_history_seq_label(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text == "" or text.to_lower() == "<null>" or text.to_lower() == "null":
		return ""
	return "Event #%s" % text

func _pvp_history_time_label(value: String) -> String:
	if value == "":
		return ""
	var normalized := value.replace("T", " ").replace("Z", "")
	if normalized.length() >= 16:
		return normalized.substr(0, 16)
	return normalized

func _pvp_history_participant_name(match: Dictionary, user_id: int) -> String:
	if user_id <= 0:
		return ""
	var participants := _array_from_variant(match.get("participants", []))
	for participant_value: Variant in participants:
		if not (participant_value is Dictionary):
			continue
		var participant: Dictionary = participant_value as Dictionary
		if _pvp_history_variant_to_user_id(participant.get("userId", 0)) == user_id:
			return str(participant.get("displayName", "Player")).strip_edges()
	return ""

func _pvp_history_variant_to_user_id(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return roundi(value)
	var text := str(value).strip_edges()
	if text.is_valid_int():
		return text.to_int()
	return 0

func _on_pvp_leave_queue_pressed() -> void:
	if pvp_battle_starting or pvp_active_queue_id == "":
		return
	_set_pvp_room_busy(true, "Leaving queue...")
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.leave_pvp_queue(request, pvp_active_queue_id)
	request.queue_free()
	_set_pvp_room_busy(false)

	if not bool(response.get("success", false)):
		_set_pvp_queue_status("Queue Status: leave failed: %s" % str(response.get("error", "Unknown error")))
		return

	pvp_active_queue_entry_id = ""
	pvp_active_queue_match_id = ""
	pvp_queue_polling_active = false
	if pvp_poll_timer != null:
		pvp_poll_timer.stop()
	_set_pvp_queue_status("Queue Status: left queue.")
	_refresh_pvp_queue_buttons("idle")

func _open_pvp_queue_match(auto_open: bool) -> void:
	if pvp_battle_starting:
		return
	if auto_open and pvp_queue_auto_open_in_flight:
		return
	if pvp_active_queue_match_id == "":
		_set_pvp_queue_status("Queue Status: no matched battle yet.")
		return

	pvp_queue_auto_open_in_flight = auto_open
	var busy_message := "Starting matched battle..." if auto_open else "Opening queue battle..."
	_set_pvp_room_busy(true, busy_message)
	_set_pvp_queue_status("Queue Status: starting matched battle..." if auto_open else "Queue Status: opening battle...")
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.start_pvp_match_battle(request, pvp_active_queue_match_id)
	request.queue_free()
	_set_pvp_room_busy(false)
	pvp_queue_auto_open_in_flight = false

	if not bool(response.get("success", false)):
		_set_pvp_queue_status("Queue Status: could not start battle: %s" % str(response.get("error", "Unknown error")))
		_refresh_pvp_queue_buttons("matched")
		return

	if str(response.get("roomCode", "")).strip_edges() == "":
		response["roomCode"] = pvp_active_queue_match_id.to_upper()
	await _start_pvp_battle_from_response(response)

func _on_pvp_reconnect_battle_pressed() -> void:
	if pvp_battle_starting:
		return

	_set_pvp_room_busy(true, "Checking active battle...")
	_set_pvp_queue_status("Queue Status: checking active battle...")
	var active_request := _create_pvp_request_node()
	var active_response: Dictionary = await BattleApiClient.get_active_pvp_match(active_request)
	active_request.queue_free()

	if not bool(active_response.get("success", false)):
		_set_pvp_room_busy(false)
		_set_pvp_queue_status("Queue Status: no active battle found.")
		return

	var match_id := str(active_response.get("matchId", "")).strip_edges()
	if match_id == "":
		_set_pvp_room_busy(false)
		_set_pvp_queue_status("Queue Status: active battle has no match id.")
		return

	pvp_active_queue_match_id = match_id
	_set_pvp_queue_status("Queue Status: reconnecting...")
	var start_request := _create_pvp_request_node()
	var start_response: Dictionary = await BattleApiClient.start_pvp_match_battle(start_request, match_id)
	start_request.queue_free()
	_set_pvp_room_busy(false)

	if not bool(start_response.get("success", false)):
		_set_pvp_queue_status("Queue Status: reconnect failed: %s" % str(start_response.get("error", "Unknown error")))
		return

	if str(start_response.get("roomCode", "")).strip_edges() == "":
		start_response["roomCode"] = match_id.to_upper()
	await _start_pvp_battle_from_response(start_response)

func _can_reconnect_to_started_pvp_room(response: Dictionary) -> bool:
	if bool(response.get("success", false)):
		return false
	if str(response.get("status", "")).strip_edges().to_lower() != "started":
		return false
	if not bool(response.get("reconnectAvailable", false)):
		return false
	var battle_id := str(response.get("battleId", "")).strip_edges()
	if battle_id != "":
		return true
	var battle: Variant = response.get("battle", {})
	return battle is Dictionary and str((battle as Dictionary).get("battleId", "")).strip_edges() != ""

func _normalize_started_pvp_reconnect_response(response: Dictionary) -> Dictionary:
	var normalized: Dictionary = response.duplicate(true)
	var battle: Variant = normalized.get("battle", {})
	if battle is Dictionary:
		for key in (battle as Dictionary).keys():
			if not normalized.has(key):
				normalized[key] = (battle as Dictionary)[key]
	normalized["success"] = true
	normalized["status"] = "started"
	if not normalized.has("playerId"):
		normalized["playerId"] = "p1"
	return normalized

func _on_pvp_copy_code_pressed() -> void:
	if pvp_active_room_code == "":
		return
	DisplayServer.clipboard_set(pvp_active_room_code)
	_set_pvp_status("Room code copied.")

func _on_pvp_poll_timeout() -> void:
	if pvp_queue_polling_active:
		if pvp_queue_poll_in_flight or pvp_battle_starting or pvp_queue_auto_open_in_flight:
			return
		await _poll_pvp_queue_status()
		return
	if not pvp_polling_active or pvp_poll_in_flight or pvp_active_room_code == "" or pvp_battle_starting:
		return
	await _poll_pvp_room()

func _start_pvp_room_polling() -> void:
	if pvp_polling_active:
		return
	pvp_polling_active = true
	pvp_poll_elapsed = 0.0

func _start_pvp_queue_polling() -> void:
	pvp_queue_polling_active = true
	if pvp_poll_timer != null and pvp_poll_timer.is_stopped():
		pvp_poll_timer.start()

func _poll_pvp_queue_status() -> void:
	if pvp_queue_poll_in_flight:
		return
	pvp_queue_poll_in_flight = true
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.get_pvp_queue_status(request)
	request.queue_free()
	pvp_queue_poll_in_flight = false

	if not bool(response.get("success", false)):
		_set_pvp_queue_status("Queue Status: check failed: %s" % str(response.get("error", "Unknown error")))
		return

	var entry: Dictionary = _latest_relevant_pvp_queue_entry(response)
	if entry.is_empty():
		pvp_queue_polling_active = false
		if pvp_poll_timer != null:
			pvp_poll_timer.stop()
		pvp_active_queue_entry_id = ""
		pvp_active_queue_match_id = ""
		_set_pvp_queue_status("Queue Status: idle")
		_refresh_pvp_queue_buttons("idle")
		return

	_update_pvp_queue_state_from_entry(entry)
	var status := str(entry.get("status", "")).strip_edges().to_lower()
	if status == "matched" and pvp_active_queue_match_id != "":
		await _open_pvp_queue_match(true)

func _pvp_queue_entry_from_response(response: Dictionary) -> Dictionary:
	var entry_value: Variant = response.get("entry", {})
	if entry_value is Dictionary:
		return (entry_value as Dictionary).duplicate(true)
	return {}

func _latest_relevant_pvp_queue_entry(response: Dictionary) -> Dictionary:
	var entries_value: Variant = response.get("entries", [])
	if not (entries_value is Array):
		return {}
	var entries: Array = entries_value as Array
	for item: Variant in entries:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item as Dictionary
		var status := str(entry.get("status", "")).strip_edges().to_lower()
		if status == "matched" or status == "waiting":
			return entry.duplicate(true)
	return {}

func _update_pvp_queue_state_from_entry(entry: Dictionary) -> void:
	var status := str(entry.get("status", "")).strip_edges().to_lower()
	pvp_active_queue_entry_id = str(entry.get("id", "")).strip_edges()
	pvp_active_queue_id = str(entry.get("queueId", pvp_active_queue_id)).strip_edges()
	pvp_active_queue_match_id = str(entry.get("matchId", "")).strip_edges()
	if pvp_active_queue_id == "":
		pvp_active_queue_id = "casual_queue_v1"
	_select_pvp_queue_by_id(pvp_active_queue_id)

	if status == "matched" and pvp_active_queue_match_id != "":
		pvp_queue_polling_active = false
		if pvp_poll_timer != null:
			pvp_poll_timer.stop()
		_set_pvp_queue_status("Queue Status: match found.")
	elif status == "waiting":
		_set_pvp_queue_status("Queue Status: waiting for opponent...")
	else:
		_set_pvp_queue_status("Queue Status: %s" % (status if status != "" else "unknown"))
	_refresh_pvp_queue_buttons(status)

func _refresh_pvp_queue_buttons(status: String) -> void:
	if pvp_join_queue_button == null or pvp_leave_queue_button == null:
		return
	var normalized_status := status.strip_edges().to_lower()
	pvp_join_queue_button.disabled = pvp_battle_starting or normalized_status == "waiting" or normalized_status == "matched"
	pvp_leave_queue_button.disabled = pvp_battle_starting or normalized_status != "waiting"
	if pvp_queue_select != null:
		pvp_queue_select.disabled = pvp_battle_starting or normalized_status == "waiting" or normalized_status == "matched"
	if pvp_reconnect_battle_button != null:
		pvp_reconnect_battle_button.disabled = pvp_battle_starting

func _poll_pvp_room() -> void:
	if pvp_poll_in_flight or pvp_active_room_code == "":
		return
	pvp_poll_in_flight = true
	var request := _create_pvp_request_node()
	var response: Dictionary = await BattleApiClient.get_pvp_room(request, pvp_active_room_code, "p1")
	request.queue_free()
	pvp_poll_in_flight = false

	if not bool(response.get("success", false)):
		_set_pvp_status("Room check failed: %s" % str(response.get("error", "Unknown error")))
		return

	var status := str(response.get("status", "waiting"))
	if status != "started":
		_set_pvp_status("Waiting for another player...")
		return

	await _start_pvp_battle_from_response(response)

func _request_pvp_room_poll() -> void:
	if pvp_poll_in_flight or pvp_active_room_code == "" or pvp_poll_request == null:
		return

	pvp_poll_in_flight = true
	var api_base_url := str(GatewayApiConfig.cached_url).strip_edges()
	if api_base_url == "":
		api_base_url = GatewayApiConfig.LOCAL_GATEWAY_URL if OS.has_feature("editor") else GatewayApiConfig.PRODUCTION_GATEWAY_URL

	var path := "/battle/pvp/rooms/%s?playerId=p1" % pvp_active_room_code.uri_encode()
	var error := pvp_poll_request.request(
		api_base_url.rstrip("/") + path,
		GatewayApiConfig.get_accept_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		pvp_poll_in_flight = false
		_set_pvp_status("Room check failed to start: %s" % error_string(error))

func _on_pvp_room_poll_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	pvp_poll_in_flight = false
	if not pvp_polling_active or pvp_active_room_code == "" or pvp_battle_starting:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_pvp_status("Room check failed: %s" % result)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_set_pvp_status("Room check failed: invalid response (%s)." % response_code)
		return

	var response: Dictionary = parsed as Dictionary
	if not bool(response.get("success", false)):
		_set_pvp_status("Room check failed: %s" % str(response.get("error", response.get("detail", "Unknown error"))))
		return

	var status := str(response.get("status", "waiting"))
	if status != "started":
		_set_pvp_status("Waiting for another player... (%s)" % status)
		return

	_set_pvp_status("Opponent joined. Starting battle...")
	await _start_pvp_battle_from_response(response)

func _start_pvp_battle_from_response(response: Dictionary) -> void:
	if pvp_battle_starting:
		return
	pvp_battle_starting = true
	if pvp_poll_timer != null:
		pvp_poll_timer.stop()
	_set_pvp_status("Starting battle...")

	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("start_pvp_battle_from_response"):
		_set_pvp_status("Could not start PvP battle from this scene.")
		pvp_battle_starting = false
		return

	var started: bool = await world.start_pvp_battle_from_response(response)
	if not started:
		_set_pvp_status("Could not start PvP battle.")
		pvp_battle_starting = false
		return

	_hide_pvp_room_popup()
	pvp_active_room_code = ""
	pvp_active_queue_entry_id = ""
	pvp_active_queue_match_id = ""
	pvp_queue_polling_active = false
	pvp_queue_poll_in_flight = false
	pvp_queue_auto_open_in_flight = false
	pvp_polling_active = false
	pvp_poll_elapsed = 0.0
	pvp_room_code_label.text = "Room Code: -"
	pvp_copy_code_button.disabled = true
	_set_pvp_queue_status("Queue Status: idle")
	_refresh_pvp_queue_buttons("idle")
	pvp_battle_starting = false

func _create_pvp_request_node() -> HTTPRequest:
	var request := HTTPRequest.new()
	add_child(request)
	return request

func _set_pvp_room_busy(is_busy: bool, message: String = "") -> void:
	pvp_create_room_button.disabled = is_busy
	pvp_join_room_button.disabled = is_busy
	if pvp_join_queue_button != null:
		pvp_join_queue_button.disabled = is_busy or pvp_active_queue_entry_id != "" or pvp_active_queue_match_id != ""
	if pvp_leave_queue_button != null:
		pvp_leave_queue_button.disabled = is_busy or pvp_active_queue_entry_id == "" or pvp_active_queue_match_id != ""
	if pvp_queue_select != null:
		pvp_queue_select.disabled = is_busy or pvp_active_queue_entry_id != "" or pvp_active_queue_match_id != ""
	if pvp_reconnect_battle_button != null:
		pvp_reconnect_battle_button.disabled = is_busy
	if message != "":
		_set_pvp_status(message)

func _set_pvp_status(message: String) -> void:
	if pvp_room_status_label != null:
		pvp_room_status_label.text = message

func _set_pvp_queue_status(message: String) -> void:
	if pvp_queue_status_label != null:
		pvp_queue_status_label.text = message

func _on_map_button_pressed() -> void:
	_add_chat_message("Town Map is not implemented yet.")

func _on_running_shoes_toggled(enabled: bool) -> void:
	GameState.running_shoes_enabled = enabled
	_set_icon_slot_active(running_shoes_slot, enabled)
	_refresh_world_running_shoes_state()
	await _save_toggle_preferences()

func _on_settings_menu_closed() -> void:
	if settings_button.has_focus():
		settings_button.release_focus()
	if not _has_visible_priority_overlay_panel():
		layer = UI_OVERLAY_BASE_LAYER

func _disable_icon_button_focus() -> void:
	for button: BaseButton in [
		map_button,
		running_shoes_button,
		bag_button,
		socials_button,
		guild_button,
		pvp_button,
		settings_button,
		repel_toggle_button,
		follower_toggle_button,
		dev_actions_button,
	]:
		if button != null:
			button.focus_mode = Control.FOCUS_NONE

func _add_chat_message(text: String, use_bbcode: bool = false) -> void:
	var entry := message_entry_template.duplicate() as RichTextLabel
	message_list.add_child(entry)
	entry.set_meta("chat_category", CHAT_CATEGORY_SYSTEM)
	entry.visible = _should_show_chat_category(CHAT_CATEGORY_SYSTEM)
	entry.bbcode_enabled = true
	entry.clear()
	if use_bbcode:
		entry.append_text(text)
	else:
		entry.append_text(_format_system_chat_message(text))
	entry.fit_content = true
	entry.scroll_active = false
	_scroll_chat_to_bottom.call_deferred()


func add_system_message(text: String) -> void:
	_add_chat_message(text)

func add_system_pokemon_message(text: String, pokemon_attachments: Array = []) -> void:
	var attachments: Array[Dictionary] = []
	for attachment_value: Variant in pokemon_attachments:
		if attachment_value is Dictionary:
			var attachment := (attachment_value as Dictionary).duplicate(true)
			if not attachment.is_empty():
				attachments.append(attachment)

	var message_text := text.strip_edges()
	if message_text == "" and attachments.is_empty():
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 4)
	row.set_meta("chat_category", CHAT_CATEGORY_SYSTEM)
	row.visible = _should_show_chat_category(CHAT_CATEGORY_SYSTEM)
	message_list.add_child(row)

	var system_label := message_entry_template.duplicate() as RichTextLabel
	row.add_child(system_label)
	system_label.visible = true
	system_label.bbcode_enabled = true
	system_label.clear()
	system_label.append_text("[color=%s][b]SYSTEM[/b][/color][color=%s]:[/color]" % [
		CHAT_SYSTEM_LABEL_COLOR,
		CHAT_SEPARATOR_COLOR,
	])
	system_label.fit_content = true
	system_label.scroll_active = false
	system_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	system_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	system_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	for pokemon_payload: Dictionary in attachments:
		row.add_child(_create_chat_pokemon_attachment_button(pokemon_payload))

	if message_text != "":
		var entry: RichTextLabel = message_entry_template.duplicate() as RichTextLabel
		row.add_child(entry)
		entry.visible = true
		entry.bbcode_enabled = true
		entry.clear()
		entry.append_text("[color=%s]%s[/color]" % [
			CHAT_SYSTEM_MESSAGE_COLOR,
			_escape_bbcode(message_text),
		])
		entry.fit_content = true
		entry.scroll_active = false
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scroll_chat_to_bottom.call_deferred()


func refresh_money_display() -> void:
	_refresh_player_status_card()


func _format_system_chat_message(text: String) -> String:
	return "[color=%s][b]SYSTEM[/b][/color][color=%s]:[/color] [color=%s]%s[/color]" % [
		CHAT_SYSTEM_LABEL_COLOR,
		CHAT_SEPARATOR_COLOR,
		CHAT_SYSTEM_MESSAGE_COLOR,
		_escape_bbcode(text),
	]

func _scroll_chat_to_bottom() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree() or message_scroll == null:
		return
	tree = get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree() or message_scroll == null:
		return
	var vertical_scroll_bar: VScrollBar = message_scroll.get_v_scroll_bar()
	if vertical_scroll_bar == null:
		return
	message_scroll.scroll_vertical = int(vertical_scroll_bar.max_value)

func _on_chat_realtime_message_received(message: Dictionary) -> void:
	if str(message.get("type", "")) == "chat_error":
		var error_text: String = str(message.get("message", "Chat message could not be sent."))
		_add_chat_message(error_text)
		return

	if str(message.get("type", "")) != "chat":
		return

	var user: Dictionary = {}
	var user_value: Variant = message.get("user", {})
	if user_value is Dictionary:
		user = user_value as Dictionary

	var display_name: String = str(user.get("displayName", user.get("username", "Trainer")))
	var text: String = str(message.get("text", "")).strip_edges()
	var pokemon_attachments: Array[Dictionary] = _get_chat_pokemon_attachments(message)
	if text == "" and pokemon_attachments.is_empty():
		return

	var channel: String = str(message.get("channel", CHAT_CHANNEL_GLOBAL)).strip_edges().to_lower()
	_add_user_chat_message(user, display_name, text, channel, pokemon_attachments)


func _on_realtime_mail_received(mail_id: int) -> void:
	if active_mail_box == "inbox":
		await _load_mailbox()
	else:
		await _refresh_mail_attention_from_inbox()


func _add_user_chat_message(user: Dictionary, display_name: String, text: String, channel: String = CHAT_CHANNEL_GLOBAL, pokemon_attachments: Array[Dictionary] = []) -> void:
	var role: Dictionary = _get_primary_visible_chat_role(user)
	var role_color: String = str(role.get("color", "#d8b767"))
	var name_color: String = role_color if not role.is_empty() else CHAT_DEFAULT_NAME_COLOR

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 4)
	var chat_category: String = CHAT_CHANNEL_TRADE if channel == CHAT_CHANNEL_TRADE else CHAT_CHANNEL_GLOBAL
	row.set_meta("chat_category", chat_category)
	row.visible = _should_show_chat_category(chat_category)
	message_list.add_child(row)

	if not role.is_empty():
		var role_name: String = str(role.get("badge", "")).strip_edges()
		if not role_name.is_empty():
			row.add_child(_create_chat_role_badge(role_name, role_color))

	var name_label := Label.new()
	name_label.text = "%s:" % display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = false
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_color_override("font_color", Color(_sanitize_hex_color(name_color, "#dfe4f2")))
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)
	for pokemon_payload: Dictionary in pokemon_attachments:
		row.add_child(_create_chat_pokemon_attachment_button(_pokemon_preview_payload_with_current_trainer(
			pokemon_payload,
			display_name,
			str(user.get("id", user.get("userId", user.get("user_id", ""))))
		)))
	if text != "":
		var entry: RichTextLabel = message_entry_template.duplicate() as RichTextLabel
		row.add_child(entry)
		entry.visible = true
		entry.bbcode_enabled = true
		entry.clear()
		entry.append_text("[color=%s]%s[/color]" % [
			CHAT_MESSAGE_COLOR,
			_escape_bbcode(text),
		])
		entry.fit_content = true
		entry.scroll_active = false
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_chat_to_bottom.call_deferred()

func _get_chat_pokemon_attachments(message: Dictionary) -> Array[Dictionary]:
	var attachments: Array[Dictionary] = []
	var attachments_value: Variant = message.get("pokemonAttachments", [])
	if attachments_value is Array:
		for attachment_value: Variant in attachments_value:
			if attachment_value is Dictionary:
				attachments.append((attachment_value as Dictionary).duplicate(true))
		return attachments

	var legacy_value: Variant = message.get("pokemonAttachment", {})
	if legacy_value is Dictionary:
		attachments.append((legacy_value as Dictionary).duplicate(true))
	return attachments

func _get_chat_pokemon_attachments_with_current_trainer(
	attachments: Array,
	trainer_name: String,
	trainer_user_id: String = ""
) -> Array[Dictionary]:
	var enriched_attachments: Array[Dictionary] = []
	for attachment_value: Variant in attachments:
		if attachment_value is Dictionary:
			enriched_attachments.append(_pokemon_preview_payload_with_current_trainer(
				attachment_value as Dictionary,
				trainer_name,
				trainer_user_id
			))

	return enriched_attachments

func _pokemon_preview_payload_with_current_trainer(
	pokemon_payload: Dictionary,
	trainer_name: String,
	trainer_user_id: String = ""
) -> Dictionary:
	var payload := pokemon_payload.duplicate(true)
	var clean_trainer_name := trainer_name.strip_edges()
	var clean_trainer_user_id := trainer_user_id.strip_edges()
	var origin_value: Variant = payload.get("origin", {})
	var origin: Dictionary = (origin_value as Dictionary).duplicate(true) if origin_value is Dictionary else {}

	if clean_trainer_name != "":
		origin["currentTrainerName"] = clean_trainer_name
		payload["ownerName"] = clean_trainer_name
	if clean_trainer_user_id != "":
		origin["currentTrainerUserId"] = clean_trainer_user_id
		payload["ownerUserId"] = clean_trainer_user_id

	if not origin.is_empty():
		payload["origin"] = origin

	return payload


func _should_show_chat_category(category: String) -> bool:
	if category == CHAT_CATEGORY_SYSTEM:
		return true
	if active_chat_tab == CHAT_TAB_GENERAL:
		return category == CHAT_CHANNEL_GLOBAL or category == CHAT_CATEGORY_USER
	if active_chat_tab == CHAT_TAB_TRADE:
		return category == CHAT_CHANNEL_TRADE
	return false


func _create_chat_role_badge(role_name: String, role_color: String) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(28, 16)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_sanitize_hex_color(role_color, "#d8b767"))
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = role_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", CHAT_BADGE_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 10)
	badge.add_child(label)
	return badge

func _create_chat_pokemon_attachment_button(pokemon_payload: Dictionary) -> Control:
	var button := Button.new()
	var species: String = str(pokemon_payload.get("species", "Pokemon"))
	var shiny: bool = bool(pokemon_payload.get("shiny", false))
	button.custom_minimum_size = Vector2(36, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "View %s summary" % species
	button.pressed.connect(_open_readonly_pokemon_summary.bind(pokemon_payload))
	var transparent_style := _make_button_style(Color("#00000000"), Color("#00000000"), 0, 0)
	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", transparent_style)
	button.add_theme_stylebox_override("pressed", transparent_style)
	button.add_theme_stylebox_override("focus", transparent_style)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = PokemonAssets.load_party_icon(species, shiny)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	return button


func _get_primary_visible_chat_role(user: Dictionary) -> Dictionary:
	var roles_value: Variant = user.get("roles", [])
	if not roles_value is Array:
		return {}

	var roles: Array = roles_value as Array
	var primary_role: Dictionary = {}
	var primary_priority: int = -999999
	for role_value: Variant in roles:
		if not role_value is Dictionary:
			continue

		var role: Dictionary = role_value as Dictionary
		var role_id: String = str(role.get("id", ""))
		var badge: String = _get_chat_role_badge(role_id)
		if badge.is_empty():
			continue

		role["badge"] = badge
		role["color"] = _get_chat_role_color(role_id, str(role.get("color", "#d8b767")))
		var priority: int = int(role.get("priority", 0))
		if primary_role.is_empty() or priority > primary_priority:
			primary_role = role
			primary_priority = priority

	return primary_role


func _get_chat_role_badge(role_id: String) -> String:
	match role_id:
		"gamemaster":
			return "GM"
		"developer":
			return "DEV"
		"moderator":
			return "MOD"
		_:
			return ""


func _get_chat_role_color(role_id: String, fallback: String) -> String:
	match role_id:
		"gamemaster":
			return "#00bfff"
		"developer":
			return "#00e5a8"
		"moderator":
			return "#7b2cbf"
		_:
			return fallback


func _sanitize_hex_color(color: String, fallback: String) -> String:
	var trimmed: String = color.strip_edges()
	if trimmed.length() == 7 and trimmed.begins_with("#"):
		return trimmed
	return fallback


func _escape_bbcode(text: String) -> String:
	var escaped: String = ""
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == "[":
			escaped += "[lb]"
		elif character == "]":
			escaped += "[rb]"
		else:
			escaped += character
	return escaped


func _on_chat_session_invalid(_reason: String) -> void:
	_add_chat_message("Your session is no longer valid. Please sign in again.")
	AuthService.clear_session()
	var tree := get_tree()
	if tree == null:
		return
	var error: Error = tree.change_scene_to_file(LOGIN_SCENE_PATH)
	if error != OK:
		push_warning("Could not return to login screen after session invalidation: %s" % error_string(error))
