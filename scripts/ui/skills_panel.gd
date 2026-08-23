extends Control

class_name SkillsPanel

const PANEL_BACKGROUND := Color("#050b14f5")
const PANEL_BORDER := Color("#345b79cc")
const CARD_BACKGROUND := Color("#081522eb")
const CARD_HOVER := Color("#112a44f2")
const CARD_SELECTED := Color("#0b2940f2")
const CARD_SELECTED_BORDER := Color("#58c8ebdd")
const TEXT_COLOR := Color("#f4f0de")
const MUTED_TEXT_COLOR := Color("#aeb8c5")
const ACCENT_COLOR := Color("#70d8f6")
const GOLD_COLOR := Color("#f3cf70")
const SUCCESS_COLOR := Color("#79d99b")
const LOCKED_COLOR := Color("#738092")
const COMPLETE_COLOR := Color("#84a0b8")
const FISHING_ICON: Texture2D = preload("res://assets/ui/fishing_rod.svg")
const THIEVING_ICON: Texture2D = preload("res://assets/ui/thieving.svg")
const ROCK_SMASH_ICON: Texture2D = preload("res://assets/ui/rock_smash_skill_icon.tres")
const WINDOW_PREFERRED_SIZE := Vector2(760, 780)
const WINDOW_MINIMUM_SIZE := Vector2(480, 420)
const WINDOW_EDGE_MARGIN := 12.0
const DETAIL_GRID_MINIMUM_WIDTH := 700.0

var main_panel: PanelContainer
var window_header: HBoxContainer
var title_label: Label
var subtitle_label: Label
var back_button: Button
var close_button: Button
var status_label: Label
var overview_panel: VBoxContainer
var overview_summary_label: Label
var overview_hint_label: Label
var overview_scroll: ScrollContainer
var skill_cards: GridContainer
var detail_panel: PanelContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_description: Label
var detail_level: Label
var experience_bar: ProgressBar
var experience_label: Label
var stats_label: Label
var wanted_section: VBoxContainer
var wanted_title_label: Label
var wanted_value_label: Label
var wanted_bar: ProgressBar
var detail_tabs: HBoxContainer
var progression_tab_button: Button
var catalog_tab_button: Button
var progression_section: VBoxContainer
var unlocks_scroll: ScrollContainer
var unlocks_container: GridContainer
var targets_section: VBoxContainer
var targets_summary_label: Label
var targets_reset_label: Label
var area_selector: OptionButton
var area_selector_spacing: Control
var targets_scroll: ScrollContainer
var targets_container: GridContainer
var fishing_catalog_section: VBoxContainer
var fishing_catalog_summary: Label
var fishing_area_selector: OptionButton
var fishing_area_spacing: Control
var fishing_rod_filters: HBoxContainer
var fishing_catalog_scroll: ScrollContainer
var fishing_catalog_container: GridContainer
var skill_buttons: Dictionary = {}
var selected_skill_id := "thieving"
var selected_detail_tab := "progression"
var selected_rod_id := "old_rod"
var selected_fishing_area_id := ""
var selected_target_town_key := ""
var target_town_order: Array[String] = []
var targets_by_town: Dictionary = {}
var showing_detail := false
var loading := false
var window_dragging := false


func _ready() -> void:
	_build_interface()
	resized.connect(_on_window_resized)
	var parent_control := get_parent_control()
	if parent_control != null:
		parent_control.resized.connect(_fit_window_to_parent)
	_fit_window_to_parent()
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	if not SkillsService.state_changed.is_connected(_on_skills_changed):
		SkillsService.state_changed.connect(_on_skills_changed)
	if not SkillsService.fishing_catalog_changed.is_connected(_on_fishing_catalog_changed):
		SkillsService.fishing_catalog_changed.connect(_on_fishing_catalog_changed)
	_refresh_localized_content()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if showing_detail:
			_show_overview()
		else:
			close_manager()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not window_dragging:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			window_dragging = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		position += (event as InputEventMouseMotion).relative
		_clamp_window_to_parent()
		get_viewport().set_input_as_handled()


func toggle_manager() -> void:
	if visible:
		close_manager()
	else:
		open_manager()


func open_manager() -> void:
	_fit_window_to_parent()
	visible = true
	showing_detail = false
	_render_skills(SkillsService.get_skills())
	_load_skills()


func close_manager() -> void:
	window_dragging = false
	visible = false


func is_manager_open() -> bool:
	return visible


func _load_skills() -> void:
	if loading:
		return
	loading = true
	status_label.visible = true
	status_label.text = _text("ui.skills.loading")
	var result: Dictionary = await SkillsService.load_skills(_current_area_id())
	loading = false
	if not visible:
		return
	if bool(result.get("success", false)):
		status_label.visible = false
		return
	status_label.visible = true
	status_label.text = _text("ui.skills.load_failed")


