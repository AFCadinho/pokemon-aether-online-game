extends RefCounted


static func remaining_copy(deadline: String, now_unix := -1) -> Dictionary:
	var cleaned := deadline.strip_edges()
	if cleaned.length() < 19:
		return {}
	var deadline_unix := int(Time.get_unix_time_from_datetime_string(cleaned.left(19)))
	if deadline_unix <= 0:
		return {}
	var current_unix := int(Time.get_unix_time_from_system()) if now_unix < 0 else int(now_unix)
	var remaining_seconds := deadline_unix - current_unix
	if remaining_seconds <= 0:
		return {"key": "ui.lending.marker.summary_time.due_now"}
	if remaining_seconds < 60:
		return {"key": "ui.lending.marker.summary_time.less_than_minute"}

	var total_minutes := remaining_seconds / 60
	var days := total_minutes / (24 * 60)
	var hours := (total_minutes % (24 * 60)) / 60
	var minutes := total_minutes % 60
	if days > 0:
		return {
			"key": "ui.lending.marker.summary_time.days_hours",
			"params": {"days": days, "hours": hours},
		}
	if hours > 0:
		return {
			"key": "ui.lending.marker.summary_time.hours_minutes",
			"params": {"hours": hours, "minutes": minutes},
		}
	return {
		"key": "ui.lending.marker.summary_time.minutes",
		"params": {"minutes": minutes},
	}
