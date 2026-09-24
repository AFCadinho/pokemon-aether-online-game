extends SceneTree

var failures := 0


func _init() -> void:
	var login_screen := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	var login_scene := FileAccess.get_file_as_string("res://scenes/interface/login_screen.tscn")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(not login_screen.contains('if OS.has_feature("web"):\n\t\tbackground_video_player.stop()'), "web login does not disable the client background video")
	_check(presets.contains("assets/video/login_background.ogv"), "web export includes the client login animation")
	_check(login_scene.contains("texture_filter = 1"), "login background uses nearest filtering for pixel-art scaling")
	_check(login_scene.contains("color = Color(0.006, 0.005, 0.02, 0.45)"), "login background shade allows more of the video through")
	print("web_login_background_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
