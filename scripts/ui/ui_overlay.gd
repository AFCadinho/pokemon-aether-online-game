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
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE_SPRITE_LOADER := preload("res://scripts/battle/battle_ui/sprite_box.gd")
const BATTLE_SUMMARY_SLOT_BG_TEXTURE: Texture2D = preload("res://assets/background/battle/pokemon_x_and_y_battle_background_11_by_phoenixoflight92_d843okx-414w-2x.jpg")
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")
const APPEARANCE_CATEGORIES := [
	{"id": "body", "label": "Body"},
	{"id": "hair", "label": "Hair"},
	{"id": "legs", "label": "Legs"},
	{"id": "feet", "label": "Feet"},
	{"id": "facegear", "label": "Facegear"},
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
const POKEMON_SUMMARY_SIZE := Vector2(620, 360)
const POKEMON_SUMMARY_LEFT_PANEL_WIDTH := 176.0
const POKEMON_SUMMARY_RIGHT_AREA_WIDTH := 336.0
const POKEMON_SUMMARY_CONTENT_PANEL_WIDTH := 336.0
const POKEMON_SUMMARY_TAB_COLUMN_WIDTH := 48.0
const POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE := Vector2i(150, 120)
const POKEMON_SUMMARY_SPRITE_MAX_SIZE := Vector2(124, 96)
const POKEMON_SUMMARY_SPRITE_MIN_SCALE := 0.72
const POKEMON_SUMMARY_SPRITE_MAX_SCALE := 2.2
const POKEMON_TYPE_ICON_ROOT := "res://assets/sprites/types/small/"
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
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
const PLAYER_STATUS_CARD_BORDER := UI_BORDER

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
var clear_party_confirm_dialog: ConfirmationDialog
var clear_inventory_confirm_dialog: ConfirmationDialog
var dev_clear_menu_popup: PanelContainer
var pvp_room_popup: PanelContainer
var pvp_room_code_label: Label
var pvp_room_status_label: Label
var pvp_room_code_input: LineEdit
var pvp_create_room_button: Button
var pvp_join_room_button: Button
var pvp_copy_code_button: Button
var pvp_poll_timer: Timer
var pvp_poll_request: HTTPRequest
var pvp_active_room_code := ""
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
var pokemon_summary_right_area: HBoxContainer
var pokemon_summary_content_panel: PanelContainer
var pokemon_summary_tab_column: VBoxContainer
var pokemon_summary_sprite: TextureRect
var pokemon_summary_sprite_viewport: SubViewport
var pokemon_summary_animated_sprite: AnimatedSprite2D
var pokemon_summary_sprite_loader: Node = BATTLE_SPRITE_LOADER.new()
var pokemon_summary_type_icon_row: HBoxContainer
var pokemon_summary_title_label: Label
var pokemon_summary_id_label: Label
var pokemon_summary_meta_label: Label
var pokemon_summary_held_item_slot: PanelContainer
var pokemon_summary_held_item_slot_button: Button
var pokemon_summary_held_item_slot_icon: TextureRect
var pokemon_summary_held_item_slot_name_label: Label
var pokemon_summary_hp_bar: ProgressBar
var pokemon_summary_hp_label: Label
var pokemon_summary_content_stack: VBoxContainer
var pokemon_summary_tab_buttons: Dictionary = {}
var pokemon_summary_shiny_badge: PanelContainer
var pokemon_summary_shiny_badge_label: Label
var pokemon_summary_active_tab := "general"
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
var dev_add_button: Button
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
var item_dex_sources_label: Label
var item_dex_search_request_id := 0
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
	_setup_pokemon_summary_ev_allocate_popup()
	_build_party_slots()
	_setup_collapsible_panels()
	_setup_chat_resize_button()
	_setup_normal_ui_focus_groups()
	_setup_chat_pokemon_attachment_preview()
	_setup_clear_party_confirm_dialog()
	_setup_clear_inventory_confirm_dialog()
	_setup_dev_clear_menu_popup()
	_setup_pvp_room_popup()
	_setup_dev_add_item_tools()
	_setup_staff_impersonation_tools()
	_setup_item_dex_button()
	_setup_item_dex_popup()
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
	_load_follower_preference.call_deferred()
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
	PlayerSave.is_staff = can_use_staff_tools
	dev_actions_slot.visible = can_use_staff_tools
	dev_actions_button.visible = can_use_staff_tools
	dev_actions_button.disabled = not can_use_staff_tools
	if staff_tools_slot != null:
		staff_tools_slot.visible = can_use_staff_tools
	if staff_tools_button != null:
		staff_tools_button.visible = can_use_staff_tools
		staff_tools_button.disabled = not can_use_staff_tools
	dev_add_pokemon_button.visible = can_use_dev_tools
	dev_add_pokemon_button.disabled = not can_use_dev_tools
	dev_add_team_button.disabled = true
	dev_spawn_pokemon_button.visible = can_use_dev_tools
	dev_spawn_pokemon_button.disabled = not can_use_dev_tools
	if dev_add_button != null:
		dev_add_button.visible = can_use_dev_tools
		dev_add_button.disabled = not can_use_dev_tools
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
	if not can_use_staff_tools:
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
	_set_collapsible_panel_available("staff_actions", can_use_staff_tools or can_use_dev_tools)

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

func _setup_clear_party_confirm_dialog() -> void:
	clear_party_confirm_dialog = ConfirmationDialog.new()
	clear_party_confirm_dialog.title = "Clear Party"
	clear_party_confirm_dialog.dialog_text = "This will remove every Pokemon from your party. This cannot be undone."
	clear_party_confirm_dialog.exclusive = true
	clear_party_confirm_dialog.ok_button_text = "Clear Party"
	clear_party_confirm_dialog.cancel_button_text = "Cancel"
	clear_party_confirm_dialog.confirmed.connect(_on_clear_party_confirmed)
	add_child(clear_party_confirm_dialog)

func _setup_clear_inventory_confirm_dialog() -> void:
	clear_inventory_confirm_dialog = ConfirmationDialog.new()
	clear_inventory_confirm_dialog.title = "Clear Inventory"
	clear_inventory_confirm_dialog.dialog_text = "This will remove every item from your inventory. This cannot be undone."
	clear_inventory_confirm_dialog.exclusive = true
	clear_inventory_confirm_dialog.ok_button_text = "Clear Inventory"
	clear_inventory_confirm_dialog.cancel_button_text = "Cancel"
	clear_inventory_confirm_dialog.confirmed.connect(_on_clear_inventory_confirmed)
	add_child(clear_inventory_confirm_dialog)

func _setup_dev_clear_menu_popup() -> void:
	dev_clear_menu_popup = PanelContainer.new()
	dev_clear_menu_popup.name = "DevClearMenuPopup"
	dev_clear_menu_popup.visible = false
	dev_clear_menu_popup.custom_minimum_size = Vector2(220, 126)
	dev_clear_menu_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_clear_menu_popup.z_index = UI_BASE_Z_INDEX
	dev_clear_menu_popup.anchor_left = 0.0
	dev_clear_menu_popup.anchor_top = 0.0
	dev_clear_menu_popup.anchor_right = 0.0
	dev_clear_menu_popup.anchor_bottom = 0.0
	dev_clear_menu_popup.offset_left = 0.0
	dev_clear_menu_popup.offset_top = 0.0
	dev_clear_menu_popup.offset_right = 220.0
	dev_clear_menu_popup.offset_bottom = 126.0
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

	_apply_button_style(party_button, "danger")
	_apply_button_style(inventory_button, "danger")

func _setup_pvp_room_popup() -> void:
	pvp_room_popup = PanelContainer.new()
	pvp_room_popup.name = "PvpRoomPopup"
	pvp_room_popup.visible = false
	pvp_room_popup.custom_minimum_size = Vector2(360, 220)
	pvp_room_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	pvp_room_popup.z_index = UI_BASE_Z_INDEX
	pvp_room_popup.anchor_left = 0.5
	pvp_room_popup.anchor_top = 0.5
	pvp_room_popup.anchor_right = 0.5
	pvp_room_popup.anchor_bottom = 0.5
	pvp_room_popup.offset_left = -180
	pvp_room_popup.offset_top = -110
	pvp_room_popup.offset_right = 180
	pvp_room_popup.offset_bottom = 110
	pvp_room_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(pvp_room_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 14)
	pvp_room_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var title := Label.new()
	title.text = "PvP Battles"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#f5df9a"))
	layout.add_child(title)

	var description := Label.new()
	description.text = "Create a room code or join one from another player."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(description)

	pvp_room_code_label = Label.new()
	pvp_room_code_label.text = "Room Code: -"
	pvp_room_code_label.add_theme_font_size_override("font_size", 18)
	pvp_room_code_label.add_theme_color_override("font_color", Color("#f5df9a"))
	layout.add_child(pvp_room_code_label)

	pvp_room_status_label = Label.new()
	pvp_room_status_label.text = "Ready."
	pvp_room_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvp_room_status_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	layout.add_child(pvp_room_status_label)

	pvp_room_code_input = LineEdit.new()
	pvp_room_code_input.placeholder_text = "Room code"
	pvp_room_code_input.max_length = 12
	pvp_room_code_input.custom_minimum_size = Vector2(0, 34)
	layout.add_child(pvp_room_code_input)
	_apply_line_edit_style(pvp_room_code_input)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)

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

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 32)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_pvp_room_popup)
	layout.add_child(close_button)

	_apply_button_style(pvp_create_room_button, "primary")
	_apply_button_style(pvp_join_room_button)
	_apply_button_style(pvp_copy_code_button)
	_apply_button_style(close_button)

	pvp_poll_timer = Timer.new()
	pvp_poll_timer.wait_time = 2.0
	pvp_poll_timer.one_shot = false
	pvp_poll_timer.timeout.connect(_on_pvp_poll_timeout)
	add_child(pvp_poll_timer)

	pvp_poll_request = HTTPRequest.new()
	pvp_poll_request.request_completed.connect(_on_pvp_room_poll_completed)
	add_child(pvp_poll_request)

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
	staff_tools_popup.custom_minimum_size = Vector2(230, 160)
	staff_tools_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	staff_tools_popup.z_index = UI_BASE_Z_INDEX
	staff_tools_popup.anchor_left = 0.5
	staff_tools_popup.anchor_top = 0.5
	staff_tools_popup.anchor_right = 0.5
	staff_tools_popup.anchor_bottom = 0.5
	staff_tools_popup.offset_left = -115
	staff_tools_popup.offset_top = -80
	staff_tools_popup.offset_right = 115
	staff_tools_popup.offset_bottom = 80
	staff_tools_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(staff_tools_popup)

	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_left", 12)
	tools_margin.add_theme_constant_override("margin_top", 12)
	tools_margin.add_theme_constant_override("margin_right", 12)
	tools_margin.add_theme_constant_override("margin_bottom", 12)
	staff_tools_popup.add_child(tools_margin)

	var tools_layout := VBoxContainer.new()
	tools_layout.add_theme_constant_override("separation", 8)
	tools_margin.add_child(tools_layout)

	staff_impersonate_button = Button.new()
	staff_impersonate_button.text = "Impersonate"
	staff_impersonate_button.custom_minimum_size = Vector2(190, 34)
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

	_apply_button_style(staff_impersonate_button)
	_apply_button_style(staff_tools_close_button)
	_apply_button_style(close_button)
	_apply_line_edit_style(staff_impersonate_token_input)
	_apply_button_style(staff_impersonate_confirm_button, "primary")

