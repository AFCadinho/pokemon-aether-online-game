extends SceneTree

const Service := preload("res://scripts/services/android_music_pack_service.gd")
const TEST_ROOT := "user://tests/android_music_pack"
const GOOD_VERSION := "music-test-one"

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := Service.new()
	root.add_child(service)
	service.call("_remove_tree", TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var descriptor := {
		"id": "music",
		"version": GOOD_VERSION,
		"url": "https://updates.pokeaether.com/assets/%s.zip" % GOOD_VERSION,
		"sizeBytes": 1234,
		"sha256": "a".repeat(64),
	}
	_check(service.call("_valid_descriptor", descriptor), "versioned same-origin descriptor is accepted")
	var invalid_url := descriptor.duplicate()
	invalid_url.url = "https://example.com/assets/%s.zip" % GOOD_VERSION
	_check(not service.call("_valid_descriptor", invalid_url), "off-origin archive URL is rejected")
	var invalid_version := descriptor.duplicate()
	invalid_version.version = "music-../../other"
	_check(not service.call("_valid_descriptor", invalid_version), "unsafe version is rejected")
	_check(not service.call("_safe_archive_entry", "assets/music/../escape.ogg"),
		"ZIP traversal is rejected")
	_check(not service.call("_safe_archive_entry", "assets/music\\battle\\wild.ogg"),
		"Windows-style ZIP traversal is rejected")

	var archive_path := TEST_ROOT.path_join("music.zip")
	var packer := ZIPPacker.new()
	_check(packer.open(ProjectSettings.globalize_path(archive_path)) == OK, "test archive opens")
	var tracks: Array = Service.REQUIRED_TRACKS
	for relative_path: String in tracks:
		packer.start_file("assets/music/" + relative_path)
		packer.write_file(("OggS-test-%s" % relative_path).to_utf8_buffer())
		packer.close_file()
	packer.close()
	var file := FileAccess.open(archive_path, FileAccess.READ)
	var archive_size := file.get_length()
	file.close()
	_check(service.call("_archive_matches", archive_path, archive_size, FileAccess.get_sha256(archive_path)),
		"size and SHA-256 verify the downloaded archive")
	_check(not service.call("_archive_matches", archive_path, archive_size + 1, FileAccess.get_sha256(archive_path)),
		"wrong size cannot activate a pack")
	_check(not service.call("_archive_matches", archive_path, archive_size, "0".repeat(64)),
		"wrong checksum cannot activate a pack")
	_check(service.call("_install_archive", archive_path, GOOD_VERSION),
		"valid music ZIP installs in an isolated version directory")
	service.active_version = GOOD_VERSION
	var installed_path := service.resolve_track_path("res://assets/music/" + tracks[0])
	_check(installed_path.begins_with("user://assets/music/%s/" % GOOD_VERSION)
		and FileAccess.file_exists(installed_path), "track resolver prefers the installed version")
	_check(service.resolve_track_path("res://assets/music/../outside.ogg") == "",
		"track resolver cannot escape the pack")

	var incomplete_path := TEST_ROOT.path_join("incomplete.zip")
	packer = ZIPPacker.new()
	packer.open(ProjectSettings.globalize_path(incomplete_path))
	packer.start_file("assets/music/login/lugia_theme_lofi.ogg")
	packer.write_file("OggS".to_utf8_buffer())
	packer.close_file()
	packer.close()
	_check(not service.call("_install_archive", incomplete_path, "music-test-incomplete"),
		"ZIP without required tracks does not activate")
	_check(service.resolve_track_path("res://assets/music/" + tracks[0]) == installed_path,
		"failed update leaves the previous music version usable")
	var real_archive := OS.get_environment("POKEAETHER_ANDROID_MUSIC_TEST_ARCHIVE")
	if real_archive != "":
		var state_path := "user://asset_versions.json"
		var old_state_exists := FileAccess.file_exists(state_path)
		var old_state := FileAccess.get_file_as_string(state_path) if old_state_exists else ""
		var real_version := "music-test-real"
		_check(service.call("_install_archive", real_archive, real_version),
			"locally packaged full music ZIP installs")
		_check(service.call("_write_installed_version", real_version),
			"installed music version is persisted atomically")
		_check(service.call("_read_installed_version") == real_version,
			"installed music version survives service restart")
		service.active_version = real_version
		for relative_path: String in tracks:
			var stream_path := service.resolve_track_path("res://assets/music/" + relative_path)
			_check(AudioStreamOggVorbis.load_from_file(stream_path) != null,
				"installed %s decodes as Ogg" % relative_path)
		service.call("_remove_tree", "user://assets/music/%s" % real_version)
		if old_state_exists:
			var restore := FileAccess.open(state_path, FileAccess.WRITE)
			restore.store_string(old_state)
			restore.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	service.call("_remove_tree", "user://assets/music/%s" % GOOD_VERSION)
	service.call("_remove_tree", TEST_ROOT)
	service.queue_free()
	if failures == 0:
		print("android_music_pack_check: PASS")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("android_music_pack_check: %s" % message)
