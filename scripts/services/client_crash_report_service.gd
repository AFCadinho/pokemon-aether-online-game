extends Node

class_name ClientCrashReportServiceNode

const ClientBuild := preload("res://scripts/services/client_build.gd")

const DIAGNOSTICS_DIR := "user://diagnostics"
const SESSION_STATE_PATH := "user://diagnostics/client_session_state.json"
const LATEST_REPORT_PATH := "user://diagnostics/latest_crash_report.txt"
const MAX_LOG_READ_BYTES := 64 * 1024
const MAX_DIAGNOSTIC_LINES := 180

const UI_BACKDROP := Color("#020711d9")
const UI_PANEL := Color("#07111ffb")
const UI_SLOT := Color("#0d1c30f5")
const UI_BORDER := Color("#7aa7f4")
const UI_BORDER_SOFT := Color("#315070")
const UI_TEXT := Color("#f1f5fb")
const UI_MUTED := Color("#aebbc9")
const UI_ACCENT := Color("#b980ff")
const UI_SUCCESS := Color("#75d69c")

var latest_report := ""
var new_interrupted_session_detected := false
var _current_session_state: Dictionary = {}
var _localization_manager: Node
var _dialog_layer: CanvasLayer
var _dialog_root: Control
var _dialog_title: Label
var _dialog_message: Label
var _dialog_privacy_note: Label
var _dialog_report: TextEdit
var _dialog_status: Label
var _dialog_copy_button: Button
var _dialog_close_button: Button
var _dialog_uses_crash_intro := false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_diagnostics_directory()
	latest_report = _read_text_file(LATEST_REPORT_PATH)

	# Running the project through the editor is stopped abruptly during normal
	# development, so only exported clients participate in crash detection.
	# Closing or refreshing a browser tab does not guarantee _exit_tree runs.
	if OS.has_feature("editor") or OS.has_feature("web"):
		return

	var previous_state := _read_json_dictionary(SESSION_STATE_PATH)
	if _session_looks_interrupted(previous_state):
		latest_report = _build_crash_report(previous_state)
		_write_text_file(LATEST_REPORT_PATH, latest_report)
		new_interrupted_session_detected = true

	_current_session_state = {
		"schemaVersion": 1,
		"cleanShutdown": false,
		"processId": OS.get_process_id(),
		"startedAtUnix": int(Time.get_unix_time_from_system()),
		"startedAt": Time.get_datetime_string_from_system(false, true),
		"buildId": ClientBuild.get_build_id(),
	}
	_write_json_file(SESSION_STATE_PATH, _current_session_state)


func _ready() -> void:
	_localization_manager = get_node_or_null("/root/LocalizationManager")
	if (
		_localization_manager != null
		and _localization_manager.has_signal("locale_changed")
		and not _localization_manager.locale_changed.is_connected(_on_locale_changed)
	):
		_localization_manager.locale_changed.connect(_on_locale_changed)
	if new_interrupted_session_detected:
		_show_interrupted_session_prompt.call_deferred()


func _exit_tree() -> void:
	if _current_session_state.is_empty():
		return
	_current_session_state["cleanShutdown"] = true
	_current_session_state["endedAtUnix"] = int(Time.get_unix_time_from_system())
	_current_session_state["endedAt"] = Time.get_datetime_string_from_system(false, true)
	_write_json_file(SESSION_STATE_PATH, _current_session_state)


func _unhandled_input(event: InputEvent) -> void:
	if _dialog_root == null or not _dialog_root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_report_dialog()
		get_viewport().set_input_as_handled()


func has_report() -> bool:
	return not latest_report.strip_edges().is_empty()


func get_latest_report() -> String:
	return latest_report


func copy_latest_report() -> bool:
	if not has_report():
		return false
	DisplayServer.clipboard_set(latest_report)
	return true


func show_report_dialog(use_crash_intro: bool = false) -> void:
	_ensure_report_dialog()
	_dialog_uses_crash_intro = use_crash_intro
	_refresh_dialog_text()
	_dialog_report.text = latest_report
	_dialog_report.scroll_vertical = 0
	_dialog_copy_button.disabled = not has_report()
	_dialog_status.text = ""
	_dialog_root.visible = true
	_dialog_copy_button.grab_focus()


