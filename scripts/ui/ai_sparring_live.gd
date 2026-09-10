extends VBoxContainer

signal watch_requested(response: Dictionary)

var watch_blocked: Callable
var search: LineEdit
var tier: OptionButton
var difficulty: OptionButton
var status: Label
var rows: VBoxContainer
var entries: Array = []
var busy := false
var watching := false
var intro: Label
var refresh: Button

const SURFACE := Color("#101a2b")
const SURFACE_ELEVATED := Color("#16233a")
const BORDER := Color("#345575")
const ACCENT := Color("#7159bd")
const ACCENT_BRIGHT := Color("#cfc2ff")
const MUTED := Color("#aabbd1")

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.pvp.ai_sparring.live." + key, values)

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var intro_card := PanelContainer.new()
	intro_card.add_theme_stylebox_override("panel", _surface_style(Color("#111d30"), Color("#516b94"), 9, 1, 12))
	add_child(intro_card)
	var intro_margin := MarginContainer.new()
	intro_margin.add_theme_constant_override("margin_left", 14)
	intro_margin.add_theme_constant_override("margin_top", 11)
	intro_margin.add_theme_constant_override("margin_right", 14)
	intro_margin.add_theme_constant_override("margin_bottom", 11)
	intro_card.add_child(intro_margin)
	intro = Label.new()
	intro.text = _t("intro")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color("#dce8fa"))
	intro.add_theme_font_size_override("font_size", 13)
	intro_margin.add_child(intro)
	var browse_card := PanelContainer.new()
	browse_card.name = "LiveBattlesBrowser"
	browse_card.add_theme_stylebox_override("panel", _surface_style(SURFACE, BORDER, 9, 1, 10))
	add_child(browse_card)
	var browse_margin := MarginContainer.new()
	browse_margin.add_theme_constant_override("margin_left", 12)
	browse_margin.add_theme_constant_override("margin_top", 12)
	browse_margin.add_theme_constant_override("margin_right", 12)
	browse_margin.add_theme_constant_override("margin_bottom", 12)
	browse_card.add_child(browse_margin)
	var browse := VBoxContainer.new()
	browse.add_theme_constant_override("separation", 8)
	browse_margin.add_child(browse)
	search = LineEdit.new()
	search.name = "LivePlayerSearch"
	search.placeholder_text = _t("search")
	search.max_length = 32
	search.custom_minimum_size = Vector2(0, 40)
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", 14)
	search.add_theme_color_override("font_placeholder_color", Color("#90a1b7"))
	search.add_theme_stylebox_override("normal", _surface_style(Color("#091627"), Color("#365d80"), 7, 1, 10))
	search.add_theme_stylebox_override("focus", _surface_style(Color("#0b1b30"), ACCENT_BRIGHT, 7, 2, 10))
	search.text_changed.connect(func(_value: String): render())
	browse.add_child(search)
	var filters := HBoxContainer.new()
	filters.name = "LiveBattleFilters"
	filters.add_theme_constant_override("separation", 8)
	browse.add_child(filters)
	tier = OptionButton.new()
	difficulty = OptionButton.new()
	for select: OptionButton in [tier, difficulty]:
		select.custom_minimum_size = Vector2(0, 38)
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.fit_to_longest_item = false
		select.add_theme_font_size_override("font_size", 13)
		select.add_theme_color_override("font_color", Color("#e7efff"))
		select.add_theme_stylebox_override("normal", _surface_style(Color("#0b1727"), Color("#365d80"), 7, 1, 10))
		select.add_theme_stylebox_override("hover", _surface_style(Color("#12233a"), Color("#839cc5"), 7, 1, 10))
		select.add_theme_stylebox_override("pressed", _surface_style(Color("#171535"), ACCENT_BRIGHT, 7, 1, 10))
		select.item_selected.connect(func(_index: int): render())
		filters.add_child(select)
	for entry: Array in [["", _t("all_tiers")], ["none", "Open"], ["aether-ou", "Aether OU"], ["aether-uu", "Aether UU"]]:
		tier.add_item(entry[1])
		tier.set_item_metadata(tier.item_count - 1, entry[0])
	for entry: Array in [["", _t("all_levels")], ["ai4", "Scholar"], ["intermediate", "Grandmaster Intermediate"], ["active", "Grandmaster Hard"], ["elite", "Grandmaster Elite"], ["nightmare", "Grandmaster Nightmare"]]:
		difficulty.add_item(entry[1])
		difficulty.set_item_metadata(difficulty.item_count - 1, entry[0])
	refresh = Button.new()
	refresh.text = _t("refresh")
	refresh.custom_minimum_size = Vector2(104, 38)
	_style_secondary_button(refresh)
	refresh.pressed.connect(load_battles)
	filters.add_child(refresh)
	status = Label.new()
	status.name = "LiveBattleResultCount"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("#dce8fa"))
	add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 310
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(load_battles)
	add_child(timer)
	visibility_changed.connect(load_battles)
	LocalizationManager.locale_changed.connect(_locale_changed)
	load_battles()

