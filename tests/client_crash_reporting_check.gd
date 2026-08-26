extends SceneTree

const CrashReportServiceScript := preload("res://scripts/services/client_crash_report_service.gd")

var failures := 0


func _init() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var service_source := FileAccess.get_file_as_string(
		"res://scripts/services/client_crash_report_service.gd"
	)
	var settings_source := FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd")
	var release_workflow_source := FileAccess.get_file_as_string(
		"res://.github/workflows/deploy-desktop-r2.yml"
	)

	_check(
		project_source.contains(
			'ClientCrashReportService="*res://scripts/services/client_crash_report_service.gd"'
		),
		"crash reporting is available as a game-wide service"
	)
	_check(
		project_source.contains("settings/gdscript/always_track_call_stacks=true")
		and project_source.contains("file_logging/enable_file_logging=true"),
		"release clients retain file logs and actionable GDScript call stacks"
	)
	_check(
		service_source.contains("cleanShutdown")
		and service_source.contains("func _exit_tree()"),
		"session markers distinguish clean exits from interruptions"
	)
	_check(
		service_source.contains("show_report_dialog(true)")
		and service_source.contains("DisplayServer.clipboard_set(latest_report)"),
		"the next start offers a one-click copyable crash report"
	)
	_check(
		settings_source.contains('_create_tab_content("Support", "ui.settings.tab.support")')
		and settings_source.contains("_on_view_crash_report_pressed")
		and settings_source.contains("_on_copy_crash_report_pressed"),
		"Settings keeps the latest report easy to view and copy"
	)
	_check(
		release_workflow_source.contains(
			"--script res://tests/client_crash_reporting_check.gd"
		)
		and release_workflow_source.contains(
			"verify_client_crash_reporting_release.sh"
		),
		"desktop releases are blocked when crash reporting validation fails"
	)

	var raw_log := "\n".join(PackedStringArray([
		"Godot Engine v4.6",
		"ordinary gameplay print with a trainer name",
		"ERROR: Resource failed at /home/Alice/private/game.gd:44",
		"SCRIPT ERROR: Invalid call in res://scripts/world/world.gd:12",
		"at: update_world (res://scripts/world/world.gd:12)",
		"ERROR: Request failed https://example.test/problem?secret=value",
		"ERROR: Contact alice@example.test from 192.168.1.20",
		"ERROR: Authorization: Bearer this-must-never-leak",
		"ERROR: username=Alice",
		"ERROR: payload={\"team\":[{\"pokemon\":\"secret\"}]}",
	]))
	var safe_report: String = CrashReportServiceScript.extract_safe_diagnostics(
		raw_log,
		PackedStringArray(["/home/Alice"])
	)
	_check(safe_report.contains("SCRIPT ERROR: Invalid call"), "script errors remain useful")
	_check(safe_report.contains("res://scripts/world/world.gd:12"), "source locations remain useful")
	_check(safe_report.contains("<private_path>"), "local user paths are redacted")
	_check(safe_report.contains("https://example.test/problem?<redacted>"), "URL queries are redacted")
	_check(safe_report.contains("<email>") and safe_report.contains("<ip_address>"), "contact and network identifiers are redacted")
	_check(not safe_report.contains("ordinary gameplay print"), "ordinary gameplay output is excluded")
	_check(not safe_report.contains("this-must-never-leak"), "authorization values are excluded")
	_check(not safe_report.contains("Alice"), "account identifiers are excluded")
	_check(not safe_report.contains("secret\""), "private team payloads are excluded")

	var service: Node = CrashReportServiceScript.new()
	_check(
		service._session_looks_interrupted({
			"schemaVersion": 1,
			"cleanShutdown": false,
			"processId": 2147483647,
		}),
		"an unfinished session from a stopped process is detected"
	)
	_check(
		not service._session_looks_interrupted({
			"schemaVersion": 1,
			"cleanShutdown": true,
			"processId": 2147483647,
		}),
		"a clean shutdown is not reported as a crash"
	)
	service.free()

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_check(parsed is Dictionary, "%s interface catalog remains valid JSON" % locale)
		if parsed is Dictionary:
			var catalog := parsed as Dictionary
			for key: String in [
				"ui.settings.tab.support",
				"ui.settings.support.copy_report",
				"ui.crash_report.detected_title",
				"ui.crash_report.copied",
			]:
				_check(catalog.has(key), "%s contains %s" % [locale, key])

	if failures == 0:
		print("PASS client_crash_reporting_check")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % message)
