extends PanelContainer

class_name GuildPopup

signal closed
signal lobby_teleport_requested
signal private_message_requested(user: Dictionary)
signal trainer_card_requested(player: Dictionary)

const POPUP_SIZE := Vector2(1040, 700)
const GUILD_ICON: Texture2D = preload("res://assets/ui/guild.svg")
const CREATION_COST := 100000
const REQUIRED_BADGES := 3
const GUILD_EMBLEM_SIZE := 32
const GUILD_EMBLEM_PIXEL_COUNT := GUILD_EMBLEM_SIZE * GUILD_EMBLEM_SIZE
const LEGACY_GUILD_EMBLEM_SIZE := 8
const EMBLEM_EDITOR_PIXEL_SIZE := 11
const EMBLEM_EDITOR_POPUP_SIZE := Vector2i(630, 500)
const DIRECTORY_FILTER_POPUP_SIZE := Vector2i(420, 390)
const GUILD_LANGUAGE_OPTIONS: Array[String] = [
	"English",
	"Spanish",
	"Portuguese",
	"Italian",
	"Chinese",
	"German",
	"French",
	"Dutch",
	"Dutch / English",
	"Other",
]
const GUILD_ASSIGNABLE_ROLES: Array[String] = ["recruit", "member", "captain"]
const GUILD_BANK_PERMISSIONS: Array[String] = [
	"bank_deposit",
	"bank_withdraw",
	"bank_borrow",
	"bank_force_return",
]

const UI_BG := Color("#050b14f5")
const UI_SURFACE := Color("#081522f2")
const UI_RAISED := Color("#0b1a2bf2")
const UI_HOVER := Color("#112a44fa")
const UI_INPUT := Color("#030812e8")
const UI_BORDER := Color("#315070")
const UI_BORDER_INNER := Color("#29445f")
const UI_ACCENT := Color("#60d3ff")
const UI_ACCENT_SOFT := Color("#3d7596")
const UI_GOLD := Color("#e3bd68")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED := Color("#aeb8c5")
const UI_SUCCESS := Color("#79e49b")
const UI_WARNING := Color("#f0c875")

# Preview-only data used by the isolated interface checks. Normal gameplay always
# loads the authoritative directory from the guild service.
const DEBUG_GUILDS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Aether Vanguard",
		"leader": "Nova",
		"level": 12,
		"members": 38,
		"capacity": 50,
		"language": "English",
		"focus": "PvP & Social",
		"recruitment": "Applications open",
		"description": "A competitive but welcoming guild preparing for Aether Clash. We train together, help newer members build teams and organise weekly battles.",
		"accent": Color("#57c7ff"),
	},
	{
		"id": 2,
		"name": "Kanto Explorers",
		"leader": "Maple",
		"level": 8,
		"members": 24,
		"capacity": 40,
		"language": "Dutch / English",
		"focus": "PvE & Social",
		"recruitment": "Open",
		"description": "A relaxed guild for trainers who enjoy exploring, collecting and helping each other through the story. All experience levels are welcome.",
		"accent": Color("#80e2a2"),
	},
	{
		"id": 3,
		"name": "Midnight League",
		"leader": "Umbra",
		"level": 15,
		"members": 47,
		"capacity": 50,
		"language": "English",
		"focus": "Competitive PvP",
		"recruitment": "Invite only",
		"description": "A focused competitive roster for experienced battlers. Recruitment is currently handled through personal invitations.",
		"accent": Color("#a78bfa"),
	},
	{
		"id": 4,
		"name": "Berry Buddies",
		"leader": "Pecha",
		"level": 5,
		"members": 16,
		"capacity": 30,
		"language": "English",
		"focus": "Casual",
		"recruitment": "Applications open",
		"description": "A small social guild built around trading, collecting and having a good time. No competitive experience required.",
		"accent": Color("#ff9cb1"),
	},
]

var guilds: Array[Dictionary] = []
var membership: Dictionary = {}
var guild_home: Dictionary = {}
var incoming_invitations: Array = []
var pending_applications: Array = []
var selected_guild_id := 0
var active_page := "browse"
var is_dragging_popup := false
var is_debug_preview := false
var is_loading_guilds := false
var is_creating_guild := false
var is_application_action_in_flight := false
var is_leaving_guild := false
var directory_request_generation := 0
var has_explicit_page_selection := false
var active_guild_section := "overview"
var active_guild_bank_category := ""
var guild_bank_state: Dictionary = {}
var is_loading_guild_bank := false
var is_guild_bank_action_in_flight := false
var is_applying_guild_bank_party := false
var guild_section_buttons: Dictionary = {}
var directory_recruitment_filter := "all"
var directory_focus_filter := "all"
var directory_language_filter := "all"

var browse_tab_button: Button
var create_tab_button: Button
var primary_navigation: HBoxContainer
var guild_section_navigation: HBoxContainer
var primary_navigation_spacer: Control
var browse_page: Control
var member_page: Control
var create_page: Control
var search_input: LineEdit
var guild_list: VBoxContainer
var guild_count_label: Label
var detail_content: VBoxContainer
var browse_status_label: Label
var directory_filter_button: Button
var directory_filter_popup: PopupPanel
var directory_recruitment_select: OptionButton
var directory_focus_select: OptionButton
var directory_language_select: OptionButton
var create_status_label: Label
var guild_name_input: LineEdit
var guild_description_input: TextEdit
var money_requirement_label: Label
var badge_requirement_label: Label
var membership_label: Label
var language_select: OptionButton
var focus_select: OptionButton
var recruitment_select: OptionButton
var submit_create_button: Button
var incoming_invitations_container: VBoxContainer
var member_content: VBoxContainer
var member_status_label: Label
var settings_description_input: TextEdit
var settings_announcement_input: TextEdit
var settings_language_select: OptionButton
var settings_focus_select: OptionButton
var settings_recruitment_select: OptionButton
var settings_loan_duration_select: OptionButton
var invite_username_input: LineEdit
var member_search_input: LineEdit
var member_cards_container: VBoxContainer
var emblem_editor_popup: PopupPanel
var emblem_grid: GridContainer
var emblem_pixel_buttons: Array[Button] = []
var emblem_palette_grid: GridContainer
var emblem_color_buttons: Array[Button] = []
var emblem_color_code_input: LineEdit
var emblem_color_code_preview: PanelContainer
var emblem_color_code_status_label: Label
var emblem_template_select: OptionButton
var apply_emblem_template_button: Button
var emblem_palette: Array[String] = ["#60d3ff", "#79e49b", "#e3bd68", "#a78bfa", "#f4f0de"]
var emblem_pixels: Array[int] = []
var selected_emblem_color := 0


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _outer_style())
	_build_ui()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save != null:
		var party_callable := Callable(self, "_on_player_party_changed")
		if not player_save.is_connected("party_changed", party_callable):
			player_save.connect("party_changed", party_callable)


func open() -> void:
	visible = true
	has_explicit_page_selection = false
	_center_in_viewport()
	_clamp_to_viewport()
	_refresh_creation_requirements()
	_render_guild_list()
	_show_page("member" if not membership.is_empty() else "browse")
	if not is_debug_preview:
		call_deferred("_refresh_from_server")


func close() -> void:
	is_dragging_popup = false
	if emblem_editor_popup != null:
		emblem_editor_popup.hide()
	if directory_filter_popup != null:
		directory_filter_popup.hide()
	visible = false
	closed.emit()


func set_guilds(entries: Array) -> void:
	guilds.clear()
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			guilds.append((entry_value as Dictionary).duplicate(true))
	var membership_guild_id := int(membership.get("guildId", 0))
	if membership_guild_id > 0 and _contains_guild_id(guilds, membership_guild_id):
		selected_guild_id = membership_guild_id
	elif not _contains_guild_id(guilds, selected_guild_id):
		selected_guild_id = int(guilds[0].get("id", 0)) if not guilds.is_empty() else 0
	_render_guild_list()
	_refresh_membership_state()


func show_debug_preview() -> void:
	is_debug_preview = true
	membership = {}
	pending_applications = []
	set_guilds(DEBUG_GUILDS)
	if browse_status_label != null:
		browse_status_label.text = _t("ui.guild.status.preview")
		browse_status_label.visible = true


func show_debug_member_preview() -> void:
	is_debug_preview = true
	active_guild_section = "overview"
	var guild := DEBUG_GUILDS[0].duplicate(true)
	guild["members"] = 3
	guild["emblem"] = {
		"version": 1,
		"size": GUILD_EMBLEM_SIZE,
		"palette": emblem_palette.duplicate(),
		"pixels": _upscale_legacy_emblem_pixels([
			-1, -1, 0, 0, 0, 0, -1, -1,
			-1, 0, 1, 1, 1, 1, 0, -1,
			0, 1, 0, 1, 1, 0, 1, 0,
			0, 1, 1, 1, 1, 1, 1, 0,
			0, 1, 1, 1, 1, 1, 1, 0,
			-1, 0, 1, 1, 1, 1, 0, -1,
			-1, -1, 0, 1, 1, 0, -1, -1,
			-1, -1, -1, 0, 0, -1, -1, -1,
		]),
	}
	membership = {
		"userId": 1,
		"guildId": int(guild.get("id", 1)),
		"role": "leader",
		"permissions": [
			"bank_deposit", "bank_withdraw", "bank_borrow", "bank_force_return",
			"manage_members", "manage_guild", "manage_permissions",
		],
		"bankPermissionOverrides": {},
	}
	guild_home = {
		"guild": guild,
		"membership": membership.duplicate(),
		"announcement": "Aether Clash practice starts Friday at 20:00.",
		"members": [
			{
				"userId": 1, "username": "nova", "displayName": "Nova",
				"role": "leader", "online": true,
				"rankPermissions": membership["permissions"],
				"bankPermissionOverrides": {},
			},
			{
				"userId": 2, "username": "maple", "displayName": "Maple",
				"role": "captain", "online": true,
				"rankPermissions": ["bank_deposit", "bank_withdraw", "bank_borrow", "bank_force_return", "manage_members"],
				"bankPermissionOverrides": {"bank_borrow": "deny"},
			},
			{
				"userId": 3, "username": "pecha", "displayName": "Pecha",
				"role": "member", "online": false,
				"lastSeenAt": "2026-08-22T16:30:00Z",
				"rankPermissions": ["bank_borrow"],
				"bankPermissionOverrides": {},
			},
		],
		"pendingInvitations": [
			{"id": 1, "invitedUsername": "leaf", "invitedDisplayName": "Leaf"},
		],
		"pendingApplications": [
			{
				"id": 8,
				"guildId": int(guild.get("id", 1)),
				"applicantUserId": 4,
				"applicantUsername": "red",
				"applicantDisplayName": "Red",
				"status": "pending",
			},
		],
		"emblemTemplates": [
			{
				"templateId": "squirtle-guild-emblem-template",
				"name": "Squirtle Guild Emblem",
				"emblem": guild["emblem"],
			},
		],
		"rankPermissions": {
			"leader": membership["permissions"],
			"captain": ["bank_deposit", "bank_withdraw", "bank_borrow", "bank_force_return", "manage_members"],
			"member": ["bank_borrow"],
			"recruit": [],
		},
	}
	guild_bank_state = {
		"access": {"canDeposit": true, "canWithdraw": true, "canDepositFunds": true, "canWithdrawFunds": true, "lendingEnabled": true, "pokemonTradeLevelCap": 100, "canBorrow": true, "canForceReturn": true},
		"funds": {"balance": 250000, "playerBalance": 87500},
		"items": [
			{"itemId": "potion", "name": "Potion", "category": "Medicine", "quantity": 18, "availableQuantity": 18, "borrowedQuantity": 0, "lendable": false},
			{"itemId": "leftovers", "name": "Leftovers", "category": "Held Items", "quantity": 18, "availableQuantity": 17, "borrowedQuantity": 1, "lendable": true},
		],
		"inventory": [
			{"itemId": "poke-ball", "name": "Poke Ball", "category": "Poke Balls", "quantity": 12},
		],
		"pokemon": [
			{
				"pokemonId": 21,
				"pokemon": {"name": "Blastoise", "level": 50},
				"depositedBy": "Maple",
				"isBorrowed": false,
				"canReturn": false,
				"canWithdraw": true,
				"canBorrow": true,
			},
		],
		"depositablePokemon": [
			{"pokemonId": 22, "pokemon": {"name": "Venusaur", "level": 48}},
		],
		"party": [],
	}
	set_guilds([guild])
	_refresh_membership_state()
	_render_guild_home()
	_show_page("member")


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
		_clamp_to_viewport()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 16, 18, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_navigation())

	var page_shell := PanelContainer.new()
	page_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_shell.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE, UI_BORDER_INNER, 11, 1))
	root.add_child(page_shell)

	var page_margin := MarginContainer.new()
	_set_margins(page_margin, 14, 14, 14, 14)
	page_shell.add_child(page_margin)

	var pages := Control.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_child(pages)

	browse_page = _build_browse_page()
	browse_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(browse_page)
	member_page = _build_member_page()
	member_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(member_page)
	create_page = _build_create_page()
	create_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(create_page)
	_show_page("browse")


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	header.add_theme_constant_override("separation", 11)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_drag_handle_gui_input)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(46, 46)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_theme_stylebox_override("panel", _panel_style(Color("#0a2133f2"), Color("#60d3ff99"), 11, 1))
	header.add_child(icon_frame)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_center)
	icon_center.add_child(_icon_rect(32, UI_ACCENT))

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 0)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	heading.add_child(_localized_label("ui.guild.title", 22, UI_TEXT))
	heading.add_child(_localized_label("ui.guild.subtitle", 11, UI_MUTED))

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "ui.guild.close")
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.pressed.connect(close)
	close_button.add_theme_font_size_override("font_size", 19)
	_apply_button_style(close_button)
	header.add_child(close_button)
	return header


func _build_navigation() -> Control:
	var navigation := HBoxContainer.new()
	primary_navigation = navigation
	navigation.add_theme_constant_override("separation", 6)

	guild_section_navigation = HBoxContainer.new()
	guild_section_navigation.name = "GuildSectionNavigation"
	guild_section_navigation.add_theme_constant_override("separation", 6)
	guild_section_navigation.visible = false
	navigation.add_child(guild_section_navigation)

	browse_tab_button = Button.new()
	browse_tab_button.name = "BrowseGuildsButton"
	_set_localized_property(browse_tab_button, "text", "ui.guild.tab.browse")
	browse_tab_button.custom_minimum_size = Vector2(190, 40)
	browse_tab_button.pressed.connect(_on_primary_navigation_pressed.bind("browse"))
	navigation.add_child(browse_tab_button)

	create_tab_button = Button.new()
	create_tab_button.name = "CreateGuildButton"
	_set_localized_property(create_tab_button, "text", "ui.guild.tab.create")
	create_tab_button.custom_minimum_size = Vector2(165, 40)
	create_tab_button.pressed.connect(_on_primary_navigation_pressed.bind("create"))
	navigation.add_child(create_tab_button)

	primary_navigation_spacer = Control.new()
	primary_navigation_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(primary_navigation_spacer)
	membership_label = _localized_label("ui.guild.membership.none", 11, UI_MUTED)
	membership_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	navigation.add_child(membership_label)
	return navigation


func _build_browse_page() -> Control:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)

	var directory := VBoxContainer.new()
	directory.custom_minimum_size = Vector2(370, 0)
	directory.add_theme_constant_override("separation", 9)
	body.add_child(directory)

	incoming_invitations_container = VBoxContainer.new()
	incoming_invitations_container.name = "GuildInvitations"
	incoming_invitations_container.add_theme_constant_override("separation", 6)
	directory.add_child(incoming_invitations_container)

	var heading := HBoxContainer.new()
	directory.add_child(heading)
	var title := _localized_label("ui.guild.directory", 10, UI_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	guild_count_label = _label(_t("ui.guild.count.many", {"count": 0}), 11, UI_MUTED)
	heading.add_child(guild_count_label)

	search_input = LineEdit.new()
	search_input.name = "GuildSearchInput"
	_set_localized_property(search_input, "placeholder_text", "ui.guild.search")
	search_input.clear_button_enabled = true
	search_input.custom_minimum_size = Vector2(0, 40)
	search_input.text_changed.connect(_on_search_changed)
	_apply_line_edit_style(search_input)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 7)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_input)
	search_row.add_child(_build_directory_filters())
	directory.add_child(search_row)

	guild_list = VBoxContainer.new()
	guild_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guild_list.add_theme_constant_override("separation", 7)
	var guild_scroll := ScrollContainer.new()
	guild_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guild_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guild_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	guild_scroll.add_child(guild_list)
	directory.add_child(guild_scroll)

	browse_status_label = _label("", 11, UI_ACCENT)
	browse_status_label.visible = false
	browse_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	directory.add_child(browse_status_label)

	var separator := VSeparator.new()
	separator.add_theme_color_override("separator", UI_BORDER_INNER)
	body.add_child(separator)
	detail_content = VBoxContainer.new()
	detail_content.name = "GuildDetailPanel"
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.add_theme_constant_override("separation", 11)
	body.add_child(detail_content)
	return body


func _build_directory_filters() -> Control:
	var filters := HBoxContainer.new()
	filters.name = "GuildDirectoryFilters"
	directory_filter_button = Button.new()
	directory_filter_button.name = "GuildFilterButton"
	directory_filter_button.custom_minimum_size = Vector2(112, 40)
	directory_filter_button.pressed.connect(_open_directory_filters)
	filters.add_child(directory_filter_button)
	_refresh_directory_filter_button()
	return filters


func _open_directory_filters() -> void:
	if directory_filter_popup == null:
		directory_filter_popup = _build_directory_filter_dialog()
		add_child(directory_filter_popup)
	_set_directory_filter_select(directory_recruitment_select, directory_recruitment_filter)
	_set_directory_filter_select(directory_focus_select, directory_focus_filter)
	_set_directory_filter_select(directory_language_select, directory_language_filter)
	directory_filter_popup.popup_centered(DIRECTORY_FILTER_POPUP_SIZE)


