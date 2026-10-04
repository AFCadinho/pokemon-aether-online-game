extends SceneTree

const Usage := preload("res://scripts/services/desktop_asset_usage_service.gd")
const Storage := preload("res://scripts/services/desktop_asset_storage.gd")
const SETTINGS_SCENE := "res://scenes/interface/settings/settings_menu.tscn"

class PausedScan extends RefCounted:
	var release := Semaphore.new()

	func scan(paths: Dictionary) -> Dictionary:
		release.wait()
		return Usage._scan_usage(paths)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings_scene := load(SETTINGS_SCENE) as PackedScene
	var baseline_started := Time.get_ticks_usec()
	var baseline_sprites: int = root.get_node("WebPokemonSpriteService").desktop_disk_bytes()
	var baseline_models: int = preload("res://scripts/services/on_demand_3d_bundle_service.gd").downloaded_bytes()
	var baseline_scan_us := Time.get_ticks_usec() - baseline_started
	var sandbox := ProjectSettings.globalize_path("user://settings-storage-check-%d" % Time.get_ticks_usec())
	var install := sandbox.path_join("install")
	var legacy_models := sandbox.path_join("asset-bundles-v1")
	_write(install.path_join("assets/sprites/pokemon/front/pikachu/sheet.png"), 3)
	_write(install.path_join("assets/sprites/pokemon/gen5/shiny_back/eevee/sheet.png"), 5)
	_write(legacy_models.path_join("objects/pikachu/model.scn"), 7)
	var previous_install := OS.get_environment("POKEAETHER_INSTALL_DIR")
	var previous_models := OS.get_environment("POKEAETHER_LAUNCHER_MODEL_DIR")
	OS.set_environment("POKEAETHER_INSTALL_DIR", install)
	OS.set_environment("POKEAETHER_LAUNCHER_MODEL_DIR", legacy_models)
	var service := root.get_node("DesktopAssetUsageService")
	var paths: Dictionary = Usage._storage_paths()
	var expected_sprites: int = root.get_node("WebPokemonSpriteService").desktop_disk_bytes()
	var expected_models: int = preload("res://scripts/services/on_demand_3d_bundle_service.gd").downloaded_bytes()
	_check(expected_sprites >= 8 and expected_models >= 7, "fixture includes nested legacy sprites and models")

	# Hold the worker indefinitely: opening, closing and freeing menus must still
	# return, and frames must advance before any storage result is available.
	var paused := PausedScan.new()
	service._thread = Thread.new()
	_check(service._thread.start(paused.scan.bind(paths)) == OK, "paused worker starts")
	service.set_process(true)
	var worker: Thread = service._thread
	var menu := settings_scene.instantiate()
	root.add_child(menu)
	var started := Time.get_ticks_usec()
	menu.open("game")
	var opening_us := Time.get_ticks_usec() - started
	_check(menu.visible and service.is_scanning(), "settings open before storage scan finishes")
	_check(menu.sprite_storage_button.disabled and menu.model_storage_button.disabled,
		"cache removal waits for complete storage counts")
	_check("Checking" in menu.model_storage_hint.text, "a pending scan has a visible explanation")
	menu.close()
	menu.open("game")
	_check(service._thread == worker, "reopening shares the pending scan")
	for frame in 3:
		await process_frame
	_check(menu.visible and service.is_scanning(), "game frames continue while storage worker is paused")
	menu.free()
	_check(service.is_scanning(), "freeing settings does not join a pending worker")
	menu = settings_scene.instantiate()
	root.add_child(menu)
	menu.open("login")
	_check(service._thread == worker, "login settings also share the pending scan")
	paused.release.post()
	await _wait_for_scan(service)
	_check(service.sprite_bytes == expected_sprites and service.model_bytes == expected_models,
		"background counts match all desktop cache and launcher asset roots")
	_check("MB" in menu.sprite_storage_hint.text and "MB" in menu.model_storage_hint.text,
		"completed scan updates separate, readable storage labels")
	_check(not menu.sprite_storage_button.disabled and not menu.model_storage_button.disabled,
		"completed nonempty scan enables removal")
	_check(menu.model_storage_button.text == "Remove files" and menu.model_storage_button.custom_minimum_size.y >= 40,
		"removal uses a short, properly sized action button")
	# The world keeps a dormant battle UI ready on the map. Its mere existence
	# must not disable cache management outside a battle.
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var prewarmed = load("res://scenes/battle/battle.tscn").instantiate()
	host.prewarm_battle(prewarmed)
	menu._refresh_asset_storage_controls()
	_check(not menu.model_storage_button.disabled and not menu.sprite_storage_button.disabled,
		"a hidden prewarmed battle does not block removal on the map")
	menu._confirm_remove_models()
	_check(menu.storage_confirm_dialog.visible and "download again" in menu.storage_confirm_dialog.message_label.text,
		"an enabled button opens the existing confirmation with clear download consequences")
	await process_frame
	_check(menu.get_viewport().gui_get_focus_owner() == menu.storage_confirm_dialog.cancel_button, "cancel has the default focus in the removal confirmation")
	menu.storage_confirm_dialog.cancel_button.pressed.emit()
	_check(not menu.storage_confirm_dialog.visible and FileAccess.file_exists(legacy_models.path_join("objects/pikachu/model.scn")), "cancelling confirmation leaves downloaded files untouched")
	menu._confirm_remove_sprites()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	menu._input(escape)
	_check(menu.visible and not menu.storage_confirm_dialog.visible and FileAccess.file_exists(legacy_models.path_join("objects/pikachu/model.scn")),
		"Escape dismisses only the confirmation without deleting files")
	var model_service := root.get_node("OnDemand3DBundleService")
	model_service._busy = true
	menu._process(0.6)
	_check(menu.model_storage_button.disabled and "downloads" in menu.model_storage_hint.text,
		"a download temporarily disables removal with a readable reason")
	menu._remove_downloaded_assets(true)
	_check(FileAccess.file_exists(legacy_models.path_join("objects/pikachu/model.scn")),
		"a newly busy download protects files even after confirmation was opened")
	model_service._busy = false
	menu._process(0.6)
	_check(not menu.model_storage_button.disabled, "button re-enables while settings stay open after downloads finish")
	host.mount(prewarmed)
	menu._refresh_asset_storage_controls()
	_check(menu.sprite_storage_button.disabled and menu.model_storage_button.disabled and "battle" in menu.model_storage_hint.text,
		"a mounted battle still protects its files and explains the disabled action")
	menu._confirm_remove_models()
	_check(not menu.storage_confirm_dialog.visible, "blocked removal cannot open a confirmation")
	host.release()
	host.free()
	menu._refresh_asset_storage_controls()
	_check(not menu.model_storage_button.disabled, "removal is available again after leaving the battle")
	service.model_bytes = 0
	menu._refresh_asset_storage_controls()
	_check(menu.model_storage_button.disabled and "No files" in menu.model_storage_hint.text,
		"an empty cache is explained rather than appearing broken")
	service.model_bytes = expected_models

	# Exercise the real request path and a refresh after assets change without
	# removing or touching any existing slot assets.
	_write(legacy_models.path_join("objects/eevee/model.scn"), 11)
	menu.close()
	menu.open("game")
	_check(service.is_scanning(), "each opening requests fresh counts asynchronously")
	_check(menu.model_storage_button.disabled, "stale counts cannot enable removal during refresh")
	await _wait_for_scan(service)
	_check(service.model_bytes == expected_models + 11, "refresh sees newly downloaded assets")
	var battle := Node.new()
	battle.name = "ExperimentalBattle3D"
	root.add_child(battle)
	menu._refresh_asset_storage_controls()
	_check(menu.sprite_storage_button.disabled and menu.model_storage_button.disabled,
		"active battle still prevents downloaded asset removal")
	battle.free()
	Storage.remove_directory(sandbox)
	_restore_environment("POKEAETHER_INSTALL_DIR", previous_install)
	_restore_environment("POKEAETHER_LAUNCHER_MODEL_DIR", previous_models)
	menu.close()
	started = Time.get_ticks_usec()
	menu.open("game")
	var large_install_opening_us := Time.get_ticks_usec() - started
	await _wait_for_scan(service)
	_check(service.sprite_bytes == baseline_sprites and service.model_bytes == baseline_models,
		"refresh reflects removed fixture assets")
	menu.free()
	print("SETTINGS_STORAGE_RESPONSIVENESS_OK opening_us=%d baseline_scan_us=%d large_install_opening_us=%d sprite_bytes=%d" % [
		opening_us, baseline_scan_us, large_install_opening_us, baseline_sprites])
	quit(1 if failed else 0)


func _wait_for_scan(service: Node) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while service.is_scanning() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not service.is_scanning(), "storage worker completes and is joined")


func _write(path: String, count: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("x".repeat(count))
	file.close()


func _restore_environment(key: String, value: String) -> void:
	if value.is_empty():
		OS.unset_environment(key)
	else:
		OS.set_environment(key, value)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
