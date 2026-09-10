extends PanelContainer

signal close_requested

var host: Node
var timeline := preload("res://scripts/battle/battle_replay_timeline.gd").new()
var index := 0
var playing := false
var busy := false
var pending_seek := -1
var play_button: Button
var turn_picker: SpinBox
var position_label: Label
var scrubber: HSlider
var status_label: Label
var status_strip: PanelContainer
var speed := 1.0
var closing := false

const INK := Color("#edf7ff")
const MUTED := Color("#91a8be")
const ACCENT := Color("#55d5ff")
const SURFACE := Color("#102239")
const SURFACE_RAISED := Color("#17314d")

func _t(key: String, args: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.replays." + key, args)

func setup(battle: Node, recording: Dictionary) -> bool:
	host = battle
	if not timeline.load_recording(recording):
		return false
	_build()
	host.call("restore_replay_position", timeline, 0)
	_refresh()
	return true

func _style(color: Color, border: Color, radius: int, width := 0, left := 9, right := 9, top := 7, bottom := 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	return box

func _button(parent: Node, text: String, action: Callable, variant := "secondary") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	var base := SURFACE_RAISED
	var hover := Color("#234968")
	var border := Color("#365b79")
	if variant == "primary":
		base = Color("#126b91")
		hover = Color("#198abd")
		border = ACCENT
	elif variant == "quiet":
		base = Color("#13243a")
		hover = Color("#1a3853")
		border = Color("#315574")
		button.add_theme_color_override("font_color", MUTED)
	else:
		button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _style(base, border, 7, 1))
	button.add_theme_stylebox_override("hover", _style(hover, border.lightened(0.2), 7, 1))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.18), border, 7, 1))
	button.add_theme_stylebox_override("disabled", _style(Color("#0c1725"), Color("#243a50"), 7, 1))
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#52677e"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _group() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#0b1726"), Color("#254966"), 8, 1, 7, 7, 6, 6))
	return panel

func _tiny_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _dropdown_arrow_icon() -> ImageTexture:
	var image := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#00000000"))
	for offset in range(4):
		image.set_pixel(2 + offset, 2 + offset, ACCENT)
		image.set_pixel(9 - offset, 2 + offset, ACCENT)
	return ImageTexture.create_from_image(image)

func _scrubber_handle_icon(highlighted := false) -> ImageTexture:
	var size := 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color("#00000000"))
	var fill := Color("#dff8ff") if highlighted else ACCENT
	for y in range(size):
		for x in range(size):
			if Vector2(x - 7.5, y - 7.5).length() <= 5.5:
				image.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(image)

