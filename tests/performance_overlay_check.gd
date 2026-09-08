extends SceneTree

const Latency := preload("res://scripts/services/connection_latency.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var metrics := preload("res://scripts/services/performance_metrics.gd").new()
	metrics.record_frame(10000, 10000)
	metrics.record_frame(50000, 60000)
	var summary: Dictionary = metrics.frame_summary(60000)
	_check(is_equal_approx(summary.milliseconds, 30.0), "average frame time includes stutters")
	_check(is_equal_approx(summary.low_fps, 20.0), "slowest frame determines recent FPS dip")
	_check(metrics.frame_summary(5060000).is_empty(), "old frame dips expire after five seconds")
	metrics.record_ping(40, 1)
	metrics.record_ping(40, 1)
	metrics.record_ping(40, 1)
	_check(metrics.ping_band == -1, "UI refreshes do not count as new ping samples")
	metrics.record_ping(40, 2)
	metrics.record_ping(40, 3)
	_check(metrics.ping_band == 0, "three low pings yield green")
	metrics.record_ping(150, 4)
	_check(metrics.ping_band == 0, "one moderate spike does not flicker the colour")
	for stamp: int in range(5, 11):
		metrics.record_ping(250, stamp)
	_check(metrics.ping_band == 2, "sustained high ping yields red")
	for stamp: int in range(11, 17):
		metrics.record_ping(195, stamp)
	_check(metrics.ping_band == 2, "hysteresis avoids flicker at the red boundary")
	for stamp: int in range(17, 23):
		metrics.record_ping(150, stamp)
	_check(metrics.ping_band == 1, "sustained recovery yields orange")
	metrics.record_ping(-1, 24)
	_check(metrics.ping_band == -1, "connection loss clears the colour history")
	var latency := Latency.new()
	_check(latency.sample(0) == -1, "no fabricated initial ping")
	latency.received(10)
	_check(latency.sample(10) == -1, "unsolicited pong ignored")
	latency.sent(100)
	latency.received(142)
	_check(latency.sample(142) == 42, "round trip measured in milliseconds")
	_check(latency.sample(15142) == -1, "stale sample expires")
	latency.sent(20000)
	latency.sent(30000)
	latency.received(33000)
	_check(latency.sample(33000) == -1, "late pong cannot become a misleading fresh sample")
	latency.sent(34000)
	latency.received(34060)
	_check(latency.sample(34060) == 60, "measurement recovers after delayed pong")
	latency.reset()
	_check(latency.sample(34060) == -1, "reset clears previous connection sample")

	var settings := root.get_node("SettingsManager")
	var overlay := root.get_node("PerformanceOverlay")
	var presence := root.get_node("WorldPresenceService")
	var pvp := root.get_node("PvpBattleRealtimeService")
	# Only this slot's isolated settings are used; restore the preference afterward.
	var original_details: bool = settings.performance_details
	var original: bool = settings.show_performance
	settings.set_show_performance(false)
	_check(not overlay.visible, "disabled meter hidden immediately")
	var world := Node.new()
	world.add_to_group("world")
	root.add_child(world)
	settings.set_show_performance(true)
	_check(overlay.visible, "enabled meter visible in gameplay")
	settings.show_performance = false
	settings.load_settings()
	_check(settings.show_performance, "enabled preference survives reload")
	var menu := load("res://scenes/interface/settings/settings_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	var details_toggle := menu.find_child("PerformanceDetailsCheckBox", true, false) as CheckBox
	_check(details_toggle != null, "optional details switch exists")
	if details_toggle != null:
		details_toggle.button_pressed = true
	_check(settings.performance_details and overlay.details.visible, "details switch immediately reveals second line")
	settings.performance_details = false
	settings.load_settings()
	_check(settings.performance_details, "details preference survives reload")
	var toggle := menu.find_child("PerformanceCheckBox", true, false) as CheckBox
	_check(toggle != null and toggle.button_pressed, "settings switch reflects saved preference")
	presence.set_process(false)
	pvp.set_process(false)
	presence.connected = true
	var now := Time.get_ticks_msec()
	presence.latency.sent(now - 42)
	presence.latency.received(now)
	overlay._refresh()
	_check(overlay.ping_readout.text.ends_with("42 ms"), "world connection supplies the displayed ping")
	pvp.active_room_code = "LOCAL_TEST"
	pvp.connected = true
	now = Time.get_ticks_msec()
	pvp.latency.sent(now - 76)
	pvp.latency.received(now)
	overlay._refresh()
	_check(overlay.ping_readout.text.ends_with("76 ms"), "battle connection takes precedence")
	pvp.latency.received_at = Time.get_ticks_msec() - 15001
	overlay._refresh()
	_check(not overlay.ping_readout.text.ends_with("ms"), "stalled open connection hides expired ping")
	pvp.connected = false
	overlay._refresh()
	_check(not overlay.ping_readout.text.ends_with("ms"), "disconnected battle cannot display old or world ping")
	pvp.active_room_code = ""
	presence.connected = false
	presence.latency.reset()
	pvp.latency.reset()
	if toggle != null:
		toggle.button_pressed = false
	_check(not settings.show_performance and not overlay.visible, "settings switch hides meter immediately")
	settings.show_performance = true
	settings.load_settings()
	_check(not settings.show_performance, "disabled preference survives reload")
	settings.set_show_performance(true)
	world.remove_from_group("world")
	overlay._refresh()
	_check(not overlay.visible, "meter hidden outside gameplay")
	world.add_to_group("world")
	settings.set_show_performance(true)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await process_frame
		var rect: Rect2 = overlay.panel.get_global_rect()
		_check(rect.position.x >= 0 and rect.end.x <= root.get_visible_rect().size.x, "readout remains inside viewport")
		_check(absf(rect.end.x - (root.get_visible_rect().size.x - 12)) < 1, "meter stays aligned to the right edge")
	if details_toggle != null:
		details_toggle.button_pressed = false
	_check(not overlay.details.visible, "compact mode hides the second line immediately")
	settings.performance_details = true
	settings.load_settings()
	_check(not settings.performance_details, "compact preference survives reload")
	settings.set_performance_details(original_details)
	settings.set_show_performance(original)
	menu.queue_free()
	world.queue_free()
	await process_frame
	print("performance_overlay_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
