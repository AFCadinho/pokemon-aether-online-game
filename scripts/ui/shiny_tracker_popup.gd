class_name ShinyTrackerPopup
extends PanelContainer

signal closed
signal share_requested(hunt: Dictionary)

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_CYAN := Color("#71e4f3")
const UI_PURPLE := Color("#c694ff")
const UI_GOLD := Color("#f3cf70")
const UI_GREEN := Color("#70d6a1")
const UI_DANGER := Color("#ef7085")

var tracker_state: Dictionary = {}
var selected_species: Dictionary = {}
var request_busy := false
var replace_confirmation := false
var search_request_id := 0
var shared_mode := false

var hunt_name_label: Label
var hunt_count_label: Label
var hunt_count_context_label: Label
var hunt_detail_label: Label
var hunt_sprite: TextureRect
var stop_button: Button
var share_button: Button
var stat_labels: Dictionary = {}
var history_list: VBoxContainer
var search_input: LineEdit
var results_list: VBoxContainer
var selected_label: Label
var start_button: Button
var status_label: Label
var search_timer: Timer
var overview_panel: PanelContainer
var selector_panel: PanelContainer
var stats_title: Label
var stats_grid: GridContainer
var history_title: Label
var history_scroll: ScrollContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#8a62b7dd"), 14, 2))
	_build_interface()
	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.25
	search_timer.timeout.connect(_refresh_search)
	add_child(search_timer)


func open_tracker() -> void:
	shared_mode = false
	selector_panel.visible = true
	stats_title.visible = true
	stats_grid.visible = true
	history_title.visible = true
	history_scroll.visible = true
	overview_panel.size_flags_horizontal = Control.SIZE_FILL
	stop_button.visible = true
	share_button.visible = true
	visible = true
	_set_status(_t("ui.shiny_tracker.status.loading"), UI_MUTED)
	request_busy = true
	_refresh_actions()
	var tracker_service := get_node_or_null("/root/ShinyTrackerService")
	var result: Dictionary = (
		await tracker_service.call("load_tracker")
		if tracker_service != null
		else {"success": false, "error": _t("ui.shiny_tracker.error.load")}
	)
	request_busy = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.shiny_tracker.error.load"))), UI_DANGER)
		_refresh_actions()
		return
	tracker_state = _as_dictionary(result.get("tracker"))
	_render_tracker()
	_set_status(_t("ui.shiny_tracker.status.ready"), UI_MUTED)
	await _refresh_search()


func open_shared_hunt(summary: Dictionary) -> void:
	shared_mode = true
	visible = true
	selector_panel.visible = false
	stats_title.visible = false
	stats_grid.visible = false
	history_title.visible = false
	history_scroll.visible = false
	overview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_button.visible = false
	share_button.visible = false
	tracker_state = {
		"stats": {},
		"activeHunt": _as_dictionary(summary.get("hunt")),
		"recentHunts": [],
	}
	_render_tracker()
	_set_status(
		_t("ui.shiny_tracker.shared_by", {"player": str(summary.get("ownerDisplayName", "Trainer"))}),
		UI_PURPLE
	)


