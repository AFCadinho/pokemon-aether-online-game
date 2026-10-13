extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var existed := FileAccess.file_exists(settings.SETTINGS_PATH)
	var saved := FileAccess.get_file_as_string(settings.SETTINGS_PATH) if existed else ""
	var profile: Dictionary = JSON.parse_string(saved) if existed else {}
	profile.erase("android_3d_move_camera")
	profile.battle_3d_camera_motion = false
	_write(settings.SETTINGS_PATH, JSON.stringify(profile))
	settings.load_settings()
	_check(settings.android_3d_move_camera and not settings.battle_3d_camera_motion,
		"existing static-camera profiles gain Android move shots without idle motion")
	var menu: Control = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var graphics: Control = menu.find_child("GraphicsContent", true, false)
	if menu.android_move_camera_toggle == null:
		menu._create_android_move_camera_toggle(graphics)
	menu._apply_settings_to_controls()
	var toggle: CheckBox = menu.android_move_camera_toggle
	_check(toggle.button_pressed and graphics.is_ancestor_of(toggle), "Android switch belongs to Graphics and starts enabled")
	toggle.button_pressed = false
	settings.android_3d_move_camera = true
	settings.load_settings()
	_check(not settings.android_3d_move_camera and not settings.battle_3d_camera_motion, "explicit disable survives reload independently of idle motion")
	menu._apply_settings_to_controls()
	_check(not toggle.button_pressed, "reopened controls reflect the saved disable")
	toggle.button_pressed = true
	settings.android_3d_move_camera = false
	settings.load_settings()
	_check(settings.android_3d_move_camera and not settings.battle_3d_camera_motion, "switch can re-enable only move shots")
	menu.queue_free()
	await process_frame
	if existed:
		_write(settings.SETTINGS_PATH, saved)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
	settings.load_settings()
	print("ANDROID_MOVE_CAMERA_SETTINGS_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
