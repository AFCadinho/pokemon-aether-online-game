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
const CHAT_TAB_SYSTEM := "system"
const CHAT_CATEGORY_USER := "user"
const CHAT_CATEGORY_SYSTEM := "system"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const PLAYER_PREVIEW_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLAYER_STATUS_CARD_SIZE := Vector2(248, 86)
const PLAYER_STATUS_CARD_MARGIN := Vector2(16, 16)
const PLAYER_STATUS_AVATAR_VIEWPORT_SIZE := Vector2i(76, 76)
const PLAYER_STATUS_AVATAR_POSITION := Vector2(38, 52)
const PLAYER_STATUS_AVATAR_SCALE := Vector2(1.5, 1.5)
const TRAINER_CARD_SIZE := Vector2(560, 390)
const TRAINER_CARD_AVATAR_VIEWPORT_SIZE := Vector2i(160, 160)
const TRAINER_CARD_AVATAR_POSITION := Vector2(80, 112)
const TRAINER_CARD_AVATAR_SCALE := Vector2(2.8, 2.8)
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
const PLAYER_STATUS_CARD_TEXT := UI_TEXT
const PLAYER_STATUS_MONEY_COLOR := UI_MONEY
const PLAYER_STATUS_MONEY_ICON := "$"

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
@onready var repel_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/RepelSlot
@onready var repel_toggle_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/RepelSlot/RepelToggle
@onready var follower_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/FollowerSlot
@onready var follower_toggle_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/FollowerSlot/FollowerToggle
@onready var dev_actions_slot: PanelContainer = $Control/ActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot
@onready var dev_actions_button: TextureButton = $Control/ActionsPanel/MarginContainer/HBoxContainer/DevActionsSlot/DevActionsButton
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
var chat_submit_in_progress: bool = false
var active_chat_tab: String = CHAT_TAB_GENERAL
var player_status_panel: PanelContainer
var player_status_name_label: Label
var player_status_money_label: Label
var player_status_avatar_viewport: SubViewport
var trainer_card_popup: PanelContainer
var trainer_card_avatar_viewport: SubViewport
var trainer_card_body_buttons: Dictionary = {}
var displayed_money: int = -1
var displayed_location_map: Node
var utc_time_refresh_elapsed := UTC_TIME_REFRESH_INTERVAL_SECONDS

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_player_status_card()
	_setup_trainer_card_popup()
	_build_party_slots()
	_setup_collapsible_panels()
	_setup_chat_resize_button()
	_setup_clear_party_confirm_dialog()
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
	system_chat_tab_button.pressed.connect(_on_chat_tab_pressed.bind(CHAT_TAB_SYSTEM))
	general_chat_tab_button.focus_mode = Control.FOCUS_NONE
	system_chat_tab_button.focus_mode = Control.FOCUS_NONE
	_apply_chat_tab_state()
	dev_pokemon_button.visible = false
	dev_pokemon_button.disabled = true
	dev_pokemon_add_button.pressed.connect(_on_dev_pokemon_add_button_pressed)
	dev_pokemon_close_button.pressed.connect(_on_dev_pokemon_close_button_pressed)
	_setup_icon_slot_hover(map_slot, map_button)
	_setup_icon_slot_hover(bag_slot, bag_button)
	_setup_icon_slot_hover(settings_slot, settings_button)
	_setup_icon_slot_hover(repel_slot, repel_toggle_button)
	_setup_icon_slot_hover(follower_slot, follower_toggle_button)
	_setup_icon_slot_hover(dev_actions_slot, dev_actions_button)
	settings_button.pressed.connect(_on_settings_button_pressed)
	repel_toggle_button.set_pressed_no_signal(GameState.repel_enabled)
	repel_toggle_button.toggled.connect(_on_repel_toggle_toggled)
	follower_toggle_button.set_pressed_no_signal(GameState.show_follower)
	follower_toggle_button.toggled.connect(_on_follower_toggle_toggled)
	_load_follower_preference.call_deferred()
	dev_actions_button.pressed.connect(_on_dev_actions_button_pressed)
	dev_add_pokemon_button.pressed.connect(_on_dev_add_pokemon_button_pressed)
	dev_add_team_button.visible = false
	dev_add_team_button.disabled = true
	dev_spawn_pokemon_button.pressed.connect(_on_dev_spawn_pokemon_button_pressed)
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

