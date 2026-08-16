extends SceneTree

const WorldTimeServiceScript := preload("res://scripts/services/world_time_service.gd")

var failed := false
var time_change_count := 0


func _init() -> void:
	var service: Node = WorldTimeServiceScript.new()
	root.add_child(service)
	service.time_changed.connect(_on_time_changed)
	_check_true(not service.has_server_time(), "local UTC is the initial fallback")
	_check_true(not service.sync_server_time("", 1000), "empty server time is rejected")
	_check_true(not service.sync_server_time("not-a-time", 1000), "invalid server time is rejected")
	_check_true(not service.sync_server_time("2026-07-17T12:34:56+02:00", 1000), "non-UTC server offsets are rejected")
	_check_true(service.sync_server_time("2026-07-17T12:34:56.123456+00:00", 1000), "backend datetime serialization with UTC offset is supported")
	var expected_offset_unix: int = int(Time.get_unix_time_from_datetime_string("2026-07-17T12:34:56Z"))
	_check_equal(int(floor(service.get_current_unix_time(1000))), expected_offset_unix, "UTC offset serialization preserves the backend second")
	_check_true(service.sync_server_time("2026-07-17T12:34:56Z", 1000), "valid backend UTC establishes an anchor")
	_check_true(service.has_server_time(), "server anchor becomes authoritative after synchronization")
	var anchored_unix: float = Time.get_unix_time_from_datetime_string("2026-07-17T12:34:56Z")
	_check_approx(service.get_current_unix_time(3500), anchored_unix + 2.5, "server time advances with monotonic elapsed time")
	var server_date_time: Dictionary = service.get_utc_datetime(1000)
	_check_equal(int(server_date_time.get("hour", -1)), 12, "shared clock reads the server hour")
	_check_equal(int(server_date_time.get("minute", -1)), 34, "shared clock reads the server minute")

	service.set_debug_time(21, 34, 56)
	var date_time: Dictionary = service.get_utc_datetime()
	_check_equal(int(date_time.get("hour", -1)), 21, "debug hour drives the shared clock")
	_check_equal(int(date_time.get("minute", -1)), 34, "debug minute drives the shared clock")
	_check_equal(int(date_time.get("second", -1)), 56, "debug second drives the shared clock")
	_check_approx(service.get_seconds_since_midnight(), 77696.0, "seconds since midnight are deterministic")
	_check_true(service.get_encounter_time_of_day() == "night", "night preview selects night encounters")
	_check_approx(service.get_day_fraction(), 77696.0 / 86400.0, "day fraction uses the shared time")
	service.set_debug_time(12)
	_check_true(service.get_encounter_time_of_day() == "day", "day preview selects day encounters")
	_check_equal(time_change_count, 4, "both supported server formats and debug time emit refresh signals")

	service.set_debug_time(99, -4, 80)
	date_time = service.get_utc_datetime()
	_check_equal(int(date_time.get("hour", -1)), 23, "debug hour is safely bounded")
	_check_equal(int(date_time.get("minute", -1)), 0, "debug minute is safely bounded")
	_check_equal(int(date_time.get("second", -1)), 59, "debug second is safely bounded")
	_check_true(service.sync_server_time("2026-07-17T13:45:00Z", 2000), "server anchor can refresh while preview time is active")
	date_time = service.get_utc_datetime(2000)
	_check_equal(int(date_time.get("hour", -1)), 23, "debug preview remains active during background server resync")

	service.clear_debug_time()
	_check_true(not service.is_debug_time_active(), "clearing debug time restores UTC")
	_check_equal(time_change_count, 7, "clearing debug time emits a refresh signal")
	server_date_time = service.get_utc_datetime(2000)
	_check_equal(int(server_date_time.get("hour", -1)), 13, "clearing debug time restores the latest server anchor")
	_check_equal(int(server_date_time.get("minute", -1)), 45, "default time retains the latest server minute")

	service.queue_free()
	quit(1 if failed else 0)


func _on_time_changed() -> void:
	time_change_count += 1


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)


func _check_equal(actual: int, expected: int, label: String) -> void:
	_check_true(actual == expected, "%s (expected %d, got %d)" % [label, expected, actual])


func _check_approx(actual: float, expected: float, label: String) -> void:
	_check_true(is_equal_approx(actual, expected), "%s (expected %f, got %f)" % [label, expected, actual])
