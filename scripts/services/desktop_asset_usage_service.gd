extends Node
## Storage accounting must never block opening a menu on a large installation.

signal usage_updated

const Storage := preload("res://scripts/services/desktop_asset_storage.gd")
const SpriteCache := preload("res://scripts/services/desktop_sprite_disk_cache.gd")
const ModelDownloads := preload("res://scripts/services/on_demand_3d_bundle_service.gd")

var sprite_bytes := -1
var model_bytes := -1
var _thread: Thread


func _ready() -> void:
	set_process(false)


func is_scanning() -> bool:
	return _thread != null


func request_refresh() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile") or is_scanning():
		return
	# Resolve configuration on the main thread; the worker only reads files.
	var paths := _storage_paths()
	_thread = Thread.new()
	var error := _thread.start(_scan_usage.bind(paths), Thread.PRIORITY_LOW)
	if error != OK:
		_thread = null
		push_warning("Could not start downloaded asset storage scan: %s" % error)
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var usage: Dictionary = _thread.wait_to_finish()
	_thread = null
	set_process(false)
	sprite_bytes = int(usage.sprites)
	model_bytes = int(usage.models)
	usage_updated.emit()


func _exit_tree() -> void:
	# This autoload outlives settings scenes, including logout to the login menu.
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


static func _storage_paths() -> Dictionary:
	var sprite_roots: Array[String] = [ProjectSettings.globalize_path(SpriteCache.DEFAULT_ROOT)]
	var install := Storage._launcher_root("POKEAETHER_INSTALL_DIR")
	if not install.is_empty():
		for folder in Storage.LEGACY_SPRITE_FOLDERS:
			sprite_roots.append(install.path_join(folder))
	var model_roots: Array[String] = [ProjectSettings.globalize_path(ModelDownloads.ROOT)]
	var legacy_models := Storage._launcher_root("POKEAETHER_LAUNCHER_MODEL_DIR")
	if not legacy_models.is_empty():
		model_roots.append(legacy_models)
	return {"sprites": sprite_roots, "models": model_roots}


static func _scan_usage(paths: Dictionary) -> Dictionary:
	var usage := {"sprites": 0, "models": 0}
	for category in usage:
		for path: String in paths[category]:
			usage[category] += Storage.directory_bytes(path)
	return usage