func _build_directory_filter_dialog() -> PopupPanel:
	var popup := PopupPanel.new()
	popup.name = "GuildFilterDialog"
	popup.exclusive = true
	popup.unresizable = true
	_apply_guild_popup_panel_style(popup)
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 16, 18, 18)
	popup.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	content.add_child(_localized_label("ui.guild.filters.title", 19, UI_TEXT))

	directory_recruitment_select = _directory_filter_select(
		"GuildRecruitmentFilterSelect",
		[
			{"id": "all", "key": "ui.guild.filter.all"},
			{"id": "open", "key": "ui.guild.filter.open"},
		]
	)
	content.add_child(_directory_filter_field(
		"ui.guild.filters.recruitment",
		directory_recruitment_select
	))
	directory_focus_select = _directory_filter_select(
		"GuildFocusFilterSelect",
		[
			{"id": "all", "key": "ui.guild.filter.all"},
			{"id": "social", "key": "ui.guild.filter.social"},
			{"id": "pve", "key": "ui.guild.filter.pve"},
			{"id": "pvp", "key": "ui.guild.filter.pvp"},
		]
	)
	content.add_child(_directory_filter_field("ui.guild.filters.focus", directory_focus_select))
	directory_language_select = _directory_filter_select(
		"GuildLanguageFilterSelect",
		[
			{"id": "all", "key": "ui.guild.filter.all"},
			{"id": "english", "key": "ui.guild.option.language.english"},
			{"id": "spanish", "key": "ui.guild.option.language.spanish"},
			{"id": "portuguese", "key": "ui.guild.option.language.portuguese"},
			{"id": "italian", "key": "ui.guild.option.language.italian"},
			{"id": "chinese", "key": "ui.guild.option.language.chinese"},
			{"id": "german", "key": "ui.guild.option.language.german"},
			{"id": "french", "key": "ui.guild.option.language.french"},
			{"id": "dutch", "key": "ui.guild.option.language.dutch"},
			{"id": "dutch_english", "key": "ui.guild.option.language.dutch_english"},
			{"id": "other", "key": "ui.guild.option.language.other"},
		]
	)
	content.add_child(_directory_filter_field("ui.guild.filters.language", directory_language_select))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	content.add_child(actions)
	var clear_button := Button.new()
	clear_button.name = "GuildFiltersClearButton"
	_set_localized_property(clear_button, "text", "ui.guild.filters.clear")
	clear_button.pressed.connect(_clear_directory_filter_choices)
	_apply_button_style(clear_button)
	actions.add_child(clear_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var cancel_button := Button.new()
	cancel_button.name = "GuildFiltersCancelButton"
	_set_localized_property(cancel_button, "text", "common.cancel")
	cancel_button.pressed.connect(popup.hide)
	_apply_button_style(cancel_button)
	actions.add_child(cancel_button)
	var apply_button := Button.new()
	apply_button.name = "GuildFiltersApplyButton"
	_set_localized_property(apply_button, "text", "ui.guild.filters.apply")
	apply_button.pressed.connect(_apply_directory_filter_choices)
	_apply_button_style(apply_button, "primary")
	actions.add_child(apply_button)
	return popup


func _directory_filter_select(name_value: String, definitions: Array) -> OptionButton:
	var select := OptionButton.new()
	select.name = name_value
	select.custom_minimum_size = Vector2(0, 40)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.set_meta("guild_filter_definitions", definitions)
	_populate_directory_filter_select(select, "all")
	_apply_option_button_style(select)
	return select


func _directory_filter_field(label_key: String, select: OptionButton) -> Control:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	field.add_child(_localized_label(label_key, 10, UI_ACCENT))
	field.add_child(select)
	return field


func _populate_directory_filter_select(select: OptionButton, selected_id: String) -> void:
	if select == null:
		return
	var definitions := _array_from_value(select.get_meta("guild_filter_definitions", []))
	select.clear()
	for definition_value: Variant in definitions:
		var definition := _dictionary(definition_value)
		var filter_id := str(definition.get("id", "all"))
		select.add_item(_t(str(definition.get("key", "ui.guild.filter.all"))))
		select.set_item_metadata(select.item_count - 1, filter_id)
		if filter_id == selected_id:
			select.select(select.item_count - 1)


func _set_directory_filter_select(select: OptionButton, selected_id: String) -> void:
	if select == null:
		return
	for item_index: int in range(select.item_count):
		if str(select.get_item_metadata(item_index)) == selected_id:
			select.select(item_index)
			return
	select.select(0)


func _clear_directory_filter_choices() -> void:
	_set_directory_filter_select(directory_recruitment_select, "all")
	_set_directory_filter_select(directory_focus_select, "all")
	_set_directory_filter_select(directory_language_select, "all")


func _apply_directory_filter_choices() -> void:
	directory_recruitment_filter = _selected_option_value(directory_recruitment_select)
	directory_focus_filter = _selected_option_value(directory_focus_select)
	directory_language_filter = _selected_option_value(directory_language_select)
	if directory_filter_popup != null:
		directory_filter_popup.hide()
	_refresh_directory_filter_button()
	_render_guild_list()


func _refresh_directory_filter_button() -> void:
	if directory_filter_button == null:
		return
	var active_count := 0
	for filter_value: String in [
		directory_recruitment_filter,
		directory_focus_filter,
		directory_language_filter,
	]:
		if filter_value != "all":
			active_count += 1
	directory_filter_button.text = (
		_t("ui.guild.filters.button_active", {"count": active_count})
		if active_count > 0
		else _t("ui.guild.filters.button")
	)
	_apply_button_style(directory_filter_button, "primary" if active_count > 0 else "default")


func _build_member_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	member_content = VBoxContainer.new()
	member_content.name = "GuildMemberDashboard"
	member_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_content.add_theme_constant_override("separation", 12)
	scroll.add_child(member_content)
	return scroll


func _build_create_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var intro := VBoxContainer.new()
	intro.add_theme_constant_override("separation", 2)
	intro.add_child(_localized_label("ui.guild.create.title", 20, UI_TEXT))
	intro.add_child(_localized_label("ui.guild.create.subtitle", 12, UI_MUTED))
	content.add_child(intro)

	var requirements := HBoxContainer.new()
	requirements.add_theme_constant_override("separation", 10)
	content.add_child(requirements)
	var money_card := _requirement_card(
		_t("ui.guild.create.pokedollars"),
		_t("ui.guild.create.money_required"),
		_t("ui.guild.create.fee")
	)
	requirements.add_child(money_card.get("control") as Control)
	money_requirement_label = money_card.get("value") as Label
	var badge_card := _requirement_card(
		_t("ui.guild.create.badges"),
		_t("ui.guild.create.badges_required", {"count": REQUIRED_BADGES}),
		_t("ui.guild.create.progress")
	)
	requirements.add_child(badge_card.get("control") as Control)
	badge_requirement_label = badge_card.get("value") as Label

	var form_panel := PanelContainer.new()
	form_panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 10, 1))
	content.add_child(form_panel)
	var form_margin := MarginContainer.new()
	_set_margins(form_margin, 15, 14, 15, 15)
	form_panel.add_child(form_margin)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 9)
	form_margin.add_child(form)
	form.add_child(_localized_label("ui.guild.create.information", 10, UI_ACCENT))

	guild_name_input = LineEdit.new()
	guild_name_input.name = "GuildNameInput"
	_set_localized_property(guild_name_input, "placeholder_text", "ui.guild.create.name_placeholder")
	guild_name_input.max_length = 24
	guild_name_input.custom_minimum_size = Vector2(0, 40)
	guild_name_input.text_changed.connect(_on_create_form_changed)
	_apply_line_edit_style(guild_name_input)
	form.add_child(_labeled_field(
		_t("ui.guild.create.name"),
		guild_name_input,
		_t("ui.guild.create.name_hint")
	))

	guild_description_input = TextEdit.new()
	guild_description_input.name = "GuildDescriptionInput"
	_set_localized_property(
		guild_description_input,
		"placeholder_text",
		"ui.guild.create.description_placeholder"
	)
	guild_description_input.custom_minimum_size = Vector2(0, 86)
	guild_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	guild_description_input.text_changed.connect(_on_create_form_changed)
	_apply_text_edit_style(guild_description_input)
	form.add_child(_labeled_field(
		_t("ui.guild.create.description"),
		guild_description_input,
		_t("ui.guild.create.description_hint")
	))

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	form.add_child(choices)
	language_select = _option_button(GUILD_LANGUAGE_OPTIONS)
	focus_select = _option_button(["Social", "PvE", "PvP", "PvP & Social", "PvE & Social", "Mixed"])
	recruitment_select = _option_button(["Applications open", "Open", "Invite only", "Closed"])
	choices.add_child(_labeled_field(_t("ui.guild.field.language"), language_select))
	choices.add_child(_labeled_field(_t("ui.guild.field.focus"), focus_select))
	choices.add_child(_labeled_field(_t("ui.guild.field.recruitment"), recruitment_select))

	var emblem_note := PanelContainer.new()
	emblem_note.add_theme_stylebox_override("panel", _panel_style(Color("#0a2133d9"), Color("#3d759699"), 8, 1))
	form.add_child(emblem_note)
	var emblem_margin := MarginContainer.new()
	_set_margins(emblem_margin, 12, 9, 12, 9)
	emblem_note.add_child(emblem_margin)
	var emblem_label := _label(
		_t("ui.guild.create.emblem_note"),
		12,
		UI_ACCENT
	)
	emblem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	emblem_margin.add_child(emblem_label)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 9)
	content.add_child(action_row)
	create_status_label = _label("", 11, UI_MUTED)
	create_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	create_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_row.add_child(create_status_label)

	var cancel_button := Button.new()
	_set_localized_property(cancel_button, "text", "ui.guild.create.back")
	cancel_button.custom_minimum_size = Vector2(140, 40)
	cancel_button.pressed.connect(_show_page.bind("browse"))
	_apply_button_style(cancel_button)
	action_row.add_child(cancel_button)
	submit_create_button = Button.new()
	submit_create_button.name = "SubmitGuildCreationButton"
	_set_localized_property(submit_create_button, "text", "ui.guild.create.submit")
	submit_create_button.custom_minimum_size = Vector2(150, 40)
	submit_create_button.pressed.connect(_on_create_pressed)
	_apply_button_style(submit_create_button, "primary")
	action_row.add_child(submit_create_button)
	return scroll


func _render_incoming_invitations() -> void:
	if incoming_invitations_container == null:
		return
	_clear_children(incoming_invitations_container)
	incoming_invitations_container.visible = not incoming_invitations.is_empty() and membership.is_empty()
	if not incoming_invitations_container.visible:
		return
	incoming_invitations_container.add_child(
		_localized_label("ui.guild.invitations", 10, UI_GOLD)
	)
	for invitation_value: Variant in incoming_invitations:
		if not invitation_value is Dictionary:
			continue
		var invitation := invitation_value as Dictionary
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("#19170de8"), Color("#8f743dcc"), 8, 1))
		incoming_invitations_container.add_child(panel)
		var margin := MarginContainer.new()
		_set_margins(margin, 10, 8, 10, 8)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		margin.add_child(row)
		var text := _label(
			_t("ui.guild.invitation.list_entry", {
				"guild": str(invitation.get("guildName", _t("ui.guild.fallback.guild"))),
				"inviter": str(invitation.get("invitedBy", _t("common.unknown"))),
			}),
			11,
			UI_TEXT
		)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var accept_button := Button.new()
		accept_button.name = "AcceptGuildInvitationButton"
		_set_localized_property(accept_button, "text", "common.accept")
		accept_button.pressed.connect(_on_accept_invitation.bind(int(invitation.get("id", 0))))
		_apply_button_style(accept_button, "primary")
		row.add_child(accept_button)
		var decline_button := Button.new()
		decline_button.name = "DeclineGuildInvitationButton"
		_set_localized_property(decline_button, "text", "common.decline")
		decline_button.pressed.connect(_on_decline_invitation.bind(int(invitation.get("id", 0))))
		_apply_button_style(decline_button)
		row.add_child(decline_button)


func _render_guild_home() -> void:
	if member_content == null:
		return
	_clear_children(member_content)
	if guild_home.is_empty():
		member_status_label = _localized_label("ui.guild.status.loading_home", 14, UI_MUTED)
		member_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		member_content.add_child(member_status_label)
		return
	var guild := _dictionary(guild_home.get("guild", {}))
	var own_membership := _dictionary(guild_home.get("membership", {}))
	var role := str(own_membership.get("role", "member"))
	var permissions := _array_from_value(own_membership.get("permissions", []))
	var is_leader := role == "leader"
	var can_invite := permissions.has("manage_members") or role in ["leader", "captain"]
	var can_review_applications := can_invite
	var can_manage_settings := is_leader or permissions.has("manage_guild")
	if active_guild_section == "applications" and not can_review_applications:
		active_guild_section = "overview"
	if active_guild_section == "management" and not can_manage_settings:
		active_guild_section = "overview"

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	member_content.add_child(header)
	header.add_child(_build_guild_header_emblem(guild, is_leader))
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_label(str(guild.get("name", "Your Guild")), 25, UI_TEXT))
	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 9)
	heading.add_child(role_row)
	var role_label := _label(
		_t("ui.guild.membership.role", {"role": _membership_role_label(role)}),
		12,
		UI_ACCENT
	)
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_row.add_child(role_label)
	var description := _label(str(guild.get("description", "")), 12, UI_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(description)
	header.add_child(_build_guild_header_travel_actions(guild, is_leader))

	_build_guild_section_navigation(can_review_applications, can_manage_settings)
	member_status_label = _label("", 11, UI_MUTED)
	member_status_label.name = "GuildMemberStatus"
	member_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	member_content.add_child(member_status_label)
	match active_guild_section:
		"bank":
			member_content.add_child(_build_guild_bank())
		"members":
			member_content.add_child(_build_member_roster(can_invite))
		"applications":
			member_content.add_child(_build_guild_applications())
		"management":
			member_content.add_child(_build_member_management(guild, is_leader))
		_:
			member_content.add_child(_build_guild_overview(guild))

func _build_guild_header_emblem(guild: Dictionary, is_editable: bool) -> Control:
	if not is_editable:
		return _guild_emblem(guild, 88, UI_ACCENT)
	var button := Button.new()
	button.name = "EditGuildEmblemIconButton"
	_set_localized_property(button, "tooltip_text", "ui.guild.emblem.edit")
	button.custom_minimum_size = Vector2(88, 88)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_open_emblem_editor)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _panel_style(Color("#60d3ff12"), UI_ACCENT, 11, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#60d3ff24"), UI_ACCENT, 11, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	center.add_child(_guild_emblem(guild, 78, UI_ACCENT))
	return button


func _build_guild_section_navigation(can_review_applications: bool, can_manage_settings: bool) -> Control:
	var navigation := guild_section_navigation
	if navigation == null:
		return Control.new()
	_clear_children(navigation)
	guild_section_buttons.clear()
	var sections: Array[Dictionary] = [
		{"id": "overview", "label_key": "ui.guild.section.overview", "name": "GuildOverviewTab"},
		{"id": "bank", "label_key": "ui.guild.section.bank", "name": "GuildBankTab"},
		{"id": "members", "label_key": "ui.guild.section.members", "name": "GuildMembersTab"},
	]
	if can_review_applications:
		sections.append({
			"id": "applications",
			"label_key": "ui.guild.section.applications",
			"name": "GuildApplicationsTab",
		})
	if can_manage_settings:
		sections.append({
			"id": "management",
			"label_key": "ui.guild.section.management",
			"name": "GuildManagementTab",
		})
	for section: Dictionary in sections:
		var section_id := str(section.get("id", "overview"))
		var button := Button.new()
		button.name = str(section.get("name", "GuildSectionTab"))
		_set_localized_property(
			button,
			"text",
			str(section.get("label_key", "ui.guild.section.overview"))
		)
		button.custom_minimum_size = Vector2(138, 36)
		button.pressed.connect(_show_guild_section.bind(section_id))
		_apply_tab_style(button, active_page == "member" and active_guild_section == section_id)
		navigation.add_child(button)
		if section_id == "applications" and _pending_application_count() > 0:
			_add_application_notification_badge(button, _pending_application_count())
		guild_section_buttons[section_id] = button
	return navigation


func _show_guild_section(section: String) -> void:
	if section not in ["overview", "bank", "members", "applications", "management"]:
		return
	active_guild_section = section
	if section != "bank":
		active_guild_bank_category = ""
	if active_page != "member":
		_show_page("member")
	else:
		_render_guild_home()
	if section == "bank" and not is_debug_preview:
		_load_guild_bank_async.call_deferred()


func _pending_application_count() -> int:
	return _array_from_value(guild_home.get("pendingApplications", [])).size()


func _add_application_notification_badge(button: Button, count: int) -> void:
	var badge := PanelContainer.new()
	badge.name = "GuildApplicationsNotificationBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -23.0
	badge.offset_top = -5.0
	badge.offset_right = 3.0
	badge.offset_bottom = 17.0
	badge.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#d94b55"), Color("#ff9ba2"), 11, 1)
	)
	button.add_child(badge)
	var count_label := _label("99+" if count > 99 else str(count), 9, Color.WHITE)
	count_label.name = "GuildApplicationsNotificationCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count_label)


func _build_guild_header_travel_actions(guild: Dictionary, is_leader: bool) -> Control:
	var actions := VBoxContainer.new()
	actions.name = "GuildHeaderTravelActions"
	actions.add_theme_constant_override("separation", 6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var lobby_button := Button.new()
	lobby_button.name = "GuildLobbyTeleportButton"
	_set_localized_property(lobby_button, "text", "ui.guild.lobby.teleport")
	_set_localized_property(lobby_button, "tooltip_text", "ui.guild.lobby.tooltip")
	lobby_button.custom_minimum_size = Vector2(170, 36)
	lobby_button.pressed.connect(_on_guild_lobby_pressed)
	_apply_button_style(lobby_button, "primary")
	actions.add_child(lobby_button)
	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 6)
	actions.add_child(secondary_row)
	var base_button := Button.new()
	base_button.name = "GuildBaseTeleportButton"
	_set_localized_property(base_button, "text", "ui.guild.base.teleport")
	_set_localized_property(base_button, "tooltip_text", "ui.guild.base.tooltip")
	base_button.custom_minimum_size = Vector2(128, 36)
	base_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_button.disabled = true
	_apply_button_style(base_button)
	secondary_row.add_child(base_button)
	var options := MenuButton.new()
	options.name = "GuildOptionsMenuButton"
	options.text = "⋯"
	options.custom_minimum_size = Vector2(36, 36)
	_set_localized_property(options, "tooltip_text", "ui.guild.options.tooltip")
	_apply_button_style(options)
	var popup := options.get_popup()
	_apply_popup_menu_style(popup)
	popup.add_item(_t("ui.guild.leave.action"), 1)
	popup.set_item_disabled(popup.get_item_index(1), is_leader or is_leaving_guild)
	popup.id_pressed.connect(_on_guild_options_menu_pressed.bind(guild.duplicate(true)))
	secondary_row.add_child(options)
	return actions


func _on_guild_options_menu_pressed(id: int, guild: Dictionary) -> void:
	if id == 1:
		_confirm_guild_leave(guild)


func _build_guild_overview(guild: Dictionary) -> Control:
	var overview := VBoxContainer.new()
	overview.name = "GuildOverviewSection"
	overview.add_theme_constant_override("separation", 10)
	var metadata := GridContainer.new()
	metadata.columns = 4
	metadata.add_theme_constant_override("h_separation", 8)
	overview.add_child(metadata)
	metadata.add_child(_metadata_card(_t("ui.guild.field.level"), str(guild.get("level", 1)), UI_ACCENT))
	metadata.add_child(_metadata_card(
		_t("ui.guild.field.members"),
		"%d / %d" % [_array_from_value(guild_home.get("members", [])).size(), int(guild.get("capacity", 50))],
		UI_SUCCESS
	))
	metadata.add_child(_metadata_card(_t("ui.guild.field.language"), _option_display(str(guild.get("language", ""))), UI_GOLD))
	metadata.add_child(_metadata_card(_t("ui.guild.field.focus"), _option_display(str(guild.get("focus", ""))), UI_ACCENT))
	var announcement_panel := PanelContainer.new()
	announcement_panel.name = "GuildAnnouncementPanel"
	announcement_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	announcement_panel.custom_minimum_size = Vector2(0, 150)
	announcement_panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 16, 14, 16, 14)
	announcement_panel.add_child(margin)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 10)
	margin.add_child(copy)
	copy.add_child(_localized_label("ui.guild.announcement.title", 10, UI_ACCENT))
	var announcement := str(guild_home.get("announcement", "")).strip_edges()
	var announcement_label := _label(
		announcement if announcement != "" else _t("ui.guild.announcement.empty"),
		14 if announcement != "" else 12,
		UI_TEXT if announcement != "" else UI_MUTED
	)
	announcement_label.name = "GuildAnnouncementText"
	announcement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announcement_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(announcement_label)
	overview.add_child(announcement_panel)
	return overview


func _confirm_guild_leave(guild: Dictionary) -> void:
	if is_leaving_guild or str(_dictionary(guild_home.get("membership", {})).get("role", "")) == "leader":
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "GuildLeaveConfirmationDialog"
	dialog.title = _t("ui.guild.leave.confirm_title")
	dialog.dialog_text = _t("ui.guild.leave.confirm", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	})
	dialog.ok_button_text = _t("ui.guild.leave.action")
	dialog.cancel_button_text = _t("common.cancel")
	_apply_guild_confirmation_style(dialog, "danger")
	dialog.confirmed.connect(_leave_current_guild.bind(guild), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 190))


