extends PanelContainer

class_name DevBadgeProgressPopup

signal closed

const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/trainer_progress_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/trainer_progress_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/trainer_progress_radio_unchecked.svg")
const POPUP_SIZE := Vector2(720, 540)
const REGION := "kanto"
const BADGES: Array[Dictionary] = [
	{"id": "boulder", "name": "Boulder", "texture": "res://assets/gym_badges/kanto_badges/Boulder_Badge.png"},
	{"id": "cascade", "name": "Cascade", "texture": "res://assets/gym_badges/kanto_badges/Cascade_Badge.png"},
	{"id": "thunder", "name": "Thunder", "texture": "res://assets/gym_badges/kanto_badges/Thunder_Badge.png"},
	{"id": "rainbow", "name": "Rainbow", "texture": "res://assets/gym_badges/kanto_badges/Rainbow_Badge.png"},
	{"id": "soul", "name": "Soul", "texture": "res://assets/gym_badges/kanto_badges/Soul_Badge.png"},
	{"id": "marsh", "name": "Marsh", "texture": "res://assets/gym_badges/kanto_badges/Marsh_Badge.png"},
	{"id": "volcano", "name": "Volcano", "texture": "res://assets/gym_badges/kanto_badges/Volcano_Badge.png"},
	{"id": "earth", "name": "Earth", "texture": "res://assets/gym_badges/kanto_badges/Earth_Badge.png"},
]
const KEY_ITEMS: Array[Dictionary] = [
	{
		"id": "pokedex",
		"name_key": "ui.staff.key_items.pokedex",
		"texture": "res://assets/ui/pokedex.svg",
	},
	{
		"id": "town-map",
		"name_key": "ui.staff.key_items.town_map",
		"texture": "res://assets/ui/town_map_navigation.svg",
	},
]
const STORY_CHECKPOINTS: Array[Dictionary] = [
	{"id": "journey_start", "chapter_id": "pallet", "label_key": "ui.staff.story_checkpoint.journey_start"},
	{"id": "choose_starter", "chapter_id": "pallet", "label_key": "ui.staff.story_checkpoint.choose_starter"},
	{"id": "oaks_parcel", "chapter_id": "pallet", "label_key": "ui.staff.story_checkpoint.oaks_parcel"},
	{"id": "route_22_gary", "chapter_id": "viridian", "label_key": "ui.staff.story_checkpoint.route_22_gary"},
	{"id": "trainer_school", "chapter_id": "viridian", "label_key": "ui.staff.story_checkpoint.trainer_school"},
	{"id": "after_dadinho", "chapter_id": "viridian", "label_key": "ui.staff.story_checkpoint.after_dadinho"},
	{"id": "pewter_gym", "chapter_id": "pewter", "label_key": "ui.staff.story_checkpoint.pewter_gym"},
	{"id": "mt_moon_warning", "chapter_id": "mt_moon", "label_key": "ui.staff.story_checkpoint.mt_moon_warning"},
	{"id": "mt_moon_grunts", "chapter_id": "mt_moon", "label_key": "ui.staff.story_checkpoint.mt_moon_grunts"},
	{"id": "mt_moon_miguel", "chapter_id": "mt_moon", "label_key": "ui.staff.story_checkpoint.mt_moon_miguel"},
	{"id": "mt_moon_fossil", "chapter_id": "mt_moon", "label_key": "ui.staff.story_checkpoint.mt_moon_fossil"},
	{"id": "mt_moon_rescue", "chapter_id": "mt_moon", "label_key": "ui.staff.story_checkpoint.mt_moon_rescue"},
]
const STORY_CHAPTERS: Array[Dictionary] = [
	{"id": "pallet", "label_key": "ui.staff.story_chapter.pallet"},
	{"id": "viridian", "label_key": "ui.staff.story_chapter.viridian"},
	{"id": "pewter", "label_key": "ui.staff.story_chapter.pewter"},
	{"id": "mt_moon", "label_key": "ui.staff.story_chapter.mt_moon"},
]

