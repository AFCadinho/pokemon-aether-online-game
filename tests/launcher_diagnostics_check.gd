extends SceneTree

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://launcher/scripts/launcher.gd")
	var download_source := FileAccess.get_file_as_string("res://launcher/scripts/resumable_download_service.gd")
	var scene := FileAccess.get_file_as_string("res://launcher/scenes/launcher.tscn")
	var package_source := FileAccess.get_file_as_string("res://tools/package_launcher_release.py")
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/deploy-desktop-r2.yml")

	_check(
		scene.contains('[node name="DiagnosticsButton" type="Button"')
		and scene.contains('[node name="DiagnosticsCard" type="PanelContainer"')
		and scene.contains('[node name="CopyButton" type="Button"')
		and scene.contains('[node name="OpenFolderButton" type="Button"')
		and scene.contains('[node name="ClearButton" type="Button"'),
		"launcher exposes diagnostics with copy, folder, and clear actions"
	)
	_check(
		source.contains("const MAX_ERROR_LOG_BYTES := 1024 * 1024")
		and source.contains("PREVIOUS_ERROR_LOG_FILE")
		and source.contains("func _rotate_diagnostics_log_if_needed"),
		"launcher diagnostics are bounded and rotated"
	)
	_check(
		source.contains('for private_path: String in _private_diagnostic_paths()')
		and source.contains('sanitized.replace(private_path, "<private_path>")')
		and source.contains('part.find("https://")')
		and source.contains("_sanitize_diagnostics_file(PREVIOUS_ERROR_LOG_FILE)")
		and source.contains("?<redacted>"),
		"launcher diagnostics redact current and historical local storage paths and URL queries"
	)
	_check(
		download_source.contains("checksum_retry_count < 1")
		and download_source.contains("_prepare_clean_checksum_retry()")
		and download_source.contains('"checksum mismatch required a clean restart"')
		and download_source.contains('headers.append("Cache-Control: no-cache")')
		and download_source.contains('headers.append("Pragma: no-cache")'),
		"checksum failures clean up and retry once with cache revalidation"
	)
	_check(
		package_source.contains('"game-{artifact_id}-windows.zip"')
		and package_source.contains('artifact_id = args.version if build_id == args.version'),
		"release packages use immutable build-aware game artifact names"
	)
	_check(
		workflow.contains('python3 tools/verify_launcher_release_urls.py')
		and workflow.find('python3 tools/verify_launcher_release_urls.py')
			< workflow.find('manifest_upload_args=('),
		"release workflow verifies public artifacts before publishing manifests"
	)

	if not failed:
		print("PASS launcher_diagnostics_check")
	quit(1 if failed else 0)


func _check(value: bool, message: String) -> void:
	if value:
		return
	failed = true
	push_error("FAIL %s" % message)
