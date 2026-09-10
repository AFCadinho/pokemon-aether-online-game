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
var speed := 1.0
var closing := false

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

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_top = 8
	offset_left = 12
	offset_right = -12
	offset_bottom = -8
	z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c30")
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	add_theme_font_size_override("font_size", 18)
	var layout := VBoxContainer.new()
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = _t("playback_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	position_label = Label.new()
	header.add_child(position_label)
	_button(header, _t("back"), _close)
	var row := HFlowContainer.new()
	layout.add_child(row)
	_button(row, "|◀", func(): seek(0)).tooltip_text = _t("begin")
	_button(row, "◀", func(): seek(timeline.index_for_turn(maxi(0, timeline.turn_at(index) - 1)))).tooltip_text = _t("previous_turn")
	play_button = _button(row, _t("play"), _toggle)
	_button(row, "▶", func():
		var turn := timeline.turn_at(index) + 1
		seek(timeline.index_for_turn(turn) if timeline.turn_indices.has(turn) else timeline.frames.size() - 1)).tooltip_text = _t("next_turn")
	_button(row, "▶|", func(): seek(timeline.frames.size() - 1)).tooltip_text = _t("end")
	turn_picker = SpinBox.new()
	turn_picker.min_value = 0
	turn_picker.max_value = timeline.turn_at(timeline.frames.size() - 1)
	turn_picker.custom_minimum_size.x = 76
	row.add_child(turn_picker)
	_button(row, _t("go_turn"), func(): seek(timeline.index_for_turn(int(turn_picker.value))))
	var speeds := OptionButton.new()
	for value: float in [0.5, 1.0, 2.0, 4.0]:
		speeds.add_item("%s×" % value)
	speeds.select(1)
	speeds.item_selected.connect(func(selected: int):
		speed = [0.5, 1.0, 2.0, 4.0][selected]
		host.call("set_replay_speed", speed))
	row.add_child(speeds)

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

func _close() -> void:
	if closing:
		return
	await stop()
	close_requested.emit()

func _refresh() -> void:
	play_button.text = _t("pause") if playing else _t("play")
	position_label.text = _t("turn_position", {"turn": timeline.turn_at(index), "total": timeline.turn_at(timeline.frames.size() - 1)})
	turn_picker.set_value_no_signal(timeline.turn_at(index))
