class_name MoveMentorPopup
extends PanelContainer

signal closed

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_HOVER := Color("#112a44fa")
const UI_SELECTED := Color("#153b55fa")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_CYAN := Color("#74d7ef")
const UI_GREEN := Color("#70d6a1")
const UI_DANGER := Color("#ef7085")

const SOURCE_ORDER: Array[String] = [
	"relearn",
	"evolution",
	"egg",
	"tutor",
	"special",
	"event",
	"legacy",
	"legacyEvent",
	"preEvolution",
]
const SOURCE_LOCALIZATION_KEYS := {
	"relearn": "ui.move_mentor.source.relearn",
	"evolution": "ui.pokedex.moves.source.evolution",
	"egg": "ui.pokedex.moves.source.egg",
	"tutor": "ui.pokedex.moves.source.tutor",
	"special": "ui.pokedex.moves.source.special",
	"event": "ui.pokedex.moves.source.event",
	"legacy": "ui.pokedex.moves.source.legacy",
	"legacyEvent": "ui.pokedex.moves.source.legacy_event",
	"preEvolution": "ui.pokedex.moves.source.pre_evolution",
}

var selected_party_index := -1
var selected_move_id := ""
var selected_replace_slot := -1
var candidates: Array[Dictionary] = []
var request_generation := 0
var request_in_progress := false

var party_list: VBoxContainer
var search_input: LineEdit
var source_filter: OptionButton
var move_list: VBoxContainer
var move_summary_label: Label
var current_moves_list: VBoxContainer
var selected_pokemon_label: Label
var status_label: Label
var learn_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#397b9cdd"), 14, 2))
	_build_interface()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open_mentor() -> void:
	visible = true
	request_generation += 1
	request_in_progress = false
	selected_move_id = ""
	selected_replace_slot = -1
	search_input.text = ""
	source_filter.select(0)
	_refresh_party_list()
	var party := _party()
	if party.is_empty():
		selected_party_index = -1
		candidates.clear()
		_refresh_move_list()
		_refresh_current_moves()
		_set_status(_t("ui.move_mentor.status.no_party"), true)
		return
	selected_party_index = clampi(selected_party_index, 0, party.size() - 1)
	if selected_party_index < 0:
		selected_party_index = 0
	_refresh_party_list()
	await _load_selected_catalog()


func close_mentor() -> void:
	if request_in_progress:
		return
	request_generation += 1
	visible = false
	closed.emit()


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 11)
	margin.add_child(layout)
	layout.add_child(_build_header())

	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 12)
	layout.add_child(workspace)
	workspace.add_child(_build_party_panel())
	workspace.add_child(_build_catalog_panel())
	workspace.add_child(_build_current_moves_panel())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", UI_MUTED)
	footer.add_child(status_label)
	learn_button = Button.new()
	_set_localized_property(learn_button, "text", "ui.move_mentor.learn")
	learn_button.custom_minimum_size = Vector2(170, 42)
	learn_button.focus_mode = Control.FOCUS_NONE
	learn_button.disabled = true
	learn_button.pressed.connect(_on_learn_pressed)
	_apply_button_style(learn_button, true)
	footer.add_child(learn_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 10)
	var accent := Panel.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.add_theme_stylebox_override("panel", _panel_style(UI_CYAN, UI_CYAN, 2, 0))
	header.add_child(accent)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(heading)
	var title := Label.new()
	_set_localized_property(title, "text", "ui.move_mentor.title")
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.move_mentor.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_mentor)
	_apply_button_style(close_button, false)
	header.add_child(close_button)
	return header


