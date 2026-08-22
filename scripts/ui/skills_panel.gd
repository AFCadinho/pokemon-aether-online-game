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
const TARGET_TOWN_TABS_PER_PAGE := 3

var main_panel: PanelContainer
var window_header: HBoxContainer
var title_label: Label
var subtitle_label: Label
var back_button: Button
var close_button: Button
var status_label: Label
var overview_panel: VBoxContainer
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
var unlocks_container: VBoxContainer
var targets_section: VBoxContainer
var targets_summary_label: Label
var targets_reset_label: Label
var target_town_previous_button: Button
var target_town_tabs: HBoxContainer
var target_town_next_button: Button
var targets_scroll: ScrollContainer
var targets_container: VBoxContainer
var fishing_catalog_section: VBoxContainer
var fishing_catalog_summary: Label
var fishing_rod_filters: HBoxContainer
var fishing_catalog_container: VBoxContainer
var skill_buttons: Dictionary = {}
var selected_skill_id := "thieving"
var selected_detail_tab := "progression"
var selected_rod_id := "old_rod"
var selected_target_town_key := ""
var target_town_page := 0
var target_town_order: Array[String] = []
var targets_by_town: Dictionary = {}
var showing_detail := false
var loading := false
var window_dragging := false


func _ready() -> void:
	_build_interface()
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
	overview_panel.add_theme_constant_override("separation", 10)
	content.add_child(overview_panel)

	skill_cards = GridContainer.new()
	skill_cards.columns = 2
	skill_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_cards.add_theme_constant_override("h_separation", 10)
	skill_cards.add_theme_constant_override("v_separation", 10)
	overview_panel.add_child(skill_cards)

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

	unlocks_container = VBoxContainer.new()
	unlocks_container.add_theme_constant_override("separation", 4)
	progression_section.add_child(unlocks_container)

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

	var target_town_navigation := HBoxContainer.new()
	target_town_navigation.name = "TargetTownNavigation"
	target_town_navigation.add_theme_constant_override("separation", 5)
	targets_section.add_child(target_town_navigation)

	target_town_previous_button = _create_target_town_arrow("‹")
	target_town_previous_button.pressed.connect(_change_target_town_page.bind(-1))
	target_town_navigation.add_child(target_town_previous_button)

	target_town_tabs = HBoxContainer.new()
	target_town_tabs.name = "TargetTownTabs"
	target_town_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_town_tabs.add_theme_constant_override("separation", 5)
	target_town_navigation.add_child(target_town_tabs)

	target_town_next_button = _create_target_town_arrow("›")
	target_town_next_button.pressed.connect(_change_target_town_page.bind(1))
	target_town_navigation.add_child(target_town_next_button)

	targets_scroll = ScrollContainer.new()
	targets_scroll.name = "TargetsScroll"
	targets_scroll.custom_minimum_size.y = 220.0
	targets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	targets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	targets_section.add_child(targets_scroll)

	targets_container = VBoxContainer.new()
	targets_container.name = "TargetsContainer"
	targets_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_container.add_theme_constant_override("separation", 5)
	targets_scroll.add_child(targets_container)

	fishing_catalog_section = VBoxContainer.new()
	fishing_catalog_section.visible = false
	fishing_catalog_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fishing_catalog_section.add_theme_constant_override("separation", 7)
	detail_content.add_child(fishing_catalog_section)

	var catalog_header := HBoxContainer.new()
	catalog_header.add_theme_constant_override("separation", 8)
	fishing_catalog_section.add_child(catalog_header)

	fishing_catalog_summary = Label.new()
	fishing_catalog_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fishing_catalog_summary.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	fishing_catalog_summary.add_theme_font_size_override("font_size", 10)
	catalog_header.add_child(fishing_catalog_summary)

	fishing_rod_filters = HBoxContainer.new()
	fishing_rod_filters.add_theme_constant_override("separation", 5)
	fishing_catalog_section.add_child(fishing_rod_filters)

	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.name = "FishingCatalogScroll"
	catalog_scroll.custom_minimum_size.y = 220.0
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fishing_catalog_section.add_child(catalog_scroll)

	fishing_catalog_container = VBoxContainer.new()
	fishing_catalog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fishing_catalog_container.add_theme_constant_override("separation", 5)
	catalog_scroll.add_child(fishing_catalog_container)

	_render_skills([])