func _leave_current_guild(guild: Dictionary) -> void:
	if is_leaving_guild:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	is_leaving_guild = true
	_render_guild_home()
	_set_member_status(_t("ui.guild.leave.status"), false)
	var response: Variant = await guild_service.call("leave_guild")
	var result := _dictionary(response)
	is_leaving_guild = false
	if not bool(result.get("success", false)):
		_render_guild_home()
		_set_member_status(str(result.get("error", _t("ui.guild.leave.error"))), true)
		return
	membership.clear()
	guild_home.clear()
	guild_bank_state.clear()
	active_guild_section = "overview"
	active_guild_bank_category = ""
	_refresh_membership_state()
	_show_page("browse")
	await _refresh_from_server()
	_set_browse_status(_t("ui.guild.leave.success", {
		"guild": str(result.get("guildName", guild.get("name", _t("ui.guild.fallback.this_guild")))),
	}), false)


func _build_guild_bank() -> Control:
	if active_guild_bank_category != "":
		return _build_guild_bank_workspace()
	var panel := PanelContainer.new()
	panel.name = "GuildBankSection"
	panel.custom_minimum_size = Vector2(0, 245)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 15, 13, 15, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	title_stack.add_child(_localized_label("ui.guild.bank.title", 16, UI_TEXT))
	var description := _localized_label("ui.guild.bank.description", 11, UI_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(description)
	header.add_child(_status_pill(
		_t("ui.guild.bank.status.loading")
		if is_loading_guild_bank
		else _t("ui.guild.bank.status.ready")
	))
	var access_summary := _label(_guild_bank_access_summary(), 10, UI_ACCENT)
	access_summary.name = "GuildBankPermissionSummary"
	access_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(access_summary)
	var vaults := GridContainer.new()
	vaults.name = "GuildBankVaults"
	vaults.columns = 3
	vaults.add_theme_constant_override("h_separation", 9)
	content.add_child(vaults)
	vaults.add_child(_build_guild_bank_card(
		"GuildBankFunds",
		"ui.guild.bank.funds.title",
		_guild_bank_card_description("funds"),
		"ui.guild.bank.funds.action",
		"funds",
		UI_GOLD
	))
	vaults.add_child(_build_guild_bank_card(
		"GuildBankPokemon",
		"ui.guild.bank.pokemon.title",
		_guild_bank_card_description("pokemon"),
		"ui.guild.bank.pokemon.action",
		"pokemon",
		UI_ACCENT
	))
	vaults.add_child(_build_guild_bank_card(
		"GuildBankItems",
		"ui.guild.bank.items.title",
		_guild_bank_card_description("items"),
		"ui.guild.bank.items.action",
		"items",
		UI_SUCCESS
	))
	var hint := _localized_label("ui.guild.bank.access_hint", 10, UI_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	return panel


func _build_guild_bank_card(
	node_prefix: String,
	title_key: String,
	description_text: String,
	action_key: String,
	category: String,
	accent: Color
) -> Control:
	var panel := PanelContainer.new()
	panel.name = "%sCard" % node_prefix
	panel.custom_minimum_size = Vector2(0, 125)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), Color(accent.r, accent.g, accent.b, 0.48), 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 10, 12, 10)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	content.add_child(_localized_label(title_key, 13, accent))
	var description := _label(description_text, 10, UI_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var action := Button.new()
	action.name = "%sAction" % node_prefix
	_set_localized_property(action, "text", action_key)
	action.disabled = is_loading_guild_bank
	action.pressed.connect(_on_guild_bank_category_opened.bind(category))
	_apply_button_style(action)
	content.add_child(action)
	return panel


func _guild_bank_access_summary() -> String:
	var access := _dictionary(guild_bank_state.get("access", {}))
	var own_membership := _dictionary(guild_home.get("membership", {}))
	var permissions := _array_from_value(own_membership.get("permissions", []))
	var states: Array[String] = []
	var access_by_permission := {
		"bank_deposit": bool(access.get("canDeposit", permissions.has("bank_deposit"))),
		"bank_withdraw": bool(access.get("canWithdraw", permissions.has("bank_withdraw"))),
		"bank_borrow": bool(access.get("canBorrow", permissions.has("bank_borrow"))),
	}
	for permission: String in access_by_permission:
		states.append(_t(
			"ui.guild.bank.permission.allowed" if bool(access_by_permission[permission]) else "ui.guild.bank.permission.locked",
			{"permission": _t("ui.guild.permission.%s" % permission)}
		))
	return "  ·  ".join(states)


func _guild_bank_rank_label() -> String:
	var role := str(_dictionary(guild_home.get("membership", {})).get("role", "recruit"))
	return _membership_role_label(role)


func _guild_bank_rank_restriction(key: String) -> String:
	return _t(key, {"role": _guild_bank_rank_label()})


func _guild_bank_permission_restriction(permission: String, rank_key: String) -> String:
	if _guild_bank_permission_is_personally_denied(permission):
		return _t("ui.guild.bank.tooltip.personal_deny", {
			"permission": _t("ui.guild.permission.%s" % permission),
		})
	return _guild_bank_rank_restriction(rank_key)


func _guild_bank_permission_is_personally_denied(permission: String) -> bool:
	var access := _dictionary(guild_bank_state.get("access", {}))
	var overrides := _dictionary(access.get(
		"bankPermissionOverrides",
		_dictionary(guild_home.get("membership", {})).get("bankPermissionOverrides", {})
	))
	return str(overrides.get(permission, "")) == "deny"


func _guild_bank_borrow_tooltip(item: Dictionary = {}) -> String:
	var own_membership := _dictionary(guild_home.get("membership", {}))
	var permissions := _array_from_value(own_membership.get("permissions", []))
	if not permissions.has("bank_borrow"):
		return _guild_bank_permission_restriction("bank_borrow", "ui.guild.bank.tooltip.borrow_rank")
	if not item.is_empty() and not bool(item.get("lendable", false)):
		return _t("ui.guild.bank.tooltip.borrow_item_ineligible")
	if not item.is_empty() and int(item.get("availableQuantity", item.get("quantity", 0))) <= 0:
		return _t("ui.guild.bank.tooltip.borrow_unavailable")
	var access := _dictionary(guild_bank_state.get("access", {}))
	if not bool(access.get("lendingEnabled", false)):
		return _t("ui.guild.bank.tooltip.borrow_disabled")
	return _t("ui.guild.bank.tooltip.borrow_unavailable")


func _guild_bank_pokemon_trade_level_cap() -> int:
	var access := _dictionary(guild_bank_state.get("access", {}))
	return clampi(int(access.get("pokemonTradeLevelCap", 100)), 1, 100)


func _guild_bank_pokemon_level(pokemon: Dictionary) -> int:
	return maxi(int(pokemon.get("level", 1)), 1)


func _guild_bank_pokemon_exceeds_trade_level_cap(pokemon: Dictionary) -> bool:
	return _guild_bank_pokemon_level(pokemon) > _guild_bank_pokemon_trade_level_cap()


func _guild_bank_pokemon_level_cap_tooltip(pokemon: Dictionary) -> String:
	return _t("ui.guild.bank.tooltip.pokemon_trade_level_cap", {
		"pokemonLevel": _guild_bank_pokemon_level(pokemon),
		"tradeLevelCap": _guild_bank_pokemon_trade_level_cap(),
	})


func _guild_bank_card_description(category: String) -> String:
	match category:
		"funds":
			var funds := _dictionary(guild_bank_state.get("funds", {}))
			return _t("ui.guild.bank.funds.balance", {
				"amount": _format_number(int(funds.get("balance", 0))),
			}) if not guild_bank_state.is_empty() else _t("ui.guild.bank.funds.description")
		"pokemon":
			return _t("ui.guild.bank.pokemon.count", {
				"count": _array_from_value(guild_bank_state.get("pokemon", [])).size(),
			}) if not guild_bank_state.is_empty() else _t("ui.guild.bank.pokemon.description")
		"items":
			return _t("ui.guild.bank.items.count", {
				"count": _array_from_value(guild_bank_state.get("items", [])).size(),
			}) if not guild_bank_state.is_empty() else _t("ui.guild.bank.items.description")
	return ""


func _on_guild_bank_category_opened(category: String) -> void:
	active_guild_bank_category = category
	_render_guild_home()
	if guild_bank_state.is_empty() and not is_debug_preview:
		_load_guild_bank_async.call_deferred()


func _build_guild_bank_workspace() -> Control:
	var panel := PanelContainer.new()
	panel.name = "GuildBankWorkspace"
	panel.custom_minimum_size = Vector2(0, 310)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 15, 13, 15, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	content.add_child(header)
	var back := Button.new()
	back.name = "GuildBankBackButton"
	_set_localized_property(back, "text", "ui.guild.bank.back")
	back.pressed.connect(_on_guild_bank_back_pressed)
	_apply_button_style(back)
	header.add_child(back)
	var title_key := "ui.guild.bank.%s.title" % active_guild_bank_category
	var title := _localized_label(title_key, 17, UI_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var refresh := Button.new()
	refresh.name = "GuildBankRefreshButton"
	_set_localized_property(refresh, "text", "ui.guild.bank.refresh")
	refresh.disabled = is_loading_guild_bank or is_guild_bank_action_in_flight
	refresh.pressed.connect(_load_guild_bank_async)
	_apply_button_style(refresh)
	header.add_child(refresh)
	var log_button := Button.new()
	log_button.name = "GuildBank%sLogButton" % active_guild_bank_category.capitalize()
	_set_localized_property(log_button, "text", "ui.guild.log.view")
	log_button.pressed.connect(_open_guild_log.bind(active_guild_bank_category))
	_apply_button_style(log_button)
	header.add_child(log_button)
	if is_loading_guild_bank and guild_bank_state.is_empty():
		var loading := _localized_label("ui.guild.bank.loading", 13, UI_MUTED)
		loading.custom_minimum_size = Vector2(0, 180)
		loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(loading)
		return panel
	match active_guild_bank_category:
		"funds":
			content.add_child(_build_guild_funds_workspace())
		"pokemon":
			content.add_child(_build_guild_pokemon_workspace())
		"items":
			content.add_child(_build_guild_items_workspace())
	return panel


func _build_guild_funds_workspace() -> Control:
	var content := VBoxContainer.new()
	content.name = "GuildBankFundsWorkspace"
	content.add_theme_constant_override("separation", 10)
	var funds := _dictionary(guild_bank_state.get("funds", {}))
	var balances := GridContainer.new()
	balances.columns = 2
	balances.add_theme_constant_override("h_separation", 10)
	content.add_child(balances)
	balances.add_child(_guild_bank_value_card(
		"ui.guild.bank.funds.guild_balance",
		"$%s" % _format_number(int(funds.get("balance", 0))),
		UI_GOLD
	))
	balances.add_child(_guild_bank_value_card(
		"ui.guild.bank.funds.your_balance",
		"$%s" % _format_number(int(funds.get("playerBalance", 0))),
		UI_ACCENT
	))
	var transfer := HBoxContainer.new()
	transfer.add_theme_constant_override("separation", 8)
	content.add_child(transfer)
	var amount := SpinBox.new()
	amount.name = "GuildBankMoneyAmount"
	amount.min_value = 1
	amount.max_value = 2147483647
	amount.value = 1000
	amount.step = 1
	amount.update_on_text_changed = true
	_set_localized_property(amount, "tooltip_text", "ui.guild.bank.funds.amount_hint")
	amount.custom_minimum_size = Vector2(220, 38)
	_apply_spin_box_style(amount)
	transfer.add_child(amount)
	var access := _dictionary(guild_bank_state.get("access", {}))
	transfer.add_child(_guild_bank_action_button(
		"GuildBankMoneyDepositButton",
		"ui.guild.bank.deposit",
		bool(access.get("canDepositFunds", true)),
		_on_guild_bank_money_action.bind("deposit", amount)
	))
	transfer.add_child(_guild_bank_action_button(
		"GuildBankMoneyWithdrawButton",
		"ui.guild.bank.withdraw",
		bool(access.get("canWithdrawFunds", access.get("canWithdraw", false))),
		_on_guild_bank_money_action.bind("withdraw", amount),
		"" if bool(access.get("canWithdrawFunds", access.get("canWithdraw", false))) else _guild_bank_permission_restriction("bank_withdraw", "ui.guild.bank.tooltip.withdraw_rank")
	))
	var amount_hint := _localized_label("ui.guild.bank.funds.amount_hint", 9, UI_MUTED)
	amount_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(amount_hint)
	return content


func _build_guild_items_workspace() -> Control:
	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 10)
	var columns := GridContainer.new()
	columns.name = "GuildBankItemsWorkspace"
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 10)
	columns.add_child(_build_guild_item_list(
		"ui.guild.bank.items.stored",
		_array_from_value(guild_bank_state.get("items", [])),
		"withdraw"
	))
	columns.add_child(_build_guild_item_list(
		"ui.guild.bank.items.yours",
		_array_from_value(guild_bank_state.get("inventory", [])),
		"deposit"
	))
	workspace.add_child(columns)
	var borrowed_items := _array_from_value(guild_bank_state.get("borrowedItems", []))
	if not borrowed_items.is_empty():
		workspace.add_child(_build_guild_borrowed_item_list(borrowed_items))
	return workspace


func _build_guild_borrowed_item_list(items: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), UI_BORDER_INNER, 8, 1))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	content.add_child(_localized_label("ui.guild.bank.items.borrowed", 10, UI_ACCENT))
	for value: Variant in items:
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var row := HBoxContainer.new()
		var item_id := str(entry.get("itemId", ""))
		var snapshot := _dictionary(entry.get("snapshot", {}))
		var label := _label("%s · %s" % [
			_guild_bank_item_name(item_id, str(snapshot.get("name", item_id))),
			str(entry.get("borrowedBy", _t("common.unknown"))),
		], 11, UI_TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var asset_id := str(entry.get("loanAssetId", ""))
		if bool(entry.get("canReturn", false)):
			row.add_child(_guild_bank_action_button("GuildItemLoanReturn_%s" % asset_id, "ui.guild.bank.return", true, _on_guild_bank_loan_action.bind("return", asset_id)))
		elif bool(entry.get("canForceReturn", false)):
			row.add_child(_guild_bank_action_button("GuildItemLoanForceReturn_%s" % asset_id, "ui.guild.bank.force_return", true, _on_guild_bank_loan_action.bind("force", asset_id)))
		content.add_child(row)
	return panel


func _build_guild_item_list(title_key: String, items: Array, action: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), UI_BORDER_INNER, 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 10, 9, 10, 9)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	content.add_child(_localized_label(title_key, 10, UI_ACCENT))
	if items.is_empty():
		var empty_key := "ui.guild.bank.empty"
		if action == "deposit":
			var can_deposit := bool(_dictionary(guild_bank_state.get("access", {})).get("canDeposit", false))
			if can_deposit:
				empty_key = "ui.guild.bank.empty.items_eligible"
			elif _guild_bank_permission_is_personally_denied("bank_deposit"):
				empty_key = "ui.guild.bank.empty.deposit_personal_deny"
			else:
				empty_key = "ui.guild.bank.empty.deposit_rank"
		var empty_label := _label(
			_t(empty_key, {"role": _guild_bank_rank_label()}),
			11,
			UI_MUTED
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(empty_label)
		return panel
	for item_value: Variant in items:
		if not item_value is Dictionary:
			continue
		content.add_child(_build_guild_item_row(item_value as Dictionary, action))
	return panel


func _build_guild_item_row(item: Dictionary, action: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var item_id := str(item.get("itemId", ""))
	var item_name := _guild_bank_item_name(item_id, str(item.get("name", item_id)))
	var icon := TextureRect.new()
	icon.name = "GuildBankItemIcon_%s" % item_id
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = _guild_bank_item_icon(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var available := int(item.get("availableQuantity", item.get("quantity", 0)))
	var name := _label(
		"%s  ×%d (%d available)" % [item_name, int(item.get("quantity", 0)), available],
		11,
		UI_TEXT
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name)
	var quantity := SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = maxi(available if action != "deposit" else int(item.get("quantity", 1)), 1)
	quantity.value = 1
	quantity.custom_minimum_size = Vector2(78, 32)
	_apply_spin_box_style(quantity)
	row.add_child(quantity)
	var access := _dictionary(guild_bank_state.get("access", {}))
	var allowed := bool(access.get("canDeposit" if action == "deposit" else "canWithdraw", false))
	row.add_child(_guild_bank_action_button(
		"GuildBankItem%sButton_%s" % [action.capitalize(), str(item.get("itemId", "item"))],
		"ui.guild.bank.donate" if action == "deposit" else "ui.guild.bank.withdraw",
		allowed,
		_on_guild_bank_item_action.bind(action, str(item.get("itemId", "")), quantity),
		"" if allowed else _guild_bank_permission_restriction(
			"bank_deposit" if action == "deposit" else "bank_withdraw",
			"ui.guild.bank.tooltip.deposit_rank" if action == "deposit" else "ui.guild.bank.tooltip.withdraw_rank"
		)
	))
	if action == "withdraw":
		var can_borrow := (
			bool(access.get("lendingEnabled", false))
			and bool(access.get("canBorrow", false))
			and available > 0
			and bool(item.get("lendable", false))
		)
		row.add_child(_guild_bank_action_button(
			"GuildBankItemBorrowButton_%s" % str(item.get("itemId", "item")),
			"ui.guild.bank.borrow",
			can_borrow,
			_on_guild_bank_item_action.bind("borrow", str(item.get("itemId", "")), quantity),
			"" if can_borrow else _guild_bank_borrow_tooltip(item)
		))
	return row


func _build_guild_pokemon_workspace() -> Control:
	var columns := GridContainer.new()
	columns.name = "GuildBankPokemonWorkspace"
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 10)
	columns.add_child(_build_guild_pokemon_list(
		"ui.guild.bank.pokemon.stored",
		_array_from_value(guild_bank_state.get("pokemon", [])),
		true
	))
	columns.add_child(_build_guild_pokemon_list(
		"ui.guild.bank.pokemon.yours",
		_array_from_value(guild_bank_state.get("depositablePokemon", [])),
		false
	))
	return columns


func _build_guild_pokemon_list(title_key: String, pokemon_values: Array, is_bank: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), UI_BORDER_INNER, 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 10, 9, 10, 9)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	content.add_child(_localized_label(title_key, 10, UI_ACCENT))
	if pokemon_values.is_empty():
		var empty_key := "ui.guild.bank.empty"
		if not is_bank:
			var can_deposit := bool(_dictionary(guild_bank_state.get("access", {})).get("canDeposit", false))
			if can_deposit:
				empty_key = "ui.guild.bank.empty.pokemon_eligible"
			elif _guild_bank_permission_is_personally_denied("bank_deposit"):
				empty_key = "ui.guild.bank.empty.deposit_personal_deny"
			else:
				empty_key = "ui.guild.bank.empty.deposit_rank"
		var empty_label := _label(
			_t(empty_key, {"role": _guild_bank_rank_label()}),
			11,
			UI_MUTED
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(empty_label)
		return panel
	for pokemon_value: Variant in pokemon_values:
		if not pokemon_value is Dictionary:
			continue
		content.add_child(_build_guild_pokemon_row(pokemon_value as Dictionary, is_bank))
	return panel


func _build_guild_pokemon_row(entry: Dictionary, is_bank: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var pokemon := _dictionary(entry.get("pokemon", {}))
	var icon := TextureRect.new()
	icon.name = "GuildBankPokemonIcon_%d" % int(entry.get("pokemonId", 0))
	icon.custom_minimum_size = Vector2(44, 44)
	icon.texture = _guild_bank_pokemon_icon(pokemon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(identity)
	identity.add_child(_label(
		_t("ui.guild.bank.pokemon.identity", {
			"name": _guild_bank_pokemon_name(pokemon),
			"level": int(pokemon.get("level", 1)),
		}),
		11,
		UI_TEXT
	))
	var pokemon_id := int(entry.get("pokemonId", 0))
	if not is_bank:
		identity.add_child(_localized_label("ui.guild.bank.pokemon.ready_to_deposit", 9, UI_MUTED))
		var can_deposit := bool(_dictionary(guild_bank_state.get("access", {})).get("canDeposit", false))
		row.add_child(_guild_bank_action_button(
			"GuildBankPokemonDepositButton_%d" % pokemon_id,
			"ui.guild.bank.donate",
			can_deposit,
			_on_guild_bank_pokemon_action.bind("deposit", pokemon_id, pokemon),
			"" if can_deposit else _guild_bank_permission_restriction("bank_deposit", "ui.guild.bank.tooltip.deposit_rank")
		))
		return row
	var is_borrowed := bool(entry.get("isBorrowed", false))
	if is_borrowed:
		identity.add_child(_label(
			_t("ui.guild.bank.pokemon.borrowed_by", {"trainer": str(entry.get("borrowedBy", _t("common.unknown")))}),
			9,
			UI_WARNING
		))
		var loan_asset_id := str(entry.get("loanAssetId", ""))
		if bool(entry.get("canReturn", false)) and loan_asset_id != "":
			row.add_child(_guild_bank_action_button(
				"GuildBankPokemonReturnButton_%d" % pokemon_id,
				"ui.guild.bank.return",
				true,
				_on_guild_bank_loan_action.bind("return", loan_asset_id)
			))
		elif bool(entry.get("canReturn", false)):
			row.add_child(_guild_bank_action_button(
				"GuildBankPokemonLegacyReturnButton_%d" % pokemon_id,
				"ui.guild.bank.return",
				true,
				_on_guild_bank_pokemon_action.bind("return", pokemon_id, pokemon)
			))
		elif bool(entry.get("canForceReturn", false)) and loan_asset_id != "":
			row.add_child(_guild_bank_action_button(
				"GuildBankPokemonForceReturnButton_%d" % pokemon_id,
				"ui.guild.bank.force_return",
				true,
				_on_guild_bank_loan_action.bind("force", loan_asset_id)
			))
		return row
	identity.add_child(_label(
		_t("ui.guild.bank.pokemon.deposited_by", {"trainer": str(entry.get("depositedBy", _t("common.unknown")))}),
		9,
		UI_MUTED
	))
	var access := _dictionary(guild_bank_state.get("access", {}))
	var rank_can_withdraw := bool(access.get("canWithdraw", false))
	var exceeds_trade_level_cap := _guild_bank_pokemon_exceeds_trade_level_cap(pokemon)
	var allowed := (
		rank_can_withdraw
		and not exceeds_trade_level_cap
		and bool(entry.get("canWithdraw", true))
	)
	var withdraw_tooltip := ""
	if not rank_can_withdraw:
		withdraw_tooltip = _guild_bank_permission_restriction("bank_withdraw", "ui.guild.bank.tooltip.withdraw_rank")
	elif exceeds_trade_level_cap:
		withdraw_tooltip = _guild_bank_pokemon_level_cap_tooltip(pokemon)
	elif not allowed:
		withdraw_tooltip = _t("ui.guild.bank.tooltip.borrow_unavailable")
	row.add_child(_guild_bank_action_button(
		"GuildBankPokemonWithdrawButton_%d" % pokemon_id,
		"ui.guild.bank.withdraw",
		allowed,
		_on_guild_bank_pokemon_action.bind("withdraw", pokemon_id, pokemon),
		withdraw_tooltip
	))
	var can_borrow := (
		bool(access.get("lendingEnabled", false))
		and bool(access.get("canBorrow", false))
		and bool(entry.get("canBorrow", false))
		and not exceeds_trade_level_cap
	)
	row.add_child(_guild_bank_action_button(
		"GuildBankPokemonBorrowButton_%d" % pokemon_id,
		"ui.guild.bank.borrow",
		can_borrow,
		_on_guild_bank_pokemon_action.bind("borrow", pokemon_id, pokemon),
		"" if can_borrow else (
			_guild_bank_pokemon_level_cap_tooltip(pokemon)
			if exceeds_trade_level_cap
			else _guild_bank_borrow_tooltip()
		)
	))
	return row


func _open_guild_log(category: String) -> void:
	if category not in ["guild", "funds", "items", "pokemon"]:
		return
	var result := await _request_guild_log(category, 0)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.log.error"))), true)
		return
	_show_guild_log_window(category, result)


func _request_guild_log(category: String, before_id: int) -> Dictionary:
	var service := get_node_or_null("/root/GuildService")
	if service == null:
		return {"success": false, "error": _t("ui.guild.error.service_unavailable")}
	var response: Variant
	if category == "guild":
		response = await service.call("load_history", before_id)
	else:
		response = await service.call("load_bank_log", category, before_id)
	return _dictionary(response)


func _show_guild_log_window(category: String, result: Dictionary) -> void:
	var window := Window.new()
	window.name = "GuildHistoryLogWindow" if category == "guild" else "Guild%sLogWindow" % category.capitalize()
	window.title = _t("ui.guild.log.%s.title" % category)
	window.size = Vector2i(680, 500)
	window.min_size = Vector2i(520, 360)
	window.transient = true
	window.exclusive = true
	_apply_guild_window_style(window)
	window.close_requested.connect(window.queue_free)
	add_child(window)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 10, 1))
	window.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 16, 15, 16, 15)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	content.add_child(_localized_label("ui.guild.log.%s.heading" % category, 12, UI_ACCENT))
	var scroll := ScrollContainer.new()
	scroll.name = "GuildLogScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.name = "GuildLogEntries"
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 7)
	scroll.add_child(entries)
	var footer := HBoxContainer.new()
	footer.name = "GuildLogFooter"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(footer)
	_append_guild_log_page(category, result, entries, footer)
	window.popup_centered()


