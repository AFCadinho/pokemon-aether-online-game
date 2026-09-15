extends SceneTree

class FakeLoader extends "res://scripts/services/web_asset_module_service.gd":
	var downloads := 0
	var fail_next := false
	var available := false
	func _is_browser() -> bool:
		return true
	func _scene_exists(_path: String) -> bool:
		return available
	func _download_and_mount(_module: String, _scene: String) -> Dictionary:
		downloads += 1
		await get_tree().process_frame
		await get_tree().process_frame
		if fail_next:
			fail_next = false
			return {"success": false, "error": "Fixture failure"}
		available = true
		return {"success": true}

var results: Array = []
var loader: FakeLoader

func _init() -> void:
	_run.call_deferred()

func _start() -> void:
	results.append(await loader.ensure_scene_available(loader.MISTY_MODULE_SCENE))

func _run() -> void:
	loader = FakeLoader.new()
	root.add_child(loader)
	loader.fail_next = true
	_start.call_deferred()
	_start.call_deferred()
	while results.size() < 2:
		await process_frame
	var ok: bool = loader.downloads == 1 and not results[0].success and not results[1].success
	var retry := await loader.ensure_scene_available(loader.MISTY_MODULE_SCENE)
	ok = ok and retry.success and loader.downloads == 2
	var cached := await loader.ensure_scene_available(loader.MISTY_MODULE_SCENE)
	ok = ok and cached.success and loader.downloads == 2
	loader.queue_free()
	print("web_asset_module_queue_check: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