func _build_party_panel() -> Control:
	var panel := _workspace_panel(Vector2(215, 0))
	var stack := _panel_stack(panel)
	var caption := Label.new()
	_set_localized_property(caption, "text", "ui.move_mentor.party")
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", UI_CYAN)
	stack.add_child(caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	party_list = VBoxContainer.new()
	party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_list.add_theme_constant_override("separation", 7)
	scroll.add_child(party_list)
	return panel


func _build_catalog_panel() -> Control:
	var panel := _workspace_panel(Vector2(355, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := _panel_stack(panel)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 7)
	stack.add_child(search_row)
	search_input = LineEdit.new()
	_set_localized_property(search_input, "placeholder_text", "ui.move_mentor.search")
	search_input.clear_button_enabled = true
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_filter_changed)
	_apply_line_edit_style(search_input)
	search_row.add_child(search_input)
	source_filter = OptionButton.new()
	source_filter.custom_minimum_size = Vector2(128, 36)
	source_filter.item_selected.connect(_on_source_filter_selected)
	_apply_button_style(source_filter, false)
	search_row.add_child(source_filter)
	_populate_source_filter()
	move_summary_label = Label.new()
	move_summary_label.add_theme_font_size_override("font_size", 10)
	move_summary_label.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(move_summary_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	move_list = VBoxContainer.new()
	move_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_list.add_theme_constant_override("separation", 6)
	scroll.add_child(move_list)
	return panel


func _build_current_moves_panel() -> Control:
	var panel := _workspace_panel(Vector2(250, 0))
	var stack := _panel_stack(panel)
	selected_pokemon_label = Label.new()
	selected_pokemon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_pokemon_label.add_theme_font_size_override("font_size", 16)
	selected_pokemon_label.add_theme_color_override("font_color", UI_TEXT)
	stack.add_child(selected_pokemon_label)
	var hint := Label.new()
	_set_localized_property(hint, "text", "ui.move_mentor.replace_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(hint)
	current_moves_list = VBoxContainer.new()
	current_moves_list.add_theme_constant_override("separation", 7)
	stack.add_child(current_moves_list)
	return panel


func _workspace_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(UI_RAISED, UI_BORDER, 10, 1))
	return panel


func _panel_stack(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	return stack


func _refresh_party_list() -> void:
	_clear_children(party_list)
	var party := _party()
	for index in range(party.size()):
		var pokemon: Pokemon = party[index]
		var button := Button.new()
		button.text = "%s\n%s" % [_pokemon_name(pokemon), _t("ui.move_mentor.level", {"level": pokemon.level})]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_party_selected.bind(index))
		_apply_selectable_style(button, index == selected_party_index)
		party_list.add_child(button)


func _on_party_selected(index: int) -> void:
	if request_in_progress or index < 0 or index >= _party().size():
		return
	selected_party_index = index
	selected_move_id = ""
	selected_replace_slot = -1
	_refresh_party_list()
	await _load_selected_catalog()


func _load_selected_catalog() -> void:
	var pokemon := _selected_pokemon()
	if pokemon == null or pokemon.owned_pokemon_id <= 0:
		candidates.clear()
		_refresh_move_list()
		_refresh_current_moves()
		_set_status(_t("ui.move_mentor.error.invalid_pokemon"), true)
		return
	request_generation += 1
	var generation := request_generation
	request_in_progress = true
	_refresh_action_state()
	_set_status(_t("ui.move_mentor.status.loading"), false)
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		request_in_progress = false
		_set_status(_t("ui.move_mentor.error.load"), true)
		return
	var result: Dictionary = await party_service.call("get_move_mentor_catalog", pokemon.owned_pokemon_id)
	if generation != request_generation:
		return
	request_in_progress = false
	if not bool(result.get("success", false)):
		candidates.clear()
		_refresh_move_list()
		_refresh_current_moves()
		_set_status(str(result.get("error", _t("ui.move_mentor.error.load"))), true)
		return
	candidates.clear()
	var moves_value: Variant = result.get("moves", [])
	if moves_value is Array:
		for value: Variant in moves_value as Array:
			if value is Dictionary:
				candidates.append((value as Dictionary).duplicate(true))
	_refresh_move_list()
	_refresh_current_moves()
	_set_status(
		_t("ui.move_mentor.status.no_moves")
		if candidates.is_empty()
		else _t("ui.move_mentor.status.choose_move"),
		false
	)


func _refresh_move_list() -> void:
	_clear_children(move_list)
	var filtered := _filtered_candidates()
	move_summary_label.text = _t("ui.move_mentor.available_count", {"count": filtered.size()})
	if filtered.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.move_mentor.no_search_results") if not search_input.text.strip_edges().is_empty() else _t("ui.move_mentor.no_moves")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", UI_MUTED)
		move_list.add_child(empty)
		_refresh_action_state()
		return
	for candidate: Dictionary in filtered:
		var move_id := str(candidate.get("moveId", ""))
		var source := str(candidate.get("source", ""))
		var button := Button.new()
		button.text = "%s  ·  %s" % [_move_name(candidate), _source_name(source)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str((candidate.get("move", {}) as Dictionary).get("shortDesc", "")) if candidate.get("move", {}) is Dictionary else ""
		button.pressed.connect(_on_move_selected.bind(move_id))
		_apply_selectable_style(button, move_id == selected_move_id)
		move_list.add_child(button)
	_refresh_action_state()


func _filtered_candidates() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var query := search_input.text.strip_edges().to_lower()
	var selected_source := ""
	if source_filter.selected > 0:
		selected_source = str(source_filter.get_item_metadata(source_filter.selected))
	for candidate: Dictionary in candidates:
		if selected_source != "" and str(candidate.get("source", "")) != selected_source:
			continue
		var move_id := str(candidate.get("moveId", ""))
		var name := _move_name(candidate)
		if query != "" and not move_id.to_lower().contains(query) and not name.to_lower().contains(query):
			continue
		filtered.append(candidate)
	return filtered


func _on_filter_changed(_value: String) -> void:
	_refresh_move_list()


func _on_source_filter_selected(_index: int) -> void:
	_refresh_move_list()


func _on_move_selected(move_id: String) -> void:
	if request_in_progress:
		return
	selected_move_id = move_id
	_refresh_move_list()
	_refresh_action_state()


func _refresh_current_moves() -> void:
	_clear_children(current_moves_list)
	var pokemon := _selected_pokemon()
	if pokemon == null:
		selected_pokemon_label.text = _t("ui.move_mentor.no_pokemon")
		_refresh_action_state()
		return
	selected_pokemon_label.text = "%s · %s" % [_pokemon_name(pokemon), _t("ui.move_mentor.level", {"level": pokemon.level})]
	for index in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		if index < pokemon.moves.size():
			button.text = _move_name_from_value(pokemon.moves[index])
			button.pressed.connect(_on_replace_slot_selected.bind(index))
			_apply_selectable_style(button, index == selected_replace_slot)
		else:
			button.text = _t("ui.move_mentor.empty_slot")
			button.disabled = true
			_apply_button_style(button, false)
		current_moves_list.add_child(button)
	_refresh_action_state()


func _on_replace_slot_selected(index: int) -> void:
	if request_in_progress:
		return
	selected_replace_slot = index
	_refresh_current_moves()


func _on_learn_pressed() -> void:
	var pokemon := _selected_pokemon()
	if request_in_progress or pokemon == null or selected_move_id == "":
		return
	var replace_slot := selected_replace_slot if pokemon.moves.size() >= 4 else -1
	if pokemon.moves.size() >= 4 and replace_slot < 0:
		_set_status(_t("ui.move_mentor.status.choose_replacement"), true)
		return
	request_in_progress = true
	_refresh_action_state()
	_set_status(_t("ui.move_mentor.status.saving"), false)
	var learned_name := _selected_move_name()
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		request_in_progress = false
		_set_status(_t("ui.move_mentor.error.learn"), true)
		_refresh_action_state()
		return
	var result: Dictionary = await party_service.call(
		"learn_pokemon_move",
		pokemon.owned_pokemon_id,
		selected_move_id,
		replace_slot,
		false,
		"",
		"move-mentor"
	)
	request_in_progress = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.move_mentor.error.learn"))), true)
		_refresh_action_state()
		return
	selected_move_id = ""
	selected_replace_slot = -1
	_refresh_party_list()
	await _load_selected_catalog()
	_set_status(_t("ui.move_mentor.status.learned", {"pokemon": _pokemon_name(_selected_pokemon()), "move": learned_name}), false, UI_GREEN)


func _refresh_action_state() -> void:
	if learn_button == null:
		return
	var pokemon := _selected_pokemon()
	learn_button.disabled = (
		request_in_progress
		or pokemon == null
		or selected_move_id == ""
		or (pokemon.moves.size() >= 4 and selected_replace_slot < 0)
	)


func _selected_pokemon() -> Pokemon:
	var party := _party()
	if selected_party_index < 0 or selected_party_index >= party.size():
		return null
	return party[selected_party_index]


func _selected_move_name() -> String:
	for candidate: Dictionary in candidates:
		if str(candidate.get("moveId", "")) == selected_move_id:
			return _move_name(candidate)
	return _format_id(selected_move_id)


func _move_name(candidate: Dictionary) -> String:
	var move_id := str(candidate.get("moveId", ""))
	var fallback := str(candidate.get("name", _format_id(move_id)))
	return _localized_content_name("moves", move_id, fallback)


func _move_name_from_value(value: Variant) -> String:
	var move_id := ""
	var fallback := ""
	if value is Dictionary:
		var move: Dictionary = value as Dictionary
		move_id = str(move.get("id", move.get("moveId", move.get("name", ""))))
		fallback = str(move.get("name", _format_id(move_id)))
	else:
		move_id = str(value)
		fallback = _format_id(move_id)
	return _localized_content_name("moves", move_id, fallback)


func _pokemon_name(pokemon: Pokemon) -> String:
	if pokemon == null:
		return _t("ui.move_mentor.no_pokemon")
	if not pokemon.nickname.strip_edges().is_empty():
		return pokemon.nickname
	var species_id := pokemon.species_id if not pokemon.species_id.is_empty() else pokemon.species
	return _localized_content_name("species", species_id, pokemon.species)


func _source_name(source: String) -> String:
	return _t(str(SOURCE_LOCALIZATION_KEYS.get(source, "ui.move_mentor.source.relearn")))


func _populate_source_filter() -> void:
	var selected_source := ""
	if source_filter.item_count > 0 and source_filter.selected > 0:
		selected_source = str(source_filter.get_item_metadata(source_filter.selected))
	source_filter.clear()
	source_filter.add_item(_t("ui.move_mentor.source.all"))
	source_filter.set_item_metadata(0, "")
	for source: String in SOURCE_ORDER:
		source_filter.add_item(_source_name(source))
		source_filter.set_item_metadata(source_filter.item_count - 1, source)
		if source == selected_source:
			source_filter.select(source_filter.item_count - 1)


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_populate_source_filter()
	_refresh_party_list()
	_refresh_move_list()
	_refresh_current_moves()


func _set_status(message: String, is_error: bool, color: Color = UI_MUTED) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", UI_DANGER if is_error else color)


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		child.queue_free()


func _format_id(value: String) -> String:
	return value.strip_edges().replace("_", "-").replace("-", " ").capitalize()


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	return str(localization_manager.call("text", key, values)) if localization_manager != null else key


func _party() -> Array:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null:
		return []
	var party_value: Variant = player_save.get("party")
	return party_value as Array if party_value is Array else []


func _localized_content_name(kind: String, content_id: String, fallback: String) -> String:
	var content_localization := get_node_or_null("/root/ContentLocalization")
	if content_localization == null:
		return fallback
	return str(content_localization.call("display_name", kind, content_id, fallback))


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set(property_name, _t(key))
	control.set_meta("i18n_source_%s" % property_name, key)


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _apply_selectable_style(button: Button, selected: bool) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(UI_SELECTED if selected else UI_INTERACTIVE, UI_CYAN if selected else UI_BORDER, 7, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(UI_SELECTED, UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("focus", _panel_style(UI_HOVER, UI_CYAN, 7, 1))


func _apply_button_style(button: BaseButton, primary: bool) -> void:
	var normal := Color("#124563") if primary else UI_INTERACTIVE
	var border := UI_CYAN if primary else UI_BORDER
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#637483"))
	button.add_theme_stylebox_override("normal", _panel_style(normal, border, 7, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0b2d43"), UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#09121b"), Color("#263746"), 7, 1))


func _apply_line_edit_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", UI_MUTED)
	input.add_theme_stylebox_override("normal", _panel_style(UI_INTERACTIVE, UI_BORDER, 7, 1))
	input.add_theme_stylebox_override("focus", _panel_style(UI_HOVER, UI_CYAN, 7, 1))
