extends CanvasLayer

const MANIFEST_URL := "https://updates.pokeaether.com/manifest-android.json"
const WEBSITE_URL := "https://pokeaether.com"
const MAX_MANIFEST_BYTES := 1024 * 1024
const MAX_APK_BYTES := 1024 * 1024 * 1024
const DOWNLOAD_DIR := "user://downloads"

var manifest_url := MANIFEST_URL
var _release := {}
var _busy := false
var _install_path := ""
var _download: HTTPRequest
var _overlay: ColorRect
var _panel: PanelContainer
var _message: Label
var _progress: ProgressBar
var _primary: Button
var _website: Button


func _ready() -> void:
	# The update gate and its HTTP requests must keep running while gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		return
	layer = 110
	if OS.is_debug_build() and FileAccess.file_exists("user://android_apk_manifest_url.txt"):
		var local_url := FileAccess.get_file_as_string("user://android_apk_manifest_url.txt").strip_edges()
		if local_url.begins_with("http://127.0.0.1:") and local_url.ends_with("/manifest-android.json"):
			manifest_url = local_url
	_prune_installed_apks(int(ProjectSettings.get_setting("application/config/android_version_code", 1)))
	_build_panel()
	_check.call_deferred()


func _process(_delta: float) -> void:
	if _download == null or _release.is_empty():
		return
	var expected := int(_release.sizeBytes)
	var bytes := _download.get_downloaded_bytes()
	_progress.value = clampf(float(bytes) * 100.0 / float(expected), 0.0, 100.0)
	_message.text = _text("ui.android_update.downloading", {"percent": int(_progress.value)})


static func parse_release(manifest: Variant, current_code: int, allowed_origin := "https://updates.pokeaether.com") -> Dictionary:
	if not (manifest is Dictionary):
		return {}
	var game: Variant = manifest.get("game", {})
	if not (game is Dictionary):
		return {}
	var code: Variant = game.get("versionCode", 0)
	var size: Variant = game.get("sizeBytes", 0)
	if not (code is int or code is float) or not (size is int or size is float):
		return {}
	if float(int(code)) != float(code) or float(int(size)) != float(size):
		return {}
	if code <= current_code or code > 2147483647 or size <= 0 or size > MAX_APK_BYTES:
		return {}
	var build_id := str(game.get("buildId", ""))
	var version := str(game.get("version", ""))
	var sha := str(game.get("sha256", "")).to_lower()
	var url := str(game.get("url", ""))
	if build_id.is_empty() or build_id.length() > 120 or version.is_empty() or version.length() > 80:
		return {}
	if sha.length() != 64:
		return {}
	for character in sha:
		if not character in "0123456789abcdef":
			return {}
	if not url.begins_with(allowed_origin + "/game/") or not url.ends_with("-android.apk"):
		return {}
	if url.contains("?") or url.contains("#") or url.contains("\\") or url.contains(".."):
		return {}
	for character in url.trim_prefix(allowed_origin + "/game/"):
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.":
			return {}
	return {"versionCode": int(code), "version": version, "buildId": build_id, "sizeBytes": int(size), "sha256": sha, "url": url}


func _check() -> void:
	if _busy:
		return
	_busy = true
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	var started := request.request(manifest_url)
	if started != OK:
		request.queue_free()
		_busy = false
		return
	var completed: Array = await request.request_completed
	request.queue_free()
	_busy = false
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
		return
	var body := completed[3] as PackedByteArray
	if body.is_empty() or body.size() > MAX_MANIFEST_BYTES:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var origin := manifest_url.get_base_dir().trim_suffix("/")
	_release = parse_release(parsed, int(ProjectSettings.get_setting("application/config/android_version_code", 1)), origin)
	if _release.is_empty():
		return
	_show_required_update()


func _show_required_update() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	DisplayServer.virtual_keyboard_hide()
	get_tree().paused = true
	_message.text = _text("ui.android_update.required", {"version": _release.version, "mb": ceili(float(_release.sizeBytes) / 1048576.0)})
	_primary.text = _text("ui.android_update.download")
	_primary.disabled = false
	_overlay.show()


