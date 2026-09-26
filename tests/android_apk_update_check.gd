extends SceneTree

const Updater := preload("res://scripts/services/android_apk_update_service.gd")
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Android export preset loads")
	_check(int(presets.get_value("preset.7.options", "version/code", -1)) == int(ProjectSettings.get_setting("application/config/android_version_code", -2)),
		"embedded Android version code matches the exported APK")
	_check(str(presets.get_value("preset.7.options", "package/unique_name", "")) == "com.pokeaether.game",
		"Android package identity remains stable")
	var manifest := {"game": {
		"buildId": "android-build-2",
		"version": "0.3.84",
		"versionCode": 2,
		"url": "https://updates.pokeaether.com/game/game-0.3.84-android.apk",
		"sizeBytes": 12345,
		"sha256": "a".repeat(64),
	}}
	_check(not Updater.parse_release(manifest, 1).is_empty(), "new verified release descriptor accepted")
	var parsed: Variant = JSON.parse_string(JSON.stringify(manifest))
	_check(not Updater.parse_release(parsed, 1).is_empty(), "JSON manifest numbers are accepted")
	_check(Updater.parse_release(manifest, 2).is_empty(), "installed version is not offered")
	var bad := manifest.duplicate(true)
	bad.game.url = "https://evil.example/game/game-0.3.84-android.apk"
	_check(Updater.parse_release(bad, 1).is_empty(), "foreign download host rejected")
	bad = manifest.duplicate(true)
	bad.game.sha256 = "not-a-checksum"
	_check(Updater.parse_release(bad, 1).is_empty(), "invalid checksum rejected")
	bad = manifest.duplicate(true)
	bad.game.sizeBytes = 0
	_check(Updater.parse_release(bad, 1).is_empty(), "empty APK rejected")
	bad = manifest.duplicate(true)
	bad.game.versionCode = 2.5
	_check(Updater.parse_release(bad, 1).is_empty(), "fractional version code rejected")
	var service := Updater.new()
	service.set("_release", manifest.game)
	var test_path := "user://tests/android_apk_update_check.apk"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("test-apk")
	file.close()
	_check(not service.call("_apk_matches", test_path), "wrong size cannot reach installer")
	root.add_child(service)
	service.call("_build_panel")
	service.call("_show_required_update")
	_check(paused and service.process_mode == Node.PROCESS_MODE_ALWAYS,
		"required update pauses gameplay while updater stays active")
	_check((service.get("_overlay") as ColorRect).visible, "required update remains visible")
	paused = false
	service.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if failures == 0:
		print("PASS android_apk_update_check")
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	push_error("FAIL " + message)