func _build() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -492
	offset_top = -212
	offset_right = -20
	offset_bottom = -48
	z_index = 100
	add_theme_stylebox_override("panel", _style(Color("#0b192b"), Color("#315c80"), 10, 1, 12, 12, 6, 6))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	var live_dot := ColorRect.new()
	live_dot.color = ACCENT
	live_dot.custom_minimum_size = Vector2(3, 22)
	header.add_child(live_dot)
	var title := Label.new()
	title.text = _t("playback_title")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	position_label = Label.new()
	position_label.add_theme_font_size_override("font_size", 13)
	position_label.add_theme_color_override("font_color", INK)
	position_label.add_theme_stylebox_override("normal", _style(Color("#122e47"), Color("#315c80"), 6, 1, 8, 8, 4, 4))
	header.add_child(position_label)
	position_label.custom_minimum_size.y = 28
	var control_hint := _tiny_label("PLAYBACK CONTROLS")
	control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(control_hint)
	var transport := _group()
	transport.custom_minimum_size.y = 44
	layout.add_child(transport)
	var transport_center := CenterContainer.new()
	transport.add_child(transport_center)
	var transport_buttons := HBoxContainer.new()
	transport_buttons.add_theme_constant_override("separation", 7)
	transport_center.add_child(transport_buttons)
	for button: Button in [
		_button(transport_buttons, "|◀", func(): seek(0), "quiet"),
		_button(transport_buttons, "◀", func(): seek(timeline.index_for_turn(maxi(0, timeline.turn_at(index) - 1))), "quiet"),
		_button(transport_buttons, "▶  " + _t("play"), _toggle, "primary"),
		_button(transport_buttons, "▶", func():
			var turn := timeline.turn_at(index) + 1
			seek(timeline.index_for_turn(turn) if timeline.turn_indices.has(turn) else timeline.frames.size() - 1), "quiet"),
		_button(transport_buttons, "▶|", func(): seek(timeline.frames.size() - 1), "quiet")
	]:
		button.custom_minimum_size.y = 34
	transport_buttons.get_child(0).tooltip_text = _t("begin")
	transport_buttons.get_child(1).tooltip_text = _t("previous_turn")
	play_button = transport_buttons.get_child(2) as Button
	transport_buttons.get_child(3).tooltip_text = _t("next_turn")
	transport_buttons.get_child(4).tooltip_text = _t("end")
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	layout.add_child(progress_row)
	var progress_caption := _tiny_label("REPLAY PROGRESS")
	progress_caption.custom_minimum_size.x = 104
	progress_row.add_child(progress_caption)
	scrubber = HSlider.new()
	scrubber.min_value = 0
	scrubber.max_value = timeline.frames.size() - 1
	scrubber.step = 1
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.custom_minimum_size.y = 16
	scrubber.focus_mode = Control.FOCUS_NONE
	scrubber.tooltip_text = _t("go_turn")
	scrubber.add_theme_stylebox_override("slider", _style(Color("#071321"), Color("#315574"), 4, 1, 0, 0, 3, 3))
	scrubber.add_theme_icon_override("grabber", _scrubber_handle_icon())
	scrubber.add_theme_icon_override("grabber_highlight", _scrubber_handle_icon(true))
	scrubber.drag_ended.connect(func(value_changed: bool):
		if value_changed:
			seek(roundi(scrubber.value)))
	progress_row.add_child(scrubber)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	layout.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var turn_group := _group()
	row.add_child(turn_group)
	var turn_layout := HBoxContainer.new()
	turn_layout.add_theme_constant_override("separation", 6)
	turn_group.add_child(turn_layout)
	turn_layout.add_child(_tiny_label("TURN"))
	turn_picker = SpinBox.new()
	turn_picker.min_value = 0
	turn_picker.max_value = timeline.turn_at(timeline.frames.size() - 1)
	turn_picker.custom_minimum_size = Vector2(58, 32)
	turn_picker.focus_mode = Control.FOCUS_NONE
	turn_picker.add_theme_icon_override("updown", _dropdown_arrow_icon())
	var turn_input := turn_picker.get_line_edit()
	turn_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_input.add_theme_font_size_override("font_size", 14)
	turn_input.add_theme_color_override("font_color", INK)
	turn_input.add_theme_stylebox_override("normal", _style(Color("#071321"), Color("#315574"), 5, 1, 7, 7, 5, 5))
	turn_input.add_theme_stylebox_override("focus", _style(Color("#0b1e30"), ACCENT, 5, 1, 7, 7, 5, 5))
	turn_layout.add_child(turn_picker)
	_button(turn_layout, _t("go_turn"), func(): seek(timeline.index_for_turn(int(turn_picker.value))), "quiet")
	var speed_group := _group()
	row.add_child(speed_group)
	var speed_layout := HBoxContainer.new()
	speed_layout.add_theme_constant_override("separation", 6)
	speed_group.add_child(speed_layout)
	speed_layout.add_child(_tiny_label("SPEED"))
	var speeds := OptionButton.new()
	for value: float in [0.5, 1.0, 2.0, 4.0]:
		speeds.add_item("%s×" % value)
	speeds.select(1)
	speeds.custom_minimum_size = Vector2(68, 32)
	speeds.focus_mode = Control.FOCUS_NONE
	speeds.add_theme_icon_override("arrow", _dropdown_arrow_icon())
	speeds.add_theme_constant_override("arrow_margin", 9)
	speeds.add_theme_font_size_override("font_size", 14)
	speeds.add_theme_color_override("font_color", INK)
	speeds.add_theme_stylebox_override("normal", _style(Color("#071321"), Color("#315574"), 5, 1, 8, 8, 5, 5))
	speeds.add_theme_stylebox_override("hover", _style(Color("#0d2840"), ACCENT, 5, 1, 8, 8, 5, 5))
	var speed_popup := speeds.get_popup()
	speed_popup.transparent_bg = true
	speed_popup.add_theme_font_size_override("font_size", 14)
	speed_popup.add_theme_color_override("font_color", INK)
	speed_popup.add_theme_color_override("font_hover_color", INK)
	speed_popup.add_theme_stylebox_override("panel", _style(Color("#0b1726"), Color("#315574"), 7, 1, 7, 7, 6, 6))
	speed_popup.add_theme_stylebox_override("hover", _style(Color("#1a4160"), ACCENT, 5, 1, 8, 8, 5, 5))
	speeds.item_selected.connect(func(selected: int):
		speed = [0.5, 1.0, 2.0, 4.0][selected]
		host.call("set_replay_speed", speed))
	speed_layout.add_child(speeds)
	_build_status_strip()

