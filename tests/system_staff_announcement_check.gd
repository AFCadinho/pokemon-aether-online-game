extends SceneTree

const BANNER_SCRIPT_PATH := "res://scripts/ui/system_notice_banner.gd"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var banner_script := load(BANNER_SCRIPT_PATH) as Script
	_check(banner_script != null, "System notice banner script loads")
	if banner_script == null:
		quit(1)
		return

	var host := Control.new()
	root.add_child(host)
	var banner: Control = banner_script.new()
	host.add_child(banner)
	await process_frame

	var first := {
		"announcementId": "announcement-1",
		"message": "Safari Zone opens soon!",
		"expiresAt": "2100-08-29T18:30:15+00:00",
	}
	_check(bool(banner.call("enqueue_notice", first)), "A current staff announcement is accepted")
	_check(banner.visible, "A staff announcement appears on screen")
	var message_label := banner.get("message_label") as Label
	var title_label := banner.get("title_label") as Label
	_check(message_label != null and message_label.text == "Safari Zone opens soon!", "The banner shows the plain player message")
	_check(title_label != null and title_label.text.strip_edges() != "", "The banner has a localized system title")
	_check(not bool(banner.call("enqueue_notice", first)), "A repeated announcement ID is deduplicated")

	var second := {
		"announcementId": "announcement-2",
		"message": "The event starts now.",
		"expiresAt": "2100-08-29T18:30:30+00:00",
	}
	_check(bool(banner.call("enqueue_notice", second)), "A second announcement is queued")
	banner.call("_finish_current_notice")
	_check(message_label.text == "The event starts now.", "Queued announcements appear in order")
	_check(
		not bool(banner.call("enqueue_notice", {
			"announcementId": "expired",
			"message": "Stale message",
			"expiresAt": "2000-01-01T00:00:00+00:00",
		})),
		"Expired announcements are not replayed"
	)

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		overlay_source.contains('message_type == "system.staff_announcement"')
		and overlay_source.contains('add_system_message(str(message.get("message", "")).strip_edges())'),
		"Realtime staff announcements also enter System chat"
	)
	_check(
		overlay_source.contains("warning_panel.position.y + warning_panel.size.y + 10.0"),
		"Ordinary notices stack below the Game Access warning"
	)

	host.free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
