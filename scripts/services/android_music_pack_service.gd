extends CanvasLayer

signal music_ready

const MANIFEST_URL := "https://updates.pokeaether.com/manifest.json"
const MUSIC_ROOT := "res://assets/music/"
const USER_MUSIC_ROOT := "user://assets/music/"
const STATE_PATH := "user://asset_versions.json"
const MAX_MANIFEST_BYTES := 1024 * 1024
const MAX_ARCHIVE_BYTES := 256 * 1024 * 1024
const MAX_EXTRACTED_BYTES := 384 * 1024 * 1024
const MAX_TRACK_BYTES := 32 * 1024 * 1024
const MAX_TRACK_COUNT := 128
const REQUIRED_TRACKS := [
	"login/lugia_theme_lofi.ogg",
	"overworld/kanto/routes/route1.ogg",
	"battle/wild/Kanto Wild Battle.ogg",
	"battle/trainer/Kalos Trainer Battle.ogg",
]

var manifest_url := MANIFEST_URL
var active_version := ""
var _busy := false
var _active_download: HTTPRequest
var _expected_bytes := 0
var _status_panel: PanelContainer
var _status_label: Label
var _progress_bar: ProgressBar
var _retry_button: Button
var _status_generation := 0


func _ready() -> void:
	if not OS.has_feature("mobile"):
		return
	layer = 95
	if OS.is_debug_build() and FileAccess.file_exists("user://android_music_manifest_url.txt"):
		var debug_url := FileAccess.get_file_as_string("user://android_music_manifest_url.txt").strip_edges()
		if debug_url.begins_with("http://127.0.0.1:") and debug_url.ends_with("/manifest.json"):
			manifest_url = debug_url
	active_version = _read_installed_version()
	if active_version != "":
		# A replaced pack can still be playing until the app exits. Remove old
		# versions on the next launch, before MusicManager starts playback.
		_prune_old_music_versions(USER_MUSIC_ROOT, active_version)
	_build_status_ui()
	_refresh.call_deferred()


func _process(_delta: float) -> void:
	if _active_download == null or _expected_bytes <= 0:
		return
	var downloaded := _active_download.get_downloaded_bytes()
	_progress_bar.value = clampf(float(downloaded) / float(_expected_bytes) * 100.0, 0.0, 100.0)
	_status_label.text = "Downloading music · %d%%" % int(_progress_bar.value)


func resolve_track_path(track_path: String) -> String:
	if active_version == "" or not track_path.begins_with(MUSIC_ROOT):
		return ""
	var relative_path := track_path.trim_prefix(MUSIC_ROOT)
	if not _safe_relative_track_path(relative_path):
		return ""
	var installed_path := USER_MUSIC_ROOT.path_join(active_version).path_join(relative_path)
	return installed_path if FileAccess.file_exists(installed_path) else ""


func _refresh() -> void:
	if _busy:
		return
	_busy = true
	if active_version == "":
		_show_status("Checking game music…", -1.0, false)
	var descriptor := await _fetch_music_descriptor()
	if descriptor.is_empty():
		_finish_failure("Could not check game music. Check your connection.")
		return
	var version := str(descriptor["version"])
	if version == active_version and _installed_pack_is_valid(version):
		_busy = false
		_hide_status()
		return
	var archive_path := "user://downloads/%s.zip.part" % version
	var expected_sha := str(descriptor["sha256"])
	var expected_size := int(descriptor["sizeBytes"])
	if not _archive_matches(archive_path, expected_size, expected_sha):
		_remove_file(archive_path)
		if not await _download_archive(str(descriptor["url"]), archive_path, expected_size):
			_finish_failure("Music download failed. Please retry.")
			return
	if not _archive_matches(archive_path, expected_size, expected_sha):
		_remove_file(archive_path)
		_finish_failure("Music download failed verification. Please retry.")
		return
	_show_status("Installing game music…", 100.0, false)
	if not _install_archive(archive_path, version):
		_finish_failure("Music installation failed. Please retry.")
		return
	if not _write_installed_version(version):
		_finish_failure("Could not save the music version. Please retry.")
		return
	active_version = version
	_remove_file(archive_path)
	_busy = false
	music_ready.emit()
	_show_status("Music ready", 100.0, false)
	_hide_status_after_delay.call_deferred(_status_generation)


