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
var transport_overlay: PanelContainer
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
	panel.add_theme_stylebox_override("panel", _style(Color("#0c1b2b"), Color("#274b64"), 8, 1, 7, 7, 6, 6))
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 12
	offset_top = 6
	offset_right = -12
	offset_bottom = -6
	z_index = 100
	add_theme_stylebox_override("panel", _style(Color("#0b192b"), Color("#315c80"), 10, 1, 12, 12, 7, 7))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	add_child(layout)
	var command_row := HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 10)
	command_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(command_row)
	var live_dot := ColorRect.new()
	live_dot.color = ACCENT
	live_dot.custom_minimum_size = Vector2(3, 44)
	command_row.add_child(live_dot)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 154
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.0
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 1)
	command_row.add_child(details)
	var title := Label.new()
	title.text = _t("playback_title")
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK)
	details.add_child(title)
	status_label = _tiny_label("")
	details.add_child(status_label)
	var utility_group := _group()
	# Keep the utility controls visually light; the individual fields provide
	# the affordance while the dock itself supplies the shared hierarchy.
	utility_group.add_theme_stylebox_override("panel", _style(Color("#00000000"), Color("#00000000"), 9, 0, 9, 9, 7, 7))
	utility_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility_group.size_flags_stretch_ratio = 1.0
	command_row.add_child(utility_group)
	var utility_layout := HBoxContainer.new()
	utility_layout.add_theme_constant_override("separation", 7)
	utility_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_group.add_child(utility_layout)
	utility_layout.add_child(_tiny_label("TURN"))
	turn_picker = SpinBox.new()
	turn_picker.min_value = 0
	turn_picker.max_value = timeline.turn_at(timeline.frames.size() - 1)
	turn_picker.custom_minimum_size = Vector2(58, 34)
	turn_picker.focus_mode = Control.FOCUS_NONE
	turn_picker.add_theme_icon_override("updown", _dropdown_arrow_icon())
	var turn_input := turn_picker.get_line_edit()
	turn_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_input.add_theme_font_size_override("font_size", 14)
	turn_input.add_theme_color_override("font_color", INK)
	turn_input.add_theme_stylebox_override("normal", _style(Color("#071321"), Color("#315574"), 5, 1, 7, 7, 5, 5))
	turn_input.add_theme_stylebox_override("focus", _style(Color("#0b1e30"), ACCENT, 5, 1, 7, 7, 5, 5))
	utility_layout.add_child(turn_picker)
	_button(utility_layout, _t("go_turn"), func(): seek(timeline.index_for_turn(int(turn_picker.value))), "quiet")
	utility_layout.add_child(_tiny_label("SPEED"))
	var speeds := OptionButton.new()
	for value: float in [0.5, 1.0, 2.0, 4.0]:
		speeds.add_item("%s×" % value)
	speeds.select(1)
	speeds.custom_minimum_size = Vector2(68, 34)
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
	utility_layout.add_child(speeds)
	position_label = Label.new()
	position_label.add_theme_font_size_override("font_size", 13)
	position_label.add_theme_color_override("font_color", INK)
	position_label.add_theme_stylebox_override("normal", _style(Color("#122e47"), Color("#315c80"), 6, 1, 8, 8, 4, 4))
	position_label.custom_minimum_size.y = 34
	command_row.add_child(position_label)
	var back_button := _button(command_row, _t("back"), _close, "quiet")
	back_button.custom_minimum_size = Vector2(66, 38)
	_build_transport_overlay()
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

func _build_transport_overlay() -> void:
	var moves: Control = host.get("moves_grid") as Control
	if moves == null or moves.get_parent() == null:
		return
	transport_overlay = PanelContainer.new()
	transport_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	transport_overlay.offset_left = -380
	transport_overlay.offset_top = -136
	transport_overlay.offset_right = -96
	transport_overlay.offset_bottom = -78
	transport_overlay.z_index = 100
	transport_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	transport_overlay.add_theme_stylebox_override("panel", _style(Color("#081522e8"), Color("#397b9b"), 9, 1, 8, 8, 7, 7))
	moves.get_parent().add_child(transport_overlay)
	var transport_center := CenterContainer.new()
	transport_overlay.add_child(transport_center)
	var transport_buttons := HBoxContainer.new()
	transport_buttons.add_theme_constant_override("separation", 5)
	transport_center.add_child(transport_buttons)
	var begin_button := _button(transport_buttons, "|◀", func(): seek(0), "quiet")
	begin_button.custom_minimum_size = Vector2(36, 36)
	begin_button.tooltip_text = _t("begin")
	var previous_button := _button(transport_buttons, "◀", func(): seek(timeline.index_for_turn(maxi(0, timeline.turn_at(index) - 1))), "quiet")
	previous_button.custom_minimum_size = Vector2(36, 36)
	previous_button.tooltip_text = _t("previous_turn")
	play_button = _button(transport_buttons, "▶  " + _t("play"), _toggle, "primary")
	play_button.custom_minimum_size = Vector2(70, 36)
	var next_button := _button(transport_buttons, "▶", func():
		var turn := timeline.turn_at(index) + 1
		seek(timeline.index_for_turn(turn) if timeline.turn_indices.has(turn) else timeline.frames.size() - 1), "quiet")
	next_button.custom_minimum_size = Vector2(36, 36)
	next_button.tooltip_text = _t("next_turn")
	var end_button := _button(transport_buttons, "▶|", func(): seek(timeline.frames.size() - 1), "quiet")
	end_button.custom_minimum_size = Vector2(36, 36)
	end_button.tooltip_text = _t("end")

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
	if is_instance_valid(transport_overlay):
		transport_overlay.queue_free()

func _close() -> void:
	if closing:
		return
	await stop()
	close_requested.emit()

func _refresh() -> void:
	play_button.text = "Ⅱ  " + _t("pause") if playing else "▶  " + _t("play")
	position_label.text = _t("turn_position", {"turn": timeline.turn_at(index), "total": timeline.turn_at(timeline.frames.size() - 1)})
	status_label.text = "Paused" if not playing else "Playing"
	turn_picker.set_value_no_signal(timeline.turn_at(index))
	scrubber.set_value_no_signal(index)