func _build_interface() -> void:
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var main_style := _make_panel_style(PANEL_BACKGROUND, PANEL_BORDER, 12, 1)
	main_style.shadow_color = Color("#00081499")
	main_style.shadow_size = 10
	main_style.shadow_offset = Vector2(0, 4)
	main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(main_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	main_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	window_header = HBoxContainer.new()
	window_header.name = "WindowHeader"
	window_header.add_theme_constant_override("separation", 10)
	window_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	window_header.gui_input.connect(_on_window_header_gui_input)
	content.add_child(window_header)

	back_button = Button.new()
	back_button.visible = false
	back_button.custom_minimum_size = Vector2(108, 34)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.add_theme_color_override("font_color", ACCENT_COLOR)
	back_button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	back_button.add_theme_stylebox_override("normal", _make_panel_style(CARD_BACKGROUND, PANEL_BORDER, 7, 1))
	back_button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
	back_button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
	back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_button.pressed.connect(_show_overview)
	window_header.add_child(back_button)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.mouse_default_cursor_shape = Control.CURSOR_MOVE
	heading.gui_input.connect(_on_window_header_gui_input)
	window_header.add_child(heading)

	title_label = Label.new()
	title_label.add_theme_color_override("font_color", TEXT_COLOR)
	title_label.add_theme_font_size_override("font_size", 20)
	heading.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	subtitle_label.add_theme_font_size_override("font_size", 11)
	heading.add_child(subtitle_label)

	close_button = Button.new()
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	close_button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close_button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, PANEL_BORDER, 7, 1))
	close_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(close_manager)
	window_header.add_child(close_button)

	status_label = Label.new()
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	status_label.add_theme_font_size_override("font_size", 11)
	content.add_child(status_label)

	overview_panel = VBoxContainer.new()
	overview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_panel.add_theme_constant_override("separation", 12)
	content.add_child(overview_panel)

	var overview_header := HBoxContainer.new()
	overview_header.add_theme_constant_override("separation", 12)
	overview_panel.add_child(overview_header)

	var overview_copy := VBoxContainer.new()
	overview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_copy.add_theme_constant_override("separation", 2)
	overview_header.add_child(overview_copy)

	overview_summary_label = Label.new()
	overview_summary_label.add_theme_color_override("font_color", TEXT_COLOR)
	overview_summary_label.add_theme_font_size_override("font_size", 13)
	overview_copy.add_child(overview_summary_label)

	overview_hint_label = Label.new()
	overview_hint_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	overview_hint_label.add_theme_font_size_override("font_size", 10)
	overview_copy.add_child(overview_hint_label)

	overview_scroll = ScrollContainer.new()
	overview_scroll.name = "SkillsOverviewScroll"
	overview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overview_panel.add_child(overview_scroll)

	skill_cards = GridContainer.new()
	skill_cards.columns = 1
	skill_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_cards.add_theme_constant_override("v_separation", 9)
	overview_scroll.add_child(skill_cards)

	detail_panel = PanelContainer.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_panel_style(CARD_BACKGROUND, PANEL_BORDER, 10, 1))
	content.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(detail_margin)

	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 8)
	detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(detail_content)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 10)
	detail_content.add_child(detail_header)

	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(52, 52)
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_header.add_child(detail_icon)

	var detail_heading := VBoxContainer.new()
	detail_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_heading.add_theme_constant_override("separation", 1)
	detail_header.add_child(detail_heading)

	detail_name = Label.new()
	detail_name.add_theme_color_override("font_color", TEXT_COLOR)
	detail_name.add_theme_font_size_override("font_size", 17)
	detail_heading.add_child(detail_name)

	detail_description = Label.new()
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	detail_description.add_theme_font_size_override("font_size", 10)
	detail_heading.add_child(detail_description)

	detail_level = Label.new()
	detail_level.custom_minimum_size = Vector2(74, 36)
	detail_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_level.add_theme_color_override("font_color", GOLD_COLOR)
	detail_level.add_theme_font_size_override("font_size", 15)
	detail_level.add_theme_stylebox_override("normal", _make_panel_style(Color("#211c0deb"), Color("#8c7436cc"), 8, 1))
	detail_header.add_child(detail_level)

	experience_bar = ProgressBar.new()
	experience_bar.custom_minimum_size.y = 20.0
	experience_bar.show_percentage = false
	experience_bar.min_value = 0.0
	experience_bar.max_value = 100.0
	experience_bar.add_theme_stylebox_override("background", _make_panel_style(Color("#030810"), Color("#263b50"), 5, 1))
	experience_bar.add_theme_stylebox_override("fill", _make_panel_style(Color("#237ca8"), ACCENT_COLOR, 5, 1))
	detail_content.add_child(experience_bar)

	experience_label = Label.new()
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	experience_label.add_theme_font_size_override("font_size", 10)
	detail_content.add_child(experience_label)

	detail_tabs = HBoxContainer.new()
	detail_tabs.add_theme_constant_override("separation", 6)
	detail_content.add_child(detail_tabs)

	progression_tab_button = _create_detail_tab_button("progression")
	progression_tab_button.pressed.connect(_select_detail_tab.bind("progression"))
	detail_tabs.add_child(progression_tab_button)

	catalog_tab_button = _create_detail_tab_button("catalog")
	catalog_tab_button.pressed.connect(_select_detail_tab.bind("catalog"))
	detail_tabs.add_child(catalog_tab_button)

	progression_section = VBoxContainer.new()
	progression_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progression_section.add_theme_constant_override("separation", 8)
	detail_content.add_child(progression_section)

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_color_override("font_color", TEXT_COLOR)
	stats_label.add_theme_font_size_override("font_size", 11)
	progression_section.add_child(stats_label)

	wanted_section = VBoxContainer.new()
	wanted_section.name = "WantedSection"
	wanted_section.add_theme_constant_override("separation", 4)
	progression_section.add_child(wanted_section)

	var wanted_header := HBoxContainer.new()
	wanted_section.add_child(wanted_header)

	wanted_title_label = Label.new()
	wanted_title_label.name = "WantedTitle"
	wanted_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wanted_title_label.add_theme_color_override("font_color", GOLD_COLOR)
	wanted_title_label.add_theme_font_size_override("font_size", 10)
	wanted_header.add_child(wanted_title_label)

	wanted_value_label = Label.new()
	wanted_value_label.name = "WantedValue"
	wanted_value_label.add_theme_font_size_override("font_size", 11)
	wanted_header.add_child(wanted_value_label)

	wanted_bar = ProgressBar.new()
	wanted_bar.name = "WantedBar"
	wanted_bar.custom_minimum_size.y = 16.0
	wanted_bar.show_percentage = false
	wanted_bar.min_value = 0.0
	wanted_bar.max_value = 100.0
	wanted_bar.add_theme_stylebox_override("background", _make_panel_style(Color("#030810"), Color("#263b50"), 5, 1))
	wanted_section.add_child(wanted_bar)

	var unlock_title := Label.new()
	unlock_title.name = "UnlockTitle"
	unlock_title.add_theme_color_override("font_color", ACCENT_COLOR)
	unlock_title.add_theme_font_size_override("font_size", 12)
	progression_section.add_child(unlock_title)

	unlocks_scroll = ScrollContainer.new()
	unlocks_scroll.name = "UnlocksScroll"
	unlocks_scroll.custom_minimum_size.y = 90.0
	unlocks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unlocks_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	unlocks_scroll.resized.connect(_update_unlock_grid_columns)
	progression_section.add_child(unlocks_scroll)

	unlocks_container = GridContainer.new()
	unlocks_container.name = "UnlocksContainer"
	unlocks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlocks_container.add_theme_constant_override("h_separation", 6)
	unlocks_container.add_theme_constant_override("v_separation", 6)
	unlocks_scroll.add_child(unlocks_container)

	targets_section = VBoxContainer.new()
	targets_section.name = "TargetsSection"
	targets_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	targets_section.add_theme_constant_override("separation", 5)
	detail_content.add_child(targets_section)

	var targets_header := HBoxContainer.new()
	targets_section.add_child(targets_header)

	var targets_title := Label.new()
	targets_title.name = "TargetsTitle"
	targets_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_title.add_theme_color_override("font_color", ACCENT_COLOR)
	targets_title.add_theme_font_size_override("font_size", 12)
	targets_header.add_child(targets_title)

	targets_summary_label = Label.new()
	targets_summary_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	targets_summary_label.add_theme_font_size_override("font_size", 10)
	targets_header.add_child(targets_summary_label)

	targets_reset_label = Label.new()
	targets_reset_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	targets_reset_label.add_theme_font_size_override("font_size", 9)
	targets_section.add_child(targets_reset_label)

	area_selector = OptionButton.new()
	area_selector.name = "AreaSelector"
	area_selector.custom_minimum_size.y = 40.0
	area_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_selector.fit_to_longest_item = false
	area_selector.alignment = HORIZONTAL_ALIGNMENT_LEFT
	area_selector.clip_text = true
	area_selector.item_selected.connect(_select_area)
	_style_area_selector(area_selector)
	targets_section.add_child(area_selector)

	area_selector_spacing = Control.new()
	area_selector_spacing.name = "AreaSelectorSpacing"
	area_selector_spacing.custom_minimum_size.y = 6.0
	area_selector_spacing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	targets_section.add_child(area_selector_spacing)

	targets_scroll = ScrollContainer.new()
	targets_scroll.name = "TargetsScroll"
	targets_scroll.custom_minimum_size.y = 120.0
	targets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	targets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	targets_section.add_child(targets_scroll)

	targets_container = GridContainer.new()
	targets_container.name = "TargetsContainer"
	targets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_container.add_theme_constant_override("h_separation", 6)
	targets_container.add_theme_constant_override("v_separation", 5)
	targets_scroll.add_child(targets_container)

	fishing_catalog_section = VBoxContainer.new()
	fishing_catalog_section.visible = false
	fishing_catalog_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fishing_catalog_section.add_theme_constant_override("separation", 7)
	detail_content.add_child(fishing_catalog_section)

	fishing_area_selector = OptionButton.new()
	fishing_area_selector.name = "FishingAreaSelector"
	fishing_area_selector.custom_minimum_size.y = 40.0
	fishing_area_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fishing_area_selector.fit_to_longest_item = false
	fishing_area_selector.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fishing_area_selector.clip_text = true
	fishing_area_selector.item_selected.connect(_select_fishing_area)
	_style_area_selector(fishing_area_selector)
	fishing_catalog_section.add_child(fishing_area_selector)

	fishing_area_spacing = Control.new()
	fishing_area_spacing.name = "FishingAreaSpacing"
	fishing_area_spacing.custom_minimum_size.y = 6.0
	fishing_area_spacing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fishing_catalog_section.add_child(fishing_area_spacing)

	fishing_rod_filters = HBoxContainer.new()
	fishing_rod_filters.add_theme_constant_override("separation", 5)
	fishing_catalog_section.add_child(fishing_rod_filters)

	var catalog_header := HBoxContainer.new()
	catalog_header.add_theme_constant_override("separation", 8)
	fishing_catalog_section.add_child(catalog_header)

	fishing_catalog_summary = Label.new()
	fishing_catalog_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fishing_catalog_summary.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	fishing_catalog_summary.add_theme_font_size_override("font_size", 10)
	catalog_header.add_child(fishing_catalog_summary)

	fishing_catalog_scroll = ScrollContainer.new()
	fishing_catalog_scroll.name = "FishingCatalogScroll"
	fishing_catalog_scroll.custom_minimum_size.y = 120.0
	fishing_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fishing_catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fishing_catalog_scroll.resized.connect(_update_fishing_catalog_grid_columns)
	fishing_catalog_section.add_child(fishing_catalog_scroll)

	fishing_catalog_container = GridContainer.new()
	fishing_catalog_container.name = "FishingCatalogContainer"
	fishing_catalog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fishing_catalog_container.add_theme_constant_override("h_separation", 6)
	fishing_catalog_container.add_theme_constant_override("v_separation", 5)
	fishing_catalog_scroll.add_child(fishing_catalog_container)

	_render_skills([])


