extends PanelContainer

class_name GuildPopup

signal closed

const POPUP_SIZE := Vector2(1040, 700)
const GUILD_ICON: Texture2D = preload("res://assets/ui/guild.svg")
const CREATION_COST := 100000
const REQUIRED_BADGES := 3

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

# Preview-only data. The overlay loads this exclusively in debug builds; release
# builds keep the directory empty until the guild service supplies real entries.
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
var selected_guild_id := 0
var active_page := "browse"
var is_dragging_popup := false

var browse_tab_button: Button
var create_tab_button: Button
var browse_page: Control
var create_page: Control
var search_input: LineEdit
var guild_list: VBoxContainer
var guild_count_label: Label
var detail_content: VBoxContainer
var browse_status_label: Label
var create_status_label: Label
var guild_name_input: LineEdit
var guild_description_input: TextEdit
var money_requirement_label: Label
var badge_requirement_label: Label


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _outer_style())
	_build_ui()


func open() -> void:
	visible = true
	_center_in_viewport()
	_clamp_to_viewport()
	_refresh_creation_requirements()
	_render_guild_list()


func close() -> void:
	is_dragging_popup = false
	visible = false
	closed.emit()


func set_guilds(entries: Array) -> void:
	guilds.clear()
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			guilds.append((entry_value as Dictionary).duplicate(true))
	selected_guild_id = int(guilds[0].get("id", 0)) if not guilds.is_empty() else 0
	_render_guild_list()


func show_debug_preview() -> void:
	set_guilds(DEBUG_GUILDS)
	if browse_status_label != null:
		browse_status_label.text = "Interface preview · guild data is local"
		browse_status_label.visible = true


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
	heading.add_child(_label("Guilds", 22, UI_TEXT))
	heading.add_child(_label("Find your place in the world of Aether", 11, UI_MUTED))

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "Close guilds"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.pressed.connect(close)
	close_button.add_theme_font_size_override("font_size", 19)
	_apply_button_style(close_button)
	header.add_child(close_button)
	return header


