extends Control

const DEFAULT_MANIFEST_URL := "https://example.com/pokemon-aether/manifest.json"
const LAUNCHER_CONFIG_FILE := "res://config/launcher_config.json"
const INSTALL_DIR := "user://game"
const VERSION_FILE := "user://versions.json"
const TEMP_DIR := "user://downloads"
const EXTRACT_PROGRESS_BATCH_SIZE := 25

@onready var version_label: Label = $Panel/MarginContainer/Layout/VersionLabel
@onready var status_label: Label = $Panel/MarginContainer/Layout/StatusLabel
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/Layout/ProgressBar
@onready var log_label: RichTextLabel = $Panel/MarginContainer/Layout/LogLabel
@onready var check_button: Button = $Panel/MarginContainer/Layout/ButtonRow/CheckButton
@onready var update_button: Button = $Panel/MarginContainer/Layout/ButtonRow/UpdateButton
@onready var play_button: Button = $Panel/MarginContainer/Layout/ButtonRow/PlayButton
@onready var http_request: HTTPRequest = $HttpRequest

var manifest: Dictionary = {}
var local_versions: Dictionary = {}
var pending_downloads: Array[Dictionary] = []
var current_download: Dictionary = {}
var update_required := false
var manifest_url := DEFAULT_MANIFEST_URL


func _ready() -> void:
	_load_launcher_config()
	check_button.pressed.connect(check_for_updates)
	update_button.pressed.connect(start_update)
	play_button.pressed.connect(launch_game)
	http_request.request_completed.connect(_on_request_completed)
	_load_local_versions()
	_refresh_status()


func _process(_delta: float) -> void:
	if http_request.get_http_client_status() == HTTPClient.STATUS_BODY:
		var downloaded_bytes: int = http_request.get_downloaded_bytes()
		var expected_bytes: int = 0
		if not current_download.is_empty():
			expected_bytes = int(current_download.get("size_bytes", 0))

		var total_bytes: int = expected_bytes
		if total_bytes <= 0:
			total_bytes = http_request.get_body_size()

		if total_bytes > 0:
			var visible_downloaded_bytes: int = mini(downloaded_bytes, total_bytes)
			var percent: float = minf((float(downloaded_bytes) / float(total_bytes)) * 100.0, 99.0)
			progress_bar.value = percent
			if not current_download.is_empty():
				_set_status(
					"Downloading %s... %s / %s (%d%%)" % [
						str(current_download.get("label", "download")),
						_format_bytes(visible_downloaded_bytes),
						_format_bytes(total_bytes),
						int(percent),
					]
				)
		elif not current_download.is_empty():
			progress_bar.value = 0.0
			_set_status(
				"Downloading %s... %s" % [
					str(current_download.get("label", "download")),
					_format_bytes(downloaded_bytes),
				]
			)


func check_for_updates() -> void:
	_set_busy(true)
	_set_status("Checking for updates...")
	_log("Checking for updates.")
	http_request.download_file = ""
	var error_code: Error = http_request.request(manifest_url)
	if error_code != OK:
		_set_busy(false)
		_set_status("Could not request manifest.")
		_log_error("Manifest request failed: %s" % error_string(error_code))


func start_update() -> void:
	if manifest.is_empty():
		check_for_updates()
		return

	_build_download_queue()
	if pending_downloads.is_empty():
		update_required = false
		_set_status("Already up to date.")
		_refresh_status()
		return

	_set_busy(true)
	update_button.disabled = true
	play_button.disabled = true
	_start_next_download()


func launch_game() -> void:
	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var executable_path := str(game_data.get("executable", local_versions.get("gameExecutable", "")))
	if executable_path.is_empty():
		if OS.get_name() == "Windows":
			executable_path = "Pokemon Aether Online.exe"
		else:
			executable_path = "Pokemon Aether Online.x86_64"

	var absolute_executable_path := ProjectSettings.globalize_path(INSTALL_DIR.path_join(executable_path))

	if not FileAccess.file_exists(absolute_executable_path):
		_set_status("Game executable not found. Run update first.")
		_log_error("Missing executable: %s" % absolute_executable_path)
		return

	var permission_error: Error = _ensure_executable_permissions(absolute_executable_path)
	if permission_error != OK:
		_set_status("Could not prepare game executable.")
		_log_error("Could not set executable permissions: %s" % error_string(permission_error))
		return

	_log("Starting game.")
	var process_id: int = _create_game_process(absolute_executable_path)
	if process_id <= 0:
		_set_status("Could not start game.")
		_log_error("OS.create_process failed.")
		return

	print("Started game process id: %s" % process_id)


