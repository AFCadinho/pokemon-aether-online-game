extends SceneTree
const ReleaseBundles = preload("res://scripts/release_asset_bundles.gd")
const Downloader = preload("res://scripts/resumable_download_service.gd")

var service: RefCounted
var downloader: Node
var descriptor: Dictionary
var index: Dictionary
var queue: Array = []
var current: Dictionary = {}
var failed := ""
var completed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var base := OS.get_environment("POKEAETHER_BUNDLE_HTTP_BASE")
	var source_index := OS.get_environment("POKEAETHER_BUNDLE_HTTP_INDEX")
	var output := OS.get_environment("POKEAETHER_BUNDLE_HTTP_OUTPUT")
	assert(base.begins_with("http://127.0.0.1:") and source_index.is_absolute_path() and output.is_absolute_path())
	assert(not DirAccess.dir_exists_absolute(output) and DirAccess.make_dir_recursive_absolute(output) == OK)
	service = ReleaseBundles.new(output.path_join("store"), output.path_join("indexes"))
	descriptor = {
		"schema": 1, "kind": "pokeaether-release-asset-index", "revision": "download-test",
		"url": base + "/optional-assets/pokemon_3d/index/test.json", "objectBaseUrl": base,
		"sha256": FileAccess.get_sha256(source_index),
		"sizeBytes": FileAccess.get_file_as_bytes(source_index).size(),
		"requiredAssetIds": ReleaseBundles.RELEASE_ASSET_IDS.duplicate(),
	}
	queue = service.jobs(descriptor).jobs
	assert(queue.size() == 1 and queue[0].type == "asset_bundle_index")
	downloader = Downloader.new()
	root.add_child(downloader)
	downloader.download_completed.connect(_downloaded)
	downloader.download_failed.connect(func(message: String, _summary: Dictionary) -> void:
		failed = message
		completed = true
	)
	_start_next()
	var deadline := Time.get_ticks_msec() + 120000
	while not completed:
		assert(Time.get_ticks_msec() < deadline, failed)
		await process_frame
	assert(failed.is_empty())
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(service.catalog_path()))
	assert(catalog is Array and catalog.size() == 14)
	assert(service.jobs(descriptor).jobs.is_empty())
	print("RELEASE_ASSET_BUNDLE_HTTP_OK downloads=8 appearances=14 no_op=0 manual_paths=false")
	quit()


func _start_next() -> void:
	if queue.is_empty():
		completed = true
		return
	current = queue.pop_front()
	current.download_dir = "user://approved-3d-download-test"
	var error: Error = downloader.start_download(current)
	if error != OK:
		failed = error_string(error)
		completed = true


func _downloaded(path: String, _summary: Dictionary) -> void:
	var result: Dictionary
	if current.type == "asset_bundle_index":
		result = service.accept_index(descriptor, path)
		index = service.cached_index(descriptor)
		for job: Dictionary in result.get("jobs", []):
			queue.append(job)
	else:
		result = service.accept_bundle(index, current.id, path)
	DirAccess.remove_absolute(path)
	if not str(result.get("error", "")).is_empty():
		failed = str(result.error)
		completed = true
		return
	current.clear()
	_start_next()