func _build_navigation() -> Control:
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 6)

	browse_tab_button = Button.new()
	browse_tab_button.name = "BrowseGuildsButton"
	browse_tab_button.text = "⌕  Browse Guilds"
	browse_tab_button.custom_minimum_size = Vector2(190, 40)
	browse_tab_button.pressed.connect(_show_page.bind("browse"))
	navigation.add_child(browse_tab_button)

	create_tab_button = Button.new()
	create_tab_button.name = "CreateGuildButton"
	create_tab_button.text = "+  Create a Guild"
	create_tab_button.custom_minimum_size = Vector2(190, 40)
	create_tab_button.pressed.connect(_show_page.bind("create"))
	navigation.add_child(create_tab_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	var membership_label := _label("You are not currently in a guild", 11, UI_MUTED)
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

	var heading := HBoxContainer.new()
	directory.add_child(heading)
	var title := _label("GUILD DIRECTORY", 10, UI_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	guild_count_label = _label("0 guilds", 11, UI_MUTED)
	heading.add_child(guild_count_label)

	search_input = LineEdit.new()
	search_input.name = "GuildSearchInput"
	search_input.placeholder_text = "Search by name, language or focus"
	search_input.clear_button_enabled = true
	search_input.custom_minimum_size = Vector2(0, 40)
	search_input.text_changed.connect(_on_search_changed)
	_apply_line_edit_style(search_input)
	directory.add_child(search_input)

	guild_list = VBoxContainer.new()
	guild_list.add_theme_constant_override("separation", 7)
	var guild_scroll := ScrollContainer.new()
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


func _build_create_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var intro := VBoxContainer.new()
	intro.add_theme_constant_override("separation", 2)
	intro.add_child(_label("Create your guild", 20, UI_TEXT))
	intro.add_child(_label("Build a home for your community. You can design a guild emblem later.", 12, UI_MUTED))
	content.add_child(intro)

	var requirements := HBoxContainer.new()
	requirements.add_theme_constant_override("separation", 10)
	content.add_child(requirements)
	var money_card := _requirement_card("POKÉDOLLARS", "$100,000 required", "Creation fee")
	requirements.add_child(money_card.get("control") as Control)
	money_requirement_label = money_card.get("value") as Label
	var badge_card := _requirement_card("GYM BADGES", "%d badges required" % REQUIRED_BADGES, "Trainer progress")
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
	form.add_child(_label("GUILD INFORMATION", 10, UI_ACCENT))

	guild_name_input = LineEdit.new()
	guild_name_input.name = "GuildNameInput"
	guild_name_input.placeholder_text = "Guild name"
	guild_name_input.max_length = 24
	guild_name_input.custom_minimum_size = Vector2(0, 40)
	guild_name_input.text_changed.connect(_on_create_form_changed)
	_apply_line_edit_style(guild_name_input)
	form.add_child(_labeled_field("NAME", guild_name_input, "3–24 characters · must be unique"))

	guild_description_input = TextEdit.new()
	guild_description_input.name = "GuildDescriptionInput"
	guild_description_input.placeholder_text = "Tell trainers what your guild is about..."
	guild_description_input.custom_minimum_size = Vector2(0, 86)
	guild_description_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	guild_description_input.text_changed.connect(_on_create_form_changed)
	_apply_text_edit_style(guild_description_input)
	form.add_child(_labeled_field("DESCRIPTION", guild_description_input, "Shown publicly in the guild directory"))

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	form.add_child(choices)
	choices.add_child(_labeled_field("LANGUAGE", _option_button(["English", "Dutch", "Dutch / English", "German", "French", "Other"])))
	choices.add_child(_labeled_field("FOCUS", _option_button(["Social", "PvE", "PvP", "PvP & Social", "PvE & Social", "Mixed"])))
	choices.add_child(_labeled_field("RECRUITMENT", _option_button(["Applications open", "Open", "Invite only", "Closed"])))

	var emblem_note := PanelContainer.new()
	emblem_note.add_theme_stylebox_override("panel", _panel_style(Color("#0a2133d9"), Color("#3d759699"), 8, 1))
	form.add_child(emblem_note)
	var emblem_margin := MarginContainer.new()
	_set_margins(emblem_margin, 12, 9, 12, 9)
	emblem_note.add_child(emblem_margin)
	var emblem_label := _label(
		"◇  An emblem is optional. After creating your guild, you can open the pixel editor from Guild Settings.",
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
	cancel_button.text = "Back to Guilds"
	cancel_button.custom_minimum_size = Vector2(140, 40)
	cancel_button.pressed.connect(_show_page.bind("browse"))
	_apply_button_style(cancel_button)
	action_row.add_child(cancel_button)
	var create_button := Button.new()
	create_button.name = "SubmitGuildCreationButton"
	create_button.text = "Create Guild"
	create_button.custom_minimum_size = Vector2(150, 40)
	create_button.pressed.connect(_on_create_pressed)
	_apply_button_style(create_button, "primary")
	action_row.add_child(create_button)
	return scroll


func _render_guild_list() -> void:
	if guild_list == null:
		return
	_clear_children(guild_list)
	var filtered := _filtered_guilds()
	guild_count_label.text = "%d guild%s" % [filtered.size(), "" if filtered.size() == 1 else "s"]
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
	button.custom_minimum_size = Vector2(0, 76)
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
	row.add_child(_emblem(50, accent))
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
	var summary := _label(
		"Lv. %d  ·  %d/%d members" % [
			int(guild.get("level", 1)),
			int(guild.get("members", 0)),
			int(guild.get("capacity", 0)),
		],
		11,
		UI_MUTED
	)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(summary)
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
	header.add_child(_emblem(82, accent))
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 3)
	header.add_child(heading)
	heading.add_child(_label(str(guild.get("name", "Unnamed Guild")), 24, UI_TEXT))
	heading.add_child(_label("Led by %s" % str(guild.get("leader", "Unknown")), 12, UI_MUTED))
	header.add_child(_status_pill(str(guild.get("recruitment", "Closed"))))
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", UI_BORDER_INNER)
	detail_content.add_child(divider)

	var metadata := GridContainer.new()
	metadata.columns = 2
	metadata.add_theme_constant_override("h_separation", 9)
	metadata.add_theme_constant_override("v_separation", 9)
	detail_content.add_child(metadata)
	metadata.add_child(_metadata_card("GUILD LEVEL", str(guild.get("level", 1)), accent))
	metadata.add_child(_metadata_card("MEMBERS", "%d / %d" % [int(guild.get("members", 0)), int(guild.get("capacity", 0))], UI_SUCCESS))
	metadata.add_child(_metadata_card("LANGUAGE", str(guild.get("language", "Not set")), UI_ACCENT))
	metadata.add_child(_metadata_card("FOCUS", str(guild.get("focus", "Not set")), UI_GOLD))
	detail_content.add_child(_label("ABOUT THIS GUILD", 10, UI_ACCENT))

	var description_panel := PanelContainer.new()
	description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER_INNER, 9, 1))
	detail_content.add_child(description_panel)
	var description_margin := MarginContainer.new()
	_set_margins(description_margin, 14, 12, 14, 12)
	description_panel.add_child(description_margin)
	var description := _label(str(guild.get("description", "This guild has not added a description yet.")), 13, UI_TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_margin.add_child(description)
	detail_content.add_child(_label("Official guild forum pages will be linked here in the future.", 10, UI_MUTED))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	detail_content.add_child(actions)
	var forum_button := Button.new()
	forum_button.name = "GuildForumButton"
	forum_button.text = "Guild Forum"
	forum_button.tooltip_text = "Official guild forum pages are coming later"
	forum_button.disabled = true
	forum_button.custom_minimum_size = Vector2(132, 40)
	_apply_button_style(forum_button)
	actions.add_child(forum_button)
	var apply_button := Button.new()
	apply_button.name = "GuildApplyButton"
	var recruitment := str(guild.get("recruitment", "Closed"))
	apply_button.text = _application_button_text(recruitment)
	apply_button.disabled = recruitment.to_lower() in ["closed", "invite only"]
	apply_button.custom_minimum_size = Vector2(150, 40)
	apply_button.pressed.connect(_on_application_pressed.bind(guild))
	_apply_button_style(apply_button, "primary")
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
	var title := _label("No guild selected", 18, UI_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(title)
	var message := _label("Search the guild directory or create a new guild to begin building your community.", 12, UI_MUTED)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.add_child(message)
	var create_button := Button.new()
	create_button.text = "Create a Guild"
	create_button.custom_minimum_size = Vector2(160, 40)
	create_button.pressed.connect(_show_page.bind("create"))
	_apply_button_style(create_button, "primary")
	empty.add_child(create_button)


func _directory_empty_state() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 150)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#07111edc"), UI_BORDER_INNER, 9, 1))
	var text := "No guilds match your search." if search_input.text.strip_edges() != "" else "The guild directory is empty.\nBe the first trainer to create one."
	var label := _label(text, 12, UI_MUTED)
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


func _status_pill(status: String) -> Control:
	var color := UI_SUCCESS if status.to_lower() in ["open", "applications open"] else UI_WARNING
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(color.r, color.g, color.b, 0.10), Color(color.r, color.g, color.b, 0.62), 9, 1))
	var margin := MarginContainer.new()
	_set_margins(margin, 10, 5, 10, 5)
	panel.add_child(margin)
	margin.add_child(_label(status, 11, color))
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
		select.add_item(option)
	_apply_option_button_style(select)
	return select


