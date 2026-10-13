class_name NatureSpecialistPopup
extends PanelContainer

signal closed
var pokemon_select: OptionButton
var nature_select: OptionButton
var comparison: RichTextLabel
var status_label: Label
var preview_button: Button
var confirm_button: Button
var close_button: Button
var confirmation: AetherConfirmationDialog
var entries: Array = []
var quote: Dictionary = {}
var busy := false
var generation := 0
var cooldown := false

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.nature_specialist." + key, values)

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081522")
	style.border_color = Color("#397b9c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	add_child(layout)
	var title := Label.new()
	title.text = _t("title")
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	var explanation := Label.new()
	explanation.text = _t("explanation")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(explanation)
	pokemon_select = OptionButton.new()
	pokemon_select.item_selected.connect(_selection_changed)
	layout.add_child(pokemon_select)
	nature_select = OptionButton.new()
	nature_select.item_selected.connect(_selection_changed)
	layout.add_child(nature_select)
	comparison = RichTextLabel.new()
	comparison.bbcode_enabled = true
	comparison.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison.custom_minimum_size.y = 165
	layout.add_child(comparison)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)
	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	preview_button = Button.new()
	preview_button.text = _t("preview")
	preview_button.pressed.connect(_preview)
	buttons.add_child(preview_button)
	confirm_button = Button.new()
	confirm_button.text = _t("confirm")
	confirm_button.pressed.connect(_ask_confirm)
	buttons.add_child(confirm_button)
	close_button = Button.new()
	close_button.text = LocalizationManager.text("ui.common.close")
	close_button.pressed.connect(close_specialist)
	buttons.add_child(close_button)
	confirmation = preload("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate() as AetherConfirmationDialog
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)

func open_specialist() -> void:
	visible = true
	generation += 1
	quote.clear()
	await _load_state()

func close_specialist() -> void:
	if busy:
		return
	generation += 1
	confirmation.hide_dialog()
	visible = false
	closed.emit()

func _set_busy(value: bool) -> void:
	busy = value
	pokemon_select.disabled = value or not NatureSpecialistService.pending_request.is_empty()
	nature_select.disabled = value or not NatureSpecialistService.pending_request.is_empty()
	close_button.disabled = value
	preview_button.disabled = value or cooldown or entries.is_empty() or not NatureSpecialistService.pending_request.is_empty()
	confirm_button.disabled = value or (quote.is_empty() and NatureSpecialistService.pending_request.is_empty())
	confirm_button.text = _t("retry") if not NatureSpecialistService.pending_request.is_empty() else _t("confirm")

func _load_state() -> void:
	_set_busy(true)
	status_label.text = _t("loading")
	var current := generation
	var response: Dictionary = await NatureSpecialistService.state()
	if current != generation:
		return
	if not bool(response.get("success", false)):
		status_label.text = str(response.get("error", ""))
		_set_busy(false)
		return
	_apply_state(response.get("body", {}))

