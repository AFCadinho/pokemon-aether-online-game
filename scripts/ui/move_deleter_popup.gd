class_name MoveDeleterPopup
extends PanelContainer

signal closed

const UI_BG := Color("#050b14fa")
const UI_RAISED := Color("#081522f5")
const UI_INTERACTIVE := Color("#0b1d30f2")
const UI_HOVER := Color("#112a44fa")
const UI_SELECTED := Color("#40202bfa")
const UI_BORDER := Color("#355672c0")
const UI_TEXT := Color("#eef5fb")
const UI_MUTED := Color("#91a4b7")
const UI_CYAN := Color("#74d7ef")
const UI_DANGER := Color("#ef7085")
const UI_GREEN := Color("#70d6a1")
const MOVE_SUMMARY_INDEX_PATH := "res://data/move_summary_index.json"
const TYPE_ICON_ROOT := "res://assets/sprites/types/small/"
const CATEGORY_ICON_PATHS := {
	"physical": "res://assets/battles/physical_move.png",
	"special": "res://assets/battles/special_move.png",
	"status": "res://assets/battles/status_move.png",
}
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")

var selected_party_index := -1
var selected_move_slot := -1
var request_in_progress := false
var move_summary_index: Dictionary = {}

var party_list: VBoxContainer
var pokemon_sprite: TextureRect
var pokemon_label: Label
var pokemon_types: HBoxContainer
var move_list: GridContainer
var status_label: Label
var delete_button: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(UI_BG, Color("#397b9cdd"), 14, 2))
	_load_move_summary_index()
	_build_interface()
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		var locale_callable := Callable(self, "_on_locale_changed")
		if not localization_manager.is_connected("locale_changed", locale_callable):
			localization_manager.connect("locale_changed", locale_callable)


func open_deleter() -> void:
	visible = true
	request_in_progress = false
	selected_move_slot = -1
	var party := _party()
	if party.is_empty():
		selected_party_index = -1
	else:
		selected_party_index = clampi(selected_party_index, 0, party.size() - 1)
		if selected_party_index < 0:
			selected_party_index = 0
	_refresh_party_list()
	_refresh_moves()
	_set_status(
		_t("ui.move_deleter.status.no_party")
		if party.is_empty()
		else _t("ui.move_deleter.status.choose_move"),
		party.is_empty()
	)


