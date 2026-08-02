extends SceneTree

const PROJECT_CONFIG := "res://project.godot"
const CURSOR_MANAGER := "res://scripts/services/cursor_theme_manager.gd"
const ARROW_CURSOR := "res://assets/ui/cursors/aether_arrow.png"
const POINTER_CURSOR := "res://assets/ui/cursors/aether_pointer.png"

var failed := false


func _init() -> void:
	var project_text := _read_text(PROJECT_CONFIG)
	var manager_text := _read_text(CURSOR_MANAGER)
	_check(
		project_text.contains('CursorThemeManager="*res://scripts/services/cursor_theme_manager.gd"'),
		"cursor theme manager is globally autoloaded"
	)
	_check(FileAccess.file_exists(ARROW_CURSOR), "custom arrow cursor asset exists")
	_check(FileAccess.file_exists(POINTER_CURSOR), "custom pointer cursor asset exists")
	_check(
		manager_text.contains("Input.CURSOR_ARROW")
		and manager_text.contains("Input.CURSOR_POINTING_HAND"),
		"arrow and pointing-hand shapes receive custom cursors"
	)
	_check(
		manager_text.contains("load(ARROW_CURSOR_PATH)")
		and manager_text.contains("load(POINTER_CURSOR_PATH)"),
		"cursor assets load safely after Godot's import scan"
	)
	_check(
		manager_text.contains("ARROW_HOTSPOT")
		and manager_text.contains("POINTER_HOTSPOT"),
		"both cursors define explicit click hotspots"
	)
	_check(
		manager_text.contains("ARROW_HOTSPOT := Vector2(1, 1)"),
		"arrow hotspot matches its exact northwest tip"
	)
	quit(1 if failed else 0)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "can read %s" % path)
		return ""
	return file.get_as_text()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