func _render_skills(skills: Array) -> void:
	for child: Node in skill_cards.get_children():
		skill_cards.remove_child(child)
		child.queue_free()
	skill_buttons.clear()

	if skills.is_empty():
		overview_summary_label.text = ""
		overview_hint_label.text = ""
		overview_panel.visible = true
		detail_panel.visible = false
		return
	var unlocked_count := 0
	var total_level := 0
	for skill_value: Variant in skills:
		var summary_skill := skill_value as Dictionary
		if bool(summary_skill.get("unlocked", true)):
			unlocked_count += 1
			total_level += maxi(int(summary_skill.get("level", 1)), 1)
	overview_summary_label.text = _text("ui.skills.overview.summary", {
		"unlocked": unlocked_count,
		"total": skills.size(),
		"level": total_level,
	})
	overview_hint_label.text = _text("ui.skills.overview.hint")
	if not _has_skill(skills, selected_skill_id):
		selected_skill_id = str((skills[0] as Dictionary).get("id", ""))
	for skill_value: Variant in skills:
		var skill := skill_value as Dictionary
		var skill_id := str(skill.get("id", ""))
		var button := _create_skill_overview_card(skill)
		skill_cards.add_child(button)
		skill_buttons[skill_id] = button
	if showing_detail:
		overview_panel.visible = false
		detail_panel.visible = true
		back_button.visible = true
		_render_detail(SkillsService.get_skill(selected_skill_id))
	else:
		overview_panel.visible = true
		detail_panel.visible = false
		back_button.visible = false


func _create_skill_overview_card(skill: Dictionary) -> Button:
	var skill_id := str(skill.get("id", ""))
	var skill_unlocked := bool(skill.get("unlocked", true))
	var level := maxi(int(skill.get("level", 1)), 1)
	var max_level := maxi(int(skill.get("maxLevel", 100)), level)
	var accent := _skill_accent_color(skill_id) if skill_unlocked else LOCKED_COLOR
	var button := Button.new()
	button.name = "%sSkillCard" % skill_id.to_pascal_case()
	button.custom_minimum_size = Vector2(0, 154)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_panel_style(CARD_BACKGROUND, _with_alpha(accent, 0.55), 10, 1))
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, accent, 10, 1))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, accent, 10, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_select_skill.bind(skill_id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 13)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(66, 66)
	icon_frame.add_theme_stylebox_override("panel", _make_panel_style(_with_alpha(accent, 0.10), _with_alpha(accent, 0.42), 9, 1))
	row.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(52, 52)
	icon.texture = _skill_icon(skill_id)
	icon.modulate = Color.WHITE if skill_unlocked else Color("#788492")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.add_child(icon)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)

	var card_header := HBoxContainer.new()
	card_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(card_header)

	var name_label := Label.new()
	name_label.name = "SkillName"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = _text(str(skill.get("nameKey", "ui.skills.%s.name" % skill_id)))
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 15)
	card_header.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "SkillLevel"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = _text("ui.skills.level", {"level": level}) if skill_unlocked else "🔒 %s" % _text("ui.skills.locked")
	level_label.add_theme_color_override("font_color", accent)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_stylebox_override("normal", _make_panel_style(_with_alpha(accent, 0.12), _with_alpha(accent, 0.55), 7, 1))
	card_header.add_child(level_label)

	var description := Label.new()
	description.name = "SkillDescription"
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.text = _text(str(skill.get("descriptionKey", "ui.skills.%s.description" % skill_id)))
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	description.add_theme_font_size_override("font_size", 10)
	copy.add_child(description)

	var progress := ProgressBar.new()
	progress.name = "SkillProgress"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.custom_minimum_size.y = 12.0
	progress.show_percentage = false
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = clampf(float(skill.get("progressPercent", 0.0)), 0.0, 100.0) if skill_unlocked else 0.0
	progress.add_theme_stylebox_override("background", _make_panel_style(Color("#030810"), Color("#263b50"), 4, 1))
	progress.add_theme_stylebox_override("fill", _make_panel_style(_with_alpha(accent, 0.72), accent, 4, 1))
	copy.add_child(progress)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(footer)

	var progress_label := Label.new()
	progress_label.name = "SkillProgressLabel"
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not skill_unlocked:
		progress_label.text = _text(str(skill.get("unlockHintKey", "ui.skills.%s.unlock_hint" % skill_id)))
	elif level >= max_level:
		progress_label.text = _text("ui.skills.max_level")
	else:
		progress_label.text = _text("ui.skills.overview.xp", {
			"current": maxi(int(skill.get("experienceIntoLevel", 0)), 0),
			"required": maxi(int(skill.get("experienceForNextLevel", 0)), 0),
		})
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	progress_label.add_theme_font_size_override("font_size", 10)
	footer.add_child(progress_label)

	var action_label := Label.new()
	action_label.name = "SkillAction"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.text = "%s  →" % _text("ui.skills.overview.open")
	action_label.add_theme_color_override("font_color", accent)
	action_label.add_theme_font_size_override("font_size", 10)
	footer.add_child(action_label)
	return button


