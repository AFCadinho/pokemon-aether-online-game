extends Node

var report := {"success": true, "maps": [], "samples": [], "errors": []}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var input: Array = WebAssetModuleService.MISTY_MAP_SCENES.values()
	var loader := WebAssetModuleService
	for path: String in input:
		var result: Dictionary = await loader.ensure_scene_available(path)
		if not bool(result.get("success", false)):
			report.errors.append(result.get("error", "Unknown error"))
			report.success = false
			JavaScriptBridge.eval("window.mistyCoreProbe = " + JSON.stringify(report), true)
			return
		var scene := load(path) as PackedScene
		if scene == null:
			report.errors.append("Could not load " + path)
			continue
		var instance := scene.instantiate()
		report.maps.append({"path": path, "nodes": instance.get_child_count()})
		instance.free()
		scene = null
		await get_tree().process_frame
		await get_tree().process_frame
	for iteration in range(8):
		for path: String in [input[0], input[12]]:
			var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			if scene == null:
				report.errors.append("Repeated load failed " + path)
				continue
			var instance := scene.instantiate()
			instance.free()
			scene = null
			await get_tree().process_frame
			await get_tree().process_frame
		report.samples.append({"iteration": iteration, "textureBytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	report.success = report.errors.is_empty() and report.maps.size() == 16
	JavaScriptBridge.eval("window.mistyCoreProbe = " + JSON.stringify(report), true)
