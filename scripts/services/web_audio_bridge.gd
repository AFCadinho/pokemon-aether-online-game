extends RefCounted

## Browser-only bridge around the shell's native HTMLAudio playback. Godot's
## single-threaded WebAudio mixer can successfully initialise while returning
## silent sample blocks, so browser audio must not depend on that mixer.

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