const UI_BG := Color("#050b14fa")
const UI_SURFACE := Color("#0a1726f5")
const UI_SURFACE_HOVER := Color("#102944fa")
const UI_BORDER := Color("#526b8c")
const UI_ACCENT := Color("#e3bd68")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED := Color("#aeb8c5")
const UI_SUCCESS := Color("#79e49b")
const UI_ERROR := Color("#ff8393")

var status_label: Label
var key_item_status_label: Label
var badge_content: VBoxContainer
var key_item_content: VBoxContainer
var badge_tab_button: Button
var key_item_tab_button: Button
var story_tab_button: Button
var story_content: VBoxContainer
var story_chapter_select: OptionButton
var story_checkpoint_select: OptionButton
var story_status_label: Label
var badge_buttons: Dictionary = {}
var badge_icon_rects: Dictionary = {}
var badge_status_labels: Dictionary = {}
var badge_state: Dictionary = {}
var key_item_buttons: Dictionary = {}
var key_item_status_labels: Dictionary = {}
var key_item_state: Dictionary = {}
var active_tab := "badges"
var busy := false
var dragging := false


func _ready() -> void:
	visible = false
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#8d7440"), 14, 1))
	_build_ui()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open() -> void:
	visible = true
	_center_in_viewport()
	_show_tab(active_tab)
	_load_key_items.call_deferred()
	_set_status(_t("ui.staff.badges.loading"), false)
	_set_busy(true)
	var service := get_node_or_null("/root/BadgeProgressionService")
	if service == null or not service.has_method("load_gym_badges"):
		_set_busy(false)
		_set_status(_t("ui.staff.badges.unavailable"), true)
		return
	var result: Dictionary = await service.call("load_gym_badges")
	_set_busy(false)
	if not visible:
		return
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.staff.badges.load_failed"))), true)
		return
	set_badge_state(result)


func close() -> void:
	var was_visible := visible
	dragging = false
	visible = false
	if was_visible:
		closed.emit()