func _render_skills(skills: Array) -> void:
	for child: Node in skill_cards.get_children():
		skill_cards.remove_child(child)
		child.queue_free()
	skill_buttons.clear()

	if skills.is_empty():
		overview_panel.visible = true
		detail_panel.visible = false
		return
	if not _has_skill(skills, selected_skill_id):
		selected_skill_id = str((skills[0] as Dictionary).get("id", ""))
	for skill_value: Variant in skills:
		var skill := skill_value as Dictionary
		var skill_id := str(skill.get("id", ""))
		var skill_unlocked := bool(skill.get("unlocked", true))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = _skill_icon(skill_id)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 42)
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", TEXT_COLOR)
		button.add_theme_font_size_override("font_size", 12)
		button.text = "%s\n%s" % [
			_text(str(skill.get("nameKey", "ui.skills.%s.name" % skill_id))),
			(
				_text("ui.skills.level_short", {"level": maxi(int(skill.get("level", 1)), 1)})
				if skill_unlocked
				else "🔒 %s" % _text("ui.skills.locked")
			),
		]
		button.add_theme_stylebox_override(
			"normal",
			_make_panel_style(CARD_BACKGROUND, PANEL_BORDER if skill_unlocked else Color("#35404c"), 9, 1)
		)
		button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 9, 1))
		button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 9, 1))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_select_skill.bind(skill_id))
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
	unlocks_container.visible = skill_unlocked
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
	fishing_catalog_summary.text = _text("ui.skills.fishing.catalog.summary", {
		"count": maxi(int(catalog.get("speciesCount", 0)), 0),
		"level": fishing_level,
	})
	if rods.is_empty():
		var empty_label := Label.new()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
		empty_label.text = _text("ui.skills.fishing.catalog.unavailable")
		fishing_catalog_container.add_child(empty_label)
		return

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
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			fishing_catalog_container.add_child(
				_create_fishing_catalog_row(entry_value as Dictionary, fishing_level, active_tier >= selected_rod_tier)
			)


func _create_fishing_catalog_row(entry: Dictionary, fishing_level: int, rod_available: bool) -> Control:
	var required_level := maxi(int(entry.get("requiredFishingLevel", 1)), 1)
	var available := rod_available and fishing_level >= required_level
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 58.0
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
	location_label.text = _text(
		"ui.skills.fishing.catalog.location" if int(entry.get("locationCount", 0)) == 1 else "ui.skills.fishing.catalog.locations",
		{
		"region": _catalog_regions(entry),
		"count": maxi(int(entry.get("locationCount", 0)), 0),
		}
	)
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
		var area_name := str(area_id_value).trim_prefix("kanto_").replace("_", " ").capitalize()
		if area_name != "":
			names.append(area_name)
	return ", ".join(names)


func _render_unlocks(unlocks: Array) -> void:
	for child: Node in unlocks_container.get_children():
		unlocks_container.remove_child(child)
		child.queue_free()
	for unlock_value: Variant in unlocks:
		var unlock := unlock_value as Dictionary
		var unlocked := bool(unlock.get("unlocked", false))
		var row := Label.new()
		row.custom_minimum_size.y = 25.0
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", SUCCESS_COLOR if unlocked else LOCKED_COLOR)
		row.add_theme_font_size_override("font_size", 11)
		row.text = "%s  %s" % [
			"✓" if unlocked else "🔒",
			_text("ui.skills.unlock_row", {
				"level": int(unlock.get("requiredLevel", 1)),
				"name": _text(str(unlock.get("labelKey", ""))),
			}),
		]
		unlocks_container.add_child(row)


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
	var selected_index := target_town_order.find(selected_target_town_key)
	target_town_page = floori(float(maxi(selected_index, 0)) / TARGET_TOWN_TABS_PER_PAGE)
	_render_target_town_tabs()
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
	var selected_index := target_town_order.find(selected_target_town_key)
	target_town_page = floori(float(maxi(selected_index, 0)) / TARGET_TOWN_TABS_PER_PAGE)
	_render_target_town_tabs()
	_render_selected_target_town()
	targets_summary_label.text = _text("ui.skills.rock_smash.rocks.summary", {
		"available": available_count,
		"completed": completed_count,
		"total": rocks.size(),
	})
	targets_reset_label.text = _text("ui.skills.rock_smash.rocks.reset")


