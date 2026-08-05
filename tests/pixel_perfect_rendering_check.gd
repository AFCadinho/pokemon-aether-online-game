extends SceneTree

const PixelPerfectRenderingScript := preload("res://scripts/services/pixel_perfect_rendering.gd")
const PROJECT_CONFIG := "res://project.godot"
const SETTINGS_MANAGER := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU := "res://scripts/ui/settings_menu.gd"
const PLAYER_SCRIPT := "res://scripts/world/player.gd"
const PLAYER_SCENE := "res://scenes/player.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"

var failed := false


func _init() -> void:
	_check(
		PixelPerfectRenderingScript.AVAILABLE_SCALES == [1.0, 1.5, 2.0],
		"settings expose only 1x, 1.5x, and 2x"
	)
	_check(PixelPerfectRenderingScript.validate_scale(-1) == 1.0, "invalid scale falls back to 1x")
	_check(PixelPerfectRenderingScript.resolve_scale(1.0, Vector2i(1920, 1080)) == 1.0, "explicit 1x remains exact")
	_check(PixelPerfectRenderingScript.resolve_scale(1.5, Vector2i(1280, 720)) == 1.5, "explicit 1.5x remains exact")
	_check(PixelPerfectRenderingScript.resolve_scale(2.0, Vector2i(1920, 1080)) == 2.0, "explicit 2x remains exact")
	_check(PixelPerfectRenderingScript.validate_scale(0) == 1.0, "legacy automatic scale migrates to 1x")
	_check(PixelPerfectRenderingScript.validate_scale(3) == 1.0, "legacy 3x scale migrates to 1x")
	_check(
		PixelPerfectRenderingScript.camera_zoom_for_output_scale(1.5, Vector2(5.0 / 6.0, 5.0 / 6.0)).is_equal_approx(Vector2(1.8, 1.8)),
		"balanced camera zoom compensates for 1920-to-1600 canvas stretch"
	)

	var project_text := _read_text(PROJECT_CONFIG)
	var settings_text := _read_text(SETTINGS_MANAGER)
	var menu_text := _read_text(SETTINGS_MENU)
	var player_text := _read_text(PLAYER_SCRIPT)
	_check(
		project_text.contains("2d/snap/snap_2d_transforms_to_pixel=true")
		and project_text.contains("2d/snap/snap_2d_vertices_to_pixel=true"),
		"project enables 2D pixel snapping"
	)
	_check(
		settings_text.contains("DEFAULT_WORLD_PIXEL_SCALE := PixelPerfectRendering.DEFAULT_SCALE")
		and settings_text.contains('"world_pixel_scale": world_pixel_scale')
		and settings_text.contains("func set_world_pixel_scale(value: float)"),
		"world zoom defaults to 1x and persists"
	)
	_check(
		menu_text.contains("WorldPixelScaleOptionsButton")
		and menu_text.contains("SettingsManager.set_world_pixel_scale")
		and menu_text.contains('"ui.settings.world_pixel_scale_overview"')
		and menu_text.contains('"ui.settings.world_pixel_scale_balanced"')
		and menu_text.contains('"ui.settings.world_pixel_scale_close"'),
		"graphics settings expose world pixel scale choices"
	)
	_check(
		player_text.contains("SettingsManager.world_pixel_scale_changed.connect")
		and player_text.contains("PixelPerfectRenderingScript.apply_to_camera"),
		"player camera follows dedicated pixel scale changes"
	)
	_check(_read_text(PLAYER_SCENE).contains("zoom = Vector2(1, 1)"), "player camera scene defaults to 1x")
	_check(_read_text(WORLD_SCENE).contains("texture_filter = 1"), "overworld uses nearest texture filtering")
	for locale_path: String in ["res://localization/en.json", "res://localization/nl.json", "res://localization/pt_BR.json"]:
		var locale_text := _read_text(locale_path)
		_check(
			locale_text.contains('"ui.settings.world_pixel_scale"')
			and locale_text.contains('"ui.settings.world_pixel_scale_overview"')
			and locale_text.contains('"ui.settings.world_pixel_scale_balanced"')
			and locale_text.contains('"ui.settings.world_pixel_scale_close"')
			and locale_text.contains('"ui.settings.world_pixel_scale_hint"'),
			"%s contains pixel scale translations" % locale_path
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