func hide_report_dialog() -> void:
	if _dialog_root != null:
		_dialog_root.visible = false


func _show_interrupted_session_prompt() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	show_report_dialog(true)


func _session_looks_interrupted(state: Dictionary) -> bool:
	if state.is_empty() or int(state.get("schemaVersion", 0)) != 1:
		return false
	if bool(state.get("cleanShutdown", true)):
		return false
	return true


func _build_crash_report(previous_state: Dictionary) -> String:
	var source_log_path := _find_previous_log_path()
	var source_log := _read_tail(source_log_path, MAX_LOG_READ_BYTES)
	var private_paths := PackedStringArray([
		ProjectSettings.globalize_path("user://").trim_suffix("/"),
		OS.get_environment("HOME").trim_suffix("/"),
		OS.get_environment("USERPROFILE").trim_suffix("/"),
	])
	var diagnostics := extract_safe_diagnostics(source_log, private_paths)
	if diagnostics.is_empty():
		diagnostics = "No specific engine error was recorded. The client log ended unexpectedly."

	var previous_started_at := str(previous_state.get("startedAt", "Unknown"))
	var previous_build := str(previous_state.get("buildId", "Unknown"))
	var report_id := "%d-%d" % [
		int(Time.get_unix_time_from_system()),
		maxi(int(previous_state.get("processId", 0)), 0),
	]
	var engine_version := Engine.get_version_info()
	var engine_label := "%s.%s.%s" % [
		str(engine_version.get("major", "?")),
		str(engine_version.get("minor", "?")),
		str(engine_version.get("patch", "?")),
	]
	var source_name := source_log_path.get_file() if not source_log_path.is_empty() else "Unavailable"
	return "\n".join(PackedStringArray([
		"POKEAETHER CLIENT CRASH REPORT",
		"Share this complete report with PokeAether staff.",
		"This report excludes account credentials, sessions, chats, teams, and private battle data.",
		"",
		"Report ID: %s" % report_id,
		"Detected: %s" % Time.get_datetime_string_from_system(false, true),
		"Previous session started: %s" % previous_started_at,
		"Client build: %s" % previous_build,
		"Current client build: %s" % ClientBuild.get_build_id(),
		"Platform: %s" % OS.get_name(),
		"OS version: %s" % _single_line(OS.get_version()),
		"Godot version: %s" % engine_label,
		"Rendering method: %s" % RenderingServer.get_current_rendering_method(),
		"Graphics adapter: %s" % _single_line(RenderingServer.get_video_adapter_name()),
		"Source log: %s" % source_name,
		"",
		"SAFE ERROR DETAILS",
		"------------------",
		diagnostics,
		"",
		"END OF REPORT",
	]))


static func extract_safe_diagnostics(contents: String, private_paths: PackedStringArray = PackedStringArray()) -> String:
	if contents.is_empty():
		return ""
	var safe_lines: Array[String] = []
	var native_backtrace_active := false
	for raw_line: String in contents.split("\n", false):
		var stripped := raw_line.strip_edges()
		if stripped.is_empty():
			continue
		if (
			stripped.contains("Program crashed with signal")
			or stripped.contains("Dumping the backtrace")
			or stripped.contains("GDScript backtrace")
		):
			native_backtrace_active = true
		if not _is_diagnostic_log_line(stripped, native_backtrace_active):
			continue
		if _contains_private_payload_hint(stripped):
			continue
		var sanitized := _sanitize_log_line(stripped, private_paths)
		if sanitized.is_empty():
			continue
		safe_lines.append(sanitized)
		if safe_lines.size() > MAX_DIAGNOSTIC_LINES:
			safe_lines.pop_front()
		if stripped.contains("END OF GDSCRIPT BACKTRACE"):
			native_backtrace_active = false
	return "\n".join(PackedStringArray(safe_lines))