func _skill_accent_color(skill_id: String) -> Color:
	match skill_id:
		"thieving":
			return Color("#c39af4")
		"rock_smash":
			return GOLD_COLOR
		_:
			return ACCENT_COLOR


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _render_detail(skill: Dictionary) -> void:
	if skill.is_empty():
		detail_panel.visible = false
		return
	detail_panel.visible = true
	var skill_id := str(skill.get("id", ""))
	var level := maxi(int(skill.get("level", 1)), 1)
	var max_level := maxi(int(skill.get("maxLevel", 100)), level)
	var skill_unlocked := bool(skill.get("unlocked", true))
	detail_icon.texture = _skill_icon(skill_id)
	detail_icon.modulate = Color.WHITE if skill_unlocked else Color("#788492")
	detail_name.text = _text(str(skill.get("nameKey", "ui.skills.%s.name" % skill_id)))
	detail_description.text = _text(str(skill.get("descriptionKey", "ui.skills.%s.description" % skill_id)))
	detail_level.text = (
		_text("ui.skills.level", {"level": level})
		if skill_unlocked
		else "🔒 %s" % _text("ui.skills.locked")
	)
	experience_bar.visible = skill_unlocked
	experience_label.visible = skill_unlocked
	var unlock_title := main_panel.find_child("UnlockTitle", true, false) as Label
	if unlock_title != null:
		unlock_title.visible = skill_unlocked
	unlocks_scroll.visible = skill_unlocked
	if not skill_unlocked:
		stats_label.text = _text(str(skill.get("unlockHintKey", "ui.skills.%s.unlock_hint" % skill_id)))
		wanted_section.visible = false
		targets_section.visible = false
		detail_tabs.visible = false
		progression_section.visible = true
		fishing_catalog_section.visible = false
		return
	experience_bar.value = clampf(float(skill.get("progressPercent", 0.0)), 0.0, 100.0)
	if level >= max_level:
		experience_label.text = _text("ui.skills.max_level")
	else:
		experience_label.text = _text("ui.skills.xp_progress", {
			"current": maxi(int(skill.get("experienceIntoLevel", 0)), 0),
			"required": maxi(int(skill.get("experienceForNextLevel", 0)), 0),
			"total": maxi(int(skill.get("totalExperience", 0)), 0),
		})
	var stats := skill.get("stats", {}) as Dictionary
	stats_label.text = _stats_text(skill_id, stats)
	var targets_title := main_panel.find_child("TargetsTitle", true, false) as Label
	if targets_title != null:
		targets_title.text = _text(
			"ui.skills.rock_smash.rocks.title"
			if skill_id == "rock_smash"
			else "ui.skills.thieving.targets.title"
		)
	wanted_section.visible = skill_id == "thieving"
	if wanted_section.visible:
		_render_wanted_meter(stats)
	_render_unlocks(skill.get("unlocks", []) as Array)
	if skill_id == "thieving":
		_render_targets(skill.get("targets", []) as Array)
	elif skill_id == "rock_smash":
		_render_rocks(skill.get("rocks", []) as Array)
	_update_target_grid_columns()
	detail_tabs.visible = skill_id in ["fishing", "thieving", "rock_smash"]
	catalog_tab_button.text = (
		_text("ui.skills.thieving.targets.tab")
		if skill_id == "thieving"
		else (
			_text("ui.skills.rock_smash.rocks.tab")
			if skill_id == "rock_smash"
			else _text("ui.skills.fishing.catalog.title")
		)
	)
	_render_detail_tab(skill)


func _create_detail_tab_button(tab_id: String) -> Button:
	var button := Button.new()
	button.name = "%sTab" % tab_id.capitalize()
	button.custom_minimum_size = Vector2(150, 31)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _select_detail_tab(tab_id: String) -> void:
	selected_detail_tab = tab_id
	_render_detail(SkillsService.get_skill(selected_skill_id))


func _render_detail_tab(skill: Dictionary) -> void:
	var skill_id := str(skill.get("id", ""))
	var show_catalog := skill_id == "fishing" and selected_detail_tab == "catalog"
	var show_targets := skill_id in ["thieving", "rock_smash"] and selected_detail_tab == "catalog"
	progression_section.visible = not show_catalog and not show_targets
	fishing_catalog_section.visible = show_catalog
	targets_section.visible = show_targets
	_style_detail_tab(progression_tab_button, not show_catalog and not show_targets)
	_style_detail_tab(catalog_tab_button, show_catalog or show_targets)
	if show_catalog:
		_render_fishing_catalog(skill)


func _style_detail_tab(button: Button, selected: bool) -> void:
	button.add_theme_color_override("font_color", TEXT_COLOR if selected else MUTED_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(CARD_SELECTED if selected else Color("#07111c"), CARD_SELECTED_BORDER if selected else PANEL_BORDER, 7, 1)
	)
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))


