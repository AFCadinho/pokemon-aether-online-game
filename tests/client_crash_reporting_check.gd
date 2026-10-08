extends SceneTree

const CrashReportServiceScript := preload("res://scripts/services/client_crash_report_service.gd")

var failures := 0

class SessionProbe extends CrashReportServiceScript:
	var saved_state: Dictionary = {}
	func _write_json_file(_path: String, value: Dictionary) -> void:
		saved_state = value.duplicate(true)


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
		settings_source.contains('"Support", "ui.settings.tab.support", "ui.settings.support.description"')
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
	_check_mobile_lifecycle()
	_check_android_exit_reasons()

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


func _check_mobile_lifecycle() -> void:
	var probe := SessionProbe.new()
	probe._current_session_state = {"schemaVersion": 1, "cleanShutdown": false, "experimentalAndroid3D": true}
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not probe._session_looks_interrupted(probe.saved_state), "Focus loss alone records a normal background exit before the render thread pauses")
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_PAUSED)
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(probe.saved_state.cleanShutdown and probe.saved_state.lifecycle == "unfocused", "Resume without focus does not rearm crash detection")
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_PAUSED)
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(probe.saved_state.cleanShutdown, "Focus before renderer resume does not rearm crash detection")
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_RESUMED)
	_check(probe._session_looks_interrupted(probe.saved_state) and probe.saved_state.lifecycle == "foreground", "Visible resumed sessions still detect an unexpected termination")
	_check(probe.saved_state.experimentalAndroid3D, "Lifecycle events preserve the selected 3D mode")
	probe._exit_tree()
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_RESUMED)
	probe._record_mobile_lifecycle_event(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(probe.saved_state.cleanShutdown and probe.saved_state.lifecycle == "closed", "Late callbacks after shutdown cannot turn a clean exit into a crash")
	probe.free()


func _check_android_exit_reasons() -> void:
	var probe := SessionProbe.new()
	var active := {"schemaVersion": 1, "cleanShutdown": false, "experimentalAndroid3D": true}
	for reason: int in [8, 10, 11, 14, 15, 16]:
		var state := active.duplicate(true)
		state.androidExitInfo = {"reason": reason}
		_check(not probe._session_looks_interrupted(state), "Native normal exit does not create a report or trigger 3D recovery: %d" % reason)
	var normal := active.duplicate(true)
	normal.androidExitInfo = {"reason": 1, "status": 0}
	_check(not probe._session_looks_interrupted(normal), "Android confirms a successful self exit even if a marker remained open")
	for reason: int in [4, 5, 6, 7]:
		var state := {"schemaVersion": 1, "cleanShutdown": true, "androidExitInfo": {"reason": reason}}
		_check(probe._session_looks_interrupted(state), "A genuine crash or ANR is retained even after a pause: %d" % reason)
	for reason: int in [2, 3, 9]:
		var state := active.duplicate(true)
		state.androidExitInfo = {"reason": reason, "status": 9, "importance": 400}
		_check(not probe._session_looks_interrupted(state), "Reclaiming a cached process is not a gameplay crash: %d" % reason)
		state.androidExitInfo.importance = 100
		_check(probe._session_looks_interrupted(state), "Foreground memory/resource termination remains actionable: %d" % reason)
		state.androidExitInfo.importance = 200
		_check(probe._session_looks_interrupted(state), "Visible split-screen processes are not mistaken for cached apps: %d" % reason)
	var signal_state := {"schemaVersion": 1, "cleanShutdown": true, "androidExitInfo": {"reason": 2, "status": 11, "importance": 400}}
	_check(probe._session_looks_interrupted(signal_state), "A native segmentation fault is retained even in a background process")
	signal_state.androidExitInfo.status = 15
	_check(not probe._session_looks_interrupted(signal_state), "A normal termination signal does not override a clean background marker")
	var unknown := active.duplicate(true)
	unknown.androidExitInfo = {"reason": 0}
	_check(probe._session_looks_interrupted(unknown), "Unknown native history keeps the interruption fallback")
	var report := probe._build_crash_report({"startedAt": "test", "lifecycle": "private account details", "androidExitInfo": {"reason": 5, "status": 6, "importance": 100, "pssKiB": 1000, "rssKiB": 2000, "description": "private team", "trace": "secret trace"}})
	_check(report.contains("Android exit reason: CRASH_NATIVE (5)") and report.contains("1000 / 2000"), "Reports include the safe native reason and process memory figures")
	_check(not report.contains("private account details") and not report.contains("private team") and not report.contains("secret trace"), "Free-form Android and lifecycle payloads cannot enter a report")
	probe.free()