func _setup_item_dex_button() -> void:
	if item_dex_button != null:
		item_dex_button.focus_mode = Control.FOCUS_NONE

func _setup_item_dex_popup() -> void:
	item_dex_popup = PanelContainer.new()
	item_dex_popup.name = "ItemDexPopup"
	item_dex_popup.visible = false
	item_dex_popup.custom_minimum_size = Vector2(560, 430)
	item_dex_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_dex_popup.z_index = UI_BASE_Z_INDEX
	item_dex_popup.anchor_left = 0.5
	item_dex_popup.anchor_top = 0.5
	item_dex_popup.anchor_right = 0.5
	item_dex_popup.anchor_bottom = 0.5
	item_dex_popup.offset_left = -280
	item_dex_popup.offset_top = -215
	item_dex_popup.offset_right = 280
	item_dex_popup.offset_bottom = 215
	item_dex_popup.add_theme_stylebox_override("panel", _make_gold_panel_style(10, 1))
	root_control.add_child(item_dex_popup)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	item_dex_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title_label := Label.new()
	title_label.text = "Item Dex"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_item_dex_popup)
	header.add_child(close_button)

	item_dex_search_input = LineEdit.new()
	item_dex_search_input.placeholder_text = "Search item..."
	item_dex_search_input.text_changed.connect(_on_item_dex_search_changed)
	layout.add_child(item_dex_search_input)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 12)
	layout.add_child(content_row)

	var results_scroll := ScrollContainer.new()
	results_scroll.custom_minimum_size = Vector2(240, 0)
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_row.add_child(results_scroll)

	item_dex_results_list = VBoxContainer.new()
	item_dex_results_list.add_theme_constant_override("separation", 6)
	item_dex_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(item_dex_results_list)

	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(250, 0)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#071827f2"), UI_BORDER_SOFT, 8, 1))
	content_row.add_child(summary_panel)

	var summary_margin := MarginContainer.new()
	summary_margin.add_theme_constant_override("margin_left", 14)
	summary_margin.add_theme_constant_override("margin_top", 14)
	summary_margin.add_theme_constant_override("margin_right", 14)
	summary_margin.add_theme_constant_override("margin_bottom", 14)
	summary_panel.add_child(summary_margin)

	var summary_layout := VBoxContainer.new()
	summary_layout.add_theme_constant_override("separation", 10)
	summary_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_margin.add_child(summary_layout)

	item_dex_icon = TextureRect.new()
	item_dex_icon.custom_minimum_size = Vector2(72, 72)
	item_dex_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_dex_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	summary_layout.add_child(item_dex_icon)

	item_dex_name_label = Label.new()
	item_dex_name_label.text = "Select an item"
	item_dex_name_label.add_theme_font_size_override("font_size", 16)
	item_dex_name_label.add_theme_color_override("font_color", UI_TEXT)
	summary_layout.add_child(item_dex_name_label)

	item_dex_meta_label = Label.new()
	item_dex_meta_label.text = "Category: -\nBase price: Unknown"
	item_dex_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_meta_label.add_theme_font_size_override("font_size", 12)
	item_dex_meta_label.add_theme_color_override("font_color", UI_MONEY)
	summary_layout.add_child(item_dex_meta_label)

	item_dex_description_label = Label.new()
	item_dex_description_label.text = "Search and select an item to view its summary."
	item_dex_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_dex_description_label.add_theme_font_size_override("font_size", 13)
	item_dex_description_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
	summary_layout.add_child(item_dex_description_label)

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

	if hotkey_sidebar_dragging:
		_handle_hotkey_sidebar_drag_input(event)
		return

	if chat_input.has_focus() and _is_settings_toggle_event(event):
		chat_input.release_focus()
		get_viewport().set_input_as_handled()
		return

	if _is_settings_toggle_event(event):
		if bag_popup != null and bag_popup.visible:
			bag_popup.visible = false
			get_viewport().set_input_as_handled()
			return

		if trainer_card_popup != null and trainer_card_popup.visible:
			trainer_card_popup.visible = false
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

	_apply_avatar_preview_body(visual_root)
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

