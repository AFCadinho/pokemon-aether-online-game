extends Node

signal time_changed
signal server_time_synchronized(server_unix_time: float)

const SECONDS_PER_DAY := 86400
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_MINUTE := 60

var _debug_seconds_since_midnight := -1
var _server_anchor_unix_seconds := -1.0
var _server_anchor_ticks_msec := 0
var _server_time_pattern: RegEx = RegEx.create_from_string(
	"^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:[.][0-9]+)?(?:Z|[+]00:00)$"
)


func get_utc_datetime(local_ticks_msec := Time.get_ticks_msec()) -> Dictionary:
	var current_unix_seconds: float = get_current_unix_time(local_ticks_msec)
	var date_time: Dictionary = Time.get_datetime_dict_from_unix_time(int(floor(current_unix_seconds)))
	if not is_debug_time_active():
		return date_time

	date_time["hour"] = _debug_seconds_since_midnight / SECONDS_PER_HOUR
	date_time["minute"] = (_debug_seconds_since_midnight % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	date_time["second"] = _debug_seconds_since_midnight % SECONDS_PER_MINUTE
	return date_time


func get_seconds_since_midnight(local_ticks_msec := Time.get_ticks_msec()) -> float:
	if is_debug_time_active():
		return float(_debug_seconds_since_midnight)

	var date_time: Dictionary = get_utc_datetime(local_ticks_msec)
	return float(
		int(date_time.get("hour", 0)) * SECONDS_PER_HOUR
		+ int(date_time.get("minute", 0)) * SECONDS_PER_MINUTE
		+ int(date_time.get("second", 0))
	)


func get_day_fraction(local_ticks_msec := Time.get_ticks_msec()) -> float:
	return get_seconds_since_midnight(local_ticks_msec) / float(SECONDS_PER_DAY)


func get_encounter_time_of_day(local_ticks_msec := Time.get_ticks_msec()) -> String:
	var hour := int(get_seconds_since_midnight(local_ticks_msec) / SECONDS_PER_HOUR)
	return "day" if hour >= 5 and hour < 21 else "night"


func sync_server_time(server_time: String, local_ticks_msec := Time.get_ticks_msec()) -> bool:
	var normalized_time := server_time.strip_edges()
	if not _is_supported_server_time(normalized_time):
		return false

	var server_unix_seconds := float(Time.get_unix_time_from_datetime_string(normalized_time))
	if server_unix_seconds <= 0.0:
		return false

	_server_anchor_unix_seconds = server_unix_seconds
	_server_anchor_ticks_msec = local_ticks_msec
	server_time_synchronized.emit(server_unix_seconds)
	time_changed.emit()
	return true


func get_current_unix_time(local_ticks_msec := Time.get_ticks_msec()) -> float:
	if not has_server_time():
		return Time.get_unix_time_from_system()
	var elapsed_msec: int = maxi(local_ticks_msec - _server_anchor_ticks_msec, 0)
	return _server_anchor_unix_seconds + (float(elapsed_msec) / 1000.0)


func has_server_time() -> bool:
	return _server_anchor_unix_seconds > 0.0


func _is_supported_server_time(value: String) -> bool:
	var match_result: RegExMatch = _server_time_pattern.search(value)
	if match_result == null:
		return false

	var month: int = int(match_result.get_string(2))
	var day: int = int(match_result.get_string(3))
	var hour: int = int(match_result.get_string(4))
	var minute: int = int(match_result.get_string(5))
	var second: int = int(match_result.get_string(6))
	if month < 1 or month > 12 or day < 1 or day > 31:
		return false
	if hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59:
		return false

	return true


func set_debug_time(hour: int, minute := 0, second := 0) -> void:
	var safe_hour: int = clampi(hour, 0, 23)
	var safe_minute: int = clampi(minute, 0, 59)
	var safe_second: int = clampi(second, 0, 59)
	_debug_seconds_since_midnight = (
		safe_hour * SECONDS_PER_HOUR
		+ safe_minute * SECONDS_PER_MINUTE
		+ safe_second
	)
	time_changed.emit()


func clear_debug_time() -> void:
	if not is_debug_time_active():
		return
	_debug_seconds_since_midnight = -1
	time_changed.emit()


func is_debug_time_active() -> bool:
	return _debug_seconds_since_midnight >= 0