func _download_update() -> void:
	if _busy or _release.is_empty():
		return
	_busy = true
	_primary.disabled = true
	_progress.show()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOWNLOAD_DIR)) != OK:
		_fail(_text("ui.android_update.storage_failed"))
		return
	var path := DOWNLOAD_DIR.path_join("game-%d.apk" % int(_release.versionCode))
	if not _apk_matches(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var request := HTTPRequest.new()
		request.timeout = 300.0
		request.download_file = ProjectSettings.globalize_path(path)
		add_child(request)
		_download = request
		if request.request(str(_release.url)) != OK:
			_download = null
			request.queue_free()
			_fail(_text("ui.android_update.download_failed"))
			return
		var completed: Array = await request.request_completed
		_download = null
		request.queue_free()
		if completed.size() < 2 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_fail(_text("ui.android_update.download_failed"))
			return
	if not _apk_matches(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		_fail(_text("ui.android_update.verify_failed"))
		return
	_busy = false
	_progress.hide()
	_message.text = _text("ui.android_update.verified")
	_primary.text = _text("ui.android_update.install")
	_primary.disabled = false
	_install_path = path


func _apk_matches(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var length := file.get_length()
	file.close()
	return length == int(_release.sizeBytes) and FileAccess.get_sha256(path).to_lower() == str(_release.sha256)


func _prune_installed_apks(current_code: int) -> void:
	var directory := DirAccess.open(DOWNLOAD_DIR)
	if directory == null:
		return
	for filename in directory.get_files():
		if not filename.begins_with("game-") or not filename.ends_with(".apk"):
			continue
		var code_text := filename.trim_prefix("game-").trim_suffix(".apk")
		if code_text.is_valid_int() and int(code_text) <= current_code:
			directory.remove(filename)


func _install_update(path: String) -> void:
	if not _apk_matches(path):
		_fail(_text("ui.android_update.verify_failed"))
		return
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	if runtime == null:
		_fail(_text("ui.android_update.install_failed"))
		return
	var bridge = JavaClassWrapper.wrap("com.pokeaether.game.ApkInstallBridge")
	var result: int = bridge.install(runtime.getActivity(), ProjectSettings.globalize_path(path))
	if JavaClassWrapper.get_exception() != null or result < 0:
		_fail(_text("ui.android_update.install_failed"))
	elif result == 1:
		_message.text = _text("ui.android_update.permission")
	else:
		_message.text = _text("ui.android_update.confirm")


func _fail(message: String) -> void:
	_busy = false
	_install_path = ""
	_progress.hide()
	_message.text = message
	_primary.text = _text("ui.android_update.retry")
	_primary.disabled = false


func _on_primary_pressed() -> void:
	if _install_path.is_empty():
		_download_update()
	else:
		_install_update(_install_path)


func _text(key: String, values: Dictionary = {}) -> String:
	var manager := get_node_or_null("/root/LocalizationManager")
	return str(manager.call("text", key, values)) if manager != null else key


func _build_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.01, 0.02, 0.05, 0.82)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#070b14f8")
	style.border_color = Color("#507ec2e6")
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	style.shadow_color = Color("#382e9b6b")
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 8)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	var title := Label.new()
	title.text = _text("ui.android_update.title")
	title.add_theme_color_override("font_color", Color("#b9a0ff"))
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color("#f5f4ff"))
	_message.add_theme_font_size_override("font_size", 23)
	column.add_child(_message)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 26
	_progress.add_theme_stylebox_override("background", _button_style(Color("#111a2b"), Color("#2f4d71")))
	_progress.add_theme_stylebox_override("fill", _button_style(Color("#744fe0"), Color("#c9aaff")))
	_progress.hide()
	column.add_child(_progress)
	_primary = Button.new()
	_primary.custom_minimum_size.y = 54
	_style_button(_primary, true)
	_primary.pressed.connect(_on_primary_pressed)
	column.add_child(_primary)
	_website = Button.new()
	_website.custom_minimum_size.y = 54
	_style_button(_website, false)
	_website.text = _text("ui.android_update.website")
	_website.pressed.connect(func() -> void: OS.shell_open(WEBSITE_URL))
	column.add_child(_website)
	_overlay.hide()


func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("#f5f4ff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#8c91a3"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#744fe2") if primary else Color("#0c1424"), Color("#c49eff") if primary else Color("#385170")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#8c64fb") if primary else Color("#1a2340"), Color("#e0c7ff") if primary else Color("#a482ee")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#5034a2") if primary else Color("#080e19"), Color("#b696ff") if primary else Color("#6d57af")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#23243c"), Color("#46506c")))
	button.add_theme_stylebox_override("focus", _button_style(Color("#5034a2") if primary else Color("#101b2c"), Color("#ead6ff")))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style