func _apply_avatar_preview_body(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(PlayerSave.appearance_body_id, PlayerSave.gender)
			if body_frames != null:
				sprite.sprite_frames = body_frames
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for child_node: Node in node.get_children():
		_apply_avatar_preview_body(child_node)

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

	var content_stack := VBoxContainer.new()
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_theme_constant_override("separation", 8)
	layout.add_child(content_stack)

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
	return tab

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
	if category_id == "body":
		_create_trainer_card_body_appearance_content(content_stack)
	else:
		_create_trainer_card_empty_appearance_content(content_stack, category_id)

func _create_trainer_card_body_appearance_content(content_stack: VBoxContainer) -> void:
	var body_label := Label.new()
	body_label.text = "Body"
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", UI_TEXT)
	content_stack.add_child(body_label)

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
		body_button.text = _format_body_appearance_name(body_id)
		body_button.focus_mode = Control.FOCUS_NONE
		body_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_button.pressed.connect(_on_trainer_card_body_selected.bind(body_id))
		grid.add_child(body_button)
		trainer_card_body_buttons[body_id] = body_button

	_refresh_trainer_card_body_buttons()

func _create_trainer_card_empty_appearance_content(content_stack: VBoxContainer, category_id: String) -> void:
	var title := Label.new()
	title.text = _format_body_appearance_name(category_id)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UI_TEXT)
	content_stack.add_child(title)

	var empty_state := Label.new()
	empty_state.text = "Coming soon"
	empty_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_state.add_theme_font_size_override("font_size", 14)
	empty_state.add_theme_color_override("font_color", UI_MUTED_TEXT)
	content_stack.add_child(empty_state)

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

func _format_body_appearance_name(body_id: String) -> String:
	var text := body_id.replace("/", " ").replace("_", " ").replace("-", " ").strip_edges()
	if text == "":
		return body_id
	return text.capitalize()

func _refresh_trainer_card_body_buttons() -> void:
	for body_id_value: Variant in trainer_card_body_buttons.keys():
		var body_id: String = str(body_id_value)
		var button: Button = trainer_card_body_buttons.get(body_id) as Button
		if button == null:
			continue

		var display_name: String = _format_body_appearance_name(body_id)
		var is_selected: bool = body_id == String(PlayerSave.appearance_body_id)
		if is_selected:
			button.text = "%s  *" % display_name
			_apply_button_style(button, "primary")
		else:
			button.text = display_name
			_apply_button_style(button)

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
	var border_color := Color("#f1c95f") if hovered else PLAYER_STATUS_CARD_BORDER
	var style := _make_panel_style(background_color, border_color, 14, 1)
	if hovered:
		style.shadow_color = Color(UI_MONEY.r, UI_MONEY.g, UI_MONEY.b, 0.30)
		style.shadow_size = 12
		style.shadow_offset = Vector2.ZERO
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
	_save_current_world_state_after_appearance_change()

