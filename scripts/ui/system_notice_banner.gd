extends Control

class_name SystemNoticeBanner

const PANEL_HEIGHT := 86.0
const PANEL_MAX_WIDTH := 680.0
const DEFAULT_TOP_OFFSET := 16.0
const NOTICE_BORDER := Color("#d8b767")
const NOTICE_TEXT := Color("#f0d992")
const BODY_TEXT := Color("#f5f0df")

var notice_queue: Array[Dictionary] = []
var seen_announcement_ids: Dictionary = {}
var active_notice: Dictionary = {}
var active_expires_at_unix := 0.0
var top_offset := DEFAULT_TOP_OFFSET
var panel: PanelContainer
var title_label: Label
var message_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2030
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_banner()
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	_position_panel()
	if not active_notice.is_empty() and Time.get_unix_time_from_system() >= active_expires_at_unix:
		_finish_current_notice()


func enqueue_notice(event: Dictionary) -> bool:
	var announcement_id := str(event.get("announcementId", "")).strip_edges()
	var message := str(event.get("message", "")).strip_edges()
	var expires_at_unix := _iso_timestamp_to_unix(str(event.get("expiresAt", "")))
	if announcement_id == "" or message.length() < 3 or expires_at_unix <= Time.get_unix_time_from_system():
		return false
	if seen_announcement_ids.has(announcement_id):
		return false
	seen_announcement_ids[announcement_id] = true
	notice_queue.append({
		"announcementId": announcement_id,
		"message": message.left(255),
		"expiresAtUnix": expires_at_unix,
	})
	if active_notice.is_empty():
		_show_next_notice()
	return true


func set_top_offset(value: float) -> void:
	top_offset = maxf(DEFAULT_TOP_OFFSET, value)
	_position_panel()


func refresh_localized_ui() -> void:
	if title_label != null:
		title_label.text = LocalizationManager.text("ui.system_announcement.title")


func _build_banner() -> void:
	panel = PanelContainer.new()
	panel.name = "AnnouncementPanel"
	panel.custom_minimum_size = Vector2(PANEL_MAX_WIDTH, PANEL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _banner_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _badge_style())
	row.add_child(badge)

	var badge_label := Label.new()
	badge_label.text = "!"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 28)
	badge_label.add_theme_color_override("font_color", NOTICE_TEXT)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_stack)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", NOTICE_TEXT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(title_label)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.add_theme_font_size_override("font_size", 14)
	message_label.add_theme_color_override("font_color", BODY_TEXT)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(message_label)
	refresh_localized_ui()


func _show_next_notice() -> void:
	var now := Time.get_unix_time_from_system()
	while not notice_queue.is_empty():
		var notice: Dictionary = notice_queue.pop_front()
		var expires_at_unix := float(notice.get("expiresAtUnix", 0.0))
		if expires_at_unix <= now:
			continue
		active_notice = notice
		active_expires_at_unix = expires_at_unix
		message_label.text = str(notice.get("message", ""))
		visible = true
		move_to_front()
		_position_panel()
		set_process(true)
		return
	active_notice.clear()
	active_expires_at_unix = 0.0
	visible = false
	set_process(false)


func _finish_current_notice() -> void:
	active_notice.clear()
	active_expires_at_unix = 0.0
	_show_next_notice()


func _position_panel() -> void:
	if panel == null or not visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(
		minf(PANEL_MAX_WIDTH, maxf(300.0, viewport_size.x - 24.0)),
		PANEL_HEIGHT
	)
	panel.custom_minimum_size = panel_size
	panel.position = Vector2((viewport_size.x - panel_size.x) * 0.5, top_offset)
	panel.size = panel_size


func _banner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#171306f7")
	style.border_color = NOTICE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.52)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	return style


func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#302806f5")
	style.border_color = NOTICE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _iso_timestamp_to_unix(value: String) -> float:
	var normalized := value.strip_edges().replace("Z", "")
	var timezone_index := normalized.find("+", 10)
	if timezone_index >= 0:
		normalized = normalized.left(timezone_index)
	var dot_index := normalized.find(".")
	if dot_index >= 0:
		normalized = normalized.left(dot_index)
	if normalized == "":
		return 0.0
	return float(Time.get_unix_time_from_datetime_string(normalized))
