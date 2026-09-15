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
	_run.call_deferred()


func _run() -> void:
	_check_browser_view()
	await _check_browser_resize_runtime()
	_check(
		PixelPerfectRenderingScript.AVAILABLE_SCALES == [1.0, 1.5, 2.0],
		"settings expose only 1x, 1.5x, and 2x"
	)
	_check(PixelPerfectRenderingScript.validate_scale(-1) == 2.0, "invalid scale falls back to the 2x outdoor default")
	_check(
		PixelPerfectRenderingScript.default_scale_for_viewport(Vector2i(1600, 900)) == 1.25,
		"automatic desktop view scales continuously at 1600x900"
	)
	_check(
		PixelPerfectRenderingScript.default_scale_for_viewport(Vector2i(1920, 1080)) == 1.5,
		"Full HD automatic view uses 1.5x for the reference world view"
	)
	_check(
		PixelPerfectRenderingScript.default_scale_for_viewport(Vector2i(1920, 900)) == 1.25,
		"short ultrawide viewports add horizontal world"
	)
	var settings_manager := root.get_node_or_null("SettingsManager")
	_check(settings_manager != null, "automatic outdoor zoom can access settings")
	if settings_manager == null:
		quit(1)
		return
	var original_mode: Variant = settings_manager.get("world_pixel_scale_mode")
	var original_scale: Variant = settings_manager.get("world_pixel_scale")
	settings_manager.set("world_pixel_scale_mode", "auto")
	_check(
		settings_manager.call("get_effective_world_pixel_scale", Vector2i(1600, 900)) == 1.25
		and settings_manager.call("get_effective_world_pixel_scale", Vector2i(1920, 1080)) == 1.5
		and settings_manager.call("get_effective_world_pixel_scale", Vector2i(3840, 2160)) == 3.0,
		"automatic outdoor zoom follows the current viewport size"
	)
	settings_manager.set("world_pixel_scale_mode", "fixed")
	settings_manager.set("world_pixel_scale", 1.5)
	_check(
		settings_manager.call("get_effective_world_pixel_scale", Vector2i(1920, 1080)) == 1.5,
		"a fixed outdoor zoom overrides automatic viewport sizing"
	)
	settings_manager.set("world_pixel_scale_mode", original_mode)
	settings_manager.set("world_pixel_scale", original_scale)
	_check(PixelPerfectRenderingScript.resolve_scale(1.0, Vector2i(1920, 1080)) == 1.0, "explicit 1x remains exact")
	_check(PixelPerfectRenderingScript.resolve_scale(1.5, Vector2i(1280, 720)) == 1.5, "explicit 1.5x remains exact")
	_check(PixelPerfectRenderingScript.resolve_scale(2.0, Vector2i(1920, 1080)) == 2.0, "explicit 2x remains exact")
	_check(
		PixelPerfectRenderingScript.resolve_world_scale_for_area(1.0, "interior") == 1.5,
		"building interiors always use fixed 1.5x zoom"
	)
	_check(
		PixelPerfectRenderingScript.resolve_world_scale_for_area(2.0, "exterior") == 2.0
		and PixelPerfectRenderingScript.resolve_world_scale_for_area(1.0, "cave") == 1.0,
		"non-interior maps preserve the configured outdoor zoom"
	)
	_check(PixelPerfectRenderingScript.validate_scale(0) == 2.0, "legacy automatic scale migrates to the 2x outdoor default")
	_check(PixelPerfectRenderingScript.validate_scale(3) == 2.0, "legacy 3x scale migrates to the 2x outdoor default")
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
		and settings_text.contains('"world_pixel_scale_mode": world_pixel_scale_mode')
		and settings_text.contains("func set_world_pixel_scale_auto()")
		and settings_text.contains("func is_world_pixel_scale_auto()")
		and settings_text.contains("PixelPerfectRendering.default_scale_for_viewport")
		and settings_text.contains("func set_world_pixel_scale(value: float)"),
		"outdoor world zoom supports persistent automatic and fixed modes"
	)
	_check(
		menu_text.contains("WorldPixelScaleOptionsButton")
		and menu_text.contains("SettingsManager.set_world_pixel_scale_auto")
		and menu_text.contains("SettingsManager.set_world_pixel_scale")
		and menu_text.contains('"ui.settings.world_pixel_scale_auto"')
		and menu_text.contains('"ui.settings.world_pixel_scale_overview"')
		and menu_text.contains('"ui.settings.world_pixel_scale_balanced"')
		and menu_text.contains('"ui.settings.world_pixel_scale_close"'),
		"graphics settings expose world pixel scale choices"
	)
	_check(
		player_text.contains("SettingsManager.world_pixel_scale_changed.connect")
		and player_text.contains("var window := get_window()")
		and player_text.contains("var viewport := world_camera.get_viewport()")
		and player_text.contains("if window == null or viewport == null:")
		and player_text.contains("SettingsManager.get_effective_world_pixel_scale(window_size)")
		and player_text.contains("resolve_player_output_scale")
		and player_text.contains("_get_current_map_world_access_area_type")
		and player_text.contains("apply_camera_baseline_zoom")
		and player_text.contains("PixelPerfectRenderingScript.apply_output_scale_to_camera"),
		"player camera applies map scaling safely during teardown without overwriting active Photo Mode zoom"
	)
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var detached_player := player_scene.instantiate() if player_scene != null else null
	var detached_camera := (
		detached_player.get_node_or_null("Camera2D") as Camera2D
		if detached_player != null
		else null
	)
	_check(detached_player != null and detached_camera != null, "player teardown regression fixture loads")
	if detached_player != null and detached_camera != null:
		detached_camera.zoom = Vector2(1.23, 1.23)
		detached_player.set("world_camera", detached_camera)
		detached_player.call("_apply_world_pixel_scale")
		_check(
			detached_camera.zoom.is_equal_approx(Vector2(1.23, 1.23)),
			"a player detached from every Window safely skips world zoom restoration"
		)
		detached_player.free()
	_check(_read_text(PLAYER_SCENE).contains("zoom = Vector2(1, 1)"), "generic player camera stays neutral before the map zoom is applied")
	_check(_read_text(WORLD_SCENE).contains("texture_filter = 1"), "overworld uses nearest texture filtering")
	for locale_path: String in ["res://localization/en.json", "res://localization/nl.json", "res://localization/pt_BR.json", "res://localization/zh_CN.json"]:
		var locale_text := _read_text(locale_path)
		_check(
			locale_text.contains('"ui.settings.world_pixel_scale"')
			and locale_text.contains('"ui.settings.world_pixel_scale_auto"')
			and locale_text.contains('"ui.settings.world_pixel_scale_overview"')
			and locale_text.contains('"ui.settings.world_pixel_scale_balanced"')
			and locale_text.contains('"ui.settings.world_pixel_scale_close"')
			and locale_text.contains('"ui.settings.world_pixel_scale_hint"'),
			"%s contains pixel scale translations" % locale_path
		)
	quit(1 if failed else 0)