func _save_current_world_state_after_appearance_change() -> void:
	var world := GameState.get_world()
	if world != null and world.has_method("save_current_player_state"):
		world.call("save_current_player_state")
	trainer_card_popup.visible = true
	_activate_ui_panel(trainer_card_popup)

func _hide_trainer_card() -> void:
	if trainer_card_popup != null:
		trainer_card_popup.visible = false

func _on_trainer_card_body_selected(body_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("set_body_appearance"):
		player.call("set_body_appearance", body_id)
	else:
		PlayerSave.appearance_body_id = body_id

	_refresh_trainer_card_body_buttons()
	_refresh_avatar_previews()

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
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	pokemon_summary_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin_container.add_child(layout)

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

	pokemon_summary_shiny_badge = PanelContainer.new()
	pokemon_summary_shiny_badge.visible = false
	pokemon_summary_shiny_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#ffcd6d")
	badge_style.border_color = Color("#ffe5a8")
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.shadow_size = 6
	badge_style.shadow_color = Color("#00111f66")
	pokemon_summary_shiny_badge.add_theme_stylebox_override("panel", badge_style)
	pokemon_summary_shiny_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pokemon_summary_shiny_badge.visible = false
	var badge_padding := MarginContainer.new()
	badge_padding.add_theme_constant_override("margin_left", 6)
	badge_padding.add_theme_constant_override("margin_top", 2)
	badge_padding.add_theme_constant_override("margin_right", 6)
	badge_padding.add_theme_constant_override("margin_bottom", 2)
	badge_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_shiny_badge.add_child(badge_padding)
	pokemon_summary_shiny_badge_label = Label.new()
	pokemon_summary_shiny_badge_label.text = "SHINY"
	pokemon_summary_shiny_badge_label.add_theme_font_size_override("font_size", 9)
	pokemon_summary_shiny_badge_label.add_theme_color_override("font_color", Color("#0d1f38"))
	pokemon_summary_shiny_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_summary_shiny_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pokemon_summary_shiny_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_label_clip_width(pokemon_summary_shiny_badge_label)
	badge_padding.add_child(pokemon_summary_shiny_badge_label)
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

	var divider_line := ColorRect.new()
	divider_line.custom_minimum_size = Vector2(0, 1)
	divider_line.color = Color("#b99045")
	layout.add_child(divider_line)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_SHRINK_END
	spacer.custom_minimum_size = Vector2.ZERO
	layout.add_child(spacer)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 8)
	layout.add_child(content_row)

	var left_panel := PanelContainer.new()
	pokemon_summary_left_panel = left_panel
	left_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, 0)
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_panel.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#07111ff6"), Color("#d8b767")))
	content_row.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 8)
	left_margin.add_theme_constant_override("margin_top", 8)
	left_margin.add_theme_constant_override("margin_right", 8)
	left_margin.add_theme_constant_override("margin_bottom", 8)
	left_panel.add_child(left_margin)

	var left_stack := VBoxContainer.new()
	left_stack.add_theme_constant_override("separation", 6)
	left_margin.add_child(left_stack)

	var sprite_frame := Control.new()
	sprite_frame.custom_minimum_size = Vector2(
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.x),
		float(POKEMON_SUMMARY_SPRITE_VIEWPORT_SIZE.y)
	)
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

	pokemon_summary_type_icon_row = HBoxContainer.new()
	pokemon_summary_type_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_summary_type_icon_row.add_theme_constant_override("separation", 4)
	pokemon_summary_type_icon_row.anchor_left = 1.0
	pokemon_summary_type_icon_row.anchor_top = 0.0
	pokemon_summary_type_icon_row.anchor_right = 1.0
	pokemon_summary_type_icon_row.anchor_bottom = 0.0
	pokemon_summary_type_icon_row.offset_left = -56.0
	pokemon_summary_type_icon_row.offset_top = 6.0
	pokemon_summary_type_icon_row.offset_right = -6.0
	pokemon_summary_type_icon_row.offset_bottom = 30.0
	sprite_frame.add_child(pokemon_summary_type_icon_row)

	pokemon_summary_hp_label = Label.new()
	pokemon_summary_hp_label.text = "HP -"
	pokemon_summary_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pokemon_summary_hp_label.add_theme_font_size_override("font_size", 10)
	pokemon_summary_hp_label.add_theme_color_override("font_color", Color("#f5df9a"))
	left_stack.add_child(pokemon_summary_hp_label)

	pokemon_summary_hp_bar = ProgressBar.new()
	pokemon_summary_hp_bar.custom_minimum_size = Vector2(0, 8)
	pokemon_summary_hp_bar.show_percentage = false
	pokemon_summary_hp_bar.add_theme_stylebox_override("background", _make_panel_style(Color("#0e1726e8"), Color("#263b58"), 8, 0))
	pokemon_summary_hp_bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#b7f37b"), Color("#b7f37b"), 8, 0))
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
	pokemon_summary_held_item_slot_name_label.add_theme_font_size_override("font_size", 11)
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
	pokemon_summary_held_item_slot_button.add_theme_stylebox_override("hover", _make_pokemon_summary_held_item_button_style(Color("#f4d78a14"), Color("#f4d78a88")))
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

	pokemon_summary_item_list = VBoxContainer.new()
	pokemon_summary_item_list.add_theme_constant_override("separation", 3)
	picker_margin.add_child(pokemon_summary_item_list)

	var right_area := HBoxContainer.new()
	pokemon_summary_right_area = right_area
	right_area.custom_minimum_size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, 0)
	right_area.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_area.add_theme_constant_override("separation", 6)
	content_row.add_child(right_area)

	var summary_content_panel := PanelContainer.new()
	pokemon_summary_content_panel = summary_content_panel
	summary_content_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, 0)
	summary_content_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_content_panel.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#0a1323f4"), Color("#d8b767")))
	right_area.add_child(summary_content_panel)

	var summary_content_margin := MarginContainer.new()
	summary_content_margin.add_theme_constant_override("margin_left", 8)
	summary_content_margin.add_theme_constant_override("margin_top", 8)
	summary_content_margin.add_theme_constant_override("margin_right", 8)
	summary_content_margin.add_theme_constant_override("margin_bottom", 8)
	summary_content_panel.add_child(summary_content_margin)

	var summary_content_scroll := ScrollContainer.new()
	summary_content_scroll.custom_minimum_size = Vector2(0, 0)
	summary_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_content_margin.add_child(summary_content_scroll)

	pokemon_summary_content_stack = VBoxContainer.new()
	pokemon_summary_content_stack.custom_minimum_size = Vector2(0, 0)
	pokemon_summary_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_summary_content_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pokemon_summary_content_stack.add_theme_constant_override("separation", 5)
	summary_content_scroll.add_child(pokemon_summary_content_stack)

	var tab_frame := PanelContainer.new()
	tab_frame.add_theme_stylebox_override("panel", _make_pokemon_summary_inner_style(Color("#050912f8"), Color("#d8b767")))
	tab_frame.custom_minimum_size = Vector2(POKEMON_SUMMARY_TAB_COLUMN_WIDTH, 0)
	tab_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(tab_frame)

	var tab_margin := MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 4)
	tab_margin.add_theme_constant_override("margin_top", 6)
	tab_margin.add_theme_constant_override("margin_right", 4)
	tab_margin.add_theme_constant_override("margin_bottom", 6)
	tab_frame.add_child(tab_margin)

	var tab_column := VBoxContainer.new()
	pokemon_summary_tab_column = tab_column
	tab_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_column.add_theme_constant_override("separation", 4)
	tab_margin.add_child(tab_column)

	var general_tab := _create_pokemon_summary_tab_button("general", "Info", Color("#d8b767"), card_key)
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
	button.custom_minimum_size = Vector2(POKEMON_SUMMARY_TAB_COLUMN_WIDTH, 32)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
			return Color("#d8b767")

