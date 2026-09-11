extends SceneTree

var failures := 0


func _init() -> void:
	var shell := FileAccess.get_file_as_string("res://infrastructure/web/shell.html")
	_check(shell.contains("const sharedAudioContext"), "web shell captures Godot's native audio context")
	_check(shell.contains("await unlockAudio();"), "preview retries audio unlock from player interaction")
	_check(shell.contains("window.AudioContext = sharedAudioContext"), "web shell observes Godot's audio context")
	_check(not shell.contains("Test sound"), "web shell removes the temporary browser tone control")
	_check(shell.contains("window.pokeaetherAudioDiagnostics"), "web shell exposes opt-in browser audio diagnostics")
	_check(shell.contains("audio-debug"), "web shell enables detailed diagnostics only from the audio-debug query")
	_check(shell.contains("context-resume-failed"), "web shell records a failed context resume")
	_check(shell.contains("context-created"), "web shell records Godot's WebAudio context creation")
	_check(shell.contains("worklet-module-loaded"), "web shell records Godot worklet module loading")
	_check(shell.contains("worklet-node-connected"), "web shell records Godot worklet connection to audio output")
	_check(shell.contains("new NativeAudioContext(...args)"), "Godot keeps its requested WebAudio sample-rate and latency settings")
	_check(shell.contains("webAudioContext = new NativeAudioContext(...args);")
		and not shell.contains("webAudioContext = new NativeAudioContext();"),
		"Godot keeps ownership of the WebAudio context instead of receiving a shell-created one")
	_check(shell.contains("await engine.startGame({")
		and shell.find("await unlockAudio();", shell.find("await engine.startGame({")) > shell.find("await engine.startGame({"),
		"the browser resumes Godot audio again after its worklet attaches")
	_check(shell.contains("['pointerdown', 'touchend', 'keydown']"), "web shell retries audio unlock on the first game interaction")
	print("web_audio_shell_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
