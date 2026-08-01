extends CanvasLayer

class_name StarterChoiceDialog

signal finished(choice: Dictionary)

const PANEL_SIZE := Vector2(1080, 690)
const UI_BG := Color("#050b14fa")
const UI_SURFACE := Color("#081522f5")
const UI_RAISED := Color("#0b1a2bf2")
const UI_HOVER := Color("#112a44fa")
const UI_BORDER := Color("#315070")
const UI_ACCENT := Color("#60d3ff")
const UI_GOLD := Color("#e3bd68")
const UI_TEXT := Color("#f4f0de")
const UI_MUTED := Color("#aeb8c5")

var choices: Array = []
var filtered_choices: Array = []
var selected_choice: Dictionary = {}
var card_buttons: Dictionary = {}

var search_input: LineEdit
var generation_filter: OptionButton
var result_count_label: Label
var choice_grid: GridContainer
var preview_sprite: TextureRect
var preview_name: Label
var preview_meta: Label
var preview_types: Label
var evolution_lines: VBoxContainer
var choose_button: Button
var confirmation_layer: Control
var confirmation_question: Label


func _ready() -> void:
	layer = 120
	_build_ui()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)


func open(available_choices: Array) -> void:
	choices = []
	for value: Variant in available_choices:
		if value is Dictionary:
			choices.append((value as Dictionary).duplicate(true))
	selected_choice = {}
	search_input.text = ""
	generation_filter.select(0)
	_apply_filters()
	search_input.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if confirmation_layer.visible:
			confirmation_layer.visible = false
			return
		_finish({})


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#01050bd9")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "StarterChoicePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -PANEL_SIZE * 0.5
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _panel_style(UI_BG, UI_GOLD, 15, 1))
	backdrop.add_child(panel)

	var outer_margin := MarginContainer.new()
	_set_margins(outer_margin, 20, 17, 20, 20)
	panel.add_child(outer_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	outer_margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)
	var title := _label(_t("ui.starter_choice.title"), 23, UI_TEXT)
	title.name = "Title"
	heading.add_child(title)
	var subtitle := _label(_t("ui.starter_choice.subtitle"), 11, UI_MUTED)
	subtitle.name = "Subtitle"
	heading.add_child(subtitle)

	var close_button := Button.new()
	close_button.text = _t("ui.starter_choice.cancel")
	close_button.custom_minimum_size = Vector2(94, 38)
	close_button.pressed.connect(_finish.bind({}))
	_apply_button_style(close_button, false)
	header.add_child(close_button)

	var prompt_panel := PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color("#102033e8"), Color("#8d7440aa"), 9, 1))
	root.add_child(prompt_panel)
	var prompt_margin := MarginContainer.new()
	_set_margins(prompt_margin, 13, 9, 13, 9)
	prompt_panel.add_child(prompt_margin)
	var prompt := _label(_t("ui.starter_choice.childhood_question"), 12, UI_GOLD)
	prompt.name = "ChildhoodQuestion"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_margin.add_child(prompt)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 9)
	root.add_child(filters)
	search_input = LineEdit.new()
	search_input.name = "SearchInput"
	search_input.placeholder_text = _t("ui.starter_choice.search")
	search_input.custom_minimum_size = Vector2(360, 38)
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_filter_changed)
	_apply_input_style(search_input)
	filters.add_child(search_input)

	generation_filter = OptionButton.new()
	generation_filter.name = "GenerationFilter"
	generation_filter.custom_minimum_size = Vector2(190, 38)
	generation_filter.add_item(_t("ui.starter_choice.all_generations"), 0)
	for generation in range(1, 10):
		generation_filter.add_item(_t("ui.starter_choice.generation").replace("{generation}", str(generation)), generation)
	generation_filter.item_selected.connect(_on_generation_selected)
	_apply_button_style(generation_filter, false)
	filters.add_child(generation_filter)

	result_count_label = _label("", 11, UI_MUTED)
	result_count_label.custom_minimum_size = Vector2(120, 38)
	result_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filters.add_child(result_count_label)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)

	var catalog_panel := PanelContainer.new()
	catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE, UI_BORDER, 10, 1))
	content.add_child(catalog_panel)
	var catalog_margin := MarginContainer.new()
	_set_margins(catalog_margin, 10, 10, 10, 10)
	catalog_panel.add_child(catalog_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_margin.add_child(scroll)
	choice_grid = GridContainer.new()
	choice_grid.name = "ChoiceGrid"
	choice_grid.columns = 4
	choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_grid.add_theme_constant_override("h_separation", 8)
	choice_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(choice_grid)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(292, 0)
	preview_panel.add_theme_stylebox_override("panel", _panel_style(UI_SURFACE, Color("#3d7596"), 10, 1))
	content.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	_set_margins(preview_margin, 15, 14, 15, 14)
	preview_panel.add_child(preview_margin)
	var preview := VBoxContainer.new()
	preview.add_theme_constant_override("separation", 8)
	preview_margin.add_child(preview)
	var sprite_stage := PanelContainer.new()
	sprite_stage.custom_minimum_size = Vector2(0, 176)
	sprite_stage.add_theme_stylebox_override("panel", _panel_style(Color("#07111eee"), UI_BORDER, 9, 1))
	preview.add_child(sprite_stage)
	var sprite_center := CenterContainer.new()
	sprite_stage.add_child(sprite_center)
	preview_sprite = TextureRect.new()
	preview_sprite.custom_minimum_size = Vector2(154, 154)
	preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_sprite.texture = PokemonAssets.load_unknown_icon()
	sprite_center.add_child(preview_sprite)

	preview_name = _label(_t("ui.starter_choice.select_prompt"), 20, UI_TEXT)
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(preview_name)
	preview_meta = _label("", 10, UI_MUTED)
	preview_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(preview_meta)
	preview_types = _label("", 11, UI_ACCENT)
	preview_types.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(preview_types)
	var divider := HSeparator.new()
	preview.add_child(divider)
	var evolution_title := _label(_t("ui.starter_choice.evolution_line"), 10, UI_GOLD)
	evolution_title.name = "EvolutionTitle"
	preview.add_child(evolution_title)
	evolution_lines = VBoxContainer.new()
	evolution_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evolution_lines.add_theme_constant_override("separation", 6)
	preview.add_child(evolution_lines)
	choose_button = Button.new()
	choose_button.text = _t("ui.starter_choice.choose")
	choose_button.custom_minimum_size = Vector2(0, 44)
	choose_button.disabled = true
	choose_button.pressed.connect(_show_confirmation)
	_apply_button_style(choose_button, true)
	preview.add_child(choose_button)

	_build_confirmation(backdrop)


func _build_confirmation(parent: Control) -> void:
	confirmation_layer = Control.new()
	confirmation_layer.name = "ConfirmationLayer"
	confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.visible = false
	parent.add_child(confirmation_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("#01050be8")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_layer.add_child(dim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-230, -125)
	card.size = Vector2(460, 250)
	card.add_theme_stylebox_override("panel", _panel_style(UI_BG, UI_GOLD, 13, 2))
	confirmation_layer.add_child(card)
	var margin := MarginContainer.new()
	_set_margins(margin, 22, 20, 22, 20)
	card.add_child(margin)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 13)
	margin.add_child(layout)
	var title := _label(_t("ui.starter_choice.confirm_title"), 21, UI_TEXT)
	title.name = "ConfirmationTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	confirmation_question = _label("", 13, UI_MUTED)
	confirmation_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(confirmation_question)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)
	var back_button := Button.new()
	back_button.text = _t("ui.starter_choice.back")
	back_button.custom_minimum_size = Vector2(130, 42)
	back_button.pressed.connect(_hide_confirmation)
	_apply_button_style(back_button, false)
	buttons.add_child(back_button)
	var confirm_button := Button.new()
	confirm_button.text = _t("ui.starter_choice.confirm")
	confirm_button.custom_minimum_size = Vector2(170, 42)
	confirm_button.pressed.connect(_confirm_choice)
	_apply_button_style(confirm_button, true)
	buttons.add_child(confirm_button)


