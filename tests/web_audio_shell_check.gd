extends SceneTree

var failures := 0


func _init() -> void:
	var shell := FileAccess.get_file_as_string("res://infrastructure/web/shell.html")
	_check(shell.contains("const sharedAudioContext"), "web shell provides one shared native audio context")
	_check(shell.contains("await unlockAudio();"), "preview start unlocks audio within its user gesture")
	_check(shell.contains("window.AudioContext = sharedAudioContext"), "Godot reuses the gesture-unlocked context")
	_check(shell.contains("webAudioContext.state !== 'running'"), "sound control reports a failed unlock instead of hiding it")
	_check(shell.contains("const primeAudioOutput"), "web shell primes a silent output source during the player gesture")
	_check(shell.contains("source.start(0)"), "web shell starts the silent source before awaiting audio resume")
	_check(shell.contains("const playAudioTestTone"), "web shell provides an audible output test on Godot's shared audio context")
	_check(shell.contains("oscillator.connect(gain).connect(webAudioContext.destination)"), "the audible output test reaches the browser audio destination")
	_check(shell.contains("playAudioTestTone();"), "the visible sound control plays the audible output test after unlocking")
	_check(shell.contains("['pointerdown', 'touchend', 'keydown']"), "web shell retries audio unlock on the first game interaction")
	print("web_audio_shell_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