func _render_fishing_catalog(skill: Dictionary) -> void:
	for child: Node in fishing_rod_filters.get_children():
		fishing_rod_filters.remove_child(child)
		child.queue_free()
	for child: Node in fishing_catalog_container.get_children():
		fishing_catalog_container.remove_child(child)
		child.queue_free()

	var catalog := SkillsService.get_fishing_catalog()
	var rods_value: Variant = catalog.get("rods", [])
	var rods: Array = rods_value as Array if rods_value is Array else []
	var fishing_level := maxi(int(skill.get("level", 1)), 1)
	if rods.is_empty():
		fishing_area_selector.clear()
		fishing_area_selector.disabled = true
		fishing_catalog_summary.text = ""
		fishing_catalog_container.columns = 1
		var empty_label := Label.new()
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
		empty_label.text = _text("ui.skills.fishing.catalog.unavailable")
		fishing_catalog_container.add_child(empty_label)
		return

	_render_fishing_area_selector(rods)
	if not _catalog_has_rod(rods, selected_rod_id):
		selected_rod_id = str((rods[0] as Dictionary).get("id", "old_rod"))
	var selected_rod: Dictionary = {}
	for rod_index in range(rods.size()):
		var rod := rods[rod_index] as Dictionary
		var rod_id := str(rod.get("id", ""))
		var rod_available := int((skill.get("stats", {}) as Dictionary).get("activeTier", 0)) >= rod_index + 1
		var filter := Button.new()
		filter.custom_minimum_size = Vector2(0, 30)
		filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filter.focus_mode = Control.FOCUS_NONE
		filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		filter.text = "%s%s" % ["" if rod_available else "🔒  ", _rod_name(rod_id, str(rod.get("name", rod_id)))]
		filter.add_theme_font_size_override("font_size", 10)
		filter.add_theme_color_override("font_color", TEXT_COLOR if rod_id == selected_rod_id else MUTED_TEXT_COLOR)
		filter.add_theme_stylebox_override(
			"normal",
			_make_panel_style(CARD_SELECTED if rod_id == selected_rod_id else Color("#07111c"), CARD_SELECTED_BORDER if rod_id == selected_rod_id else PANEL_BORDER, 7, 1)
		)
		filter.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
		filter.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
		filter.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		filter.pressed.connect(_select_fishing_rod.bind(rod_id))
		fishing_rod_filters.add_child(filter)
		if rod_id == selected_rod_id:
			selected_rod = rod

	var entries_value: Variant = selected_rod.get("entries", [])
	var entries: Array = entries_value as Array if entries_value is Array else []
	var selected_rod_tier := _catalog_rod_tier(rods, selected_rod_id)
	var active_tier := maxi(int((skill.get("stats", {}) as Dictionary).get("activeTier", 0)), 0)
	var filtered_entries: Array[Dictionary] = []
	for entry_value: Variant in entries:
		if entry_value is Dictionary and _entry_is_in_fishing_area(entry_value as Dictionary, selected_fishing_area_id):
			filtered_entries.append(entry_value as Dictionary)
	fishing_catalog_summary.text = _text("ui.skills.fishing.catalog.area_summary", {
		"count": filtered_entries.size(),
		"rod": _rod_name(selected_rod_id, str(selected_rod.get("name", selected_rod_id))),
		"level": fishing_level,
	})
	if filtered_entries.is_empty():
		var empty_area_label := Label.new()
		empty_area_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_area_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
		empty_area_label.text = _text("ui.skills.fishing.catalog.area_empty")
		fishing_catalog_container.add_child(empty_area_label)
	else:
		for entry: Dictionary in filtered_entries:
			fishing_catalog_container.add_child(
				_create_fishing_catalog_row(
					entry,
					fishing_level,
					active_tier >= selected_rod_tier,
					selected_fishing_area_id
				)
			)
	_update_fishing_catalog_grid_columns()


