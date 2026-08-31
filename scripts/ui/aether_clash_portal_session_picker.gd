extends VBoxContainer

signal selection_changed(index: int)

const COLOR_SURFACE := Color("0b1928fa")
const COLOR_BORDER := Color("315d78")
const COLOR_ACCENT := Color("69d8e7")
const COLOR_WARNING := Color("e3bd68")
const COLOR_TEXT := Color("eef8ff")
const COLOR_MUTED := Color("9eb3c5")

var _sessions: Array[Dictionary] = []
var _last_clock_second := -1
var _choices: OptionButton
var _matchup_label: Label
var _status_label: Label
var _access_label: Label


func _init() -> void:
	name = "AetherClashPortalSessionPicker"
	add_theme_constant_override("separation", 8)
	_build_interface()
	set_process(true)


func configure(sessions: Array[Dictionary]) -> void:
	_sessions.clear()
	_choices.clear()
	for item: Dictionary in sessions:
		var normalized := item.duplicate(true)
		_sessions.append(normalized)
		_choices.add_item(_option_text(normalized))
	var has_sessions := not _sessions.is_empty()
	_choices.disabled = not has_sessions
	if has_sessions:
		_choices.select(0)
	_last_clock_second = -1
	_refresh_details(Time.get_unix_time_from_system())


func option_button() -> OptionButton:
	return _choices


func selected_session() -> Dictionary:
	var selected_index := _choices.selected
	if selected_index < 0 or selected_index >= _sessions.size():
		return {}
	return _sessions[selected_index].duplicate(true)


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _sessions.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	var clock_second := int(floor(now))
	if clock_second == _last_clock_second:
		return
	_last_clock_second = clock_second
	_refresh_details(now)


func _build_interface() -> void:
	_choices = OptionButton.new()
	_choices.name = "AetherClashPortalSessionSelect"
	_choices.custom_minimum_size = Vector2(0, 42)
	_choices.item_selected.connect(_on_session_selected)
	add_child(_choices)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "AetherClashPortalSessionDetails"
	detail_panel.custom_minimum_size = Vector2(0, 104)
	detail_panel.add_theme_stylebox_override("panel", _detail_style())
	add_child(detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 11)
	detail_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)

	_matchup_label = Label.new()
	_matchup_label.name = "Matchup"
	_matchup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_matchup_label.add_theme_font_size_override("font_size", 16)
	_matchup_label.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(_matchup_label)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	content.add_child(_status_label)

	_access_label = Label.new()
	_access_label.name = "Access"
	_access_label.add_theme_font_size_override("font_size", 12)
	_access_label.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(_access_label)


func _on_session_selected(index: int) -> void:
	_last_clock_second = -1
	_refresh_details(Time.get_unix_time_from_system())
	selection_changed.emit(index)


func _refresh_details(now: float) -> void:
	var item := selected_session()
	if item.is_empty():
		_matchup_label.text = ""
		_status_label.text = ""
		_access_label.text = ""
		return
	var session := _dictionary(item.get("session", {}))
	var challenger := _dictionary(session.get("challengerGuild", {}))
	var challenged := _dictionary(session.get("challengedGuild", {}))
	var status := str(session.get("status", "entry_open"))
	var counts := _display_counts(session)
	var challenger_name := str(challenger.get("name", "Guild"))
	var challenged_name := str(challenged.get("name", "Guild"))
	var challenger_count := maxi(0, int(counts.get("challenger", 0)))
	var challenged_count := maxi(0, int(counts.get("challenged", 0)))
	var count_label_key := (
		"world.aether_clash.portal.players.entry_open"
		if status == "entry_open"
		else "world.aether_clash.portal.players.active"
	)
	_matchup_label.text = _text(
		"world.aether_clash.portal.summary.players",
		{
			"label": _text(count_label_key),
			"challenger": challenger_name,
			"challenger_count": challenger_count,
			"challenged_count": challenged_count,
			"challenged": challenged_name,
		}
	)
	var duration := _status_duration(session, status, now)
	_status_label.text = _text(
		"world.aether_clash.portal.timer.%s" % status,
		{"time": _format_duration(duration)}
	)
	_status_label.add_theme_color_override(
		"font_color",
		COLOR_WARNING if status == "entry_open" else COLOR_ACCENT
	)
	var role := str(item.get("role", "spectator"))
	_access_label.text = _text(
		"world.aether_clash.portal.summary.access",
		{
			"role": _text("world.aether_clash.portal.role.%s" % role),
			"tier": str(session.get("tierName", "Aether OU")),
		}
	)


func _option_text(item: Dictionary) -> String:
	var session := _dictionary(item.get("session", {}))
	var challenger := _dictionary(session.get("challengerGuild", {}))
	var challenged := _dictionary(session.get("challengedGuild", {}))
	var counts := _display_counts(session)
	var status := str(session.get("status", "entry_open"))
	return _text(
		"world.aether_clash.portal.option",
		{
			"challenger": str(challenger.get("name", "Guild")),
			"challenger_count": maxi(0, int(counts.get("challenger", 0))),
			"challenged_count": maxi(0, int(counts.get("challenged", 0))),
			"challenged": str(challenged.get("name", "Guild")),
			"status": _text("world.aether_clash.portal.status.%s" % status),
		}
	)


func _display_counts(session: Dictionary) -> Dictionary:
	return _dictionary(
		session.get(
			"entryCounts" if str(session.get("status", "")) == "entry_open" else "activeCounts",
			{}
		)
	)


func _status_duration(session: Dictionary, status: String, now: float) -> int:
	if status == "entry_open":
		var closes_at := _timestamp_to_unix(str(session.get("entryClosesAt", "")))
		return maxi(0, int(ceil(closes_at - now))) if closes_at > 0.0 else 0
	var started_at := _timestamp_to_unix(str(session.get("startedAt", "")))
	return maxi(0, int(floor(now - started_at))) if started_at > 0.0 else 0


func _format_duration(total_seconds: int) -> String:
	var hours := int(total_seconds / 3600)
	var minutes := int(total_seconds / 60) % 60
	var seconds := total_seconds % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _timestamp_to_unix(value: String) -> float:
	var normalized := value.strip_edges().replace("+00:00", "Z")
	if normalized.is_empty():
		return 0.0
	return Time.get_unix_time_from_datetime_string(normalized)


func _detail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _text(key: String, values: Dictionary = {}) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key, values))
	return key.format(values)
