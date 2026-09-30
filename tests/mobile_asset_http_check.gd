extends SceneTree
const Service := preload("res://scripts/services/mobile_asset_service.gd")
const Cache := preload("res://scripts/services/mobile_asset_cache.gd")
class FixtureService extends Service:
	func release_prefix() -> String:
		return OS.get_environment("POKEAETHER_MOBILE_FIXTURE_ORIGIN") + "/"

var failures := 0
var service: Node
var results: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _fetch(url: String) -> void:
	results.append(await service.fetch_url(url, "fixture-body".sha256_text(), 64))

func _run() -> void:
	service = FixtureService.new()
	var directory := "user://tests/mobile-http-" + str(Time.get_ticks_usec())
	service.cache = Cache.new(directory, 4096)
	root.add_child(service)
	var origin := OS.get_environment("POKEAETHER_MOBILE_FIXTURE_ORIGIN")
	_check(origin.begins_with("http://127.0.0.1:"), "loopback fixture is configured")
	_fetch(origin + "/asset")
	_fetch(origin + "/asset")
	while results.size() < 2:
		await process_frame
	_check(results[0] != "" and results[0] == results[1], "concurrent requests share one cached file")
	_check(FileAccess.get_file_as_string(results[0]) == "fixture-body", "downloaded bytes are complete")
	var restarted := Service.new()
	restarted.cache = Cache.new(directory, 4096)
	root.add_child(restarted)
	ProjectSettings.set_setting("application/config/android_asset_build_id", "fixture-build-7")
	_check(await restarted.release_prefix() == "https://web-assets.pokeaether.com/web/releases/fixture-build-7/", "Android assets are pinned without fetching the active browser release")
	ProjectSettings.set_setting("application/config/android_asset_build_id", "../invalid")
	_check(await restarted.release_prefix() == "", "invalid pinned asset build is rejected")
	ProjectSettings.set_setting("application/config/android_asset_build_id", "")
	_check(await restarted.fetch_url(origin + "/asset", "fixture-body".sha256_text(), 64) == results[0], "restart reads disk without a second download")
	_check(await service.fetch_url(origin + "/bad", "correct".sha256_text(), 64) == "", "wrong response checksum is rejected")
	_check(await service.fetch_url(origin + "/missing", "", 64) == "", "404 does not enter cache")
	_check(await service.fetch_url(origin + "/large", "", 64) == "", "oversized response is rejected")
	_check(await service.fetch("cry with space.ogg") != "", "manifest-driven fetch validates size and checksum and encodes URL segments")
	_check(await service.fetch("oversized.ogg") == "", "manifest cannot allow an oversized asset")
	_check(await service.fetch("../escape") == "", "catalog traversal is refused")
	var cry := AudioStreamOggVorbis.load_from_file("res://assets/audio/sfx/pokemon_cries/PIKACHU.ogg")
	_check(cry != null and cry.get_length() > 0, "native Ogg loader can decode a standalone cry")
	# Use a filename without an extension, as the persistent cache does.
	var video_path := directory.path_join("video.cache")
	var video_bytes := FileAccess.get_file_as_bytes("res://assets/video/login_background.ogv")
	var file := FileAccess.open(video_path, FileAccess.WRITE)
	file.store_buffer(video_bytes)
	file.close()
	var stream := VideoStreamTheora.new()
	stream.file = video_path
	var player := VideoStreamPlayer.new()
	root.add_child(player)
	player.stream = stream
	player.play()
	await create_timer(0.25).timeout
	_check(player.is_playing() and player.get_video_texture() != null, "external cached Theora video plays without an import")
	player.stop()
	player.queue_free()
	service.queue_free()
	restarted.queue_free()
	await process_frame
	var dir := DirAccess.open(directory)
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("mobile_asset_http_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
