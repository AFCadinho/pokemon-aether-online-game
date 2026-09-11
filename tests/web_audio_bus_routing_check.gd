extends SceneTree

var failures := 0


func _init() -> void:
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	var music_source := FileAccess.get_file_as_string("res://scripts/services/music_manager.gd")
	var sfx_source := FileAccess.get_file_as_string("res://scripts/services/sfx_manager.gd")
	_check(settings_source.contains("func get_audio_output_bus"), "settings expose a shared audio output route")
	_check(settings_source.contains("return MASTER_BUS if OS.has_feature(\"web\") else preferred_bus"), "web playback routes through Godot's guaranteed Master bus")
	_check(music_source.contains("SettingsManager.get_audio_output_bus(SettingsManager.MUSIC_BUS)"), "web music uses the Master fallback")
	_check(sfx_source.contains("SettingsManager.get_audio_output_bus(DEFAULT_BUS)"), "web effects use the Master fallback")
	_check(sfx_source.contains("SettingsManager.get_audio_output_bus(SettingsManager.POKEMON_CRY_BUS)"), "web cries use the Master fallback")
	print("web_audio_bus_routing_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