func _append_guild_log_page(category: String, result: Dictionary, entries: VBoxContainer, footer: HBoxContainer) -> void:
	for child in footer.get_children():
		child.queue_free()
	var page_entries := _array_from_value(result.get("entries", []))
	if entries.get_child_count() == 0 and page_entries.is_empty():
		entries.add_child(_localized_label("ui.guild.log.empty", 12, UI_MUTED))
	for entry_value: Variant in page_entries:
		if entry_value is Dictionary:
			entries.add_child(_build_guild_log_entry(category, entry_value as Dictionary))
	var next_before_id := int(result.get("nextBeforeId", 0))
	if next_before_id > 0:
		var more := Button.new()
		more.name = "GuildLogLoadMoreButton"
		_set_localized_property(more, "text", "ui.guild.log.load_more")
		more.pressed.connect(_load_more_guild_log.bind(category, next_before_id, entries, footer))
		_apply_button_style(more)
		footer.add_child(more)


func _load_more_guild_log(category: String, before_id: int, entries: VBoxContainer, footer: HBoxContainer) -> void:
	for child in footer.get_children():
		child.queue_free()
	var result := await _request_guild_log(category, before_id)
	if not bool(result.get("success", false)):
		footer.add_child(_localized_label("ui.guild.log.error", 11, UI_WARNING))
		return
	_append_guild_log_page(category, result, entries, footer)


func _build_guild_log_entry(category: String, entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), UI_BORDER_INNER, 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 10, 8, 10, 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	if category == "items":
		var item := _dictionary(entry.get("item", {}))
		row.add_child(_guild_log_icon(_guild_bank_item_icon(str(item.get("itemId", entry.get("assetReference", ""))))))
	elif category == "pokemon":
		row.add_child(_guild_log_icon(_guild_bank_pokemon_icon(_dictionary(entry.get("pokemon", {})))))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(_label(_guild_log_entry_text(category, entry), 12, UI_TEXT))
	var created_at := str(entry.get("createdAt", ""))
	copy.add_child(_label(_relative_last_seen_text(created_at), 10, UI_MUTED))
	return card


func _guild_log_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func _guild_log_entry_text(category: String, entry: Dictionary) -> String:
	var action := str(entry.get("action", "deposit"))
	if category == "guild":
		if action == "joined":
			return _t("ui.guild.log.guild.joined", {
				"trainer": str(entry.get("target", _t("common.unknown"))),
				"rank": _t("ui.guild.role.%s" % str(entry.get("newRole", "recruit"))),
			})
		if action == "left":
			return _t("ui.guild.log.guild.left", {"trainer": str(entry.get("target", _t("common.unknown")))})
		if action == "rank_changed":
			return _t("ui.guild.log.guild.rank_changed", {
				"actor": str(entry.get("actor", _t("common.unknown"))),
				"trainer": str(entry.get("target", _t("common.unknown"))),
				"old_rank": _t("ui.guild.role.%s" % str(entry.get("previousRole", "recruit"))),
				"new_rank": _t("ui.guild.role.%s" % str(entry.get("newRole", "recruit"))),
			})
		if action == "bank_permission_changed":
			return _t("ui.guild.log.guild.bank_permission_changed", {
				"actor": str(entry.get("actor", _t("common.unknown"))),
				"trainer": str(entry.get("target", _t("common.unknown"))),
			})
		return _t("ui.guild.log.guild.generic", {"trainer": str(entry.get("target", _t("common.unknown")))})
	var actor := str(entry.get("actor", _t("common.unknown")))
	var action_group := "funds" if category == "funds" else "asset"
	var action_text := _t("ui.guild.log.action.%s.%s" % [action_group, action])
	if category == "funds":
		return _t("ui.guild.log.funds.entry", {
			"trainer": actor,
			"action": action_text,
			"amount": _format_number(int(entry.get("amount", 0))),
		})
	if category == "items":
		var item := _dictionary(entry.get("item", {}))
		return _t("ui.guild.log.items.entry", {
			"trainer": actor,
			"action": action_text,
			"item": _guild_bank_item_name(str(item.get("itemId", "")), str(item.get("name", entry.get("assetReference", "")))),
			"amount": int(entry.get("amount", 1)),
		})
	var pokemon := _dictionary(entry.get("pokemon", {}))
	return _t("ui.guild.log.pokemon.entry", {
		"trainer": actor,
		"action": action_text,
		"pokemon": _guild_bank_pokemon_name(pokemon),
	})