func _fetch_music_descriptor() -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	var started := request.request(manifest_url)
	if started != OK:
		request.queue_free()
		return {}
	var completed: Array = await request.request_completed
	request.queue_free()
	if completed.size() < 4 or int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
		return {}
	var body := completed[3] as PackedByteArray
	if body.is_empty() or body.size() > MAX_MANIFEST_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	var packs: Variant = (parsed as Dictionary).get("assetPacks", [])
	if not (packs is Array):
		return {}
	for entry: Variant in packs:
		if entry is Dictionary and str(entry.get("id", "")) == "music":
			return entry if _valid_descriptor(entry) else {}
	return {}


func _valid_descriptor(descriptor: Dictionary) -> bool:
	var version := str(descriptor.get("version", ""))
	var sha := str(descriptor.get("sha256", "")).to_lower()
	var size := int(descriptor.get("sizeBytes", 0))
	if not _safe_version(version):
		return false
	if sha.length() != 64:
		return false
	for character in sha:
		if not character in "0123456789abcdef":
			return false
	if size <= 0 or size > MAX_ARCHIVE_BYTES:
		return false
	return str(descriptor.get("url", "")) == "%s/assets/%s.zip" % [manifest_url.get_base_dir(), version]


func _safe_version(version: String) -> bool:
	if not version.begins_with("music-") or version.length() > 80:
		return false
	for character in version:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			return false
	return true


func _download_archive(url: String, archive_path: String, size_bytes: int) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://downloads")) != OK:
		return false
	var request := HTTPRequest.new()
	request.timeout = 180.0
	request.download_file = ProjectSettings.globalize_path(archive_path)
	add_child(request)
	_expected_bytes = size_bytes
	_active_download = request
	_show_status("Downloading music · 0%", 0.0, false)
	var started := request.request(url)
	if started != OK:
		_active_download = null
		request.queue_free()
		return false
	var completed: Array = await request.request_completed
	_active_download = null
	request.queue_free()
	return completed.size() >= 2 and int(completed[0]) == HTTPRequest.RESULT_SUCCESS and int(completed[1]) == 200


func _archive_matches(archive_path: String, size_bytes: int, sha256: String) -> bool:
	var file := FileAccess.open(archive_path, FileAccess.READ)
	if file == null:
		return false
	var actual_size := file.get_length()
	file.close()
	return actual_size == size_bytes and FileAccess.get_sha256(archive_path).to_lower() == sha256.to_lower()


func _install_archive(archive_path: String, version: String) -> bool:
	if not _safe_version(version):
		return false
	var staging_path := "user://staging/%s" % version
	var target_path := USER_MUSIC_ROOT.path_join(version)
	_remove_tree(staging_path)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(staging_path)) != OK:
		return false
	var zip := ZIPReader.new()
	if zip.open(ProjectSettings.globalize_path(archive_path)) != OK:
		_remove_tree(staging_path)
		return false
	var paths := zip.get_files()
	var track_count := 0
	var extracted_bytes := 0
	var valid := true
	var seen_paths := {}
	for archive_path_value in paths:
		var entry_path := str(archive_path_value)
		if not _safe_archive_entry(entry_path):
			valid = false
			break
		if entry_path.ends_with("/"):
			continue
		if seen_paths.has(entry_path):
			valid = false
			break
		seen_paths[entry_path] = true
		var relative_path := entry_path.trim_prefix("assets/music/")
		track_count += 1
		if track_count > MAX_TRACK_COUNT:
			valid = false
			break
		var bytes := zip.read_file(entry_path)
		extracted_bytes += bytes.size()
		if bytes.is_empty() or bytes.size() > MAX_TRACK_BYTES or extracted_bytes > MAX_EXTRACTED_BYTES:
			valid = false
			break
		var target_file := staging_path.path_join(relative_path)
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_file.get_base_dir())) != OK:
			valid = false
			break
		var file := FileAccess.open(target_file, FileAccess.WRITE)
		if file == null:
			valid = false
			break
		file.store_buffer(bytes)
		file.flush()
		file.close()
	zip.close()
	if not valid or track_count == 0 or not _required_tracks_exist(staging_path):
		_remove_tree(staging_path)
		return false
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_path)):
		if target_path == USER_MUSIC_ROOT.path_join(active_version):
			_remove_tree(staging_path)
			return false
		_remove_tree(target_path)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_MUSIC_ROOT)) != OK:
		_remove_tree(staging_path)
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(staging_path), ProjectSettings.globalize_path(target_path)) != OK:
		_remove_tree(staging_path)
		return false
	return true


