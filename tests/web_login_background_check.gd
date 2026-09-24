extends SceneTree

var failures := 0


func _init() -> void:
	var login_screen := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(not login_screen.contains('if OS.has_feature("web"):\n\t\tbackground_video_player.stop()'), "web login does not disable the client background video")
	_check(presets.contains("assets/video/login_background.ogv"), "web export includes the client login animation")
	print("web_login_background_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)