func close_tracker() -> void:
	if request_busy:
		return
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	layout.add_child(_build_header())
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	layout.add_child(workspace)
	workspace.add_child(_build_overview_panel())
	workspace.add_child(_build_selector_panel())
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	layout.add_child(status_label)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	header.add_theme_constant_override("separation", 11)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = load("res://assets/items/icons/SHINYTRACKER.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(heading)
	var title := Label.new()
	title.text = _t("ui.shiny_tracker.title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _t("ui.shiny_tracker.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.pressed.connect(close_tracker)
	_apply_button_style(close_button)
	header.add_child(close_button)
	return header


func _build_overview_panel() -> Control:
	var panel := PanelContainer.new()
	overview_panel = panel
	panel.custom_minimum_size = Vector2(480, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 11, 1))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 13)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var section := Label.new()
	section.text = _t("ui.shiny_tracker.active_hunt")
	section.add_theme_font_size_override("font_size", 11)
	section.add_theme_color_override("font_color", UI_PURPLE)
	stack.add_child(section)
	var hunt_card := PanelContainer.new()
	hunt_card.custom_minimum_size = Vector2(0, 145)
	hunt_card.add_theme_stylebox_override("panel", _panel_style(Color("#0a1626f5"), Color("#6f4f91cc"), 10, 1))
	stack.add_child(hunt_card)
	var hunt_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		hunt_margin.add_theme_constant_override("margin_%s" % side, 12)
	hunt_card.add_child(hunt_margin)
	var hunt_stack := VBoxContainer.new()
	hunt_stack.add_theme_constant_override("separation", 5)
	hunt_margin.add_child(hunt_stack)
	var hunt_header := HBoxContainer.new()
	hunt_header.add_theme_constant_override("separation", 8)
	hunt_stack.add_child(hunt_header)
	var hunt_details := VBoxContainer.new()
	hunt_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunt_details.add_theme_constant_override("separation", 5)
	hunt_header.add_child(hunt_details)
	hunt_name_label = Label.new()
	hunt_name_label.add_theme_font_size_override("font_size", 18)
	hunt_name_label.add_theme_color_override("font_color", UI_TEXT)
	hunt_details.add_child(hunt_name_label)
	hunt_count_label = Label.new()
	hunt_count_label.add_theme_font_size_override("font_size", 32)
	hunt_count_label.add_theme_color_override("font_color", UI_CYAN)
	hunt_details.add_child(hunt_count_label)
	hunt_count_context_label = Label.new()
	hunt_count_context_label.text = _t("ui.shiny_tracker.hunt_encounters")
	hunt_count_context_label.add_theme_font_size_override("font_size", 9)
	hunt_count_context_label.add_theme_color_override("font_color", UI_CYAN)
	hunt_details.add_child(hunt_count_context_label)
	hunt_detail_label = Label.new()
	hunt_detail_label.add_theme_font_size_override("font_size", 10)
	hunt_detail_label.add_theme_color_override("font_color", UI_MUTED)
	hunt_details.add_child(hunt_detail_label)
	hunt_sprite = TextureRect.new()
	hunt_sprite.custom_minimum_size = Vector2(76, 76)
	hunt_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hunt_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hunt_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hunt_sprite.visible = false
	hunt_header.add_child(hunt_sprite)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	hunt_stack.add_child(actions)
	share_button = Button.new()
	share_button.text = _t("ui.shiny_tracker.share")
	share_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_button.pressed.connect(_on_share_pressed)
	_apply_button_style(share_button, true)
	actions.add_child(share_button)
	stop_button = Button.new()
	stop_button.text = _t("ui.shiny_tracker.stop")
	stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stop_button.pressed.connect(_on_stop_pressed)
	_apply_button_style(stop_button)
	actions.add_child(stop_button)
	stats_title = Label.new()
	stats_title.text = _t("ui.shiny_tracker.overall_stats")
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", UI_GOLD)
	stack.add_child(stats_title)
	stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(stats_grid)
	for definition in [
		["lifetimeEligibleEncounters", "ui.shiny_tracker.stat.lifetime"],
		["encountersSinceLastShiny", "ui.shiny_tracker.stat.current_dry"],
		["longestDryStreak", "ui.shiny_tracker.stat.longest_dry"],
		["shinyEncounters", "ui.shiny_tracker.stat.shinies"],
	]:
		var stat_card := _build_stat_card(str(definition[1]))
		stats_grid.add_child(stat_card[0])
		stat_labels[str(definition[0])] = stat_card[1]
	history_title = Label.new()
	history_title.text = _t("ui.shiny_tracker.recent_hunts")
	history_title.add_theme_font_size_override("font_size", 11)
	history_title.add_theme_color_override("font_color", UI_GOLD)
	stack.add_child(history_title)
	history_scroll = ScrollContainer.new()
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(history_scroll)
	history_list = VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list.add_theme_constant_override("separation", 5)
	history_scroll.add_child(history_list)
	return panel


