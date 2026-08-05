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
const FISHING_ICON: Texture2D = preload("res://assets/ui/fishing_rod.svg")
const THIEVING_ICON: Texture2D = preload("res://assets/ui/skills.svg")

var main_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var close_button: Button
var status_label: Label
var skill_cards: HBoxContainer
var detail_panel: PanelContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_description: Label
var detail_level: Label
var experience_bar: ProgressBar
var experience_label: Label
var stats_label: Label
var unlocks_container: VBoxContainer
var skill_buttons: Dictionary = {}
var selected_skill_id := "thieving"
var loading := false


func _ready() -> void:
	_build_interface()
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	if not SkillsService.state_changed.is_connected(_on_skills_changed):
		SkillsService.state_changed.connect(_on_skills_changed)
	_refresh_localized_content()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_manager()
		get_viewport().set_input_as_handled()


func toggle_manager() -> void:
	if visible:
		close_manager()
	else:
		open_manager()


func open_manager() -> void:
	visible = true
	_render_skills(SkillsService.get_skills())
	_load_skills()


func close_manager() -> void:
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)

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
	header.add_child(close_button)

	status_label = Label.new()
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	status_label.add_theme_font_size_override("font_size", 11)
	content.add_child(status_label)

	skill_cards = HBoxContainer.new()
	skill_cards.custom_minimum_size.y = 72.0
	skill_cards.add_theme_constant_override("separation", 10)
	content.add_child(skill_cards)

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

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_color_override("font_color", TEXT_COLOR)
	stats_label.add_theme_font_size_override("font_size", 11)
	detail_content.add_child(stats_label)

	var unlock_title := Label.new()
	unlock_title.name = "UnlockTitle"
	unlock_title.add_theme_color_override("font_color", ACCENT_COLOR)
	unlock_title.add_theme_font_size_override("font_size", 12)
	detail_content.add_child(unlock_title)

	unlocks_container = VBoxContainer.new()
	unlocks_container.add_theme_constant_override("separation", 4)
	detail_content.add_child(unlocks_container)

	_render_skills([])


func _render_skills(skills: Array) -> void:
	for child: Node in skill_cards.get_children():
		skill_cards.remove_child(child)
		child.queue_free()
	skill_buttons.clear()

	if skills.is_empty():
		detail_panel.visible = false
		return
	detail_panel.visible = true
	if not _has_skill(skills, selected_skill_id):
		selected_skill_id = str((skills[0] as Dictionary).get("id", ""))
	for skill_value: Variant in skills:
		var skill := skill_value as Dictionary
		var skill_id := str(skill.get("id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 68)
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
			_text("ui.skills.level_short", {"level": maxi(int(skill.get("level", 1)), 1)}),
		]
		var selected := skill_id == selected_skill_id
		button.add_theme_stylebox_override("normal", _make_panel_style(CARD_SELECTED if selected else CARD_BACKGROUND, CARD_SELECTED_BORDER if selected else PANEL_BORDER, 9, 1))
		button.add_theme_stylebox_override("hover", _make_panel_style(CARD_HOVER, CARD_SELECTED_BORDER, 9, 1))
		button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_SELECTED, CARD_SELECTED_BORDER, 9, 1))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_select_skill.bind(skill_id))
		skill_cards.add_child(button)
		skill_buttons[skill_id] = button
	_render_detail(SkillsService.get_skill(selected_skill_id))


func _render_detail(skill: Dictionary) -> void:
	if skill.is_empty():
		detail_panel.visible = false
		return
	detail_panel.visible = true
	var skill_id := str(skill.get("id", ""))
	var level := maxi(int(skill.get("level", 1)), 1)
	var max_level := maxi(int(skill.get("maxLevel", 100)), level)
	detail_icon.texture = _skill_icon(skill_id)
	detail_name.text = _text(str(skill.get("nameKey", "ui.skills.%s.name" % skill_id)))
	detail_description.text = _text(str(skill.get("descriptionKey", "ui.skills.%s.description" % skill_id)))
	detail_level.text = _text("ui.skills.level", {"level": level})
	experience_bar.value = clampf(float(skill.get("progressPercent", 0.0)), 0.0, 100.0)
	if level >= max_level:
		experience_label.text = _text("ui.skills.max_level")
	else:
		experience_label.text = _text("ui.skills.xp_progress", {
			"current": maxi(int(skill.get("experienceIntoLevel", 0)), 0),
			"required": maxi(int(skill.get("experienceForNextLevel", 0)), 0),
			"total": maxi(int(skill.get("totalExperience", 0)), 0),
		})
	stats_label.text = _stats_text(skill_id, skill.get("stats", {}) as Dictionary)
	_render_unlocks(skill.get("unlocks", []) as Array)


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


func _stats_text(skill_id: String, stats: Dictionary) -> String:
	if skill_id == "thieving":
		return _text("ui.skills.thieving.stats", {
			"currency": maxi(int(stats.get("currency", 0)), 0),
			"wanted": clampi(int(stats.get("wanted", 0)), 0, 100),
			"reward": snappedf(float(stats.get("rewardBonusPercent", 0.0)), 0.1),
			"risk": snappedf(float(stats.get("maximumCatchReductionPercent", 0.0)), 0.1),
			"heat": snappedf(float(stats.get("wantedReductionPercent", 0.0)), 0.1),
		})
	return _text("ui.skills.fishing.stats", {
		"tier": maxi(int(stats.get("activeTier", 0)), 0),
		"badges": maxi(int(stats.get("badgeCount", 0)), 0),
	})


func _select_skill(skill_id: String) -> void:
	selected_skill_id = skill_id
	_render_skills(SkillsService.get_skills())


func _on_skills_changed(skills: Array) -> void:
	if visible:
		_render_skills(skills)


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_content()
	if visible:
		_render_skills(SkillsService.get_skills())


func _refresh_localized_content() -> void:
	if title_label == null:
		return
	title_label.text = _text("ui.skills.title")
	subtitle_label.text = _text("ui.skills.subtitle")
	close_button.tooltip_text = _text("common.close")
	var unlock_title := main_panel.find_child("UnlockTitle", true, false) as Label
	if unlock_title != null:
		unlock_title.text = _text("ui.skills.unlocks")


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
	return FISHING_ICON if skill_id == "fishing" else THIEVING_ICON


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