func close_deleter() -> void:
	if request_in_progress:
		return
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
	workspace.add_child(_build_move_panel())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", UI_MUTED)
	footer.add_child(status_label)
	delete_button = Button.new()
	_set_localized_property(delete_button, "text", "ui.move_deleter.delete")
	delete_button.custom_minimum_size = Vector2(170, 42)
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.disabled = true
	delete_button.pressed.connect(_on_delete_pressed)
	_apply_action_style(delete_button)
	footer.add_child(delete_button)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 10)
	var accent := Panel.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.add_theme_stylebox_override("panel", _panel_style(UI_DANGER, UI_DANGER, 2, 0))
	header.add_child(accent)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(heading)
	var title := Label.new()
	_set_localized_property(title, "text", "ui.move_deleter.title")
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UI_TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	_set_localized_property(subtitle, "text", "ui.move_deleter.subtitle")
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UI_MUTED)
	heading.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "×"
	_set_localized_property(close_button, "tooltip_text", "common.close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_deleter)
	_apply_secondary_style(close_button)
	header.add_child(close_button)
	return header


func _build_party_panel() -> Control:
	var panel := _workspace_panel(Vector2(225, 0))
	var stack := _panel_stack(panel)
	var caption := Label.new()
	_set_localized_property(caption, "text", "ui.move_deleter.party")
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


func _build_move_panel() -> Control:
	var panel := _workspace_panel(Vector2(0, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := _panel_stack(panel)
	var pokemon_header := HBoxContainer.new()
	pokemon_header.custom_minimum_size = Vector2(0, 68)
	pokemon_header.add_theme_constant_override("separation", 10)
	stack.add_child(pokemon_header)
	pokemon_sprite = TextureRect.new()
	pokemon_sprite.custom_minimum_size = Vector2(60, 60)
	pokemon_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pokemon_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pokemon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pokemon_header.add_child(pokemon_sprite)
	var pokemon_heading := VBoxContainer.new()
	pokemon_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pokemon_heading.alignment = BoxContainer.ALIGNMENT_CENTER
	pokemon_header.add_child(pokemon_heading)
	pokemon_label = Label.new()
	pokemon_label.add_theme_font_size_override("font_size", 17)
	pokemon_label.add_theme_color_override("font_color", UI_TEXT)
	pokemon_heading.add_child(pokemon_label)
	pokemon_types = HBoxContainer.new()
	pokemon_types.add_theme_constant_override("separation", 4)
	pokemon_heading.add_child(pokemon_types)
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("#35567299"))
	stack.add_child(divider)
	var hint := Label.new()
	_set_localized_property(hint, "text", "ui.move_deleter.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UI_MUTED)
	stack.add_child(hint)
	move_list = GridContainer.new()
	move_list.columns = 2
	move_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	move_list.add_theme_constant_override("h_separation", 8)
	move_list.add_theme_constant_override("v_separation", 8)
	stack.add_child(move_list)
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
		_apply_selectable_style(button, index == selected_party_index, false)
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
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		details.add_child(_text_label(_pokemon_name(pokemon), 14, UI_TEXT))
		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 4)
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(meta)
		meta.add_child(_text_label(_t("ui.move_deleter.level", {"level": pokemon.level}), 10, UI_MUTED))
		for type_value: Variant in pokemon.types:
			var type_icon := _type_icon(str(type_value), Vector2(18, 18))
			if type_icon != null:
				meta.add_child(type_icon)
		party_list.add_child(button)


func _on_party_selected(index: int) -> void:
	if request_in_progress or index < 0 or index >= _party().size():
		return
	selected_party_index = index
	selected_move_slot = -1
	_refresh_party_list()
	_refresh_moves()
	_set_status(_t("ui.move_deleter.status.choose_move"), false)


func _refresh_moves() -> void:
	_clear_children(move_list)
	_clear_children(pokemon_types)
	var pokemon := _selected_pokemon()
	if pokemon == null:
		pokemon_label.text = _t("ui.move_deleter.no_pokemon")
		pokemon_sprite.texture = null
		_refresh_action_state()
		return
	pokemon_label.text = "%s · %s" % [_pokemon_name(pokemon), _t("ui.move_deleter.level", {"level": pokemon.level})]
	pokemon_sprite.texture = PokemonAssets.load_home_sprite(pokemon.species, pokemon.shiny)
	for type_value: Variant in pokemon.types:
		var pokemon_type_icon := _type_icon(str(type_value), Vector2(22, 22))
		if pokemon_type_icon != null:
			pokemon_types.add_child(pokemon_type_icon)
	var can_delete := pokemon.moves.size() > 1
	for index in range(pokemon.moves.size()):
		var move_value: Variant = pokemon.moves[index]
		var move_id := _move_id(move_value)
		var fallback := (move_value as Dictionary) if move_value is Dictionary else {}
		var metadata := _move_metadata(move_id, fallback)
		var button := Button.new()
		button.name = "DeleteMove%d" % index
		button.custom_minimum_size = Vector2(245, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_delete else Control.CURSOR_ARROW
		button.tooltip_text = str(metadata.get("shortDesc", metadata.get("desc", "")))
		if can_delete:
			button.pressed.connect(_on_move_selected.bind(index))
		_apply_selectable_style(button, index == selected_move_slot, true)
		var row := _button_content(button, 10, 7, 10, 7)
		var type_icon := _type_icon(str(metadata.get("type", "")), Vector2(32, 32))
		if type_icon != null:
			row.add_child(type_icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 2)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(details)
		details.add_child(_text_label(_move_name(move_value), 14, UI_TEXT))
		var stats := _move_stats(metadata)
		if not stats.is_empty():
			details.add_child(_text_label(stats, 10, UI_MUTED))
		var category_icon := _category_icon(str(metadata.get("category", "")))
		if category_icon != null:
			row.add_child(category_icon)
		move_list.add_child(button)
	if not can_delete:
		_set_status(_t("ui.move_deleter.status.last_move"), true)
	_refresh_action_state()


func _on_move_selected(index: int) -> void:
	if request_in_progress:
		return
	selected_move_slot = index
	_refresh_moves()


func _on_delete_pressed() -> void:
	var pokemon := _selected_pokemon()
	if request_in_progress or pokemon == null or selected_move_slot < 0 or pokemon.moves.size() <= 1:
		return
	var move_id := _move_id(pokemon.moves[selected_move_slot])
	var move_name := _move_name(pokemon.moves[selected_move_slot])
	var dialog := AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
	dialog.name = "MoveDeleterConfirmation"
	add_child(dialog)
	dialog.configure(
		_t("ui.move_deleter.confirm.title"),
		_t("ui.move_deleter.confirm.message", {"pokemon": _pokemon_name(pokemon), "move": move_name}),
		_t("ui.move_deleter.confirm.delete"),
		_t("common.cancel")
	)
	dialog.confirmed.connect(_confirm_delete.bind(dialog, selected_move_slot, move_id, move_name), CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 250))


func _confirm_delete(dialog: AetherConfirmationDialog, move_slot: int, move_id: String, move_name: String) -> void:
	dialog.queue_free()
	var pokemon := _selected_pokemon()
	if pokemon == null or request_in_progress or pokemon.moves.size() <= 1:
		return
	request_in_progress = true
	_refresh_action_state()
	_set_status(_t("ui.move_deleter.status.deleting"), false)
	var pokemon_name := _pokemon_name(pokemon)
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		request_in_progress = false
		_set_status(_t("ui.move_deleter.error.delete"), true)
		_refresh_action_state()
		return
	var result: Dictionary = await party_service.call("delete_pokemon_move", pokemon.owned_pokemon_id, move_slot, move_id)
	request_in_progress = false
	if not bool(result.get("success", false)):
		_set_status(str(result.get("error", _t("ui.move_deleter.error.delete"))), true)
		_refresh_action_state()
		return
	selected_move_slot = -1
	_refresh_party_list()
	_refresh_moves()
	var message := _t("ui.move_deleter.result.deleted", {"pokemon": pokemon_name, "move": move_name})
	_set_status(message, false, UI_GREEN)
	get_tree().call_group("ui_overlay", "add_system_message", message)


func _refresh_action_state() -> void:
	if delete_button == null:
		return
	var pokemon := _selected_pokemon()
	delete_button.disabled = (
		request_in_progress
		or pokemon == null
		or pokemon.moves.size() <= 1
		or selected_move_slot < 0
	)


func _selected_pokemon() -> Pokemon:
	var party := _party()
	if selected_party_index < 0 or selected_party_index >= party.size():
		return null
	return party[selected_party_index]


func _pokemon_name(pokemon: Pokemon) -> String:
	if pokemon == null:
		return _t("ui.move_deleter.no_pokemon")
	if not pokemon.nickname.strip_edges().is_empty():
		return pokemon.nickname
	var species_id := pokemon.species_id if not pokemon.species_id.is_empty() else pokemon.species
	return _localized_content_name("species", species_id, pokemon.species)


func _move_id(value: Variant) -> String:
	if value is Dictionary:
		var move := value as Dictionary
		return str(move.get("id", move.get("moveId", move.get("name", "")))).strip_edges()
	return str(value).strip_edges()


func _move_name(value: Variant) -> String:
	var move_id := _move_id(value)
	var fallback := _format_id(move_id)
	if value is Dictionary:
		fallback = str((value as Dictionary).get("name", fallback))
	return _localized_content_name("moves", move_id, fallback)


func _load_move_summary_index() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_SUMMARY_INDEX_PATH))
	if parsed is Dictionary:
		move_summary_index = parsed as Dictionary


