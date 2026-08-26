extends SceneTree

const LoanSummaryTimeScript := preload("res://scripts/ui/loan_summary_time.gd")

var failed := false


func _init() -> void:
	var now := int(Time.get_unix_time_from_datetime_string("2026-08-26T12:00:00"))

	var remaining := LoanSummaryTimeScript.remaining_copy("2026-08-28T15:30:00+00:00", now)
	_check(
		remaining.get("key") == "ui.lending.marker.summary_time.days_hours"
		and remaining.get("params", {}).get("days") == 2
		and remaining.get("params", {}).get("hours") == 3,
		"multi-day loans show days and hours"
	)
	remaining = LoanSummaryTimeScript.remaining_copy("2026-08-26T14:15:00+00:00", now)
	_check(
		remaining.get("key") == "ui.lending.marker.summary_time.hours_minutes"
		and remaining.get("params", {}).get("hours") == 2
		and remaining.get("params", {}).get("minutes") == 15,
		"short loans show hours and minutes"
	)
	remaining = LoanSummaryTimeScript.remaining_copy("2026-08-26T12:00:30+00:00", now)
	_check(
		remaining.get("key") == "ui.lending.marker.summary_time.less_than_minute",
		"the final minute remains visible"
	)
	remaining = LoanSummaryTimeScript.remaining_copy("2026-08-26T11:59:59+00:00", now)
	_check(
		remaining.get("key") == "ui.lending.marker.summary_time.due_now",
		"elapsed loans are due now"
	)
	_check(LoanSummaryTimeScript.remaining_copy("", now).is_empty(), "missing deadlines keep the original marker")

	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failed = true
	push_error("FAIL: %s" % description)