func set_badge_state(state: Dictionary) -> void:
	badge_state.clear()
	var values: Variant = state.get("badges", [])
	if values is Array:
		for value: Variant in values:
			if not (value is Dictionary):
				continue
			var badge: Dictionary = value as Dictionary
			if str(badge.get("region", "")).to_lower() != REGION:
				continue
			badge_state[str(badge.get("badgeId", badge.get("id", ""))).to_lower()] = bool(badge.get("earned", false))
	_render_badges()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 15, 18, 17)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	layout.add_child(header)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	heading.add_child(_localized_label("ui.staff.dev.trainer_progress", 20, UI_TEXT))
	heading.add_child(_localized_label("ui.staff.dev.trainer_progress_description", 11, UI_MUTED))

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	_apply_button_style(close_button, false)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.name = "ProgressTabs"
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)

	badge_tab_button = Button.new()
	badge_tab_button.name = "BadgesTabButton"
	badge_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_tab_button.custom_minimum_size = Vector2(0, 38)
	badge_tab_button.focus_mode = Control.FOCUS_NONE
	_set_localized_property(badge_tab_button, "text", "ui.staff.trainer_progress.badges")
	badge_tab_button.pressed.connect(_show_tab.bind("badges"))
	tabs.add_child(badge_tab_button)

	key_item_tab_button = Button.new()
	key_item_tab_button.name = "KeyItemsTabButton"
	key_item_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_item_tab_button.custom_minimum_size = Vector2(0, 38)
	key_item_tab_button.focus_mode = Control.FOCUS_NONE
	_set_localized_property(key_item_tab_button, "text", "ui.staff.trainer_progress.key_items")
	key_item_tab_button.pressed.connect(_show_tab.bind("key_items"))
	tabs.add_child(key_item_tab_button)

	story_tab_button = Button.new()
	story_tab_button.name = "StoryTabButton"
	story_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_tab_button.custom_minimum_size = Vector2(0, 38)
	story_tab_button.focus_mode = Control.FOCUS_NONE
	_set_localized_property(story_tab_button, "text", "ui.staff.trainer_progress.story")
	story_tab_button.pressed.connect(_show_tab.bind("story"))
	tabs.add_child(story_tab_button)

	badge_content = VBoxContainer.new()
	badge_content.name = "BadgesContent"
	badge_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge_content.add_theme_constant_override("separation", 12)
	layout.add_child(badge_content)

	var notice := PanelContainer.new()
	notice.add_theme_stylebox_override("panel", _panel_style(Color("#112033e8"), Color("#486888aa"), 9, 1))
	badge_content.add_child(notice)
	var notice_margin := MarginContainer.new()
	_set_margins(notice_margin, 12, 9, 12, 9)
	notice.add_child(notice_margin)
	var notice_label := _localized_label(
		"ui.staff.badges.notice",
		11,
		UI_MUTED
	)
	notice_margin.add_child(notice_label)

	var grid := GridContainer.new()
	grid.name = "BadgeGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	badge_content.add_child(grid)

	for definition: Dictionary in BADGES:
		var button := Button.new()
		var badge_id := str(definition.get("id", ""))
		button.name = "%sBadgeButton" % badge_id.capitalize().replace(" ", "")
		button.custom_minimum_size = Vector2(158, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		var tile_margin := MarginContainer.new()
		tile_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_margins(tile_margin, 8, 7, 8, 7)
		button.add_child(tile_margin)
		var tile_layout := VBoxContainer.new()
		tile_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_layout.add_theme_constant_override("separation", 2)
		tile_margin.add_child(tile_layout)
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile_layout.add_child(icon_center)
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(54, 54)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_path := str(definition.get("texture", ""))
		if ResourceLoader.exists(texture_path):
			icon_rect.texture = load(texture_path) as Texture2D
		icon_center.add_child(icon_rect)
		var name_label := _label(str(definition.get("name", "Badge")), 12, UI_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(name_label)
		var state_label := _localized_label("ui.staff.badges.locked", 9, UI_MUTED)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(state_label)
		button.pressed.connect(_toggle_badge.bind(badge_id))
		_apply_button_style(button, false)
		grid.add_child(button)
		badge_buttons[badge_id] = button
		badge_icon_rects[badge_id] = icon_rect
		badge_status_labels[badge_id] = state_label

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	badge_content.add_child(footer)

	var first_three_button := Button.new()
	first_three_button.name = "GrantFirstThreeButton"
	_set_localized_property(first_three_button, "text", "ui.staff.badges.grant_first_three")
	first_three_button.pressed.connect(_set_first_three)
	_apply_button_style(first_three_button, true)
	footer.add_child(first_three_button)

	var all_button := Button.new()
	all_button.name = "GrantAllButton"
	_set_localized_property(all_button, "text", "ui.staff.badges.grant_all")
	all_button.pressed.connect(_set_all.bind(true))
	_apply_button_style(all_button, true)
	footer.add_child(all_button)

	var clear_button := Button.new()
	clear_button.name = "ClearAllButton"
	_set_localized_property(clear_button, "text", "ui.staff.badges.clear_all")
	clear_button.pressed.connect(_set_all.bind(false))
	_apply_button_style(clear_button, false)
	footer.add_child(clear_button)

	status_label = _label("", 11, UI_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(status_label)

	_build_key_items_ui(layout)
	_build_story_ui(layout)
	_show_tab(active_tab)
	_render_badges()
	_render_key_items()


func _build_key_items_ui(layout: VBoxContainer) -> void:
	key_item_content = VBoxContainer.new()
	key_item_content.name = "KeyItemsContent"
	key_item_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	key_item_content.add_theme_constant_override("separation", 12)
	layout.add_child(key_item_content)

	var notice := PanelContainer.new()
	notice.add_theme_stylebox_override("panel", _panel_style(Color("#112033e8"), Color("#486888aa"), 9, 1))
	key_item_content.add_child(notice)
	var notice_margin := MarginContainer.new()
	_set_margins(notice_margin, 12, 9, 12, 9)
	notice.add_child(notice_margin)
	notice_margin.add_child(_localized_label("ui.staff.key_items.notice", 11, UI_MUTED))

	var item_grid := GridContainer.new()
	item_grid.name = "KeyItemGrid"
	item_grid.columns = 2
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 12)
	key_item_content.add_child(item_grid)

	for definition: Dictionary in KEY_ITEMS:
		var item_id := str(definition.get("id", ""))
		var button := Button.new()
		button.name = "%sKeyItemButton" % item_id.replace("-", " ").capitalize().replace(" ", "")
		button.custom_minimum_size = Vector2(0, 230)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_grant_key_items.bind([item_id]))

		var tile_margin := MarginContainer.new()
		tile_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_margins(tile_margin, 12, 12, 12, 12)
		button.add_child(tile_margin)
		var tile_layout := VBoxContainer.new()
		tile_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.alignment = BoxContainer.ALIGNMENT_CENTER
		tile_layout.add_theme_constant_override("separation", 8)
		tile_margin.add_child(tile_layout)

		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile_layout.add_child(icon_center)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(92, 92)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_path := str(definition.get("texture", ""))
		if ResourceLoader.exists(texture_path):
			icon.texture = load(texture_path) as Texture2D
		icon_center.add_child(icon)

		var name_label := _localized_label(str(definition.get("name_key", "")), 16, UI_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(name_label)
		var state_label := _localized_label("ui.staff.key_items.missing", 10, UI_MUTED)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_layout.add_child(state_label)

		_apply_button_style(button, false)
		item_grid.add_child(button)
		key_item_buttons[item_id] = button
		key_item_status_labels[item_id] = state_label

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	key_item_content.add_child(footer)
	var grant_all_button := Button.new()
	grant_all_button.name = "GrantAllKeyItemsButton"
	grant_all_button.custom_minimum_size = Vector2(190, 38)
	_set_localized_property(grant_all_button, "text", "ui.staff.key_items.grant_all")
	grant_all_button.pressed.connect(_grant_all_key_items)
	_apply_button_style(grant_all_button, true)
	footer.add_child(grant_all_button)

	key_item_status_label = _label("", 11, UI_MUTED)
	key_item_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_item_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_item_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(key_item_status_label)


func _build_story_ui(layout: VBoxContainer) -> void:
	story_content = VBoxContainer.new()
	story_content.name = "StoryContent"
	story_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_content.add_theme_constant_override("separation", 16)
	layout.add_child(story_content)

	var notice := PanelContainer.new()
	notice.add_theme_stylebox_override("panel", _panel_style(Color("#112033e8"), Color("#486888aa"), 9, 1))
	story_content.add_child(notice)
	var notice_margin := MarginContainer.new()
	_set_margins(notice_margin, 14, 12, 14, 12)
	notice.add_child(notice_margin)
	var notice_label := _localized_label("ui.staff.story_checkpoint.notice", 12, UI_MUTED)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_margin.add_child(notice_label)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	story_content.add_child(form)
	form.add_child(_localized_label("ui.staff.story_chapter.select", 13, UI_TEXT))
	story_chapter_select = OptionButton.new()
	story_chapter_select.name = "StoryChapterSelect"
	story_chapter_select.custom_minimum_size = Vector2(0, 46)
	story_chapter_select.focus_mode = Control.FOCUS_NONE
	_apply_story_checkpoint_dropdown_style(story_chapter_select)
	story_chapter_select.item_selected.connect(_on_story_chapter_selected)
	form.add_child(story_chapter_select)
	form.add_child(_localized_label("ui.staff.story_checkpoint.select", 13, UI_TEXT))
	story_checkpoint_select = OptionButton.new()
	story_checkpoint_select.name = "StoryCheckpointSelect"
	story_checkpoint_select.custom_minimum_size = Vector2(0, 46)
	story_checkpoint_select.focus_mode = Control.FOCUS_NONE
	_apply_story_checkpoint_dropdown_style(story_checkpoint_select)
	form.add_child(story_checkpoint_select)
	_refresh_story_chapter_options()
	_refresh_story_checkpoint_options()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_content.add_child(spacer)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	story_content.add_child(footer)
	var apply_button := Button.new()
	apply_button.name = "ApplyStoryCheckpointButton"
	apply_button.custom_minimum_size = Vector2(210, 40)
	_set_localized_property(apply_button, "text", "ui.staff.story_checkpoint.apply")
	apply_button.pressed.connect(_apply_story_checkpoint)
	_apply_button_style(apply_button, true)
	footer.add_child(apply_button)
	story_status_label = _label("", 11, UI_MUTED)
	story_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	story_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(story_status_label)


func _toggle_badge(badge_id: String) -> void:
	if busy:
		return
	await _submit_badges([badge_id], not bool(badge_state.get(badge_id, false)))


func _set_first_three() -> void:
	if busy:
		return
	var badge_ids: Array[String] = ["boulder", "cascade", "thunder"]
	await _submit_badges(badge_ids, true)


func _set_all(earned: bool) -> void:
	if busy:
		return
	var badge_ids: Array[String] = []
	for definition: Dictionary in BADGES:
		badge_ids.append(str(definition.get("id", "")))
	await _submit_badges(badge_ids, earned)


func _submit_badges(badge_ids: Array[String], earned: bool) -> void:
	_set_busy(true)
	_set_status(_t("ui.staff.badges.saving"), false)
	var service := get_node_or_null("/root/BadgeProgressionService")
	if service == null or not service.has_method("dev_set_gym_badges"):
		_set_busy(false)
		_set_status(_t("ui.staff.badges.unavailable"), true)
		return
	var result: Dictionary = await service.call("dev_set_gym_badges", REGION, badge_ids, earned)
	_set_busy(false)
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.staff.badges.update_failed"))), true)
		return
	set_badge_state(result)


func _show_tab(tab_id: String) -> void:
	active_tab = tab_id if tab_id in ["badges", "key_items", "story"] else "badges"
	if badge_content != null:
		badge_content.visible = active_tab == "badges"
	if key_item_content != null:
		key_item_content.visible = active_tab == "key_items"
	if story_content != null:
		story_content.visible = active_tab == "story"
	if badge_tab_button != null:
		_apply_button_style(badge_tab_button, active_tab == "badges")
	if key_item_tab_button != null:
		_apply_button_style(key_item_tab_button, active_tab == "key_items")
	if story_tab_button != null:
		_apply_button_style(story_tab_button, active_tab == "story")


func _refresh_story_chapter_options() -> void:
	if story_chapter_select == null:
		return
	var selected_id := _selected_story_chapter_id()
	story_chapter_select.clear()
	for chapter: Dictionary in STORY_CHAPTERS:
		story_chapter_select.add_item(_t(str(chapter.get("label_key", ""))))
		var index := story_chapter_select.item_count - 1
		var chapter_id := str(chapter.get("id", ""))
		story_chapter_select.set_item_metadata(index, chapter_id)
		if chapter_id == selected_id:
			story_chapter_select.select(index)
	if story_chapter_select.selected < 0 and story_chapter_select.item_count > 0:
		story_chapter_select.select(0)


func _refresh_story_checkpoint_options() -> void:
	if story_checkpoint_select == null:
		return
	var chapter_id := _selected_story_chapter_id()
	var selected_id := ""
	if story_checkpoint_select.selected >= 0:
		selected_id = str(story_checkpoint_select.get_item_metadata(story_checkpoint_select.selected))
	story_checkpoint_select.clear()
	for checkpoint: Dictionary in STORY_CHECKPOINTS:
		if str(checkpoint.get("chapter_id", "")) != chapter_id:
			continue
		story_checkpoint_select.add_item(_t(str(checkpoint.get("label_key", ""))))
		var index := story_checkpoint_select.item_count - 1
		var checkpoint_id := str(checkpoint.get("id", ""))
		story_checkpoint_select.set_item_metadata(index, checkpoint_id)
		if checkpoint_id == selected_id:
			story_checkpoint_select.select(index)
	if story_checkpoint_select.selected < 0 and story_checkpoint_select.item_count > 0:
		story_checkpoint_select.select(0)


func _selected_story_chapter_id() -> String:
	if story_chapter_select == null or story_chapter_select.selected < 0:
		return ""
	return str(story_chapter_select.get_item_metadata(story_chapter_select.selected))


func _on_story_chapter_selected(_index: int) -> void:
	_refresh_story_checkpoint_options()
	_set_story_status("", false)


func _apply_story_checkpoint() -> void:
	if busy or story_checkpoint_select == null or story_checkpoint_select.selected < 0:
		return
	var checkpoint_id := str(story_checkpoint_select.get_item_metadata(story_checkpoint_select.selected))
	var service := get_node_or_null("/root/PlayerGameStateService")
	if service == null or not service.has_method("dev_set_story_checkpoint"):
		_set_story_status(_t("ui.staff.story_checkpoint.unavailable"), true)
		return
	_set_busy(true)
	_set_story_status(_t("ui.staff.story_checkpoint.applying"), false)
	var result: Dictionary = await service.call("dev_set_story_checkpoint", checkpoint_id)
	_set_busy(false)
	if not bool(result.get("success", false)):
		_set_story_status(str(result.get("error", _t("ui.staff.story_checkpoint.failed"))), true)
		return
	_set_story_status(_t("ui.staff.story_checkpoint.applied"), false)
	var badge_service := get_node_or_null("/root/BadgeProgressionService")
	if badge_service != null and badge_service.has_method("load_gym_badges"):
		var badge_result: Dictionary = await badge_service.call("load_gym_badges")
		if bool(badge_result.get("success", false)):
			set_badge_state(badge_result)
	_load_key_items.call_deferred()


func _load_key_items() -> void:
	_set_key_item_status(_t("ui.staff.key_items.loading"), false)
	var service := get_node_or_null("/root/InventoryService")
	if service == null or not service.has_method("load_inventory"):
		_set_key_item_status(_t("ui.staff.key_items.unavailable"), true)
		return
	var result: Dictionary = await service.call("load_inventory")
	if not visible:
		return
	if not bool(result.get("success", false)):
		_set_key_item_status(str(result.get("error", _t("ui.staff.key_items.load_failed"))), true)
		return
	_set_key_item_state(result.get("items", []))


func _set_key_item_state(items_value: Variant) -> void:
	key_item_state.clear()
	if items_value is Array:
		for value: Variant in items_value as Array:
			if not (value is Dictionary):
				continue
			var item := value as Dictionary
			var item_id := str(item.get("itemId", item.get("item_id", item.get("id", "")))).strip_edges().to_lower()
			if item_id != "" and int(item.get("quantity", 0)) > 0:
				key_item_state[item_id] = true
	_set_key_item_status("", false)
	_render_key_items()


func _grant_all_key_items() -> void:
	var item_ids: Array[String] = []
	for definition: Dictionary in KEY_ITEMS:
		item_ids.append(str(definition.get("id", "")))
	await _grant_key_items(item_ids)


func _grant_key_items(item_ids: Array) -> void:
	if busy:
		return
	var missing_ids: Array[String] = []
	for item_id_value: Variant in item_ids:
		var item_id := str(item_id_value).strip_edges().to_lower()
		if item_id != "" and not bool(key_item_state.get(item_id, false)):
			missing_ids.append(item_id)
	if missing_ids.is_empty():
		_set_key_item_status(_t("ui.staff.key_items.already_owned"), false)
		return

	var service := get_node_or_null("/root/InventoryService")
	if service == null or not service.has_method("dev_add_item"):
		_set_key_item_status(_t("ui.staff.key_items.unavailable"), true)
		return

	_set_busy(true)
	_set_key_item_status(_t("ui.staff.key_items.saving"), false)
	var latest_items: Variant = []
	for item_id: String in missing_ids:
		var result: Dictionary = await service.call("dev_add_item", item_id, 1)
		if not bool(result.get("success", false)):
			_set_busy(false)
			_set_key_item_status(str(result.get("error", _t("ui.staff.key_items.update_failed"))), true)
			_render_key_items()
			return
		latest_items = result.get("items", latest_items)

	if service.has_method("load_inventory"):
		var inventory_result: Dictionary = await service.call("load_inventory")
		if bool(inventory_result.get("success", false)):
			latest_items = inventory_result.get("items", latest_items)
	_set_busy(false)
	_set_key_item_state(latest_items)
	_set_key_item_status(_t("ui.staff.key_items.added"), false)


func _render_key_items() -> void:
	var owned_count := 0
	for definition: Dictionary in KEY_ITEMS:
		var item_id := str(definition.get("id", ""))
		var owned := bool(key_item_state.get(item_id, false))
		if owned:
			owned_count += 1
		var button := key_item_buttons.get(item_id) as Button
		if button != null:
			button.disabled = busy or owned
			button.tooltip_text = _t(
				"ui.staff.key_items.owned" if owned else "ui.staff.key_items.grant"
			)
			button.add_theme_stylebox_override(
				"normal",
				_panel_style(
					Color("#112b27f2") if owned else UI_SURFACE,
					UI_SUCCESS if owned else UI_BORDER,
					9,
					1
				)
			)
		var state_label := key_item_status_labels.get(item_id) as Label
		if state_label != null:
			state_label.text = _t("ui.staff.key_items.owned" if owned else "ui.staff.key_items.missing")
			state_label.add_theme_color_override("font_color", UI_SUCCESS if owned else UI_MUTED)
	if not busy and key_item_status_label != null and key_item_status_label.text == "":
		_set_key_item_status(_t("ui.staff.key_items.progress", {
			"owned": owned_count,
			"total": KEY_ITEMS.size(),
		}), false)


func _render_badges() -> void:
	var earned_count := 0
	for definition: Dictionary in BADGES:
		var badge_id := str(definition.get("id", ""))
		var earned := bool(badge_state.get(badge_id, false))
		if earned:
			earned_count += 1
		var button := badge_buttons.get(badge_id) as Button
		if button == null:
			continue
		button.tooltip_text = "%s · %s" % [
			str(definition.get("name", "Badge")),
			(
				_t("ui.staff.badges.earned")
				if earned
				else _t("ui.staff.badges.locked")
			).capitalize(),
		]
		var icon_rect := badge_icon_rects.get(badge_id) as TextureRect
		if icon_rect != null:
			icon_rect.modulate = Color.WHITE if earned else Color("#6370809a")
		var state_label := badge_status_labels.get(badge_id) as Label
		if state_label != null:
			state_label.text = (
				_t("ui.staff.badges.earned")
				if earned
				else _t("ui.staff.badges.locked")
			)
			state_label.add_theme_color_override("font_color", UI_SUCCESS if earned else UI_MUTED)
		var style := _panel_style(
			Color("#112b27f2") if earned else UI_SURFACE,
			UI_SUCCESS if earned else UI_BORDER,
			9,
			1
		)
		button.add_theme_stylebox_override("normal", style)
	if not busy:
		_set_status(_t("ui.staff.badges.progress", {
			"earned": earned_count,
			"total": BADGES.size(),
		}), false)


func _set_busy(value: bool) -> void:
	busy = value
	for value_button: Variant in badge_buttons.values():
		var button := value_button as Button
		if button != null:
			button.disabled = value
	var named_buttons := find_children("*Button", "Button", true, false)
	for button_node: Node in named_buttons:
		var button := button_node as Button
		if button != null and button.name != "CloseButton":
			button.disabled = value
	_render_key_items()


func _set_status(message: String, is_error: bool) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_MUTED)


func _set_key_item_status(message: String, is_error: bool) -> void:
	if key_item_status_label == null:
		return
	key_item_status_label.text = message
	key_item_status_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_MUTED)


