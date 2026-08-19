extends PanelContainer

class_name ChatModerationCenter

signal closed
signal moderation_requested(action: String, player: Dictionary)

const ACCENT := Color("#60d3ff")
const PURPLE := Color("#9a5cff")
const TEXT := Color("#edf3ff")
const MUTED_TEXT := Color("#98a5ba")
const SURFACE := Color("#08121eeF")
const RAISED := Color("#101b2aF5")
const BORDER := Color("#31506aaa")
const AUTO_REFRESH_SECONDS := 15.0

var active_tab := "online"
var overview: Dictionary = {"online": [], "muted": [], "recent": []}
var loaded_at_unix := 0.0
var refresh_in_flight := false
var countdown_elapsed := 0.0
var auto_refresh_elapsed := 0.0
var expiry_refresh_requested := false

var online_tab_button: Button
var muted_tab_button: Button
var recent_tab_button: Button
var search_input: LineEdit
var rows: VBoxContainer
var status_label: Label
var refresh_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(760, 570)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -380
	offset_top = -285
	offset_right = 380
	offset_bottom = 285
	add_theme_stylebox_override("panel", _panel_style(SURFACE, ACCENT, 14, 1))
	_build_ui()
	set_process(false)


func open_center() -> void:
	visible = true
	set_process(true)
	await refresh_overview()


func close_center() -> void:
	visible = false
	set_process(false)
	closed.emit()


func refresh_overview() -> void:
	if refresh_in_flight:
		return
	refresh_in_flight = true
	refresh_button.disabled = true
	status_label.text = LocalizationManager.text("ui.staff.chat.loading")
	var result: Dictionary = await ChatModerationService.get_moderation_overview()
	refresh_in_flight = false
	refresh_button.disabled = false
	if not bool(result.get("success", false)):
		status_label.text = str(result.get(
			"error",
			LocalizationManager.text("ui.staff.chat.load_failed")
		))
		return
	var body_value: Variant = result.get("body", {})
	overview = body_value if body_value is Dictionary else {"online": [], "muted": [], "recent": []}
	loaded_at_unix = Time.get_unix_time_from_system()
	auto_refresh_elapsed = 0.0
	expiry_refresh_requested = false
	status_label.text = LocalizationManager.text("ui.staff.chat.updated")
	_refresh_tabs()
	_render_active_tab()


func _process(delta: float) -> void:
	if not visible or refresh_in_flight:
		return
	auto_refresh_elapsed += delta
	if auto_refresh_elapsed >= AUTO_REFRESH_SECONDS:
		auto_refresh_elapsed = 0.0
		refresh_overview.call_deferred()
	countdown_elapsed += delta
	if countdown_elapsed < 1.0:
		return
	countdown_elapsed = 0.0
	if active_tab in ["online", "muted"] and not _array_from_value(overview.get("muted", [])).is_empty():
		_render_active_tab()
		if not expiry_refresh_requested and _has_expired_mute():
			expiry_refresh_requested = true
			refresh_overview.call_deferred()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	var title := Label.new()
	title.text = LocalizationManager.text("ui.staff.chat.title")
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", TEXT)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = LocalizationManager.text("ui.staff.chat.subtitle")
	subtitle.add_theme_color_override("font_color", MUTED_TEXT)
	heading.add_child(subtitle)
	refresh_button = Button.new()
	refresh_button.text = LocalizationManager.text("ui.staff.chat.refresh")
	refresh_button.pressed.connect(refresh_overview)
	_style_button(refresh_button, false)
	header.add_child(refresh_button)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = LocalizationManager.text("common.close")
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.pressed.connect(close_center)
	_style_button(close_button, false)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	online_tab_button = _create_tab_button("online")
	muted_tab_button = _create_tab_button("muted")
	recent_tab_button = _create_tab_button("recent")
	tabs.add_child(online_tab_button)
	tabs.add_child(muted_tab_button)
	tabs.add_child(recent_tab_button)

	search_input = LineEdit.new()
	search_input.placeholder_text = LocalizationManager.text("ui.staff.chat.search")
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(_on_search_changed)
	search_input.add_theme_stylebox_override("normal", _panel_style(Color("#07111ddd"), BORDER, 8, 1))
	search_input.add_theme_stylebox_override("focus", _panel_style(Color("#091625f5"), ACCENT, 8, 1))
	layout.add_child(search_input)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED_TEXT)
	status_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(status_label)


func _create_tab_button(tab_id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 38)
	button.pressed.connect(_select_tab.bind(tab_id))
	return button


func _select_tab(tab_id: String) -> void:
	active_tab = tab_id
	_refresh_tabs()
	_render_active_tab()


func _refresh_tabs() -> void:
	var online_count := _array_from_value(overview.get("online", [])).size()
	var muted_count := _array_from_value(overview.get("muted", [])).size()
	var recent_count := _array_from_value(overview.get("recent", [])).size()
	online_tab_button.text = LocalizationManager.text("ui.staff.chat.online", {"count": online_count})
	muted_tab_button.text = LocalizationManager.text("ui.staff.chat.muted", {"count": muted_count})
	recent_tab_button.text = LocalizationManager.text("ui.staff.chat.recent", {"count": recent_count})
	_style_button(online_tab_button, active_tab == "online")
	_style_button(muted_tab_button, active_tab == "muted")
	_style_button(recent_tab_button, active_tab == "recent")
	search_input.placeholder_text = LocalizationManager.text(
		"ui.staff.chat.search_actions" if active_tab == "recent" else "ui.staff.chat.search"
	)


func _on_search_changed(_value: String) -> void:
	_render_active_tab()


