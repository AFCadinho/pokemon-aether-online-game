extends CanvasLayer

var readout: Label
var refresh_timer := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	readout = Label.new()
	readout.name = "PerformanceReadout"
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	readout.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	readout.position = Vector2(-12, 6)
	readout.add_theme_font_size_override("font_size", 14)
	readout.add_theme_color_override("font_color", Color.WHITE)
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	layout.add_child(readout)
	SettingsManager.settings_changed.connect(_refresh)
	LocalizationManager.locale_changed.connect(_on_locale_changed)
	_refresh()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.5
		_refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	visible = SettingsManager.show_performance and GameState.get_world() != null
	if not visible:
		return
	var service: Node = WorldPresenceService
	if not PvpBattleRealtimeService.active_room_code.is_empty():
		service = PvpBattleRealtimeService
	var ping := -1
	if service.connected:
		ping = service.latency.sample(Time.get_ticks_msec())
	var now := Time.get_ticks_msec()
	var stalled: bool = (
		service.latency.received_at >= 0
		or (service.latency.sent_at >= 0 and now - service.latency.sent_at >= 12000)
	)
	var network_text := "%d ms" % ping if ping >= 0 else LocalizationManager.text(
		"ui.performance.measuring" if service.connected and not stalled else "ui.performance.reconnecting"
	)
	readout.text = "%d FPS · %s" % [int(Engine.get_frames_per_second()), network_text]