func _guild_bank_value_card(title_key: String, value: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07131ff2"), Color(accent.r, accent.g, accent.b, 0.5), 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 9, 12, 9)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	content.add_child(_localized_label(title_key, 9, UI_MUTED))
	content.add_child(_label(value, 18, accent))
	return panel


func _guild_bank_action_button(
	node_name: String,
	text_key: String,
	allowed: bool,
	callback: Callable,
	tooltip_text: String = ""
) -> Button:
	var button := Button.new()
	button.name = node_name
	_set_localized_property(button, "text", text_key)
	button.custom_minimum_size = Vector2(92, 32)
	button.disabled = not allowed or is_guild_bank_action_in_flight
	button.tooltip_text = tooltip_text
	button.pressed.connect(callback)
	_apply_button_style(button, "primary")
	return button


func _on_guild_bank_back_pressed() -> void:
	active_guild_bank_category = ""
	_render_guild_home()


func _load_guild_bank_async() -> void:
	if is_loading_guild_bank or is_guild_bank_action_in_flight or is_debug_preview:
		return
	is_loading_guild_bank = true
	_render_guild_home()
	var service := get_node_or_null("/root/GuildService")
	var response: Variant = await service.call("load_bank") if service != null else {
		"success": false, "error": _t("ui.guild.error.service_unavailable"),
	}
	is_loading_guild_bank = false
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_render_guild_home_with_status(
			str(result.get("error", _t("ui.guild.bank.error.load"))),
			true
		)
		return
	_apply_guild_bank_result(result)
	_render_guild_home()


func _on_guild_bank_money_action(action: String, amount_input: SpinBox) -> void:
	var amount := int(amount_input.value) if amount_input != null else 0
	if amount <= 0:
		return
	if action == "deposit":
		_confirm_guild_bank_donation(
			"$%s" % _format_number(amount),
			_run_guild_bank_action.bind("deposit_bank_money", [amount], "money")
		)
		return
	await _run_guild_bank_action("%s_bank_money" % action, [amount], "money")


func _on_guild_bank_item_action(action: String, item_id: String, quantity_input: SpinBox) -> void:
	var quantity := int(quantity_input.value) if quantity_input != null else 0
	if item_id == "" or quantity <= 0:
		return
	if action == "deposit":
		_confirm_guild_bank_donation(
			"%s ×%d" % [_guild_bank_item_name(item_id, item_id), quantity],
			_run_guild_bank_action.bind("deposit_bank_item", [item_id, quantity], "item")
		)
		return
	await _run_guild_bank_action("%s_bank_item" % action, [item_id, quantity], "item")


func _on_guild_bank_pokemon_action(action: String, pokemon_id: int, pokemon: Dictionary = {}) -> void:
	if pokemon_id <= 0:
		return
	if action == "deposit":
		_confirm_guild_bank_donation(
			_guild_bank_pokemon_name(pokemon),
			_run_guild_bank_action.bind("deposit_bank_pokemon", [pokemon_id], "pokemon")
		)
		return
	var service_method := "deposit_bank_pokemon" if action == "return" else "%s_bank_pokemon" % action
	await _run_guild_bank_action(service_method, [pokemon_id], "pokemon")


func _on_guild_bank_loan_action(action: String, asset_id: String) -> void:
	if asset_id.strip_edges() == "":
		return
	var method := "force_return_bank_loan_asset" if action == "force" else "return_bank_loan_asset"
	await _run_guild_bank_action(method, [asset_id], "loan")


func _confirm_guild_bank_donation(asset_name: String, confirmed_action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "GuildBankDonationConfirmationDialog"
	dialog.title = _t("ui.guild.bank.donation.confirm_title")
	dialog.dialog_text = _t("ui.guild.bank.donation.confirm", {"asset": asset_name})
	dialog.ok_button_text = _t("ui.guild.bank.donation.action")
	dialog.cancel_button_text = _t("common.cancel")
	_apply_guild_confirmation_style(dialog, "primary")
	dialog.confirmed.connect(confirmed_action, CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	add_child(dialog)
	dialog.popup_centered(Vector2i(470, 190))


func _run_guild_bank_action(method: String, arguments: Array, asset_type: String) -> void:
	if is_guild_bank_action_in_flight:
		return
	is_guild_bank_action_in_flight = true
	_render_guild_home()
	var service := get_node_or_null("/root/GuildService")
	var response: Variant = await service.callv(method, arguments) if service != null else {
		"success": false, "error": _t("ui.guild.error.service_unavailable"),
	}
	is_guild_bank_action_in_flight = false
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_render_guild_home_with_status(
			str(result.get("error", _t("ui.guild.bank.error.action"))),
			true
		)
		return
	_apply_guild_bank_result(result)
	if asset_type == "money":
		var wallet_service := get_node_or_null("/root/PlayerWalletService")
		if wallet_service != null:
			var wallet_result: Variant = await wallet_service.call("load_wallet")
			if wallet_result is Dictionary:
				wallet_service.call("apply_wallet_result", wallet_result)
	elif asset_type == "item":
		var inventory_service := get_node_or_null("/root/InventoryService")
		if inventory_service != null:
			await inventory_service.call("load_inventory")
	_render_guild_home_with_status(_t("ui.guild.bank.status.updated"), false)


func _apply_guild_bank_result(result: Dictionary) -> void:
	guild_bank_state = result.duplicate(true)
	var party_value: Variant = result.get("party", [])
	if party_value is Array:
		var player_save := get_node_or_null("/root/PlayerSave")
		if player_save != null and player_save.has_method("replace_party_from_state"):
			is_applying_guild_bank_party = true
			player_save.call("replace_party_from_state", party_value)
			is_applying_guild_bank_party = false


func _on_player_party_changed() -> void:
	if (
		is_applying_guild_bank_party
		or not visible
		or is_debug_preview
		or active_guild_section != "bank"
		or active_guild_bank_category != "pokemon"
		or is_loading_guild_bank
		or is_guild_bank_action_in_flight
	):
		return
	_load_guild_bank_async.call_deferred()


func _guild_bank_pokemon_name(pokemon: Dictionary) -> String:
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	if nickname != "":
		return nickname
	return str(pokemon.get("name", pokemon.get("speciesName", "Pokemon")))


func _guild_bank_item_icon(item_id: String) -> Texture2D:
	var normalized := item_id.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	for path: String in [
		"res://assets/items/icons/%s.png" % normalized,
		"res://assets/items/icons/%s.png" % item_id.strip_edges(),
		"res://assets/items/icons/000.png",
	]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


func _guild_bank_pokemon_icon(pokemon: Dictionary) -> Texture2D:
	var species := str(pokemon.get("speciesName", pokemon.get("species", pokemon.get("name", ""))))
	var shiny := bool(pokemon.get("shiny", pokemon.get("isShiny", false)))
	var texture := PokemonAssets.load_party_icon(species, shiny)
	if texture == null:
		texture = PokemonAssets.load_home_sprite(species, shiny)
	return texture if texture != null else PokemonAssets.load_unknown_icon()


func _guild_bank_item_name(item_id: String, fallback: String) -> String:
	var localization := get_node_or_null("/root/ItemLocalization")
	if localization != null and localization.has_method("display_name"):
		return str(localization.call("display_name", item_id, fallback))
	return fallback


func _on_guild_lobby_pressed() -> void:
	lobby_teleport_requested.emit()


func _build_member_roster(can_invite: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.name = "GuildMembersSection"
	panel.custom_minimum_size = Vector2(330, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 13, 12, 13, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var members := _array_from_value(guild_home.get("members", []))
	var online_count := 0
	for member_value: Variant in members:
		if member_value is Dictionary and bool((member_value as Dictionary).get("online", false)):
			online_count += 1
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 10)
	content.add_child(heading_row)
	var roster_heading := _localized_label("ui.guild.roster", 10, UI_ACCENT)
	roster_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(roster_heading)
	var history_button := Button.new()
	history_button.name = "GuildHistoryLogButton"
	_set_localized_property(history_button, "text", "ui.guild.log.history.view")
	history_button.pressed.connect(_open_guild_log.bind("guild"))
	_apply_button_style(history_button)
	heading_row.add_child(history_button)
	heading_row.add_child(_label(
		_t("ui.guild.roster.summary", {"online": online_count, "total": members.size()}),
		10,
		UI_MUTED
	))
	content.add_child(_build_guild_roster_toolbar(can_invite))
	if can_invite:
		_render_pending_invitations(content)
	var own_role := str(_dictionary(guild_home.get("membership", {})).get("role", "recruit"))
	var own_membership := _dictionary(guild_home.get("membership", {}))
	var own_user_id := int(own_membership.get("userId", 0))
	var can_manage_permissions := _array_from_value(own_membership.get("permissions", [])).has("manage_permissions")
	member_cards_container = VBoxContainer.new()
	member_cards_container.name = "GuildMemberCards"
	member_cards_container.add_theme_constant_override("separation", 7)
	content.add_child(member_cards_container)
	for member_value: Variant in members:
		if not member_value is Dictionary:
			continue
		var member := member_value as Dictionary
		member_cards_container.add_child(_build_guild_member_card(member, own_role, own_user_id, can_manage_permissions))
	return panel


func _build_guild_roster_toolbar(can_invite: bool) -> Control:
	var toolbar := HBoxContainer.new()
	toolbar.name = "GuildMemberRosterToolbar"
	toolbar.add_theme_constant_override("separation", 8)
	member_search_input = LineEdit.new()
	member_search_input.name = "GuildMemberSearchInput"
	_set_localized_property(
		member_search_input,
		"placeholder_text",
		"ui.guild.roster.search"
	)
	member_search_input.clear_button_enabled = true
	member_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_search_input.text_changed.connect(_filter_guild_member_cards)
	_apply_line_edit_style(member_search_input)
	toolbar.add_child(member_search_input)
	if not can_invite:
		return toolbar
	var invite_button := Button.new()
	invite_button.name = "OpenGuildInviteDialogButton"
	_set_localized_property(invite_button, "text", "ui.guild.invite.send")
	invite_button.pressed.connect(_open_guild_invite_dialog)
	_apply_button_style(invite_button, "primary")
	toolbar.add_child(invite_button)
	return toolbar


func _filter_guild_member_cards(query: String) -> void:
	if member_cards_container == null:
		return
	var normalized := query.strip_edges().to_lower()
	for child: Node in member_cards_container.get_children():
		if child is Control:
			var haystack := str(child.get_meta("member_search_text", ""))
			(child as Control).visible = normalized == "" or haystack.contains(normalized)


func _open_guild_invite_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "GuildInviteDialog"
	dialog.title = _t("ui.guild.invite.title")
	dialog.ok_button_text = _t("ui.guild.invite.send")
	dialog.cancel_button_text = _t("common.cancel")
	_apply_guild_confirmation_style(dialog, "primary")
	add_child(dialog)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_top = 48
	content.offset_right = -18
	content.offset_bottom = -62
	content.add_theme_constant_override("separation", 8)
	dialog.add_child(content)
	content.add_child(_localized_label("ui.guild.invite.prompt", 11, UI_MUTED))
	invite_username_input = LineEdit.new()
	invite_username_input.name = "GuildInviteUsername"
	_set_localized_property(invite_username_input, "placeholder_text", "ui.guild.invite.username")
	invite_username_input.clear_button_enabled = true
	_apply_line_edit_style(invite_username_input)
	content.add_child(invite_username_input)
	dialog.confirmed.connect(_on_invite_member.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(460, 210))
	invite_username_input.grab_focus.call_deferred()


func _build_guild_member_card(
	member: Dictionary,
	own_role: String,
	own_user_id: int,
	can_manage_permissions: bool = false
) -> Control:
	var user_id := int(member.get("userId", 0))
	var online := bool(member.get("online", false))
	var card := PanelContainer.new()
	card.name = "GuildMemberCard_%d" % user_id
	card.set_meta("member_search_text", "%s %s" % [
		str(member.get("displayName", "")).to_lower(),
		str(member.get("username", "")).to_lower(),
	])
	card.custom_minimum_size = Vector2(0, 70)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#081827f2"), UI_ACCENT_SOFT if online else UI_BORDER_INNER, 8, 1)
	)
	var margin := MarginContainer.new()
	_set_margins(margin, 12, 9, 10, 9)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var presence_dot := _label("●", 15, UI_SUCCESS if online else UI_MUTED)
	presence_dot.name = "GuildMemberPresenceDot_%d" % user_id
	presence_dot.custom_minimum_size = Vector2(18, 0)
	presence_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(presence_dot)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(225, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	row.add_child(identity)
	var display_name := str(member.get("displayName", member.get("username", _t("common.unknown"))))
	var name_label := _label(display_name, 14, UI_TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(name_label)
	var username := str(member.get("username", "")).strip_edges()
	identity.add_child(_label("@%s" % username if username != "" else "", 10, UI_ACCENT))

	var presence := VBoxContainer.new()
	presence.custom_minimum_size = Vector2(210, 0)
	presence.add_theme_constant_override("separation", 3)
	row.add_child(presence)
	presence.add_child(_localized_label("ui.guild.member.status", 9, UI_MUTED))
	var presence_label := _label(_guild_member_presence_text(member), 11, UI_SUCCESS if online else UI_MUTED)
	presence_label.name = "GuildMemberPresenceLabel_%d" % user_id
	presence_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	presence.add_child(presence_label)

	var rank := VBoxContainer.new()
	rank.custom_minimum_size = Vector2(145, 0)
	rank.add_theme_constant_override("separation", 3)
	row.add_child(rank)
	rank.add_child(_localized_label("ui.guild.member.rank", 9, UI_MUTED))
	var member_role := str(member.get("role", "recruit"))
	if own_role == "leader" and member_role != "leader":
		rank.add_child(_guild_member_role_select(user_id, member_role))
	else:
		var role_label := _label(_membership_role_label(member_role).to_upper(), 10, UI_GOLD)
		role_label.name = "GuildMemberRankLabel_%d" % user_id
		rank.add_child(role_label)
	var overrides := _dictionary(member.get("bankPermissionOverrides", {}))
	if not overrides.is_empty():
		var override_label := _label(
			_t("ui.guild.permissions.custom_count", {"count": overrides.size()}),
			9,
			UI_ACCENT
		)
		override_label.name = "GuildMemberPermissionOverrideCount_%d" % user_id
		rank.add_child(override_label)

	if can_manage_permissions and member_role != "leader":
		var permissions_button := Button.new()
		permissions_button.name = "GuildMemberBankPermissionsButton_%d" % user_id
		permissions_button.custom_minimum_size = Vector2(118, 36)
		_set_localized_property(permissions_button, "text", "ui.guild.permissions.action")
		_set_localized_property(permissions_button, "tooltip_text", "ui.guild.permissions.action_tooltip")
		permissions_button.pressed.connect(_open_guild_member_bank_permissions.bind(member.duplicate(true)))
		_apply_button_style(permissions_button)
		row.add_child(permissions_button)

	var message_button := Button.new()
	message_button.name = "GuildMemberPmButton_%d" % user_id
	message_button.custom_minimum_size = Vector2(92, 36)
	message_button.disabled = user_id == own_user_id or not online
	_set_localized_property(
		message_button,
		"text",
		"ui.guild.member.you" if user_id == own_user_id else "ui.guild.member.message"
	)
	_set_localized_property(
		message_button,
		"tooltip_text",
		"ui.guild.member.message_self"
		if user_id == own_user_id
		else ("ui.guild.member.message_tooltip" if online else "ui.guild.member.message_offline")
	)
	message_button.pressed.connect(_on_guild_member_private_message_pressed.bind(member.duplicate(true)))
	_apply_button_style(message_button, "primary")
	row.add_child(message_button)
	return card


func _on_guild_member_private_message_pressed(member: Dictionary) -> void:
	if not bool(member.get("online", false)):
		return
	private_message_requested.emit({
		"id": int(member.get("userId", 0)),
		"userId": int(member.get("userId", 0)),
		"username": str(member.get("username", "")),
		"displayName": str(member.get("displayName", member.get("username", ""))),
		"online": true,
	})


func _guild_member_presence_text(member: Dictionary) -> String:
	if bool(member.get("online", false)):
		return _t("ui.guild.member.online")
	var last_seen_at := str(member.get("lastSeenAt", "")).strip_edges()
	if last_seen_at == "":
		return _t("ui.guild.member.offline")
	return _t("ui.guild.member.last_seen", {"time": _relative_last_seen_text(last_seen_at)})


func _relative_last_seen_text(last_seen_at: String) -> String:
	var last_seen_unix := _unix_from_iso_datetime(last_seen_at)
	if last_seen_unix <= 0.0:
		return _t("ui.guild.member.offline").to_lower()
	var elapsed_seconds := maxi(0, int(Time.get_unix_time_from_system() - last_seen_unix))
	if elapsed_seconds < 60:
		return _t("ui.friends.time.just_now")
	if elapsed_seconds < 3600:
		return _t("ui.friends.time.minutes_ago", {"count": int(elapsed_seconds / 60)})
	if elapsed_seconds < 86400:
		return _t("ui.friends.time.hours_ago", {"count": int(elapsed_seconds / 3600)})
	if elapsed_seconds < 172800:
		return _t("ui.friends.time.yesterday")
	if elapsed_seconds < 604800:
		return _t("ui.friends.time.days_ago", {"count": int(elapsed_seconds / 86400)})
	var datetime := Time.get_datetime_dict_from_unix_time(int(last_seen_unix))
	var month := int(datetime.get("month", 0))
	var day := int(datetime.get("day", 0))
	var year := int(datetime.get("year", 0))
	if month < 1 or month > 12 or day < 1:
		return _t("ui.guild.member.offline").to_lower()
	var month_name := _t("ui.friends.month.%02d" % month)
	if year == int(Time.get_datetime_dict_from_system().get("year", 0)):
		return "%s %s" % [month_name, day]
	return "%s %s, %s" % [month_name, day, year]


func _unix_from_iso_datetime(value: String) -> float:
	var datetime_text := value.strip_edges()
	if datetime_text == "":
		return 0.0
	if datetime_text.ends_with("Z"):
		datetime_text = datetime_text.substr(0, datetime_text.length() - 1)
	var plus_index := datetime_text.find("+", 10)
	if plus_index >= 0:
		datetime_text = datetime_text.substr(0, plus_index)
	else:
		var minus_index := datetime_text.find("-", 10)
		if minus_index >= 0:
			datetime_text = datetime_text.substr(0, minus_index)
	var dot_index := datetime_text.find(".")
	if dot_index >= 0:
		datetime_text = datetime_text.substr(0, dot_index)
	return float(Time.get_unix_time_from_datetime_string(datetime_text))


func _guild_member_role_select(user_id: int, current_role: String) -> OptionButton:
	var select := OptionButton.new()
	select.name = "GuildMemberRoleSelect_%d" % user_id
	select.custom_minimum_size = Vector2(125, 30)
	for role: String in GUILD_ASSIGNABLE_ROLES:
		select.add_item(_membership_role_label(role))
		select.set_item_metadata(select.item_count - 1, role)
		if role == current_role:
			select.select(select.item_count - 1)
	_apply_option_button_style(select)
	select.item_selected.connect(_on_guild_member_role_selected.bind(user_id, select))
	return select


func _open_guild_member_bank_permissions(member: Dictionary) -> void:
	var user_id := int(member.get("userId", 0))
	if user_id <= 0 or str(member.get("role", "recruit")) == "leader":
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "GuildMemberBankPermissionsDialog_%d" % user_id
	dialog.title = _t("ui.guild.permissions.title", {
		"trainer": str(member.get("displayName", member.get("username", _t("common.unknown")))),
	})
	dialog.ok_button_text = _t("common.save")
	dialog.cancel_button_text = _t("common.cancel")
	_apply_guild_confirmation_style(dialog, "primary")
	add_child(dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18
	content.offset_top = 48
	content.offset_right = -18
	content.offset_bottom = -62
	dialog.add_child(content)
	var explanation := _localized_label("ui.guild.permissions.hint", 11, UI_MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)
	var overrides := _dictionary(member.get("bankPermissionOverrides", {}))
	var rank_permissions := _array_from_value(member.get("rankPermissions", []))
	var selects: Dictionary = {}
	for permission: String in GUILD_BANK_PERMISSIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		content.add_child(row)
		var permission_label := _label(_t("ui.guild.permission.%s" % permission), 11, UI_TEXT)
		permission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(permission_label)
		var select := OptionButton.new()
		select.name = "GuildBankPermissionSelect_%s" % permission
		select.custom_minimum_size = Vector2(230, 32)
		select.add_item(_t(
			"ui.guild.permissions.inherit_allowed" if rank_permissions.has(permission) else "ui.guild.permissions.inherit_denied"
		))
		select.set_item_metadata(0, "inherit")
		select.add_item(_t("ui.guild.permissions.allow"))
		select.set_item_metadata(1, "allow")
		select.add_item(_t("ui.guild.permissions.deny"))
		select.set_item_metadata(2, "deny")
		var current_mode := str(overrides.get(permission, "inherit"))
		select.select(1 if current_mode == "allow" else (2 if current_mode == "deny" else 0))
		_apply_option_button_style(select)
		row.add_child(select)
		selects[permission] = select
	dialog.confirmed.connect(_save_guild_member_bank_permissions.bind(user_id, selects, dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 330))


func _save_guild_member_bank_permissions(
	user_id: int,
	selects: Dictionary,
	dialog: ConfirmationDialog
) -> void:
	var overrides: Dictionary = {}
	for permission: String in GUILD_BANK_PERMISSIONS:
		var select := selects.get(permission) as OptionButton
		if select != null and select.selected >= 0:
			overrides[permission] = str(select.get_item_metadata(select.selected))
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		if is_instance_valid(dialog):
			dialog.queue_free()
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var response: Variant = await guild_service.call("update_member_bank_permissions", user_id, overrides)
	var result := _dictionary(response)
	if is_instance_valid(dialog):
		dialog.queue_free()
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.permissions.error"))), true)
		return
	_apply_home_result(result)
	_set_member_status(_t("ui.guild.permissions.updated"), false)


func _guild_loan_duration_label(seconds: int) -> String:
	return _t("ui.guild.bank.loan_duration.hours", {"hours": seconds / 3600})


func _select_guild_loan_duration(seconds: int) -> void:
	if settings_loan_duration_select == null:
		return
	for index: int in range(settings_loan_duration_select.item_count):
		if int(settings_loan_duration_select.get_item_metadata(index)) == seconds:
			settings_loan_duration_select.select(index)
			return


func _selected_guild_loan_duration() -> int:
	if settings_loan_duration_select == null or settings_loan_duration_select.selected < 0:
		return 86400
	return int(settings_loan_duration_select.get_item_metadata(settings_loan_duration_select.selected))


func _on_guild_member_role_selected(index: int, user_id: int, select: OptionButton) -> void:
	if select == null or index < 0 or index >= select.item_count:
		return
	var role := str(select.get_item_metadata(index))
	select.disabled = true
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		select.disabled = false
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var response: Variant = await guild_service.call("update_member_role", user_id, role)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		select.disabled = false
		_set_member_status(str(result.get("error", _t("ui.guild.error.update_role"))), true)
		return
	_apply_home_result(result)
	_set_member_status(_t("ui.guild.status.role_updated"), false)


func _build_member_management(guild: Dictionary, is_leader: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "GuildManagementSection"
	panel.custom_minimum_size = Vector2(610, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 13, 12, 13, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	if is_leader:
		content.add_child(_localized_label("ui.guild.settings", 10, UI_ACCENT))
		content.add_child(_localized_label("ui.guild.settings.description", 9, UI_MUTED))
		settings_description_input = TextEdit.new()
		settings_description_input.name = "GuildSettingsDescription"
		settings_description_input.text = str(guild.get("description", ""))
		settings_description_input.custom_minimum_size = Vector2(0, 58)
		settings_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_apply_text_edit_style(settings_description_input)
		content.add_child(settings_description_input)
		content.add_child(_localized_label("ui.guild.announcement.manage", 9, UI_MUTED))
		settings_announcement_input = TextEdit.new()
		settings_announcement_input.name = "GuildSettingsAnnouncement"
		settings_announcement_input.text = str(guild_home.get("announcement", ""))
		settings_announcement_input.custom_minimum_size = Vector2(0, 70)
		settings_announcement_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		_apply_text_edit_style(settings_announcement_input)
		content.add_child(settings_announcement_input)
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 7)
		content.add_child(choices)
		settings_language_select = _option_button(GUILD_LANGUAGE_OPTIONS)
		settings_focus_select = _option_button(["Social", "PvE", "PvP", "PvP & Social", "PvE & Social", "Mixed"])
		settings_recruitment_select = _option_button(["Applications open", "Open", "Invite only", "Closed"])
		settings_loan_duration_select = OptionButton.new()
		for duration: int in [3600, 10800, 21600, 43200, 86400, 172800, 259200]:
			settings_loan_duration_select.add_item(_guild_loan_duration_label(duration))
			settings_loan_duration_select.set_item_metadata(settings_loan_duration_select.item_count - 1, duration)
		_apply_option_button_style(settings_loan_duration_select)
		_select_option_text(settings_language_select, str(guild.get("language", "English")))
		_select_option_text(settings_focus_select, str(guild.get("focus", "Social")))
		_select_option_text(settings_recruitment_select, str(guild.get("recruitment", "Applications open")))
		_select_guild_loan_duration(int(guild.get("loanDurationSeconds", 86400)))
		choices.add_child(settings_language_select)
		choices.add_child(settings_focus_select)
		choices.add_child(settings_recruitment_select)
		choices.add_child(settings_loan_duration_select)
		var save_settings := Button.new()
		_set_localized_property(save_settings, "text", "ui.guild.settings.save")
		save_settings.pressed.connect(_on_save_settings)
		_apply_button_style(save_settings, "primary")
		content.add_child(save_settings)

	if not is_leader:
		content.add_child(_localized_label("ui.guild.management.restricted", 12, UI_MUTED))
	return panel


func _build_guild_applications() -> Control:
	var panel := PanelContainer.new()
	panel.name = "GuildApplicationsSection"
	panel.custom_minimum_size = Vector2(610, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 13, 12, 13, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	_render_pending_applications(content)
	return panel


func _open_emblem_editor() -> void:
	var guild := _dictionary(guild_home.get("guild", {}))
	_load_emblem_editor(_dictionary(guild.get("emblem", {})))
	if emblem_editor_popup == null:
		emblem_editor_popup = _build_emblem_editor_popup()
		add_child(emblem_editor_popup)
	else:
		_refresh_emblem_grid()
		_refresh_emblem_palette_controls()
	_refresh_emblem_template_controls()
	emblem_editor_popup.popup_centered(EMBLEM_EDITOR_POPUP_SIZE)


func _build_emblem_editor_popup() -> PopupPanel:
	var popup := PopupPanel.new()
	popup.name = "GuildEmblemEditorPopup"
	popup.exclusive = true
	popup.unresizable = true
	_apply_guild_popup_panel_style(popup)
	var margin := MarginContainer.new()
	_set_margins(margin, 16, 14, 16, 16)
	popup.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _localized_label("ui.guild.emblem.title", 19, UI_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseGuildEmblemEditorButton"
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "ui.guild.emblem.cancel_tooltip")
	close_button.custom_minimum_size = Vector2(36, 34)
	close_button.pressed.connect(_cancel_emblem_edit)
	_apply_button_style(close_button)
	header.add_child(close_button)
	content.add_child(_localized_label("ui.guild.emblem.instructions", 11, UI_MUTED))
	content.add_child(_build_emblem_editor())
	return popup


func _build_emblem_editor() -> Control:
	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 12)
	emblem_grid = GridContainer.new()
	emblem_grid.name = "GuildEmblemGrid"
	emblem_grid.columns = GUILD_EMBLEM_SIZE
	emblem_grid.add_theme_constant_override("h_separation", 1)
	emblem_grid.add_theme_constant_override("v_separation", 1)
	editor.add_child(emblem_grid)
	emblem_pixel_buttons.clear()
	for pixel_index: int in range(GUILD_EMBLEM_PIXEL_COUNT):
		var pixel := Button.new()
		pixel.custom_minimum_size = Vector2(EMBLEM_EDITOR_PIXEL_SIZE, EMBLEM_EDITOR_PIXEL_SIZE)
		pixel.focus_mode = Control.FOCUS_NONE
		pixel.pressed.connect(_on_emblem_pixel_pressed.bind(pixel_index))
		emblem_grid.add_child(pixel)
		emblem_pixel_buttons.append(pixel)
	var tools := VBoxContainer.new()
	tools.custom_minimum_size = Vector2(185, 0)
	tools.add_theme_constant_override("separation", 5)
	editor.add_child(tools)
	tools.add_child(_localized_label("ui.guild.emblem.templates", 9, UI_MUTED))
	emblem_template_select = OptionButton.new()
	emblem_template_select.name = "GuildSavedEmblemSelect"
	emblem_template_select.fit_to_longest_item = false
	emblem_template_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_option_button_style(emblem_template_select)
	tools.add_child(emblem_template_select)
	apply_emblem_template_button = Button.new()
	apply_emblem_template_button.name = "ApplySavedGuildEmblemButton"
	_set_localized_property(
		apply_emblem_template_button,
		"text",
		"ui.guild.emblem.apply_template"
	)
	apply_emblem_template_button.pressed.connect(_on_apply_saved_emblem_template)
	_apply_button_style(apply_emblem_template_button, "primary")
	tools.add_child(apply_emblem_template_button)
	_refresh_emblem_template_controls()
	tools.add_child(_localized_label("ui.guild.emblem.palette", 9, UI_MUTED))
	emblem_palette_grid = GridContainer.new()
	emblem_palette_grid.name = "GuildEmblemPaletteGrid"
	emblem_palette_grid.columns = 2
	emblem_palette_grid.add_theme_constant_override("h_separation", 5)
	emblem_palette_grid.add_theme_constant_override("v_separation", 5)
	tools.add_child(emblem_palette_grid)
	_rebuild_emblem_palette_buttons()
	tools.add_child(_localized_label("ui.guild.emblem.hex", 9, UI_MUTED))
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 5)
	tools.add_child(code_row)
	emblem_color_code_input = LineEdit.new()
	emblem_color_code_input.name = "GuildEmblemColorCode"
	emblem_color_code_input.placeholder_text = "#rrggbb"
	emblem_color_code_input.max_length = 7
	emblem_color_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emblem_color_code_input.text_submitted.connect(_on_emblem_color_code_submitted)
	emblem_color_code_input.text_changed.connect(_on_emblem_color_code_changed)
	_apply_line_edit_style(emblem_color_code_input)
	code_row.add_child(emblem_color_code_input)
	emblem_color_code_preview = PanelContainer.new()
	emblem_color_code_preview.name = "GuildEmblemColorCodePreview"
	emblem_color_code_preview.custom_minimum_size = Vector2(34, 34)
	_set_localized_property(
		emblem_color_code_preview,
		"tooltip_text",
		"ui.guild.emblem.hex_preview"
	)
	emblem_color_code_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code_row.add_child(emblem_color_code_preview)
	var apply_color_button := Button.new()
	apply_color_button.name = "ApplyGuildEmblemColorCodeButton"
	_set_localized_property(apply_color_button, "text", "ui.guild.emblem.apply")
	apply_color_button.pressed.connect(_apply_emblem_color_code)
	_apply_button_style(apply_color_button, "primary")
	code_row.add_child(apply_color_button)
	emblem_color_code_status_label = _label("", 9, UI_WARNING)
	emblem_color_code_status_label.name = "GuildEmblemColorCodeStatus"
	emblem_color_code_status_label.visible = false
	tools.add_child(emblem_color_code_status_label)
	var canvas_actions := HBoxContainer.new()
	canvas_actions.add_theme_constant_override("separation", 5)
	tools.add_child(canvas_actions)
	var erase_button := Button.new()
	_set_localized_property(erase_button, "text", "ui.guild.emblem.erase")
	erase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erase_button.pressed.connect(_select_emblem_color.bind(-1))
	_apply_button_style(erase_button)
	canvas_actions.add_child(erase_button)
	var clear_button := Button.new()
	_set_localized_property(clear_button, "text", "ui.guild.emblem.clear")
	clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_button.pressed.connect(_clear_emblem)
	_apply_button_style(clear_button)
	canvas_actions.add_child(clear_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	var commit_actions := HBoxContainer.new()
	commit_actions.add_theme_constant_override("separation", 5)
	tools.add_child(commit_actions)
	var cancel_button := Button.new()
	cancel_button.name = "CancelGuildEmblemButton"
	_set_localized_property(cancel_button, "text", "common.cancel")
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_cancel_emblem_edit)
	_apply_button_style(cancel_button)
	commit_actions.add_child(cancel_button)
	var save_button := Button.new()
	save_button.name = "SaveGuildEmblemButton"
	_set_localized_property(save_button, "text", "ui.guild.emblem.save")
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(_on_save_emblem)
	_apply_button_style(save_button, "primary")
	commit_actions.add_child(save_button)
	_refresh_emblem_palette_controls()
	_refresh_emblem_grid()
	return editor


func _rebuild_emblem_palette_buttons() -> void:
	if emblem_palette_grid == null:
		return
	_clear_children(emblem_palette_grid)
	emblem_color_buttons.clear()
	for color_index: int in range(emblem_palette.size()):
		var color_button := Button.new()
		color_button.name = "GuildEmblemColor_%d" % (color_index + 1)
		color_button.text = _t("ui.guild.emblem.color", {"number": color_index + 1})
		color_button.custom_minimum_size = Vector2(88, 34)
		color_button.pressed.connect(_select_emblem_color.bind(color_index))
		emblem_palette_grid.add_child(color_button)
		emblem_color_buttons.append(color_button)


func _refresh_emblem_template_controls() -> void:
	if emblem_template_select == null or apply_emblem_template_button == null:
		return
	emblem_template_select.clear()
	var templates := _array_from_value(guild_home.get("emblemTemplates", []))
	for template_value: Variant in templates:
		var template := _dictionary(template_value)
		var template_id := str(template.get("templateId", "")).strip_edges()
		if template_id == "":
			continue
		emblem_template_select.add_item(str(template.get("name", template_id)))
		emblem_template_select.set_item_metadata(
			emblem_template_select.item_count - 1,
			template_id
		)
	var has_templates := emblem_template_select.item_count > 0
	if not has_templates:
		emblem_template_select.add_item(_t("ui.guild.emblem.no_templates"))
	emblem_template_select.disabled = not has_templates
	apply_emblem_template_button.disabled = not has_templates


func _cancel_emblem_edit() -> void:
	if emblem_editor_popup != null:
		emblem_editor_popup.hide()


func _render_pending_applications(content: VBoxContainer) -> void:
	var applications := _array_from_value(guild_home.get("pendingApplications", []))
	var inbox := PanelContainer.new()
	inbox.name = "GuildApplicationsInbox"
	inbox.custom_minimum_size = Vector2(0, 126)
	inbox.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#0b1b29f2"), Color(UI_GOLD.r, UI_GOLD.g, UI_GOLD.b, 0.58), 9, 1)
	)
	content.add_child(inbox)
	var inbox_margin := MarginContainer.new()
	_set_margins(inbox_margin, 13, 11, 13, 12)
	inbox.add_child(inbox_margin)
	var inbox_content := VBoxContainer.new()
	inbox_content.add_theme_constant_override("separation", 7)
	inbox_margin.add_child(inbox_content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	inbox_content.add_child(header)
	var title := _localized_label("ui.guild.application.pending_title", 12, UI_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var count := Label.new()
	count.name = "GuildApplicationsPendingCount"
	count.text = _t("ui.guild.application.pending_count", {"count": applications.size()})
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", UI_TEXT)
	header.add_child(count)
	var hint := _localized_label("ui.guild.application.review_hint", 10, UI_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inbox_content.add_child(hint)

	if applications.is_empty():
		var empty_state := PanelContainer.new()
		empty_state.name = "GuildApplicationsEmptyState"
		empty_state.add_theme_stylebox_override("panel", _panel_style(UI_INPUT, UI_BORDER_INNER, 7, 1))
		inbox_content.add_child(empty_state)
		var empty_margin := MarginContainer.new()
		_set_margins(empty_margin, 11, 9, 11, 9)
		empty_state.add_child(empty_margin)
		var empty_row := HBoxContainer.new()
		empty_row.add_theme_constant_override("separation", 9)
		empty_margin.add_child(empty_row)
		var marker := _label("✓", 18, UI_SUCCESS)
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_row.add_child(marker)
		var empty_copy := VBoxContainer.new()
		empty_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_copy.add_theme_constant_override("separation", 2)
		empty_row.add_child(empty_copy)
		empty_copy.add_child(_localized_label("ui.guild.application.pending_empty_title", 12, UI_TEXT))
		empty_copy.add_child(_localized_label("ui.guild.application.pending_empty", 10, UI_MUTED))
		return
	for application_value: Variant in applications:
		if not application_value is Dictionary:
			continue
		var application := application_value as Dictionary
		var application_id := int(application.get("id", 0))
		var application_card := PanelContainer.new()
		application_card.add_theme_stylebox_override("panel", _panel_style(UI_INPUT, UI_BORDER_INNER, 7, 1))
		inbox_content.add_child(application_card)
		var row_margin := MarginContainer.new()
		_set_margins(row_margin, 11, 8, 9, 8)
		application_card.add_child(row_margin)
		var row := HBoxContainer.new()
		row.name = "GuildApplicationRow_%d" % application_id
		row.add_theme_constant_override("separation", 7)
		row_margin.add_child(row)
		var applicant := _label(
			str(application.get(
				"applicantDisplayName",
				application.get("applicantUsername", _t("common.unknown"))
			)),
			11,
			UI_TEXT
		)
		var applicant_identity := VBoxContainer.new()
		applicant_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		applicant_identity.add_theme_constant_override("separation", 1)
		row.add_child(applicant_identity)
		applicant_identity.add_child(applicant)
		var applicant_username := str(application.get("applicantUsername", "")).strip_edges()
		if applicant_username != "":
			applicant_identity.add_child(_label("@%s" % applicant_username, 9, UI_MUTED))
		var trainer_card := Button.new()
		trainer_card.name = "ViewGuildApplicantTrainerCardButton_%d" % application_id
		_set_localized_property(trainer_card, "text", "ui.guild.application.trainer_card")
		trainer_card.disabled = int(application.get("applicantUserId", 0)) <= 0
		trainer_card.pressed.connect(_on_guild_application_trainer_card_pressed.bind(application))
		_apply_button_style(trainer_card)
		row.add_child(trainer_card)
		var accept := Button.new()
		accept.name = "AcceptGuildApplicationButton_%d" % application_id
		_set_localized_property(accept, "text", "common.accept")
		accept.pressed.connect(_on_accept_application.bind(application_id))
		_apply_button_style(accept, "primary")
		row.add_child(accept)
		var decline := Button.new()
		decline.name = "DeclineGuildApplicationButton_%d" % application_id
		_set_localized_property(decline, "text", "common.decline")
		decline.pressed.connect(_on_decline_application.bind(application_id))
		_apply_button_style(decline)
		row.add_child(decline)


func _on_guild_application_trainer_card_pressed(application: Dictionary) -> void:
	var user_id := int(application.get("applicantUserId", 0))
	if user_id <= 0:
		return
	trainer_card_requested.emit({
		"userId": user_id,
		"username": str(application.get("applicantUsername", "")),
		"displayName": str(application.get("applicantDisplayName", application.get("applicantUsername", "Trainer"))),
	})


func _render_pending_invitations(content: VBoxContainer) -> void:
	var invitations := _array_from_value(guild_home.get("pendingInvitations", []))
	if invitations.is_empty():
		return
	content.add_child(_localized_label("ui.guild.invite.pending", 9, UI_MUTED))
	for invitation_value: Variant in invitations:
		if not invitation_value is Dictionary:
			continue
		var invitation := invitation_value as Dictionary
		var row := HBoxContainer.new()
		content.add_child(row)
		var target := _label(str(invitation.get("invitedDisplayName", invitation.get("invitedUsername", "Trainer"))), 11, UI_TEXT)
		target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(target)
		var cancel := Button.new()
		_set_localized_property(cancel, "text", "common.cancel")
		cancel.pressed.connect(_on_cancel_invitation.bind(int(invitation.get("id", 0))))
		_apply_button_style(cancel)
		row.add_child(cancel)


func _render_guild_list() -> void:
	if guild_list == null:
		return
	_render_incoming_invitations()
	_clear_children(guild_list)
	var filtered := _filtered_guilds()
	guild_count_label.text = _plural(
		"ui.guild.count.one",
		"ui.guild.count.many",
		filtered.size()
	)
	if filtered.is_empty():
		selected_guild_id = 0
		guild_list.add_child(_directory_empty_state())
		_render_empty_detail()
		return
	if not _contains_guild_id(filtered, selected_guild_id):
		selected_guild_id = int(filtered[0].get("id", 0))
	for guild: Dictionary in filtered:
		guild_list.add_child(_guild_row(guild))
	_render_selected_guild()


func _guild_row(guild: Dictionary) -> Control:
	var guild_id := int(guild.get("id", 0))
	var selected := guild_id == selected_guild_id
	var accent: Color = guild.get("accent", UI_ACCENT)
	var button := Button.new()
	button.name = "GuildRow_%d" % guild_id
	button.text = ""
	button.custom_minimum_size = Vector2(0, 92)
	button.add_theme_stylebox_override("normal", _row_style(accent, selected))
	button.add_theme_stylebox_override("hover", _row_style(Color("#7edfff"), true))
	button.add_theme_stylebox_override("pressed", _row_style(UI_ACCENT, true, Color("#071624fa")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_select_guild.bind(guild_id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_set_margins(margin, 10, 8, 10, 8)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	row.add_child(_guild_emblem(guild, 50, accent))
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var name_label := _label(str(guild.get("name", "Unnamed Guild")), 15, UI_TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)
	var discovery := _label(
		_t("ui.guild.row.discovery", {
			"focus": _option_display(str(guild.get("focus", ""))),
			"language": _option_display(str(guild.get("language", ""))),
		}),
		10,
		UI_ACCENT
	)
	discovery.name = "GuildRowDiscovery_%d" % guild_id
	discovery.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	discovery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(discovery)
	var availability := _label(
		_t("ui.guild.row.availability", {
			"members": int(guild.get("members", 0)),
			"capacity": int(guild.get("capacity", 0)),
			"recruitment": _option_display(str(guild.get("recruitment", "Closed"))),
		}),
		10,
		UI_MUTED
	)
	availability.name = "GuildRowAvailability_%d" % guild_id
	availability.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	availability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(availability)
	var arrow := _label("›", 22, UI_ACCENT if selected else UI_MUTED)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	return button


func _render_selected_guild() -> void:
	_clear_children(detail_content)
	var guild := _guild_by_id(selected_guild_id)
	if guild.is_empty():
		_render_empty_detail()
		return
	var accent: Color = guild.get("accent", UI_ACCENT)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 13)
	detail_content.add_child(header)
	header.add_child(_guild_emblem(guild, 82, accent))
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 3)
	header.add_child(heading)
	heading.add_child(_label(str(guild.get("name", "Unnamed Guild")), 24, UI_TEXT))
	heading.add_child(_label(_t("ui.guild.led_by", {
		"leader": str(guild.get("leader", _t("common.unknown"))),
	}), 12, UI_MUTED))
	header.add_child(_status_pill(str(guild.get("recruitment", "Closed"))))
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", UI_BORDER_INNER)
	detail_content.add_child(divider)

	var metadata := GridContainer.new()
	metadata.columns = 2
	metadata.add_theme_constant_override("h_separation", 9)
	metadata.add_theme_constant_override("v_separation", 9)
	detail_content.add_child(metadata)
	metadata.add_child(_metadata_card(_t("ui.guild.field.level"), str(guild.get("level", 1)), accent))
	metadata.add_child(_metadata_card(_t("ui.guild.field.members"), "%d / %d" % [int(guild.get("members", 0)), int(guild.get("capacity", 0))], UI_SUCCESS))
	metadata.add_child(_metadata_card(_t("ui.guild.field.language"), _option_display(str(guild.get("language", ""))), UI_ACCENT))
	metadata.add_child(_metadata_card(_t("ui.guild.field.focus"), _option_display(str(guild.get("focus", ""))), UI_GOLD))
	detail_content.add_child(_localized_label("ui.guild.about", 10, UI_ACCENT))

	var description_panel := PanelContainer.new()
	description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	detail_content.add_child(description_panel)
	var description_margin := MarginContainer.new()
	_set_margins(description_margin, 14, 12, 14, 12)
	description_panel.add_child(description_margin)
	var description := _label(str(guild.get("description", _t("ui.guild.no_description"))), 13, UI_TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_margin.add_child(description)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	detail_content.add_child(actions)
	var apply_button := Button.new()
	apply_button.name = "GuildApplyButton"
	var recruitment := str(guild.get("recruitment", "Closed"))
	var is_own_guild := int(membership.get("guildId", 0)) == int(guild.get("id", 0))
	var pending_application := _pending_application_for_guild(int(guild.get("id", 0)))
	if not pending_application.is_empty():
		var pending_label := _localized_label("ui.guild.application.pending", 11, UI_GOLD)
		pending_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		actions.add_child(pending_label)
	if is_own_guild:
		apply_button.text = _t("ui.guild.yours")
	elif not membership.is_empty():
		apply_button.text = _t("ui.guild.application.already_member")
	elif not pending_application.is_empty():
		apply_button.text = _t("ui.guild.application.cancel")
	else:
		apply_button.text = _application_button_text(recruitment)
	apply_button.disabled = (
		is_application_action_in_flight
		or is_own_guild
		or not membership.is_empty()
		or (pending_application.is_empty() and recruitment.to_lower() in ["closed", "invite only"])
	)
	apply_button.custom_minimum_size = Vector2(150, 40)
	apply_button.pressed.connect(_on_application_pressed.bind(guild))
	_apply_button_style(apply_button, "" if not pending_application.is_empty() else "primary")
	actions.add_child(apply_button)


func _render_empty_detail() -> void:
	_clear_children(detail_content)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_content.add_child(center)
	var empty := VBoxContainer.new()
	empty.custom_minimum_size = Vector2(390, 0)
	empty.alignment = BoxContainer.ALIGNMENT_CENTER
	empty.add_theme_constant_override("separation", 8)
	center.add_child(empty)
	var icon := _icon_rect(58, Color(1, 1, 1, 0.42))
	empty.add_child(icon)
	var title := _localized_label("ui.guild.empty_selection.title", 18, UI_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(title)
	var message := _localized_label("ui.guild.empty_selection.description", 12, UI_MUTED)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_child(message)
	var create_button := Button.new()
	_set_localized_property(create_button, "text", "ui.guild.create.action")
	create_button.custom_minimum_size = Vector2(160, 40)
	create_button.pressed.connect(_show_page.bind("create"))
	_apply_button_style(create_button, "primary")
	empty.add_child(create_button)


func _directory_empty_state() -> Control:
	var panel := PanelContainer.new()
	panel.name = "GuildDirectoryEmptyState"
	panel.custom_minimum_size = Vector2(0, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07111edc"), UI_BORDER_INNER, 9, 1))
	var text := (
		_t("ui.guild.empty_search")
		if search_input.text.strip_edges() != ""
		else _t("ui.guild.empty_directory")
	)
	var label := _label(text, 12, UI_MUTED)
	label.name = "GuildDirectoryEmptyMessage"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _emblem(emblem_size: int, accent: Color) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(emblem_size, emblem_size)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(Color("#0a2133ee"), Color(accent.r, accent.g, accent.b, 0.72), 10, 1))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)
	center.add_child(_icon_rect(int(emblem_size * 0.58), Color(accent.r, accent.g, accent.b, 0.82)))
	return frame


func _guild_emblem(guild: Dictionary, emblem_size: int, accent: Color) -> Control:
	var emblem := _dictionary(guild.get("emblem", {}))
	var palette := _array_from_value(emblem.get("palette", []))
	var pixels := _normalized_emblem_pixels(emblem)
	if palette.is_empty() or pixels.is_empty() or not pixels.any(func(value: Variant) -> bool: return int(value) >= 0):
		return _emblem(emblem_size, accent)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(emblem_size, emblem_size)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(Color("#07111eee"), Color(accent.r, accent.g, accent.b, 0.72), 8, 1))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)
	var grid := GridContainer.new()
	grid.columns = GUILD_EMBLEM_SIZE
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	center.add_child(grid)
	var pixel_size := maxf(float(emblem_size - 10) / float(GUILD_EMBLEM_SIZE), 1.0)
	for pixel_value: Variant in pixels:
		var pixel := ColorRect.new()
		pixel.custom_minimum_size = Vector2(pixel_size, pixel_size)
		pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color_index := int(pixel_value)
		pixel.color = Color(str(palette[color_index])) if color_index >= 0 and color_index < palette.size() else Color(0, 0, 0, 0)
		grid.add_child(pixel)
	return frame


func _status_pill(status: String) -> Control:
	var color := UI_SUCCESS if status.to_lower() in ["open", "applications open"] else UI_WARNING
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.10), Color(color.r, color.g, color.b, 0.62), 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 10, 5, 10, 5)
	panel.add_child(margin)
	margin.add_child(_label(_option_display(status), 11, color))
	return panel


func _metadata_card(caption: String, value: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, Color(accent.r, accent.g, accent.b, 0.45), 8, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 11, 8, 11, 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	stack.add_child(_label(caption, 9, UI_MUTED))
	var value_label := _label(value, 14, accent)
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(value_label)
	return panel


func _requirement_card(caption: String, value: String, note: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, Color("#8f743dcc"), 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 13, 9, 13, 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var marker := _label("◆", 18, UI_GOLD)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(marker)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 1)
	row.add_child(stack)
	stack.add_child(_label(caption, 9, UI_MUTED))
	var value_label := _label(value, 14, UI_TEXT)
	stack.add_child(value_label)
	stack.add_child(_label(note, 10, UI_GOLD))
	return {"control": panel, "value": value_label}


func _labeled_field(caption: String, field: Control, hint: String = "") -> Control:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var caption_label := _label(caption, 10, UI_ACCENT)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption_label)
	if hint != "":
		header.add_child(_label(hint, 9, UI_MUTED))
	stack.add_child(field)
	return stack


func _option_button(options: Array[String]) -> OptionButton:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(0, 40)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option: String in options:
		select.add_item(_option_display(option))
		select.set_item_metadata(select.item_count - 1, option)
	_apply_option_button_style(select)
	return select


func _show_page(page: String) -> void:
	active_page = page if page in ["browse", "member", "create"] else "browse"
	if active_page == "create" and not membership.is_empty():
		active_page = "member"
	if active_page == "member" and membership.is_empty():
		active_page = "browse"
	if browse_page != null:
		browse_page.visible = active_page == "browse"
	if member_page != null:
		member_page.visible = active_page == "member"
	if create_page != null:
		create_page.visible = active_page == "create"
	_refresh_primary_navigation_style()
	_apply_tab_style(create_tab_button, active_page == "create")
	if active_page == "create":
		_refresh_creation_requirements()
	elif active_page == "member":
		_render_guild_home()


func _on_primary_navigation_pressed(page: String) -> void:
	has_explicit_page_selection = true
	_show_page(page)


func _select_guild(guild_id: int) -> void:
	selected_guild_id = guild_id
	_render_guild_list()


func _on_search_changed(_query: String) -> void:
	_render_guild_list()


func _on_application_pressed(guild: Dictionary) -> void:
	if is_application_action_in_flight or not membership.is_empty():
		return
	var guild_id := int(guild.get("id", 0))
	if guild_id <= 0:
		return
	var pending_application := _pending_application_for_guild(guild_id)
	if not pending_application.is_empty():
		_cancel_application(int(pending_application.get("id", 0)), guild)
		return
	match str(guild.get("recruitment", "Closed")).to_lower():
		"open":
			_confirm_open_guild_join(guild)
		"applications open":
			_apply_to_selected_guild(guild)


func _confirm_open_guild_join(guild: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "GuildJoinConfirmationDialog"
	dialog.title = _t("ui.guild.application.join_confirm_title")
	dialog.dialog_text = _t("ui.guild.application.join_confirm", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	})
	dialog.ok_button_text = _t("ui.guild.application.join")
	dialog.cancel_button_text = _t("common.cancel")
	_apply_guild_confirmation_style(dialog, "primary")
	dialog.confirmed.connect(_join_selected_guild.bind(guild), CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	add_child(dialog)
	dialog.popup_centered(Vector2i(430, 170))


func _join_selected_guild(guild: Dictionary) -> void:
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_browse_status(_t("ui.guild.error.service_unavailable"), true)
		return
	is_application_action_in_flight = true
	_render_guild_list()
	_set_browse_status(_t("ui.guild.status.joining", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	}), false)
	var response: Variant = await guild_service.call("join_guild", int(guild.get("id", 0)))
	var result := _dictionary(response)
	is_application_action_in_flight = false
	if not bool(result.get("success", false)):
		_render_guild_list()
		_set_browse_status(str(result.get("error", _t("ui.guild.error.join"))), true)
		return
	pending_applications.clear()
	incoming_invitations.clear()
	_apply_home_result(result)
	_show_page("member")
	_set_member_status(_t("ui.guild.status.joined", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	}), false)


func _apply_to_selected_guild(guild: Dictionary) -> void:
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_browse_status(_t("ui.guild.error.service_unavailable"), true)
		return
	is_application_action_in_flight = true
	_render_guild_list()
	_set_browse_status(_t("ui.guild.status.applying", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	}), false)
	var response: Variant = await guild_service.call("apply_to_guild", int(guild.get("id", 0)))
	var result := _dictionary(response)
	is_application_action_in_flight = false
	if not bool(result.get("success", false)):
		_render_guild_list()
		_set_browse_status(str(result.get("error", _t("ui.guild.error.apply"))), true)
		return
	_upsert_pending_application(_dictionary(result.get("application", {})))
	_render_guild_list()
	_set_browse_status(_t("ui.guild.status.application_sent", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	}), false)


func _cancel_application(application_id: int, guild: Dictionary) -> void:
	if application_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_browse_status(_t("ui.guild.error.service_unavailable"), true)
		return
	is_application_action_in_flight = true
	_render_guild_list()
	var response: Variant = await guild_service.call("cancel_application", application_id)
	var result := _dictionary(response)
	is_application_action_in_flight = false
	if not bool(result.get("success", false)):
		_render_guild_list()
		_set_browse_status(str(result.get("error", _t("ui.guild.error.cancel_application"))), true)
		return
	_remove_pending_application(application_id)
	_render_guild_list()
	_set_browse_status(_t("ui.guild.status.application_cancelled", {
		"guild": str(guild.get("name", _t("ui.guild.fallback.this_guild"))),
	}), false)


func _on_create_form_changed(_unused: Variant = null) -> void:
	if create_status_label != null:
		create_status_label.text = ""


func _on_create_pressed() -> void:
	if is_creating_guild:
		return
	if not membership.is_empty():
		_set_create_status(_t("ui.guild.error.already_member"), true)
		return
	var guild_name := guild_name_input.text.strip_edges()
	var description := guild_description_input.text.strip_edges()
	if guild_name.length() < 3:
		_set_create_status(_t("ui.guild.error.name_short"), true)
		return
	if description.length() < 12:
		_set_create_status(_t("ui.guild.error.description_short"), true)
		return
	if _player_money() < CREATION_COST:
		_set_create_status(_t("ui.guild.error.money_required"), true)
		return
	if _player_badge_count() < REQUIRED_BADGES:
		_set_create_status(_t("ui.guild.error.badges_required", {"count": REQUIRED_BADGES}), true)
		return
	is_creating_guild = true
	submit_create_button.disabled = true
	submit_create_button.text = _t("ui.guild.status.creating")
	_set_create_status(_t("ui.guild.status.creating_long"), false)
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		is_creating_guild = false
		submit_create_button.disabled = false
		submit_create_button.text = _t("ui.guild.create.submit")
		_set_create_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var response: Variant = await guild_service.call(
		"create_guild",
		guild_name,
		description,
		_selected_option_value(language_select),
		_selected_option_value(focus_select),
		_selected_option_value(recruitment_select)
	)
	var result := _dictionary(response)
	is_creating_guild = false
	submit_create_button.disabled = false
	submit_create_button.text = _t("ui.guild.create.submit")
	if not bool(result.get("success", false)):
		_set_create_status(str(result.get("error", _t("ui.guild.error.create"))), true)
		return
	var wallet: Variant = result.get("wallet", {})
	if wallet is Dictionary:
		var player_wallet_service := get_node_or_null("/root/PlayerWalletService")
		if player_wallet_service != null:
			player_wallet_service.call("apply_wallet_result", {"success": true, "wallet": wallet})
	membership = _dictionary(result.get("membership", {})).duplicate(true)
	var created_guild := _dictionary(result.get("guild", {})).duplicate(true)
	_upsert_guild(created_guild)
	selected_guild_id = int(created_guild.get("id", 0))
	_refresh_creation_requirements()
	_refresh_membership_state()
	await _refresh_home_from_server()
	_show_page("member")
	_set_member_status(_t("ui.guild.status.created", {
		"guild": str(created_guild.get("name", guild_name)),
	}), false)


func _refresh_from_server() -> void:
	if is_loading_guilds or is_debug_preview or not visible:
		return
	is_loading_guilds = true
	directory_request_generation += 1
	var request_generation := directory_request_generation
	browse_status_label.text = _t("ui.guild.status.loading_directory")
	browse_status_label.visible = true
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		is_loading_guilds = false
		browse_status_label.text = _t("ui.guild.error.service_unavailable")
		return
	var response: Variant = await guild_service.call("load_directory")
	var result := _dictionary(response)
	if request_generation != directory_request_generation:
		return
	is_loading_guilds = false
	if not bool(result.get("success", false)):
		browse_status_label.text = str(result.get("error", _t("ui.guild.error.load_directory")))
		browse_status_label.visible = true
		return
	membership = _dictionary(result.get("membership", {})).duplicate(true)
	incoming_invitations = _array_from_value(result.get("incomingInvitations", [])).duplicate(true)
	pending_applications = _array_from_value(result.get("pendingApplications", [])).duplicate(true)
	set_guilds(_array_from_value(result.get("guilds", [])))
	browse_status_label.visible = false
	if not membership.is_empty():
		await _refresh_home_from_server()
		if visible and not has_explicit_page_selection:
			_show_page("member")
	else:
		guild_home.clear()
		_render_guild_home()


func _refresh_home_from_server() -> void:
	if membership.is_empty():
		guild_home.clear()
		_render_guild_home()
		return
	if guild_home.is_empty():
		_render_guild_home()
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		return
	var response: Variant = await guild_service.call("load_home")
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.load_home"))), true)
		return
	_apply_home_result(result)


func _apply_home_result(result: Dictionary) -> void:
	guild_home = result.duplicate(true)
	membership = _dictionary(result.get("membership", {})).duplicate(true)
	if not membership.is_empty():
		pending_applications.clear()
	var home_guild := _dictionary(result.get("guild", {})).duplicate(true)
	if not home_guild.is_empty():
		_upsert_guild(home_guild)
		selected_guild_id = int(home_guild.get("id", selected_guild_id))
	_refresh_membership_state()
	_render_guild_home()
	if visible and active_guild_section == "bank" and not is_debug_preview:
		_load_guild_bank_async.call_deferred()


func _upsert_guild(guild: Dictionary) -> void:
	var guild_id := int(guild.get("id", 0))
	for index: int in range(guilds.size()):
		if int(guilds[index].get("id", 0)) == guild_id:
			guilds[index] = guild
			return
	guilds.append(guild)


func _refresh_membership_state() -> void:
	if membership_label == null:
		return
	var guild_id := int(membership.get("guildId", 0))
	if guild_id <= 0:
		membership_label.text = _t("ui.guild.membership.none")
		membership_label.visible = true
		create_tab_button.visible = true
		create_tab_button.disabled = false
		guild_section_navigation.visible = false
		browse_tab_button.custom_minimum_size = Vector2(190, 40)
		primary_navigation.move_child(browse_tab_button, 0)
		primary_navigation.move_child(create_tab_button, 1)
		primary_navigation.move_child(primary_navigation_spacer, 2)
		_refresh_primary_navigation_style()
		return
	membership_label.visible = false
	create_tab_button.visible = false
	guild_section_navigation.visible = true
	browse_tab_button.custom_minimum_size = Vector2(150, 34)
	if guild_section_buttons.is_empty():
		_build_guild_section_navigation(false, false)
	primary_navigation.move_child(guild_section_navigation, 0)
	primary_navigation.move_child(primary_navigation_spacer, 1)
	primary_navigation.move_child(browse_tab_button, 2)
	_refresh_primary_navigation_style()
	if active_page == "create":
		_show_page("member")


func _refresh_primary_navigation_style() -> void:
	if browse_tab_button == null:
		return
	if membership.is_empty():
		_apply_tab_style(browse_tab_button, active_page == "browse")
	else:
		_apply_button_style(browse_tab_button, "primary" if active_page == "browse" else "secondary")
	for section_id: String in guild_section_buttons:
		var button := guild_section_buttons.get(section_id) as Button
		if button != null:
			_apply_tab_style(
				button,
				active_page == "member" and active_guild_section == section_id
			)


func _membership_role_label(role: String) -> String:
	match role.to_lower():
		"leader":
			return _t("ui.guild.role.leader")
		"captain", "officer":
			return _t("ui.guild.role.captain")
		"member":
			return _t("ui.guild.role.member")
		_:
			return _t("ui.guild.role.recruit")


func _on_save_settings() -> void:
	if settings_description_input == null or settings_announcement_input == null:
		return
	var description := settings_description_input.text.strip_edges()
	if description.length() < 12:
		_set_member_status(_t("ui.guild.error.description_short"), true)
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	_set_member_status(_t("ui.guild.status.saving_settings"), false)
	var response: Variant = await guild_service.call(
		"update_settings",
		description,
		settings_announcement_input.text.strip_edges(),
		_selected_option_value(settings_language_select),
		_selected_option_value(settings_focus_select),
		_selected_option_value(settings_recruitment_select),
		_selected_guild_loan_duration()
	)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.save_settings"))), true)
		return
	_apply_home_result(result)
	_set_member_status(_t("ui.guild.status.settings_saved"), false)


func _on_invite_member(dialog: ConfirmationDialog = null) -> void:
	if invite_username_input == null:
		return
	var username := invite_username_input.text.strip_edges()
	if username.length() < 3:
		_set_member_status(_t("ui.guild.error.username_required"), true)
		if dialog != null and is_instance_valid(dialog):
			dialog.popup_centered(Vector2i(460, 210))
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var response: Variant = await guild_service.call("invite_member", username)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.send_invitation"))), true)
		if dialog != null and is_instance_valid(dialog):
			dialog.popup_centered(Vector2i(460, 210))
		return
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()
	await _refresh_home_from_server()
	_set_member_status(_t("ui.guild.status.invitation_sent", {"username": username}), false)


func _on_accept_invitation(invitation_id: int) -> void:
	if invitation_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		return
	var response: Variant = await guild_service.call("accept_invitation", invitation_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		browse_status_label.text = str(result.get("error", _t("ui.guild.error.accept_invitation")))
		browse_status_label.visible = true
		return
	incoming_invitations.clear()
	_apply_home_result(result)
	_show_page("member")
	_set_member_status(_t("ui.guild.status.invitation_accepted"), false)


func _on_decline_invitation(invitation_id: int) -> void:
	if invitation_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		return
	var response: Variant = await guild_service.call("decline_invitation", invitation_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		browse_status_label.text = str(result.get("error", _t("ui.guild.error.decline_invitation")))
		browse_status_label.visible = true
		return
	var remaining: Array = []
	for invitation_value: Variant in incoming_invitations:
		if not invitation_value is Dictionary or int((invitation_value as Dictionary).get("id", 0)) != invitation_id:
			remaining.append(invitation_value)
	incoming_invitations = remaining
	_render_incoming_invitations()


func _on_cancel_invitation(invitation_id: int) -> void:
	if invitation_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		return
	var response: Variant = await guild_service.call("cancel_invitation", invitation_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.cancel_invitation"))), true)
		return
	await _refresh_home_from_server()
	_set_member_status(_t("ui.guild.status.invitation_cancelled"), false)


func _on_accept_application(application_id: int) -> void:
	if application_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var trainer_name := _guild_application_trainer_name(application_id)
	var response: Variant = await guild_service.call("accept_application", application_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.accept_application"))), true)
		return
	_apply_home_result(result)
	active_guild_section = "management"
	_render_guild_home()
	_set_member_status(_t("ui.guild.status.application_accepted"), false)
	_show_guild_system_message("ui.guild.notification.you_accepted", {"trainer": trainer_name})


func _on_decline_application(application_id: int) -> void:
	if application_id <= 0:
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var trainer_name := _guild_application_trainer_name(application_id)
	var response: Variant = await guild_service.call("decline_application", application_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.decline_application"))), true)
		return
	await _refresh_home_from_server()
	active_guild_section = "management"
	_render_guild_home()
	_set_member_status(_t("ui.guild.status.application_declined"), false)
	_show_guild_system_message("ui.guild.notification.you_declined", {"trainer": trainer_name})


func _guild_application_trainer_name(application_id: int) -> String:
	for value: Variant in _array_from_value(guild_home.get("pendingApplications", [])):
		if value is Dictionary and int((value as Dictionary).get("id", 0)) == application_id:
			return str((value as Dictionary).get(
				"applicantDisplayName",
				(value as Dictionary).get("applicantUsername", _t("common.unknown"))
			))
	return _t("common.unknown")


func _show_guild_system_message(key: String, args: Dictionary = {}) -> void:
	get_tree().call_group("ui_overlay", "add_system_message", _t(key, args))


func _load_emblem_editor(emblem: Dictionary) -> void:
	var palette_value := _array_from_value(emblem.get("palette", []))
	if not palette_value.is_empty():
		emblem_palette.clear()
		for color_value: Variant in palette_value:
			emblem_palette.append(str(color_value))
	if emblem_palette.is_empty():
		emblem_palette = ["#60d3ff", "#79e49b", "#e3bd68", "#a78bfa", "#f4f0de"]
	emblem_pixels.clear()
	var pixels_value := _normalized_emblem_pixels(emblem)
	for pixel_index: int in range(GUILD_EMBLEM_PIXEL_COUNT):
		var color_index := int(pixels_value[pixel_index]) if pixel_index < pixels_value.size() else -1
		emblem_pixels.append(color_index if color_index >= -1 and color_index < emblem_palette.size() else -1)
	selected_emblem_color = 0


func _normalized_emblem_pixels(emblem: Dictionary) -> Array:
	var pixels := _array_from_value(emblem.get("pixels", []))
	if pixels.size() == GUILD_EMBLEM_PIXEL_COUNT:
		return pixels
	if pixels.size() == LEGACY_GUILD_EMBLEM_SIZE * LEGACY_GUILD_EMBLEM_SIZE:
		return _upscale_legacy_emblem_pixels(pixels)
	return []


func _upscale_legacy_emblem_pixels(legacy_pixels: Array) -> Array:
	var pixels: Array = []
	var scale := GUILD_EMBLEM_SIZE / LEGACY_GUILD_EMBLEM_SIZE
	for y: int in range(GUILD_EMBLEM_SIZE):
		for x: int in range(GUILD_EMBLEM_SIZE):
			var source_y := int(y / scale)
			var source_x := int(x / scale)
			pixels.append(int(legacy_pixels[source_y * LEGACY_GUILD_EMBLEM_SIZE + source_x]))
	return pixels


func _on_emblem_pixel_pressed(pixel_index: int) -> void:
	if pixel_index < 0 or pixel_index >= emblem_pixels.size():
		return
	emblem_pixels[pixel_index] = selected_emblem_color
	_refresh_emblem_grid()


func _select_emblem_color(color_index: int) -> void:
	selected_emblem_color = color_index
	_refresh_emblem_palette_controls()


func _on_emblem_color_code_submitted(_code: String) -> void:
	_apply_emblem_color_code()


func _on_emblem_color_code_changed(code: String) -> void:
	var normalized_code := code.strip_edges().to_lower()
	if _is_hex_color_code(normalized_code):
		_set_emblem_color_code_preview(Color(normalized_code))


func _apply_emblem_color_code() -> void:
	if emblem_color_code_input == null or selected_emblem_color < 0 or selected_emblem_color >= emblem_palette.size():
		return
	var code := emblem_color_code_input.text.strip_edges().to_lower()
	if not _is_hex_color_code(code):
		emblem_color_code_status_label.text = _t("ui.guild.emblem.hex_error")
		emblem_color_code_status_label.visible = true
		emblem_color_code_input.add_theme_color_override("font_color", UI_WARNING)
		return
	emblem_palette[selected_emblem_color] = code
	emblem_color_code_input.text = code
	emblem_color_code_input.add_theme_color_override("font_color", UI_TEXT)
	emblem_color_code_status_label.visible = false
	_refresh_emblem_palette_controls()
	_refresh_emblem_grid()


func _is_hex_color_code(code: String) -> bool:
	if code.length() != 7 or not code.begins_with("#"):
		return false
	for character_index: int in range(1, code.length()):
		if not code.substr(character_index, 1).to_lower() in "0123456789abcdef":
			return false
	return true


func _refresh_emblem_palette_controls() -> void:
	if emblem_color_buttons.size() != emblem_palette.size():
		_rebuild_emblem_palette_buttons()
	for color_index: int in range(mini(emblem_color_buttons.size(), emblem_palette.size())):
		var color_button := emblem_color_buttons[color_index]
		var color := Color(emblem_palette[color_index])
		var border := UI_TEXT if color_index == selected_emblem_color else UI_BORDER
		color_button.add_theme_stylebox_override("normal", _button_style(color, border))
		color_button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.12), UI_ACCENT))
		color_button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.12), UI_ACCENT))
	if emblem_color_code_input != null:
		var has_color := selected_emblem_color >= 0 and selected_emblem_color < emblem_palette.size()
		emblem_color_code_input.editable = has_color
		emblem_color_code_input.text = emblem_palette[selected_emblem_color] if has_color else ""
		emblem_color_code_input.add_theme_color_override("font_color", UI_TEXT)
		_set_emblem_color_code_preview(
			Color(emblem_palette[selected_emblem_color]) if has_color else UI_INPUT
		)
	if emblem_color_code_status_label != null:
		emblem_color_code_status_label.visible = false


func _set_emblem_color_code_preview(color: Color) -> void:
	if emblem_color_code_preview == null:
		return
	emblem_color_code_preview.add_theme_stylebox_override(
		"panel",
		_button_style(color, UI_BORDER, 7, 1)
	)


func _clear_emblem() -> void:
	for pixel_index: int in range(emblem_pixels.size()):
		emblem_pixels[pixel_index] = -1
	_refresh_emblem_grid()


func _refresh_emblem_grid() -> void:
	for pixel_index: int in range(mini(emblem_pixel_buttons.size(), emblem_pixels.size())):
		var color_index := emblem_pixels[pixel_index]
		var background := Color("#07111e")
		if color_index >= 0 and color_index < emblem_palette.size():
			background = Color(emblem_palette[color_index])
		var pixel := emblem_pixel_buttons[pixel_index]
		pixel.add_theme_stylebox_override("normal", _emblem_pixel_style(background, UI_BORDER_INNER))
		pixel.add_theme_stylebox_override("hover", _emblem_pixel_style(background.lightened(0.2), UI_ACCENT))
		pixel.add_theme_stylebox_override("pressed", _emblem_pixel_style(background.darkened(0.15), UI_ACCENT))


func _on_save_emblem() -> void:
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	var response: Variant = await guild_service.call("update_emblem", emblem_palette, emblem_pixels)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		_set_member_status(str(result.get("error", _t("ui.guild.error.save_emblem"))), true)
		return
	_apply_home_result(result)
	if emblem_editor_popup != null:
		emblem_editor_popup.hide()
	_set_member_status(_t("ui.guild.status.emblem_saved"), false)


func _on_apply_saved_emblem_template() -> void:
	if emblem_template_select == null or emblem_template_select.disabled:
		return
	var selected_index := emblem_template_select.selected
	if selected_index < 0 or selected_index >= emblem_template_select.item_count:
		return
	var template_id := str(emblem_template_select.get_item_metadata(selected_index))
	if template_id == "":
		return
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null:
		_set_member_status(_t("ui.guild.error.service_unavailable"), true)
		return
	apply_emblem_template_button.disabled = true
	var response: Variant = await guild_service.call("apply_emblem_template", template_id)
	var result := _dictionary(response)
	if not bool(result.get("success", false)):
		apply_emblem_template_button.disabled = false
		_set_member_status(str(result.get("error", _t("ui.guild.error.apply_emblem"))), true)
		return
	_apply_home_result(result)
	if emblem_editor_popup != null:
		emblem_editor_popup.hide()
	_set_member_status(_t("ui.guild.status.emblem_applied"), false)


func _select_option_text(select: OptionButton, value: String) -> void:
	for item_index: int in range(select.item_count):
		if str(select.get_item_metadata(item_index)) == value:
			select.select(item_index)
			return


func _set_member_status(message: String, is_error: bool) -> void:
	if member_status_label == null:
		return
	member_status_label.text = message
	member_status_label.add_theme_color_override("font_color", UI_WARNING if is_error else UI_SUCCESS)


func _render_guild_home_with_status(message: String, is_error: bool) -> void:
	_render_guild_home()
	_set_member_status(message, is_error)


func _set_browse_status(message: String, is_error: bool) -> void:
	if browse_status_label == null:
		return
	browse_status_label.text = message
	browse_status_label.visible = not message.is_empty()
	browse_status_label.add_theme_color_override(
		"font_color",
		UI_WARNING if is_error else UI_SUCCESS
	)


func _refresh_creation_requirements() -> void:
	if money_requirement_label == null:
		return
	var current_money := _player_money()
	var has_money := current_money >= CREATION_COST
	money_requirement_label.text = "$%s / $%s" % [_format_number(current_money), _format_number(CREATION_COST)]
	money_requirement_label.add_theme_color_override("font_color", UI_SUCCESS if has_money else UI_TEXT)
	if badge_requirement_label != null:
		var current_badges := _player_badge_count()
		badge_requirement_label.text = _t("ui.guild.create.badge_progress", {
			"current": current_badges,
			"required": REQUIRED_BADGES,
		})
		badge_requirement_label.add_theme_color_override(
			"font_color",
			UI_SUCCESS if current_badges >= REQUIRED_BADGES else UI_TEXT
		)


func _set_create_status(message: String, is_error: bool) -> void:
	create_status_label.text = message
	create_status_label.add_theme_color_override("font_color", UI_WARNING if is_error else UI_SUCCESS)


func _filtered_guilds() -> Array[Dictionary]:
	var query := search_input.text.strip_edges().to_lower() if search_input != null else ""
	var matches: Array[Dictionary] = []
	for guild: Dictionary in guilds:
		if not _matches_directory_filter(guild):
			continue
		var searchable := " ".join([
			str(guild.get("name", "")),
			str(guild.get("language", "")),
			str(guild.get("focus", "")),
			str(guild.get("description", "")),
		]).to_lower()
		if query == "" or searchable.contains(query):
			matches.append(guild)
	return matches


func _matches_directory_filter(guild: Dictionary) -> bool:
	var recruitment := str(guild.get("recruitment", "")).to_lower()
	var focus := str(guild.get("focus", "")).to_lower()
	var language := str(guild.get("language", "")).to_lower()
	if directory_recruitment_filter == "open" and recruitment not in ["open", "applications open"]:
		return false
	if directory_focus_filter != "all" and not focus.contains(directory_focus_filter):
		return false
	if not _matches_directory_language_filter(language):
		return false
	return true


func _matches_directory_language_filter(language: String) -> bool:
	if directory_language_filter == "all":
		return true
	if directory_language_filter == "dutch_english":
		return language == "dutch / english"
	var language_label := str({
		"english": "english",
		"spanish": "spanish",
		"portuguese": "portuguese",
		"italian": "italian",
		"chinese": "chinese",
		"german": "german",
		"french": "french",
		"dutch": "dutch",
		"other": "other",
	}.get(directory_language_filter, ""))
	return not language_label.is_empty() and language.contains(language_label)


func _contains_guild_id(entries: Array[Dictionary], guild_id: int) -> bool:
	for guild: Dictionary in entries:
		if int(guild.get("id", 0)) == guild_id:
			return true
	return false


func _guild_by_id(guild_id: int) -> Dictionary:
	for guild: Dictionary in guilds:
		if int(guild.get("id", 0)) == guild_id:
			return guild
	return {}


func _pending_application_for_guild(guild_id: int) -> Dictionary:
	for application_value: Variant in pending_applications:
		if not application_value is Dictionary:
			continue
		var application := application_value as Dictionary
		if (
			int(application.get("guildId", 0)) == guild_id
			and str(application.get("status", "pending")) == "pending"
		):
			return application
	return {}


func _upsert_pending_application(application: Dictionary) -> void:
	var application_id := int(application.get("id", 0))
	if application_id <= 0:
		return
	for index: int in range(pending_applications.size()):
		var existing := _dictionary(pending_applications[index])
		if int(existing.get("id", 0)) == application_id:
			pending_applications[index] = application.duplicate(true)
			return
	pending_applications.append(application.duplicate(true))


func _remove_pending_application(application_id: int) -> void:
	var remaining: Array = []
	for application_value: Variant in pending_applications:
		if (
			not application_value is Dictionary
			or int((application_value as Dictionary).get("id", 0)) != application_id
		):
			remaining.append(application_value)
	pending_applications = remaining


func _application_button_text(recruitment: String) -> String:
	match recruitment.to_lower():
		"open":
			return _t("ui.guild.application.join")
		"applications open":
			return _t("ui.guild.application.apply")
		"invite only":
			return _t("ui.guild.application.invite_only")
		_:
			return _t("ui.guild.application.closed")


func _format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted


func _player_money() -> int:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null:
		return 0
	return maxi(int(player_save.get("money")), 0)


func _player_badge_count() -> int:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null or not player_save.has_method("gym_badge_count"):
		return 0
	return maxi(int(player_save.call("gym_badge_count")), 0)


func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	size = POPUP_SIZE
	position = (viewport_size - size) * 0.5


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(clampf(position.x, 0.0, maxf(viewport_size.x - size.x, 0.0)), clampf(position.y, 0.0, maxf(viewport_size.y - size.y, 0.0)))


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		is_dragging_popup = mouse_button.pressed
		if is_dragging_popup:
			move_to_front()
		accept_event()


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array_from_value(value: Variant) -> Array:
	return value as Array if value is Array else []


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _localized_label(key: String, font_size: int, color: Color) -> Label:
	var label := _label(_t(key), font_size, color)
	label.set_meta("i18n_source_text", key)
	return label


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key.format(values)
	return str(localization_manager.call("text", key, values))


func _plural(one_key: String, many_key: String, count: int) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return one_key if count == 1 else many_key
	return str(localization_manager.call("plural", one_key, many_key, count))


func _option_display(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.is_empty():
		return _t("ui.guild.not_set")
	var key := str({
		"English": "ui.guild.option.language.english",
		"Spanish": "ui.guild.option.language.spanish",
		"Portuguese": "ui.guild.option.language.portuguese",
		"Italian": "ui.guild.option.language.italian",
		"Chinese": "ui.guild.option.language.chinese",
		"German": "ui.guild.option.language.german",
		"French": "ui.guild.option.language.french",
		"Dutch": "ui.guild.option.language.dutch",
		"Dutch / English": "ui.guild.option.language.dutch_english",
		"Other": "ui.guild.option.language.other",
		"Social": "ui.guild.option.focus.social",
		"PvE": "ui.guild.option.focus.pve",
		"PvP": "ui.guild.option.focus.pvp",
		"PvP & Social": "ui.guild.option.focus.pvp_social",
		"PvE & Social": "ui.guild.option.focus.pve_social",
		"Mixed": "ui.guild.option.focus.mixed",
		"Applications open": "ui.guild.option.recruitment.applications",
		"Open": "ui.guild.option.recruitment.open",
		"Invite only": "ui.guild.option.recruitment.invite_only",
		"Closed": "ui.guild.option.recruitment.closed",
	}.get(normalized, ""))
	return _t(key) if not key.is_empty() else normalized


func _selected_option_value(select: OptionButton) -> String:
	if select == null or select.selected < 0:
		return ""
	return str(select.get_item_metadata(select.selected))


func _refresh_option_labels(select_value: Variant) -> void:
	if select_value == null or not is_instance_valid(select_value) or not select_value is OptionButton:
		return
	var select := select_value as OptionButton
	for item_index: int in range(select.item_count):
		select.set_item_text(
			item_index,
			_option_display(str(select.get_item_metadata(item_index)))
		)


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_refresh_option_labels(language_select)
	_refresh_option_labels(focus_select)
	_refresh_option_labels(recruitment_select)
	_refresh_option_labels(settings_language_select)
	_refresh_option_labels(settings_focus_select)
	_refresh_option_labels(settings_recruitment_select)
	if directory_filter_popup != null:
		_populate_directory_filter_select(
			directory_recruitment_select,
			_selected_option_value(directory_recruitment_select)
		)
		_populate_directory_filter_select(
			directory_focus_select,
			_selected_option_value(directory_focus_select)
		)
		_populate_directory_filter_select(
			directory_language_select,
			_selected_option_value(directory_language_select)
		)
	_refresh_directory_filter_button()
	_refresh_creation_requirements()
	_refresh_membership_state()
	_render_guild_list()
	if not membership.is_empty():
		_render_guild_home()
	if emblem_editor_popup != null and emblem_editor_popup.visible:
		_refresh_emblem_template_controls()
		_refresh_emblem_palette_controls()
		for color_index: int in range(emblem_color_buttons.size()):
			emblem_color_buttons[color_index].text = _t(
				"ui.guild.emblem.color",
				{"number": color_index + 1}
			)


func _icon_rect(icon_size: int, color: Color) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = GUILD_ICON
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _apply_tab_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var background := UI_RAISED if selected else Color("#07111edc")
	var border := UI_ACCENT if selected else UI_BORDER
	button.add_theme_color_override("font_color", UI_TEXT if selected else UI_MUTED)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _tab_style(background, border, selected))
	button.add_theme_stylebox_override("hover", _tab_style(UI_HOVER, UI_ACCENT, selected))
	button.add_theme_stylebox_override("pressed", _tab_style(Color("#0d1730f2"), UI_ACCENT, selected))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_button_style(button: Button, variant: String = "default") -> void:
	var normal_bg := UI_RAISED
	var hover_bg := UI_HOVER
	var pressed_bg := Color("#060e18f2")
	var border := UI_BORDER
	var hover_border := Color("#7aa7f4")
	if variant == "primary":
		normal_bg = Color("#0b2235f2")
		hover_bg = Color("#12334df2")
		pressed_bg = Color("#071624f2")
		border = Color("#4b9dc4cc")
		hover_border = Color("#79d9ff")
	elif variant == "danger":
		normal_bg = Color("#35151bf2")
		hover_bg = Color("#512029f2")
		pressed_bg = Color("#260d12f2")
		border = Color("#b84f5dcc")
		hover_border = Color("#ff8895")
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, 0.45))
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _button_style(pressed_bg, hover_border))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", _button_style(Color("#08111bd0"), Color("#26384b88")))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, 0.7))
	input.add_theme_color_override("caret_color", Color("#79d9ff"))
	input.add_theme_font_size_override("font_size", 13)
	input.add_theme_stylebox_override("normal", _input_style(UI_INPUT, UI_BORDER))
	input.add_theme_stylebox_override("focus", _input_style(Color("#071225f2"), Color("#7aa7f4"), 2))