func _render_active_tab() -> void:
	_clear_rows()
	var entries := _array_from_value(overview.get(active_tab, []))
	var search := search_input.text.strip_edges().to_lower()
	var visible_count := 0
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		if search != "" and not _entry_matches_search(entry, search):
			continue
		rows.add_child(_create_recent_row(entry) if active_tab == "recent" else _create_player_row(entry))
		visible_count += 1
	if visible_count == 0:
		var empty := Label.new()
		empty.text = LocalizationManager.text("ui.staff.chat.empty_%s" % active_tab)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 180)
		empty.add_theme_color_override("font_color", MUTED_TEXT)
		rows.add_child(empty)


func _create_player_row(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(RAISED, BORDER, 9, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	var name_label := Label.new()
	var display_name := str(entry.get("displayName", entry.get("username", "Trainer")))
	var role_label := str(entry.get("roleLabel", "")).strip_edges()
	name_label.text = display_name if role_label == "" else "%s  ·  %s" % [display_name, role_label]
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.add_theme_font_size_override("font_size", 16)
	copy.add_child(name_label)
	var username := str(entry.get("username", ""))
	var map_id := str(entry.get("mapId", ""))
	var detail_parts: Array[String] = []
	if username != "":
		detail_parts.append("@" + username)
	if active_tab == "online" and map_id != "":
		detail_parts.append(_format_map_id(map_id))
	if bool(entry.get("muted", false)):
		detail_parts.append(LocalizationManager.text(
			"ui.staff.chat.remaining",
			{"time": _format_duration(_remaining_seconds(entry))}
		))
	var detail := Label.new()
	detail.text = "  ·  ".join(detail_parts)
	detail.add_theme_color_override("font_color", MUTED_TEXT)
	copy.add_child(detail)
	if active_tab == "muted":
		var reason := Label.new()
		reason.text = LocalizationManager.text("ui.staff.chat.mute_detail", {
			"moderator": str(entry.get("mutedByDisplayName", "System")),
			"reason": str(entry.get("reason", "")),
		})
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_color_override("font_color", MUTED_TEXT)
		copy.add_child(reason)
	if bool(entry.get("canModerate", false)):
		var action := "unmute" if bool(entry.get("muted", false)) else "mute"
		var action_button := Button.new()
		action_button.text = LocalizationManager.text("ui.chat.moderation.%s" % action)
		action_button.custom_minimum_size = Vector2(92, 36)
		action_button.pressed.connect(_request_moderation.bind(action, entry.duplicate(true)))
		_style_button(action_button, action == "unmute")
		row.add_child(action_button)
	return card


func _create_recent_row(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(RAISED, BORDER, 9, 1))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 11)
	card.add_child(margin)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	margin.add_child(copy)
	var action := str(entry.get("action", "updated"))
	var title := Label.new()
	title.text = LocalizationManager.text("ui.staff.chat.action_%s" % action, {
		"player": str(entry.get("targetDisplayName", "Trainer")),
	})
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 15)
	copy.add_child(title)
	var meta := Label.new()
	meta.text = LocalizationManager.text("ui.staff.chat.action_meta", {
		"moderator": str(entry.get("actorDisplayName", "System")),
		"time": _format_timestamp(str(entry.get("occurredAt", ""))),
	})
	meta.add_theme_color_override("font_color", MUTED_TEXT)
	copy.add_child(meta)
	var reason_text := str(entry.get("reason", "")).strip_edges()
	if reason_text != "":
		var reason := Label.new()
		reason.text = LocalizationManager.text("ui.staff.chat.reason", {"reason": reason_text})
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_color_override("font_color", MUTED_TEXT)
		copy.add_child(reason)
	return card


func _request_moderation(action: String, player: Dictionary) -> void:
	moderation_requested.emit(action, player)


func _entry_matches_search(entry: Dictionary, search: String) -> bool:
	var values := [
		entry.get("displayName", ""),
		entry.get("username", ""),
		entry.get("roleLabel", ""),
		entry.get("mapId", ""),
		entry.get("reason", ""),
		entry.get("targetDisplayName", ""),
		entry.get("actorDisplayName", ""),
		entry.get("action", ""),
	]
	for value: Variant in values:
		if search in str(value).to_lower():
			return true
	return false


func _remaining_seconds(entry: Dictionary) -> int:
	var initial := maxi(int(entry.get("remainingSeconds", 0)), 0)
	var elapsed := maxi(int(Time.get_unix_time_from_system() - loaded_at_unix), 0)
	return maxi(initial - elapsed, 0)


func _has_expired_mute() -> bool:
	for entry_value: Variant in _array_from_value(overview.get("muted", [])):
		if entry_value is Dictionary and _remaining_seconds(entry_value as Dictionary) <= 0:
			return true
	return false


func _format_duration(total_seconds: int) -> String:
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _format_map_id(map_id: String) -> String:
	var words := map_id.replace("_", " ").split(" ", false)
	var formatted: Array[String] = []
	for word: String in words:
		formatted.append(word.capitalize())
	return " ".join(formatted)


func _format_timestamp(value: String) -> String:
	var cleaned := value.replace("T", " ").replace("Z", "")
	var plus_index := cleaned.find("+")
	if plus_index >= 0:
		cleaned = cleaned.substr(0, plus_index)
	return cleaned.substr(0, mini(cleaned.length(), 16)) + " UTC"


func _array_from_value(value: Variant) -> Array:
	return value as Array if value is Array else []


func _clear_rows() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


func _style_button(button: Button, selected: bool) -> void:
	var border := PURPLE if selected else BORDER
	var background := Color("#2a1a4bea") if selected else Color("#0b1725e8")
	button.add_theme_stylebox_override("normal", _panel_style(background, border, 8, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#17283af4"), ACCENT, 8, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#241843f4"), PURPLE, 8, 1))
	button.add_theme_color_override("font_color", TEXT)


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style