func _process(delta: float) -> void:
	_position_collapsible_buttons()
	_refresh_player_status_card_if_needed()
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

	if chat_input.has_focus() and _is_settings_toggle_event(event):
		chat_input.release_focus()
		get_viewport().set_input_as_handled()
		return

	if _is_settings_toggle_event(event):
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
			clampf(chat_resize_drag_start_rect.size.x - delta.x, CHAT_MIN_SIZE.x, CHAT_MAX_SIZE.x),
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

func _setup_player_status_card() -> void:
	player_status_panel = PanelContainer.new()
	player_status_panel.name = "PlayerStatusPanel"
	player_status_panel.custom_minimum_size = PLAYER_STATUS_CARD_SIZE
	player_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	player_status_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	player_status_panel.anchor_left = 0.0
	player_status_panel.anchor_top = 1.0
	player_status_panel.anchor_right = 0.0
	player_status_panel.anchor_bottom = 1.0
	player_status_panel.offset_left = PLAYER_STATUS_CARD_MARGIN.x
	player_status_panel.offset_top = -PLAYER_STATUS_CARD_SIZE.y - PLAYER_STATUS_CARD_MARGIN.y
	player_status_panel.offset_right = PLAYER_STATUS_CARD_MARGIN.x + PLAYER_STATUS_CARD_SIZE.x
	player_status_panel.offset_bottom = -PLAYER_STATUS_CARD_MARGIN.y
	player_status_panel.add_theme_stylebox_override("panel", _make_panel_style(
		PLAYER_STATUS_CARD_BACKGROUND,
		PLAYER_STATUS_CARD_BORDER,
		14,
		1
	))
	root_control.add_child(player_status_panel)
	player_status_panel.gui_input.connect(_on_player_status_panel_gui_input)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	player_status_panel.add_child(margin_container)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin_container.add_child(row)

	row.add_child(_create_player_status_avatar())

	var info_layout := VBoxContainer.new()
	info_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	info_layout.add_theme_constant_override("separation", 7)
	row.add_child(info_layout)

	player_status_name_label = Label.new()
	player_status_name_label.text = PlayerSave.player_name
	player_status_name_label.add_theme_font_size_override("font_size", 17)
	player_status_name_label.add_theme_color_override("font_color", PLAYER_STATUS_CARD_TEXT)
	player_status_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_layout.add_child(player_status_name_label)

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 8)
	info_layout.add_child(money_row)

	var money_icon := PanelContainer.new()
	money_icon.custom_minimum_size = Vector2(24, 24)
	money_icon.add_theme_stylebox_override("panel", _make_panel_style(PLAYER_STATUS_MONEY_COLOR, Color("#fff1a8"), 12, 1))
	money_row.add_child(money_icon)

	var money_icon_label := Label.new()
	money_icon_label.text = PLAYER_STATUS_MONEY_ICON
	money_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_icon_label.add_theme_color_override("font_color", Color("#5b3f00"))
	money_icon_label.add_theme_font_size_override("font_size", 15)
	money_icon.add_child(money_icon_label)

	player_status_money_label = Label.new()
	player_status_money_label.add_theme_font_size_override("font_size", 22)
	player_status_money_label.add_theme_color_override("font_color", PLAYER_STATUS_MONEY_COLOR)
	player_status_money_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	money_row.add_child(player_status_money_label)

	_refresh_player_status_card()

func _create_player_status_avatar() -> Control:
	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(68, 68)
	avatar_frame.add_theme_stylebox_override("panel", _make_panel_style(UI_BG_STRONG, Color("#f4ecd5"), 34, 2))

	var avatar_viewport_container := SubViewportContainer.new()
	avatar_viewport_container.custom_minimum_size = Vector2(68, 68)
	avatar_viewport_container.stretch = false
	avatar_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(avatar_viewport_container)

	var avatar_viewport := SubViewport.new()
	avatar_viewport.transparent_bg = true
	avatar_viewport.size = PLAYER_STATUS_AVATAR_VIEWPORT_SIZE
	avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	avatar_viewport_container.add_child(avatar_viewport)
	player_status_avatar_viewport = avatar_viewport

	_populate_avatar_preview(avatar_viewport, PLAYER_STATUS_AVATAR_POSITION, PLAYER_STATUS_AVATAR_SCALE)

	return avatar_frame

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
	_populate_avatar_preview(trainer_card_avatar_viewport, TRAINER_CARD_AVATAR_POSITION, TRAINER_CARD_AVATAR_SCALE)