static func _is_diagnostic_log_line(line: String, native_backtrace_active: bool) -> bool:
	if (
		line.begins_with("ERROR:")
		or line.begins_with("WARNING:")
		or line.begins_with("SCRIPT ERROR:")
		or line.begins_with("USER ERROR:")
		or line.begins_with("USER WARNING:")
		or line.begins_with("at:")
		or line.begins_with("handle_crash:")
		or line.begins_with("Engine version:")
		or line.contains("Program crashed with signal")
		or line.contains("Dumping the backtrace")
		or line.contains("GDScript backtrace")
		or line.contains("C++ BACKTRACE")
	):
		return true
	if native_backtrace_active and line.begins_with("["):
		return true
	return false


static func _contains_private_payload_hint(line: String) -> bool:
	var lower := line.to_lower()
	for hint: String in [
		"authorization", "bearer ", "password", "cookie", "access_token",
		"refresh_token", "auth_session", "username", "display=", "email",
		"logged in as", "\"team\"", "\"party\"", "\"pokemon\"",
		"\"moves\"", "\"participants\"", "private battle", "websocket",
	]:
		if lower.contains(hint):
			return true
	return false


static func _sanitize_log_line(line: String, private_paths: PackedStringArray) -> String:
	var sanitized := _single_line(line)
	for private_path: String in private_paths:
		if not private_path.is_empty():
			sanitized = sanitized.replace(private_path, "<private_path>")
	var parts := sanitized.split(" ")
	for index: int in range(parts.size()):
		var part := parts[index]
		var url_start := part.find("https://")
		if url_start < 0:
			url_start = part.find("http://")
		if url_start < 0:
			continue
		var query_start := part.find("?", url_start)
		if query_start >= 0:
			parts[index] = "%s?<redacted>" % part.substr(0, query_start)
	sanitized = " ".join(parts)
	var email_pattern := RegEx.create_from_string(
		"[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}"
	)
	sanitized = email_pattern.sub(sanitized, "<email>", true)
	var ipv4_pattern := RegEx.create_from_string(
		"(?<![0-9])(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9])"
	)
	sanitized = ipv4_pattern.sub(sanitized, "<ip_address>", true)
	var jwt_pattern := RegEx.create_from_string(
		"[A-Za-z0-9_\\-]{20,}\\.[A-Za-z0-9_\\-]{20,}\\.[A-Za-z0-9_\\-]{20,}"
	)
	return jwt_pattern.sub(sanitized, "<token>", true)


static func _single_line(value: String) -> String:
	return value.replace("\r", " ").replace("\n", " ").strip_edges()


func _find_previous_log_path() -> String:
	var configured_path := str(ProjectSettings.get_setting(
		"debug/file_logging/log_path",
		"user://logs/godot.log"
	))
	var log_directory := configured_path.get_base_dir()
	var current_log_name := configured_path.get_file()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(log_directory)):
		return ""
	var newest_path := ""
	var newest_modified := 0
	for file_name: String in DirAccess.get_files_at(log_directory):
		if file_name == current_log_name or not file_name.to_lower().ends_with(".log"):
			continue
		var candidate_path := log_directory.path_join(file_name)
		var modified := int(FileAccess.get_modified_time(candidate_path))
		if modified >= newest_modified:
			newest_modified = modified
			newest_path = candidate_path
	return newest_path


func _read_tail(path: String, max_bytes: int) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var length := file.get_length()
	if length > max_bytes:
		file.seek(length - max_bytes)
	var contents := file.get_buffer(mini(max_bytes, length)).get_string_from_utf8()
	file.close()
	return contents


func _ensure_diagnostics_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIAGNOSTICS_DIR))


func _read_json_dictionary(path: String) -> Dictionary:
	var contents := _read_text_file(path)
	if contents.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(contents)
	return parsed if parsed is Dictionary else {}


func _read_text_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func _write_json_file(path: String, value: Dictionary) -> void:
	_write_text_file(path, JSON.stringify(value))


func _write_text_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Client crash diagnostics could not write %s" % path)
		return
	file.store_string(contents)
	file.close()


