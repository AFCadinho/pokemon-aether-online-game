extends SceneTree

var failures := 0


func _init() -> void:
	var shell := FileAccess.get_file_as_string("res://infrastructure/web/shell.html")
	_check(shell.contains("const sharedAudioContext"), "web shell provides one shared native audio context")
	_check(shell.contains("await unlockAudio();"), "preview start unlocks audio within its user gesture")
	_check(shell.contains("window.AudioContext = sharedAudioContext"), "Godot reuses the gesture-unlocked context")
	_check(shell.contains("webAudioContext.state !== 'running'"), "sound control reports a failed unlock instead of hiding it")
	print("web_audio_shell_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
