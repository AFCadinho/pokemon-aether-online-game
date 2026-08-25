extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		overlay_source.contains("root_control.theme = _make_main_ui_tooltip_theme()"),
		"Main UI installs one inherited hover card theme"
	)

	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	_check(overlay_script != null, "Main UI overlay script loads for tooltip theme checks")
	if overlay_script == null:
		quit(1)
		return

	var overlay: Node = overlay_script.new()
	var tooltip_theme := overlay.call("_make_main_ui_tooltip_theme") as Theme
	var main_ui_root := Control.new()
	var navigation_button := Button.new()
	main_ui_root.theme = tooltip_theme
	main_ui_root.add_child(navigation_button)
	_check(
		tooltip_theme != null
		and navigation_button.get_theme_stylebox("panel", "TooltipPanel") is StyleBoxFlat
		and navigation_button.get_theme_font_size("font_size", "TooltipLabel") == 12,
		"Main UI descendants resolve the shared styled hover card theme"
	)

	navigation_button.free()
	main_ui_root.free()
	overlay.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