func _create_game_process(absolute_executable_path: String) -> int:
	var game_dir: String = absolute_executable_path.get_base_dir()
	var executable_name: String = absolute_executable_path.get_file()
	var os_name: String = OS.get_name()
	if os_name == "Windows":
		var command: String = "cd /D %s && %s" % [
			_quote_windows_shell(game_dir),
			_quote_windows_shell(executable_name),
		]
		return OS.create_process("cmd.exe", PackedStringArray(["/C", command]))

	if os_name == "Linux" or os_name == "macOS" or os_name == "FreeBSD" or os_name == "NetBSD" or os_name == "OpenBSD" or os_name == "BSD":
		var command: String = "cd \"$1\" && exec \"./$2\""
		return OS.create_process("/bin/sh", PackedStringArray(["-c", command, "pokemon-aether-launcher", game_dir, executable_name]))

	return OS.create_process(absolute_executable_path, PackedStringArray())


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	progress_bar.value = 100.0
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_busy(false)
		_set_status("Download failed.")
		_log_error("Request failed. result=%s status=%s" % [result, response_code])
		return

	if current_download.is_empty():
		_handle_manifest_response(body)
	else:
		_handle_download_response()


func _handle_manifest_response(body: PackedByteArray) -> void:
	var manifest_text := body.get_string_from_utf8()
	var parsed_json: Variant = JSON.parse_string(manifest_text)
	if typeof(parsed_json) != TYPE_DICTIONARY:
		_set_busy(false)
		_set_status("Manifest is invalid.")
		_log_error("Manifest JSON must be an object.")
		return

	manifest = parsed_json
	_build_download_queue()
	update_required = not pending_downloads.is_empty()
	_set_busy(false)
	_refresh_status()

	if update_required:
		_log("Update available.")
	else:
		_log("Everything is up to date.")


func _handle_download_response() -> void:
	var file_path := str(current_download.get("file_path", ""))
	var sha256 := str(current_download.get("sha256", ""))
	if not FileAccess.file_exists(file_path):
		_set_busy(false)
		_set_status("Downloaded file is missing.")
		_log_error("Downloaded file is missing.")
		current_download.clear()
		return

	if not sha256.is_empty() and FileAccess.get_sha256(file_path) != sha256:
		_set_busy(false)
		_set_status("Downloaded file checksum failed.")
		_log_error("Downloaded file checksum failed.")
		current_download.clear()
		return

	var download_label: String = str(current_download.get("label", "download"))
	_set_status("Extracting %s..." % download_label)
	_log("Extracting %s." % download_label)
	await get_tree().process_frame

	var extract_error: Error = await _extract_zip(file_path, INSTALL_DIR, download_label)
	if extract_error != OK:
		_set_busy(false)
		_set_status("Could not extract update.")
		_log_error("Extract failed: %s" % error_string(extract_error))
		current_download.clear()
		return

	_mark_download_installed(current_download)
	current_download.clear()
	_start_next_download()


func _start_next_download() -> void:
	if pending_downloads.is_empty():
		_save_local_versions()
		update_required = false
		_set_busy(false)
		_refresh_status()
		_set_status("Update complete.")
		_log("Update complete.")
		return

	current_download = pending_downloads.pop_front()
	var url := str(current_download.get("url", ""))
	var file_name := str(current_download.get("file_name", "download.zip"))
	var unique_file_name := "%s-%s.zip" % [file_name.get_basename(), Time.get_ticks_msec()]
	var target_path := TEMP_DIR.path_join(unique_file_name)
	current_download["file_path"] = target_path
	progress_bar.value = 0.0

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR))
	var download_label: String = str(current_download.get("label", file_name))
	_set_status("Downloading %s..." % download_label)
	_log("Downloading %s." % download_label)
	http_request.download_file = target_path
	var error_code: Error = http_request.request(url)
	if error_code != OK:
		_set_busy(false)
		_set_status("Could not start download.")
		_log_error("Download request failed: %s" % error_string(error_code))
		current_download.clear()