func _set_story_status(message: String, is_error: bool) -> void:
	if story_status_label == null:
		return
	story_status_label.text = message
	story_status_label.add_theme_color_override("font_color", UI_ERROR if is_error else UI_MUTED)


func _t(key: String, replacements: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager == null:
		return key
	return str(localization_manager.call("text", key, replacements))


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set_meta("i18n_source_%s" % property_name, key)
	control.set(property_name, _t(key))


func _localized_label(key: String, font_size: int, color: Color) -> Label:
	var label := _label("", font_size, color)
	_set_localized_property(label, "text", key)
	return label


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_render_badges()
	_render_key_items()
	_refresh_story_chapter_options()
	_refresh_story_checkpoint_options()


func _on_header_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		dragging = mouse_button.pressed
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and dragging:
		position += mouse_motion.relative
		_clamp_to_viewport()


func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = (viewport_size - POPUP_SIZE) * 0.5
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position.x = clampf(position.x, 8.0, maxf(viewport_size.x - size.x - 8.0, 8.0))
	position.y = clampf(position.y, 8.0, maxf(viewport_size.y - size.y - 8.0, 8.0))


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_button_style(button: Button, primary: bool) -> void:
	var background := Color("#253e29") if primary else UI_SURFACE
	var border := UI_ACCENT if primary else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_SURFACE_HOVER, UI_ACCENT, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#172d41"), UI_ACCENT, 8, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#09111c"), Color("#303b4b"), 8, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#687382"))


func _apply_story_checkpoint_dropdown_style(select: OptionButton) -> void:
	if select == null:
		return
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	select.add_theme_font_size_override("font_size", 14)
	select.add_theme_color_override("font_color", UI_TEXT)
	select.add_theme_color_override("font_hover_color", Color.WHITE)
	select.add_theme_color_override("font_pressed_color", Color.WHITE)
	select.add_theme_color_override("font_focus_color", Color.WHITE)
	select.add_theme_color_override("font_disabled_color", Color(UI_MUTED, 0.5))
	select.add_theme_constant_override("arrow_margin", 12)
	select.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	select.add_theme_stylebox_override(
		"normal",
		_dropdown_button_style(UI_SURFACE, UI_BORDER)
	)
	select.add_theme_stylebox_override(
		"hover",
		_dropdown_button_style(UI_SURFACE_HOVER, UI_ACCENT)
	)
	select.add_theme_stylebox_override(
		"pressed",
		_dropdown_button_style(Color("#172d41"), UI_ACCENT)
	)
	select.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	select.add_theme_stylebox_override(
		"disabled",
		_dropdown_button_style(Color("#09111c"), Color("#303b4b"))
	)

	var popup := select.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", UI_MUTED)
	popup.add_theme_color_override("font_hover_color", UI_TEXT)
	popup.add_theme_color_override("font_disabled_color", Color("#687382"))
	popup.add_theme_color_override("font_outline_color", Color("#02070b"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_stylebox_override("panel", _dropdown_popup_style())
	popup.add_theme_stylebox_override(
		"hover",
		_dropdown_item_style(Color("#17304afa"), UI_ACCENT)
	)
	popup.add_theme_icon_override("radio_checked", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", DROPDOWN_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", DROPDOWN_RADIO_UNCHECKED)


func _dropdown_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 8, 1)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 30
	style.content_margin_bottom = 8
	return style


func _dropdown_popup_style() -> StyleBoxFlat:
	var style := _dropdown_item_style(UI_BG, UI_BORDER, 9)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _dropdown_item_style(
	background: Color,
	border: Color,
	radius: int = 6
) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, 1)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
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
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)