func _apply_summary_tab_style(button: Button, selected: bool, accent_color: Color) -> void:
	var bg: Color = Color("#07111fe8") if not selected else Color("#183157f6")
	var border: Color = Color("#233a58aa") if not selected else accent_color
	button.add_theme_color_override("font_color", Color("#f8e6b0") if selected else UI_MUTED_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_shadow_color", Color("#00111f"))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)
	button.text = button.text.to_upper()
	button.add_theme_stylebox_override("normal", _make_pokemon_summary_tab_button_style(bg, border, selected, accent_color))
	button.add_theme_stylebox_override("hover", _make_pokemon_summary_tab_button_style(Color("#182b4cee"), accent_color, false, accent_color))
	button.add_theme_stylebox_override("pressed", _make_pokemon_summary_tab_button_style(Color("#08101cf2"), accent_color, true, accent_color))
	button.add_theme_stylebox_override("focus", _make_pokemon_summary_tab_button_style(bg, accent_color, selected, accent_color))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _make_pokemon_summary_tab_button_style(
	background_color: Color,
	border_color: Color,
	selected: bool,
	accent_color: Color
) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 9, 1)
	style.content_margin_left = 5
	style.content_margin_top = 4
	style.content_margin_right = 5
	style.content_margin_bottom = 4
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.16 if selected else 0.0)
	style.shadow_size = 2 if selected else 0
	style.shadow_offset = Vector2.ZERO
	style.border_width_left = 3 if selected else 1
	style.border_width_top = 1
	if selected:
		style.border_width_right = 2
	else:
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

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 5)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_right", 5)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	slot.add_child(margin_container)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin_container.add_child(stack)

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(64, 44)
	stack.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_item_icon(str(item.get("id", "")))
	icon_wrap.add_child(icon)

	var quantity_label := Label.new()
	quantity_label.text = "x%s" % max(int(item.get("quantity", 1)), 1)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 11)
	quantity_label.add_theme_color_override("font_color", UI_MONEY)
	stack.add_child(quantity_label)

	var name_label := Label.new()
	name_label.text = _ellipsize_text(str(item.get("name", "Item")), 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(name_label)
	return slot

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
		"item_list": pokemon_summary_item_list,
		"preview_pokemon": pokemon if mode == "readonly" else null,
		"mode": mode,
		"selected_slot": slot_index,
		"active_tab": "general",
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
	pokemon_summary_right_area = context.get("right_area") as HBoxContainer
	pokemon_summary_content_panel = context.get("content_panel") as PanelContainer
	pokemon_summary_tab_column = context.get("tab_column") as VBoxContainer
	pokemon_summary_sprite = context.get("sprite") as TextureRect
	pokemon_summary_sprite_viewport = context.get("sprite_viewport") as SubViewport
	pokemon_summary_animated_sprite = context.get("animated_sprite") as AnimatedSprite2D
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
	pokemon_summary_item_list = context.get("item_list") as VBoxContainer
	pokemon_summary_preview_pokemon = context.get("preview_pokemon") as Pokemon
	pokemon_summary_mode = str(context.get("mode", "interactive"))
	pokemon_summary_selected_slot = int(context.get("selected_slot", -1))
	pokemon_summary_active_tab = str(context.get("active_tab", "general"))
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
	pokemon_summary_item_picker.visible = false
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
		pokemon_summary_shiny_badge_label.text = "SHINY"
	pokemon_summary_trainer_label.text = "Original Trainer: %s" % PlayerSave.player_name
	pokemon_summary_meta_label.text = "Lv %s" % str(max(pokemon.level, 1))
	pokemon_summary_trainer_label.tooltip_text = pokemon_summary_trainer_label.text
	pokemon_summary_meta_label.tooltip_text = pokemon_summary_meta_label.text
	_set_pokemon_summary_sprite(pokemon)
	_refresh_pokemon_summary_type_icons(pokemon)

	_set_pokemon_summary_held_item_slot(pokemon)
	if _is_pokemon_summary_readonly():
		_hide_pokemon_summary_ev_allocate_popup()
		pokemon_summary_item_picker.visible = false
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

func _make_label_clip_width(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2.ZERO

func _set_pokemon_summary_sprite(pokemon: Pokemon) -> void:
	if pokemon_summary_animated_sprite == null:
		return

	var loaded_frames: Variant = pokemon_summary_sprite_loader.call(
		"_load_sprite_frames",
		pokemon.species,
		"front",
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

func _refresh_pokemon_summary_type_icons(pokemon: Pokemon) -> void:
	if pokemon_summary_type_icon_row == null:
		return

	for child: Node in pokemon_summary_type_icon_row.get_children():
		child.queue_free()

	var added_count: int = 0
	for type_value: String in _string_array_from_value(pokemon.types):
		var type_icon: Texture2D = _load_pokemon_type_icon(type_value)
		if type_icon == null:
			continue

		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = type_icon
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
	return Vector2(scale_value, scale_value)

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
	_add_summary_section_title("General Info", Color("#f2cf78"))
	pokemon_summary_content_stack.add_child(_create_summary_info_row("Ability", _default_text(pokemon.ability), Color("#ffb15f")))
	pokemon_summary_content_stack.add_child(_create_summary_info_row("Nature", _default_text(pokemon.nature), Color("#f2cf78")))
	pokemon_summary_content_stack.add_child(_create_summary_info_row("Location", _get_pokemon_origin_summary_text(pokemon), Color("#62d7ff")))
	_render_stat_bar_list(pokemon.stats, 260, true)

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
	_add_summary_section_title("Allocated EVs", Color("#ffcc7a"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	pokemon_summary_content_stack.add_child(grid)
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		var value: int = int(pokemon.evs.get(stat_id, 0))
		grid.add_child(_create_summary_ev_box(stat_id, str(stat.get("label", stat_id)), value, stat.get("color", UI_BORDER_FOCUS) as Color))
	_add_summary_section_title("Stored EVs", Color("#ffcc7a"))
	pokemon_summary_content_stack.add_child(_create_summary_stored_evs_panel(pokemon.evs, pokemon.stored_evs))

func _render_pokemon_summary_moves_tab(pokemon: Pokemon) -> void:
	_add_summary_section_title("Moves", Color("#f2cf78"))
	for move_index in range(4):
		var move_name: String = "-"
		var pp_text: String = "--/--"
		var move_type: String = ""
		if move_index < pokemon.moves.size():
			var move_value: Variant = pokemon.moves[move_index]
			move_name = _get_summary_move_name(move_value)
			pp_text = _get_summary_move_pp_text(move_value)
			move_type = _get_summary_move_type(move_value)
		pokemon_summary_content_stack.add_child(_create_summary_move_card(move_index + 1, move_name, pp_text, move_type))

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
	label.add_theme_font_size_override("font_size", 10)
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
	panel.custom_minimum_size = Vector2(96, 66)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color("#d8b76788"), 8, 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	panel.add_child(stack)
	var value_label := Label.new()
	value_label.text = str(clamp(value, 0, max_value))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 17)
	value_label.add_theme_color_override("font_color", color)
	stack.add_child(value_label)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", color)
	stack.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = max(max_value, 1)
	bar.value = clamp(value, 0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(58, 6)
	bar.add_theme_stylebox_override("background", _make_panel_style(Color("#111927d8"), Color("#1b2a3d"), 8, 0))
	bar.add_theme_stylebox_override("fill", _make_panel_style(color, color, 8, 0))
	stack.add_child(bar)
	return panel

func _create_summary_ev_box(stat_id: String, label_text: String, value: int, color: Color) -> Control:
	var panel: Control = PanelContainer.new() if _is_pokemon_summary_readonly() else Button.new()
	panel.custom_minimum_size = Vector2(96, 44)
	if panel is Button:
		var button: Button = panel as Button
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Allocate %s EVs" % label_text
		button.pressed.connect(_on_summary_allocated_ev_pressed.bind(stat_id, label_text, pokemon_summary_active_card_key))
		button.add_theme_stylebox_override("normal", _make_panel_style(Color("#081321ef"), Color("#d8b76766"), 8, 1))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color("#10243cf2"), color, 8, 1))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#050912f4"), color, 8, 1))
	else:
		(panel as PanelContainer).add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color("#d8b76766"), 8, 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)
	var value_label := Label.new()
	value_label.text = str(value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(value_label)
	return panel

func _create_summary_stored_evs_panel(allocated_evs: Dictionary, stored_evs: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color("#d8b76766"), 8, 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var allocated_total: int = 0
	var stored_total: int = 0
	for stat_value: Variant in _summary_stat_order():
		var stat: Dictionary = stat_value
		var stat_id: String = str(stat.get("id", ""))
		allocated_total += int(allocated_evs.get(stat_id, 0))
		stored_total += int(stored_evs.get(stat_id, 0))

	var total_label := Label.new()
	total_label.text = "AVAILABLE: %s    CAPACITY: %s / 756" % [stored_total, allocated_total + stored_total]
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_size_override("font_size", 9)
	total_label.add_theme_color_override("font_color", Color("#f5df9a"))
	stack.add_child(total_label)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 2)
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
	panel.custom_minimum_size = Vector2(40, 26)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#050912e8"), Color(color.r, color.g, color.b, 0.55), 6, 1))

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", color)
	stack.add_child(label)

	var value_label := Label.new()
	value_label.text = str(value)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", UI_TEXT)
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

	pokemon_summary_ev_allocate_status_label.text = "EV allocation mutation is not implemented yet."
	pokemon_summary_ev_allocate_status_label.add_theme_color_override("font_color", Color("#ffcc7a"))

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
		total += int(evs.get(str(stat.get("id", "")), 0))
	return total

func _create_summary_move_card(move_number: int, move_name: String, pp_text: String, move_type: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 44)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#081321ef"), Color("#d8b76777"), 8, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var number_label := Label.new()
	number_label.text = str(move_number)
	number_label.custom_minimum_size = Vector2(24, 24)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override("font_color", Color("#101827"))
	number_label.add_theme_stylebox_override("normal", _make_panel_style(Color("#f2cf78"), Color("#fff1bf"), 12, 1))
	row.add_child(number_label)
	var move_label := Label.new()
	move_label.text = move_name
	move_label.tooltip_text = move_name
	move_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_label_clip_width(move_label)
	move_label.add_theme_font_size_override("font_size", 12)
	move_label.add_theme_color_override("font_color", Color("#f5df9a"))
	row.add_child(move_label)
	var type_icon_texture: Texture2D = _load_pokemon_type_icon(move_type)
	if type_icon_texture != null:
		var type_icon := TextureRect.new()
		type_icon.custom_minimum_size = Vector2(22, 22)
		type_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		type_icon.texture = type_icon_texture
		type_icon.tooltip_text = move_type.capitalize()
		type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(type_icon)
	var pp_label := Label.new()
	pp_label.text = pp_text
	pp_label.custom_minimum_size = Vector2(42, 0)
	pp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_label.add_theme_font_size_override("font_size", 10)
	pp_label.add_theme_color_override("font_color", Color("#ff5da8"))
	row.add_child(pp_label)
	return panel

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
	_refresh_pokemon_summary_item_picker()
	pokemon_summary_item_picker.visible = not pokemon_summary_item_picker.visible
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

	var added_count: int = 0
	for item_value: Variant in bag_inventory_items:
		var item: Dictionary = item_value
		if not _is_holdable_bag_item(item):
			continue
		pokemon_summary_item_list.add_child(_create_summary_item_choice(item))
		added_count += 1
		if added_count >= 6:
			break

	if added_count <= 0:
		var empty_label := Label.new()
		empty_label.text = "No held items in your bag."
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", UI_MUTED_TEXT)
		pokemon_summary_item_list.add_child(empty_label)

func _create_summary_item_choice(item: Dictionary) -> Control:
	var button := Button.new()
	var item_id: String = str(item.get("id", ""))
	button.text = "%s  x%s" % [_ellipsize_text(str(item.get("name", item_id)), 18), max(int(item.get("quantity", 1)), 1)]
	button.tooltip_text = item_id
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
	return category in ["held_items", "power_stones"] or item_id.ends_with("berry") or item_id.ends_with("--held")

func _format_move_name(move_id: String) -> String:
	return _item_name_from_id(move_id)

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
		return _lookup_summary_move_type(str(move_value))

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
		var indexed_type: String = _lookup_summary_move_type(move_key)
		if indexed_type != "":
			return indexed_type

	if metadata_value is Dictionary:
		var metadata: Dictionary = metadata_value as Dictionary
		for key in ["id", "move", "moveId", "move_id", "name"]:
			var move_key: String = str(metadata.get(key, "")).strip_edges()
			var indexed_type: String = _lookup_summary_move_type(move_key)
			if indexed_type != "":
				return indexed_type

	return _lookup_summary_move_type(_get_summary_move_name(move_value))

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

	var move_data: Dictionary = move_value as Dictionary
	var current_pp: int = int(_get_first_dictionary_value(
		move_data,
		["pp", "currentPp", "currentPP", "current_pp"],
		0
	))
	var max_pp: int = int(_get_first_dictionary_value(
		move_data,
		["maxpp", "maxPp", "maxPP", "max_pp", "pp"],
		current_pp
	))
	if max_pp <= 0:
		return "--/--"
	return "%s/%s" % [clamp(current_pp, 0, max_pp), max_pp]

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
		pokemon_summary_left_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, 0)
		pokemon_summary_left_panel.size = Vector2(POKEMON_SUMMARY_LEFT_PANEL_WIDTH, pokemon_summary_left_panel.size.y)
	if pokemon_summary_right_area != null:
		pokemon_summary_right_area.custom_minimum_size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, 0)
		pokemon_summary_right_area.size = Vector2(POKEMON_SUMMARY_RIGHT_AREA_WIDTH, pokemon_summary_right_area.size.y)
	if pokemon_summary_content_panel != null:
		pokemon_summary_content_panel.custom_minimum_size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, 0)
		pokemon_summary_content_panel.size = Vector2(POKEMON_SUMMARY_CONTENT_PANEL_WIDTH, pokemon_summary_content_panel.size.y)
	if pokemon_summary_tab_column != null:
		pokemon_summary_tab_column.custom_minimum_size = Vector2(POKEMON_SUMMARY_TAB_COLUMN_WIDTH, 0)
		pokemon_summary_tab_column.size = Vector2(POKEMON_SUMMARY_TAB_COLUMN_WIDTH, pokemon_summary_tab_column.size.y)

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
	var style := _make_panel_style(Color("#050812fb"), Color("#d8b767"), 14, 2)
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_pokemon_summary_inner_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(background_color, border_color, 9, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_header_frame_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#101827f4"), Color("#d8b767"), 10, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _make_pokemon_summary_sprite_stage_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#00000000"), Color("#d8b767aa"), 12, 1)
	style.shadow_color = Color("#00000000")
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_section_title_style(color: Color) -> StyleBoxFlat:
	var style := _make_panel_style(Color("#07111fe8"), Color(color.r, color.g, color.b, 0.58), 6, 1)
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
	var style := _make_panel_style(Color("#0b1322b8"), Color("#d8b76755"), 7, 1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _make_pokemon_summary_button_style(background_color: Color, border_color: Color, selected: bool) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 8, 1)
	if selected:
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	return style

func _make_pokemon_summary_held_item_slot_style() -> StyleBoxFlat:
	var style := _make_panel_style(Color("#07111fcc"), Color("#d8b76766"), 6, 1)
	style.content_margin_left = 7
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style

func _make_pokemon_summary_held_item_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _make_button_style(background_color, border_color, 6, 1)
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
		player_status_panel.add_theme_stylebox_override("panel", _make_gold_panel_style(14, 1))

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

func _toggle_settings_menu() -> void:
	if settings_menu.visible:
		if settings_menu.has_method("close"):
			settings_menu.call("close")
		else:
			settings_menu.visible = false
			_on_settings_menu_closed()
		_deactivate_ui_panel(settings_menu)
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

	var pokemon_attachments: Array[Dictionary] = pending_chat_pokemon_attachments.duplicate(true)
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
			attachments.append(pokemon.to_persistence_dict())

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

func _load_follower_preference() -> void:
	var result: Dictionary = await PlayerGameStateService.load_player_preferences()
	if not bool(result.get("success", false)):
		push_warning("UIOverlay: follower preference load failed: %s" % str(result.get("error", "Unknown error")))
		return

	var preferences_value: Variant = result.get("preferences", {})
	var preferences: Dictionary = preferences_value if preferences_value is Dictionary else {}
	GameState.show_follower = bool(preferences.get("showFollower", true))
	follower_toggle_button.set_pressed_no_signal(GameState.show_follower)
	_set_icon_slot_active(follower_slot, GameState.show_follower)
	_refresh_world_follower_visibility()

func _on_follower_toggle_toggled(toggled_on: bool) -> void:
	GameState.show_follower = toggled_on
	_set_icon_slot_active(follower_slot, GameState.show_follower)
	_refresh_world_follower_visibility()

	var result: Dictionary = await PlayerGameStateService.save_player_preferences({
		"showFollower": GameState.show_follower,
	})
	if not bool(result.get("success", false)):
		_add_chat_message("Could not save follower setting. Please contact staff.")
		push_warning("UIOverlay: follower preference save failed: %s" % str(result.get("error", "Unknown error")))

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

func _on_dev_actions_button_pressed() -> void:
	if not _can_use_staff_tools():
		return

	dev_actions_popup.visible = not dev_actions_popup.visible
	if dev_actions_popup.visible:
		_activate_ui_panel(dev_actions_popup)
	else:
		_deactivate_ui_panel(dev_actions_popup)

func _on_staff_tools_button_pressed() -> void:
	if not _can_use_staff_tools():
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
		_set_icon_slot_active(follower_slot, GameState.show_follower)
		_refresh_world_follower_visibility()

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
	if player_node != null and player_node.has_method("set_body_appearance"):
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
	PlayerSave.appearance_hair_id = ""
	PlayerSave.appearance_legs_id = ""
	PlayerSave.appearance_feet_id = ""
	PlayerSave.appearance_facegear_id = ""
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
	_add_chat_message("Pokedex is not implemented yet.")

func _on_content_creator_tools_button_pressed() -> void:
	_add_chat_message("Content Creator Tools are not implemented yet.")

func _show_item_dex_popup() -> void:
	item_dex_popup.visible = true
	_activate_ui_panel(item_dex_popup)
	item_dex_search_input.grab_focus.call_deferred()
	await _refresh_item_dex_results()

func _hide_item_dex_popup() -> void:
	item_dex_popup.visible = false
	_deactivate_ui_panel(item_dex_popup)

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
		if count >= 8:
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
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = str(item.get("shortDesc", item.get("desc", "")))
	button.pressed.connect(_on_item_dex_result_selected.bind(item))
	_apply_button_style(button)

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
	item_dex_sources_label.text = _format_item_dex_sources(item)

func _format_item_dex_meta(item: Dictionary) -> String:
	var category := str(item.get("category", "-"))
	var cost_value: Variant = item.get("cost", null)
	var cost_text := "Unknown"
	if cost_value != null:
		cost_text = "$%s" % _format_money(int(cost_value))
	return "Category: %s\nBase price: %s" % [category, cost_text]

func _format_item_dex_sources(item: Dictionary) -> String:
	var summary_value: Variant = item.get("sourceSummary", [])
	if typeof(summary_value) != TYPE_ARRAY:
		return "Where to get\nNo known repeatable ways yet."

	var summaries: Array = summary_value
	if summaries.is_empty():
		return "Where to get\nNo known repeatable ways yet."

	var lines: Array[String] = ["Where to get"]
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
			"shortDesc": str(item.get("shortDesc", "")),
			"desc": str(item.get("desc", "")),
			"cost": item.get("cost", null),
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
	clear_party_confirm_dialog.popup_centered(Vector2i(460, 150))

func _on_dev_clear_inventory_option_pressed() -> void:
	if not _can_use_dev_tools():
		return

	dev_clear_menu_popup.visible = false
	clear_inventory_confirm_dialog.popup_centered(Vector2i(460, 150))

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
	pokemon_summary_item_picker.visible = false
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

func _hide_pvp_room_popup() -> void:
	if pvp_room_popup == null:
		return
	if pvp_poll_timer != null:
		pvp_poll_timer.stop()
	pvp_polling_active = false
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
		_set_pvp_status("Could not join room: %s" % str(response.get("error", "Unknown error")))
		return

	pvp_active_room_code = str(response.get("roomCode", room_code)).strip_edges()
	pvp_room_code_label.text = "Room Code: %s" % pvp_active_room_code
	pvp_copy_code_button.disabled = pvp_active_room_code == ""
	await _start_pvp_battle_from_response(response)

func _on_pvp_copy_code_pressed() -> void:
	if pvp_active_room_code == "":
		return
	DisplayServer.clipboard_set(pvp_active_room_code)
	_set_pvp_status("Room code copied.")

func _on_pvp_poll_timeout() -> void:
	if not pvp_polling_active or pvp_poll_in_flight or pvp_active_room_code == "" or pvp_battle_starting:
		return
	await _poll_pvp_room()

func _start_pvp_room_polling() -> void:
	if pvp_polling_active:
		return
	pvp_polling_active = true
	pvp_poll_elapsed = 0.0

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
	pvp_polling_active = false
	pvp_poll_elapsed = 0.0
	pvp_room_code_label.text = "Room Code: -"
	pvp_copy_code_button.disabled = true
	pvp_battle_starting = false

func _create_pvp_request_node() -> HTTPRequest:
	var request := HTTPRequest.new()
	add_child(request)
	return request

func _set_pvp_room_busy(is_busy: bool, message: String = "") -> void:
	pvp_create_room_button.disabled = is_busy
	pvp_join_room_button.disabled = is_busy
	if message != "":
		_set_pvp_status(message)

func _set_pvp_status(message: String) -> void:
	if pvp_room_status_label != null:
		pvp_room_status_label.text = message

func _on_map_button_pressed() -> void:
	_add_chat_message("Town Map is not implemented yet.")

func _on_running_shoes_toggled(enabled: bool) -> void:
	GameState.running_shoes_enabled = enabled
	_set_icon_slot_active(running_shoes_slot, enabled)
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_running_shoes_enabled"):
		player_node.call("set_running_shoes_enabled", enabled)

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
		row.add_child(_create_chat_pokemon_attachment_button(pokemon_payload))
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
