extends CanvasLayer

const MAX_PARTY_SIZE := 6
const ADD_POKEMON_COMMAND := "/addpokemon"
const ADD_POKEMON_CLIPBOARD_COMMAND := "/addpokemonclip"
const ADD_POKEMON_CLIPBOARD_ALIAS := "/apc"
const ADD_TEAM_COMMAND := "/addteam"
const ADD_TEAM_ALIAS := "/at"
const ADD_TEAM_CLIPBOARD_COMMAND := "/addteamclip"
const ADD_TEAM_CLIPBOARD_ALIAS := "/atc"
const START_ENCOUNTER_COMMAND := "/encounter"
const START_ENCOUNTER_CLIPBOARD_COMMAND := "/encounterclip"
const START_ENCOUNTER_CLIPBOARD_ALIAS := "/ec"
const SPAWN_COMMAND := "/spawn"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const COLLAPSE_BUTTON_SIZE := Vector2(28, 28)
const COLLAPSE_BUTTON_MARGIN := 10.0
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
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
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
@onready var actions_panel: PanelContainer = $Control/ActionsPanel
@onready var message_scroll: ScrollContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll
@onready var message_list: VBoxContainer = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList
@onready var message_entry_template: RichTextLabel = $Control/ChatPanel/MarginContainer/VBoxContainer/MessageScroll/MarginContainer/MessageList/MessageEntry
@onready var chat_tabs_panel: Control = $Control/ChatTabsPanel
@onready var general_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/GeneralButton
@onready var trade_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/TradeButton
@onready var system_chat_tab_button: Button = $Control/ChatTabsPanel/TabRow/SystemButton
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
@onready var settings_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/SettingsSlot
@onready var settings_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/SettingsSlot/SettingsButton
@onready var settings_menu: PanelContainer = $Control/SettingsMenu
@onready var map_slot: PanelContainer = $Control/OptionsPanel/MarginContainer/HBoxContainer/MapSlot
@onready var map_button: TextureButton = $Control/OptionsPanel/MarginContainer/HBoxContainer/MapSlot/MapButton
@onready var running_shoes_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/RunningShoesSlot
@onready var running_shoes_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/RunningShoesSlot/RunningShoesButton
@onready var repel_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/RepelSlot
@onready var repel_toggle_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/RepelSlot/RepelToggle
@onready var follower_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/FollowerSlot
@onready var follower_toggle_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/FollowerSlot/FollowerToggle
@onready var dev_actions_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot
@onready var dev_actions_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot/DevActionsButton
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
var clear_party_confirm_dialog: ConfirmationDialog
var clear_inventory_confirm_dialog: ConfirmationDialog
var dev_clear_menu_popup: PanelContainer
var chat_submit_in_progress: bool = false
var active_chat_tab: String = CHAT_TAB_GENERAL
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
var dev_add_item_button: Button
var dev_add_item_popup: PanelContainer
var dev_item_search_input: LineEdit
var dev_item_results_list: VBoxContainer
var dev_item_quantity_spinbox: SpinBox
var dev_item_confirm_button: Button
var dev_item_catalog: Array[Dictionary] = []
var dev_selected_item: Dictionary = {}
var dev_item_search_request_id := 0
var item_dex_slot: PanelContainer
var item_dex_button: TextureButton
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("ui_overlay")
	_setup_player_status_card()
	_setup_trainer_card_popup()
	_setup_bag_popup()
	_build_party_slots()
	_setup_collapsible_panels()
	_setup_chat_resize_button()
	_setup_clear_party_confirm_dialog()
	_setup_clear_inventory_confirm_dialog()
	_setup_dev_clear_menu_popup()
	_setup_dev_add_item_tools()
	_setup_item_dex_button()
	_setup_item_dex_popup()
	_apply_premium_overlay_styles()
	_refresh_location_label()
	_refresh_utc_time_label(UTC_TIME_REFRESH_INTERVAL_SECONDS, true)
	_refresh_party()

	if not PlayerSave.party_changed.is_connected(_refresh_party):
		PlayerSave.party_changed.connect(_refresh_party)
	if not ChatRealtimeService.message_received.is_connected(_on_chat_realtime_message_received):
		ChatRealtimeService.message_received.connect(_on_chat_realtime_message_received)
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
	_setup_icon_slot_hover(settings_slot, settings_button)
	_setup_icon_slot_hover(repel_slot, repel_toggle_button)
	_setup_icon_slot_hover(follower_slot, follower_toggle_button)
	_setup_icon_slot_hover(item_dex_slot, item_dex_button)
	_setup_icon_slot_hover(dev_actions_slot, dev_actions_button)
	_disable_icon_button_focus()
	bag_button.pressed.connect(_on_bag_button_pressed)
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
	item_dex_button.pressed.connect(_on_item_dex_button_pressed)
	hotkey_sidebar_panel.gui_input.connect(_on_hotkey_sidebar_gui_input)
	dev_add_pokemon_button.pressed.connect(_on_dev_add_pokemon_button_pressed)
	dev_add_team_button.visible = false
	dev_add_team_button.disabled = true
	dev_spawn_pokemon_button.pressed.connect(_on_dev_spawn_pokemon_button_pressed)
	dev_add_item_button.pressed.connect(_on_dev_add_item_button_pressed)
	dev_clear_party_button.pressed.connect(_on_dev_clear_party_button_pressed)
	dev_actions_close_button.pressed.connect(_on_dev_actions_close_button_pressed)
	dev_actions_slot.visible = PlayerSave.is_staff
	dev_actions_button.visible = PlayerSave.is_staff
	dev_actions_popup.visible = false
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)

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
	dev_clear_menu_popup.z_index = 365
	dev_clear_menu_popup.anchor_left = 0.5
	dev_clear_menu_popup.anchor_top = 0.5
	dev_clear_menu_popup.anchor_right = 0.5
	dev_clear_menu_popup.anchor_bottom = 0.5
	dev_clear_menu_popup.offset_left = -110
	dev_clear_menu_popup.offset_top = -63
	dev_clear_menu_popup.offset_right = 110
	dev_clear_menu_popup.offset_bottom = 63
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