func _check_browser_view() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(960, 540)]:
		var scale := PixelPerfectRenderingScript.resolve_player_output_scale(2.0, size, "exterior", true)
		_check(is_equal_approx(scale, PixelPerfectRenderingScript.resolve_player_output_scale(2.0, size, "exterior", false, true)), "Automatic desktop matches browser outdoors at %s" % size)
		_check(is_equal_approx(scale, PixelPerfectRenderingScript.resolve_player_output_scale(1.0, size, "interior", false, true)), "Automatic desktop matches browser indoors at %s" % size)
		_check((Vector2(size) / scale).is_equal_approx(Vector2(1280, 720)), "Browser keeps the same world view at %s" % size)
		_check(is_equal_approx(scale, PixelPerfectRenderingScript.resolve_player_output_scale(1.0, size, "interior", true)), "Browser ignores personal/indoor zoom at %s" % size)
	var wide := Vector2i(2560, 1080)
	var wide_view := Vector2(wide) / PixelPerfectRenderingScript.browser_output_scale(wide)
	_check(wide_view.x > 1280 and is_equal_approx(wide_view.y, 720), "Ultrawide browser adds horizontal world without bars")
	var tall := Vector2i(720, 1280)
	var tall_view := Vector2(tall) / PixelPerfectRenderingScript.browser_output_scale(tall)
	_check(is_equal_approx(tall_view.x, 1280) and tall_view.y > 720, "Tall browser adds vertical world without bars")
	_check(PixelPerfectRenderingScript.browser_output_scale(Vector2i.ZERO) > 0, "Transient zero-size browser resize stays safe")
	_check(PixelPerfectRenderingScript.resolve_player_output_scale(2.0, Vector2i(3840, 2160), "exterior", false) == 2.0, "Desktop retains configured outdoor zoom")
	_check(PixelPerfectRenderingScript.resolve_player_output_scale(1.0, Vector2i(1280, 720), "interior", false) == 1.5, "Desktop retains indoor zoom")
	var camera := Camera2D.new()
	root.add_child(camera)
	var scale := PixelPerfectRenderingScript.browser_output_scale(Vector2i(3840, 2160))
	PixelPerfectRenderingScript.apply_output_scale_to_camera(camera, scale)
	_check(camera.zoom.is_equal_approx(PixelPerfectRenderingScript.camera_zoom_for_output_scale(3.0, root.get_screen_transform().get_scale())), "4K browser scale is not clamped to desktop preset values")
	camera.free()
	_check(_read_text("res://scripts/core/window_fit.gd").contains("Window.CONTENT_SCALE_ASPECT_EXPAND"), "Browser uses full-canvas aspect expansion")


func _check_browser_resize_runtime() -> void:
	var original_size := root.size
	var original_aspect := root.content_scale_aspect
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var camera := Camera2D.new()
	root.add_child(camera)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(2560, 1080)]:
		root.size = size
		await process_frame
		await process_frame
		PixelPerfectRenderingScript.apply_output_scale_to_camera(camera, PixelPerfectRenderingScript.browser_output_scale(root.size))
		var world_view := root.get_visible_rect().size / camera.zoom
		var expected := Vector2(root.size) / PixelPerfectRenderingScript.browser_output_scale(root.size)
		_check(world_view.is_equal_approx(expected), "Actual expanded viewport/camera keeps expected world view after resize to %s" % size)
		_check(root.get_screen_transform().get_scale().x == root.get_screen_transform().get_scale().y, "Resize preserves uniform pixels and UI scaling at %s" % size)
	camera.free()
	root.content_scale_aspect = original_aspect
	root.size = original_size
	await process_frame


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