func _move_metadata(move_id: String, fallback: Dictionary = {}) -> Dictionary:
	var normalized := move_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	var metadata: Dictionary = {}
	var indexed: Variant = move_summary_index.get(normalized, {})
	if indexed is Dictionary:
		metadata = (indexed as Dictionary).duplicate(true)
	metadata.merge(fallback, true)
	if not metadata.has("basePower") and metadata.has("base_power"):
		metadata["basePower"] = metadata.get("base_power")
	return metadata


func _move_stats(metadata: Dictionary) -> String:
	var parts: Array[String] = []
	var pp := int(metadata.get("pp", metadata.get("maxPp", 0)))
	if pp > 0:
		parts.append("PP %d" % pp)
	var power := int(metadata.get("basePower", 0))
	parts.append("BP %d" % power if power > 0 else "BP —")
	var accuracy: Variant = metadata.get("accuracy", null)
	parts.append("ACC %d" % int(accuracy) if accuracy != null and not accuracy is bool and int(accuracy) > 0 else "ACC —")
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
	var path := "%s%s.png" % [TYPE_ICON_ROOT, normalized]
	if normalized.is_empty() or not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _category_icon(category: String) -> TextureRect:
	var path := str(CATEGORY_ICON_PATHS.get(category.strip_edges().to_lower(), ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path) as Texture2D
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _apply_selectable_style(button: Button, selected: bool, destructive: bool) -> void:
	var accent := UI_DANGER if destructive else UI_CYAN
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	var normal := _panel_style(UI_SELECTED if selected else UI_INTERACTIVE, accent if selected else UI_BORDER, 8, 1)
	var hover := _panel_style(UI_HOVER, accent, 8, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _panel_style(UI_SELECTED, accent, 8, 1))
	button.add_theme_stylebox_override("focus", hover.duplicate())


func _apply_action_style(button: Button) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_disabled_color", Color("#637483"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#5a1825"), UI_DANGER, 7, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#752235"), Color("#ff92a5"), 7, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#3d101a"), UI_DANGER, 7, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#09121b"), Color("#263746"), 7, 1))


func _apply_secondary_style(button: Button) -> void:
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(UI_INTERACTIVE, UI_BORDER, 7, 1))
	button.add_theme_stylebox_override("hover", _panel_style(UI_HOVER, UI_CYAN, 7, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0b2d43"), UI_CYAN, 7, 1))


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


func _t(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	return str(localization_manager.call("text", key, values)) if localization_manager != null else key


func _set_localized_property(control: Control, property_name: String, key: String) -> void:
	control.set(property_name, _t(key))
	control.set_meta("i18n_source_%s" % property_name, key)


func _on_locale_changed(_locale: String) -> void:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	_refresh_party_list()
	_refresh_moves()
