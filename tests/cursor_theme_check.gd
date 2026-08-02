extends SceneTree

const PROJECT_CONFIG := "res://project.godot"
const CURSOR_MANAGER := "res://scripts/services/cursor_theme_manager.gd"
const SETTINGS_MANAGER := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU := "res://scripts/ui/settings_menu.gd"
const ARROW_CURSOR := "res://assets/ui/cursors/aether_arrow.png"
const POINTER_CURSOR := "res://assets/ui/cursors/aether_pointer.png"

var failed := false


func _init() -> void:
	var project_text := _read_text(PROJECT_CONFIG)
	var manager_text := _read_text(CURSOR_MANAGER)
	var settings_text := _read_text(SETTINGS_MANAGER)
	var menu_text := _read_text(SETTINGS_MENU)
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
	_check(
		manager_text.contains("POINTER_HOTSPOT := Vector2(1, 1)"),
		"hover cursor keeps the same northwest click hotspot"
	)
	_check(
		manager_text.contains("DEFAULT_CURSOR_SCALE := 75.0")
		and manager_text.contains("func set_cursor_scale(value: float)")
		and manager_text.contains("Image.INTERPOLATE_LANCZOS"),
		"cursor theme scales both high-quality cursor textures from a smaller default"
	)
	_check(
		settings_text.contains('"cursor_scale": cursor_scale')
		and settings_text.contains("CursorThemeManager.set_cursor_scale(cursor_scale)"),
		"cursor scale persists and applies immediately"
	)
	_check(
		menu_text.contains("func _create_cursor_scale_control()")
		and menu_text.contains("SettingsManager.set_cursor_scale(value)"),
		"graphics settings expose the cursor scale control"
	)
	var cursor_manager := (load(CURSOR_MANAGER) as Script).new() as Node
	cursor_manager.set("cursor_scale", 75.0)
	var scaled_arrow := cursor_manager.call(
		"_scaled_cursor",
		load(ARROW_CURSOR) as Texture2D
	) as ImageTexture
	_check(
		scaled_arrow != null
		and scaled_arrow.get_width() == 30
		and scaled_arrow.get_height() == 30,
		"75 percent cursor setting renders the 40 pixel arrow at 30 pixels"
	)
	cursor_manager.free()
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
