extends CanvasLayer

const Metrics := preload("res://scripts/services/performance_metrics.gd")
const FrameSpikeRecorder := preload("res://scripts/services/frame_spike_recorder.gd")
const CERULEAN_MAP_ID := "kanto_cerulean_city"
const PING_COLOURS := [Color("8bdfa0"), Color("ffca72"), Color("ff8888")]
var metrics := Metrics.new()
var spike_recorder := FrameSpikeRecorder.new()
var last_frame_usec := -1
var ping_source: Node
var panel: VBoxContainer
var ping_readout: Label
var details: Label
var recording_readout: Label
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
	recording_readout = _make_label("PerformanceRecording")
	recording_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	recording_readout.add_theme_color_override("font_color", Color("ffca72"))
	panel.add_child(recording_readout)
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
			var frame_duration_usec := now - last_frame_usec
			metrics.record_frame(frame_duration_usec, now)
			spike_recorder.record_frame(frame_duration_usec, _capture_spike_context)
		last_frame_usec = now
	else:
		last_frame_usec = -1
		metrics.reset_frames()
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.5
		_refresh()


func _exit_tree() -> void:
	spike_recorder.finish()


func _on_locale_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	visible = SettingsManager.show_performance and GameState.get_world() != null
	if not visible:
		if spike_recorder.is_recording():
			spike_recorder.finish()
		if recording_readout != null:
			recording_readout.visible = false
		metrics.reset_ping()
		metrics.reset_frames()
		last_frame_usec = -1
		return
	details.visible = SettingsManager.performance_details
	_update_spike_recording()
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


func _update_spike_recording() -> void:
	var should_record := (
		visible
		and details.visible
		and _get_current_map_id() == CERULEAN_MAP_ID
	)
	if should_record and not spike_recorder.is_recording():
		spike_recorder.start(_capture_session_context())
	elif not should_record and spike_recorder.is_recording():
		spike_recorder.finish()
	recording_readout.visible = spike_recorder.is_recording()
	recording_readout.text = LocalizationManager.text("ui.performance.cerulean_recording") \
		if recording_readout.visible \
		else ""


func _get_current_map_id() -> String:
	var current_map: Node = GameState.current_map
	if current_map == null or not is_instance_valid(current_map):
		return ""
	if current_map.has_method("get_map_id"):
		return str(current_map.call("get_map_id")).strip_edges()
	return str(current_map.name)


func _capture_session_context() -> Dictionary:
	return {
		"map_id": _get_current_map_id(),
		"platform": OS.get_name(),
		"engine": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"viewport": [get_viewport().size.x, get_viewport().size.y],
		"pixel_scale": SettingsManager.world_pixel_scale,
		"hide_other_players": SettingsManager.hide_other_players,
		"weather_effects": SettingsManager.weather_effects,
		"terrain_effects": SettingsManager.terrain_effects,
	}


func _capture_spike_context() -> Dictionary:
	var world: Node = GameState.get_world()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.get_parent() != null and player.get_parent().is_in_group("world"):
		world = player.get_parent()
	var weather_controller: Node = world.get_node_or_null("WeatherController") if world != null else null
	var day_night_controller: Node = world.get_node_or_null("DayNightController") if world != null else null
	var remote_count := 0
	if world != null:
		var remote_players_value: Variant = world.get("remote_player_avatars")
		if remote_players_value is Dictionary:
			remote_count = (remote_players_value as Dictionary).size()
	var player_context := {
		"position": [],
		"moving": false,
		"mount_id": "",
		"move_duration_ms": 0.0,
	}
	if player != null:
		player_context.position = [snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1)]
		if player.has_method("is_tile_moving"):
			player_context.moving = bool(player.call("is_tile_moving"))
		if player.has_method("get_active_mount_id"):
			player_context.mount_id = str(player.call("get_active_mount_id"))
		if player.has_method("get_current_move_duration"):
			player_context.move_duration_ms = snappedf(float(player.call("get_current_move_duration")) * 1000.0, 0.1)
	var weather := "unknown"
	if weather_controller != null and weather_controller.has_method("get_effective_weather"):
		weather = str(weather_controller.call("get_effective_weather"))
	var night_intensity := 0.0
	if day_night_controller != null:
		night_intensity = float(day_night_controller.get("current_night_intensity"))
	return {
		"map_id": _get_current_map_id(),
		"player": player_context,
		"weather": weather,
		"time_of_day": WorldTimeService.get_encounter_time_of_day(),
		"night_intensity": snappedf(night_intensity, 0.001),
		"window_focused": DisplayServer.window_is_focused(),
		"process_frame": Engine.get_process_frames(),
		"engine_fps": Engine.get_frames_per_second(),
		"process_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0, 0.001),
		"physics_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0, 0.001),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_memory_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"physics_2d_active": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"physics_2d_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		"remote_players": remote_count,
	}