func _build_download_queue() -> void:
	pending_downloads.clear()
	if manifest.is_empty():
		return

	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var remote_game_version := str(game_data.get("version", manifest.get("gameVersion", "")))
	if remote_game_version != "" and str(local_versions.get("gameVersion", "")) != remote_game_version:
		pending_downloads.append({
			"type": "game",
			"id": "game",
			"version": remote_game_version,
			"url": str(game_data.get("url", "")),
			"sha256": str(game_data.get("sha256", "")),
			"size_bytes": int(game_data.get("sizeBytes", 0)),
			"file_name": "game-%s.zip" % remote_game_version,
			"label": "game %s" % remote_game_version,
		})

	var asset_packs_variant: Variant = manifest.get("assetPacks", [])
	var asset_packs: Array = []
	if typeof(asset_packs_variant) == TYPE_ARRAY:
		asset_packs = asset_packs_variant

	var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
	for asset_pack_variant: Variant in asset_packs:
		if typeof(asset_pack_variant) != TYPE_DICTIONARY:
			continue

		var asset_pack: Dictionary = asset_pack_variant
		var pack_id := str(asset_pack.get("id", ""))
		var pack_version := str(asset_pack.get("version", ""))
		if pack_id.is_empty() or pack_version.is_empty():
			continue

		if str(local_asset_packs.get(pack_id, "")) == pack_version:
			continue

		pending_downloads.append({
			"type": "asset_pack",
			"id": pack_id,
			"version": pack_version,
			"url": str(asset_pack.get("url", "")),
			"sha256": str(asset_pack.get("sha256", "")),
			"size_bytes": int(asset_pack.get("sizeBytes", 0)),
			"file_name": "%s-%s.zip" % [pack_id, pack_version],
			"label": pack_id,
		})

	var filtered_downloads: Array[Dictionary] = []
	for download: Dictionary in pending_downloads:
		if not str(download.get("url", "")).is_empty():
			filtered_downloads.append(download)

	pending_downloads = filtered_downloads


func _mark_download_installed(download: Dictionary) -> void:
	var download_type := str(download.get("type", ""))
	if download_type == "game":
		local_versions["gameVersion"] = str(download.get("version", ""))
		var game_data: Dictionary = _get_dictionary(manifest, "game")
		local_versions["gameExecutable"] = str(game_data.get("executable", ""))
	elif download_type == "asset_pack":
		var local_asset_packs: Dictionary = _get_dictionary(local_versions, "assetPacks")
		local_asset_packs[str(download.get("id", ""))] = str(download.get("version", ""))
		local_versions["assetPacks"] = local_asset_packs


func _extract_zip(zip_path: String, target_dir: String, label: String) -> Error:
	var reader := ZIPReader.new()
	var open_error: Error = reader.open(zip_path)
	if open_error != OK:
		return open_error

	var packed_file_paths: PackedStringArray = reader.get_files()
	var file_count: int = packed_file_paths.size()
	var extracted_file_count: int = 0
	progress_bar.value = 0.0

	for packed_file_path: String in packed_file_paths:
		if packed_file_path.ends_with("/"):
			continue

		extracted_file_count += 1
		if extracted_file_count == 1 or extracted_file_count % EXTRACT_PROGRESS_BATCH_SIZE == 0:
			var percent: float = 0.0
			if file_count > 0:
				percent = minf((float(extracted_file_count) / float(file_count)) * 100.0, 99.0)
			progress_bar.value = percent
			_set_status(
				"Extracting %s... %d / %d files (%d%%)" % [
					label,
					extracted_file_count,
					file_count,
					int(percent),
				]
			)
			await get_tree().process_frame

		var output_path := target_dir.path_join(packed_file_path)
		var absolute_output_path := ProjectSettings.globalize_path(output_path)
		DirAccess.make_dir_recursive_absolute(absolute_output_path.get_base_dir())

		if FileAccess.file_exists(absolute_output_path):
			var remove_error: Error = DirAccess.remove_absolute(absolute_output_path)
			if remove_error != OK:
				reader.close()
				_log_error("Could not replace existing file: %s (%s)" % [absolute_output_path, error_string(remove_error)])
				return remove_error

		var output_file := FileAccess.open(absolute_output_path, FileAccess.WRITE)
		if output_file == null:
			reader.close()
			_log_error("Could not create extracted file: %s" % absolute_output_path)
			return ERR_CANT_CREATE

		output_file.store_buffer(reader.read_file(packed_file_path))

	reader.close()
	progress_bar.value = 100.0
	return OK


func _delete_existing_download(download_path: String) -> void:
	if not FileAccess.file_exists(download_path):
		return

	var absolute_download_path := ProjectSettings.globalize_path(download_path)
	var remove_error: Error = DirAccess.remove_absolute(absolute_download_path)
	if remove_error != OK:
		_log_error("Could not remove old download: %s" % error_string(remove_error))