func _show_page(page: String) -> void:
	active_page = page if page in ["browse", "create"] else "browse"
	if browse_page != null:
		browse_page.visible = active_page == "browse"
	if create_page != null:
		create_page.visible = active_page == "create"
	_apply_tab_style(browse_tab_button, active_page == "browse")
	_apply_tab_style(create_tab_button, active_page == "create")
	if active_page == "create":
		_refresh_creation_requirements()


func _select_guild(guild_id: int) -> void:
	selected_guild_id = guild_id
	_render_guild_list()


func _on_search_changed(_query: String) -> void:
	_render_guild_list()


func _on_application_pressed(guild: Dictionary) -> void:
	browse_status_label.text = "Applications for %s will become available when the guild service is connected." % str(guild.get("name", "this guild"))
	browse_status_label.visible = true


func _on_create_form_changed(_unused: Variant = null) -> void:
	if create_status_label != null:
		create_status_label.text = ""


func _on_create_pressed() -> void:
	var guild_name := guild_name_input.text.strip_edges()
	var description := guild_description_input.text.strip_edges()
	if guild_name.length() < 3:
		_set_create_status("Choose a guild name with at least 3 characters.", true)
		return
	if description.length() < 12:
		_set_create_status("Tell trainers a little more about your guild.", true)
		return
	if _player_money() < CREATION_COST:
		_set_create_status("You need $100,000 to create a guild.", true)
		return
	if _player_badge_count() < REQUIRED_BADGES:
		_set_create_status("You need at least %d Gym Badges to create a guild." % REQUIRED_BADGES, true)
		return
	_set_create_status("Guild creation is ready for backend integration; no Pokédollars were deducted.", false)


func _refresh_creation_requirements() -> void:
	if money_requirement_label == null:
		return
	var current_money := _player_money()
	var has_money := current_money >= CREATION_COST
	money_requirement_label.text = "$%s / $%s" % [_format_number(current_money), _format_number(CREATION_COST)]
	money_requirement_label.add_theme_color_override("font_color", UI_SUCCESS if has_money else UI_TEXT)
	if badge_requirement_label != null:
		var current_badges := _player_badge_count()
		badge_requirement_label.text = "%d / %d badges" % [current_badges, REQUIRED_BADGES]
		badge_requirement_label.add_theme_color_override(
			"font_color",
			UI_SUCCESS if current_badges >= REQUIRED_BADGES else UI_TEXT
		)


func _set_create_status(message: String, is_error: bool) -> void:
	create_status_label.text = message
	create_status_label.add_theme_color_override("font_color", UI_WARNING if is_error else UI_SUCCESS)


func _filtered_guilds() -> Array[Dictionary]:
	var query := search_input.text.strip_edges().to_lower() if search_input != null else ""
	if query == "":
		return guilds.duplicate()
	var matches: Array[Dictionary] = []
	for guild: Dictionary in guilds:
		var searchable := " ".join([
			str(guild.get("name", "")),
			str(guild.get("language", "")),
			str(guild.get("focus", "")),
			str(guild.get("description", "")),
		]).to_lower()
		if searchable.contains(query):
			matches.append(guild)
	return matches


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


func _application_button_text(recruitment: String) -> String:
	match recruitment.to_lower():
		"open":
			return "Join Guild"
		"applications open":
			return "Apply to Guild"
		"invite only":
			return "Invite Only"
		_:
			return "Recruitment Closed"


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