func _locale_changed(_locale: String) -> void:
	intro.text = _t("intro")
	search.placeholder_text = _t("search")
	tier.set_item_text(0, _t("all_tiers"))
	difficulty.set_item_text(0, _t("all_levels"))
	refresh.text = _t("refresh")
	render()

func load_battles() -> void:
	if not is_node_ready() or not is_visible_in_tree() or busy or watching:
		return
	busy = true
	var request := HTTPRequest.new()
	add_child(request)
	var response: Dictionary = await BattleApiClient.send_get_request(request, "/battle/pvp/training/ai/live")
	request.queue_free()
	busy = false
	if not bool(response.get("success", false)):
		entries = []
		render()
		status.text = _t("unavailable")
		return
	entries = response.get("battles", []) if response.get("battles") is Array else []
	render()

func filtered_entries() -> Array:
	var filtered: Array = []
	for value: Variant in entries:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var query := search.text.strip_edges().to_lower()
		if not query.is_empty() and not query in str(row.get("playerName", "")).to_lower():
			continue
		if tier.selected > 0 and row.get("tierId") != tier.get_selected_metadata():
			continue
		if difficulty.selected > 0 and row.get("difficulty") != difficulty.get_selected_metadata():
			continue
		filtered.append(row)
	return filtered

func render() -> void:
	if rows == null:
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var shown := filtered_entries()
	status.text = _t("empty") if shown.is_empty() else _t("count", {"count": shown.size()})
	for entry: Dictionary in shown:
		var panel := PanelContainer.new()
		panel.name = "LiveBattleCard"
		panel.add_theme_stylebox_override("panel", _surface_style(SURFACE_ELEVATED, Color("#294d72"), 9, 1, 12))
		rows.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var heading := Label.new()
		heading.text = "%s  ·  %s" % [entry.get("playerName", ""), entry.get("opponentName", "")]
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_size_override("font_size", 16)
		heading.add_theme_color_override("font_color", Color("#f4f6ff"))
		copy.add_child(heading)
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var started := Time.get_unix_time_from_datetime_string(str(entry.get("startedAt", "")).left(19))
		var minutes := maxi(0, int((Time.get_unix_time_from_system() - started) / 60))
		detail.text = _t("details", {"tier": entry.get("tierName", "Open"), "turn": entry.get("turn", 0), "minutes": minutes, "count": entry.get("spectators", 0), "max": entry.get("maxSpectators", 8)})
		detail.add_theme_font_size_override("font_size", 12)
		detail.add_theme_color_override("font_color", MUTED)
		copy.add_child(detail)
		var button := Button.new()
		button.text = _t("watch")
		button.custom_minimum_size = Vector2(118, 42)
		_style_watch_button(button)
		button.disabled = watching or (watch_blocked.is_valid() and watch_blocked.call()) or int(entry.get("spectators", 0)) >= int(entry.get("maxSpectators", 8))
		button.pressed.connect(watch.bind(str(entry.get("battleId", ""))))
		row.add_child(button)

func watch(battle_id: String) -> void:
	if watching or (watch_blocked.is_valid() and watch_blocked.call()):
		return
	watching = true
	render()
	var request := HTTPRequest.new()
	add_child(request)
	var response: Dictionary = await BattleApiClient.send_get_request(request, "/battle/pvp/training/ai/live/%s/spectate" % battle_id.uri_encode())
	request.queue_free()
	watching = false
	if not is_visible_in_tree():
		return
	render()
	if watch_blocked.is_valid() and watch_blocked.call():
		return
	if bool(response.get("success", false)) and response.get("viewerRole") == "spectator":
		watch_requested.emit(response)
	else:
		status.text = _t("watch_failed")

func _surface_style(fill: Color, border: Color, radius: int, width: int, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	if padding > 0:
		style.content_margin_left = padding
		style.content_margin_right = padding
		style.content_margin_top = padding
		style.content_margin_bottom = padding
	return style

func _style_secondary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("#e4edff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _surface_style(Color("#17263b"), Color("#496b91"), 7, 1, 10))
	button.add_theme_stylebox_override("hover", _surface_style(Color("#243b58"), Color("#93b3df"), 7, 1, 10))
	button.add_theme_stylebox_override("pressed", _surface_style(Color("#0f1c2d"), Color("#c8dcff"), 7, 1, 10))
	button.add_theme_stylebox_override("focus", _surface_style(Color("#17263b"), ACCENT_BRIGHT, 7, 2, 10))

func _style_watch_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#8995a6"))
	button.add_theme_stylebox_override("normal", _surface_style(ACCENT, Color("#d6ccff"), 8, 2, 12))
	button.add_theme_stylebox_override("hover", _surface_style(Color("#8068cc"), Color("#f1edff"), 8, 2, 12))
	button.add_theme_stylebox_override("pressed", _surface_style(Color("#51418c"), Color("#bdaeff"), 8, 2, 12))
	button.add_theme_stylebox_override("disabled", _surface_style(Color("#202c3d"), Color("#354557"), 8, 1, 12))
	button.add_theme_stylebox_override("focus", _surface_style(ACCENT, Color("#fff0a8"), 8, 2, 12))