func _ensure_executable_permissions(absolute_executable_path: String) -> Error:
	var os_name := OS.get_name()
	if os_name != "Linux" and os_name != "macOS" and os_name != "FreeBSD" and os_name != "NetBSD" and os_name != "OpenBSD" and os_name != "BSD":
		return OK

	var chmod_args := PackedStringArray(["755", absolute_executable_path])
	var exit_code: int = OS.execute("chmod", chmod_args)
	if exit_code != 0:
		return FAILED

	return OK


func _quote_windows_shell(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")


func _load_local_versions() -> void:
	if not FileAccess.file_exists(VERSION_FILE):
		local_versions = {
			"gameVersion": "",
			"assetPacks": {},
		}
		return

	var file := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if file == null:
		local_versions = {}
		return

	var parsed_json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_json) == TYPE_DICTIONARY:
		local_versions = parsed_json
	else:
		local_versions = {}

	if not local_versions.has("assetPacks"):
		local_versions["assetPacks"] = {}


func _load_launcher_config() -> void:
	if not FileAccess.file_exists(LAUNCHER_CONFIG_FILE):
		return

	var file := FileAccess.open(LAUNCHER_CONFIG_FILE, FileAccess.READ)
	if file == null:
		return

	var parsed_json: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed_json) != TYPE_DICTIONARY:
		return

	var config: Dictionary = parsed_json
	var configured_manifest_urls: Dictionary = _get_dictionary(config, "manifestUrls")
	var platform_manifest_url := _get_platform_manifest_url(configured_manifest_urls)
	if not platform_manifest_url.is_empty():
		manifest_url = platform_manifest_url
		return

	var configured_manifest_url := str(config.get("manifestUrl", ""))
	if not configured_manifest_url.is_empty():
		manifest_url = configured_manifest_url


func _get_platform_manifest_url(manifest_urls: Dictionary) -> String:
	if manifest_urls.is_empty():
		return ""

	var os_name := OS.get_name()
	var candidates := PackedStringArray([
		os_name,
		os_name.to_lower(),
	])
	if os_name == "macOS":
		candidates.append("MacOS")
		candidates.append("macos")
	elif os_name == "Linux" or os_name == "FreeBSD" or os_name == "NetBSD" or os_name == "OpenBSD" or os_name == "BSD":
		candidates.append("linux")

	for candidate: String in candidates:
		var manifest_url_variant: Variant = manifest_urls.get(candidate, "")
		var platform_manifest_url := str(manifest_url_variant)
		if not platform_manifest_url.is_empty():
			return platform_manifest_url

	return ""


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value

	return {}


func _save_local_versions() -> void:
	var file := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	if file == null:
		_log_error("Could not write versions file.")
		return

	file.store_string(JSON.stringify(local_versions, "\t"))


func _refresh_status() -> void:
	var local_game_version := str(local_versions.get("gameVersion", ""))
	if local_game_version.is_empty():
		local_game_version = "not installed"
	version_label.text = "Installed version: %s" % local_game_version
	play_button.disabled = not _has_installed_game()
	update_button.disabled = not update_required
	check_button.disabled = false
	if update_required:
		_set_status("Update available.")
	elif local_game_version == "" or local_game_version == "not installed":
		_set_status("Game is not installed.")
	else:
		_set_status("Ready to play.")


func _set_busy(is_busy: bool) -> void:
	check_button.disabled = is_busy
	update_button.disabled = is_busy or not update_required
	play_button.disabled = is_busy or not _has_installed_game()


func _has_installed_game() -> bool:
	if str(local_versions.get("gameVersion", "")).is_empty():
		return false

	var game_data: Dictionary = _get_dictionary(manifest, "game")
	var executable_path := str(game_data.get("executable", local_versions.get("gameExecutable", "")))
	if executable_path.is_empty():
		if OS.get_name() == "Windows":
			executable_path = "Pokemon Aether Online.exe"
		else:
			executable_path = "Pokemon Aether Online.x86_64"

	var absolute_executable_path := ProjectSettings.globalize_path(INSTALL_DIR.path_join(executable_path))
	return FileAccess.file_exists(absolute_executable_path)


func _set_status(message: String) -> void:
	status_label.text = message


func _format_bytes(byte_count: int) -> String:
	var byte_count_float := float(byte_count)
	if byte_count_float >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (byte_count_float / 1024.0 / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0 * 1024.0:
		return "%.1f MB" % (byte_count_float / 1024.0 / 1024.0)
	if byte_count_float >= 1024.0:
		return "%.1f KB" % (byte_count_float / 1024.0)

	return "%d B" % byte_count


func _log(message: String) -> void:
	log_label.append_text("%s\n" % message)


func _log_error(message: String) -> void:
	log_label.append_text("[color=#ff6b6b]%s[/color]\n" % message)