func _build_selector_panel() -> Control:
	var panel := PanelContainer.new()
	selector_panel = panel
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 11, 1))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 13)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	var title := Label.new()
	title.text = _t("ui.shiny_tracker.choose_target")
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(title)
	var hint := Label.new()
	hint.text = _t("ui.shiny_tracker.family_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(hint)
	search_input = LineEdit.new()
	search_input.placeholder_text = _t("ui.shiny_tracker.search")
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(_on_search_changed)
	_apply_line_edit_style(search_input)
	stack.add_child(search_input)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	results_list = VBoxContainer.new()
	results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_list.add_theme_constant_override("separation", 5)
	scroll.add_child(results_list)
	selected_label = Label.new()
	selected_label.text = _t("ui.shiny_tracker.no_target")
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(selected_label)
	start_button = Button.new()
	start_button.text = _t("ui.shiny_tracker.start")
	start_button.custom_minimum_size = Vector2(0, 42)
	start_button.pressed.connect(_on_start_pressed)
	_apply_button_style(start_button, true)
	stack.add_child(start_button)
	return panel


func _build_stat_card(title_text: String) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(218, 56)
	panel.add_theme_stylebox_override("panel", _panel_style(UI_INTERACTIVE, Color("#28445eb5"), 8, 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(stack)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", UI_CYAN)
	stack.add_child(value)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(title)
	return [panel, value]


func _render_tracker() -> void:
	var stats := _as_dictionary(tracker_state.get("stats"))
	for key: String in stat_labels:
		(stat_labels[key] as Label).text = _format_number(int(stats.get(key, 0)))
	var active := _active_hunt()
	var has_active := not active.is_empty()
	if has_active:
		var target_species := str(active.get("targetSpeciesName", ""))
		hunt_name_label.text = str(active.get("evolutionLineName", target_species if not target_species.is_empty() else "Pokémon"))
		hunt_count_label.text = _format_number(int(active.get("encounterCount", 0)))
		hunt_count_context_label.visible = true
		hunt_sprite.texture = PokemonAssets.load_home_sprite(target_species)
		hunt_sprite.visible = hunt_sprite.texture != null
		var member_names: Array[String] = []
		for member_value: Variant in active.get("evolutionLineMembers", []):
			if member_value is Dictionary:
				member_names.append(str((member_value as Dictionary).get("name", "")))
		hunt_detail_label.text = " • ".join(member_names)
	else:
		hunt_name_label.text = _t("ui.shiny_tracker.no_active")
		hunt_count_label.text = "—"
		hunt_count_context_label.visible = false
		hunt_detail_label.text = _t("ui.shiny_tracker.no_active_hint")
		hunt_sprite.texture = null
		hunt_sprite.visible = false
	for child: Node in history_list.get_children():
		child.queue_free()
	var recent := _as_array(tracker_state.get("recentHunts"))
	for hunt_value: Variant in recent:
		if hunt_value is Dictionary:
			history_list.add_child(_build_history_row(hunt_value as Dictionary))
	if recent.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.shiny_tracker.no_history")
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", UI_MUTED)
		history_list.add_child(empty)
	_refresh_actions()


func _build_history_row(hunt: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var name := Label.new()
	name.text = str(hunt.get("evolutionLineName", "Pokémon"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 11)
	name.add_theme_color_override("font_color", UI_TEXT)
	row.add_child(name)
	var count := Label.new()
	count.text = _format_number(int(hunt.get("encounterCount", 0)))
	count.add_theme_color_override("font_color", UI_GREEN if str(hunt.get("status", "")) == "completed" else UI_MUTED)
	row.add_child(count)
	return row


func _on_search_changed(_value: String) -> void:
	search_request_id += 1
	search_timer.start()


func _refresh_search() -> void:
	for child: Node in results_list.get_children():
		child.queue_free()
	var request_id := search_request_id
	var pokedex_service := get_node_or_null("/root/PokedexService")
	var result: Dictionary = (
		await pokedex_service.call("search_species", search_input.text.strip_edges(), 40)
		if pokedex_service != null
		else {"success": false}
	)
	if request_id != search_request_id:
		return
	if not bool(result.get("success", false)):
		_add_result_message(_t("ui.shiny_tracker.error.search"), UI_DANGER)
		return
	for species_value: Variant in result.get("species", []):
		if species_value is Dictionary:
			results_list.add_child(_build_species_button(species_value as Dictionary))
	if results_list.get_child_count() == 0:
		_add_result_message(_t("ui.shiny_tracker.no_results"), UI_MUTED)


func _build_species_button(species: Dictionary) -> Button:
	var button := Button.new()
	button.text = "#%03d  %s" % [int(species.get("nationalDexNumber", 0)), str(species.get("name", "Pokémon"))]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(_select_species.bind(species.duplicate(true)))
	_apply_button_style(button)
	return button


func _select_species(species: Dictionary) -> void:
	selected_species = species
	replace_confirmation = false
	selected_label.text = _t("ui.shiny_tracker.selected", {"name": str(species.get("name", "Pokémon"))})
	selected_label.add_theme_color_override("font_color", UI_CYAN)
	_refresh_actions()


func _on_start_pressed() -> void:
	if selected_species.is_empty() or request_busy:
		return
	var has_active := not _active_hunt().is_empty()
	if has_active and not replace_confirmation:
		replace_confirmation = true
		_set_status(_t("ui.shiny_tracker.confirm_replace"), UI_GOLD)
		_refresh_actions()
		return
	request_busy = true
	_refresh_actions()
	var tracker_service := get_node_or_null("/root/ShinyTrackerService")
	var result: Dictionary = (
		await tracker_service.call("start_hunt", str(selected_species.get("id", "")), has_active)
		if tracker_service != null
		else {"success": false, "error": _t("ui.shiny_tracker.error.start")}
	)
	request_busy = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.shiny_tracker.error.start"))), UI_DANGER)
		_refresh_actions()
		return
	tracker_state = _as_dictionary(result.get("tracker"))
	replace_confirmation = false
	_render_tracker()
	_set_status(_t("ui.shiny_tracker.status.started"), UI_GREEN)


func _on_stop_pressed() -> void:
	var active := _active_hunt()
	if active.is_empty() or request_busy:
		return
	request_busy = true
	_refresh_actions()
	var tracker_service := get_node_or_null("/root/ShinyTrackerService")
	var result: Dictionary = (
		await tracker_service.call("stop_hunt", str(active.get("id", "")))
		if tracker_service != null
		else {"success": false, "error": _t("ui.shiny_tracker.error.stop")}
	)
	request_busy = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.shiny_tracker.error.stop"))), UI_DANGER)
		_refresh_actions()
		return
	tracker_state = _as_dictionary(result.get("tracker"))
	_render_tracker()
	_set_status(_t("ui.shiny_tracker.status.stopped"), UI_MUTED)


func _on_share_pressed() -> void:
	var active := _active_hunt()
	if not active.is_empty() and not request_busy:
		share_requested.emit(active.duplicate(true))


func _refresh_actions() -> void:
	var has_active := not _active_hunt().is_empty()
	stop_button.disabled = request_busy or not has_active
	share_button.disabled = request_busy or not has_active
	start_button.disabled = request_busy or selected_species.is_empty()
	if shared_mode:
		stop_button.disabled = true
		share_button.disabled = true
	if replace_confirmation:
		start_button.text = _t("ui.shiny_tracker.confirm_button")
	elif has_active:
		start_button.text = _t("ui.shiny_tracker.replace")
	else:
		start_button.text = _t("ui.shiny_tracker.start")


func _active_hunt() -> Dictionary:
	return _as_dictionary(tracker_state.get("activeHunt"))


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _add_result_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 42)
	label.add_theme_color_override("font_color", color)
	results_list.add_child(label)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _format_number(value: int) -> String:
	var raw := str(maxi(value, 0))
	var output := ""
	while raw.length() > 3:
		output = "." + raw.right(3) + output
		raw = raw.left(-3)
	return raw + output


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		return str(localization_manager.call("text", key, values))
	var fallback := key
	for value_key: Variant in values:
		fallback = fallback.replace("{%s}" % str(value_key), str(values[value_key]))
	return fallback


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _apply_button_style(button: Button, primary: bool = false) -> void:
	var border := UI_PURPLE if primary else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(UI_INTERACTIVE, border, 7, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#122a43fa"), UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#07101bf5"), UI_PURPLE, 7, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#09121dcc"), Color("#25384a99"), 7, 1))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#647383"))


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_stylebox_override("normal", _panel_style(Color("#030812e8"), UI_BORDER, 7, 1))
	input.add_theme_stylebox_override("focus", _panel_style(Color("#050d18f5"), UI_CYAN, 7, 1))
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", UI_MUTED)