func _setup_dev_add_item_tools() -> void:
	dev_add_item_button = Button.new()
	dev_add_item_button.text = "Add Item"
	dev_add_item_button.custom_minimum_size = Vector2(190, 34)
	dev_add_item_button.focus_mode = Control.FOCUS_NONE
	var dev_actions_container := dev_clear_party_button.get_parent()
	if dev_actions_container != null:
		dev_actions_container.add_child(dev_add_item_button)
		dev_actions_container.move_child(dev_add_item_button, dev_clear_party_button.get_index())

	dev_add_item_popup = PanelContainer.new()
	dev_add_item_popup.name = "DevAddItemPopup"
	dev_add_item_popup.visible = false
	dev_add_item_popup.custom_minimum_size = Vector2(460, 430)
	dev_add_item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	dev_add_item_popup.z_index = 370
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

func _setup_item_dex_button() -> void:
	item_dex_slot = PanelContainer.new()
	item_dex_slot.name = "ItemDexSlot"
	item_dex_slot.custom_minimum_size = Vector2(52, 52)
	item_dex_slot.add_theme_stylebox_override("panel", _make_panel_style(UI_SLOT_BG, UI_BORDER_SOFT, 8, 1))

	item_dex_button = TextureButton.new()
	item_dex_button.name = "ItemDexButton"
	item_dex_button.custom_minimum_size = Vector2(32, 32)
	item_dex_button.tooltip_text = "Item Dex"
	item_dex_button.texture_normal = ITEM_DEX_ICON
	item_dex_button.texture_pressed = ITEM_DEX_ICON
	item_dex_button.texture_hover = ITEM_DEX_ICON
	item_dex_button.texture_disabled = ITEM_DEX_ICON
	item_dex_button.texture_focused = ITEM_DEX_ICON
	item_dex_button.ignore_texture_size = true
	item_dex_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	item_dex_button.focus_mode = Control.FOCUS_NONE
	item_dex_slot.add_child(item_dex_button)

	var actions_row := running_shoes_slot.get_parent()
	if actions_row != null:
		actions_row.add_child(item_dex_slot)
		actions_row.move_child(item_dex_slot, dev_actions_slot.get_index())