func _apply_avatar_preview_body(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if sprite.name == "BodySprite":
			var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(PlayerSave.appearance_body_id)
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

func _refresh_player_status_card() -> void:
	displayed_money = _get_player_money_value()
	if player_status_name_label != null:
		player_status_name_label.text = PlayerSave.player_name
	if player_status_money_label != null:
		player_status_money_label.text = _format_money(displayed_money)

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
	margin_container.add_theme_constant_override("margin_bottom", 16)
	trainer_card_popup.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Trainer Card"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UI_MONEY)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_hide_trainer_card)
	_apply_button_style(close_button, "danger")
	header.add_child(close_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	layout.add_child(content)

	content.add_child(_create_trainer_card_avatar_panel())

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 14)
	tabs.add_child(_create_trainer_card_stats_tab())
	tabs.add_child(_create_trainer_card_appearance_tab())
	content.add_child(tabs)

func _create_trainer_card_avatar_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(UI_BG_STRONG, UI_BORDER_SOFT, 8, 1))

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin_container)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	margin_container.add_child(layout)

	var viewport_frame := PanelContainer.new()
	viewport_frame.custom_minimum_size = Vector2(160, 160)
	viewport_frame.add_theme_stylebox_override("panel", _make_panel_style(Color("#04070df2"), UI_BORDER_FOCUS, 80, 2))
	layout.add_child(viewport_frame)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(160, 160)
	viewport_container.stretch = false
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_frame.add_child(viewport_container)

	trainer_card_avatar_viewport = SubViewport.new()
	trainer_card_avatar_viewport.transparent_bg = true
	trainer_card_avatar_viewport.size = TRAINER_CARD_AVATAR_VIEWPORT_SIZE
	trainer_card_avatar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(trainer_card_avatar_viewport)
	_populate_avatar_preview(trainer_card_avatar_viewport, TRAINER_CARD_AVATAR_POSITION, TRAINER_CARD_AVATAR_SCALE)

	var name_label := Label.new()
	name_label.text = PlayerSave.player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(name_label)

	return panel

func _create_trainer_card_stats_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "Trainer"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 12)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	tab.add_child(layout)

	layout.add_child(_create_trainer_card_stat_row("Name", PlayerSave.player_name))
	layout.add_child(_create_trainer_card_stat_row("ID", str(PlayerSave.player_id)))
	layout.add_child(_create_trainer_card_stat_row("Money", _format_money(_get_player_money_value())))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	return tab

func _create_trainer_card_stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.custom_minimum_size = Vector2(82, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color("#00f5ff"))
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)

	return row

