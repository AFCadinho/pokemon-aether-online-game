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
const UI_GOLD := Color("#f3cf70")
const UI_PURPLE := Color("#c694ff")
const MOVE_SUMMARY_INDEX_PATH := "res://data/move_summary_index.json"
const TYPE_ICON_ROOT := "res://assets/sprites/types/small/"
const CATEGORY_ICON_PATHS := {
	"physical": "res://assets/battles/physical_move.png",
	"special": "res://assets/battles/special_move.png",
	"status": "res://assets/battles/status_move.png",
}
const DROPDOWN_ARROW: Texture2D = preload("res://assets/ui/photo_mode_dropdown_arrow.svg")
const DROPDOWN_RADIO_CHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_checked.svg")
const DROPDOWN_RADIO_UNCHECKED: Texture2D = preload("res://assets/ui/photo_mode_radio_unchecked.svg")
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")

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
var move_summary_index: Dictionary = {}

var party_list: VBoxContainer
var search_input: LineEdit
var source_filter: OptionButton
var move_list: VBoxContainer
var move_summary_label: Label
var current_moves_list: VBoxContainer
var selected_pokemon_label: Label
var selected_pokemon_sprite: TextureRect
var selected_pokemon_types: HBoxContainer
var status_label: Label
var learn_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#397b9cdd"), 14, 2))
	_load_move_summary_index()
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
	var panel := _workspace_panel(Vector2(225, 0))
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
	var panel := _workspace_panel(Vector2(380, 0))
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
	source_filter.custom_minimum_size = Vector2(138, 38)
	source_filter.alignment = HORIZONTAL_ALIGNMENT_LEFT
	source_filter.focus_mode = Control.FOCUS_NONE
	source_filter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	source_filter.item_selected.connect(_on_source_filter_selected)
	_apply_source_filter_style(source_filter)
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
	var panel := _workspace_panel(Vector2(270, 0))
	var stack := _panel_stack(panel)
	var pokemon_header := HBoxContainer.new()
	pokemon_header.custom_minimum_size = Vector2(0, 62)
	pokemon_header.add_theme_constant_override("separation", 9)
	stack.add_child(pokemon_header)
	selected_pokemon_sprite = TextureRect.new()
	selected_pokemon_sprite.custom_minimum_size = Vector2(56, 56)
	selected_pokemon_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_pokemon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	selected_pokemon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_header.add_child(selected_pokemon_sprite)
	var pokemon_heading := VBoxContainer.new()
	pokemon_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_heading.alignment = BoxContainer.ALIGNMENT_CENTER
	pokemon_heading.add_theme_constant_override("separation", 3)
	pokemon_header.add_child(pokemon_heading)
	selected_pokemon_label = Label.new()
	selected_pokemon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_pokemon_label.add_theme_font_size_override("font_size", 16)
	selected_pokemon_label.add_theme_color_override("font_color", UI_TEXT)
	pokemon_heading.add_child(selected_pokemon_label)
	selected_pokemon_types = HBoxContainer.new()
	selected_pokemon_types.add_theme_constant_override("separation", 4)
	pokemon_heading.add_child(selected_pokemon_types)
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#35567299"))
	stack.add_child(divider)
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
		button.custom_minimum_size = Vector2(0, 68)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_party_selected.bind(index))
		_apply_selectable_style(button, index == selected_party_index)
		var row := _button_content(button, 7, 6, 9, 6)
		var sprite := TextureRect.new()
		sprite.custom_minimum_size = Vector2(52, 52)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.texture = PokemonAssets.load_home_sprite(pokemon.species, pokemon.shiny)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sprite)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 2)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		details.add_child(_text_label(_pokemon_name(pokemon), 14, UI_TEXT))
		var meta_row := HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 4)
		meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(meta_row)
		meta_row.add_child(_text_label(_t("ui.move_mentor.level", {"level": pokemon.level}), 10, UI_MUTED))
		for type_value: Variant in pokemon.types:
			var type_icon := _type_icon(str(type_value), Vector2(18, 18))
			if type_icon != null:
				meta_row.add_child(type_icon)
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
		var metadata := _move_metadata(move_id)
		var move_type := str(metadata.get("type", ""))
		var category := str(metadata.get("category", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = str(metadata.get("shortDesc", metadata.get("desc", "")))
		button.pressed.connect(_on_move_selected.bind(move_id))
		_apply_selectable_style(button, move_id == selected_move_id)
		var row := _button_content(button, 8, 6, 9, 6)
		var type_icon := _type_icon(move_type, Vector2(30, 30))
		if type_icon != null:
			row.add_child(type_icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 2)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		details.add_child(_text_label(_move_name(candidate), 14, UI_TEXT))
		var meta_row := HBoxContainer.new()
		meta_row.add_theme_constant_override("separation", 6)
		meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(meta_row)
		meta_row.add_child(_source_badge(source))
		var level := int(candidate.get("level", 0))
		if level > 0:
			meta_row.add_child(_text_label(_t("ui.move_mentor.level", {"level": level}), 9, UI_MUTED))
		var stats := _move_stats_text(metadata)
		if not stats.is_empty():
			var stats_label := _text_label(stats, 9, UI_MUTED)
			meta_row.add_child(stats_label)
		var category_icon := _category_icon(category)
		if category_icon != null:
			row.add_child(category_icon)
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
	_clear_children(selected_pokemon_types)
	var pokemon := _selected_pokemon()
	if pokemon == null:
		selected_pokemon_label.text = _t("ui.move_mentor.no_pokemon")
		selected_pokemon_sprite.texture = null
		_refresh_action_state()
		return
	selected_pokemon_label.text = "%s · %s" % [_pokemon_name(pokemon), _t("ui.move_mentor.level", {"level": pokemon.level})]
	selected_pokemon_sprite.texture = PokemonAssets.load_home_sprite(pokemon.species, pokemon.shiny)
	for type_value: Variant in pokemon.types:
		var pokemon_type_icon := _type_icon(str(type_value), Vector2(22, 22))
		if pokemon_type_icon != null:
			selected_pokemon_types.add_child(pokemon_type_icon)
	for index in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_NONE
		if index < pokemon.moves.size():
			var move_value: Variant = pokemon.moves[index]
			var move_id := _move_id_from_value(move_value)
			var move_data := (move_value as Dictionary) if move_value is Dictionary else {}
			var metadata := _move_metadata(move_id, move_data)
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.tooltip_text = str(metadata.get("shortDesc", metadata.get("desc", "")))
			_apply_selectable_style(button, false)
			var row := _button_content(button, 8, 7, 8, 7)
			var type_icon := _type_icon(str(metadata.get("type", "")), Vector2(28, 28))
			if type_icon != null:
				row.add_child(type_icon)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details.alignment = BoxContainer.ALIGNMENT_CENTER
			details.add_theme_constant_override("separation", 2)
			details.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(details)
			details.add_child(_text_label(_move_name_from_value(move_value), 13, UI_TEXT))
			var stats := _move_stats_text(metadata, true)
			if not stats.is_empty():
				details.add_child(_text_label(stats, 9, UI_MUTED))
			var category_icon := _category_icon(str(metadata.get("category", "")))
			if category_icon != null:
				row.add_child(category_icon)
		else:
			button.text = _t("ui.move_mentor.empty_slot")
			button.disabled = true
			_apply_button_style(button, false)
		current_moves_list.add_child(button)
	_refresh_action_state()


func _on_learn_pressed() -> void:
	var pokemon := _selected_pokemon()
	if request_in_progress or pokemon == null or selected_move_id == "":
		return
	if pokemon.moves.size() >= 4:
		_open_replacement_dialog(pokemon)
		return
	await _teach_selected_move(-1)


func _open_replacement_dialog(pokemon: Pokemon) -> void:
	selected_replace_slot = -1
	var dialog := AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
	dialog.name = "MoveMentorReplacementDialog"
	add_child(dialog)
	dialog.configure(
		_t("ui.move_mentor.replace_dialog.title"),
		_t("ui.move_mentor.replace_dialog.message", {
			"pokemon": _pokemon_name(pokemon),
			"move": _selected_move_name(),
		}),
		_t("ui.move_mentor.replace_dialog.confirm"),
		_t("common.cancel")
	)
	var grid := GridContainer.new()
	grid.name = "ReplacementMoveGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var buttons: Array[Button] = []
	for index in range(mini(4, pokemon.moves.size())):
		var move_value: Variant = pokemon.moves[index]
		var move_id := _move_id_from_value(move_value)
		var move_data := (move_value as Dictionary) if move_value is Dictionary else {}
		var metadata := _move_metadata(move_id, move_data)
		var button := Button.new()
		button.name = "ReplacementMove%d" % index
		button.custom_minimum_size = Vector2(250, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = str(metadata.get("shortDesc", metadata.get("desc", "")))
		_apply_selectable_style(button, false)
		var row := _button_content(button, 8, 7, 8, 7)
		var type_icon := _type_icon(str(metadata.get("type", "")), Vector2(30, 30))
		if type_icon != null:
			row.add_child(type_icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 2)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		details.add_child(_text_label(_move_name_from_value(move_value), 13, UI_TEXT))
		var stats := _move_stats_text(metadata, true)
		if not stats.is_empty():
			details.add_child(_text_label(stats, 9, UI_MUTED))
		var category_icon := _category_icon(str(metadata.get("category", "")))
		if category_icon != null:
			row.add_child(category_icon)
		buttons.append(button)
		button.pressed.connect(_on_dialog_replace_slot_selected.bind(index, buttons, dialog))
		grid.add_child(button)
	dialog.add_custom_control(grid)
	dialog.confirm_button.disabled = true
	dialog.confirmed.connect(_confirm_replacement.bind(dialog), CONNECT_ONE_SHOT)
	dialog.canceled.connect(_cancel_replacement.bind(dialog), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(620, 430))


func _on_dialog_replace_slot_selected(index: int, buttons: Array[Button], dialog: AetherConfirmationDialog) -> void:
	selected_replace_slot = index
	for button_index in range(buttons.size()):
		_apply_selectable_style(buttons[button_index], button_index == selected_replace_slot)
	dialog.confirm_button.disabled = false


func _confirm_replacement(dialog: AetherConfirmationDialog) -> void:
	var replace_slot := selected_replace_slot
	dialog.queue_free()
	if replace_slot < 0:
		return
	await _teach_selected_move(replace_slot)


func _cancel_replacement(dialog: AetherConfirmationDialog) -> void:
	selected_replace_slot = -1
	dialog.queue_free()


func _teach_selected_move(replace_slot: int) -> void:
	var pokemon := _selected_pokemon()
	if request_in_progress or pokemon == null or selected_move_id == "":
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
	var move_id := _move_id_from_value(value)
	var fallback := ""
	if value is Dictionary:
		var move: Dictionary = value as Dictionary
		fallback = str(move.get("name", _format_id(move_id)))
	else:
		fallback = _format_id(move_id)
	return _localized_content_name("moves", move_id, fallback)


func _move_id_from_value(value: Variant) -> String:
	if value is Dictionary:
		var move := value as Dictionary
		return str(move.get("id", move.get("moveId", move.get("name", "")))).strip_edges()
	return str(value).strip_edges()


func _load_move_summary_index() -> void:
	move_summary_index.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_SUMMARY_INDEX_PATH))
	if parsed is Dictionary:
		move_summary_index = parsed as Dictionary


func _move_metadata(move_id: String, fallback: Dictionary = {}) -> Dictionary:
	var normalized_id := move_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	var metadata: Dictionary = {}
	var indexed_value: Variant = move_summary_index.get(normalized_id, {})
	if indexed_value is Dictionary:
		metadata = (indexed_value as Dictionary).duplicate(true)
	metadata.merge(fallback, true)
	if not metadata.has("basePower") and metadata.has("base_power"):
		metadata["basePower"] = metadata.get("base_power")
	return metadata


func _move_stats_text(metadata: Dictionary, include_current_pp := false) -> String:
	var parts: Array[String] = []
	var pp := int(metadata.get("pp", 0))
	var max_pp := int(metadata.get("maxPp", metadata.get("maxpp", pp)))
	if include_current_pp and max_pp > 0:
		parts.append("PP %d/%d" % [pp, max_pp])
	elif pp > 0:
		parts.append("PP %d" % pp)
	var power_value: Variant = metadata.get("basePower", null)
	if power_value != null and int(power_value) > 0:
		parts.append("BP %d" % int(power_value))
	var accuracy_value: Variant = metadata.get("accuracy", null)
	if accuracy_value != null and int(accuracy_value) > 0:
		parts.append("ACC %d" % int(accuracy_value))
	return "  ·  ".join(parts)


func _button_content(button: Button, left: int, top: int, right: int, bottom: int) -> HBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	return row


func _text_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _type_icon(type_name: String, minimum_size: Vector2) -> TextureRect:
	var normalized := type_name.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if normalized.is_empty():
		return null
	var path := "%s%s.png" % [TYPE_ICON_ROOT, normalized]
	if not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path) as Texture2D
	icon.tooltip_text = _format_id(normalized)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _category_icon(category: String) -> TextureRect:
	var normalized := category.strip_edges().to_lower()
	var path := str(CATEGORY_ICON_PATHS.get(normalized, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path) as Texture2D
	icon.tooltip_text = _format_id(normalized)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _source_badge(source: String) -> Label:
	var color := _source_color(source)
	var badge := _text_label(_source_name(source).to_upper(), 10, color.lightened(0.28))
	badge.custom_minimum_size = Vector2(76, 18)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.tooltip_text = _source_name(source)
	var style := _panel_style(Color(color, 0.13), Color(color, 0.62), 5, 1)
	style.content_margin_left = 6
	style.content_margin_top = 1
	style.content_margin_right = 6
	style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", style)
	return badge


func _source_color(source: String) -> Color:
	return {
		"relearn": UI_CYAN,
		"evolution": UI_GREEN,
		"egg": Color("#f3a8c8"),
		"tutor": UI_PURPLE,
		"special": UI_GOLD,
		"event": Color("#ff9f76"),
		"legacy": Color("#b6a3ff"),
		"legacyEvent": Color("#ff7fa6"),
		"preEvolution": Color("#80d5b4"),
	}.get(source, UI_MUTED) as Color


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
	var normal := _panel_style(UI_SELECTED if selected else UI_INTERACTIVE, UI_CYAN if selected else UI_BORDER, 8, 1)
	var hover := _panel_style(UI_HOVER, UI_CYAN, 8, 1)
	var pressed := _panel_style(UI_SELECTED, UI_CYAN, 8, 1)
	for style: StyleBoxFlat in [normal, hover, pressed]:
		style.shadow_color = Color("#00000052")
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover.duplicate())


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
	input.add_theme_font_size_override("font_size", 13)
	var normal := _panel_style(UI_INTERACTIVE, UI_BORDER, 7, 1)
	normal.content_margin_left = 10
	normal.content_margin_right = 8
	var focus := _panel_style(UI_HOVER, UI_CYAN, 7, 1)
	focus.content_margin_left = 10
	focus.content_margin_right = 8
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)


