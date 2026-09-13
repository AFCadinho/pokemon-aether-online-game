extends CanvasLayer

const Metrics := preload("res://scripts/services/performance_metrics.gd")
const PING_COLOURS := [Color("8bdfa0"), Color("ffca72"), Color("ff8888")]
var metrics := Metrics.new()
var last_frame_usec := -1
var ping_source: Node
var panel: VBoxContainer
var ping_readout: Label
var details: Label
var readout: Label
var refresh_timer := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layout := Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -12
	panel.offset_right = -12
	panel.offset_top = 6
	panel.offset_bottom = 6
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(row)
	readout = _make_label("PerformanceReadout")
	row.add_child(readout)
	ping_readout = _make_label("PingReadout")
	row.add_child(ping_readout)
	details = _make_label("PerformanceDetails")
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(details)
	SettingsManager.settings_changed.connect(_refresh)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh()


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _process(delta: float) -> void:
	if visible and SettingsManager.performance_details:
		var now := Time.get_ticks_usec()
		if last_frame_usec >= 0:
			metrics.record_frame(now - last_frame_usec, now)
		last_frame_usec = now
	else:
		last_frame_usec = -1
		metrics.reset_frames()
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.5
		_refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	visible = SettingsManager.show_performance and GameState.get_world() != null
	if not visible:
		metrics.reset_ping()
		metrics.reset_frames()
		last_frame_usec = -1
		return
	details.visible = SettingsManager.performance_details
	if not details.visible:
		metrics.reset_frames()
		last_frame_usec = -1
	var service: Node = WorldPresenceService
	if not PvpBattleRealtimeService.active_room_code.is_empty():
		service = PvpBattleRealtimeService
	if service != ping_source:
		metrics.reset_ping()
		ping_source = service
	var ping := -1
	if service.connected:
		ping = service.latency.sample(Time.get_ticks_msec())
	var now := Time.get_ticks_msec()
	var stalled: bool = (
		service.latency.received_at >= 0
		or (service.latency.sent_at >= 0 and now - service.latency.sent_at >= 12000)
	)
	metrics.record_ping(ping, service.latency.received_at)
	var average_ping := metrics.average_ping()
	var network_text := "%d ms" % int(roundf(average_ping)) if average_ping >= 0 else LocalizationManager.text(
		"ui.performance.measuring" if service.connected and not stalled else "ui.performance.reconnecting"
	)
	readout.text = "%d FPS ·" % int(Engine.get_frames_per_second())
	ping_readout.text = network_text
	ping_readout.add_theme_color_override("font_color",
		PING_COLOURS[metrics.ping_band] if metrics.ping_band >= 0 else Color.WHITE)
	if details.visible:
		var summary := metrics.frame_summary(Time.get_ticks_usec())
		details.text = LocalizationManager.text("ui.performance.details", {
			"time": "—" if summary.is_empty() else "%.1f" % float(summary.milliseconds),
			"fps": "—" if summary.is_empty() else "%d" % int(roundf(summary.low_fps)),
		})
	# Containers retain their previous size after their minimum shrinks.
	panel.size = panel.get_combined_minimum_size()
	panel.offset_left = -panel.size.x - 12
	panel.offset_right = -12