func _setup_item_dex_popup() -> void:
	item_dex_popup = PanelContainer.new()
	item_dex_popup.name = "ItemDexPopup"
	item_dex_popup.visible = false
	item_dex_popup.custom_minimum_size = Vector2(560, 430)
	item_dex_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	item_dex_popup.z_index = 365
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
	trainer_card_popup.z_index = 320
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
		trainer_card_popup.move_to_front()
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
	trainer_card_popup.move_to_front()

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

func _setup_bag_popup() -> void:
	bag_popup = PanelContainer.new()
	bag_popup.name = "BagPopup"
	bag_popup.visible = false
	bag_popup.custom_minimum_size = BAG_SIZE
	bag_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_popup.z_index = 360
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
		bag_popup.move_to_front()
		_load_bag_inventory()
		if bag_button.has_focus():
			bag_button.release_focus()

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
		normalized_items.append({
			"id": item_id,
			"name": _item_name_from_id(item_id),
			"category": _guess_bag_category(item_id),
			"quantity": max(int(item.get("quantity", 1)), 1),
		})
	return normalized_items

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
	if normalized.ends_with("ite") or normalized.ends_with("-z") or normalized.ends_with("ium-z"):
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
		bag_popup.move_to_front()
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
	if dev_add_item_button != null:
		_apply_button_style(dev_add_item_button, "primary")
	_apply_button_style(dev_clear_party_button, "danger")
	dev_clear_party_button.text = "Clear"
	_apply_button_style(dev_actions_close_button)

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

func _setup_collapsible_panels() -> void:
	_register_collapsible_panel("hotkey_sidebar", hotkey_sidebar_panel, "right_center")
	_register_collapsible_panel("chat", chat_panel, "right")
	_register_collapsible_panel("player_status", player_status_panel, "left")
	_register_collapsible_panel("party", party_panel, "left")
	_register_collapsible_panel("location", location_panel, "right_center")
	_register_collapsible_panel("options", options_panel, "right")
	_register_collapsible_panel("actions", actions_panel, "left")
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
	chat_resize_button.z_index = 200
	chat_resize_button.gui_input.connect(_on_chat_resize_button_gui_input)
	root_control.add_child(chat_resize_button)
	_position_chat_resize_button()

func _on_chat_resize_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		chat_resize_dragging = true
		chat_resize_drag_start_mouse = root_control.get_local_mouse_position()
		chat_resize_drag_start_rect = chat_panel.get_rect()
		get_viewport().set_input_as_handled()