func _apply_spin_box_style(input: SpinBox) -> void:
	var line_edit := input.get_line_edit()
	if line_edit != null:
		_apply_line_edit_style(line_edit)


func _apply_text_edit_style(input: TextEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, 0.7))
	input.add_theme_color_override("caret_color", Color("#79d9ff"))
	input.add_theme_font_size_override("font_size", 13)
	input.add_theme_stylebox_override("normal", _input_style(UI_INPUT, UI_BORDER))
	input.add_theme_stylebox_override("focus", _input_style(Color("#071225f2"), Color("#7aa7f4"), 2))


func _apply_option_button_style(select: OptionButton) -> void:
	select.add_theme_color_override("font_color", UI_TEXT)
	select.add_theme_color_override("font_hover_color", UI_TEXT)
	select.add_theme_font_size_override("font_size", 12)
	select.add_theme_stylebox_override("normal", _input_style(UI_INPUT, UI_BORDER))
	select.add_theme_stylebox_override("hover", _input_style(UI_HOVER, Color("#7aa7f4")))
	select.add_theme_stylebox_override("pressed", _input_style(Color("#071225f2"), Color("#7aa7f4")))
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	select.focus_mode = Control.FOCUS_NONE
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_popup_menu_style(select.get_popup())


func _apply_guild_window_style(window: Window) -> void:
	var border := _panel_style(UI_SURFACE, UI_ACCENT_SOFT, 11, 1)
	border.content_margin_left = 8
	border.content_margin_top = 30
	border.content_margin_right = 8
	border.content_margin_bottom = 8
	border.shadow_color = Color(0, 0, 0, 0.55)
	border.shadow_size = 18
	border.shadow_offset = Vector2(0, 7)
	window.add_theme_stylebox_override("embedded_border", border)
	window.add_theme_stylebox_override("embedded_unfocused_border", border.duplicate())
	window.add_theme_color_override("title_color", UI_TEXT)
	window.add_theme_font_size_override("title_font_size", 15)