func _build_status_strip() -> void:
	var dock: Control = host.get("action_side_panel") as Control
	if dock == null:
		return
	dock.custom_minimum_size.y = 68
	status_strip = PanelContainer.new()
	status_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_strip.offset_left = 12
	status_strip.offset_top = 8
	status_strip.offset_right = -12
	status_strip.offset_bottom = -8
	status_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	status_strip.add_theme_stylebox_override("panel", _style(Color("#0b192b"), Color("#315c80"), 9, 1, 12, 12, 7, 7))
	dock.add_child(status_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	status_strip.add_child(row)
	var label := _tiny_label("REPLAY STATUS")
	label.custom_minimum_size.x = 94
	row.add_child(label)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", INK)
	row.add_child(status_label)
	var back_button := _button(row, _t("back"), _close, "quiet")
	back_button.custom_minimum_size = Vector2(66, 34)

func _toggle() -> void:
	if closing:
		return
	playing = not playing
	if playing and index >= timeline.frames.size() - 1:
		index = 0
		host.call("restore_replay_position", timeline, index)
	host.set("replay_paused", not playing)
	_refresh()
	if playing and not busy:
		_run()

func seek(target: int) -> void:
	if closing:
		return
	playing = false
	host.set("replay_paused", false)
	pending_seek = clampi(target, 0, timeline.frames.size() - 1)
	if busy:
		host.call("cancel_replay_render")
	else:
		_apply_seek()
	_refresh()

func _apply_seek() -> void:
	index = pending_seek
	pending_seek = -1
	host.call("restore_replay_position", timeline, index)
	host.set("replay_paused", true)

func _run() -> void:
	busy = true
	while playing and index + 1 < timeline.frames.size():
		await host.call("play_replay_frame", timeline, index + 1)
		if closing or pending_seek >= 0:
			break
		index += 1
		_refresh()
	busy = false
	if closing:
		return
	if pending_seek >= 0:
		_apply_seek()
	if index + 1 >= timeline.frames.size():
		playing = false
	_refresh()

func stop() -> void:
	closing = true
	playing = false
	host.call("cancel_replay_render")
	while busy:
		await get_tree().process_frame
	if is_instance_valid(status_strip):
		status_strip.queue_free()

func _close() -> void:
	if closing:
		return
	await stop()
	close_requested.emit()

func _refresh() -> void:
	play_button.text = "Ⅱ  " + _t("pause") if playing else "▶  " + _t("play")
	position_label.text = _t("turn_position", {"turn": timeline.turn_at(index), "total": timeline.turn_at(timeline.frames.size() - 1)})
	if is_instance_valid(status_label):
		status_label.text = "Paused · Turn %s" % timeline.turn_at(index) if not playing else "Playing · Turn %s" % timeline.turn_at(index)
	turn_picker.set_value_no_signal(timeline.turn_at(index))
	scrubber.set_value_no_signal(index)