func _apply_filters(_unused: Variant = null) -> void:
	var query := search_input.text.strip_edges().to_lower()
	var generation := generation_filter.get_selected_id()
	filtered_choices = []
	for value: Variant in choices:
		var choice := value as Dictionary
		if generation > 0 and int(choice.get("generation", 0)) != generation:
			continue
		var searchable := "%s %s" % [choice.get("name", ""), choice.get("speciesId", "")]
		if not query.is_empty() and not searchable.to_lower().contains(query):
			continue
		filtered_choices.append(choice)
	_render_cards()
	result_count_label.text = _t("ui.starter_choice.available").replace("{count}", str(filtered_choices.size()))


func _render_cards() -> void:
	for child: Node in choice_grid.get_children():
		child.queue_free()
	card_buttons.clear()
	if filtered_choices.is_empty():
		var empty_label := _label(_t("ui.starter_choice.no_results"), 12, UI_MUTED)
		empty_label.custom_minimum_size = Vector2(680, 80)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		choice_grid.add_child(empty_label)
		return

	for value: Variant in filtered_choices:
		var choice := value as Dictionary
		var species_id := str(choice.get("speciesId", ""))
		var button := Button.new()
		button.name = "Starter_%s" % species_id.replace("-", "_")
		button.custom_minimum_size = Vector2(160, 142)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_select_choice.bind(choice))
		choice_grid.add_child(button)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_set_margins(margin, 7, 6, 7, 7)
		button.add_child(margin)
		var layout := VBoxContainer.new()
		layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.alignment = BoxContainer.ALIGNMENT_CENTER
		layout.add_theme_constant_override("separation", 1)
		margin.add_child(layout)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(88, 88)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = PokemonAssets.load_home_sprite(str(choice.get("name", species_id)))
		if icon.texture == null:
			icon.texture = PokemonAssets.load_unknown_icon()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(icon)
		var name_label := _label(str(choice.get("name", species_id)), 12, UI_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(name_label)
		var meta := _label("Gen %s · #%04d" % [choice.get("generation", 0), choice.get("nationalDexNumber", 0)], 9, UI_MUTED)
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(meta)
		card_buttons[species_id] = button
		_apply_card_style(button, species_id == str(selected_choice.get("speciesId", "")))


func _select_choice(choice: Dictionary) -> void:
	selected_choice = choice.duplicate(true)
	for species_id: String in card_buttons:
		_apply_card_style(card_buttons[species_id] as Button, species_id == str(selected_choice.get("speciesId", "")))
	var species_name := str(selected_choice.get("name", selected_choice.get("speciesId", "Pokemon")))
	preview_sprite.texture = PokemonAssets.load_home_sprite(species_name)
	if preview_sprite.texture == null:
		preview_sprite.texture = PokemonAssets.load_unknown_icon()
	preview_name.text = species_name
	preview_meta.text = "Generation %s · #%04d" % [selected_choice.get("generation", 0), selected_choice.get("nationalDexNumber", 0)]
	var types: Array = selected_choice.get("types", []) as Array
	preview_types.text = " · ".join(types)
	for child: Node in evolution_lines.get_children():
		child.queue_free()
	var paths: Array = selected_choice.get("evolutionPaths", []) as Array
	for path_index in range(mini(paths.size(), 3)):
		var path_value: Variant = paths[path_index]
		if not (path_value is Array):
			continue
		var names: Array[String] = []
		for stage_value: Variant in path_value as Array:
			if stage_value is Dictionary:
				names.append(str((stage_value as Dictionary).get("name", "?")))
		var line := _label("  →  ".join(names), 11, UI_TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		evolution_lines.add_child(line)
	choose_button.disabled = false
	choose_button.text = _t("ui.starter_choice.choose_named").replace("{pokemon}", species_name)


func _show_confirmation() -> void:
	if selected_choice.is_empty():
		return
	var species_name := str(selected_choice.get("name", "Pokemon"))
	confirmation_question.text = _t("ui.starter_choice.confirm_question").replace("{pokemon}", species_name)
	confirmation_layer.visible = true


func _hide_confirmation() -> void:
	confirmation_layer.visible = false


func _confirm_choice() -> void:
	if selected_choice.is_empty():
		return
	_finish(selected_choice)


func _finish(choice: Dictionary) -> void:
	finished.emit(choice.duplicate(true))
	queue_free()


func _on_filter_changed(_value: String) -> void:
	_apply_filters()


func _on_generation_selected(_index: int) -> void:
	_apply_filters()


func _on_locale_changed(_locale: String) -> void:
	# This first-run modal is short-lived. Rebuilding it keeps every generated
	# label and filter option in sync if the locale changes while it is open.
	var current_choices := choices.duplicate(true)
	for child: Node in get_children():
		child.queue_free()
	_build_ui()
	open(current_choices)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_card_style(button: Button, selected: bool) -> void:
	var border := UI_GOLD if selected else UI_BORDER
	button.add_theme_stylebox_override("normal", _panel_style(UI_RAISED, border, 9, 2 if selected else 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_ACCENT, 9, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#071624fa"), UI_GOLD, 9, 2))
	button.add_theme_stylebox_override("focus", _panel_style(UI_RAISED, UI_ACCENT, 9, 2))


func _apply_button_style(button: BaseButton, primary: bool) -> void:
	var normal_bg := Color("#123b26f0") if primary else UI_RAISED
	var border := Color("#3f9f68") if primary else UI_BORDER
	var hover_bg := Color("#1a5a38ee") if primary else UI_HOVER
	var hover_border := Color("#80e2a2") if primary else UI_ACCENT
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#778194"))
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(hover_bg, hover_border, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#071624f2"), hover_border, 8, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#08111bd0"), Color("#26384b88"), 8, 1))


func _apply_input_style(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", UI_TEXT)
	input.add_theme_color_override("font_placeholder_color", UI_MUTED)
	input.add_theme_color_override("caret_color", UI_ACCENT)
	input.add_theme_stylebox_override("normal", _panel_style(Color("#030812e8"), UI_BORDER, 8, 1))
	input.add_theme_stylebox_override("focus", _panel_style(Color("#071225f2"), UI_ACCENT, 8, 2))


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)


func _t(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key))
	return key
