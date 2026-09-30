extends RefCounted

## Browser-only bridge around the shell's native HTMLAudio playback. Godot's
## single-threaded WebAudio mixer can successfully initialise while returning
## silent sample blocks, so browser audio must not depend on that mixer.

const CATALOG_PATH := "res://generated/browser_audio_catalog.json"
static var _available: Dictionary = {}
static var _catalog_loaded := false


static func has_resource(path: String) -> bool:
	if not _catalog_loaded:
		_catalog_loaded = true
		if FileAccess.file_exists(CATALOG_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
			if parsed is Array:
				for value: Variant in parsed:
					if value is String:
						_available[value] = true
	return _available.has(path)


static func play_music(resource_path: String, volume: float) -> void:
	_call("playMusic", [resource_path, volume])


static func stop_music() -> void:
	_call("stopMusic", [])


static func set_music_volume(volume: float) -> void:
	_call("setMusicVolume", [volume])


static func play_sfx(resource_path: String, volume: float, pitch_scale: float = 1.0) -> void:
	_call("playSfx", [resource_path, volume, pitch_scale])


static func _call(method_name: String, arguments: Array) -> void:
	if not OS.has_feature("web"):
		return
	var arguments_json := JSON.stringify(arguments)
	JavaScriptBridge.eval(
		"window.pokeaetherBrowserAudio?.%s?.apply(window.pokeaetherBrowserAudio, %s)" % [method_name, arguments_json],
		true
	)
