extends SceneTree
const Cache := preload("res://scripts/services/mobile_asset_cache.gd")
var failures := 0
var directory := "user://tests/mobile-cache-" + str(Time.get_ticks_usec())

func _init() -> void:
	_run.call_deferred()

func _store(cache: RefCounted, url: String, body: String, digest := "") -> String:
	var temporary: String = cache.path_for(url) + ".partial"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	file.store_string(body)
	file.close()
	return cache.commit(url, temporary, digest, 64)

func _run() -> void:
	var cache := Cache.new(directory, 12)
	var first := _store(cache, "first", "aaaaaa", "aaaaaa".sha256_text())
	_check(first != "", "valid digest commits atomically")
	var restarted := Cache.new(directory, 12)
	_check(restarted.read_path("first") == first, "a new instance reuses the persistent cache")
	_check(_store(cache, "bad", "wrong", "correct".sha256_text()) == "", "checksum mismatch is rejected")
	_check(not FileAccess.file_exists(cache.path_for("bad") + ".partial"), "failed download leaves no partial file")
	cache.pins[first] = true
	_check(_store(cache, "second", "bbbbbb") != "", "second file fits byte budget")
	_check(_store(cache, "third", "cccccc") != "", "oldest unpinned file is evicted")
	_check(cache.read_path("first") != "" and cache.read_path("second") == "", "active video remains pinned during eviction")
	var file := FileAccess.open(first, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	_check(cache.read_path("first") == "", "same-size local corruption is detected")
	_check(cache.read_path("third", "different".sha256_text()) == "", "cached file cannot bypass expected checksum")
	var dir := DirAccess.open(directory)
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("mobile_asset_cache_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