func _safe_relative_track_path(relative_path: String) -> bool:
	if relative_path == "" or not relative_path.ends_with(".ogg") or "\\" in relative_path or ":" in relative_path:
		return false
	for component in relative_path.split("/"):
		if component == "" or component == "." or component == "..":
			return false
	return true


func _safe_archive_entry(entry_path: String) -> bool:
	if entry_path == "assets/" or entry_path == "assets/music/":
		return true
	if not entry_path.begins_with("assets/music/") or "\\" in entry_path or ":" in entry_path:
		return false
	var relative_path := entry_path.trim_prefix("assets/music/")
	if entry_path.ends_with("/"):
		relative_path = relative_path.trim_suffix("/")
		if relative_path == "":
			return false
		for component in relative_path.split("/"):
			if component == "" or component == "." or component == "..":
				return false
		return true
	return _safe_relative_track_path(relative_path)


func _required_tracks_exist(root_path: String) -> bool:
	for relative_path in REQUIRED_TRACKS:
		if not FileAccess.file_exists(root_path.path_join(relative_path)):
			return false
	return true


func _installed_pack_is_valid(version: String) -> bool:
	return version != "" and _required_tracks_exist(USER_MUSIC_ROOT.path_join(version))


func _read_installed_version() -> String:
	if not FileAccess.file_exists(STATE_PATH):
		return ""
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if not (state is Dictionary):
		return ""
	var music: Variant = (state as Dictionary).get("music", {})
	if not (music is Dictionary):
		return ""
	var version := str((music as Dictionary).get("version", ""))
	return version if _safe_version(version) and _installed_pack_is_valid(version) else ""


func _write_installed_version(version: String) -> bool:
	if not _safe_version(version) or not _installed_pack_is_valid(version):
		return false
	var state := {}
	if FileAccess.file_exists(STATE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
		if parsed is Dictionary:
			state = parsed
	state["music"] = {"version": version}
	var temp_path := STATE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(STATE_PATH)) == OK


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		var child_path := path.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child_path)
		else:
			_remove_file(child_path)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _prune_old_music_versions(music_root: String, current_version: String) -> void:
	if not _safe_version(current_version):
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(music_root.path_join(current_version))):
		return
	for directory_name: String in DirAccess.get_directories_at(music_root):
		if directory_name != current_version and _safe_version(directory_name):
			_remove_tree(music_root.path_join(directory_name))


func _finish_failure(message: String) -> void:
	_busy = false
	if active_version == "":
		_show_status(message, -1.0, true)
	else:
		_hide_status()


func _build_status_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_status_panel = PanelContainer.new()
	_status_panel.visible = false
	_status_panel.anchor_left = 0.5
	_status_panel.anchor_right = 0.5
	_status_panel.offset_left = -195.0
	_status_panel.offset_right = 195.0
	_status_panel.offset_top = 140.0
	_status_panel.offset_bottom = 206.0
	_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.095, 0.95)
	style.border_color = Color(0.25, 0.55, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	_status_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_status_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_status_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	column.add_child(_progress_bar)
	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.pressed.connect(_refresh)
	column.add_child(_retry_button)


func _show_status(message: String, progress: float, can_retry: bool) -> void:
	_status_generation += 1
	_status_panel.visible = true
	_status_label.text = message
	_progress_bar.visible = progress >= 0.0
	_progress_bar.value = maxf(progress, 0.0)
	_retry_button.visible = can_retry


func _hide_status() -> void:
	_status_generation += 1
	_status_panel.visible = false


func _hide_status_after_delay(generation: int) -> void:
	await get_tree().create_timer(1.5).timeout
	if generation == _status_generation:
		_hide_status()