func _ensure_report_dialog() -> void:
	if _dialog_root != null:
		return
	_dialog_layer = CanvasLayer.new()
	_dialog_layer.name = "ClientCrashReportLayer"
	_dialog_layer.layer = 200
	add_child(_dialog_layer)

	_dialog_root = Control.new()
	_dialog_root.name = "ClientCrashReportDialog"
	_dialog_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_layer.add_child(_dialog_root)

	var backdrop := ColorRect.new()
	backdrop.color = UI_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 18
	center.offset_top = 18
	center.offset_right = -18
	center.offset_bottom = -18
	_dialog_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 520)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(UI_PANEL, UI_BORDER, 14, 1))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	_dialog_title = Label.new()
	_dialog_title.add_theme_color_override("font_color", UI_TEXT)
	_dialog_title.add_theme_font_size_override("font_size", 23)
	stack.add_child(_dialog_title)

	_dialog_message = Label.new()
	_dialog_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_message.add_theme_color_override("font_color", UI_TEXT)
	_dialog_message.add_theme_font_size_override("font_size", 14)
	stack.add_child(_dialog_message)

	_dialog_privacy_note = Label.new()
	_dialog_privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_privacy_note.add_theme_color_override("font_color", UI_MUTED)
	_dialog_privacy_note.add_theme_font_size_override("font_size", 12)
	stack.add_child(_dialog_privacy_note)

	_dialog_report = TextEdit.new()
	_dialog_report.name = "CrashReportText"
	_dialog_report.custom_minimum_size = Vector2(0, 285)
	_dialog_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_report.editable = false
	_dialog_report.context_menu_enabled = true
	_dialog_report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_dialog_report.add_theme_color_override("font_color", UI_TEXT)
	_dialog_report.add_theme_color_override("background_color", UI_SLOT)
	stack.add_child(_dialog_report)

	_dialog_status = Label.new()
	_dialog_status.custom_minimum_size.y = 24
	_dialog_status.add_theme_color_override("font_color", UI_SUCCESS)
	_dialog_status.add_theme_font_size_override("font_size", 12)
	stack.add_child(_dialog_status)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	stack.add_child(button_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	_dialog_close_button = Button.new()
	_dialog_close_button.custom_minimum_size = Vector2(120, 40)
	_dialog_close_button.pressed.connect(hide_report_dialog)
	_apply_button_style(_dialog_close_button, false)
	button_row.add_child(_dialog_close_button)

	_dialog_copy_button = Button.new()
	_dialog_copy_button.name = "CopyCrashReportButton"
	_dialog_copy_button.custom_minimum_size = Vector2(190, 40)
	_dialog_copy_button.pressed.connect(_on_copy_report_pressed)
	_apply_button_style(_dialog_copy_button, true)
	button_row.add_child(_dialog_copy_button)
	_dialog_root.visible = false


func _refresh_dialog_text() -> void:
	if _dialog_root == null:
		return
	_dialog_title.text = _text(
		"ui.crash_report.detected_title" if _dialog_uses_crash_intro else "ui.crash_report.title"
	)
	_dialog_message.text = _text(
		"ui.crash_report.detected_message" if _dialog_uses_crash_intro else "ui.crash_report.message"
	)
	_dialog_privacy_note.text = _text("ui.crash_report.privacy_note")
	_dialog_close_button.text = _text("ui.crash_report.close")
	_dialog_copy_button.text = _text("ui.crash_report.copy")


func _on_copy_report_pressed() -> void:
	if copy_latest_report():
		_dialog_status.text = _text("ui.crash_report.copied")
	else:
		_dialog_status.text = _text("ui.crash_report.none")


func _on_locale_changed(_locale: String) -> void:
	_refresh_dialog_text()


func _text(key: String) -> String:
	if _localization_manager != null and _localization_manager.has_method("text"):
		return str(_localization_manager.call("text", key))
	return key


func _panel_style(background: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_background := Color("#355ca0") if primary else Color("#142740")
	var hover_background := Color("#4775c6") if primary else Color("#203a5c")
	button.add_theme_stylebox_override("normal", _button_style(normal_background, UI_BORDER_SOFT))
	button.add_theme_stylebox_override("hover", _button_style(hover_background, UI_BORDER))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#263f70"), UI_ACCENT))
	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), UI_ACCENT, 2))
	button.add_theme_color_override("font_color", UI_TEXT)
	button.add_theme_color_override("font_hover_color", UI_TEXT)
	button.add_theme_color_override("font_pressed_color", UI_TEXT)


func _button_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := _panel_style(background, border, 8, width)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