func _apply_guild_confirmation_style(dialog: ConfirmationDialog, ok_variant: String = "primary") -> void:
	_apply_guild_window_style(dialog)
	dialog.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE, UI_ACCENT_SOFT, 10, 1))
	var message := dialog.get_label()
	if message != null:
		message.add_theme_color_override("font_color", UI_TEXT)
		message.add_theme_font_size_override("font_size", 13)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok_button := dialog.get_ok_button()
	var cancel_button := dialog.get_cancel_button()
	_apply_button_style(ok_button, ok_variant)
	_apply_button_style(cancel_button)
	ok_button.focus_mode = Control.FOCUS_ALL
	cancel_button.focus_mode = Control.FOCUS_ALL


func _apply_guild_popup_panel_style(popup: PopupPanel) -> void:
	var panel := _panel_style(UI_SURFACE, UI_ACCENT_SOFT, 11, 1)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 18
	panel.shadow_offset = Vector2(0, 7)
	popup.add_theme_stylebox_override("panel", panel)


func _apply_popup_menu_style(popup: PopupMenu) -> void:
	if popup == null:
		return
	popup.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE, UI_ACCENT_SOFT, 8, 1))
	popup.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, Color("#7aa7f4"), 5, 1))
	popup.add_theme_stylebox_override("separator", _panel_style(UI_BORDER_INNER, UI_BORDER_INNER, 0, 0))
	popup.add_theme_color_override("font_color", UI_TEXT)
	popup.add_theme_color_override("font_hover_color", UI_TEXT)
	popup.add_theme_color_override("font_disabled_color", Color(UI_MUTED.r, UI_MUTED.g, UI_MUTED.b, 0.48))
	popup.add_theme_color_override("font_separator_color", UI_MUTED)
	popup.add_theme_font_size_override("font_size", 12)
	popup.add_theme_constant_override("v_separation", 5)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 10)


func _outer_style() -> StyleBoxFlat:
	var style := _panel_style(UI_BG, UI_ACCENT_SOFT, 13, 1)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.52)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 7)
	return style


func _row_style(accent: Color, selected: bool, background: Color = UI_RAISED) -> StyleBoxFlat:
	var border := accent if selected else Color(accent.r, accent.g, accent.b, 0.42)
	var style := _panel_style(background, border, 9, 1)
	style.border_width_left = 3
	return style


func _tab_style(background: Color, border: Color, selected: bool) -> StyleBoxFlat:
	var style := _button_style(background, border, 7, 1)
	if selected:
		style.border_width_bottom = 2
	return style


func _button_style(background: Color, border: Color, radius: int = 8, width: int = 1) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _emblem_pixel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 1, 1)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _input_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := _panel_style(background, border, 7, width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
