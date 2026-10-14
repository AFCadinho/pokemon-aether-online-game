extends "res://tests/early_3d_arena_check.gd"

func _init() -> void:
	# Exercise the actual mobile guards on desktop CI, without replacing battle
	# code or changing project.godot. These feature tags last only for this process.
	# Set them before autoload initialization caches OS.has_feature() results.
	ProjectSettings.set_setting("_custom_features", "mobile,android,android_3d_experimental")
	super()

func _run() -> void:
	_check(OS.has_feature("mobile") and OS.has_feature("android") and OS.has_feature("android_3d_experimental"), "fixture enables the real Android feature guards")
	_check(preload("res://scripts/battle/battle_ui/model_platform.gd").supported(), "experimental Android supports 3D")
	if failed:
		quit(1)
		return
	# The parent suite supplies a local stadium and offline Pokémon fixtures.
	# Mark the environment available so the Android download service stays offline.
	root.get_node("Android3DEnvironmentService").verified = true
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	# Compare entry framing with all optional motion disabled, like the desktop fixture.
	settings.android_3d_idle_camera_motion = false
	settings.android_3d_move_camera = false
	await super._run()
	print("ANDROID_3D_ENTRY_VISIBILITY_CHECK ", "FAIL" if failed else "PASS")
