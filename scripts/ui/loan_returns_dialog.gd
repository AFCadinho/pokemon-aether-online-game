extends Window

signal locate_requested(entry: Dictionary)
signal summary_requested(pokemon_payload: Dictionary)
signal count_changed(count: int)

const WINDOW_SIZE := Vector2i(700, 520)
const BG := Color("#050912fa")
const SURFACE := Color("#081522f7")
const BORDER := Color("#2d4b66b3")
const ACCENT := Color("#62d7ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")

var entries: Array[Dictionary] = []
var list: VBoxContainer
var status: Label


func _ready() -> void:
	hide()
	title = _t("ui.storage.loan_returns.title")
	min_size = WINDOW_SIZE
	max_size = WINDOW_SIZE
	size = WINDOW_SIZE
	unresizable = true
	borderless = true
	close_requested.connect(hide)
	_build_ui()


func open_inbox() -> void:
	popup_centered(WINDOW_SIZE)
	await refresh()


func refresh() -> void:
	status.text = _t("ui.lending.status.loading")
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		status.text = _t("ui.lending.error.unavailable")
		return
	var result: Dictionary = await service.load_return_inbox()
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", _t("ui.lending.error.load")))
		return
	entries.clear()
	var body: Dictionary = result.get("body", {})
	for value: Variant in body.get("returns", []):
		if value is Dictionary:
			entries.append((value as Dictionary).duplicate(true))
	status.text = _t("ui.storage.loan_returns.hint")
	count_changed.emit(entries.size())
	_render()


func _build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _style(BG, ACCENT, 12))
	add_child(background)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	background.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title_label := Label.new()
	title_label.text = _t("ui.storage.loan_returns.title")
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", TEXT)
	heading.add_child(title_label)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", MUTED)
	heading.add_child(status)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(38, 36)
	close.pressed.connect(hide)
	_apply_button_style(close)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)


func _render() -> void:
	_clear(list)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = _t("ui.storage.loan_returns.empty")
		empty.add_theme_color_override("font_color", MUTED)
		list.add_child(empty)
		return
	for entry: Dictionary in entries:
		list.add_child(_entry_row(entry))


func _entry_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 70
	panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 8))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var wrapper: Dictionary = entry.get("pokemon", {})
	var payload: Dictionary = wrapper.get("pokemon", {})
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.texture = PokemonAssets.load_party_icon(str(payload.get("speciesId", "")), bool(payload.get("shiny", false)))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	var name := Label.new()
	name.text = _pokemon_name(payload)
	name.add_theme_font_size_override("font_size", 14)
	name.add_theme_color_override("font_color", TEXT)
	identity.add_child(name)
	var detail := Label.new()
	detail.text = "%s · %s" % [_location_label(entry.get("location", {})), _returned_label(str(entry.get("returnedAt", "")))]
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", MUTED)
	identity.add_child(detail)
	var view := Button.new()
	view.text = _t("ui.lending.invitation.view")
	view.pressed.connect(func(): summary_requested.emit(payload))
	_apply_button_style(view)
	row.add_child(view)
	var locate := Button.new()
	locate.text = _t("ui.storage.loan_returns.locate")
	locate.pressed.connect(_locate.bind(entry))
	_apply_button_style(locate, true)
	row.add_child(locate)
	var dismiss := Button.new()
	dismiss.text = _t("ui.storage.loan_returns.dismiss")
	dismiss.pressed.connect(_dismiss.bind(entry))
	_apply_button_style(dismiss)
	row.add_child(dismiss)
	return panel


func _locate(entry: Dictionary) -> void:
	await _acknowledge(str(entry.get("assetId", "")))
	hide()
	locate_requested.emit(entry.duplicate(true))


func _dismiss(entry: Dictionary) -> void:
	if await _acknowledge(str(entry.get("assetId", ""))):
		await refresh()


func _acknowledge(asset_id: String) -> bool:
	var service := get_node_or_null("/root/LendingService")
	if service == null:
		return false
	var result: Dictionary = await service.acknowledge_return(asset_id)
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", _t("ui.lending.error.action")))
		return false
	return true


func _location_label(value: Variant) -> String:
	var location: Dictionary = value if value is Dictionary else {}
	if str(location.get("type", "")) == "party":
		return _t("ui.storage.loan_returns.location_party", {"slot": int(location.get("partySlot", 0)) + 1})
	return _t("ui.storage.loan_returns.location_box", {"box": int(location.get("boxIndex", 0)) + 1, "slot": int(location.get("slotIndex", 0)) + 1})


func _returned_label(value: String) -> String:
	if value == "":
		return ""
	return value.replace("T", " ").left(16)


func _pokemon_name(payload: Dictionary) -> String:
	var nickname := str(payload.get("nickname", "")).strip_edges()
	if nickname != "" and nickname != "<null>":
		return nickname
	var species_id := str(payload.get("speciesId", payload.get("species", "")))
	var localizer := get_node_or_null("/root/ContentLocalization")
	return str(localizer.call("display_name", "species", species_id, species_id.capitalize())) if localizer != null else species_id.capitalize()


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.set_corner_radius_all(radius)
	return style


func _apply_button_style(button: Button, primary := false) -> void:
	var normal := Color("#0c2030") if primary else Color("#091725")
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(normal, ACCENT if primary else BORDER, 7))
	button.add_theme_stylebox_override("hover", _style(Color("#123049"), ACCENT, 7))
	button.add_theme_stylebox_override("pressed", _style(Color("#07111d"), ACCENT, 7))
	button.add_theme_stylebox_override("focus", _style(Color("#123049"), ACCENT, 7))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _t(key: String, values := {}) -> String:
	var localization := get_node_or_null("/root/LocalizationManager")
	return str(localization.call("text", key, values)) if localization != null else key