func _apply_source_filter_style(select: OptionButton) -> void:
	select.add_theme_font_size_override("font_size", 12)
	select.add_theme_color_override("font_color", UI_TEXT)
	select.add_theme_color_override("font_hover_color", Color.WHITE)
	select.add_theme_color_override("font_pressed_color", Color.WHITE)
	select.add_theme_color_override("font_disabled_color", Color("#637483"))
	select.add_theme_constant_override("arrow_margin", 10)
	select.add_theme_icon_override("arrow", DROPDOWN_ARROW)
	var normal := _dropdown_button_style(UI_INTERACTIVE, UI_BORDER)
	var hover := _dropdown_button_style(UI_HOVER, UI_CYAN)
	var pressed := _dropdown_button_style(Color("#0b2d43"), UI_CYAN)
	select.add_theme_stylebox_override("normal", normal)
	select.add_theme_stylebox_override("hover", hover)
	select.add_theme_stylebox_override("pressed", pressed)
	select.add_theme_stylebox_override("focus", hover.duplicate())

	var popup := select.get_popup()
	popup.transparent_bg = true
	popup.borderless = true
	popup.max_size = Vector2i(360, 420)
	popup.add_theme_font_size_override("font_size", 12)
	popup.add_theme_color_override("font_color", UI_TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_disabled_color", UI_MUTED)
	popup.add_theme_color_override("font_separator_color", UI_CYAN)
	popup.add_theme_color_override("font_outline_color", Color("#02070b"))
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 5)
	popup.add_theme_stylebox_override("panel", _dropdown_popup_style())
	popup.add_theme_stylebox_override("hover", _dropdown_item_style(Color("#12344cf7"), UI_CYAN))
	popup.add_theme_stylebox_override("separator", _dropdown_item_style(Color.TRANSPARENT, Color("#31566b88"), 0))
	popup.add_theme_icon_override("radio_checked", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked", DROPDOWN_RADIO_UNCHECKED)
	popup.add_theme_icon_override("radio_checked_disabled", DROPDOWN_RADIO_CHECKED)
	popup.add_theme_icon_override("radio_unchecked_disabled", DROPDOWN_RADIO_UNCHECKED)


func _dropdown_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, 7, 1)
	style.content_margin_left = 10
	style.content_margin_top = 5
	style.content_margin_right = 28
	style.content_margin_bottom = 5
	return style


func _dropdown_popup_style() -> StyleBoxFlat:
	var style := _dropdown_item_style(Color("#050e18fc"), Color("#4e8caae6"), 9)
	style.content_margin_left = 5
	style.content_margin_top = 6
	style.content_margin_right = 5
	style.content_margin_bottom = 6
	style.shadow_color = Color("#00000099")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _dropdown_item_style(background: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius, 1 if radius > 0 else 0)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style