func _register_collapsible_panel(panel_id: String, panel: Control, side: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = COLLAPSE_BUTTON_SIZE
	button.size = COLLAPSE_BUTTON_SIZE
	button.text = "-"
	button.tooltip_text = "Collapse"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = 200
	button.pressed.connect(_on_collapsible_panel_button_pressed.bind(panel_id))
	root_control.add_child(button)

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
	if collapsed and panel_id == "actions":
		dev_actions_popup.visible = false
	if panel_id == "chat":
		chat_tabs_panel.visible = available and not collapsed
		_position_chat_tabs_panel()
		_position_chat_resize_button()
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
			"left":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"right":
				position.x = rect.position.x
				position.y = rect.position.y
			"right_center":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			"bottom":
				position.x = rect.position.x + rect.size.x - COLLAPSE_BUTTON_SIZE.x
				position.y = rect.position.y
			_:
				position.x = rect.position.x
				position.y = rect.position.y
	else:
		match side:
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
			return

		settings_menu.visible = false
		_on_settings_menu_closed()
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

func _register_party_slot_drag_handlers(slot: Node, slot_index: int) -> void:
	slot.set("slot_index", slot_index)
	var drag_started_callable := Callable(self, "_on_party_slot_drag_started")
	var drag_released_callable := Callable(self, "_on_party_slot_drag_released")
	if slot.has_signal("drag_started") and not slot.is_connected("drag_started", drag_started_callable):
		slot.connect("drag_started", drag_started_callable)
	if slot.has_signal("drag_released") and not slot.is_connected("drag_released", drag_released_callable):
		slot.connect("drag_released", drag_released_callable)

func _on_party_slot_drag_started(slot_index: int) -> void:
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
	party_drag_source_slot.modulate = Color(1.0, 1.0, 1.0, 0.35)

	party_drag_visual = party_drag_source_slot.duplicate() as Control
	if party_drag_visual == null:
		return

	party_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_drag_visual.set_anchors_preset(Control.PRESET_TOP_LEFT)
	party_drag_visual.custom_minimum_size = source_global_rect.size
	party_drag_visual.size = source_global_rect.size
	party_drag_visual.z_index = 500
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
	var target_index := _get_party_slot_index_at_position(global_position)
	if target_index < 0 or target_index >= PlayerSave.party.size() or target_index == party_drag_start_index:
		party_drag_start_index = -1
		_clear_party_drag_visual()
		return

	var dragged_pokemon: Pokemon = PlayerSave.party[party_drag_start_index]
	PlayerSave.party[party_drag_start_index] = PlayerSave.party[target_index]
	PlayerSave.party[target_index] = dragged_pokemon
	party_drag_start_index = -1
	_clear_party_drag_visual()
	PlayerSave.party_changed.emit()
	await _save_party_state_after_change()

func _clear_party_drag_visual() -> void:
	if party_drag_source_slot != null:
		party_drag_source_slot.modulate = Color.WHITE
	party_drag_source_slot = null

	if party_drag_visual != null:
		party_drag_visual.queue_free()
	party_drag_visual = null

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
	if text == "":
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	chat_input.clear()
	if text == START_ENCOUNTER_CLIPBOARD_COMMAND or text == START_ENCOUNTER_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		await _handle_start_encounter_command(DisplayServer.clipboard_get())
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text == START_ENCOUNTER_COMMAND or text.begins_with(START_ENCOUNTER_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		var encounter_text := text.substr(START_ENCOUNTER_COMMAND.length()).strip_edges()
		await _handle_start_encounter_command(encounter_text)
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text == SPAWN_COMMAND or text.begins_with(SPAWN_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		var spawn_text := text.substr(SPAWN_COMMAND.length()).strip_edges()
		await _handle_start_encounter_command(spawn_text)
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text == ADD_POKEMON_CLIPBOARD_COMMAND or text == ADD_POKEMON_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		await _handle_add_pokemon_command(DisplayServer.clipboard_get())
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text == ADD_POKEMON_COMMAND or text.begins_with(ADD_POKEMON_COMMAND + " "):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		var pokemon_text := text.substr(ADD_POKEMON_COMMAND.length()).strip_edges()
		if pokemon_text == "":
			chat_submit_in_progress = false
			_show_dev_pokemon_popup(DevPokemonPopupMode.POKEMON)
			return

		await _handle_add_pokemon_command(pokemon_text)
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text == ADD_TEAM_CLIPBOARD_COMMAND or text == ADD_TEAM_CLIPBOARD_ALIAS:
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		await _handle_add_team_command(DisplayServer.clipboard_get())
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if _is_command_with_text(text, ADD_TEAM_COMMAND) or _is_command_with_text(text, ADD_TEAM_ALIAS):
		if not PlayerSave.is_staff:
			_add_chat_message("Command not recognized.")
			chat_submit_in_progress = false
			_keep_chat_input_focused()
			return

		var team_text: String = _strip_first_matching_command(text, [ADD_TEAM_ALIAS, ADD_TEAM_COMMAND])
		if team_text == "":
			chat_submit_in_progress = false
			_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)
			return

		await _handle_add_team_command(team_text)
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if text.begins_with("/"):
		_add_chat_message("Command not recognized.")
		chat_submit_in_progress = false
		_keep_chat_input_focused()
		return

	if not ChatRealtimeService.send_chat_message(text, _get_active_chat_channel()):
		_add_chat_message("Chat is reconnecting. Please try again in a moment.")
	chat_submit_in_progress = false
	_keep_chat_input_focused()

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

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	var pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(pokemon_data)
	if pokemon == null:
		print_debug("Dev add Pokemon failed after backend create. pokemon_data=", pokemon_data, " response=", response)
		var reason: String = PokemonFactory.last_error_message
		if reason == "":
			reason = "Unknown reason."

		_add_chat_message("Could not create Pokemon from backend data. Reason: %s" % reason)
		return false

	PlayerSave.add_pokemon(pokemon)
	await _save_party_state_after_change()
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

	var parsed_pokemon: Array[Pokemon] = []
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

		parsed_pokemon.append(pokemon)

	for pokemon in parsed_pokemon:
		PlayerSave.add_pokemon(pokemon)

	await _save_party_state_after_change()
	_add_chat_message("Added %s Pokemon to party." % parsed_pokemon.size())
	return true

func _clean_pokemon_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [ADD_POKEMON_CLIPBOARD_ALIAS, ADD_POKEMON_CLIPBOARD_COMMAND, ADD_POKEMON_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _clean_team_paste_text(team_text: String) -> String:
	var cleaned_text := team_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [ADD_TEAM_CLIPBOARD_ALIAS, ADD_TEAM_CLIPBOARD_COMMAND, ADD_TEAM_ALIAS, ADD_TEAM_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _is_command_with_text(text: String, command: String) -> bool:
	return text == command or text.begins_with(command + " ")

func _strip_first_matching_command(text: String, commands: Array) -> String:
	var cleaned_text: String = text.strip_edges()
	for command_value in commands:
		var command: String = str(command_value)
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			return cleaned_text.substr(command.length()).strip_edges()

	return cleaned_text

func _clean_encounter_paste_text(pokemon_text: String) -> String:
	var cleaned_text := pokemon_text.strip_edges()
	cleaned_text = cleaned_text.replace("\\n", "\n")

	for command in [START_ENCOUNTER_CLIPBOARD_ALIAS, START_ENCOUNTER_CLIPBOARD_COMMAND, START_ENCOUNTER_COMMAND, SPAWN_COMMAND]:
		if cleaned_text == command:
			return ""
		if cleaned_text.begins_with(command + " "):
			cleaned_text = cleaned_text.substr(command.length()).strip_edges()
			break

	return cleaned_text

func _on_dev_pokemon_button_pressed() -> void:
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
	if not PlayerSave.is_staff:
		return

	dev_actions_popup.visible = not dev_actions_popup.visible

func _on_item_dex_button_pressed() -> void:
	await _show_item_dex_popup()

func _show_item_dex_popup() -> void:
	item_dex_popup.visible = true
	item_dex_popup.move_to_front()
	item_dex_search_input.grab_focus.call_deferred()
	await _refresh_item_dex_results()

func _hide_item_dex_popup() -> void:
	item_dex_popup.visible = false

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
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_add_team_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_spawn_pokemon_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.SPAWN)

func _on_dev_add_item_button_pressed() -> void:
	if not PlayerSave.is_staff:
		return

	dev_actions_popup.visible = false
	await _show_dev_add_item_popup()

func _show_dev_add_item_popup() -> void:
	dev_selected_item = {}
	dev_item_confirm_button.disabled = true
	dev_item_quantity_spinbox.value = 1
	dev_item_search_input.clear()
	dev_add_item_popup.visible = true
	dev_add_item_popup.move_to_front()
	dev_item_search_input.grab_focus.call_deferred()
	await _refresh_dev_item_results()

func _hide_dev_add_item_popup() -> void:
	dev_add_item_popup.visible = false
	dev_selected_item = {}

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
	dev_selected_item = {}
	dev_item_confirm_button.disabled = true
	_refresh_dev_item_results()

func _refresh_dev_item_results() -> void:
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
	dev_selected_item = item.duplicate(true)
	dev_item_confirm_button.disabled = false
	for child: Node in dev_item_results_list.get_children():
		if child is Button:
			var button: Button = child as Button
			_apply_button_style(button, "primary" if button.tooltip_text == str(dev_selected_item.get("shortDesc", dev_selected_item.get("desc", ""))) else "default")

func _on_dev_item_confirm_pressed() -> void:
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
	if not PlayerSave.is_staff:
		return

	dev_actions_popup.visible = false
	dev_clear_menu_popup.visible = true
	dev_clear_menu_popup.move_to_front()

func _on_dev_clear_party_option_pressed() -> void:
	dev_clear_menu_popup.visible = false
	clear_party_confirm_dialog.popup_centered(Vector2i(460, 150))

func _on_dev_clear_inventory_option_pressed() -> void:
	dev_clear_menu_popup.visible = false
	clear_inventory_confirm_dialog.popup_centered(Vector2i(460, 150))

func _on_clear_party_confirmed() -> void:
	if not PlayerSave.is_staff:
		return

	PlayerSave.party.clear()
	PlayerSave.party_changed.emit()
	await _save_party_state_after_change()
	dev_actions_popup.visible = false
	_add_chat_message("Party cleared.")

func _on_clear_inventory_confirmed() -> void:
	if not PlayerSave.is_staff:
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

func _show_dev_pokemon_popup(mode: int) -> void:
	if not PlayerSave.is_staff:
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
	dev_pokemon_text.grab_focus()

func _on_dev_pokemon_add_button_pressed() -> void:
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
		return

	settings_menu.visible = true

func _on_running_shoes_toggled(enabled: bool) -> void:
	GameState.running_shoes_enabled = enabled
	_set_icon_slot_active(running_shoes_slot, enabled)
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("set_running_shoes_enabled"):
		player_node.call("set_running_shoes_enabled", enabled)

func _on_settings_menu_closed() -> void:
	if settings_button.has_focus():
		settings_button.release_focus()

func _disable_icon_button_focus() -> void:
	for button: BaseButton in [
		map_button,
		running_shoes_button,
		bag_button,
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
	await get_tree().process_frame
	await get_tree().process_frame
	var vertical_scroll_bar: VScrollBar = message_scroll.get_v_scroll_bar()
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
	if text == "":
		return

	var channel: String = str(message.get("channel", CHAT_CHANNEL_GLOBAL)).strip_edges().to_lower()
	_add_user_chat_message(user, display_name, text, channel)


func _add_user_chat_message(user: Dictionary, display_name: String, text: String, channel: String = CHAT_CHANNEL_GLOBAL) -> void:
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

	var entry: RichTextLabel = message_entry_template.duplicate() as RichTextLabel
	row.add_child(entry)
	entry.visible = true
	entry.bbcode_enabled = true
	entry.clear()
	entry.append_text("[color=%s][b]%s[/b][/color][color=%s]:[/color] [color=%s]%s[/color]" % [
		_sanitize_hex_color(name_color, "#dfe4f2"),
		_escape_bbcode(display_name),
		CHAT_SEPARATOR_COLOR,
		CHAT_MESSAGE_COLOR,
		_escape_bbcode(text),
	])
	entry.fit_content = true
	entry.scroll_active = false
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_chat_to_bottom.call_deferred()


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
	var error: Error = get_tree().change_scene_to_file(LOGIN_SCENE_PATH)
	if error != OK:
		push_warning("Could not return to login screen after session invalidation: %s" % error_string(error))