func _render_target_town_tabs() -> void:
	for child: Node in target_town_tabs.get_children():
		target_town_tabs.remove_child(child)
		child.queue_free()
	var page_count := maxi(ceili(float(target_town_order.size()) / TARGET_TOWN_TABS_PER_PAGE), 1)
	target_town_page = clampi(target_town_page, 0, page_count - 1)
	var start_index := target_town_page * TARGET_TOWN_TABS_PER_PAGE
	var end_index := mini(start_index + TARGET_TOWN_TABS_PER_PAGE, target_town_order.size())
	for index in range(start_index, end_index):
		var town_key := target_town_order[index]
		target_town_tabs.add_child(_create_target_town_tab(town_key))
	var has_overflow := target_town_order.size() > TARGET_TOWN_TABS_PER_PAGE
	target_town_previous_button.visible = has_overflow
	target_town_next_button.visible = has_overflow
	target_town_previous_button.disabled = target_town_page <= 0
	target_town_next_button.disabled = target_town_page >= page_count - 1


func _render_selected_target_town() -> void:
	for child: Node in targets_container.get_children():
		targets_container.remove_child(child)
		child.queue_free()
	var town_targets: Array = targets_by_town.get(selected_target_town_key, []) as Array
	for target_value: Variant in town_targets:
		targets_container.add_child(_create_target_row(target_value as Dictionary))
	targets_scroll.scroll_vertical = 0


func _create_target_town_tab(town_key: String) -> Button:
	var town_targets: Array = targets_by_town.get(town_key, []) as Array
	var available_count := 0
	for target_value: Variant in town_targets:
		if bool((target_value as Dictionary).get("availableToday", false)):
			available_count += 1
	var selected := town_key == selected_target_town_key
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = _text(town_key)
	button.tooltip_text = _text(
		"ui.skills.rock_smash.rocks.town_summary"
		if selected_skill_id == "rock_smash"
		else "ui.skills.thieving.targets.town_summary",
		{
		"available": available_count,
		"total": town_targets.size(),
		}
	)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_COLOR if selected else MUTED_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(CARD_SELECTED if selected else Color("#07111c"), CARD_SELECTED_BORDER if selected else PANEL_BORDER, 7, 1)
	)
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_select_target_town.bind(town_key))
	return button


func _create_target_town_arrow(label: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(34, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = label
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", ACCENT_COLOR)
	button.add_theme_color_override("font_disabled_color", LOCKED_COLOR)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color("#07111c"), PANEL_BORDER, 7, 1))
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 7, 1))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 7, 1))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color("#070c12"), Color("#25313d"), 7, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _select_target_town(town_key: String) -> void:
	if town_key not in target_town_order:
		return
	selected_target_town_key = town_key
	target_town_page = floori(float(target_town_order.find(town_key)) / TARGET_TOWN_TABS_PER_PAGE)
	_render_target_town_tabs()
	_render_selected_target_town()


func _change_target_town_page(direction: int) -> void:
	var page_count := maxi(ceili(float(target_town_order.size()) / TARGET_TOWN_TABS_PER_PAGE), 1)
	var next_page := clampi(target_town_page + direction, 0, page_count - 1)
	if next_page == target_town_page:
		return
	target_town_page = next_page
	var first_town_index := target_town_page * TARGET_TOWN_TABS_PER_PAGE
	if first_town_index < target_town_order.size():
		selected_target_town_key = target_town_order[first_town_index]
	_render_target_town_tabs()
	_render_selected_target_town()


func _create_target_row(target: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 47.0
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