func _create_fishing_catalog_row(
	entry: Dictionary,
	fishing_level: int,
	rod_available: bool,
	area_id: String
) -> Control:
	var required_level := maxi(int(entry.get("requiredFishingLevel", 1)), 1)
	var available := rod_available and fishing_level >= required_level
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 58.0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color("#07111ceb"), Color("#326b74") if available else Color("#263746"), 8, 1)
	)
	row.tooltip_text = _catalog_locations_tooltip(entry)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	row.add_child(content)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = PokemonAssets.load_party_icon(str(entry.get("species", "")))
	icon.modulate = Color.WHITE if available else Color("#8793a0a8")
	content.add_child(icon)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 1)
	content.add_child(identity)

	var name_label := Label.new()
	name_label.add_theme_color_override("font_color", TEXT_COLOR if available else COMPLETE_COLOR)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.text = str(entry.get("species", "Unknown"))
	identity.add_child(name_label)

	var level_label := Label.new()
	level_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.text = _text("ui.skills.fishing.catalog.levels", {
		"fishing": required_level,
		"pokemon": _pokemon_level_range(entry),
	})
	identity.add_child(level_label)

	var location_label := Label.new()
	location_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	location_label.add_theme_font_size_override("font_size", 9)
	location_label.text = _fishing_area_name(area_id) if area_id != "" else _catalog_regions(entry)
	identity.add_child(location_label)

	var status := Label.new()
	status.custom_minimum_size = Vector2(108, 28)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 9)
	if available:
		status.text = _text("ui.skills.fishing.catalog.available")
		status.add_theme_color_override("font_color", SUCCESS_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#0b241a"), Color("#397858"), 7, 1))
	elif not rod_available:
		status.text = _text("ui.skills.fishing.catalog.rod_locked")
		status.add_theme_color_override("font_color", LOCKED_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#10151c"), Color("#2c3540"), 7, 1))
	else:
		status.text = _text("ui.skills.fishing.catalog.level_required", {"level": required_level})
		status.add_theme_color_override("font_color", GOLD_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#211c0d"), Color("#6f5d31"), 7, 1))
	content.add_child(status)
	return row


func _select_fishing_rod(rod_id: String) -> void:
	selected_rod_id = rod_id
	_render_fishing_catalog(SkillsService.get_skill("fishing"))


func _select_fishing_area(index: int) -> void:
	if index < 0 or index >= fishing_area_selector.item_count:
		return
	selected_fishing_area_id = str(fishing_area_selector.get_item_metadata(index))
	_render_fishing_catalog(SkillsService.get_skill("fishing"))


func _render_fishing_area_selector(rods: Array) -> void:
	var area_ids := _fishing_catalog_area_ids(rods)
	if selected_fishing_area_id not in area_ids:
		selected_fishing_area_id = area_ids[0] if not area_ids.is_empty() else ""
	fishing_area_selector.clear()
	for index in range(area_ids.size()):
		var area_id := area_ids[index]
		fishing_area_selector.add_item(_text("ui.skills.fishing.catalog.area_option", {
			"area": _fishing_area_name(area_id),
			"count": _fishing_area_species_count(rods, area_id),
		}))
		fishing_area_selector.set_item_metadata(index, area_id)
		if area_id == selected_fishing_area_id:
			fishing_area_selector.select(index)
	fishing_area_selector.disabled = area_ids.is_empty()


func _fishing_catalog_area_ids(rods: Array) -> Array[String]:
	var area_ids: Array[String] = []
	for rod_value: Variant in rods:
		var entries_value: Variant = (rod_value as Dictionary).get("entries", [])
		if not entries_value is Array:
			continue
		for entry_value: Variant in entries_value as Array:
			if not entry_value is Dictionary:
				continue
			var entry_area_ids: Variant = (entry_value as Dictionary).get("areaIds", [])
			if not entry_area_ids is Array:
				continue
			for area_id_value: Variant in entry_area_ids as Array:
				var area_id := str(area_id_value).strip_edges()
				if area_id != "" and area_id not in area_ids:
					area_ids.append(area_id)
	return area_ids


func _fishing_area_species_count(rods: Array, area_id: String) -> int:
	var species: Dictionary = {}
	for rod_value: Variant in rods:
		var entries_value: Variant = (rod_value as Dictionary).get("entries", [])
		if not entries_value is Array:
			continue
		for entry_value: Variant in entries_value as Array:
			if entry_value is Dictionary and _entry_is_in_fishing_area(entry_value as Dictionary, area_id):
				var species_name := str((entry_value as Dictionary).get("species", "")).strip_edges()
				if species_name != "":
					species[species_name] = true
	return species.size()


func _entry_is_in_fishing_area(entry: Dictionary, area_id: String) -> bool:
	if area_id == "":
		return true
	var area_ids_value: Variant = entry.get("areaIds", [])
	return area_ids_value is Array and area_id in (area_ids_value as Array)


func _fishing_area_name(area_id: String) -> String:
	var normalized := area_id.trim_prefix("kanto_")
	var key := "ui.town_map.location.%s.name" % normalized
	var translated := _text(key)
	return normalized.replace("_", " ").capitalize() if translated == key else translated


func _catalog_has_rod(rods: Array, rod_id: String) -> bool:
	return _catalog_rod_tier(rods, rod_id) > 0


func _catalog_rod_tier(rods: Array, rod_id: String) -> int:
	for index in range(rods.size()):
		if str((rods[index] as Dictionary).get("id", "")) == rod_id:
			return index + 1
	return 0


func _rod_name(rod_id: String, fallback: String) -> String:
	var key := "ui.skills.fishing.rod.%s" % rod_id
	var translated := _text(key)
	return fallback if translated == key else translated


func _pokemon_level_range(entry: Dictionary) -> String:
	var min_level := maxi(int(entry.get("minPokemonLevel", 1)), 1)
	var max_level := maxi(int(entry.get("maxPokemonLevel", min_level)), min_level)
	return str(min_level) if min_level == max_level else "%d–%d" % [min_level, max_level]


func _catalog_regions(entry: Dictionary) -> String:
	var regions_value: Variant = entry.get("regions", [])
	if not regions_value is Array:
		return _text("ui.skills.fishing.catalog.unknown_region")
	var names: Array[String] = []
	for region_value: Variant in regions_value as Array:
		var region := str(region_value).strip_edges()
		if region != "":
			names.append(region.capitalize())
	return ", ".join(names) if not names.is_empty() else _text("ui.skills.fishing.catalog.unknown_region")


func _catalog_locations_tooltip(entry: Dictionary) -> String:
	var area_ids_value: Variant = entry.get("areaIds", [])
	if not area_ids_value is Array:
		return ""
	var names: Array[String] = []
	for area_id_value: Variant in area_ids_value as Array:
		var area_name := _fishing_area_name(str(area_id_value))
		if area_name != "":
			names.append(area_name)
	return ", ".join(names)


func _render_unlocks(unlocks: Array) -> void:
	for child: Node in unlocks_container.get_children():
		unlocks_container.remove_child(child)
		child.queue_free()
	var next_unlock_found := false
	for index in range(unlocks.size()):
		var unlock_value: Variant = unlocks[index]
		var unlock := unlock_value as Dictionary
		var unlocked := bool(unlock.get("unlocked", false))
		var is_next := not unlocked and not next_unlock_found
		if is_next:
			next_unlock_found = true
		unlocks_container.add_child(_create_unlock_card(unlock, unlocked, is_next))
	_update_unlock_grid_columns()
	unlocks_scroll.scroll_vertical = 0


func _create_unlock_card(unlock: Dictionary, unlocked: bool, is_next: bool) -> Control:
	var accent := SUCCESS_COLOR if unlocked else (GOLD_COLOR if is_next else LOCKED_COLOR)
	var background := Color("#0a1d17") if unlocked else (Color("#211c0d") if is_next else Color("#080f18"))
	var border := Color("#397858") if unlocked else (Color("#8c7436") if is_next else Color("#263746"))
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 54.0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(background, border, 8, 1))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	card.add_child(content)

	var marker := Label.new()
	marker.custom_minimum_size = Vector2(28, 28)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", accent)
	marker.add_theme_font_size_override("font_size", 15)
	marker.text = "✓" if unlocked else ("→" if is_next else "🔒")
	content.add_child(marker)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 1)
	content.add_child(identity)

	var status_key := (
		"ui.skills.unlock_status.unlocked"
		if unlocked
		else ("ui.skills.unlock_status.next" if is_next else "ui.skills.unlock_status.locked")
	)
	var meta_label := Label.new()
	meta_label.add_theme_color_override("font_color", accent)
	meta_label.add_theme_font_size_override("font_size", 9)
	meta_label.text = "%s  •  %s" % [
		_text("ui.skills.level", {"level": int(unlock.get("requiredLevel", 1))}),
		_text(status_key),
	]
	identity.add_child(meta_label)

	var name_label := Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", TEXT_COLOR if unlocked or is_next else COMPLETE_COLOR)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.text = _text(str(unlock.get("labelKey", "")))
	identity.add_child(name_label)
	return card


func _render_targets(targets: Array) -> void:
	var available_count := 0
	var completed_count := 0
	target_town_order.clear()
	targets_by_town.clear()
	for target_value: Variant in targets:
		var target := target_value as Dictionary
		if bool(target.get("availableToday", false)):
			available_count += 1
		if bool(target.get("attemptedToday", false)):
			completed_count += 1
		var town_key := str(target.get("townKey", target.get("locationKey", "")))
		if not targets_by_town.has(town_key):
			target_town_order.append(town_key)
			targets_by_town[town_key] = []
		var town_targets: Array = targets_by_town[town_key] as Array
		town_targets.append(target)
	if selected_target_town_key not in target_town_order:
		selected_target_town_key = target_town_order[0] if not target_town_order.is_empty() else ""
	_render_area_selector()
	_render_selected_target_town()
	targets_summary_label.text = _text("ui.skills.thieving.targets.summary", {
		"available": available_count,
		"completed": completed_count,
		"total": targets.size(),
	})
	targets_reset_label.text = _text("ui.skills.thieving.targets.reset")


func _render_rocks(rocks: Array) -> void:
	var available_count := 0
	var completed_count := 0
	target_town_order.clear()
	targets_by_town.clear()
	for rock_value: Variant in rocks:
		var rock := rock_value as Dictionary
		if bool(rock.get("availableToday", false)):
			available_count += 1
		if bool(rock.get("smashedToday", false)):
			completed_count += 1
		var town_key := str(rock.get("townKey", rock.get("locationKey", "")))
		if not targets_by_town.has(town_key):
			target_town_order.append(town_key)
			targets_by_town[town_key] = []
		var town_rocks: Array = targets_by_town[town_key] as Array
		town_rocks.append(rock)
	if selected_target_town_key not in target_town_order:
		selected_target_town_key = target_town_order[0] if not target_town_order.is_empty() else ""
	_render_area_selector()
	_render_selected_target_town()
	targets_summary_label.text = _text("ui.skills.rock_smash.rocks.summary", {
		"available": available_count,
		"completed": completed_count,
		"total": rocks.size(),
	})
	targets_reset_label.text = _text("ui.skills.rock_smash.rocks.reset")


func _render_area_selector() -> void:
	area_selector.clear()
	var selected_index := 0
	var completion_key := "smashedToday" if selected_skill_id == "rock_smash" else "attemptedToday"
	var option_key := (
		"ui.skills.rock_smash.rocks.area_option"
		if selected_skill_id == "rock_smash"
		else "ui.skills.thieving.targets.area_option"
	)
	for index in range(target_town_order.size()):
		var town_key := target_town_order[index]
		var area_targets: Array = targets_by_town.get(town_key, []) as Array
		var completed_count := 0
		for target_value: Variant in area_targets:
			if bool((target_value as Dictionary).get(completion_key, false)):
				completed_count += 1
		area_selector.add_item(_text(option_key, {
			"area": _text(town_key),
			"completed": completed_count,
			"total": area_targets.size(),
		}))
		area_selector.set_item_metadata(index, town_key)
		if town_key == selected_target_town_key:
			selected_index = index
	area_selector.disabled = target_town_order.is_empty()
	if not target_town_order.is_empty():
		area_selector.select(selected_index)


func _select_area(index: int) -> void:
	if index < 0 or index >= area_selector.item_count:
		return
	var town_key := str(area_selector.get_item_metadata(index))
	if town_key not in target_town_order:
		return
	selected_target_town_key = town_key
	_render_selected_target_town()


func _render_selected_target_town() -> void:
	for child: Node in targets_container.get_children():
		targets_container.remove_child(child)
		child.queue_free()
	var town_targets: Array = targets_by_town.get(selected_target_town_key, []) as Array
	for target_value: Variant in town_targets:
		targets_container.add_child(_create_target_row(target_value as Dictionary))
	targets_scroll.scroll_vertical = 0


func _style_area_selector(option: OptionButton) -> void:
	option.focus_mode = Control.FOCUS_ALL
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.add_theme_font_size_override("font_size", 12)
	option.add_theme_color_override("font_color", TEXT_COLOR)
	option.add_theme_color_override("font_hover_color", TEXT_COLOR)
	option.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	option.add_theme_color_override("font_focus_color", TEXT_COLOR)
	option.add_theme_constant_override("arrow_margin", 12)
	option.add_theme_stylebox_override("normal", _make_panel_style(Color("#07111c"), PANEL_BORDER, 7, 1))
	option.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
	option.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
	option.add_theme_stylebox_override("focus", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
	var popup := option.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.max_size = Vector2i(760, 360)
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_color_override("font_color", TEXT_COLOR)
	popup.add_theme_color_override("font_hover_color", TEXT_COLOR)
	popup.add_theme_color_override("font_disabled_color", LOCKED_COLOR)
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", 14)
	popup.add_theme_constant_override("v_separation", 12)
	popup.add_theme_stylebox_override("panel", _make_panel_style(Color("#050e18fc"), CARD_SELECTED_BORDER, 8, 1))
	popup.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 5, 1))
	popup.about_to_popup.connect(_fit_area_popup.bind(option))


