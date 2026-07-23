extends PanelContainer

class_name MapChatBubble

const BUBBLE_MIN_WIDTH := 68.0
const BUBBLE_MAX_WIDTH := 144.0
const BUBBLE_HORIZONTAL_PADDING := 14.0
const BUBBLE_BOTTOM_Y := -96.0
const MIN_VISIBLE_SECONDS := 4.0
const MAX_VISIBLE_SECONDS := 8.0
const SECONDS_PER_CHARACTER := 0.045

var message_label: Label
var hide_timer: Timer
var fade_tween: Tween
var show_revision := 0


func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BUBBLE_MIN_WIDTH, 0.0)
	visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f7f4e8f2")
	style.border_color = Color("#25364ce6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color("#00000055")
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	message_label = Label.new()
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 4
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.add_theme_color_override("font_color", Color("#152238"))
	message_label.add_theme_font_size_override("font_size", 10)
	margin.add_child(message_label)

	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_begin_fade)
	add_child(hide_timer)
	resized.connect(_reposition)


func show_message(text: String) -> void:
	var cleaned_text := text.strip_edges()
	if cleaned_text == "":
		return
	show_revision += 1
	var current_revision := show_revision
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = null
	hide_timer.stop()
	modulate.a = 0.0
	var target_width := _message_bubble_width(cleaned_text)
	custom_minimum_size.x = target_width
	size.x = target_width
	message_label.custom_minimum_size.x = maxf(
		target_width - BUBBLE_HORIZONTAL_PADDING,
		1.0
	)
	message_label.text = cleaned_text
	message_label.update_minimum_size()
	update_minimum_size()
	# Containers skip layout while hidden. Keep it in the layout pass but
	# transparent until its final wrapped height has been calculated.
	visible = true
	reset_size()
	var visible_seconds := clampf(
		MIN_VISIBLE_SECONDS + (cleaned_text.length() * SECONDS_PER_CHARACTER),
		MIN_VISIBLE_SECONDS,
		MAX_VISIBLE_SECONDS
	)
	_finish_show_after_layout.call_deferred(current_revision, visible_seconds)


func _finish_show_after_layout(revision: int, visible_seconds: float) -> void:
	await get_tree().process_frame
	if revision != show_revision:
		return
	reset_size()
	await get_tree().process_frame
	if revision != show_revision:
		return
	reset_size()
	_reposition()
	modulate.a = 1.0
	hide_timer.start(visible_seconds)


func _message_bubble_width(text: String) -> float:
	var font := message_label.get_theme_font("font")
	var font_size := message_label.get_theme_font_size("font_size")
	var text_width := float(text.length() * 6)
	if font != null:
		text_width = font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
	return clampf(
		ceilf(text_width + BUBBLE_HORIZONTAL_PADDING),
		BUBBLE_MIN_WIDTH,
		BUBBLE_MAX_WIDTH
	)


func _reposition() -> void:
	position = Vector2(-size.x * 0.5, BUBBLE_BOTTOM_Y - size.y)


func _begin_fade() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	var active_tween := fade_tween
	active_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	active_tween.finished.connect(_on_fade_finished.bind(active_tween))


func _on_fade_finished(completed_tween: Tween) -> void:
	if completed_tween != fade_tween:
		return
	visible = false
	fade_tween = null