func _create_trainer_card_appearance_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "Appearance"
	tab.add_theme_constant_override("margin_left", 12)
	tab.add_theme_constant_override("margin_top", 12)
	tab.add_theme_constant_override("margin_right", 12)
	tab.add_theme_constant_override("margin_bottom", 12)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	tab.add_child(layout)

	var body_label := Label.new()
	body_label.text = "Body Sprite"
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", UI_TEXT)
	layout.add_child(body_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

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
	return tab

func _get_body_appearance_ids() -> Array[String]:
	var ids: Array[String] = CharacterAppearanceService.get_available_body_ids()
	if ids.is_empty():
		ids.append(CharacterAppearanceService.DEFAULT_BODY_ID)
	return ids

func _format_body_appearance_name(body_id: String) -> String:
	var text := body_id.replace("_", " ").replace("-", " ").strip_edges()
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

func _show_trainer_card() -> void:
	if trainer_card_popup == null:
		return

	_refresh_trainer_card_body_buttons()
	_refresh_avatar_previews()
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
	_apply_button_style(system_chat_tab_button, "primary")
	_apply_button_style(send_button, "primary")
	_apply_button_style(dev_pokemon_add_button, "primary")
	_apply_button_style(dev_pokemon_close_button)
	_apply_button_style(dev_add_pokemon_button, "primary")
	_apply_button_style(dev_spawn_pokemon_button, "primary")
	_apply_button_style(dev_clear_party_button, "danger")
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

	for panel_id_value: Variant in collapsible_panels.keys():
		var panel_id := str(panel_id_value)
		var state: Dictionary = collapsible_panels.get(panel_id, {})
		var button: Button = state.get("button") as Button
		if button != null:
			_apply_button_style(button)
	if chat_resize_button != null:
		_apply_button_style(chat_resize_button)

func _setup_collapsible_panels() -> void:
	_register_collapsible_panel("chat", chat_panel, "left")
	_register_collapsible_panel("player_status", player_status_panel, "right")
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
	chat_panel.offset_left = chat_panel.offset_right - clamped_size.x
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
	if active_chat_tab != CHAT_TAB_GENERAL:
		return

	_submit_chat_input_deferred()

func _on_chat_text_submitted(_text: String) -> void:
	if active_chat_tab != CHAT_TAB_GENERAL:
		return

	_submit_chat_input_deferred()

func _on_chat_tab_pressed(tab_id: String) -> void:
	if active_chat_tab == tab_id:
		return

	active_chat_tab = tab_id
	_apply_chat_tab_state()

func _apply_chat_tab_state() -> void:
	var general_active: bool = active_chat_tab == CHAT_TAB_GENERAL
	general_chat_tab_button.add_theme_color_override("font_color", Color(CHAT_SYSTEM_LABEL_COLOR if general_active else CHAT_MESSAGE_COLOR))
	system_chat_tab_button.add_theme_color_override("font_color", Color(CHAT_SYSTEM_LABEL_COLOR if active_chat_tab == CHAT_TAB_SYSTEM else CHAT_MESSAGE_COLOR))
	chat_input.editable = general_active
	chat_input.placeholder_text = "" if general_active else "System messages only"
	send_button.disabled = not general_active
	if not general_active:
		chat_input.release_focus()
	_refresh_chat_message_visibility()
	_scroll_chat_to_bottom.call_deferred()

func _refresh_chat_message_visibility() -> void:
	for child: Node in message_list.get_children():
		if child == message_entry_template:
			continue

		var category: String = str(child.get_meta("chat_category", CHAT_CATEGORY_USER))
		child.visible = active_chat_tab == CHAT_TAB_GENERAL or category == CHAT_CATEGORY_SYSTEM

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

	if not ChatRealtimeService.send_chat_message(text):
		_add_chat_message("Chat is reconnecting. Please try again in a moment.")
	chat_submit_in_progress = false
	_keep_chat_input_focused()

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

func _on_dev_add_pokemon_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_add_team_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.TEAM)

func _on_dev_spawn_pokemon_button_pressed() -> void:
	dev_actions_popup.visible = false
	_show_dev_pokemon_popup(DevPokemonPopupMode.SPAWN)

func _on_dev_clear_party_button_pressed() -> void:
	if not PlayerSave.is_staff:
		return

	clear_party_confirm_dialog.popup_centered(Vector2i(460, 150))

func _on_clear_party_confirmed() -> void:
	if not PlayerSave.is_staff:
		return

	PlayerSave.party.clear()
	PlayerSave.party_changed.emit()
	await _save_party_state_after_change()
	dev_actions_popup.visible = false
	_add_chat_message("Party cleared.")

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

func _on_settings_menu_closed() -> void:
	settings_button.grab_focus()

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

	_add_user_chat_message(user, display_name, text)


func _add_user_chat_message(user: Dictionary, display_name: String, text: String) -> void:
	var role: Dictionary = _get_primary_visible_chat_role(user)
	var role_color: String = str(role.get("color", "#d8b767"))
	var name_color: String = role_color if not role.is_empty() else CHAT_DEFAULT_NAME_COLOR

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 4)
	row.set_meta("chat_category", CHAT_CATEGORY_USER)
	row.visible = _should_show_chat_category(CHAT_CATEGORY_USER)
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
	return active_chat_tab == CHAT_TAB_GENERAL or category == CHAT_CATEGORY_SYSTEM


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