func _fit_area_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	var popup_width := maxi(roundi(option.size.x), 320)
	popup.min_size = Vector2i(popup_width, 0)
	popup.max_size = Vector2i(popup_width, 360)

func _create_target_row(target: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 47.0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _make_panel_style(Color("#07111ceb"), Color("#233d52"), 7, 1))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	row.add_child(content)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 1)
	content.add_child(identity)

	var name_label := Label.new()
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.text = _text(str(target.get("nameKey", "")))
	identity.add_child(name_label)

	var detail_label := Label.new()
	detail_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	detail_label.add_theme_font_size_override("font_size", 9)
	if selected_skill_id == "rock_smash":
		detail_label.text = _text("ui.skills.rock_smash.rock.detail", {
			"location": _text(str(target.get("locationKey", ""))),
			"level": int(target.get("requiredLevel", 1)),
		})
	else:
		detail_label.text = _text("ui.skills.thieving.target.detail", {
			"type": _text("ui.skills.thieving.target_type.%s" % str(target.get("npcType", "civilian"))),
			"location": _text(str(target.get("locationKey", ""))),
			"level": int(target.get("requiredLevel", 1)),
		})
	identity.add_child(detail_label)

	var status := Label.new()
	status.custom_minimum_size = Vector2(104, 28)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	var attempted := bool(target.get(
		"smashedToday" if selected_skill_id == "rock_smash" else "attemptedToday",
		false
	))
	var unlocked := bool(target.get("unlocked", false))
	var available := bool(target.get("availableToday", false))
	if attempted:
		status.text = _text(
			"ui.skills.rock_smash.rock.completed"
			if selected_skill_id == "rock_smash"
			else "ui.skills.thieving.target.completed"
		)
		status.add_theme_color_override("font_color", COMPLETE_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#111d28"), Color("#38536a"), 7, 1))
	elif not unlocked:
		status.text = _text(
			"ui.skills.rock_smash.rock.level_required"
			if selected_skill_id == "rock_smash"
			else "ui.skills.thieving.target.level_required",
			{"level": int(target.get("requiredLevel", 1))}
		)
		status.add_theme_color_override("font_color", LOCKED_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#10151c"), Color("#2c3540"), 7, 1))
	elif available:
		status.text = _text(
			"ui.skills.rock_smash.rock.available"
			if selected_skill_id == "rock_smash"
			else "ui.skills.thieving.target.available"
		)
		status.add_theme_color_override("font_color", SUCCESS_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#0b241a"), Color("#397858"), 7, 1))
	else:
		status.text = _text(
			"ui.skills.rock_smash.rock.unavailable"
			if selected_skill_id == "rock_smash"
			else "ui.skills.thieving.target.unavailable"
		)
		status.add_theme_color_override("font_color", LOCKED_COLOR)
		status.add_theme_stylebox_override("normal", _make_panel_style(Color("#10151c"), Color("#2c3540"), 7, 1))
	content.add_child(status)
	return row


func _stats_text(skill_id: String, stats: Dictionary) -> String:
	if skill_id == "thieving":
		return _text("ui.skills.thieving.stats", {
			"reward": snappedf(float(stats.get("rewardBonusPercent", 0.0)), 0.1),
			"risk": snappedf(float(stats.get("maximumCatchReductionPercent", 0.0)), 0.1),
			"heat": snappedf(float(stats.get("wantedReductionPercent", 0.0)), 0.1),
		})
	if skill_id == "rock_smash":
		return _text("ui.skills.rock_smash.stats", {
			"fossil": snappedf(float(stats.get("fossilChancePercent", 0.0)), 0.001),
			"available": maxi(int(stats.get("availableRocks", 0)), 0),
		})
	return _text("ui.skills.fishing.stats", {
		"tier": maxi(int(stats.get("activeTier", 0)), 0),
		"badges": maxi(int(stats.get("badgeCount", 0)), 0),
	})


func _render_wanted_meter(stats: Dictionary) -> void:
	var wanted := clampi(int(stats.get("wanted", 0)), 0, 100)
	var wanted_color := _wanted_meter_color(wanted)
	wanted_bar.value = wanted
	wanted_bar.tooltip_text = _text("ui.skills.thieving.wanted.tooltip")
	wanted_bar.add_theme_stylebox_override(
		"fill",
		_make_panel_style(wanted_color.darkened(0.35), wanted_color, 5, 1)
	)
	wanted_value_label.text = _text("ui.skills.thieving.wanted.value", {"wanted": wanted})
	wanted_value_label.add_theme_color_override("font_color", wanted_color)
	wanted_title_label.text = _text("ui.skills.thieving.wanted")


func _wanted_meter_color(wanted: int) -> Color:
	if wanted >= 75:
		return Color("#f0606c")
	if wanted >= 50:
		return Color("#f39a52")
	if wanted >= 25:
		return GOLD_COLOR
	return Color("#c9a94f")


func _select_skill(skill_id: String) -> void:
	selected_skill_id = skill_id
	selected_detail_tab = "progression"
	showing_detail = true
	_render_skills(SkillsService.get_skills())


func _show_overview() -> void:
	showing_detail = false
	_render_skills(SkillsService.get_skills())


func _on_window_header_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	window_dragging = mouse_button.pressed
	if window_dragging:
		move_to_front()
	accept_event()


func _clamp_window_to_parent() -> void:
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	var available := parent_control.size
	position = Vector2(
		clampf(position.x, 8.0, maxf(available.x - size.x - 8.0, 8.0)),
		clampf(position.y, 8.0, maxf(available.y - size.y - 8.0, 8.0))
	)


func _fit_window_to_parent() -> void:
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	var available_size := parent_control.size - Vector2.ONE * WINDOW_EDGE_MARGIN * 2.0
	available_size.x = maxf(available_size.x, 320.0)
	available_size.y = maxf(available_size.y, 360.0)
	custom_minimum_size = Vector2(
		minf(WINDOW_MINIMUM_SIZE.x, available_size.x),
		minf(WINDOW_MINIMUM_SIZE.y, available_size.y)
	)
	size = Vector2(
		minf(WINDOW_PREFERRED_SIZE.x, available_size.x),
		minf(WINDOW_PREFERRED_SIZE.y, available_size.y)
	)
	_clamp_window_to_parent()


func _on_window_resized() -> void:
	_update_unlock_grid_columns()
	_update_target_grid_columns()
	_update_fishing_catalog_grid_columns()


func _update_unlock_grid_columns() -> void:
	if unlocks_container == null:
		return
	unlocks_container.columns = 2 if size.x >= DETAIL_GRID_MINIMUM_WIDTH else 1


func _update_target_grid_columns() -> void:
	if targets_container == null:
		return
	targets_container.columns = (
		2 if selected_skill_id == "rock_smash" and size.x >= DETAIL_GRID_MINIMUM_WIDTH else 1
	)


func _update_fishing_catalog_grid_columns() -> void:
	if fishing_catalog_container == null:
		return
	if fishing_catalog_container.get_child_count() == 1 and fishing_catalog_container.get_child(0) is Label:
		fishing_catalog_container.columns = 1
		return
	fishing_catalog_container.columns = 2 if size.x >= DETAIL_GRID_MINIMUM_WIDTH else 1


func _on_skills_changed(skills: Array) -> void:
	if visible:
		_render_skills(skills)


func _on_fishing_catalog_changed(_catalog: Dictionary) -> void:
	if visible and showing_detail and selected_skill_id == "fishing" and selected_detail_tab == "catalog":
		_render_detail(SkillsService.get_skill("fishing"))


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_content()
	if visible:
		_render_skills(SkillsService.get_skills())


func _refresh_localized_content() -> void:
	if title_label == null:
		return
	title_label.text = _text("ui.skills.title")
	subtitle_label.text = _text("ui.skills.subtitle")
	back_button.text = "←  %s" % _text("ui.skills.back")
	progression_tab_button.text = _text("ui.skills.progression")
	catalog_tab_button.text = _text("ui.skills.fishing.catalog.title")
	close_button.tooltip_text = _text("common.close")
	var unlock_title := main_panel.find_child("UnlockTitle", true, false) as Label
	if unlock_title != null:
		unlock_title.text = _text("ui.skills.unlocks")
	var targets_title := main_panel.find_child("TargetsTitle", true, false) as Label
	if targets_title != null:
		targets_title.text = _text("ui.skills.thieving.targets.title")


func _current_area_id() -> String:
	if GameState.current_map == null or not is_instance_valid(GameState.current_map):
		return ""
	for method_name: String in ["get_encounter_area_id", "get_map_id"]:
		if GameState.current_map.has_method(method_name):
			var value := str(GameState.current_map.call(method_name)).strip_edges()
			if value != "":
				return value
	return ""


func _has_skill(skills: Array, skill_id: String) -> bool:
	for skill_value: Variant in skills:
		if skill_value is Dictionary and str((skill_value as Dictionary).get("id", "")) == skill_id:
			return true
	return false


func _skill_icon(skill_id: String) -> Texture2D:
	if skill_id == "fishing":
		return FISHING_ICON
	if skill_id == "rock_smash":
		return ROCK_SMASH_ICON
	return THIEVING_ICON


func _text(key: String, replacements: Dictionary = {}) -> String:
	return LocalizationManager.text(key, replacements)


func _make_panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
