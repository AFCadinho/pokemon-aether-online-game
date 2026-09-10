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

func _t(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.pvp.ai_sparring.live." + key, values)

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	intro = Label.new()
	intro.text = _t("intro")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	search = LineEdit.new()
	search.name = "LivePlayerSearch"
	search.placeholder_text = _t("search")
	search.max_length = 32
	search.text_changed.connect(func(_value: String): render())
	add_child(search)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	add_child(filters)
	tier = OptionButton.new()
	difficulty = OptionButton.new()
	for select: OptionButton in [tier, difficulty]:
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.fit_to_longest_item = false
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
	refresh.pressed.connect(load_battles)
	filters.add_child(refresh)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#172238")
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		rows.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		var heading := Label.new()
		heading.text = "%s  ·  %s" % [entry.get("playerName", ""), entry.get("opponentName", "")]
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(heading)
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var started := Time.get_unix_time_from_datetime_string(str(entry.get("startedAt", "")).left(19))
		var minutes := maxi(0, int((Time.get_unix_time_from_system() - started) / 60))
		detail.text = _t("details", {"tier": entry.get("tierName", "Open"), "turn": entry.get("turn", 0), "minutes": minutes, "count": entry.get("spectators", 0), "max": entry.get("maxSpectators", 8)})
		detail.add_theme_font_size_override("font_size", 12)
		detail.add_theme_color_override("font_color", Color("#adbed7"))
		copy.add_child(detail)
		var button := Button.new()
		button.text = _t("watch")
		button.custom_minimum_size = Vector2(108, 40)
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