func _apply_state(data: Dictionary) -> void:
	entries = data.get("pokemon", [])
	pokemon_select.clear()
	for entry: Dictionary in entries:
		var p: Dictionary = entry.get("pokemon", {})
		var location: Dictionary = entry.get("location", {})
		var position_text := "PC %s/%s" % [int(location.get("boxIndex",0))+1,int(location.get("slotIndex",0))+1] if str(location.get("type","")) == "box" else "Party %s" % (int(location.get("partySlot",0))+1)
		var display_name := str(p.get("nickname")) if p.get("nickname") is String and not str(p.get("nickname")).is_empty() else str(p.get("species","Pokemon"))
		pokemon_select.add_item("%s #%s · Lv.%s%s · %s · %s ₽" % [display_name,p.get("ownedPokemonId",0),p.get("level",1)," ★" if bool(p.get("shiny",false)) else "",position_text,entry.get("price",0)])
	if entries.is_empty():
		pokemon_select.add_item(_t("no_pokemon"))
	nature_select.clear()
	for nature: Dictionary in data.get("natures", []):
		var name := str(nature.get("name", "Hardy"))
		var boosted := str(nature.get("boosted_stat")).to_upper() if nature.get("boosted_stat") != null else "—"
		var lowered := str(nature.get("lowered_stat")).to_upper() if nature.get("lowered_stat") != null else "—"
		var effect := "(+10%% %s / −10%% %s)" % [boosted, lowered] if nature.get("boosted_stat") != null else _t("neutral")
		nature_select.add_item("%s %s" % [ContentLocalization.nature_name(name.to_lower(),name), effect])
		nature_select.set_item_metadata(nature_select.item_count-1, name)
	var next_at := str(data.get("nextAvailableAt", "")) if data.get("nextAvailableAt") != null else ""
	cooldown = not next_at.is_empty() and next_at > str(data.get("serverTime", ""))
	status_label.text = _t("available", {"money":str(data.get("money",0))})
	if cooldown:
		status_label.text = _t("cooldown", {"time":next_at.replace("T", " ").replace("+00:00"," UTC")})
	_selection_changed(0)
	if not NatureSpecialistService.pending_request.is_empty():
		_show_quote(NatureSpecialistService.pending_display)
		status_label.text = _t("pending")
	_set_busy(false)

func _selection_changed(_index: int) -> void:
	quote.clear()
	comparison.text = ""
	if not entries.is_empty():
		var p: Dictionary = entries[pokemon_select.selected].get("pokemon", {})
		comparison.text = _t("current", {"original":str(p.get("nature","Hardy")), "effective":str(p.get("effectiveNature", p.get("nature","Hardy")))})
		var iv_text: Array[String] = []
		for stat: String in ["hp","atk","def","spa","spd","spe"]:
			iv_text.append("%s %s" % [stat.to_upper(),p.get("ivs",{}).get(stat,0)])
		comparison.text += "\nIVs: " + " · ".join(iv_text)
	_set_busy(busy)

func _preview() -> void:
	if busy or entries.is_empty():
		return
	_set_busy(true)
	var p: Dictionary = entries[pokemon_select.selected].get("pokemon", {})
	var pokemon_id := int(p.get("ownedPokemonId",p.get("pokemonId",0)))
	var response: Dictionary = await NatureSpecialistService.preview(pokemon_id, str(nature_select.get_item_metadata(nature_select.selected)))
	if bool(response.get("success",false)):
		_show_quote(response.get("body", {}))
	else:
		status_label.text = str(response.get("error",""))
	_set_busy(false)

func _show_quote(data: Dictionary) -> void:
	quote = data
	comparison.text = _t("current", {"original":str(quote.get("originalNature","")), "effective":str(quote.get("oldNature",""))}) + "\n" + _t("proposed", {"nature":str(quote.get("newNature","")), "price":str(quote.get("price",0))})
	for stat: String in ["hp","atk","def","spa","spd","spe"]:
		comparison.text += "\n%s: %s → %s" % [stat.to_upper(),quote.get("oldStats",{}).get(stat,0),quote.get("newStats",{}).get(stat,0)]
	status_label.text = _t("review")

func _ask_confirm() -> void:
	if busy:
		return
	if not NatureSpecialistService.pending_request.is_empty():
		await _confirm()
	elif not quote.is_empty():
		confirmation.configure(_t("title"), _t("confirmation", {"nature":str(quote.get("newNature","")), "price":str(quote.get("price",0))}), _t("confirm"), LocalizationManager.text("ui.common.cancel"))
		confirmation.popup_centered(Vector2i(600,280))

func _confirm() -> void:
	if busy:
		return
	_set_busy(true)
	var response: Dictionary = await NatureSpecialistService.confirm(str(quote.get("previewId","")), quote)
	if bool(response.get("success",false)):
		quote.clear()
		await _load_state()
		status_label.text = _t("success") + "\n" + status_label.text
	else:
		status_label.text = str(response.get("error",""))
	_set_busy(false)
